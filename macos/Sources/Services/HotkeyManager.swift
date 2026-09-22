import AppKit
import Carbon.HIToolbox

/// HIToolbox caches AppleFnUsageType. Writing the pref does not change Globe/Fn
/// until this private call flushes that cache.
@_silgen_name("TISUpdateFnUsageType")
private func TISUpdateFnUsageType(_ value: Int32)

private enum FnUsageType: Int32 {
    case doNothing = 0
    case showEmojiAndSymbols = 2
}

/// Monitors an exact chord of physical modifier keys and turns tap, double-tap,
/// and hold gestures into recording actions.
@MainActor
final class HotkeyManager {
    var onRecordStart: (() -> Void)?
    var onRecordStop: (() -> Void)?

    private let preferences: ShortcutPreferences
    private var stateMachine: ShortcutStateMachine
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var holdWorkItem: DispatchWorkItem?
    private var doubleTapWorkItem: DispatchWorkItem?
    private var exactChordWasPressed = false

    private var isOverridingFnBehavior = false
    /// The user's AppleFnUsageType while we override it; -1 means the key was
    /// absent. Persisted so a crash cannot leave Globe permanently disabled.
    private static let fnUsageTypeBackupKey = "fnUsageTypeBackup"

    private static let holdThreshold: TimeInterval = 0.3
    private static let doubleTapWindow: TimeInterval = 0.4

    /// Physical modifier masks from IOLLEvent.h, including unsupported modifiers
    /// so an extra Shift or right Control invalidates an exact chord.
    private static let allPhysicalModifierMask: UInt64 =
        0x0080_0000  // Fn
        | 0x0000_0001  // Left Control
        | 0x0000_2000  // Right Control
        | 0x0000_0002  // Left Shift
        | 0x0000_0004  // Right Shift
        | 0x0000_0008  // Left Command
        | 0x0000_0010  // Right Command
        | 0x0000_0020  // Left Option
        | 0x0000_0040  // Right Option

    init(preferences: ShortcutPreferences) {
        self.preferences = preferences
        self.stateMachine = ShortcutStateMachine(configuration: preferences.configuration)
    }

    func start() {
        guard AXIsProcessTrusted() else { return }
        // A tap survives an Accessibility revoke/re-grant only as a dead object; rebuild it.
        if let eventTap, CGEvent.tapIsEnabled(tap: eventTap) { return }
        stop(shouldStopRecording: false)

        // Rebuilding means the old tap was dead and gesture events were likely
        // missed. Reconcile like a tap timeout: a hold whose release was lost
        // stops now, while a toggle recording stays stoppable by the next tap.
        // Never discard the state machine here — replacing it while a recording
        // is active orphans that recording from the hotkey layer.
        apply(stateMachine.cancelPendingGesture())

        if preferences.configuration.modifiers.contains(.fn) {
            disableSystemFnBehavior()
        } else if UserDefaults.standard.object(forKey: Self.fnUsageTypeBackupKey) != nil {
            // A previous run crashed before restoring Globe.
            isOverridingFnBehavior = true
            restoreSystemFnBehavior()
        }

        let eventMask =
            (CGEventMask(1) << CGEventType.flagsChanged.rawValue)
            | (CGEventMask(1) << CGEventType.keyDown.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                // The callback never modifies events, so a passive tap suffices.
                // Unlike an active tap, a slow main run loop then delays only
                // this observer, not the user's keystrokes.
                options: .listenOnly,
                eventsOfInterest: eventMask,
                callback: hotkeyEventCallback,
                userInfo: userInfo
            )
        else {
            restoreSystemFnBehavior()
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        stop(shouldStopRecording: false)
    }

    func reloadConfiguration() {
        apply(stateMachine.updateConfiguration(preferences.configuration))
        stop(shouldStopRecording: false)
        start()
    }

    /// The app stopped recording without a hotkey gesture (microphone
    /// disconnect, failed capture start). Keeps the gesture phases aligned
    /// with the recorder so the next gesture starts fresh.
    func recordingWasStopped() {
        apply(stateMachine.externalRecordingStopped())
    }

    fileprivate func handleEvent(type: CGEventType, keyCode: UInt16, flagsRawValue: UInt64) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            exactChordWasPressed = false
            apply(stateMachine.cancelPendingGesture())
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return
        }

        if type == .keyDown {
            apply(stateMachine.ordinaryKeyPressed())
            return
        }

        guard type == .flagsChanged else { return }

