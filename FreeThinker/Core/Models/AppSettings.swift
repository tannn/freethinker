import Foundation

public enum ModelOption: String, Codable, CaseIterable, Identifiable, Sendable {
    case `default`
    case creativeWriting

    public var id: String { rawValue }
}

public enum ProvocationStylePreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case contrarian
    case socratic
    case systemsThinking

    public var id: String { rawValue }

    public var instruction: String {
        switch self {
        case .contrarian:
            return "Take a rigorous contrary angle. Surface weak premises and overconfidence."
        case .socratic:
            return "Use Socratic questioning to challenge assumptions and reveal gaps in reasoning."
        case .systemsThinking:
            return "Analyze second-order effects, feedback loops, and systemic tradeoffs."
        }
    }
}

public enum AppUpdateChannel: String, Codable, CaseIterable, Identifiable, Sendable {
    case stable
    case beta

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .stable:
            return "Stable"
        case .beta:
            return "Beta"
        }
    }
}

public enum SettingsSection: String, CaseIterable, Identifiable, Sendable {
    case general
    case provocation
    case accessibilityHelp

    public var id: String { rawValue }

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

public struct AppSettings: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 2
    public static let defaultPrompt1 = "Identify hidden assumptions, unstated premises, or implicit biases in the following text."
    public static let defaultPrompt2 = "Provide a strong, well-reasoned counterargument or alternative perspective to the following claim."
    public static let maxPromptLength = 1_000
    public static let maxCustomInstructionLength = 300
    public static let minAutoDismissSeconds: TimeInterval = 2
    public static let maxAutoDismissSeconds: TimeInterval = 20

    public var schemaVersion: Int
    public var hotkeyEnabled: Bool = true
    public var hotkeyModifiers: Int
    public var hotkeyKeyCode: Int
    public var prompt1: String
    public var prompt2: String
    public var launchAtLogin: Bool
    public var selectedModel: ModelOption
    public var showMenuBarIcon: Bool
    public var dismissOnCopy: Bool
    public var autoDismissSeconds: TimeInterval
    public var fallbackCaptureEnabled: Bool
    public var provocationStylePreset: ProvocationStylePreset
    public var customStyleInstructions: String
    public var automaticallyCheckForUpdates: Bool
    public var appUpdateChannel: AppUpdateChannel
    public var aiTimeoutSeconds: TimeInterval

    public init(
        schemaVersion: Int = AppSettings.currentSchemaVersion,
        hotkeyEnabled: Bool = true,
        hotkeyModifiers: Int = 1_179_648,
        hotkeyKeyCode: Int = 35,
        prompt1: String = AppSettings.defaultPrompt1,
        prompt2: String = AppSettings.defaultPrompt2,
        launchAtLogin: Bool = false,
        selectedModel: ModelOption = .default,
        showMenuBarIcon: Bool = true,
        dismissOnCopy: Bool = true,
        autoDismissSeconds: TimeInterval = 6.0,
        fallbackCaptureEnabled: Bool = true,
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
        self.provocationStylePreset = provocationStylePreset
        self.customStyleInstructions = customStyleInstructions
        self.automaticallyCheckForUpdates = automaticallyCheckForUpdates
        self.appUpdateChannel = appUpdateChannel
        self.aiTimeoutSeconds = aiTimeoutSeconds
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
        case provocationStylePreset
        case customStyleInstructions
        case automaticallyCheckForUpdates
        case appUpdateChannel
        case aiTimeoutSeconds
    }
}

public extension AppSettings {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        hotkeyEnabled = try container.decodeIfPresent(Bool.self, forKey: .hotkeyEnabled) ?? true
        hotkeyModifiers = try container.decodeIfPresent(Int.self, forKey: .hotkeyModifiers) ?? 1_179_648
        hotkeyKeyCode = try container.decodeIfPresent(Int.self, forKey: .hotkeyKeyCode) ?? 35
        prompt1 = try container.decodeIfPresent(String.self, forKey: .prompt1) ?? Self.defaultPrompt1
        prompt2 = try container.decodeIfPresent(String.self, forKey: .prompt2) ?? Self.defaultPrompt2
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        selectedModel = try container.decodeIfPresent(ModelOption.self, forKey: .selectedModel) ?? .default
        showMenuBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? true
        dismissOnCopy = try container.decodeIfPresent(Bool.self, forKey: .dismissOnCopy) ?? true
        autoDismissSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .autoDismissSeconds) ?? 6.0
        fallbackCaptureEnabled = try container.decodeIfPresent(Bool.self, forKey: .fallbackCaptureEnabled) ?? true
        provocationStylePreset = try container.decodeIfPresent(ProvocationStylePreset.self, forKey: .provocationStylePreset) ?? .socratic
        customStyleInstructions = try container.decodeIfPresent(String.self, forKey: .customStyleInstructions) ?? ""
        automaticallyCheckForUpdates = try container.decodeIfPresent(Bool.self, forKey: .automaticallyCheckForUpdates) ?? true
        appUpdateChannel = try container.decodeIfPresent(AppUpdateChannel.self, forKey: .appUpdateChannel) ?? .stable
        aiTimeoutSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .aiTimeoutSeconds) ?? 5.0
    }
}

public extension AppSettings {
    func validated() -> AppSettings {
        var result = self

        if result.schemaVersion < Self.currentSchemaVersion {
            result.schemaVersion = Self.currentSchemaVersion
        }

        if result.hotkeyKeyCode < 0 || result.hotkeyKeyCode > 127 {
            result.hotkeyKeyCode = 35
        }

        result.prompt1 = String(result.prompt1.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxPromptLength))
        result.prompt2 = String(result.prompt2.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxPromptLength))

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

        return result
    }
}
