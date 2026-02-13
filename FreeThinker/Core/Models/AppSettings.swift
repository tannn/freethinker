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

public struct AppSettings: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public static let defaultPrompt1 = "Identify hidden assumptions, unstated premises, or implicit biases in the following text."
    public static let defaultPrompt2 = "Provide a strong, well-reasoned counterargument or alternative perspective to the following claim."
    public static let maxPromptLength = 1_000
    public static let maxCustomInstructionLength = 300

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
    public var provocationStylePreset: ProvocationStylePreset
    public var customStyleInstructions: String
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
        provocationStylePreset: ProvocationStylePreset = .socratic,
        customStyleInstructions: String = "",
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
        self.provocationStylePreset = provocationStylePreset
        self.customStyleInstructions = customStyleInstructions
        self.aiTimeoutSeconds = aiTimeoutSeconds
    }
}

public extension AppSettings {
    func validated() -> AppSettings {
        var result = self

        if result.schemaVersion <= 0 {
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

        if result.aiTimeoutSeconds < 1 {
            result.aiTimeoutSeconds = 1
        } else if result.aiTimeoutSeconds > 15 {
            result.aiTimeoutSeconds = 15
        }

        return result
    }
}
