import Foundation
import Observation

@MainActor
@Observable
public final class AppState {
    public enum GenerationState: Equatable {
        case idle
        case blockedByPermission
        case capturingText
        case captureSucceeded
        case captureFailed
    }

    public enum TriggerOrigin: String {
        case menuBar
        case hotkey
    }

    public private(set) var generationState: GenerationState = .idle
    public private(set) var permissionStatus: PermissionStatus = .denied(canPrompt: true, nextPromptDate: nil)
    public private(set) var lastCaptureResult: CaptureResult?
    public private(set) var lastCaptureError: FreeThinkerError?
    public private(set) var permissionDeniedEventCount: Int = 0
    public private(set) var lastTriggerOrigin: TriggerOrigin?

    private var retryHook: (() -> Void)?

    public init() {}

    public func beginCapture(origin: TriggerOrigin) {
        lastTriggerOrigin = origin
        generationState = .capturingText
        lastCaptureError = nil
    }

    public func finishCapture(result: CaptureResult) {
        lastCaptureResult = result
        lastCaptureError = nil
        generationState = .captureSucceeded
    }

    public func failCapture(error: FreeThinkerError) {
        lastCaptureError = error
        generationState = .captureFailed
    }

    public func updatePermissionStatus(_ status: PermissionStatus) {
        permissionStatus = status
    }

    public func recordPermissionDenied(origin: TriggerOrigin) {
        permissionDeniedEventCount += 1
        lastTriggerOrigin = origin
        generationState = .blockedByPermission
        lastCaptureError = .permissionDenied(status: permissionStatus)
    }

    public func setRetryHook(_ hook: @escaping () -> Void) {
        retryHook = hook
    }

    public func runRetryHookIfAuthorized() {
        guard permissionStatus.isAuthorized else {
            return
        }

        let hook = retryHook
        retryHook = nil
        hook?()
    }

    public func clearRetryHook() {
        retryHook = nil
    }
}
