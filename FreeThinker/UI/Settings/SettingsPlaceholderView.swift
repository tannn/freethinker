import SwiftUI

struct SettingsPlaceholderView: View {
    let container: AppContainer

    @State private var settings: AppSettings = .defaultValue
    @State private var statusMessage = "Loading settings..."

    var body: some View {
        Form {
            Toggle("Enable global hotkey", isOn: $settings.hotkeyEnabled)
                .onChange(of: settings.hotkeyEnabled) { _, _ in
                    persistSettings()
                }

            Toggle("Launch at login", isOn: $settings.launchAtLogin)
                .onChange(of: settings.launchAtLogin) { _, _ in
                    persistSettings()
                }

            Picker("Panel behavior", selection: $settings.panelBehavior) {
                ForEach(AppSettings.PanelBehavior.allCases, id: \.self) { behavior in
                    Text(behavior.displayName)
                        .tag(behavior)
                }
            }
            .onChange(of: settings.panelBehavior) { _, _ in
                persistSettings()
            }

            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 420)
        .task {
            await loadSettings()
        }
    }

    @MainActor
    private func loadSettings() async {
        switch await container.settingsService.load() {
        case let .success(loadedSettings):
            settings = loadedSettings
            statusMessage = "Settings loaded"
        case let .failure(error):
            statusMessage = error.localizedDescription
        }
    }

    private func persistSettings() {
        Task { @MainActor in
            switch await container.settingsService.save(settings) {
            case .success:
                statusMessage = "Settings saved"
            case let .failure(error):
                statusMessage = error.localizedDescription
            }

            switch await container.setLaunchAtLogin(settings.launchAtLogin) {
            case .success:
                break
            case let .failure(error):
                statusMessage = error.localizedDescription
            }
        }
    }
}
