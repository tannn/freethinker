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
    public init() {}

    public func map(error: FreeThinkerError, source: ProvocationTriggerSource) -> ErrorPresentation {
        switch error {
        case .accessibilityPermissionDenied:
            return ErrorPresentation(
                message: "FreeThinker needs Accessibility access. Open Settings -> Privacy & Security -> Accessibility, then enable FreeThinker.",
                action: .openAccessibilitySettings,
                preferPanelPresentation: true
            )

        case .noSelection:
            return ErrorPresentation(
                message: "Select some text in the active app, then trigger FreeThinker again.",
                action: .retry,
                preferPanelPresentation: true
            )

        case .hotkeyRegistrationConflict:
            return ErrorPresentation(
                message: "Cmd+Shift+P is already used by another app. Open Settings to change or disable the FreeThinker hotkey.",
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
