import AppKit

final class PromptTextView: NSTextView {
    var onCommandEnter: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        // ⌘ + Enter triggers copy (and should NOT insert a newline).
        if event.modifierFlags.contains(.command), (event.keyCode == 36 /* Return */ || event.keyCode == 76 /* Keypad Enter */) {
            onCommandEnter?()
            return
        }
        super.keyDown(with: event)
    }
}


