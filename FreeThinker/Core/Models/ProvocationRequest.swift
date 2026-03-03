import Foundation

/// The style of critical-thinking challenge the AI should generate.
public enum ProvocationType: String, Codable, CaseIterable, Sendable {
    /// Surface hidden assumptions and unstated premises in the text.
    case hiddenAssumptions
    /// Produce a strong counterargument or alternative perspective.
    case counterargument
    /// Apply a custom challenge framing defined by the user's prompt.
    case custom
}

/// A validated request to generate a provocation for a piece of selected text.
///
/// The initialiser trims whitespace and throws if the result is empty. The text is
/// truncated to ``maxSelectedTextLength`` characters on init.
public struct ProvocationRequest: Identifiable, Codable, Equatable, Sendable {
    /// Maximum number of characters retained from the selected text.
    public static let maxSelectedTextLength = 1_000

    /// Errors thrown during ``ProvocationRequest`` initialisation.
    public enum ValidationError: LocalizedError, Equatable, Sendable {
        /// The selected text was empty or consisted only of whitespace.
        case emptySelectedText

        public var errorDescription: String? {
            switch self {
            case .emptySelectedText:
                return "Selected text cannot be empty."
            }
        }
    }

    /// Unique identifier for this request.
    public let id: UUID
    /// The user's selected text, trimmed and truncated to ``maxSelectedTextLength``.
    public let selectedText: String
    /// The type of critical-thinking challenge requested.
    public let provocationType: ProvocationType
    /// The time this request was created.
    public let timestamp: Date
    /// When set, indicates this is a regeneration of the response with this ID.
    public let regenerateFromResponseID: UUID?

    /// Creates a validated `ProvocationRequest`.
    ///
    /// - Parameters:
    ///   - id: A unique identifier. Defaults to a new `UUID()`.
    ///   - selectedText: The text the user selected. Must be non-empty after trimming.
    ///   - provocationType: The challenge type to apply.
    ///   - timestamp: When the request was created. Defaults to `Date()`.
    ///   - regenerateFromResponseID: ID of a prior response to regenerate, or `nil`.
    /// - Throws: ``ValidationError/emptySelectedText`` if `selectedText` is blank.
    public init(
        id: UUID = UUID(),
        selectedText: String,
        provocationType: ProvocationType,
        timestamp: Date = Date(),
        regenerateFromResponseID: UUID? = nil
    ) throws {
        let trimmed = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ValidationError.emptySelectedText
        }

        self.id = id
        self.selectedText = String(trimmed.prefix(Self.maxSelectedTextLength))
        self.provocationType = provocationType
        self.timestamp = timestamp
        self.regenerateFromResponseID = regenerateFromResponseID
    }
}
