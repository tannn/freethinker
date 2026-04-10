import AppKit
import Foundation

/// The on-device Foundation Model variant to use for generation.
public enum ModelOption: String, Codable, CaseIterable, Identifiable, Sendable {
    /// The default general-purpose model.
    case `default`
    /// A model variant tuned for creative writing tasks.
    case creativeWriting

    public var id: String { rawValue }
}

/// The critical-thinking style applied when composing provocation prompts.
public enum ProvocationStylePreset: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Takes a contrary angle and challenges weak premises.
    case contrarian
    /// Uses Socratic questioning to expose gaps in reasoning.
    case socratic
    /// Analyses second-order effects and systemic trade-offs.
    case systemsThinking

    public var id: String { rawValue }

    /// A human-readable name suitable for display in the UI.
    public var displayName: String {
        switch self {
        case .contrarian:
            return "Contrarian"
        case .socratic:
            return "Socratic"
        case .systemsThinking:
            return "Systems Thinking"
        }
    }

    /// The style instruction injected into the model prompt for this preset.
    public var instruction: String {
        switch self {
        case .contrarian:
            return "Take a rigorous contrary angle. Surface weak premises and overconfidence. "
                + "What might be wrong, incomplete, or deserving of skepticism? What counterarguments could be made?"
        case .socratic:
            return "Use Socratic questioning to challenge assumptions and reveal gaps in reasoning. "
                + "Challenge the main assumptions or claims made here. "
                + "What might be wrong, incomplete, or deserving of skepticism?"
        case .systemsThinking:
            return "Analyze second-order effects, feedback loops, and systemic tradeoffs. "
                + "What are the broader implications? What connections can you draw to other fields or concepts? "
                + "How might this extend or apply in unexpected ways?"
        }
    }
}

/// The software update channel the app subscribes to.
public enum AppUpdateChannel: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Production releases only.
    case stable
    /// Pre-release builds for early testing.
    case beta

    public var id: String { rawValue }

    /// A human-readable channel name for display in Settings.
    public var displayName: String {
        switch self {
        case .stable:
            return "Stable"
        case .beta:
            return "Beta"
        }
    }
}

/// Identifies a named section within the Settings window.
public enum SettingsSection: String, CaseIterable, Identifiable, Sendable {
    /// General app preferences (hotkey, menu bar, launch at login, etc.).
    case general
    /// Provocation style and prompt customisation settings.
    case provocation
    /// Accessibility troubleshooting and permission guidance.
    case accessibilityHelp

    public var id: String { rawValue }

    /// The localised title shown in the Settings navigation sidebar.
    public var title: String {
        switch self {
        case .general:
            return "General"
        case .provocation:
            return "Provocation"
        case .accessibilityHelp:
            return "Accessibility Help"
        }
    }
}

/// A global keyboard shortcut consisting of modifier flags and a key code.
public struct HotkeyShortcut: Codable, Equatable, Hashable, Sendable {
    /// The app's default shortcut: Cmd+Shift+P.
    public static let defaultShortcut = HotkeyShortcut(
        modifiers: AppSettings.defaultHotkeyModifiers,
        keyCode: AppSettings.defaultHotkeyKeyCode
    )

    /// The raw `NSEvent.ModifierFlags` value (e.g., command + shift).
    public let modifiers: Int
    /// The virtual key code (Carbon key codes).
    public let keyCode: Int

    /// Creates a shortcut with the given modifier flags and key code.
    ///
    /// - Parameters:
    ///   - modifiers: Raw `NSEvent.ModifierFlags` integer value.
    ///   - keyCode: Carbon virtual key code.
    public init(modifiers: Int, keyCode: Int) {
        self.modifiers = modifiers
        self.keyCode = keyCode
    }

    /// A human-readable representation such as `"Cmd+Shift+P"`.
    public var displayString: String {
        HotkeyDisplayFormatter.displayString(for: self)
    }
}

/// The outcome of validating a proposed global hotkey shortcut.
public enum HotkeyValidationStatus: String, Equatable, Sendable {
    /// The shortcut is acceptable and was (or can be) registered.
    case valid
    /// The shortcut is structurally invalid (e.g., no modifier key).
    case invalid
    /// The shortcut is reserved by macOS and cannot be used.
    case reserved
    /// The shortcut is already claimed by another application.
    case conflict
}

