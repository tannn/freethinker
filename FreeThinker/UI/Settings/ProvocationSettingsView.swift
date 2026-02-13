import SwiftUI

public struct ProvocationSettingsView: View {
    @ObservedObject private var appState: AppState
    @State private var draftCustomInstructions: String
    @State private var persistTask: Task<Void, Never>?
    @FocusState private var isCustomInstructionEditorFocused: Bool

    public init(appState: AppState) {
        self.appState = appState
        _draftCustomInstructions = State(initialValue: appState.settings.customStyleInstructions)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Provocation")
                    .font(.title2.weight(.semibold))

                GroupBox("Style") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Style preset", selection: stylePresetBinding) {
                            ForEach(ProvocationStylePreset.allCases) { preset in
                                Text(presetTitle(for: preset))
                                    .tag(preset)
                            }
                        }
                        .accessibilityIdentifier(SettingsAccessibility.Identifier.provocationPresetPicker)

                        Text(appState.settings.provocationStylePreset.instruction)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Custom Instructions") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextEditor(text: $draftCustomInstructions)
                            .frame(minHeight: 160)
                            .font(.body)
                            .focused($isCustomInstructionEditorFocused)
                            .accessibilityIdentifier(SettingsAccessibility.Identifier.provocationCustomInstructionEditor)
                            .onChange(of: draftCustomInstructions) { newValue in
                                scheduleCustomInstructionPersistence(newValue)
                            }

                        HStack {
                            Text("\(draftCustomInstructions.count)/\(AppSettings.maxCustomInstructionLength)")
                                .font(.footnote.monospacedDigit())
                                .foregroundStyle(isOverCustomInstructionLimit ? .orange : .secondary)
                                .accessibilityIdentifier(SettingsAccessibility.Identifier.provocationCharacterCount)

                            Spacer()

                            Button("Reset to Defaults") {
                                persistTask?.cancel()
                                persistTask = nil
                                draftCustomInstructions = ""
                                Task {
                                    await appState.resetProvocationStyleCustomization()
                                }
                            }
                            .disabled(
                                appState.settings.provocationStylePreset == .socratic &&
                                appState.settings.customStyleInstructions.isEmpty
                            )
                            .accessibilityIdentifier(SettingsAccessibility.Identifier.provocationResetButton)
                        }

                        if isOverCustomInstructionLimit {
                            Text("Limit is \(AppSettings.maxCustomInstructionLength) characters. Extra text is trimmed when saved.")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }

                        if containsNullCharacter {
                            Text("Unsupported control characters will be sanitized automatically.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text("Tip: keep custom instructions short and concrete for more stable outputs.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onChange(of: appState.settings.customStyleInstructions) { newValue in
            guard !isCustomInstructionEditorFocused else {
                return
            }
            guard newValue != draftCustomInstructions else {
                return
            }
            draftCustomInstructions = newValue
        }
        .onDisappear {
            persistTask?.cancel()
            persistTask = nil
            Task {
                await appState.setCustomStyleInstructions(draftCustomInstructions)
            }
        }
    }
}

private extension ProvocationSettingsView {
    var stylePresetBinding: Binding<ProvocationStylePreset> {
        Binding(
            get: { appState.settings.provocationStylePreset },
            set: { preset in
                Task {
                    await appState.setProvocationStylePreset(preset)
                }
            }
        )
    }

    var isOverCustomInstructionLimit: Bool {
        draftCustomInstructions.count > AppSettings.maxCustomInstructionLength
    }

    var containsNullCharacter: Bool {
        draftCustomInstructions.contains("\0")
    }

    func presetTitle(for preset: ProvocationStylePreset) -> String {
        switch preset {
        case .contrarian:
            return "Contrarian"
        case .socratic:
            return "Socratic"
        case .systemsThinking:
            return "Systems Thinking"
        }
    }

    func scheduleCustomInstructionPersistence(_ value: String) {
        persistTask?.cancel()
        persistTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await appState.setCustomStyleInstructions(value)
        }
    }
}
