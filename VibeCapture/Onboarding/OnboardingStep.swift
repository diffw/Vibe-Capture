import Foundation

enum OnboardingStep: String, Codable, CaseIterable {
    case welcome
    case screenRecording
    case accessibility
    case preferences
    case paywall
    case done

    var index: Int {
        switch self {
        case .welcome: return 0
        case .screenRecording: return 1
        case .accessibility: return 2
        case .preferences: return 3
        case .paywall: return 4
        case .done: return 5
        }
    }

    static let ordered: [OnboardingStep] = [
        .welcome, .screenRecording, .accessibility, .preferences, .paywall
    ]

    var next: OnboardingStep {
        switch self {
        case .welcome: return .screenRecording
        case .screenRecording: return .accessibility
        case .accessibility: return .preferences
        case .preferences: return .paywall
        case .paywall: return .done
        case .done: return .done
        }
    }
}

