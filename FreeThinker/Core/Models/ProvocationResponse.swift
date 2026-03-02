import Foundation

/// The parsed content of a successful provocation generation.
///
/// Both `body` and `followUpQuestion` are trimmed and truncated on init.
public struct ProvocationContent: Equatable, Codable, Sendable {
    /// Maximum character length for `body`.
    public static let maxBodyLength = 420
    /// Maximum character length for `followUpQuestion`.
    public static let maxFollowUpLength = 140

    /// The main provocation text (max 420 characters).
    public let body: String
    /// An optional follow-up question to deepen the provocation (max 140 characters).
    public let followUpQuestion: String?

    /// Creates `ProvocationContent`, trimming and truncating both fields.
    ///
    /// - Parameters:
    ///   - body: The main provocation body text.
    ///   - followUpQuestion: An optional question; `nil` or empty strings are stored as `nil`.
    public init(body: String, followUpQuestion: String? = nil) {
        self.body = String(body.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxBodyLength))
        if let followUpQuestion {
            let normalized = followUpQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
            self.followUpQuestion = normalized.isEmpty ? nil : String(normalized.prefix(Self.maxFollowUpLength))
        } else {
            self.followUpQuestion = nil
        }
    }
}

/// The result of a single generation attempt.
public enum ProvocationOutcome: Equatable, Sendable {
    /// Generation succeeded; the associated content is ready to display.
    case success(content: ProvocationContent)
    /// Generation failed; the associated error describes the cause.
    case failure(error: FreeThinkerError)
}

/// A complete record of a provocation generation request and its outcome.
///
/// `ProvocationResponse` is immutable after creation. Use the convenience
/// properties ``isSuccess``, ``content``, and ``error`` to inspect the outcome.
public struct ProvocationResponse: Identifiable, Equatable, Sendable {
    /// Unique identifier for this response.
    public let id: UUID
    /// The ID of the ``ProvocationRequest`` that produced this response.
    public let requestId: UUID
    /// The original selected text, truncated to ``ProvocationRequest/maxSelectedTextLength``.
    public let originalText: String
    /// The provocation type used for this generation.
    public let provocationType: ProvocationType
    /// The style preset active when the response was generated.
    public let styleUsed: ProvocationStylePreset
    /// Whether the generation succeeded or failed, with associated data.
    public let outcome: ProvocationOutcome
    /// Wall-clock seconds elapsed from request start to response, clamped to ≥ 0.
    public let generationTime: TimeInterval
    /// The wall-clock time when the response was created.
    public let timestamp: Date

    /// Creates a `ProvocationResponse`.
    ///
    /// - Parameters:
    ///   - id: A unique response identifier. Defaults to a new `UUID()`.
    ///   - requestId: The ID of the originating ``ProvocationRequest``.
    ///   - originalText: The selected text that was sent to the model.
    ///   - provocationType: The challenge type used.
    ///   - styleUsed: The style preset active at generation time.
    ///   - outcome: The success or failure result.
    ///   - generationTime: Elapsed generation time in seconds (clamped to ≥ 0).
    ///   - timestamp: Creation time. Defaults to `Date()`.
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
    /// `true` when ``outcome`` is ``ProvocationOutcome/success(content:)``.
    var isSuccess: Bool {
        if case .success = outcome { return true }
        return false
    }

    /// The ``ProvocationContent`` from a successful outcome, or `nil` on failure.
    var content: ProvocationContent? {
        if case let .success(content) = outcome { return content }
        return nil
    }

    /// The ``FreeThinkerError`` from a failed outcome, or `nil` on success.
    var error: FreeThinkerError? {
        if case let .failure(error) = outcome { return error }
        return nil
    }
}
