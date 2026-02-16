import Foundation

public enum ErrorPresentationAction: Equatable, Sendable {
    case retry
    case openAccessibilitySettings
    case openHotkeySettings
    case openSettings
    case none
}

public struct ErrorPresentation: Equatable, Sendable {
    public let message: String
    public let action: ErrorPresentationAction
    public let preferPanelPresentation: Bool

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

public protocol ErrorPresentationMapping: Sendable {
    func map(error: FreeThinkerError, source: ProvocationTriggerSource) -> ErrorPresentation
}

public struct ErrorPresentationMapper: ErrorPresentationMapping {
    private let isTranslocatedProvider: @Sendable () -> Bool

    public init(
        isTranslocatedProvider: @escaping @Sendable () -> Bool = {
            Bundle.main.bundlePath.contains("/AppTranslocation/")
        }
    ) {
        self.isTranslocatedProvider = isTranslocatedProvider
    }

    public func map(error: FreeThinkerError, source: ProvocationTriggerSource) -> ErrorPresentation {
        switch error {
        case .accessibilityPermissionDenied:
            let translocationHint = isTranslocatedProvider()
                ? " FreeThinker appears to be running from a translocated location. Move it to /Applications, relaunch, then re-enable Accessibility once."
                : ""
            return ErrorPresentation(
                message: "FreeThinker needs Accessibility access. Open Settings -> Privacy & Security -> Accessibility, then enable FreeThinker.\(translocationHint)",
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
                message: "That shortcut is already used by another app. Open Settings to change or disable the FreeThinker hotkey.",
                action: .openHotkeySettings,
                preferPanelPresentation: true
            )

        case .hotkeyRegistrationFailed:
            return ErrorPresentation(
                message: "FreeThinker could not register its global hotkey. Open Settings to retry or adjust the shortcut.",
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
