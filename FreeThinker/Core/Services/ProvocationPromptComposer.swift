import Foundation

/// Concrete implementation of ``ProvocationPromptComposing`` that formats the full
/// prompt sent to the Foundation Models framework.
///
/// The prompt structure is:
/// - A system persona line.
/// - A TASK section derived from the request's ``ProvocationType`` and custom prompts.
/// - A STYLE section from the active ``ProvocationStylePreset`` and any custom instructions.
/// - A strict OUTPUT FORMAT specifying BODY and FOLLOW_UP labels.
/// - Rules constraining response length and style.
/// - The sanitised selected text delimited by triple-quotes.
public struct ProvocationPromptComposer: ProvocationPromptComposing, Sendable {
    private static let maxSanitizedTextLength = ProvocationRequest.maxSelectedTextLength

    /// Creates a default `ProvocationPromptComposer`.
    public init() {}

    /// Composes the initial provocation prompt for the given request and settings.
    ///
    /// Settings are validated before use. The selected text is sanitised and truncated.
    ///
    /// - Parameters:
    ///   - request: The provocation request containing the selected text and type.
    ///   - settings: App settings providing prompts, style, and custom instructions.
    /// - Returns: The fully-formatted prompt string.
    public func composePrompt(for request: ProvocationRequest, settings: AppSettings) -> String {
        let normalizedSettings = settings.validated()
        let selectedText = sanitizeSelectedText(request.selectedText, maxLength: Self.maxSanitizedTextLength)
        let baseInstruction = baseInstruction(for: request.provocationType, settings: normalizedSettings)
        let styleInstruction = normalizedSettings.provocationStylePreset.instruction
        let customInstruction = normalizedCustomInstruction(normalizedSettings.customStyleInstructions)

        Logger.debug(
            "Composing prompt type=\(request.provocationType.rawValue) "
                + "style=\(normalizedSettings.provocationStylePreset.rawValue) "
                + "textChars=\(selectedText.count)",
            category: .promptComposer
        )

        return """
        You are a concise critical-thinking copilot.

        TASK:
        \(baseInstruction)

        STYLE:
        \(styleInstruction)
        \(customInstruction)

        OUTPUT FORMAT (exactly these labels, one block each):
        BODY: <1-2 sentences, max 250 chars, plain text>
        FOLLOW_UP: <one optional question, or NONE>

        RULES:
        - Be specific to the provided text
        - No markdown, no bullets, no JSON
        - Keep language direct and thought-provoking
        - Avoid repeating the selected text verbatim
        - Do not be authoritative
        - Avoid overly long or overly complex sentences

        SELECTED_TEXT:
        \"\"\"
        \(selectedText)
        \"\"\"
        """
    }

    /// Composes a follow-up prompt that generates a distinct alternative provocation.
    ///
    /// Includes the previous response's body in the prompt so the model avoids repeating it.
    ///
    /// - Parameters:
    ///   - request: The original provocation request.
    ///   - previousResponse: The prior generation result to avoid duplicating.
    ///   - settings: App settings controlling style.
    /// - Returns: A prompt string instructing the model to produce a different result.
    public func composeFollowUpPrompt(
        for request: ProvocationRequest,
        previousResponse: ProvocationContent,
        settings: AppSettings
    ) -> String {
        let normalizedSettings = settings.validated()
        let selectedText = sanitizeSelectedText(request.selectedText, maxLength: Self.maxSanitizedTextLength)
        let styleInstruction = normalizedSettings.provocationStylePreset.instruction

        return """
        Generate a distinctly different provocation for the same text.

        STYLE:
        \(styleInstruction)
        \(normalizedCustomInstruction(normalizedSettings.customStyleInstructions))

        AVOID DUPLICATING THIS PRIOR OUTPUT:
        BODY: \(previousResponse.body)

        OUTPUT FORMAT:
        BODY: <1-2 sentences, max 250 chars, plain text>
        FOLLOW_UP: <one optional question, or NONE>

        SELECTED_TEXT:
        \"\"\"
        \(selectedText)
        \"\"\"
        """
    }
}

extension ProvocationPromptComposer {
    func sanitizeSelectedText(_ text: String, maxLength: Int) -> String {
        var sanitized = text
            .replacingOccurrences(of: "\0", with: " ")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        sanitized = sanitized
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")

        while sanitized.contains("\n\n\n") {
            sanitized = sanitized.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        let trimmed = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(maxLength))
    }

    private func baseInstruction(for type: ProvocationType, settings: AppSettings) -> String {
        switch type {
        case .hiddenAssumptions:
            return settings.prompt1
        case .counterargument:
            return settings.prompt2
        case .custom:
            return "Challenge the text with a precise, surprising, and defensible perspective."
        }
    }

    private func normalizedCustomInstruction(_ text: String) -> String {
        let normalized = String(
            text.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\0", with: " ")
                .prefix(AppSettings.maxCustomInstructionLength)
        )

        if normalized.isEmpty {
            return "No extra style constraints."
        }
        return normalized
    }
}
