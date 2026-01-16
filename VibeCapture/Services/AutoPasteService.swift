import AppKit
import Carbon.HIToolbox

/// Service that automates pasting image + text to target applications by:
/// 1. Putting image in clipboard → simulating ⌘+V
/// 2. Putting text in clipboard → simulating ⌘+V
final class AutoPasteService {
    static let shared = AutoPasteService()
    private init() {}

    /// Check if we have Accessibility permission (required for simulating keystrokes)
    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Request Accessibility permission (opens System Preferences)
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Paste image and text to a target app automatically
    /// - Parameters:
    ///   - image: The screenshot image
    ///   - text: The prompt text
    ///   - targetApp: The target application to paste to
    ///   - completion: Called when done, with success/failure
    func pasteToApp(image: NSImage, text: String, targetApp: TargetApp, completion: @escaping (Bool, String?) -> Void) {
        // Check Accessibility permission first
        guard hasAccessibilityPermission else {
            requestAccessibilityPermission()
            completion(false, "Accessibility permission required. Please grant it in System Settings → Privacy & Security → Accessibility, then try again.")
            return
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Get timing configuration based on target app
        let timing = getTimingForApp(targetApp)

        // Step 1: Put image in clipboard
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([image])

        // Step 2: Activate target app
        guard AppDetectionService.shared.activate(targetApp) else {
            completion(false, "Could not find \(targetApp.displayName). Is it running?")
            return
        }

        // Step 3: Wait for app to come to front
        DispatchQueue.main.asyncAfter(deadline: .now() + timing.activationDelay) {
            
            // Step 3.5: Send focus shortcut if configured (e.g., ⌘+L for Cursor)
            if let focusShortcut = timing.focusShortcut {
                self.simulateKeyCombo(keyCode: focusShortcut.keyCode, modifiers: focusShortcut.modifiers)
            }
            
            // Step 4: Wait for focus, then paste image
            DispatchQueue.main.asyncAfter(deadline: .now() + timing.focusDelay) {
                self.simulatePaste()

                // Step 5: If there's text, wait and paste it too
                if !trimmedText.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + timing.textPasteDelay) {
                        // Put text in clipboard
                        pb.clearContents()
                        pb.writeObjects([trimmedText as NSString])

                        // Paste text
                        self.simulatePaste()

                        completion(true, nil)
                    }
                } else {
                    completion(true, nil)
                }
            }
        }
    }
    
    /// Timing and focus configuration for different apps
    private struct PasteTiming {
        let activationDelay: Double  // Delay after activating app before focus shortcut
        let focusShortcut: FocusShortcut?  // Optional shortcut to focus input field
        let focusDelay: Double       // Delay after focus shortcut before pasting
        let textPasteDelay: Double   // Delay after pasting image before pasting text
    }
    
    /// Focus shortcut configuration
    private struct FocusShortcut {
        let keyCode: CGKeyCode
        let modifiers: CGEventFlags
    }
    
    /// Common key codes
    private enum KeyCode {
        static let l: CGKeyCode = 37  // L key
        static let i: CGKeyCode = 34  // I key
        static let k: CGKeyCode = 40  // K key
    }
    
    /// Get appropriate timing and focus shortcut for different apps
    /// Electron apps (Cursor, VS Code, Claude) need focus shortcuts to ensure input field is active
    private func getTimingForApp(_ app: TargetApp) -> PasteTiming {
        switch app.bundleIdentifier {
        case "com.todesktop.230313mzl4w4u92", "com.cursor.Cursor":
            // Cursor: ⌘+L focuses Composer (verified by user)
            return PasteTiming(
                activationDelay: 0.15,
                focusShortcut: FocusShortcut(keyCode: KeyCode.l, modifiers: .maskCommand),
                focusDelay: 0.1,
                textPasteDelay: 0.25
            )
        case "com.microsoft.VSCode":
            // VS Code: ⌘+L focuses Copilot Chat (if installed)
            // If user doesn't have Copilot, this might open "Go to Line" - acceptable fallback
            return PasteTiming(
                activationDelay: 0.15,
                focusShortcut: FocusShortcut(keyCode: KeyCode.l, modifiers: .maskCommand),
                focusDelay: 0.1,
                textPasteDelay: 0.25
            )
        case "com.anthropic.claudefordesktop":
            // Claude: No known focus shortcut, rely on longer delays
            return PasteTiming(
                activationDelay: 0.2,
                focusShortcut: nil,
                focusDelay: 0.0,
                textPasteDelay: 0.35
            )
        case "com.figma.Desktop":
            // Figma: ⌘+L opens "Figma AI" / Make input (if available)
            return PasteTiming(
                activationDelay: 0.3,
                focusShortcut: FocusShortcut(keyCode: KeyCode.l, modifiers: .maskCommand),
                focusDelay: 0.15,
                textPasteDelay: 0.5
            )
        case "com.google.Chrome", "com.apple.Safari", "com.microsoft.edgemac", "company.thebrowser.Browser":
            // Browsers: No universal focus shortcut, rely on user pre-positioning
            return PasteTiming(
                activationDelay: 0.25,
                focusShortcut: nil,
                focusDelay: 0.0,
                textPasteDelay: 0.4
            )
        default:
            // Default: Native apps (Telegram, etc.) usually maintain focus well
            return PasteTiming(
                activationDelay: 0.15,
                focusShortcut: nil,
                focusDelay: 0.0,
                textPasteDelay: 0.25
            )
        }
    }

    /// Legacy method for backward compatibility - paste to Cursor
    func pasteToCursor(image: NSImage, text: String, completion: @escaping (Bool, String?) -> Void) {
        // Create a Cursor target app
        let cursorApp = TargetApp(
            bundleIdentifier: "com.todesktop.230313mzl4w4u92",
            displayName: "Cursor",
            icon: nil,
            runningApp: NSRunningApplication.runningApplications(withBundleIdentifier: "com.todesktop.230313mzl4w4u92").first
                ?? NSRunningApplication.runningApplications(withBundleIdentifier: "com.cursor.Cursor").first
        )
        
        pasteToApp(image: image, text: text, targetApp: cursorApp, completion: completion)
    }

    /// Simulate ⌘+V keystroke
    private func simulatePaste() {
        simulateKeyCombo(keyCode: 9, modifiers: .maskCommand)  // V = 9
    }
    
    /// Simulate any key combination
    /// - Parameters:
    ///   - keyCode: The virtual key code
    ///   - modifiers: The modifier flags (Command, Shift, etc.)
    private func simulateKeyCombo(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        // Create key down event
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else { return }
        keyDown.flags = modifiers
        keyDown.post(tap: .cghidEventTap)

        // Create key up event
        guard let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else { return }
        keyUp.flags = modifiers
        keyUp.post(tap: .cghidEventTap)
    }
}
