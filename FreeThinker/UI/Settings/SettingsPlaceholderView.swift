import SwiftUI

struct SettingsPlaceholderView: View {
    let appState: AppState

    var body: some View {
        Form {
            Toggle("Enable global hotkey", isOn: Binding(
                get: { appState.settings.hotkeyEnabled },
                set: { enabled in
                    Task {
                        await appState.setHotkeyEnabled(enabled)
                    }
                }
            ))

            Toggle("Launch at login", isOn: Binding(
                get: { appState.launchAtLoginEnabled },
                set: { enabled in
                    Task {
                        await appState.setLaunchAtLogin(enabled)
                    }
                }
            ))

            Picker("Panel behavior", selection: Binding(
                get: { appState.settings.panelBehavior },
                set: { behavior in
                    Task {
                        await appState.setPanelBehavior(behavior)
                    }
                }
            )) {
                ForEach(AppSettings.PanelBehavior.allCases, id: \.self) { behavior in
                    Text(behavior.displayName)
                        .tag(behavior)
                }
            }

            Picker("Provocation style", selection: Binding(
                get: { appState.selectedStyle },
                set: { style in
                    Task {
                        await appState.setProvocationStyle(style)
                    }
                }
            )) {
                ForEach(AppSettings.ProvocationStyle.allCases, id: \.self) { style in
                    Text(style.rawValue.capitalized)
                        .tag(style)
                }
            }

            Button("Reset to defaults") {
                Task {
                    await appState.resetSettingsToDefaults()
                }
            }

            Text(appState.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 420)
        .task {
            await appState.loadIfNeeded()
        }
    }
}
