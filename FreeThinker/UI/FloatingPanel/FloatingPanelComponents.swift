import SwiftUI

public enum FloatingPanelDesignTokens {
    public static let cornerRadius: CGFloat = 16
    public static let compactSpacing: CGFloat = 8
    public static let regularSpacing: CGFloat = 12
    public static let wideSpacing: CGFloat = 16
    public static let maxBodyHeight: CGFloat = 220
}

public struct FloatingPanelLoadingView: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: FloatingPanelDesignTokens.regularSpacing) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.accentColor)
                .controlSize(.regular)
                .accessibilityIdentifier(FloatingPanelAccessibility.Identifier.loadingIndicator)
                .accessibilityLabel(FloatingPanelAccessibility.Label.loading)

            Text("Generating a provocative perspective...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public struct FloatingPanelResponseCard: View {
    private let content: ProvocationContent

    public init(content: ProvocationContent) {
        self.content = content
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FloatingPanelDesignTokens.regularSpacing) {
                Text(content.headline)
                    .font(.headline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(content.body)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                if let followUpQuestion = content.followUpQuestion {
                    Divider()
                    Text(followUpQuestion)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: FloatingPanelDesignTokens.maxBodyHeight)
        .accessibilityIdentifier(FloatingPanelAccessibility.Identifier.responseCard)
    }
}

public struct FloatingPanelErrorCallout: View {
    private let message: String
    private let suggestedAction: String?

    public init(message: String, suggestedAction: String? = nil) {
        self.message = message
        self.suggestedAction = suggestedAction
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FloatingPanelDesignTokens.compactSpacing) {
            Label("Could not generate provocation", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let suggestedAction {
                Text(suggestedAction)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(FloatingPanelDesignTokens.regularSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.red.opacity(0.12))
        )
        .accessibilityIdentifier(FloatingPanelAccessibility.Identifier.errorCallout)
        .accessibilityLabel(FloatingPanelAccessibility.Label.error)
        .accessibilityHint(FloatingPanelAccessibility.Hint.error)
    }
}
