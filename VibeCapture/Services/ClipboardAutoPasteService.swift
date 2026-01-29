import AppKit
import ApplicationServices

extension Notification.Name {
    static let clipboardAutoPasteArmed = Notification.Name("ClipboardAutoPasteArmed")
    static let clipboardAutoPasteTriggered = Notification.Name("ClipboardAutoPasteTriggered")
    static let clipboardAutoPasteDisarmed = Notification.Name("ClipboardAutoPasteDisarmed")
}

/// Implements "Copy & Arm (next ⌘V)" for apps that don't reliably paste image+text together.
///
/// Strategy (per design doc):
/// - Arm: snapshot clipboard -> write text-only -> listen for ONE user ⌘V (global)
/// - Trigger: when user presses ⌘V once, disarm immediately, then auto-paste images:
///   write image-only -> inject ⌘V -> repeat
/// - Finish: optionally restore the original clipboard
final class ClipboardAutoPasteService {
    static let shared = ClipboardAutoPasteService()

    /// Check if we have Accessibility permission (required for simulating keystrokes)
    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    var armTimeoutSeconds: TimeInterval {
        core.config.armTimeoutSeconds
    }
    
    private var core = ClipboardAutoPasteCore()
    private var debounceWindowSeconds: TimeInterval = 0.65

    private var preparedImagesPNG: [Data] = []
    private var preparedTextTrimmed: String = ""
    private var clipboardSnapshot: PasteboardSnapshot?
    // Global key monitoring (CGEventTap is more reliable than NSEvent global monitor in sandbox)
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var sawVKeyDownWithCmd: Bool = false
    private let injectedEventMarker: Int64 = 0x56494245 // "VIBE" - used to tag injected CGEvents

    private var lastTriggerTime: CFAbsoluteTime = 0
    private var scheduledWorkItems: [DispatchWorkItem] = []
    private var sequenceToken: UInt64 = 0
    private var armStartedAt: CFAbsoluteTime?

    private init() {}

    func updateConfig(_ update: (inout ClipboardAutoPasteCore.Config) -> Void) {
        update(&core.config)
    }
    
    func updateDebounceWindowSeconds(_ seconds: TimeInterval) {
        debounceWindowSeconds = seconds
    }

    /// Prepare a payload. Images are converted to PNG eagerly (best-effort).
    func prepare(text: String, images: [NSImage]) {
        preparedImagesPNG = images.compactMap { $0.pngData() }
        preparedTextTrimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        core.prepare(text: text, imageCount: preparedImagesPNG.count)
    }

    func arm() {
        guard hasAccessibilityPermission else {
            requestAccessibilityPermission()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                PermissionsUI.openAccessibilitySettings()
            }
            return
        }

