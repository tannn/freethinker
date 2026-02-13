import AppKit
import Foundation

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public let container: AppContainer

    public override init() {
        self.container = AppContainer()
        super.init()
    }

    public init(container: AppContainer) {
        self.container = container
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        container.start()
    }

    public func applicationDidBecomeActive(_ notification: Notification) {
        container.hotkeyService.refreshRegistration(using: container.appState.settings)
    }

    public func applicationWillTerminate(_ notification: Notification) {
        container.stop()
    }
}
