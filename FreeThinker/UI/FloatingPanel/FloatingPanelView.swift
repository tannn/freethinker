import SwiftUI

public struct FloatingPanelView: View {
    @ObservedObject private var viewModel: FloatingPanelViewModel
    @FocusState private var focusedControl: FocusedControl?

    private enum FocusedControl: Hashable {
        case primaryAction
    }

    public init(viewModel: FloatingPanelViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FloatingPanelDesignTokens.wideSpacing) {
            header
            bodyContent
            footer
        }
        .padding(FloatingPanelDesignTokens.wideSpacing)
        .frame(minWidth: 360, idealWidth: 420, maxWidth: 440)
        .background(
            RoundedRectangle(cornerRadius: FloatingPanelDesignTokens.cornerRadius, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: FloatingPanelDesignTokens.cornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .accessibilityIdentifier(FloatingPanelAccessibility.Identifier.panel)
        .onAppear {
            focusedControl = .primaryAction
        }
        .onExitCommand {
            viewModel.closePanel()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: FloatingPanelDesignTokens.compactSpacing) {
            Label(FloatingPanelAccessibility.Label.panelTitle, systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            if let copyFeedback = viewModel.copyFeedback {
                Text(copyFeedback)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
                    .accessibilityIdentifier(FloatingPanelAccessibility.Identifier.feedbackLabel)
            }

            pinButton
            closeButton
        }
    }

    @ViewBuilder
    private var bodyContent: some View {
        switch viewModel.state {
        case .idle:
            Text("Select text and trigger FreeThinker to generate a provocation.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

        case let .loading(selectedTextPreview):
            VStack(alignment: .leading, spacing: FloatingPanelDesignTokens.regularSpacing) {
                FloatingPanelLoadingView()

                if let selectedTextPreview {
                    Text("Source: \(selectedTextPreview)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

        case let .success(response):
            if let content = response.content {
                FloatingPanelResponseCard(content: content)
            } else {
                FloatingPanelErrorCallout(message: FreeThinkerError.invalidResponse.userMessage)
            }

        case let .error(message):
            FloatingPanelErrorCallout(message: message)
        }
    }

    private var footer: some View {
        HStack(spacing: FloatingPanelDesignTokens.regularSpacing) {
            Button("Copy") {
                viewModel.copyCurrentResult()
            }
            .keyboardShortcut("c", modifiers: [.command])
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canCopy)
            .accessibilityIdentifier(FloatingPanelAccessibility.Identifier.copyButton)
            .accessibilityLabel(FloatingPanelAccessibility.Label.copy)
            .accessibilityHint(FloatingPanelAccessibility.Hint.copy)

            Button("Regenerate") {
                viewModel.requestRegenerate()
            }
            .keyboardShortcut("r", modifiers: [.command])
            .buttonStyle(.bordered)
            .disabled(!viewModel.canRegenerate)
            .focused($focusedControl, equals: .primaryAction)
            .accessibilityIdentifier(FloatingPanelAccessibility.Identifier.regenerateButton)
            .accessibilityLabel(FloatingPanelAccessibility.Label.regenerate)
            .accessibilityHint(FloatingPanelAccessibility.Hint.regenerate)

            Spacer()
        }
    }

    private var pinButton: some View {
        Button {
            viewModel.togglePin()
        } label: {
            Image(systemName: viewModel.isPinned ? "pin.fill" : "pin")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("p", modifiers: [.command])
        .accessibilityIdentifier(FloatingPanelAccessibility.Identifier.pinButton)
        .accessibilityLabel(viewModel.isPinned ? FloatingPanelAccessibility.Label.unpin : FloatingPanelAccessibility.Label.pin)
        .accessibilityHint(viewModel.isPinned ? FloatingPanelAccessibility.Hint.unpin : FloatingPanelAccessibility.Hint.pin)
    }

    private var closeButton: some View {
        Button {
            viewModel.closePanel()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.escape, modifiers: [])
        .accessibilityIdentifier(FloatingPanelAccessibility.Identifier.closeButton)
        .accessibilityLabel(FloatingPanelAccessibility.Label.close)
        .accessibilityHint(FloatingPanelAccessibility.Hint.close)
    }
}
