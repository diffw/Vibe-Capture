import AppKit

final class PromptTextView: NSTextView {
    var onCommandEnter: (() -> Void)?
    var onTypingStarted: (() -> Void)?
    
    // MARK: - Debug Logging
    
    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[PromptTextView \(timestamp)] \(message)")
    }
    
    // MARK: - First Responder
    
    override var acceptsFirstResponder: Bool {
        let accepts = super.acceptsFirstResponder
        log("acceptsFirstResponder called, returning: \(accepts), isEditable: \(isEditable), isSelectable: \(isSelectable)")
        return accepts
    }
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        log("becomeFirstResponder called, result: \(result)")
        return result
    }
    
    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        log("resignFirstResponder called, result: \(result)")
        return result
    }
    
    override func mouseDown(with event: NSEvent) {
        log("mouseDown - clickCount: \(event.clickCount), window.firstResponder: \(String(describing: window?.firstResponder))")
        super.mouseDown(with: event)
        log("mouseDown after super - window.firstResponder: \(String(describing: window?.firstResponder))")
    }

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


