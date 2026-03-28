import AppKit
import Carbon.HIToolbox

// MARK: - Hotkey Manager

/// Manages the Fn (Globe) key for dictation:
/// - **Double-press Fn**: Hands-free mode (recording starts, press Fn again to stop + transcribe)
/// - **Hold Fn**: Hold-to-talk (release to stop + transcribe)
///
/// Uses a CGEvent tap to intercept Fn before macOS shows the emoji picker.
@MainActor
class HotkeyManager {
    var onRecordStart: (() -> Void)?
    var onRecordStop: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Keep the state object alive for the C callback
    private var stateRef: AnyObject?

    /// Saved original Fn key usage type so we can restore on quit
    private var originalFnUsageType: Int?

    func start() {
        guard AXIsProcessTrusted() else { return }
        stop()

        // Disable the system Globe key behavior (emoji picker / input switching)
        // by setting AppleFnUsageType to 0 ("Do Nothing"). We restore on stop().
        disableSystemFnBehavior()

        let state = FnKeyState()
        state.manager = self
        stateRef = state

        let userInfo = Unmanaged.passUnretained(state).toOpaque()

        // Listen for flagsChanged events (modifier key presses, which includes Fn)
        let eventMask: CGEventMask = 1 << CGEventType.flagsChanged.rawValue

        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: eventMask,
                callback: fnEventCallback,
                userInfo: userInfo
            )
        else {
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        stateRef = nil

        restoreSystemFnBehavior()
    }

    // MARK: - System Fn Key Override

    /// Disable macOS Globe key system action by writing AppleFnUsageType = 0
    private func disableSystemFnBehavior() {
        let defaults = UserDefaults(suiteName: "com.apple.HIToolbox")
        originalFnUsageType = defaults?.integer(forKey: "AppleFnUsageType")
        defaults?.set(0, forKey: "AppleFnUsageType")
    }

    /// Restore the user's original Globe key behavior
    private func restoreSystemFnBehavior() {
        guard let original = originalFnUsageType else { return }
        let defaults = UserDefaults(suiteName: "com.apple.HIToolbox")
        defaults?.set(original, forKey: "AppleFnUsageType")
        originalFnUsageType = nil
    }

    func cancelRecording() {
        if let state = stateRef as? FnKeyState {
            state.phase = .idle
        }
    }
}

// MARK: - State Machine

/// Fn key detection phases:
/// ```
/// idle → fnDown:
///   start holdTimer (300ms)
///   → if held past timer → holdRecording → fnUp → stop + transcribe → idle
///   → if released quickly → waitingForDoubleTap (400ms window)
///       → fnDown within window → handsFreeRecording → fnDown → stop + transcribe → idle
///       → timeout → idle (single tap, ignored)
/// ```
private enum FnPhase {
    case idle
    case fnDownPending          // Fn pressed, waiting to see if it's a hold or first tap
    case waitingForDoubleTap    // First quick tap done, waiting for second tap
    case holdRecording          // Holding Fn, recording in progress
    case handsFreeRecording     // Double-tapped, recording until next Fn press
}

private class FnKeyState: @unchecked Sendable {
    var phase: FnPhase = .idle
    var fnDownTime: CFAbsoluteTime = 0
    var holdTimer: DispatchWorkItem?
    var doubleTapTimer: DispatchWorkItem?
    weak var manager: HotkeyManager?

    /// How long Fn must be held before hold-to-talk activates
    let holdThreshold: TimeInterval = 0.3
    /// Window to detect second tap of double-tap
    let doubleTapWindow: TimeInterval = 0.4
}

// MARK: - CGEvent Callback (C-function, runs on event tap thread)

private func fnEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // Re-enable if macOS disabled the tap
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        // We can't access the tap ref here easily, but it auto-re-enables in practice
        return Unmanaged.passUnretained(event)
    }

    guard type == .flagsChanged, let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let state = Unmanaged<FnKeyState>.fromOpaque(userInfo).takeUnretainedValue()

    // Check if the Fn (Globe / SecondaryFn) flag changed
    // NX_SECONDARYFN = 0x800000 in IOKit
    let fnFlag: UInt64 = 0x800000
    let fnPressed = (event.flags.rawValue & fnFlag) != 0

    // Ignore if other modifiers are held (Cmd, Opt, Shift, Ctrl)
    let otherModifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskShift, .maskControl]
    let hasOtherModifiers = !event.flags.intersection(otherModifiers).isEmpty
    if hasOtherModifiers {
        return Unmanaged.passUnretained(event)
    }

    DispatchQueue.main.async {
        handleFnStateChange(state: state, fnPressed: fnPressed)
    }

    // Suppress ALL Fn events unconditionally to prevent macOS from showing
    // the emoji picker, keyboard switcher, or dictation panel.
    // Our app owns the Fn key entirely while running.
    return nil
}

@MainActor
private func handleFnStateChange(state: FnKeyState, fnPressed: Bool) {
    switch state.phase {

    case .idle:
        if fnPressed {
            state.phase = .fnDownPending
            state.fnDownTime = CFAbsoluteTimeGetCurrent()

            // Start hold timer
            state.holdTimer?.cancel()
            let holdWork = DispatchWorkItem { [weak state] in
                guard let state, state.phase == .fnDownPending else { return }
                // Held long enough → hold-to-talk
                state.phase = .holdRecording
                state.manager?.onRecordStart?()
            }
            state.holdTimer = holdWork
            DispatchQueue.main.asyncAfter(
                deadline: .now() + state.holdThreshold, execute: holdWork)
        }

    case .fnDownPending:
        if !fnPressed {
            // Released quickly → could be first tap of double-tap
            state.holdTimer?.cancel()
            state.holdTimer = nil
            state.phase = .waitingForDoubleTap

            // Start double-tap window timer
            state.doubleTapTimer?.cancel()
            let dtWork = DispatchWorkItem { [weak state] in
                guard let state, state.phase == .waitingForDoubleTap else { return }
                // Timeout: was just a single tap → do nothing
                state.phase = .idle
            }
            state.doubleTapTimer = dtWork
            DispatchQueue.main.asyncAfter(
                deadline: .now() + state.doubleTapWindow, execute: dtWork)
        }

    case .waitingForDoubleTap:
        if fnPressed {
            // Second tap! → hands-free recording
            state.doubleTapTimer?.cancel()
            state.doubleTapTimer = nil
            state.phase = .handsFreeRecording
            state.manager?.onRecordStart?()
        }

    case .holdRecording:
        if !fnPressed {
            // Released → stop recording + transcribe
            state.phase = .idle
            state.manager?.onRecordStop?()
        }

    case .handsFreeRecording:
        if fnPressed {
            // Next Fn press → stop recording + transcribe
            state.phase = .idle
            state.manager?.onRecordStop?()
        }
    }
}
