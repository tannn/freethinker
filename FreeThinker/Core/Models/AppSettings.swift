import Foundation

struct AppSettings: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 2

    enum PanelBehavior: String, Codable, CaseIterable, Sendable {
        case anchoredNearSelection
        case centered
        case pinned

        var displayName: String {
            switch self {
            case .anchoredNearSelection:
                return "Near selected text"
            case .centered:
                return "Centered"
            case .pinned:
                return "Pinned"
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let value = (try? container.decode(String.self)) ?? PanelBehavior.anchoredNearSelection.rawValue

            switch value {
            case PanelBehavior.anchoredNearSelection.rawValue, "anchored":
                self = .anchoredNearSelection
            case PanelBehavior.centered.rawValue:
                self = .centered
            case PanelBehavior.pinned.rawValue:
                self = .pinned
            default:
                self = .anchoredNearSelection
            }
        }
    }

    enum ProvocationStyle: String, Codable, CaseIterable, Sendable {
        case balanced
        case provocative
        case analytical

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let value = (try? container.decode(String.self)) ?? ProvocationStyle.balanced.rawValue

            switch value {
            case ProvocationStyle.balanced.rawValue:
                self = .balanced
            case ProvocationStyle.provocative.rawValue, "spicy":
                self = .provocative
            case ProvocationStyle.analytical.rawValue, "critical":
                self = .analytical
            default:
                self = .balanced
            }
        }
    }

    enum KeyModifier: String, Codable, CaseIterable, Sendable {
        case command
        case shift
        case option
        case control
    }

    struct HotkeyShortcut: Codable, Equatable, Sendable {
        var key: String
        var modifiers: Set<KeyModifier>

        init(key: String, modifiers: Set<KeyModifier>) {
            self.key = key
            self.modifiers = modifiers
        }

        static let `default` = HotkeyShortcut(
            key: "P",
            modifiers: [.command, .shift]
        )

        func normalized() -> HotkeyShortcut {
            var result = self
            let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)

            if let first = trimmedKey.unicodeScalars.first {
                result.key = String(Character(first)).uppercased()
            } else {
                result.key = HotkeyShortcut.default.key
            }

            if result.modifiers.isEmpty {
                result.modifiers = HotkeyShortcut.default.modifiers
            }

            return result
        }
    }

    var schemaVersion: Int
    var hotkeyEnabled: Bool
    var hotkeyShortcut: HotkeyShortcut
    var panelBehavior: PanelBehavior
    var provocationStyle: ProvocationStyle
    var launchAtLogin: Bool
    var autoDismissSeconds: TimeInterval?

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        hotkeyEnabled: Bool = true,
        hotkeyShortcut: HotkeyShortcut = .default,
        panelBehavior: PanelBehavior = .anchoredNearSelection,
        provocationStyle: ProvocationStyle = .balanced,
        launchAtLogin: Bool = false,
        autoDismissSeconds: TimeInterval? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.hotkeyEnabled = hotkeyEnabled
        self.hotkeyShortcut = hotkeyShortcut
        self.panelBehavior = panelBehavior
        self.provocationStyle = provocationStyle
        self.launchAtLogin = launchAtLogin
        self.autoDismissSeconds = autoDismissSeconds
    }

    func normalized() -> AppSettings {
        var result = self

        if result.schemaVersion <= 0 {
            result.schemaVersion = 1
        }

        result.hotkeyShortcut = result.hotkeyShortcut.normalized()

        if let autoDismissSeconds = result.autoDismissSeconds {
            if autoDismissSeconds <= 0 {
                result.autoDismissSeconds = nil
            } else {
                result.autoDismissSeconds = min(max(autoDismissSeconds, 3), 120)
            }
        }

        return result
    }

    func normalizedForPersistence() -> AppSettings {
        var result = normalized()
        result.schemaVersion = Self.currentSchemaVersion
        return result
    }

    static let defaultValue = AppSettings()
}
