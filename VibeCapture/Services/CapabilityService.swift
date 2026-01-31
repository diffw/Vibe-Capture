import Foundation

/// Protocol for CapabilityService (enables testing/DI).
protocol CapabilityServiceProtocol {
    func canUse(_ key: CapabilityKey) -> Bool
}

/// String-based capability key (keeps adding capabilities cheap).
struct CapabilityKey: Hashable, RawRepresentable {
    let rawValue: String
    init(rawValue: String) { self.rawValue = rawValue }
}

extension CapabilityKey {
    // Capture
    static let captureArea = CapabilityKey(rawValue: "cap.capture.area")
    static let captureSave = CapabilityKey(rawValue: "cap.capture.save")
    static let captureAutosave = CapabilityKey(rawValue: "cap.capture.autosave")

    // Annotations
    static let annotationsArrow = CapabilityKey(rawValue: "cap.annotations.arrow")
    static let annotationsShapes = CapabilityKey(rawValue: "cap.annotations.shapes")
    static let annotationsNumbering = CapabilityKey(rawValue: "cap.annotations.numbering")
    static let annotationsColors = CapabilityKey(rawValue: "cap.annotations.colors")
}

/// Capability gating service.
///
/// NOTE: Until all call sites migrate, this is a read-only service.
final class CapabilityService: CapabilityServiceProtocol {
    static let shared = CapabilityService()

    enum AccessLevel {
        case free
        case pro
    }

    private let entitlements: EntitlementsServiceProtocol

    /// Capability table (from `IAP_SPEC.md`).
    static let table: [CapabilityKey: AccessLevel] = [
        .captureArea: .free,
        .captureSave: .free,
        .captureAutosave: .free,
        .annotationsArrow: .free,
        .annotationsShapes: .pro,
        .annotationsNumbering: .pro,
        .annotationsColors: .pro,
    ]

    /// Designated initializer with dependency injection support.
    /// - Parameter entitlements: EntitlementsServiceProtocol instance (defaults to shared singleton)
    init(entitlements: EntitlementsServiceProtocol = EntitlementsService.shared) {
        self.entitlements = entitlements
    }

    func canUse(_ key: CapabilityKey) -> Bool {
        guard let access = Self.table[key] else {
            // Default deny for unspecified capabilities (TBD in spec).
            return false
        }
        switch access {
        case .free: return true
        case .pro: return entitlements.isPro
        }
    }
}

