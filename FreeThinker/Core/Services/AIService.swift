import Foundation

enum AIServiceError: Error, LocalizedError, Equatable, Sendable {
    case notReady(message: String)
    case generationFailed(reason: String)
    case invalidRequest(reason: String)

    var errorDescription: String? {
        switch self {
        case let .notReady(message):
            return message
        case let .generationFailed(reason):
            return "Generation failed: \(reason)"
        case let .invalidRequest(reason):
            return "Invalid request: \(reason)"
        }
    }
}

/// Contract for asynchronous, on-device provocation generation.
/// Thread safety: implementers must support concurrent callers safely.
protocol AIService: Sendable {
    func generateProvocation(
        for request: ProvocationRequest
    ) async -> Result<ProvocationResponse, AIServiceError>
}
