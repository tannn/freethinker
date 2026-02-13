import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

public actor FoundationModelsAdapter: FoundationModelsAdapterProtocol {
    private var cachedModelOption: ModelOption?

#if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private var model: SystemLanguageModel?
    @available(macOS 26.0, *)
    private var session: LanguageModelSession?
#endif

    public init() {}

    public nonisolated func availability() -> FoundationModelAvailability {
        if #unavailable(macOS 26.0) {
            return .unsupportedOperatingSystem
        }

#if !arch(arm64)
        return .unsupportedHardware
#endif

#if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                return .available
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible:
                    return .unsupportedHardware
                case .appleIntelligenceNotEnabled, .modelNotReady:
                    return .modelUnavailable
                @unknown default:
                    return .modelUnavailable
                }
            }
        }
        return .unsupportedOperatingSystem
#else
        return .frameworkUnavailable
#endif
    }

    public func preload(model option: ModelOption) async throws {
        try ensureAvailable()

        if cachedModelOption == option {
            return
        }

        Logger.info("Preloading on-device model option=\(option.rawValue)", category: .foundationModels)

#if canImport(FoundationModels)
        guard #available(macOS 26.0, *) else {
            throw FreeThinkerError.unsupportedOperatingSystem
        }

        let selectedModel = makeSystemModel(for: option)
        guard selectedModel.isAvailable else {
            throw FreeThinkerError.modelUnavailable
        }

        self.model = selectedModel
        self.session = LanguageModelSession(model: selectedModel)
        self.cachedModelOption = option
#else
        throw FreeThinkerError.frameworkUnavailable
#endif
    }

    public func generate(prompt: String, options: FoundationGenerationOptions) async throws -> String {
        let normalizedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPrompt.isEmpty else {
            throw FreeThinkerError.invalidPrompt
        }

        try ensureAvailable()
        try await preload(model: options.model)

        Logger.debug(
            "Generating on-device output model=\(options.model.rawValue) promptChars=\(normalizedPrompt.count)",
            category: .foundationModels
        )

#if canImport(FoundationModels)
        guard #available(macOS 26.0, *), let session else {
            throw FreeThinkerError.modelUnavailable
        }

        do {
            let response = try await session.respond(to: normalizedPrompt)
            let trimmed = String(response.content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).prefix(options.maximumOutputCharacters))
            guard !trimmed.isEmpty else {
                throw FreeThinkerError.generationFailed
            }
            return trimmed
        } catch is CancellationError {
            throw FreeThinkerError.cancelled
        } catch {
            throw mapModelError(error)
        }
#else
        throw FreeThinkerError.frameworkUnavailable
#endif
    }
}

private extension FoundationModelsAdapter {
    func ensureAvailable() throws {
        switch availability() {
        case .available:
            return
        case .unsupportedOperatingSystem:
            throw FreeThinkerError.unsupportedOperatingSystem
        case .unsupportedHardware:
            throw FreeThinkerError.unsupportedHardware
        case .frameworkUnavailable:
            throw FreeThinkerError.frameworkUnavailable
        case .modelUnavailable:
            throw FreeThinkerError.modelUnavailable
        }
    }

#if canImport(FoundationModels)
    @available(macOS 26.0, *)
    func makeSystemModel(for option: ModelOption) -> SystemLanguageModel {
        switch option {
        case .default:
            return .default
        case .creativeWriting:
            return SystemLanguageModel(
                useCase: .general,
                guardrails: .permissiveContentTransformations
            )
        }
    }
#endif

    func mapModelError(_ error: Error) -> FreeThinkerError {
        if let typed = error as? FreeThinkerError {
            return typed
        }

        let description = (error as NSError).localizedDescription.lowercased()
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *), let generationError = error as? LanguageModelSession.GenerationError {
            switch generationError {
            case .assetsUnavailable, .rateLimited, .concurrentRequests:
                return .transientModelFailure
            default:
                break
            }
        }
        #endif
        if description.contains("temporar") || description.contains("busy") || description.contains("warm") {
            return .transientModelFailure
        }
        return .generationFailed
    }
}
