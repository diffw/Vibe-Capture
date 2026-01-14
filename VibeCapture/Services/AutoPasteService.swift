import AppKit
import Carbon.HIToolbox

/// Service that automates pasting image + text to Cursor by:
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

    /// Paste image and text to Cursor automatically
    /// - Parameters:
    ///   - image: The screenshot image
    ///   - text: The prompt text
    ///   - completion: Called when done, with success/failure
    func pasteToСursor(image: NSImage, text: String, completion: @escaping (Bool, String?) -> Void) {
        // Check Accessibility permission first
        guard hasAccessibilityPermission else {
            requestAccessibilityPermission()
            completion(false, "Accessibility permission required. Please grant it in System Settings → Privacy & Security → Accessibility, then try again.")
            return
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Step 1: Put image in clipboard
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([image])

        // Step 2: Activate Cursor
        guard activateCursor() else {
            completion(false, "Could not find Cursor. Is it running?")
            return
        }

        // Step 3: Wait for Cursor to come to front, then paste image
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.simulatePaste()

            // Step 4: If there's text, wait and paste it too
            if !trimmedText.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
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

    /// Activate Cursor application
    private func activateCursor() -> Bool {
        // Try to find Cursor by bundle identifier
        let cursorBundleIDs = [
            "com.todesktop.230313mzl4w4u92",  // Cursor's known bundle ID
            "com.cursor.Cursor"                // Alternative
        ]

        for bundleID in cursorBundleIDs {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
                app.activate(options: [.activateIgnoringOtherApps])
                return true
            }
        }

        // Fallback: try to find by name
        let workspace = NSWorkspace.shared
        let apps = workspace.runningApplications
        if let cursor = apps.first(where: { $0.localizedName == "Cursor" }) {
            cursor.activate(options: [.activateIgnoringOtherApps])
            return true
        }

        return false
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
