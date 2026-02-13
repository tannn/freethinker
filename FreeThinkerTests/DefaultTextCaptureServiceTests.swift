import XCTest
@testable import FreeThinker

final class DefaultTextCaptureServiceTests: XCTestCase {
    func testCapturePrefersAccessibilitySelectionOverClipboardFallback() async throws {
        let service = DefaultTextCaptureService(
            permissionChecker: { true },
            accessibilitySelectionProvider: { "  selected from accessibility  " },
            clipboardFallbackProvider: { "clipboard text" }
        )

        let captured = try await service.captureSelectedText()
        XCTAssertEqual(captured, "selected from accessibility")
    }

    func testCaptureUsesClipboardFallbackWhenAccessibilitySelectionIsUnavailable() async throws {
        let service = DefaultTextCaptureService(
            permissionChecker: { true },
            accessibilitySelectionProvider: { nil },
            clipboardFallbackProvider: { "  clipboard fallback text  " }
        )

        let captured = try await service.captureSelectedText()
        XCTAssertEqual(captured, "clipboard fallback text")
    }

    func testCaptureHonorsFallbackToggleAtRuntime() async {
        let service = DefaultTextCaptureService(
            permissionChecker: { true },
            accessibilitySelectionProvider: { nil },
            clipboardFallbackProvider: { "clipboard fallback text" }
        )

        await service.setFallbackCaptureEnabled(false)

        do {
            _ = try await service.captureSelectedText()
            XCTFail("Expected noSelection when fallback capture is disabled")
        } catch let error as FreeThinkerError {
            XCTAssertEqual(error, .noSelection)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

