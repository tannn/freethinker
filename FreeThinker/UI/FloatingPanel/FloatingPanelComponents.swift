import SwiftUI

/// Design constants shared across all floating panel views.
///
/// Centralising these values ensures visual consistency and makes global
/// adjustments (e.g. spacing, corner radius) a single-site change.
public enum FloatingPanelDesignTokens {
    public static let cornerRadius: CGFloat = 16
    public static let compactSpacing: CGFloat = 8
    public static let regularSpacing: CGFloat = 12
    public static let wideSpacing: CGFloat = 16
    public static let maxBodyHeight: CGFloat = 220
}

/// A loading placeholder shown while the AI generates a provocation.
///
/// Displays a circular progress indicator and a message that names the
/// active style preset so the user knows what kind of response to expect.
public struct FloatingPanelLoadingView: View {
    private let styleDisplayName: String

    /// Creates a loading view for the given style preset.
    ///
    /// - Parameter styleDisplayName: The display name of the active style preset.
    ///   The name is lowercased before display.
    public init(styleDisplayName: String) {
        self.styleDisplayName = styleDisplayName.lowercased()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FloatingPanelDesignTokens.regularSpacing) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.accentColor)
                .controlSize(.regular)
                .accessibilityIdentifier(FloatingPanelAccessibility.Identifier.loadingIndicator)
                .accessibilityLabel(FloatingPanelAccessibility.Label.loading)

            Text("Generating a \(styleDisplayName) perspective…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A scrollable card that renders the body and optional follow-up question from a provocation response.
///
/// Tapping the card copies its content when `canCopy` is `true` by invoking `onCopyRequested`.
public struct FloatingPanelResponseCard: View {
    private let content: ProvocationContent
    private let canCopy: Bool
    private let onCopyRequested: () -> Void

    /// Creates a response card.
    ///
    /// - Parameters:
    ///   - content: The provocation content to render.
    ///   - canCopy: Whether tapping the card should trigger a copy. Defaults to `true`.
    ///   - onCopyRequested: Closure called when the user taps the card and `canCopy` is `true`.
    public init(
        content: ProvocationContent,
        canCopy: Bool = true,
        onCopyRequested: @escaping () -> Void = {}
    ) {
        self.content = content
        self.canCopy = canCopy
        self.onCopyRequested = onCopyRequested
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FloatingPanelDesignTokens.regularSpacing) {

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
            .accessibilityIdentifier(FloatingPanelAccessibility.Identifier.copyTarget)
            .accessibilityLabel(FloatingPanelAccessibility.Label.copyTarget)
            .accessibilityHint(FloatingPanelAccessibility.Hint.copyTarget)
            .accessibilityAddTraits(.isButton)
        }
        .contentShape(Rectangle())
        .highPriorityGesture(
            TapGesture().onEnded {
                guard canCopy else {
                    return
                }
                onCopyRequested()
            },
            including: .all
        )
        .frame(maxHeight: FloatingPanelDesignTokens.maxBodyHeight)
        .accessibilityIdentifier(FloatingPanelAccessibility.Identifier.responseCard)
    }
}

/// An inline error callout that displays a failure message and an optional remediation hint.
///
/// Rendered with a red tinted background to draw the user's attention to the failure state.
public struct FloatingPanelErrorCallout: View {
    private let message: String
    private let suggestedAction: String?

    /// Creates an error callout.
    ///
    /// - Parameters:
    ///   - message: A localised description of the error.
    ///   - suggestedAction: An optional follow-up action the user can take to recover.
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
