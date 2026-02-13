import Foundation

struct CapturedText: Codable, Equatable, Sendable {
    var text: String
    var sourceApplication: String?

    init(text: String, sourceApplication: String? = nil) {
        self.text = text
        self.sourceApplication = sourceApplication
    }
}

enum TextCaptureError: Error, LocalizedError, Equatable, Sendable {
    case permissionDenied
    case noSelection
    case unavailable(reason: String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Accessibility permission is not granted."
        case .noSelection:
            return "No selected text was found."
        case let .unavailable(reason):
            return "Text capture unavailable: \(reason)"
        }
    }
}

/// Contract for asynchronous selected-text capture from the focused app.
/// Thread safety: implementers should serialize AX state access internally.
protocol TextCaptureService: Sendable {
    func captureSelectedText() async -> Result<CapturedText, TextCaptureError>
}
