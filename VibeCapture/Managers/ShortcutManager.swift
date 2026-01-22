import AppKit
import Carbon.HIToolbox

final class ShortcutManager {
    static let shared = ShortcutManager()

    var onHotKey: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private let hotKeyID = EventHotKeyID(signature: 0x56424350 /* 'VBCP' */, id: 1)

    private init() {}

    func start() {
        installHandlerIfNeeded()
        registerFromSettings()
    }

    func updateHotKey(_ combo: KeyCombo) throws {
        let previous = SettingsStore.shared.captureHotKey
        do {
            try register(combo)
            SettingsStore.shared.captureHotKey = combo
        } catch {
            // Best effort: restore previous hotkey registration.
            _ = try? register(previous)
            throw error
        }
    }

    private func registerFromSettings() {
        _ = try? register(SettingsStore.shared.captureHotKey)
    }

    private func installHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let userData = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData in
                guard let userData else { return noErr }
                let manager = Unmanaged<ShortcutManager>.fromOpaque(userData).takeUnretainedValue()

                var hotKeyID = EventHotKeyID()
                let err = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                if err == noErr, hotKeyID.signature == manager.hotKeyID.signature, hotKeyID.id == manager.hotKeyID.id {
                    DispatchQueue.main.async {
                        manager.onHotKey?()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            userData,
            &eventHandlerRef
        )

        if status != noErr {
            // If this fails, hotkeys won't work; we keep app functional otherwise.
            eventHandlerRef = nil
        }
    }

    private func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    private func register(_ combo: KeyCombo) throws {
        unregister()

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(combo.keyCode),
            combo.carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &ref
        )

        guard status == noErr else {
            throw ShortcutError.registrationFailed(status: status)
        }

        hotKeyRef = ref
    }
}

enum ShortcutError: LocalizedError {
    case registrationFailed(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .registrationFailed(let status):
            // Common: -9879 (eventHotKeyExistsErr)
            return L("error.shortcut_registration_failed", status)
        }
    }
}



