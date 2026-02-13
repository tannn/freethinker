import Foundation

public enum FreeThinkerError: Error, Sendable, Equatable {
    case accessibilityPermissionDenied
    case noSelection
    case hotkeyRegistrationConflict
    case hotkeyRegistrationFailed
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
    case triggerDebounced
    case generationAlreadyInProgress
}

extension FreeThinkerError: LocalizedError {
    public var errorDescription: String? {
        userMessage
    }
}

public extension FreeThinkerError {
    var userMessage: String {
        switch self {
        case .accessibilityPermissionDenied:
            return "Accessibility permission is required to read selected text."
        case .noSelection:
            return "No text selected. Select text and try again."
        case .hotkeyRegistrationConflict:
            return "The global hotkey is already used by another app."
        case .hotkeyRegistrationFailed:
            return "Could not register the global hotkey."
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
        case .triggerDebounced:
            return "Trigger ignored because it was pressed too quickly."
        case .generationAlreadyInProgress:
            return "A provocation is already being generated."
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
