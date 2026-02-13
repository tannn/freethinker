import SwiftUI

@main
struct FreeThinkerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsPlaceholderView(container: appDelegate.container)
                .frame(width: 420)
        }
    }
}
