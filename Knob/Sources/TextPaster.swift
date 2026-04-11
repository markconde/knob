import Cocoa

@MainActor
enum TextPaster {
    /// A paste session snapshots the clipboard at creation time and restores
    /// it once `finish()` is called. Intermediate `paste(_:)` calls do not
    /// touch the saved clipboard, so multiple chunks can be pasted during a
    /// single dictation without losing the user's original clipboard.
    @MainActor
    final class Session {
        private let pasteboard = NSPasteboard.general
        private let savedContents: String?

        init() {
            self.savedContents = pasteboard.string(forType: .string)
        }

        func paste(_ text: String) {
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            Self.postCmdV()
        }

        /// Restores the saved clipboard contents after a short delay to let
        /// the last synthetic Cmd+V be consumed by the frontmost app.
        func finish() {
            let saved = savedContents
            let pb = pasteboard
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(200))
                pb.clearContents()
                if let saved {
                    pb.setString(saved, forType: .string)
                }
            }
        }

        private static func postCmdV() {
            let vKeyCode: CGKeyCode = 0x09
            let source = CGEventSource(stateID: .hidSystemState)

            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
               let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) {
                keyDown.flags = .maskCommand
                keyUp.flags = .maskCommand
                keyDown.post(tap: .cgAnnotatedSessionEventTap)
                keyUp.post(tap: .cgAnnotatedSessionEventTap)
            }
        }
    }

    static func beginSession() -> Session { Session() }
}
