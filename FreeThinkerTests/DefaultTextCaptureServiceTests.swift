import os
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

    func testCaptureRequestsAccessibilityPromptWhenPermissionDenied() async {
        let promptCount = OSAllocatedUnfairLock(initialState: 0)
        let service = DefaultTextCaptureService(
            permissionChecker: { false },
            permissionPromptRequester: {
                promptCount.withLock { $0 += 1 }
                return false
            },
            accessibilityReachabilityProbe: { false },
            clipboardFallbackProvider: { nil }
        )

        do {
            _ = try await service.captureSelectedText()
            XCTFail("Expected accessibilityPermissionDenied when trust is missing")
        } catch let error as FreeThinkerError {
            XCTAssertEqual(error, .accessibilityPermissionDenied)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(promptCount.withLock { $0 }, 1)
    }

    func testPermissionPromptUsesCooldownToAvoidRepeatedPromptSpam() async {
        struct PromptState {
            var promptCount: Int = 0
            var now: UInt64 = 1_000
        }

        let state = OSAllocatedUnfairLock(initialState: PromptState())
        let service = DefaultTextCaptureService(
            permissionChecker: { false },
            permissionPromptRequester: {
                state.withLock { $0.promptCount += 1 }
                return false
            },
            permissionPromptCooldownNanoseconds: 500,
            uptimeNanosecondsProvider: {
                state.withLock { $0.now }
            },
            accessibilityReachabilityProbe: { false },
            clipboardFallbackProvider: { nil }
        )

        for _ in 0..<2 {
            do {
                _ = try await service.captureSelectedText()
                XCTFail("Expected accessibilityPermissionDenied while trust is missing")
            } catch let error as FreeThinkerError {
                XCTAssertEqual(error, .accessibilityPermissionDenied)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }

        XCTAssertEqual(state.withLock { $0.promptCount }, 1)

        state.withLock { $0.now = 2_000 }
        do {
            _ = try await service.captureSelectedText()
            XCTFail("Expected accessibilityPermissionDenied while trust is missing")
        } catch let error as FreeThinkerError {
            XCTAssertEqual(error, .accessibilityPermissionDenied)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(state.withLock { $0.promptCount }, 2)
    }
}
