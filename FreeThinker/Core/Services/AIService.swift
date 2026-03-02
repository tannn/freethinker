import Foundation

/// Protocol defining the interface for an AI service that generates provocations.
///
/// Conforming types are actors to ensure safe concurrent access. All methods
/// must be called within an async context and support Swift structured concurrency.
public protocol AIServiceProtocol: Actor, Sendable {
    /// Whether the underlying AI model is currently available on this device.
    var isAvailable: Bool { get }

    /// The model currently selected for generation.
    var currentModel: ModelOption { get }

    /// Updates the selected model for future generation requests.
    ///
    /// - Parameter model: The model to use for subsequent ``generateProvocation(request:settings:)`` calls.
    func setCurrentModel(_ model: ModelOption)

    /// Warms up the model so the first generation request completes faster.
    ///
    /// Call this during app startup or after changing ``currentModel``.
    /// Throws if the model cannot be loaded (e.g., hardware unsupported).
    func preloadModel() async throws

    /// Generates a provocation response for the given request and settings.
    ///
    /// This method never throws; all errors are encoded into the returned
    /// ``ProvocationResponse`` via ``ProvocationOutcome/failure(error:)``.
    ///
    /// - Parameters:
    ///   - request: The provocation request containing the selected text and type.
    ///   - settings: Current app settings controlling model, timeout, and style.
    /// - Returns: A ``ProvocationResponse`` containing either generated content or an error.
    func generateProvocation(request: ProvocationRequest, settings: AppSettings) async -> ProvocationResponse
}

/// Options controlling how the Foundation Models framework generates text.
public struct FoundationGenerationOptions: Equatable, Sendable {
    /// The model variant to use for generation.
    public var model: ModelOption

    /// The maximum number of characters the model may output.
    ///
    /// Defaults to 700 characters, which is enough for a BODY + FOLLOW_UP response.
    public var maximumOutputCharacters: Int

    /// Creates generation options with the specified model and output limit.
    ///
    /// - Parameters:
    ///   - model: The model variant to use.
    ///   - maximumOutputCharacters: Output character budget. Defaults to `700`.
    public init(model: ModelOption, maximumOutputCharacters: Int = 700) {
        self.model = model
        self.maximumOutputCharacters = maximumOutputCharacters
    }
}

/// Describes the availability of the Foundation Models framework on the current device.
public enum FoundationModelAvailability: Equatable, Sendable {
    /// The model is ready for use.
    case available
    /// The operating system version does not support the framework.
    case unsupportedOperatingSystem
    /// The device hardware (e.g., non-Apple Silicon) cannot run on-device models.
    case unsupportedHardware
    /// The framework binary is not present in this build configuration.
    case frameworkUnavailable
    /// The specific model variant is not available or has not been downloaded.
    case modelUnavailable
}

/// Protocol abstracting the Foundation Models framework for testability.
///
/// Conforming types wrap platform-specific APIs so that ``DefaultAIService``
/// can be tested without requiring actual on-device inference.
public protocol FoundationModelsAdapterProtocol: Sendable {
    /// Returns the current availability of the Foundation Models framework.
    func availability() -> FoundationModelAvailability

    /// Warms up the specified model, blocking until it is ready to generate.
    ///
    /// - Parameter model: The model variant to preload.
    /// - Throws: ``FreeThinkerError/modelUnavailable`` or related errors if loading fails.
    func preload(model: ModelOption) async throws

    /// Generates text from the given prompt using the specified options.
    ///
    /// - Parameters:
    ///   - prompt: The instruction and context string sent to the model.
    ///   - options: Generation parameters including model variant and output limit.
    /// - Returns: The raw text output from the model.
    /// - Throws: ``FreeThinkerError`` variants on failure, or `CancellationError` if cancelled.
    func generate(prompt: String, options: FoundationGenerationOptions) async throws -> String
}

/// Protocol for composing the prompt strings sent to the AI model.
///
/// Implementations are value types (`Sendable`) so they can be captured safely
/// by the actor-isolated ``DefaultAIService``.
public protocol ProvocationPromptComposing: Sendable {
    /// Composes the initial prompt for a provocation request.
    ///
    /// - Parameters:
    ///   - request: The provocation request specifying text and type.
    ///   - settings: App settings that influence style and prompt templates.
    /// - Returns: A fully-formatted prompt string ready for model inference.
    func composePrompt(for request: ProvocationRequest, settings: AppSettings) -> String

    /// Composes a follow-up prompt that generates a distinctly different provocation.
    ///
    /// Used during regeneration to avoid repeating the previous response.
    ///
    /// - Parameters:
    ///   - request: The original provocation request.
    ///   - previousResponse: The content from the prior generation to avoid duplicating.
    ///   - settings: App settings controlling style.
    /// - Returns: A prompt string instructing the model to produce a different result.
    func composeFollowUpPrompt(
        for request: ProvocationRequest,
        previousResponse: ProvocationContent,
        settings: AppSettings
    ) -> String
}

/// Protocol for parsing raw model output into structured ``ProvocationContent``.
///
/// Implementations are value types (`Sendable`) so they can be captured safely
/// by the actor-isolated ``DefaultAIService``.
public protocol ProvocationResponseParsing: Sendable {
    /// Parses raw text output from the model into structured content.
    ///
    /// - Parameter rawOutput: The unstructured string returned by the model.
    /// - Returns: A ``ProvocationContent`` with a `body` and optional `followUpQuestion`.
    /// - Throws: ``FreeThinkerError/invalidResponse`` if the output cannot be parsed,
    ///   or ``FreeThinkerError/generationFailed`` if the output is empty.
    func parse(rawOutput: String) throws -> ProvocationContent
}
