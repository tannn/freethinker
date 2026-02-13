import Foundation

public enum FreeThinkerError: Error, Sendable, Equatable {
    case timeout
    case cancelled
    case modelUnavailable
    case unsupportedOperatingSystem
    case unsupportedHardware
    case frameworkUnavailable
    case transientModelFailure
    case generationFailed
    case invalidPrompt
    case invalidResponse
}

extension FreeThinkerError: LocalizedError {
    public var errorDescription: String? {
        userMessage
    }
}

public extension FreeThinkerError {
    var userMessage: String {
        switch self {
        case .timeout:
            return "AI generation timed out. Please try again."
        case .cancelled:
            return "Generation was cancelled."
        case .modelUnavailable:
            return "AI model is unavailable. Check system requirements."
        case .unsupportedOperatingSystem:
            return "FreeThinker requires macOS 26 or later for on-device AI."
        case .unsupportedHardware:
            return "FreeThinker requires Apple Silicon for on-device AI."
        case .frameworkUnavailable:
            return "The FoundationModels framework is unavailable in this build."
        case .transientModelFailure:
            return "The AI model is warming up. Please try again."
        case .generationFailed:
            return "Could not generate provocations. Please try again."
        case .invalidPrompt:
            return "The generated prompt was invalid."
        case .invalidResponse:
            return "The AI response format was invalid."
        }
    }

    var isRetriable: Bool {
        switch self {
        case .transientModelFailure:
            return true
        default:
            return false
        }
    }
}
