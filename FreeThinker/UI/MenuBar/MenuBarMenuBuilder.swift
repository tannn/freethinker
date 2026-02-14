import AppKit
import Foundation

public enum MenuBarCommand: String, Sendable {
    case generate
    case setStylePresetContrarian
    case setStylePresetSocratic
    case setStylePresetSystemsThinking
    case openSettings
    case openOnboardingGuide
    case toggleLaunchAtLogin
    case quit
}

public enum MenuBarMenuLabel {
    public static let generate = "Generate Provocation"
    public static let styleContrarian = "Style: Contrarian"
    public static let styleSocratic = "Style: Socratic"
    public static let styleSystemsThinking = "Style: Systems Thinking"
    public static let settings = "Settings..."
    public static let onboardingGuide = "Onboarding Guide..."
    public static let launchAtLogin = "Launch at Login"
    public static let quit = "Quit FreeThinker"
}

public struct MenuBarMenuState: Equatable, Sendable {
    public var isGenerating: Bool
    public var selectedStylePreset: ProvocationStylePreset
    public var launchAtLoginEnabled: Bool

    public init(
        isGenerating: Bool,
        selectedStylePreset: ProvocationStylePreset,
        launchAtLoginEnabled: Bool
    ) {
        self.isGenerating = isGenerating
        self.selectedStylePreset = selectedStylePreset
        self.launchAtLoginEnabled = launchAtLoginEnabled
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
        [
            MenuBarMenuItemDescriptor(
                title: MenuBarMenuLabel.generate,
                command: .generate,
                isEnabled: !state.isGenerating
            ),
            MenuBarMenuItemDescriptor(title: "", command: nil, isSeparator: true),
            MenuBarMenuItemDescriptor(
                title: MenuBarMenuLabel.styleContrarian,
                command: .setStylePresetContrarian,
                isOn: state.selectedStylePreset == .contrarian
            ),
            MenuBarMenuItemDescriptor(
                title: MenuBarMenuLabel.styleSocratic,
                command: .setStylePresetSocratic,
                isOn: state.selectedStylePreset == .socratic
            ),
            MenuBarMenuItemDescriptor(
                title: MenuBarMenuLabel.styleSystemsThinking,
                command: .setStylePresetSystemsThinking,
                isOn: state.selectedStylePreset == .systemsThinking
            ),
            MenuBarMenuItemDescriptor(title: "", command: nil, isSeparator: true),
            MenuBarMenuItemDescriptor(title: MenuBarMenuLabel.settings, command: .openSettings),
            MenuBarMenuItemDescriptor(title: MenuBarMenuLabel.onboardingGuide, command: .openOnboardingGuide),
            MenuBarMenuItemDescriptor(
                title: MenuBarMenuLabel.launchAtLogin,
                command: .toggleLaunchAtLogin,
                isOn: state.launchAtLoginEnabled
            ),
            MenuBarMenuItemDescriptor(title: "", command: nil, isSeparator: true),
            MenuBarMenuItemDescriptor(title: MenuBarMenuLabel.quit, command: .quit)
        ]
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
            item.representedObject = descriptor.command?.rawValue
            menu.addItem(item)
        }
        return menu
    }
}