/// The result of validating a proposed hotkey shortcut.
///
/// `proposedShortcut` is the shortcut the user requested;
/// `effectiveShortcut` is the shortcut that will actually be used
/// (may differ if the validator chose a safe alternative).
public struct HotkeyValidationResult: Equatable, Sendable {
    /// The validation outcome.
    public let status: HotkeyValidationStatus
    /// An optional localised message to display to the user.
    public let message: String?
    /// The shortcut the user originally requested.
    public let proposedShortcut: HotkeyShortcut
    /// The shortcut that will actually be registered.
    public let effectiveShortcut: HotkeyShortcut

    /// Creates a validation result with explicit values.
    public init(
        status: HotkeyValidationStatus,
        message: String?,
        proposedShortcut: HotkeyShortcut,
        effectiveShortcut: HotkeyShortcut
    ) {
        self.status = status
        self.message = message
        self.proposedShortcut = proposedShortcut
        self.effectiveShortcut = effectiveShortcut
    }

    /// `true` when `status` is ``HotkeyValidationStatus/valid``.
    public var isAccepted: Bool {
        status == .valid
    }

    public static func valid(
        proposedShortcut: HotkeyShortcut,
        effectiveShortcut: HotkeyShortcut,
        message: String? = nil
    ) -> HotkeyValidationResult {
        HotkeyValidationResult(
            status: .valid,
            message: message,
            proposedShortcut: proposedShortcut,
            effectiveShortcut: effectiveShortcut
        )
    }

    public static func invalid(
        proposedShortcut: HotkeyShortcut,
        effectiveShortcut: HotkeyShortcut,
        message: String
    ) -> HotkeyValidationResult {
        HotkeyValidationResult(
            status: .invalid,
            message: message,
            proposedShortcut: proposedShortcut,
            effectiveShortcut: effectiveShortcut
        )
    }

    public static func reserved(
        proposedShortcut: HotkeyShortcut,
        effectiveShortcut: HotkeyShortcut,
        message: String
    ) -> HotkeyValidationResult {
        HotkeyValidationResult(
            status: .reserved,
            message: message,
            proposedShortcut: proposedShortcut,
            effectiveShortcut: effectiveShortcut
        )
    }

    public static func conflict(
        proposedShortcut: HotkeyShortcut,
        effectiveShortcut: HotkeyShortcut,
        message: String
    ) -> HotkeyValidationResult {
        HotkeyValidationResult(
            status: .conflict,
            message: message,
            proposedShortcut: proposedShortcut,
            effectiveShortcut: effectiveShortcut
        )
    }
}

public enum HotkeyDisplayFormatter {
    public static func displayString(for shortcut: HotkeyShortcut) -> String {
        let modifierPart = modifierDisplayNames(rawModifiers: shortcut.modifiers)
        let keyPart = keyDisplayName(keyCode: shortcut.keyCode)

        guard modifierPart.isEmpty == false else {
            return keyPart
        }

        return (modifierPart + [keyPart]).joined(separator: "+")
    }
}

