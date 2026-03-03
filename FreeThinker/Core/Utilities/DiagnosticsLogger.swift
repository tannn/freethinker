import Foundation

/// Protocol for recording and exporting diagnostic events.
///
/// Conforming types are responsible for thread safety. Recording is a no-op
/// when ``isEnabled()`` returns `false`.
public protocol DiagnosticsLogging {
    /// Returns whether diagnostic recording is currently active.
    func isEnabled() -> Bool

    /// Enables or disables diagnostic recording.
    ///
    /// - Parameter enabled: `true` to start recording; `false` to stop.
    func setEnabled(_ enabled: Bool)

    /// Records a pre-constructed ``DiagnosticEvent``.
    ///
    /// - Parameter event: The event to append to the in-memory log.
    func record(_ event: DiagnosticEvent)

    /// Constructs and records a diagnostic event from component parts.
    ///
    /// - Parameters:
    ///   - stage: The functional area that produced the event.
    ///   - category: The event severity.
    ///   - message: A brief human-readable description.
    ///   - metadata: Supplemental key-value pairs (sensitive keys are redacted).
    func record(
        stage: DiagnosticStage,
        category: DiagnosticCategory,
        message: String,
        metadata: [String: String]
    )

    /// Returns all events currently held in memory, in chronological order.
    func recentEvents() -> [DiagnosticEvent]

    /// Serialises events to a pretty-printed JSON file at the given URL.
    ///
    /// Creates intermediate directories if needed. Writes atomically.
    ///
    /// - Parameter url: The destination file URL.
    /// - Throws: Encoding or file-system errors if the export fails.
    func exportEvents(to url: URL) throws
}

/// Thread-safe ``DiagnosticsLogging`` implementation backed by `UserDefaults`.
///
/// Events are stored in memory and persisted to `UserDefaults` after each write.
/// The log is bounded by ``maxEvents`` and ``maxStorageBytes``; the oldest events
/// are dropped when either limit is exceeded.
public final class DiagnosticsLogger: DiagnosticsLogging {
    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let enabledKey: String
    private let storageKey: String
    private let maxEvents: Int
    private let maxStorageBytes: Int

    private let lock = NSLock()
    private var enabled: Bool
    private var events: [DiagnosticEvent]

    /// Creates a `DiagnosticsLogger` with injectable dependencies.
    ///
    /// - Parameters:
    ///   - userDefaults: `UserDefaults` instance for persistence. Defaults to `.standard`.
    ///   - encoder: JSON encoder for writing events. Defaults to `JSONEncoder()`.
    ///   - decoder: JSON decoder for loading persisted events. Defaults to `JSONDecoder()`.
    ///   - enabledKey: `UserDefaults` key for the enabled flag. Defaults to `"diagnostics.enabled"`.
    ///   - storageKey: `UserDefaults` key for the events array. Defaults to `"diagnostics.events.v1"`.
    ///   - maxEvents: Maximum number of events retained (minimum 1). Defaults to 300.
    ///   - maxStorageBytes: Maximum encoded size in bytes (minimum 2 048). Defaults to 64 KiB.
    public init(
        userDefaults: UserDefaults = .standard,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder(),
        enabledKey: String = "diagnostics.enabled",
        storageKey: String = "diagnostics.events.v1",
        maxEvents: Int = 300,
        maxStorageBytes: Int = 64 * 1024
    ) {
        self.userDefaults = userDefaults
        self.encoder = encoder
        self.decoder = decoder
        self.enabledKey = enabledKey
        self.storageKey = storageKey
        self.maxEvents = max(1, maxEvents)
        self.maxStorageBytes = max(2_048, maxStorageBytes)

        enabled = userDefaults.object(forKey: enabledKey) as? Bool ?? false

        var recoveredEvents: [DiagnosticEvent] = []
        var shouldPersistRecoveredEvents = false
        if
            let data = userDefaults.data(forKey: storageKey),
            let decoded = try? decoder.decode([DiagnosticEvent].self, from: data)
        {
            recoveredEvents = decoded.map { $0.sanitized() }
            shouldPersistRecoveredEvents = recoveredEvents != decoded
        }

        events = recoveredEvents
        trimToBounds()
        if shouldPersistRecoveredEvents || events.count != recoveredEvents.count {
            persistEvents()
        }
    }

    public func isEnabled() -> Bool {
        lock.withLock { enabled }
    }

    public func setEnabled(_ enabled: Bool) {
        lock.withLock {
            self.enabled = enabled
            userDefaults.set(enabled, forKey: enabledKey)
        }

        if enabled {
            Logger.info("Diagnostics enabled", category: .diagnostics)
        } else {
            Logger.info("Diagnostics disabled", category: .diagnostics)
        }
    }

    public func record(_ event: DiagnosticEvent) {
        lock.withLock {
            guard enabled else {
                return
            }

            events.append(event.sanitized())
            trimToBounds()
            persistEvents()
        }
    }

    public func record(
        stage: DiagnosticStage,
        category: DiagnosticCategory,
        message: String,
        metadata: [String: String] = [:]
    ) {
        let event = DiagnosticEvent(
            stage: stage,
            category: category,
            message: message,
            metadata: metadata
        )
        record(event)
    }

    public func recentEvents() -> [DiagnosticEvent] {
        lock.withLock { events }
    }

    public func exportEvents(to url: URL) throws {
        let exportEncoder = JSONEncoder()
        exportEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        exportEncoder.dateEncodingStrategy = .iso8601

        let snapshot = lock.withLock { events.map { $0.sanitized() } }
        let payload = try exportEncoder.encode(snapshot)
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try payload.write(to: url, options: .atomic)
    }
}

private extension DiagnosticsLogger {
    func trimToBounds() {
        if events.count > maxEvents {
            events = Array(events.suffix(maxEvents))
        }

        while encodedSizeInBytes() > maxStorageBytes, events.count > 1 {
            events.removeFirst()
        }
    }

    func encodedSizeInBytes() -> Int {
        (try? encoder.encode(events).count) ?? 0
    }

    func persistEvents() {
        guard let encoded = try? encoder.encode(events) else {
            Logger.warning("Diagnostics encoding failed; skipping persistence", category: .diagnostics)
            return
        }

        userDefaults.set(encoded, forKey: storageKey)
    }
}

private extension NSLock {
    @discardableResult
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
