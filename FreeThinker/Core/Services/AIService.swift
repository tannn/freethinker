import Foundation

public protocol AIServiceProtocol: Actor, Sendable {
    var isAvailable: Bool { get }
    var currentModel: ModelOption { get }

    func setCurrentModel(_ model: ModelOption)
    func preloadModel() async throws
    func generateProvocation(request: ProvocationRequest, settings: AppSettings) async -> ProvocationResponse
}

public struct FoundationGenerationOptions: Equatable, Sendable {
    public var model: ModelOption
    public var maximumOutputCharacters: Int

    public init(model: ModelOption, maximumOutputCharacters: Int = 700) {
        self.model = model
        self.maximumOutputCharacters = maximumOutputCharacters
    }
}

public enum FoundationModelAvailability: Equatable, Sendable {
    case available
    case unsupportedOperatingSystem
    case unsupportedHardware
    case frameworkUnavailable
    case modelUnavailable
}

public protocol FoundationModelsAdapterProtocol: Sendable {
    func availability() -> FoundationModelAvailability
    func preload(model: ModelOption) async throws
    func generate(prompt: String, options: FoundationGenerationOptions) async throws -> String
}

public protocol ProvocationPromptComposing: Sendable {
    func composePrompt(for request: ProvocationRequest, settings: AppSettings) -> String
    func composeFollowUpPrompt(
        for request: ProvocationRequest,
        previousResponse: ProvocationContent,
        settings: AppSettings
    ) -> String
}

public protocol ProvocationResponseParsing: Sendable {
    func parse(rawOutput: String) throws -> ProvocationContent
}
