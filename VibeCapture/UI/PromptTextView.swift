import AppKit

final class PromptTextView: NSTextView {
    var onCommandEnter: (() -> Void)?
    var onTypingStarted: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        // ⌘ + Enter triggers copy (and should NOT insert a newline).
        if event.modifierFlags.contains(.command), (event.keyCode == 36 /* Return */ || event.keyCode == 76 /* Keypad Enter */) {
            onCommandEnter?()
            return
        }
        
        // Notify that typing has started (for hiding placeholder immediately)
        // Exclude modifier-only keys and navigation keys
        let keyCode = event.keyCode
        let isModifierOnly = event.modifierFlags.intersection([.command, .control, .option]).isEmpty == false && event.characters?.isEmpty ?? true
        let isNavigationKey = [123, 124, 125, 126, 115, 116, 119, 121].contains(Int(keyCode)) // arrows, home, end, etc.
        
        if !isModifierOnly && !isNavigationKey {
            onTypingStarted?()
        }
        
        super.keyDown(with: event)
    }
}


