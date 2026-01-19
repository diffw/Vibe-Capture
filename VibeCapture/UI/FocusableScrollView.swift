import AppKit

/// A scroll view that ensures its documentView (typically NSTextView) becomes first responder when clicked
final class FocusableScrollView: NSScrollView {
    
    override func mouseDown(with event: NSEvent) {
        print("[FocusableScrollView] mouseDown - documentView: \(String(describing: documentView)), window: \(String(describing: window))")
        
        // Make the document view first responder when clicking anywhere in the scroll view
        if let documentView = documentView {
            let beforeResponder = window?.firstResponder
            let result = window?.makeFirstResponder(documentView)
            let afterResponder = window?.firstResponder
            print("[FocusableScrollView] makeFirstResponder result: \(String(describing: result)), before: \(String(describing: beforeResponder)), after: \(String(describing: afterResponder))")
        }
        super.mouseDown(with: event)
    }
}
