import AppKit
import Combine
import Foundation

/// Manages the macOS menu bar status item and dispatches menu commands.
///
/// `MenuBarCoordinator` installs and removes the `NSStatusItem`, rebuilds its `NSMenu`
/// whenever app state changes, and routes selected menu items to the appropriate handler.
/// It is `@MainActor`-isolated because all `NSStatusBar` and `NSMenu` APIs must run on the
/// main thread.
@MainActor
public final class MenuBarCoordinator: NSObject {
    /// Called when the user selects "Open Settings" from the menu.
    public var onOpenSettings: (() -> Void)?
    /// Called when the user selects "Open Onboarding Guide" from the menu.
    public var onOpenOnboardingGuide: (() -> Void)?
    /// Called when the user selects "Quit" from the menu.
    ///
    /// If `nil`, `NSApp.terminate(nil)` is called directly.
    public var onQuit: (() -> Void)?

    /// The currently installed status item, or `nil` if the icon is hidden.
    public private(set) var statusItem: NSStatusItem?

    private let appState: AppState
    private let orchestrator: any ProvocationOrchestrating
    private let menuBuilder: MenuBarMenuBuilder

    private var cancellables: Set<AnyCancellable> = []

    public init(
        appState: AppState,
        orchestrator: any ProvocationOrchestrating,
        menuBuilder: MenuBarMenuBuilder = MenuBarMenuBuilder()
    ) {
        self.appState = appState
        self.orchestrator = orchestrator
        self.menuBuilder = menuBuilder
        super.init()

        bindState()
    }

    /// Adds the FreeThinker sparkle icon to the system menu bar if it is not already present.
    ///
    /// Calling this method when a status item already exists is a no-op.
    public func installStatusItemIfNeeded() {
        guard statusItem == nil else {
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "FreeThinker")
        item.menu = makeMenu()

        statusItem = item
        Logger.info("Installed menu bar status item", category: .menuBar)
    }

    /// Removes the FreeThinker status item from the menu bar.
    ///
    /// Calling this method when no status item is installed is a no-op.
    public func uninstallStatusItem() {
        guard let statusItem else {
            return
        }

        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
        Logger.info("Removed menu bar status item", category: .menuBar)
    }

    public func perform(_ command: MenuBarCommand) {
        switch command {
        case .generate:
            Task {
                _ = await orchestrator.trigger(source: .menu, regenerateFromResponseID: nil)
            }

        case .setStylePresetContrarian:
            Task {
                await appState.setProvocationStylePreset(.contrarian)
            }

        case .setStylePresetSocratic:
            Task {
                await appState.setProvocationStylePreset(.socratic)
            }

        case .setStylePresetSystemsThinking:
            Task {
                await appState.setProvocationStylePreset(.systemsThinking)
            }

        case .openSettings:
            onOpenSettings?()

        case .openOnboardingGuide:
            onOpenOnboardingGuide?()

        case .toggleLaunchAtLogin:
            toggleLaunchAtLogin()

        case .selectStylePreset(let preset):
            Task {
                await appState.setProvocationStylePreset(preset)
            }

        case .quit:
            if let onQuit {
                onQuit()
            } else {
                NSApp.terminate(nil)
            }
        }
    }

    public func currentMenuDescriptors() -> [MenuBarMenuItemDescriptor] {
        menuBuilder.makeDescriptors(state: menuState())
    }

    @objc
    public func handleMenuItemAction(_ sender: NSMenuItem) {
        guard
            let raw = sender.representedObject as? String,
            let command = MenuBarCommand(menuToken: raw)
        else {
            return
        }

        perform(command)
    }
}

private extension MenuBarCoordinator {
    func bindState() {
        appState.$isGenerating
            .combineLatest(appState.$settings)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.reloadMenu()
            }
            .store(in: &cancellables)
    }

    func menuState() -> MenuBarMenuState {
        MenuBarMenuState(
            isGenerating: appState.isGenerating,
            launchAtLoginEnabled: appState.settings.launchAtLogin,
            selectedStylePreset: appState.settings.provocationStylePreset
        )
    }

    func makeMenu() -> NSMenu {
        menuBuilder.makeMenu(
            state: menuState(),
            target: self,
            action: #selector(handleMenuItemAction(_:))
        )
    }

    func reloadMenu() {
        statusItem?.menu = makeMenu()
    }

    func toggleLaunchAtLogin() {
        let targetState = !appState.settings.launchAtLogin
        Task {
            await appState.setLaunchAtLoginEnabled(targetState)
        }
    }
}