private extension HotkeyDisplayFormatter {
    static let keyDisplayNames: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2", 20: "3",
        21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]",
        31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return", 37: "L", 38: "J", 39: "'", 40: "K",
        41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space", 50: "`",
        51: "Delete", 53: "Esc",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
        103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15", 106: "F16",
        64: "F17", 79: "F18", 80: "F19", 90: "F20",
        123: "Left", 124: "Right", 125: "Down", 126: "Up"
    ]

    static let supportedModifiers: NSEvent.ModifierFlags = [.command, .shift, .option, .control]

    static func modifierDisplayNames(rawModifiers: Int) -> [String] {
        guard rawModifiers >= 0 else {
            return []
        }

        let flags = NSEvent.ModifierFlags(rawValue: UInt(rawModifiers))
            .intersection(.deviceIndependentFlagsMask)
            .intersection(supportedModifiers)

        var names: [String] = []

        if flags.contains(.command) {
            names.append("Cmd")
        }
        if flags.contains(.shift) {
            names.append("Shift")
        }
        if flags.contains(.option) {
            names.append("Option")
        }
        if flags.contains(.control) {
            names.append("Control")
        }

        return names
    }

    static func keyDisplayName(keyCode: Int) -> String {
        if let display = keyDisplayNames[keyCode] {
            return display
        }

        return "Key\(keyCode)"
    }
}

/// The root settings model for FreeThinker.
///
/// `AppSettings` is persisted as JSON via a custom `Codable` implementation that
/// falls back to defaults for missing keys, enabling forward and backward compatibility.
/// Call ``validated()`` after loading from disk or applying user changes to clamp
/// all values to their legal ranges.
public struct AppSettings: Codable, Equatable, Sendable {
    /// The current JSON schema version; used to migrate old persisted values.
    public static let currentSchemaVersion = 2
    /// Default modifier flags for the global hotkey (Cmd+Shift = 1_179_648).
    public static let defaultHotkeyModifiers = 1_179_648
    /// Default key code for the global hotkey (P = 35).
    public static let defaultHotkeyKeyCode = 35
    /// Default text for the first custom prompt template.
    public static let defaultPrompt1 =
        "Identify hidden assumptions, unstated premises, or implicit biases in the following text."
    /// Default text for the second custom prompt template.
    public static let defaultPrompt2 =
        "Provide a strong, well-reasoned counterargument or alternative perspective to the following claim."
    /// Maximum allowed length (in characters) for prompt1 and prompt2.
    public static let maxPromptLength = 1_000
    /// Maximum allowed length (in characters) for `customStyleInstructions`.
    public static let maxCustomInstructionLength = 300
    /// Minimum allowed value for `autoDismissSeconds`.
    public static let minAutoDismissSeconds: TimeInterval = 2
    /// Maximum allowed value for `autoDismissSeconds`.
    public static let maxAutoDismissSeconds: TimeInterval = 20

    /// The persisted schema version of this settings value.
    public var schemaVersion: Int
    /// Whether the global hotkey is active.
    public var hotkeyEnabled: Bool
    /// Raw `NSEvent.ModifierFlags` for the global hotkey.
    public var hotkeyModifiers: Int
    /// Carbon virtual key code for the global hotkey.
    public var hotkeyKeyCode: Int
    /// The first customisable prompt template (hidden assumptions style).
    public var prompt1: String
    /// The second customisable prompt template (counterargument style).
    public var prompt2: String
    /// Whether the app launches at login.
    public var launchAtLogin: Bool
    /// The on-device model variant used for generation.
    public var selectedModel: ModelOption
    /// Whether the menu bar status item is visible.
    public var showMenuBarIcon: Bool
    /// Whether the panel is automatically dismissed after the user copies a result.
    public var dismissOnCopy: Bool
    /// Seconds before the panel auto-dismisses after showing a result (clamped to 2–20).
    public var autoDismissSeconds: TimeInterval
    /// Whether clipboard-based text capture fallback is enabled.
    public var fallbackCaptureEnabled: Bool
    /// Whether diagnostic event recording is active.
    public var diagnosticsEnabled: Bool
    /// `true` once the user has seen the onboarding flow at least once.
    public var hasSeenOnboarding: Bool
    /// `true` once the user has completed all onboarding steps.
    public var onboardingCompleted: Bool
    /// `true` once the user has confirmed awareness of the global hotkey.
    public var hotkeyAwarenessConfirmed: Bool
    /// The active provocation style preset.
    public var provocationStylePreset: ProvocationStylePreset
    /// Optional extra instructions appended to the style section of the prompt (max 300 chars).
    public var customStyleInstructions: String
    /// Whether Sparkle checks for updates automatically.
    public var automaticallyCheckForUpdates: Bool
    /// The update channel (stable or beta).
    public var appUpdateChannel: AppUpdateChannel
    /// Maximum seconds the AI generation may run before timing out (clamped to 1–15).
    public var aiTimeoutSeconds: TimeInterval

    public init(
        schemaVersion: Int = AppSettings.currentSchemaVersion,
        hotkeyEnabled: Bool = true,
        hotkeyModifiers: Int = AppSettings.defaultHotkeyModifiers,
        hotkeyKeyCode: Int = AppSettings.defaultHotkeyKeyCode,
        prompt1: String = AppSettings.defaultPrompt1,
        prompt2: String = AppSettings.defaultPrompt2,
        launchAtLogin: Bool = false,
        selectedModel: ModelOption = .default,
        showMenuBarIcon: Bool = true,
        dismissOnCopy: Bool = true,
        autoDismissSeconds: TimeInterval = 6.0,
        fallbackCaptureEnabled: Bool = true,
        diagnosticsEnabled: Bool = false,
        hasSeenOnboarding: Bool = false,
        onboardingCompleted: Bool = false,
        hotkeyAwarenessConfirmed: Bool = false,
        provocationStylePreset: ProvocationStylePreset = .socratic,
        customStyleInstructions: String = "",
        automaticallyCheckForUpdates: Bool = true,
        appUpdateChannel: AppUpdateChannel = .stable,
        aiTimeoutSeconds: TimeInterval = 5.0
    ) {
        self.schemaVersion = schemaVersion
        self.hotkeyEnabled = hotkeyEnabled
        self.hotkeyModifiers = hotkeyModifiers
        self.hotkeyKeyCode = hotkeyKeyCode
        self.prompt1 = prompt1
        self.prompt2 = prompt2
        self.launchAtLogin = launchAtLogin
        self.selectedModel = selectedModel
        self.showMenuBarIcon = showMenuBarIcon
        self.dismissOnCopy = dismissOnCopy
        self.autoDismissSeconds = autoDismissSeconds
        self.fallbackCaptureEnabled = fallbackCaptureEnabled
        self.diagnosticsEnabled = diagnosticsEnabled
        self.hasSeenOnboarding = hasSeenOnboarding
        self.onboardingCompleted = onboardingCompleted
        self.hotkeyAwarenessConfirmed = hotkeyAwarenessConfirmed
        self.provocationStylePreset = provocationStylePreset
        self.customStyleInstructions = customStyleInstructions
        self.automaticallyCheckForUpdates = automaticallyCheckForUpdates
        self.appUpdateChannel = appUpdateChannel
        self.aiTimeoutSeconds = aiTimeoutSeconds
    }

    public var hotkeyShortcut: HotkeyShortcut {
        get {
            HotkeyShortcut(modifiers: hotkeyModifiers, keyCode: hotkeyKeyCode)
        }
        set {
            hotkeyModifiers = newValue.modifiers
            hotkeyKeyCode = newValue.keyCode
        }
    }
}

private extension AppSettings {
    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case hotkeyEnabled
        case hotkeyModifiers
        case hotkeyKeyCode
        case prompt1
        case prompt2
        case launchAtLogin
        case selectedModel
        case showMenuBarIcon
        case dismissOnCopy
        case autoDismissSeconds
        case fallbackCaptureEnabled
        case diagnosticsEnabled
        case hasSeenOnboarding
        case onboardingCompleted
        case hotkeyAwarenessConfirmed
        case provocationStylePreset
        case customStyleInstructions
        case automaticallyCheckForUpdates
        case appUpdateChannel
        case aiTimeoutSeconds
    }
}

public extension AppSettings {
    init(from decoder: any Decoder) throws {
        let defaults = AppSettings()
        let container = try decoder.container(keyedBy: CodingKeys.self)

        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? defaults.schemaVersion
        hotkeyEnabled = try container.decodeIfPresent(Bool.self, forKey: .hotkeyEnabled) ?? defaults.hotkeyEnabled
        hotkeyModifiers = try container.decodeIfPresent(Int.self, forKey: .hotkeyModifiers) ?? defaults.hotkeyModifiers
        hotkeyKeyCode = try container.decodeIfPresent(Int.self, forKey: .hotkeyKeyCode) ?? defaults.hotkeyKeyCode
        prompt1 = try container.decodeIfPresent(String.self, forKey: .prompt1) ?? defaults.prompt1
        prompt2 = try container.decodeIfPresent(String.self, forKey: .prompt2) ?? defaults.prompt2
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? defaults.launchAtLogin
        selectedModel = try container.decodeIfPresent(ModelOption.self, forKey: .selectedModel)
            ?? defaults.selectedModel
        showMenuBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon)
            ?? defaults.showMenuBarIcon
        dismissOnCopy = try container.decodeIfPresent(Bool.self, forKey: .dismissOnCopy)
            ?? defaults.dismissOnCopy
        autoDismissSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .autoDismissSeconds)
            ?? defaults.autoDismissSeconds
        fallbackCaptureEnabled = try container.decodeIfPresent(Bool.self, forKey: .fallbackCaptureEnabled)
            ?? defaults.fallbackCaptureEnabled
        diagnosticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .diagnosticsEnabled)
            ?? defaults.diagnosticsEnabled
        hasSeenOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasSeenOnboarding)
            ?? defaults.hasSeenOnboarding
        onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted)
            ?? defaults.onboardingCompleted
        hotkeyAwarenessConfirmed = try container.decodeIfPresent(Bool.self, forKey: .hotkeyAwarenessConfirmed)
            ?? defaults.hotkeyAwarenessConfirmed
        provocationStylePreset = try container.decodeIfPresent(
            ProvocationStylePreset.self, forKey: .provocationStylePreset
        ) ?? defaults.provocationStylePreset
        customStyleInstructions = try container.decodeIfPresent(String.self, forKey: .customStyleInstructions)
            ?? defaults.customStyleInstructions
        automaticallyCheckForUpdates = try container.decodeIfPresent(Bool.self, forKey: .automaticallyCheckForUpdates)
            ?? defaults.automaticallyCheckForUpdates
        appUpdateChannel = try container.decodeIfPresent(AppUpdateChannel.self, forKey: .appUpdateChannel)
            ?? defaults.appUpdateChannel
        aiTimeoutSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .aiTimeoutSeconds)
            ?? defaults.aiTimeoutSeconds
    }
}

public extension AppSettings {
    /// Returns a copy of these settings with all values clamped to their valid ranges.
    ///
    /// Specifically:
    /// - `schemaVersion` is bumped to ``currentSchemaVersion`` if lower.
    /// - `hotkeyKeyCode` is reset to ``defaultHotkeyKeyCode`` if out of range 0–127.
    /// - `hotkeyModifiers` is reset to ``defaultHotkeyModifiers`` if negative.
    /// - `prompt1` and `prompt2` are trimmed and truncated to ``maxPromptLength``, then
    ///   restored to their defaults if empty.
    /// - `customStyleInstructions` is sanitised and truncated to ``maxCustomInstructionLength``.
    /// - `autoDismissSeconds` is clamped to `minAutoDismissSeconds...maxAutoDismissSeconds`.
    /// - `aiTimeoutSeconds` is clamped to 1...15.
    /// - `hasSeenOnboarding` is set to `true` if `onboardingCompleted` is `true`.
    ///
    /// - Returns: A validated copy of `self`.
    func validated() -> AppSettings {
        var result = self

        if result.schemaVersion < Self.currentSchemaVersion {
            result.schemaVersion = Self.currentSchemaVersion
        }

        if result.hotkeyKeyCode < 0 || result.hotkeyKeyCode > 127 {
            result.hotkeyKeyCode = Self.defaultHotkeyKeyCode
        }

        if result.hotkeyModifiers < 0 {
            result.hotkeyModifiers = Self.defaultHotkeyModifiers
        }

        result.prompt1 = String(
            result.prompt1.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxPromptLength)
        )
        result.prompt2 = String(
            result.prompt2.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxPromptLength)
        )

        if result.prompt1.isEmpty {
            result.prompt1 = Self.defaultPrompt1
        }
        if result.prompt2.isEmpty {
            result.prompt2 = Self.defaultPrompt2
        }

        result.customStyleInstructions = String(
            result.customStyleInstructions
                .replacingOccurrences(of: "\0", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(Self.maxCustomInstructionLength)
        )

        if result.autoDismissSeconds < Self.minAutoDismissSeconds {
            result.autoDismissSeconds = Self.minAutoDismissSeconds
        } else if result.autoDismissSeconds > Self.maxAutoDismissSeconds {
            result.autoDismissSeconds = Self.maxAutoDismissSeconds
        }

        if result.aiTimeoutSeconds < 1 {
            result.aiTimeoutSeconds = 1
        } else if result.aiTimeoutSeconds > 15 {
            result.aiTimeoutSeconds = 15
        }

        if result.onboardingCompleted {
            result.hasSeenOnboarding = true
        }

        return result
    }
}
