import AppKit
import Carbon.HIToolbox

@MainActor
enum TextInserter {

    /// Insert text into the currently focused text field by simulating Cmd+V.
    /// Saves and restores the clipboard content around the paste.
    static func insertText(_ text: String) {
        let pasteboard = NSPasteboard.general

        // 1. Save current clipboard contents (all types)
        let savedItems = savePasteboard(pasteboard)

        // 2. Set our text on the clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 3. Simulate Cmd+V
        simulatePaste()

        // 4. Restore clipboard after a delay to let the paste complete
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            pasteboard.clearContents()
            if !savedItems.isEmpty {
                pasteboard.writeObjects(savedItems)
            }
        }
    }

    // MARK: - Private

    private static func savePasteboard(_ pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        guard let items = pasteboard.pasteboardItems else { return [] }

        return items.compactMap { item in
            let newItem = NSPasteboardItem()
            var hasData = false
            for type in item.types {
                if let data = item.data(forType: type) {
                    newItem.setData(data, forType: type)
                    hasData = true
                }
            }
            return hasData ? newItem : nil
        }
    }

    private static func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        // V key = keyCode 0x09 (kVK_ANSI_V)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: UInt16(kVK_ANSI_V), keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: UInt16(kVK_ANSI_V), keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
