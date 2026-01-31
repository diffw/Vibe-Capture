import Foundation

enum ClipboardAutoPasteEffect: Equatable {
    case captureClipboard
    case writeTextOnly(String)
    case startMonitoring
    case stopMonitoring
    case startTimeout(TimeInterval)
    case cancelTimeout

    case writeImageOnly(index: Int)
    case simulatePaste
    case scheduleNextPaste(after: TimeInterval)
    case scheduleRestoreClipboard(after: TimeInterval)
    case restoreClipboard
}

struct ClipboardAutoPasteCore: Equatable {
    struct Config: Equatable {
        var delayBetweenPastes: TimeInterval = 0.25
        var armTimeoutSeconds: TimeInterval = 10
        var restoreClipboardAfter: Bool = true
        /// Delay after the user's first ⌘V before we overwrite the clipboard with image-only.
        /// This prevents racing the user's paste handler (which could otherwise paste image instead of text).
        var userPasteSettlingDelay: TimeInterval = 0.25
    }

    enum State: Equatable {
        case idle
        case armed
        case autoPasting(nextIndex: Int)
    }

    var config = Config()
    private(set) var state: State = .idle

    private var preparedText: String = ""
    private var preparedImageCount: Int = 0

    // Debug-only visibility for logging (do not include actual text).
    var debugPreparedTextLen: Int { preparedText.count }

    mutating func prepare(text: String, imageCount: Int) {
        preparedText = text
        preparedImageCount = imageCount
    }

    mutating func arm() -> [ClipboardAutoPasteEffect] {
        state = .armed
        var effects: [ClipboardAutoPasteEffect] = [
            .captureClipboard,
            .writeTextOnly(preparedText),
            .startMonitoring,
            .startTimeout(config.armTimeoutSeconds),
        ]
        if config.restoreClipboardAfter == false {
            // Still captureClipboard for potential future; but core doesn't require it.
        }
        return effects
    }

    mutating func disarm() -> [ClipboardAutoPasteEffect] {
        state = .idle
        var effects: [ClipboardAutoPasteEffect] = [
            .stopMonitoring,
            .cancelTimeout,
        ]
        if config.restoreClipboardAfter {
            effects.append(.restoreClipboard)
        }
        return effects
    }

    mutating func timeoutFired() -> [ClipboardAutoPasteEffect] {
        guard state == .armed else { return [] }
        return disarm()
    }

    mutating func userPasteDetected() -> [ClipboardAutoPasteEffect] {
        guard state == .armed else { return [] }

        // Single-consume
        var effects: [ClipboardAutoPasteEffect] = [
            .stopMonitoring,
            .cancelTimeout,
        ]

        guard preparedImageCount > 0 else {
            state = .idle
            if config.restoreClipboardAfter {
                effects.append(.restoreClipboard)
            }
            return effects
        }

        // IMPORTANT:
        // We must not overwrite the clipboard with image-only immediately on keyDown detection.
        // Otherwise the user's first ⌘V may paste an image (not text), and then our injected ⌘V
        // pastes the same image again (double paste). Instead, wait briefly for the user's paste
        // handler to consume the text-only clipboard, then begin auto-pasting images.
        state = .autoPasting(nextIndex: 0)
        effects.append(.scheduleNextPaste(after: config.userPasteSettlingDelay))
        return effects
    }

    mutating func autoPasteTick() -> [ClipboardAutoPasteEffect] {
        guard case .autoPasting = state else { return [] }
        return autoPasteCurrentAndScheduleNext()
    }

    private mutating func autoPasteCurrentAndScheduleNext() -> [ClipboardAutoPasteEffect] {
        guard case let .autoPasting(nextIndex) = state else { return [] }
        guard nextIndex < preparedImageCount else {
            return finishAutoPaste()
        }

        var effects: [ClipboardAutoPasteEffect] = [
            .writeImageOnly(index: nextIndex),
            .simulatePaste,
        ]

        let upcoming = nextIndex + 1
        if upcoming < preparedImageCount {
            state = .autoPasting(nextIndex: upcoming)
            effects.append(.scheduleNextPaste(after: config.delayBetweenPastes))
        } else {
            state = .idle
            effects.append(contentsOf: finishAutoPaste())
        }

        return effects
    }

    private func finishAutoPaste() -> [ClipboardAutoPasteEffect] {
        guard config.restoreClipboardAfter else { return [] }
        let restoreDelay = max(0.1, config.delayBetweenPastes)
        return [.scheduleRestoreClipboard(after: restoreDelay)]
    }
}

