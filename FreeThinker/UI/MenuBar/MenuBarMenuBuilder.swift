import AppKit
import Foundation

public enum MenuBarCommand: Equatable, Sendable {
    case generate
    case openSettings
    case openOnboardingGuide
    case toggleLaunchAtLogin
    case selectStylePreset(ProvocationStylePreset)
    case quit
}

public enum MenuBarMenuLabel {
    public static let generate = "Generate Provocation"
    public static let settings = "Settings..."
    public static let onboardingGuide = "Onboarding Guide..."
    public static let launchAtLogin = "Launch at Login"
    public static let quit = "Quit FreeThinker"
}

public struct MenuBarMenuState: Equatable, Sendable {
    public var isGenerating: Bool
    public var launchAtLoginEnabled: Bool
    public var selectedStylePreset: ProvocationStylePreset

    public init(
        isGenerating: Bool,
        launchAtLoginEnabled: Bool,
        selectedStylePreset: ProvocationStylePreset
    ) {
        self.isGenerating = isGenerating
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.selectedStylePreset = selectedStylePreset
    }
}

public struct MenuBarMenuItemDescriptor: Equatable, Sendable {
    public var title: String
    public var command: MenuBarCommand?
    public var isEnabled: Bool
    public var isSeparator: Bool
    public var isOn: Bool

    public init(
        title: String,
        command: MenuBarCommand?,
        isEnabled: Bool = true,
        isSeparator: Bool = false,
        isOn: Bool = false
    ) {
        self.title = title
        self.command = command
        self.isEnabled = isEnabled
        self.isSeparator = isSeparator
        self.isOn = isOn
    }
}

public protocol MenuBarMenuBuilding: Sendable {
    func makeDescriptors(state: MenuBarMenuState) -> [MenuBarMenuItemDescriptor]
}

public struct MenuBarMenuBuilder: MenuBarMenuBuilding {
    public init() {}

    public func makeDescriptors(state: MenuBarMenuState) -> [MenuBarMenuItemDescriptor] {
        var descriptors = [
            MenuBarMenuItemDescriptor(
                title: MenuBarMenuLabel.generate,
                command: .generate,
                isEnabled: !state.isGenerating
            ),
            MenuBarMenuItemDescriptor(title: "", command: nil, isSeparator: true),
            MenuBarMenuItemDescriptor(title: MenuBarMenuLabel.settings, command: .openSettings),
            MenuBarMenuItemDescriptor(title: MenuBarMenuLabel.onboardingGuide, command: .openOnboardingGuide),
            MenuBarMenuItemDescriptor(
                title: MenuBarMenuLabel.launchAtLogin,
                command: .toggleLaunchAtLogin,
                isOn: state.launchAtLoginEnabled
            ),
            MenuBarMenuItemDescriptor(title: "", command: nil, isSeparator: true)
        ]

        descriptors.append(contentsOf: ProvocationStylePreset.allCases.map { preset in
            MenuBarMenuItemDescriptor(
                title: preset.displayName,
                command: .selectStylePreset(preset),
                isOn: preset == state.selectedStylePreset
            )
        })

        descriptors.append(contentsOf: [
            MenuBarMenuItemDescriptor(title: "", command: nil, isSeparator: true),
            MenuBarMenuItemDescriptor(title: MenuBarMenuLabel.quit, command: .quit)
        ])

        return descriptors
    }
}

@MainActor
public extension MenuBarMenuBuilder {
    func makeMenu(
        state: MenuBarMenuState,
        target: AnyObject,
        action: Selector
    ) -> NSMenu {
        let menu = NSMenu()
        for descriptor in makeDescriptors(state: state) {
            if descriptor.isSeparator {
                menu.addItem(.separator())
                continue
            }

            let item = NSMenuItem(title: descriptor.title, action: action, keyEquivalent: "")
            item.target = target
            item.isEnabled = descriptor.isEnabled
            item.state = descriptor.isOn ? .on : .off
            item.representedObject = descriptor.command?.menuToken
            menu.addItem(item)
        }
        return menu
    }
}

private extension MenuBarCommand {
    var menuToken: String {
        switch self {
        case .generate:
            return "generate"
        case .openSettings:
            return "openSettings"
        case .openOnboardingGuide:
            return "openOnboardingGuide"
        case .toggleLaunchAtLogin:
            return "toggleLaunchAtLogin"
        case .selectStylePreset(let preset):
            return "stylePreset:\(preset.rawValue)"
        case .quit:
            return "quit"
        }
    }
}

public extension MenuBarCommand {
    init?(menuToken: String) {
        switch menuToken {
        case "generate":
            self = .generate
        case "openSettings":
            self = .openSettings
        case "openOnboardingGuide":
            self = .openOnboardingGuide
        case "toggleLaunchAtLogin":
            self = .toggleLaunchAtLogin
        case "quit":
            self = .quit
        default:
            let prefix = "stylePreset:"
            guard menuToken.hasPrefix(prefix) else {
                return nil
            }

            let rawPreset = String(menuToken.dropFirst(prefix.count))
            guard let preset = ProvocationStylePreset(rawValue: rawPreset) else {
                return nil
            }

            self = .selectStylePreset(preset)
        }
    }
}
