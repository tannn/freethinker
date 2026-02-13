import Foundation

enum FreeThinkerError: Error, LocalizedError, Sendable {
    case ai(AIServiceError)
    case textCapture(TextCaptureError)
    case settings(SettingsServiceError)
    case startup(message: String)
    case unknown(message: String)

    var userMessage: String {
        switch self {
        case let .ai(error):
            return error.errorDescription ?? "AI generation failed."
        case let .textCapture(error):
            return error.errorDescription ?? "Text capture failed."
        case let .settings(error):
            return error.errorDescription ?? "Settings update failed."
        case let .startup(message):
            return message
        case let .unknown(message):
            return message
        }
    }

    var errorDescription: String? {
        userMessage
    }

    var recoverySuggestion: String? {
        switch self {
        case .ai:
            return "Try again with different selected text."
        case .textCapture:
            return "Confirm Accessibility permissions in System Settings."
        case .settings:
            return "Check disk permissions and retry."
        case .startup, .unknown:
            return nil
        }
    }
}
