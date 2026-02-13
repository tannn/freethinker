import AppKit
import Foundation

public enum MenuBarCommand: String, Sendable {
    case generate
    case openSettings
    case openOnboardingGuide
    case toggleLaunchAtLogin
    case checkForUpdates
    case quit
}

public enum MenuBarMenuLabel {
    public static let generate = "Generate Provocation"
    public static let settings = "Settings..."
    public static let onboardingGuide = "Onboarding Guide..."
    public static let launchAtLogin = "Launch at Login"
    public static let checkForUpdates = "Check for Updates"
    public static let quit = "Quit FreeThinker"
}

public struct MenuBarMenuState: Equatable, Sendable {
    public var isGenerating: Bool
    public var launchAtLoginEnabled: Bool

    public init(isGenerating: Bool, launchAtLoginEnabled: Bool) {
        self.isGenerating = isGenerating
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
            MenuBarMenuItemDescriptor(title: MenuBarMenuLabel.settings, command: .openSettings),
            MenuBarMenuItemDescriptor(title: MenuBarMenuLabel.onboardingGuide, command: .openOnboardingGuide),
            MenuBarMenuItemDescriptor(
                title: MenuBarMenuLabel.launchAtLogin,
                command: .toggleLaunchAtLogin,
                isOn: state.launchAtLoginEnabled
            ),
            MenuBarMenuItemDescriptor(title: MenuBarMenuLabel.checkForUpdates, command: .checkForUpdates),
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
