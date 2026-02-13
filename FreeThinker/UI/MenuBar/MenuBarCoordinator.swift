import Foundation

public protocol MenuBarTelemetryLogging: Sendable {
    func logPermissionDenied(origin: AppState.TriggerOrigin)
}

public struct NoopMenuBarTelemetryLogger: MenuBarTelemetryLogging {
    public init() {}

    public func logPermissionDenied(origin: AppState.TriggerOrigin) {}
}

@MainActor
public final class MenuBarCoordinator {
    private let appState: AppState
    private let textCaptureService: TextCaptureServiceProtocol
    private let telemetryLogger: MenuBarTelemetryLogging

    public init(
        appState: AppState,
        textCaptureService: TextCaptureServiceProtocol,
        telemetryLogger: MenuBarTelemetryLogging = NoopMenuBarTelemetryLogger()
    ) {
        self.appState = appState
        self.textCaptureService = textCaptureService
        self.telemetryLogger = telemetryLogger
    }

    public func handleMenuBarGenerateAction() {
        runTriggerFlow(origin: .menuBar)
    }

    public func handleHotkeyTrigger() {
        runTriggerFlow(origin: .hotkey)
    }

    public func retryAfterPermissionGrant() {
        runTriggerFlow(origin: appState.lastTriggerOrigin ?? .menuBar)
    }

    private func runTriggerFlow(origin: AppState.TriggerOrigin) {
        Task { [weak self] in
            guard let self else {
                return
            }

            let permissionStatus = await textCaptureService.preflightPermission(promptIfNeeded: true)
            await MainActor.run {
                appState.updatePermissionStatus(permissionStatus)
            }

            guard permissionStatus.isAuthorized else {
                await MainActor.run {
                    appState.recordPermissionDenied(origin: origin)
                    appState.setRetryHook { [weak self] in
                        self?.retryAfterPermissionGrant()
                    }
                }
                telemetryLogger.logPermissionDenied(origin: origin)
                return
            }

            await MainActor.run {
                appState.beginCapture(origin: origin)
            }

            do {
                let captureResult = try await textCaptureService.captureSelectedText()
                await MainActor.run {
                    appState.finishCapture(result: captureResult)
                    appState.clearRetryHook()
                }
            } catch let freeThinkerError as FreeThinkerError {
                await MainActor.run {
                    appState.failCapture(error: freeThinkerError)
                }
            } catch {
                await MainActor.run {
                    appState.failCapture(error: .captureFailed(reason: String(describing: error)))
                }
            }
        }
    }
}