        let configuration = preferences.configuration
        let physicalFlags = flagsRawValue & Self.allPhysicalModifierMask
        let isExactChord = physicalFlags == configuration.deviceMask
        let changedKeyIsSelected = configuration.modifiers.contains { $0.keyCode == keyCode }

        // Only a selected key may arm the chord: releasing an extra Shift while the
        // chord is still held must not restart a recording that Shift just cancelled.
        if !exactChordWasPressed, isExactChord, changedKeyIsSelected {
            exactChordWasPressed = true
            apply(stateMachine.chordPressed())
            return
        }

        guard exactChordWasPressed, !isExactChord else {
            if !physicalFlags.isSubset(of: configuration.deviceMask) {
                apply(stateMachine.cancelPendingGesture())
            }
            return
        }

        exactChordWasPressed = false
        if changedKeyIsSelected {
            apply(stateMachine.chordReleased())
        } else {
            apply(stateMachine.cancelPendingGesture())
        }
    }

    private func stop(shouldStopRecording: Bool) {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        exactChordWasPressed = false

        if shouldStopRecording {
            apply(stateMachine.reset())
        } else {
            cancelTimers()
        }
        restoreSystemFnBehavior()
    }

    private func apply(_ effects: [ShortcutEffect]) {
        for effect in effects {
            switch effect {
            case .scheduleHold:
                scheduleHoldThreshold()
            case .cancelHold:
                holdWorkItem?.cancel()
                holdWorkItem = nil
            case .scheduleDoubleTapTimeout:
                scheduleDoubleTapTimeout()
            case .cancelDoubleTapTimeout:
                doubleTapWorkItem?.cancel()
                doubleTapWorkItem = nil
            case .startRecording:
                onRecordStart?()
            case .stopRecording:
                onRecordStop?()
            }
        }
    }

    private func scheduleHoldThreshold() {
        holdWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.holdWorkItem = nil
            self.apply(self.stateMachine.holdThresholdElapsed())
        }
        holdWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.holdThreshold, execute: workItem)
    }

    private func scheduleDoubleTapTimeout() {
        doubleTapWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.doubleTapWorkItem = nil
            self.apply(self.stateMachine.doubleTapWindowElapsed())
        }
        doubleTapWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.doubleTapWindow, execute: workItem)
    }

    private func cancelTimers() {
        holdWorkItem?.cancel()
        holdWorkItem = nil
        doubleTapWorkItem?.cancel()
        doubleTapWorkItem = nil
    }

    private func disableSystemFnBehavior() {
        guard let defaults = UserDefaults(suiteName: "com.apple.HIToolbox") else { return }
        // A backup left by a crashed run holds the user's real value; the live
        // preference is then our own override.
        if UserDefaults.standard.object(forKey: Self.fnUsageTypeBackupKey) == nil {
            let original = defaults.object(forKey: "AppleFnUsageType") as? Int ?? -1
            UserDefaults.standard.set(original, forKey: Self.fnUsageTypeBackupKey)
        }
        defaults.set(Int(FnUsageType.doNothing.rawValue), forKey: "AppleFnUsageType")
        TISUpdateFnUsageType(FnUsageType.doNothing.rawValue)
        isOverridingFnBehavior = true
    }

    private func restoreSystemFnBehavior() {
        guard isOverridingFnBehavior else { return }
        guard let defaults = UserDefaults(suiteName: "com.apple.HIToolbox") else { return }

        let original = UserDefaults.standard.object(forKey: Self.fnUsageTypeBackupKey) as? Int ?? -1
        if original >= 0 {
            defaults.set(original, forKey: "AppleFnUsageType")
            TISUpdateFnUsageType(Int32(original))
        } else {
            defaults.removeObject(forKey: "AppleFnUsageType")
            // Absent key means Globe's factory action: emoji & symbols.
            TISUpdateFnUsageType(FnUsageType.showEmojiAndSymbols.rawValue)
        }
        UserDefaults.standard.removeObject(forKey: Self.fnUsageTypeBackupKey)
        isOverridingFnBehavior = false
    }
}

private func hotkeyEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }

    let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
    let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
    let flagsRawValue = event.flags.rawValue

    DispatchQueue.main.async {
        manager.handleEvent(type: type, keyCode: keyCode, flagsRawValue: flagsRawValue)
    }

    return Unmanaged.passUnretained(event)
}

private extension UInt64 {
    func isSubset(of other: UInt64) -> Bool {
        self & ~other == 0
    }
}
