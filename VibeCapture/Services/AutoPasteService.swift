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

        // Step 3: Wait for app to come to front, then paste image
        DispatchQueue.main.asyncAfter(deadline: .now() + timing.activationDelay) {
            self.simulatePaste()

            // Step 4: If there's text, wait and paste it too
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
    
    /// Timing configuration for different apps
    private struct PasteTiming {
        let activationDelay: Double  // Delay after activating app before pasting image
        let textPasteDelay: Double   // Delay after pasting image before pasting text
    }
    
    /// Get appropriate timing for different apps
    /// Some apps (like Figma, browsers) need longer delays due to their architecture
    private func getTimingForApp(_ app: TargetApp) -> PasteTiming {
        switch app.bundleIdentifier {
        case "com.figma.Desktop":
            // Figma is an Electron app and needs longer delays
            return PasteTiming(activationDelay: 0.3, textPasteDelay: 0.5)
        case "com.anthropic.claudefordesktop":
            // Claude desktop app might also need slightly longer delays
            return PasteTiming(activationDelay: 0.2, textPasteDelay: 0.35)
        case "com.google.Chrome", "com.apple.Safari", "com.microsoft.edgemac", "company.thebrowser.Browser":
            // Browsers need longer delays for web apps (ChatGPT, Gemini, etc.)
            return PasteTiming(activationDelay: 0.25, textPasteDelay: 0.4)
        default:
            // Default timing for most apps (Cursor, VS Code, Telegram)
            return PasteTiming(activationDelay: 0.15, textPasteDelay: 0.25)
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
        // Key codes: V = 9, Command = 55
        let vKeyCode: CGKeyCode = 9

        // Create key down event for ⌘+V
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: true) else { return }
        keyDown.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)

        // Create key up event
        guard let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: false) else { return }
        keyUp.flags = .maskCommand
        keyUp.post(tap: .cghidEventTap)
    }
}
