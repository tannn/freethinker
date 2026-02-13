import AppKit
import Combine
import Foundation

public protocol PanelPinningStore: Sendable {
    func loadPinnedState() -> Bool
    func savePinnedState(_ isPinned: Bool)
}

public final class UserDefaultsPanelPinningStore: PanelPinningStore, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let key: String

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = "floating_panel.is_pinned"
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    public func loadPinnedState() -> Bool {
        userDefaults.object(forKey: key) as? Bool ?? false
    }

    public func savePinnedState(_ isPinned: Bool) {
        userDefaults.set(isPinned, forKey: key)
    }
}

@MainActor
public final class AppState: ObservableObject {
    @Published public private(set) var settings: AppSettings
    @Published public private(set) var isGenerating: Bool = false

    public let panelViewModel: FloatingPanelViewModel

    public var onRegenerateRequested: ((_ regenerateFromResponseID: UUID?) async -> Void)?
    public var onCloseRequested: (() -> Void)?
    public var onSettingsUpdated: ((AppSettings) -> Void)?

    private let pinningStore: any PanelPinningStore
    private var panelController: FloatingPanelController?

    public init(
        settings: AppSettings = AppSettings(),
        pinningStore: any PanelPinningStore = UserDefaultsPanelPinningStore(),
        timing: any FloatingPanelTiming = SystemFloatingPanelTiming(),
        pasteboardWriter: ((String) -> Void)? = nil
    ) {
        let validatedSettings = settings.validated()

        let resolvedPasteboardWriter: (String) -> Void = pasteboardWriter ?? { text in
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }

        self.settings = validatedSettings
        self.pinningStore = pinningStore

        panelViewModel = FloatingPanelViewModel(
            isPinned: pinningStore.loadPinnedState(),
            dismissOnCopy: validatedSettings.dismissOnCopy,
            timing: timing,
            pasteboardWriter: resolvedPasteboardWriter
        )

        panelViewModel.onPinStateChanged = { [weak self] isPinned in
            self?.pinningStore.savePinnedState(isPinned)
        }

        panelViewModel.onRegenerateRequested = { [weak self] responseID in
            await self?.onRegenerateRequested?(responseID)
        }

        panelViewModel.onCloseRequested = { [weak self] in
            self?.onCloseRequested?()
            self?.panelController?.hide()
        }
    }

    public func attachPanelController(_ controller: FloatingPanelController) {
        panelController = controller
    }

    public func presentLoading(selectedText: String? = nil) {
        isGenerating = true
        panelViewModel.setLoading(selectedTextPreview: selectedText)
        panelController?.show()
    }

    public func present(response: ProvocationResponse) {
        isGenerating = false
        panelController?.show()

        if case .success = response.outcome {
            panelViewModel.setSuccess(response)
            return
        }

        panelViewModel.setError(response.error ?? .generationFailed)
    }

    public func presentError(_ error: FreeThinkerError) {
        isGenerating = false
        panelController?.show()
        panelViewModel.setError(error)
    }

    public func presentErrorPresentation(_ presentation: ErrorPresentation) {
        isGenerating = false
        panelController?.show()
        panelViewModel.setErrorPresentation(presentation)
    }

    public func presentErrorMessage(_ message: String) {
        isGenerating = false
        panelController?.show()
        panelViewModel.setErrorMessage(message)
    }

    public func dismissPanel() {
        isGenerating = false
        panelViewModel.setIdle()
        panelController?.hide()
    }

    public func updateSettings(_ settings: AppSettings) {
        self.settings = settings.validated()
        panelViewModel.dismissOnCopy = self.settings.dismissOnCopy
        onSettingsUpdated?(self.settings)
    }

    public func setGenerating(_ isGenerating: Bool) {
        self.isGenerating = isGenerating
    }

    public var isPanelVisible: Bool {
        panelController?.panel.isVisible ?? false
    }
}
