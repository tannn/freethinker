import AppKit
import SwiftUI

public struct AccessibilityHelpSettingsView: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Accessibility Help")
                    .font(.title2.weight(.semibold))

                Text("FreeThinker needs Accessibility permission to read selected text from other apps.")
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Open System Settings.")
                    Text("2. Go to Privacy & Security.")
                    Text("3. Select Accessibility.")
                    Text("4. Enable FreeThinker in the app list.")
                    Text("5. Re-trigger Cmd+Shift+P.")
                }
                .font(.body.monospacedDigit())

                Button("Open Accessibility Settings") {
                    openAccessibilitySettings()
                }
                .buttonStyle(.borderedProminent)

                Text("If FreeThinker does not appear in the list, restart the app after granting permission.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

private extension AccessibilityHelpSettingsView {
    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
