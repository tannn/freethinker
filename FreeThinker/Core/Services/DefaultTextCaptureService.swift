import Foundation

public actor DefaultTextCaptureService: TextCaptureServiceProtocol {
    private let permissionService: AccessibilityPermissionServiceProtocol
    private let axTextExtractor: AXTextExtractorProtocol
    private let clipboardFallbackCapture: ClipboardFallbackCaptureProtocol
    private let dateProvider: DateProviding
    private let frontmostApplicationProvider: FrontmostApplicationProviding

    public init(
        permissionService: AccessibilityPermissionServiceProtocol,
        axTextExtractor: AXTextExtractorProtocol,
        clipboardFallbackCapture: ClipboardFallbackCaptureProtocol,
        dateProvider: DateProviding = SystemDateProvider(),
        frontmostApplicationProvider: FrontmostApplicationProviding = WorkspaceFrontmostApplicationProvider()
    ) {
        self.permissionService = permissionService
        self.axTextExtractor = axTextExtractor
        self.clipboardFallbackCapture = clipboardFallbackCapture
        self.dateProvider = dateProvider
        self.frontmostApplicationProvider = frontmostApplicationProvider
    }

    public var hasAccessibilityPermission: Bool {
        get async {
            let status = await permissionService.currentStatus()
            return status.isAuthorized
        }
    }

    public func preflightPermission(promptIfNeeded: Bool) async -> PermissionStatus {
        if promptIfNeeded {
            return await permissionService.requestPermissionIfNeeded()
        }
        return await permissionService.currentStatus()
    }

    public func requestAccessibilityPermission() async -> PermissionStatus {
        await permissionService.requestPermissionIfNeeded()
    }

    public func openAccessibilitySettings() async -> Bool {
        await permissionService.openSystemSettings()
    }

    public func captureSelectedText() async throws -> CaptureResult {
        do {
            try Task.checkCancellation()

            let permissionStatus = await permissionService.currentStatus()
            guard permissionStatus.isAuthorized else {
                throw FreeThinkerError.permissionDenied(status: permissionStatus)
            }

            do {
                let extracted = try axTextExtractor.extractSelectedText()
                return CaptureResult(
                    text: extracted.text,
                    metadata: CaptureMetadata(
                        method: .accessibilityAPI,
                        timestamp: dateProvider.now,
                        sourceAppBundleIdentifier: extracted.sourceAppBundleIdentifier,
                        selectionBounds: extracted.selectionBounds,
                        usedFallback: false,
                        fallbackReason: nil
                    )
                )
            } catch {
                let mappedError = mapExtractorError(error)
                guard shouldAttemptFallback(for: mappedError), clipboardFallbackCapture.isEnabled else {
                    throw mappedError
                }

                let fallbackText = try await clipboardFallbackCapture.captureSelectedText()
                return CaptureResult(
                    text: fallbackText,
                    metadata: CaptureMetadata(
                        method: .clipboardFallback,
                        timestamp: dateProvider.now,
                        sourceAppBundleIdentifier: frontmostApplicationProvider.frontmostBundleIdentifier,
                        selectionBounds: nil,
                        usedFallback: true,
                        fallbackReason: fallbackReason(for: mappedError)
                    )
                )
            }
        } catch is CancellationError {
            throw FreeThinkerError.cancelled
        } catch let freeThinkerError as FreeThinkerError {
            throw freeThinkerError
        } catch {
            throw FreeThinkerError.captureFailed(reason: String(describing: error))
        }
    }

    private func mapExtractorError(_ error: Error) -> FreeThinkerError {
        if let freeThinkerError = error as? FreeThinkerError {
            return freeThinkerError
        }

        if error is CancellationError {
            return .cancelled
        }

        return .captureFailed(reason: String(describing: error))
    }

    private func shouldAttemptFallback(for error: FreeThinkerError) -> Bool {
        switch error {
        case .unsupportedElement, .noSelection, .captureFailed:
            return true
        default:
            return false
        }
    }

    private func fallbackReason(for error: FreeThinkerError) -> CaptureFallbackReason {
        switch error {
        case .unsupportedElement:
            return .unsupportedElement
        case .noSelection:
            return .noSelection
        default:
            return .extractorFailure
        }
    }
}
