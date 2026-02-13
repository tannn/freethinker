import Foundation
import XCTest
@testable import FreeThinker

final class DiagnosticsLoggerTests: XCTestCase {
    func testRecordIgnoredWhenDisabled() {
        let logger = DiagnosticsLogger(userDefaults: makeDefaults())

        logger.record(
            stage: .aiGeneration,
            category: .info,
            message: "ignored",
            metadata: [:]
        )

        XCTAssertTrue(logger.recentEvents().isEmpty)
    }

    func testRecordRedactsSensitiveMetadata() {
        let logger = DiagnosticsLogger(userDefaults: makeDefaults())
        logger.setEnabled(true)

        logger.record(
            stage: .textCapture,
            category: .info,
            message: "Captured text",
            metadata: [
                "selected_text": "sensitive user content",
                "request_id": "123"
            ]
        )

        let events = logger.recentEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].metadata["selected_text"], "[REDACTED]")
        XCTAssertEqual(events[0].metadata["request_id"], "123")
    }

    func testRollingBoundsKeepMostRecentEvents() {
        let logger = DiagnosticsLogger(
            userDefaults: makeDefaults(),
            maxEvents: 3,
            maxStorageBytes: 16 * 1024
        )
        logger.setEnabled(true)

        for index in 0..<6 {
            logger.record(
                stage: .settings,
                category: .info,
                message: "event-\(index)",
                metadata: [:]
            )
        }

        let events = logger.recentEvents()
        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events.map(\.message), ["event-3", "event-4", "event-5"])
    }

    func testExportWritesJSONFile() throws {
        let logger = DiagnosticsLogger(userDefaults: makeDefaults())
        logger.setEnabled(true)
        logger.record(stage: .export, category: .info, message: "exporting", metadata: [:])

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("diagnostics-\(UUID().uuidString).json")

        try logger.exportEvents(to: url)
        let data = try Data(contentsOf: url)

        XCTAssertFalse(data.isEmpty)
        try FileManager.default.removeItem(at: url)
    }

    func testInitSanitizesRecoveredLegacyEvents() throws {
        let defaults = makeDefaults()
        let rawEvent: [String: Any] = [
            "id": UUID().uuidString,
            "timestamp": Date().timeIntervalSinceReferenceDate,
            "stage": "textCapture",
            "category": "info",
            "message": "line-1\nline-2",
            "metadata": [
                "selected_text": "sensitive user content",
                "request_id": "abc-123"
            ]
        ]
        let rawPayload = try JSONSerialization.data(withJSONObject: [rawEvent], options: [])
        defaults.set(rawPayload, forKey: "diagnostics.events.v1")

        let logger = DiagnosticsLogger(userDefaults: defaults)
        let events = logger.recentEvents()

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].metadata["selected_text"], "[REDACTED]")
        XCTAssertEqual(events[0].metadata["request_id"], "abc-123")
        XCTAssertFalse(events[0].message.contains("\n"))
    }

    func testDiagnosticEventRedactsNullCharactersAndStructuredContentKeys() {
        let event = DiagnosticEvent(
            stage: .aiGeneration,
            category: .warning,
            message: "Bad\0Message",
            metadata: [
                "headline": "Sensitive\0headline",
                "request_id": "safe-id"
            ]
        )

        XCTAssertFalse(event.message.contains("\0"))
        XCTAssertEqual(event.metadata["headline"], "[REDACTED]")
        XCTAssertEqual(event.metadata["request_id"], "safe-id")
    }
}

private extension DiagnosticsLoggerTests {
    func makeDefaults() -> UserDefaults {
        let suite = "diagnostics-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
