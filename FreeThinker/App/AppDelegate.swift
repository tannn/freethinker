import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let container = AppContainer()
    private var menuBarCoordinator: MenuBarCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.lifecycle.info("Application finished launching.")

        let coordinator = MenuBarCoordinator(container: container)
        coordinator.start()
        menuBarCoordinator = coordinator

        Task {
            await container.appState.loadIfNeeded()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppLog.lifecycle.info("Application will terminate.")
    }
}
