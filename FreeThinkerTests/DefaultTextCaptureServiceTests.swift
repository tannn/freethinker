import XCTest
@testable import FreeThinker

final class DefaultTextCaptureServiceTests: XCTestCase {
    func testPreflightTreatsReachableAXAPIAsGrantedWhenTrustFlagIsFalse() async {
        let service = DefaultTextCaptureService(
            permissionChecker: { false },
            accessibilityReachabilityProbe: { true }
        )

        let status = await service.preflightPermission()
        XCTAssertEqual(status, .granted)
    }

    func testCaptureAllowsSelectionWhenTrustFlagIsFalseButAXAPIIsReachable() async throws {
        let service = DefaultTextCaptureService(
            permissionChecker: { false },
            accessibilityReachabilityProbe: { true },
            accessibilitySelectionProvider: { "selected text" },
            clipboardFallbackProvider: { nil }
        )

        let captured = try await service.captureSelectedText()
        XCTAssertEqual(captured, "selected text")
    }

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
