import Foundation

public struct ProvocationContent: Equatable, Codable, Sendable {
    public static let maxHeadlineLength = 100
    public static let maxBodyLength = 420
    public static let maxFollowUpLength = 140

    public let headline: String
    public let body: String
    public let followUpQuestion: String?

    public init(headline: String, body: String, followUpQuestion: String? = nil) {
        self.headline = String(headline.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxHeadlineLength))
        self.body = String(body.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxBodyLength))
        if let followUpQuestion {
            let normalized = followUpQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
            self.followUpQuestion = normalized.isEmpty ? nil : String(normalized.prefix(Self.maxFollowUpLength))
        } else {
            self.followUpQuestion = nil
        }
    }
}

public enum ProvocationOutcome: Equatable, Sendable {
    case success(content: ProvocationContent)
    case failure(error: FreeThinkerError)
}

public struct ProvocationResponse: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let requestId: UUID
    public let originalText: String
    public let provocationType: ProvocationType
    public let styleUsed: ProvocationStylePreset
    public let outcome: ProvocationOutcome
    public let generationTime: TimeInterval
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        requestId: UUID,
        originalText: String,
        provocationType: ProvocationType,
        styleUsed: ProvocationStylePreset,
        outcome: ProvocationOutcome,
        generationTime: TimeInterval,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.requestId = requestId
        self.originalText = String(originalText.prefix(ProvocationRequest.maxSelectedTextLength))
        self.provocationType = provocationType
        self.styleUsed = styleUsed
        self.outcome = outcome
        self.generationTime = max(0, generationTime)
        self.timestamp = timestamp
    }
}

public extension ProvocationResponse {
    var isSuccess: Bool {
        if case .success = outcome { return true }
        return false
    }

    var content: ProvocationContent? {
        if case let .success(content) = outcome { return content }
        return nil
    }

    var error: FreeThinkerError? {
        if case let .failure(error) = outcome { return error }
        return nil
    }
}