        disarm(reason: "Re-arm")
        sequenceToken &+= 1
        armStartedAt = CFAbsoluteTimeGetCurrent()
        NotificationCenter.default.post(
            name: .clipboardAutoPasteArmed,
            object: self,
            userInfo: ["timeoutSeconds": core.config.armTimeoutSeconds]
        )
        execute(core.arm(), token: sequenceToken)
    }

    func disarm(reason: String) {
        sequenceToken &+= 1
        cancelScheduledWork()
        execute(core.disarm(), token: sequenceToken)
        NotificationCenter.default.post(name: .clipboardAutoPasteDisarmed, object: self)
    }

    // MARK: - Accessibility

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Clipboard

    private func writeTextOnlyToClipboard(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(trimmed, forType: .string)
    }

    private func writeImageOnlyToClipboard(pngData: Data) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(pngData, forType: .png)
    }

    private func restoreClipboardIfNeeded() {
        guard core.config.restoreClipboardAfter else { return }
        guard let snapshot = clipboardSnapshot else { return }
        snapshot.restore(into: .general)
        clipboardSnapshot = nil
    }

    // MARK: - Monitoring & Trigger

    private func startGlobalMonitorIfNeeded() {
        guard eventTap == nil else { return }
        sawVKeyDownWithCmd = false

        let mask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        // Default tap so we can (optionally) swallow user's ⌘V while armed.
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, cgEvent, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(cgEvent) }
                let svc = Unmanaged<ClipboardAutoPasteService>.fromOpaque(userInfo).takeUnretainedValue()
                return svc.handleGlobalCGEventAndMaybeSwallow(type, cgEvent)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap else {
            return
        }

        eventTap = tap
        eventTapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source = eventTapSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func stopGlobalMonitorIfNeeded() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = eventTapSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            eventTapSource = nil
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
    }

    private func handleGlobalCGEventAndMaybeSwallow(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        // Ignore our own injected events so we don't swallow them.
        let marker = event.getIntegerValueField(.eventSourceUserData)
        if marker == injectedEventMarker {
            return Unmanaged.passUnretained(event)
        }

        guard core.state == .armed else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        let hasCmd = flags.contains(.maskCommand)

        // Track whether this ⌘V combo occurred even if cmd is released before keyUp.
        if type == .keyDown, keyCode == 9, hasCmd {
            sawVKeyDownWithCmd = true
        }
        if type == .flagsChanged, !hasCmd {
            // Command released; keep sawVKeyDownWithCmd as-is until next non-V keyDown resets it.
        }

        // We allow user's real ⌘V to proceed for text paste reliability.
        // Then we run core.userPasteDetected() to schedule image pastes after a settling delay.
        guard (type == .keyDown || type == .keyUp), keyCode == 9 else { return Unmanaged.passUnretained(event) }
        guard hasCmd || sawVKeyDownWithCmd else { return Unmanaged.passUnretained(event) }

        // Debounce to avoid injection loop / accidental double triggers
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastTriggerTime < debounceWindowSeconds { return Unmanaged.passUnretained(event) }
        lastTriggerTime = now

        sawVKeyDownWithCmd = false

        // IMPORTANT:
        // Avoid tearing down the event tap inside its callback. Defer side-effects to main-async.
        let token = sequenceToken
        let effects = core.userPasteDetected()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.execute(effects, token: token)
        }
        NotificationCenter.default.post(name: .clipboardAutoPasteTriggered, object: self)
        return Unmanaged.passUnretained(event)
    }

    // MARK: - Effect runner

    private func execute(_ effects: [ClipboardAutoPasteEffect], token: UInt64) {
        for effect in effects {
            switch effect {
            case .captureClipboard:
                clipboardSnapshot = PasteboardSnapshot.capture(from: .general)

            case .writeTextOnly(let text):
                writeTextOnlyToClipboard(text)

            case .startMonitoring:
                startGlobalMonitorIfNeeded()

            case .stopMonitoring:
                stopGlobalMonitorIfNeeded()

            case .startTimeout(let seconds):
                schedule(after: seconds, token: token) { [weak self] in
                    guard let self else { return }
                    self.execute(self.core.timeoutFired(), token: token)
                }

            case .cancelTimeout:
                // Timeout cancellation handled by token + cancelScheduledWork
                break

            case .writeImageOnly(let index):
                if index >= 0, index < preparedImagesPNG.count {
                    writeImageOnlyToClipboard(pngData: preparedImagesPNG[index])
                }

            case .simulatePaste:
                simulatePaste()

            case .scheduleNextPaste(let delay):
                schedule(after: delay, token: token) { [weak self] in
                    guard let self else { return }
                    self.execute(self.core.autoPasteTick(), token: token)
                }

            case .scheduleRestoreClipboard(let delay):
                schedule(after: delay, token: token) { [weak self] in
                    guard let self else { return }
                    self.restoreClipboardIfNeeded()
                }

            case .restoreClipboard:
                restoreClipboardIfNeeded()
            }
        }
    }

    private func schedule(after delay: TimeInterval, token: UInt64, _ block: @escaping () -> Void) {
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.sequenceToken == token else { return }
            block()
        }
        scheduledWorkItems.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func cancelScheduledWork() {
        for item in scheduledWorkItems {
            item.cancel()
        }
        scheduledWorkItems.removeAll()
    }

    private func simulatePaste() {
        simulateKeyCombo(keyCode: 9, modifiers: .maskCommand)  // V = 9
    }

    private func simulateKeyCombo(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else { return }
        keyDown.flags = modifiers
        keyDown.setIntegerValueField(.eventSourceUserData, value: injectedEventMarker)
        keyDown.post(tap: .cghidEventTap)

        guard let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else { return }
        keyUp.flags = modifiers
        keyUp.setIntegerValueField(.eventSourceUserData, value: injectedEventMarker)
        keyUp.post(tap: .cghidEventTap)
    }
}

// MARK: - Pasteboard snapshot

private struct PasteboardSnapshot {
    struct Item {
        var dataByType: [NSPasteboard.PasteboardType: Data]
    }

    var items: [Item]

    static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot? {
        guard let pbItems = pasteboard.pasteboardItems, !pbItems.isEmpty else { return nil }

        let items: [Item] = pbItems.map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return Item(dataByType: dict)
        }
        return PasteboardSnapshot(items: items)
    }

    func restore(into pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let restored: [NSPasteboardItem] = items.map { item in
            let pbItem = NSPasteboardItem()
            for (type, data) in item.dataByType {
                pbItem.setData(data, forType: type)
            }
            return pbItem
        }
        _ = pasteboard.writeObjects(restored)
    }
}

