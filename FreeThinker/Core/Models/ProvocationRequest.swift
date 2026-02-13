import Foundation

public enum ProvocationType: String, Codable, CaseIterable, Sendable {
    case hiddenAssumptions
    case counterargument
    case custom
}

public struct ProvocationRequest: Identifiable, Codable, Equatable, Sendable {
    public static let maxSelectedTextLength = 1_000

    public enum ValidationError: LocalizedError, Equatable, Sendable {
        case emptySelectedText

        public var errorDescription: String? {
            switch self {
            case .emptySelectedText:
                return "Selected text cannot be empty."
            }
        }
    }

    public let id: UUID
    public let selectedText: String
    public let provocationType: ProvocationType
    public let timestamp: Date
    public let regenerateFromResponseID: UUID?

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
