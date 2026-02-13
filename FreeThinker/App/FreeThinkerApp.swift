import SwiftUI

@main
struct FreeThinkerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsPlaceholderView(appState: appDelegate.container.appState)
                .frame(width: 420)
        }
    }
}
