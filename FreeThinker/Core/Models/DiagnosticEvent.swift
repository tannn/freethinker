import Foundation

public enum DiagnosticStage: String, Codable, Equatable, Sendable, CaseIterable {
    case appLifecycle
    case onboarding
    case settings
    case permissionPreflight
    case textCapture
    case aiGeneration
    case responsePresentation
    case export
}

public enum DiagnosticCategory: String, Codable, Equatable, Sendable {
    case info
    case warning
    case error
}

public struct DiagnosticEvent: Codable, Equatable, Identifiable, Sendable {
    public static let maxMessageLength = 240
    public static let maxMetadataValueLength = 160

    public let id: UUID
    public let timestamp: Date
    public let stage: DiagnosticStage
    public let category: DiagnosticCategory
    public let message: String
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        stage: DiagnosticStage,
        category: DiagnosticCategory,
        message: String,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.stage = stage
        self.category = category
        self.message = DiagnosticEvent.redactMessage(message)
        self.metadata = DiagnosticEvent.redact(metadata)
    }
}

public extension DiagnosticEvent {
    func sanitized() -> DiagnosticEvent {
        DiagnosticEvent(
            id: id,
            timestamp: timestamp,
            stage: stage,
            category: category,
            message: message,
            metadata: metadata
        )
    }

    static func redact(_ metadata: [String: String]) -> [String: String] {
        guard !metadata.isEmpty else {
            return [:]
        }

        var sanitized: [String: String] = [:]
        sanitized.reserveCapacity(metadata.count)

        for (key, value) in metadata {
            if isSensitiveKey(key) {
                sanitized[key] = "[REDACTED]"
                continue
            }

            sanitized[key] = redact(value)
        }

        return sanitized
    }

    static func redact(_ value: String) -> String {
        String(
            value
                .replacingOccurrences(of: "\0", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(maxMetadataValueLength)
        )
    }

    static func redactMessage(_ value: String) -> String {
        String(
            value
                .replacingOccurrences(of: "\0", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(maxMessageLength)
        )
    }

    static func isSensitiveKey(_ key: String) -> Bool {
        let normalized = key.lowercased()
        return normalized.contains("text")
            || normalized.contains("prompt")
            || normalized.contains("content")
            || normalized.contains("selection")
            || normalized.contains("clipboard")
            || normalized.contains("input")
            || normalized.contains("output")
            || normalized.contains("headline")
            || normalized.contains("body")
            || normalized.contains("follow_up")
            || normalized.contains("followup")
    }
}
