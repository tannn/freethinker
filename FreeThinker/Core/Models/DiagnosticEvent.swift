import Foundation

/// Identifies the functional area of the app that produced a diagnostic event.
public enum DiagnosticStage: String, Codable, Equatable, Sendable, CaseIterable {
    /// App startup and shutdown events.
    case appLifecycle
    /// Onboarding flow events.
    case onboarding
    /// Settings changes and persistence events.
    case settings
    /// Accessibility permission check before text capture.
    case permissionPreflight
    /// Selected text reading and clipboard fallback events.
    case textCapture
    /// AI model prompt submission and response events.
    case aiGeneration
    /// Panel state transitions after a response is received.
    case responsePresentation
    /// Diagnostics export operations.
    case export
}

/// The severity level of a diagnostic event.
public enum DiagnosticCategory: String, Codable, Equatable, Sendable {
    /// Informational; normal operation.
    case info
    /// Unexpected but non-fatal condition.
    case warning
    /// A failure that affected the user.
    case error
}

/// A single recorded diagnostic event.
///
/// Messages and metadata values are automatically redacted on init:
/// - The message is truncated to ``maxMessageLength``.
/// - Metadata keys matching known sensitive patterns are replaced with `"[REDACTED]"`.
/// - All metadata values are truncated to ``maxMetadataValueLength``.
public struct DiagnosticEvent: Codable, Equatable, Identifiable, Sendable {
    /// Maximum character length for ``message``.
    public static let maxMessageLength = 240
    /// Maximum character length for each metadata value.
    public static let maxMetadataValueLength = 160

    /// Unique identifier for this event.
    public let id: UUID
    /// The wall-clock time when the event was recorded.
    public let timestamp: Date
    /// The functional area that produced this event.
    public let stage: DiagnosticStage
    /// The severity of this event.
    public let category: DiagnosticCategory
    /// A brief human-readable description (truncated and sanitised).
    public let message: String
    /// Structured key-value metadata (values truncated and sensitive keys redacted).
    public let metadata: [String: String]

    /// Creates a `DiagnosticEvent`, sanitising message and metadata on init.
    ///
    /// - Parameters:
    ///   - id: Unique event ID. Defaults to a new `UUID()`.
    ///   - timestamp: Event time. Defaults to `Date()`.
    ///   - stage: The functional area producing the event.
    ///   - category: The event severity.
    ///   - message: A brief description; truncated to ``maxMessageLength``.
    ///   - metadata: Supplemental key-value pairs; sensitive keys are redacted.
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
    /// Returns a copy of this event after passing all fields through sanitisation again.
    ///
    /// Useful when loading persisted events that may have been written by an older version.
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

    /// Returns a sanitised copy of a metadata dictionary.
    ///
    /// Values whose keys match ``isSensitiveKey(_:)`` are replaced with `"[REDACTED]"`.
    /// All other values are passed through ``redact(_:)-9vxm9`` to strip control characters
    /// and enforce ``maxMetadataValueLength``.
    ///
    /// - Parameter metadata: The raw metadata dictionary to sanitise.
    /// - Returns: A new dictionary with sensitive values redacted and all values truncated.
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

    /// Returns a sanitised copy of a single metadata value string.
    ///
    /// Replaces null bytes and newlines with spaces, trims surrounding whitespace,
    /// and truncates to ``maxMetadataValueLength`` characters.
    ///
    /// - Parameter value: The raw string to sanitise.
    /// - Returns: The sanitised string, at most ``maxMetadataValueLength`` characters long.
    static func redact(_ value: String) -> String {
        String(
            value
                .replacingOccurrences(of: "\0", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(maxMetadataValueLength)
        )
    }

    /// Returns a sanitised copy of an event message string.
    ///
    /// Applies the same transformations as ``redact(_:)-9vxm9`` but truncates
    /// to ``maxMessageLength`` instead.
    ///
    /// - Parameter value: The raw message string to sanitise.
    /// - Returns: The sanitised string, at most ``maxMessageLength`` characters long.
    static func redactMessage(_ value: String) -> String {
        String(
            value
                .replacingOccurrences(of: "\0", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(maxMessageLength)
        )
    }

    /// Returns `true` when the given metadata key is considered sensitive.
    ///
    /// A key is sensitive if its lowercased form contains any of the substrings:
    /// `text`, `prompt`, `content`, `selection`, `clipboard`, `input`, `output`,
    /// `body`, `follow_up`, or `followup`. Matching keys have their values replaced
    /// with `"[REDACTED]"` during sanitisation.
    ///
    /// - Parameter key: The metadata key to test.
    /// - Returns: `true` if the key matches a sensitive pattern.
    static func isSensitiveKey(_ key: String) -> Bool {
        let normalized = key.lowercased()
        return normalized.contains("text")
            || normalized.contains("prompt")
            || normalized.contains("content")
            || normalized.contains("selection")
            || normalized.contains("clipboard")
            || normalized.contains("input")
            || normalized.contains("output")
            || normalized.contains("body")
            || normalized.contains("follow_up")
            || normalized.contains("followup")
    }
}
