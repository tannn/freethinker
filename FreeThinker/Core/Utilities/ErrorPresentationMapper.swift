import Foundation

/// A UI action suggested alongside an error message to help the user recover.
public enum ErrorPresentationAction: Equatable, Sendable {
    /// Retry the operation that failed.
    case retry
    /// Navigate to System Settings > Privacy & Security > Accessibility.
    case openAccessibilitySettings
    /// Navigate to the hotkey customisation section of FreeThinker's settings.
    case openHotkeySettings
    /// Navigate to FreeThinker's general settings window.
    case openSettings
    /// No action is suggested.
    case none
}

/// A fully-mapped error suitable for display in the floating panel or as a notification.
public struct ErrorPresentation: Equatable, Sendable {
    /// The localised message to show in the UI.
    public let message: String
    /// A suggested remediation action, or ``ErrorPresentationAction/none``.
    public let action: ErrorPresentationAction
    /// When `true`, the panel should be shown even if it was not previously visible.
    public let preferPanelPresentation: Bool

    /// Creates an `ErrorPresentation` with explicit values.
    public init(
        message: String,
        action: ErrorPresentationAction,
        preferPanelPresentation: Bool
    ) {
        self.message = message
        self.action = action
        self.preferPanelPresentation = preferPanelPresentation
    }
}

/// Protocol for mapping ``FreeThinkerError`` values to user-facing ``ErrorPresentation`` instances.
///
/// The mapping is trigger-source-aware: some errors (like ``FreeThinkerError/timeout``)
/// prefer background presentation when triggered via the hotkey.
public protocol ErrorPresentationMapping: Sendable {
    /// Maps a ``FreeThinkerError`` to an ``ErrorPresentation`` appropriate for the given trigger source.
    ///
    /// - Parameters:
    ///   - error: The error to map.
    ///   - source: The trigger source that initiated the failed generation.
    /// - Returns: A presentation value with a message, action, and panel preference.
    func map(error: FreeThinkerError, source: ProvocationTriggerSource) -> ErrorPresentation
}

/// Concrete implementation of ``ErrorPresentationMapping`` with translocation detection.
///
/// For Accessibility permission errors, the mapper appends an extra hint when the app
/// appears to be running from a translocated path.
public struct ErrorPresentationMapper: ErrorPresentationMapping {
    private let isTranslocatedProvider: @Sendable () -> Bool

    /// Creates a mapper with a custom translocation detector.
    ///
    /// - Parameter isTranslocatedProvider: Returns `true` if the app bundle is in a translocated
    ///   path. Defaults to checking for `/AppTranslocation/` in `Bundle.main.bundlePath`.
    public init(
        isTranslocatedProvider: @escaping @Sendable () -> Bool = {
            Bundle.main.bundlePath.contains("/AppTranslocation/")
        }
    ) {
        self.isTranslocatedProvider = isTranslocatedProvider
    }

    /// Maps a ``FreeThinkerError`` to an ``ErrorPresentation``.
    ///
    /// - Parameters:
    ///   - error: The error to map.
    ///   - source: The trigger source; influences ``ErrorPresentation/preferPanelPresentation``
    ///     for some error cases.
    /// - Returns: A user-facing error presentation.
    public func map(error: FreeThinkerError, source: ProvocationTriggerSource) -> ErrorPresentation {
        switch error {
        case .accessibilityPermissionDenied:
            let translocationHint = isTranslocatedProvider()
                ? " FreeThinker appears to be running from a translocated location."
                    + " Move it to /Applications, relaunch, then re-enable Accessibility once."
                : ""
            return ErrorPresentation(
                message: "FreeThinker needs Accessibility access. "
                    + "Open Settings -> Privacy & Security -> Accessibility, then enable FreeThinker."
                    + "\(translocationHint)",
                action: .openAccessibilitySettings,
                preferPanelPresentation: true
            )

        case .noSelection:
            return ErrorPresentation(
                message: "Select some text in the active app, then trigger FreeThinker again.",
                action: .retry,
                preferPanelPresentation: true
            )

        case .hotkeyShortcutInvalid:
            return ErrorPresentation(
                message: "That shortcut is not supported. Choose a key with Command, Shift, Option, or Control.",
                action: .openHotkeySettings,
                preferPanelPresentation: true
            )

        case .hotkeyShortcutReserved:
            return ErrorPresentation(
                message: "That shortcut is reserved by macOS. Choose a different combination in Settings.",
                action: .openHotkeySettings,
                preferPanelPresentation: true
            )

        case .hotkeyRegistrationConflict:
            return ErrorPresentation(
                message: "That shortcut is already used by another app. "
                    + "Open Settings to change or disable the FreeThinker hotkey.",
                action: .openHotkeySettings,
                preferPanelPresentation: true
            )

        case .hotkeyRegistrationFailed:
            return ErrorPresentation(
                message: "FreeThinker could not register its global hotkey. "
                    + "Open Settings to retry or adjust the shortcut.",
                action: .openHotkeySettings,
                preferPanelPresentation: true
            )

        case .timeout:
            return ErrorPresentation(
                message: "Generation took too long. Try again.",
                action: .retry,
                preferPanelPresentation: source != .hotkey
            )

        case .cancelled:
            return ErrorPresentation(
                message: "Generation cancelled.",
                action: .none,
                preferPanelPresentation: false
            )

        case .modelUnavailable, .unsupportedOperatingSystem, .unsupportedHardware, .frameworkUnavailable:
            return ErrorPresentation(
                message: "On-device AI is not available on this Mac. Open Settings to review model options.",
                action: .openSettings,
                preferPanelPresentation: true
            )

        case .transientModelFailure:
            return ErrorPresentation(
                message: "The model is warming up. Try again in a moment.",
                action: .retry,
                preferPanelPresentation: false
            )

        case .generationFailed, .invalidPrompt, .invalidResponse:
            return ErrorPresentation(
                message: "FreeThinker could not generate a provocation. Try again.",
                action: .retry,
                preferPanelPresentation: true
            )

        case .triggerDebounced:
            return ErrorPresentation(
                message: "You triggered too quickly. Wait a moment and try again.",
                action: .none,
                preferPanelPresentation: false
            )

        case .generationAlreadyInProgress:
            return ErrorPresentation(
                message: "Generation is already running.",
                action: .none,
                preferPanelPresentation: false
            )
        }
    }
}
