import Foundation

struct AppSettings: Codable, Equatable, Sendable {
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
    }

    enum ProvocationStyle: String, Codable, CaseIterable, Sendable {
        case balanced
        case provocative
        case analytical
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
    }

    var hotkeyEnabled: Bool
    var hotkeyShortcut: HotkeyShortcut
    var panelBehavior: PanelBehavior
    var provocationStyle: ProvocationStyle
    var launchAtLogin: Bool
    var autoDismissSeconds: TimeInterval?

    init(
        hotkeyEnabled: Bool = true,
        hotkeyShortcut: HotkeyShortcut = .default,
        panelBehavior: PanelBehavior = .anchoredNearSelection,
        provocationStyle: ProvocationStyle = .balanced,
        launchAtLogin: Bool = false,
        autoDismissSeconds: TimeInterval? = nil
    ) {
        self.hotkeyEnabled = hotkeyEnabled
        self.hotkeyShortcut = hotkeyShortcut
        self.panelBehavior = panelBehavior
        self.provocationStyle = provocationStyle
        self.launchAtLogin = launchAtLogin
        self.autoDismissSeconds = autoDismissSeconds
    }

    static let defaultValue = AppSettings()
}
