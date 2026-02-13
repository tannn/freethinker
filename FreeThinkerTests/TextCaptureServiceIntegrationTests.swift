import CoreGraphics
import Foundation
import XCTest
@testable import FreeThinker

final class TextCaptureServiceIntegrationTests: XCTestCase {
    func testCaptureFailsWhenPermissionDenied() async {
        let service = makeService(
            permissionStatus: .denied(canPrompt: true, nextPromptDate: nil),
            extractor: StubAXTextExtractor(result: .failure(FreeThinkerError.noSelection)),
            fallback: StubFallbackCapture(isEnabled: true, result: .success("fallback"))
        )

        do {
            _ = try await service.captureSelectedText()
            XCTFail("Expected permissionDenied error")
        } catch let error as FreeThinkerError {
            XCTAssertEqual(error, .permissionDenied(status: .denied(canPrompt: true, nextPromptDate: nil)))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCaptureReturnsDirectAXResultWithMetadata() async throws {
        let fixedDate = Date(timeIntervalSince1970: 3_000)
        let extracted = AXExtractedText(
            text: "Hello\nWorld",
            selectionBounds: CGRect(x: 10, y: 20, width: 30, height: 40),
            sourceAppBundleIdentifier: "com.example.editor"
        )

        let service = makeService(
            permissionStatus: .authorized,
            extractor: StubAXTextExtractor(result: .success(extracted)),
            fallback: StubFallbackCapture(isEnabled: true, result: .success("fallback")),
            dateProvider: FixedDateProvider(now: fixedDate)
        )

        let result = try await service.captureSelectedText()

        XCTAssertEqual(result.text, "Hello\nWorld")
        XCTAssertEqual(result.metadata.method, .accessibilityAPI)
        XCTAssertEqual(result.metadata.timestamp, fixedDate)
        XCTAssertEqual(result.metadata.sourceAppBundleIdentifier, "com.example.editor")
        XCTAssertFalse(result.metadata.usedFallback)
        XCTAssertNil(result.metadata.fallbackReason)
    }

    func testCaptureUsesFallbackWhenExtractorUnsupported() async throws {
        let service = makeService(
            permissionStatus: .authorized,
            extractor: StubAXTextExtractor(result: .failure(FreeThinkerError.unsupportedElement(role: "AXButton"))),
            fallback: StubFallbackCapture(isEnabled: true, result: .success("Recovered text")),
            dateProvider: FixedDateProvider(now: Date(timeIntervalSince1970: 4_000)),
            frontmostAppProvider: StaticFrontmostAppProvider(frontmostBundleIdentifier: "com.example.browser")
        )

        let result = try await service.captureSelectedText()

        XCTAssertEqual(result.text, "Recovered text")
        XCTAssertEqual(result.metadata.method, .clipboardFallback)
        XCTAssertTrue(result.metadata.usedFallback)
        XCTAssertEqual(result.metadata.fallbackReason, .unsupportedElement)
        XCTAssertEqual(result.metadata.sourceAppBundleIdentifier, "com.example.browser")
    }

    func testCaptureReturnsNoSelectionWhenFallbackDisabled() async {
        let service = makeService(
            permissionStatus: .authorized,
            extractor: StubAXTextExtractor(result: .failure(FreeThinkerError.noSelection)),
            fallback: StubFallbackCapture(isEnabled: false, result: .success("unused"))
        )

        do {
            _ = try await service.captureSelectedText()
            XCTFail("Expected noSelection")
        } catch let error as FreeThinkerError {
            XCTAssertEqual(error, .noSelection)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCaptureMapsCancellationToCancelledError() async {
        let service = makeService(
            permissionStatus: .authorized,
            extractor: StubAXTextExtractor(result: .failure(FreeThinkerError.unsupportedElement(role: nil))),
            fallback: DelayedFallbackCapture()
        )

        let task = Task {
            try await service.captureSelectedText()
        }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation error")
        } catch let error as FreeThinkerError {
            XCTAssertEqual(error, .cancelled)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeService(
        permissionStatus: PermissionStatus,
        extractor: AXTextExtractorProtocol,
        fallback: ClipboardFallbackCaptureProtocol,
        dateProvider: DateProviding = FixedDateProvider(now: Date(timeIntervalSince1970: 0)),
        frontmostAppProvider: FrontmostApplicationProviding = StaticFrontmostAppProvider(frontmostBundleIdentifier: nil)
    ) -> DefaultTextCaptureService {
        DefaultTextCaptureService(
            permissionService: StubPermissionService(status: permissionStatus),
            axTextExtractor: extractor,
            clipboardFallbackCapture: fallback,
            dateProvider: dateProvider,
            frontmostApplicationProvider: frontmostAppProvider
        )
    }
}

private struct StubAXTextExtractor: AXTextExtractorProtocol {
    let result: Result<AXExtractedText, Error>

    func extractSelectedText() throws -> AXExtractedText {
        try result.get()
    }
}

private final class StubPermissionService: AccessibilityPermissionServiceProtocol, @unchecked Sendable {
    private let status: PermissionStatus

    init(status: PermissionStatus) {
        self.status = status
    }

    func currentStatus() async -> PermissionStatus {
        status
    }

    func requestPermissionIfNeeded() async -> PermissionStatus {
        status
    }

    func openSystemSettings() async -> Bool {
        true
    }
}

private final class StubFallbackCapture: ClipboardFallbackCaptureProtocol, @unchecked Sendable {
    let isEnabled: Bool
    private let result: Result<String, Error>

    init(isEnabled: Bool, result: Result<String, Error>) {
        self.isEnabled = isEnabled
        self.result = result
    }

    func captureSelectedText() async throws -> String {
        try result.get()
    }
}

private final class DelayedFallbackCapture: ClipboardFallbackCaptureProtocol, @unchecked Sendable {
    let isEnabled = true

    func captureSelectedText() async throws -> String {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return "late"
    }
}

private struct FixedDateProvider: DateProviding {
    let now: Date
}

private struct StaticFrontmostAppProvider: FrontmostApplicationProviding {
    let frontmostBundleIdentifier: String?
}
