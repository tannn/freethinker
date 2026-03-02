import Foundation

/// Concrete implementation of ``ProvocationResponseParsing`` that extracts `BODY:` and
/// `FOLLOW_UP:` labelled sections from raw model output.
///
/// The parser is lenient: if the expected labels are absent, the entire output is used
/// as the body and a trailing question mark heuristic is applied to extract a follow-up.
/// Text is normalised (whitespace collapsed, NUL bytes removed) and truncated to the
/// ``ProvocationContent`` length constants before being returned.
public struct ProvocationResponseParser: ProvocationResponseParsing, Sendable {
    /// Creates a default `ProvocationResponseParser`.
    public init() {}

    /// Parses raw model output into a ``ProvocationContent`` value.
    ///
    /// - Parameter rawOutput: The unstructured string returned by the model.
    /// - Returns: A ``ProvocationContent`` with a body and optional follow-up question.
    /// - Throws: ``FreeThinkerError/generationFailed`` if `rawOutput` is empty after normalisation,
    ///   or ``FreeThinkerError/invalidResponse`` if the body section is empty.
    public func parse(rawOutput: String) throws -> ProvocationContent {
        let trimmed = normalizeWhitespace(rawOutput)
        guard !trimmed.isEmpty else {
            throw FreeThinkerError.generationFailed
        }

        let extracted = extractTaggedSections(from: trimmed)

        let body = normalizePanelText(
            extracted.body ?? fallbackBody(from: trimmed),
            maxLength: ProvocationContent.maxBodyLength
        )
        let followUp = normalizeOptionalFollowUp(
            extracted.followUp ?? fallbackFollowUp(from: body),
            maxLength: ProvocationContent.maxFollowUpLength
        )

        guard !body.isEmpty else {
            throw FreeThinkerError.invalidResponse
        }

        return ProvocationContent(
            body: body,
            followUpQuestion: followUp
        )
    }
}

private extension ProvocationResponseParser {
    enum TaggedSection {
        case body
        case followUp
    }

    struct ExtractedSections {
        let body: String?
        let followUp: String?
    }

    func extractTaggedSections(from text: String) -> ExtractedSections {
        var sectionBuffers: [TaggedSection: [String]] = [:]
        var currentSection: TaggedSection?

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if let (section, initialValue) = parseTaggedLine(line) {
                currentSection = section
                if !initialValue.isEmpty {
                    sectionBuffers[section, default: []].append(initialValue)
                }
                continue
            }

            guard let currentSection, !line.isEmpty else {
                continue
            }

            sectionBuffers[currentSection, default: []].append(line)
        }

        return ExtractedSections(
            body: joinedSection(sectionBuffers[.body]),
            followUp: joinedSection(sectionBuffers[.followUp])
        )
    }

    func parseTaggedLine(_ line: String) -> (TaggedSection, String)? {
        guard let tagSeparator = line.firstIndex(of: ":") else {
            return nil
        }

        let tag = line[..<tagSeparator]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let value = line[line.index(after: tagSeparator)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        switch tag {
        case "body":
            return (.body, value)
        case "follow_up", "follow-up", "followup":
            return (.followUp, value)
        default:
            return nil
        }
    }

    func joinedSection(_ lines: [String]?) -> String? {
        guard let lines else {
            return nil
        }

        let joined = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return joined.isEmpty ? nil : joined
    }

    func fallbackBody(from text: String) -> String {
        return text
    }

    func fallbackFollowUp(from body: String) -> String? {
        guard let questionMark = body.lastIndex(of: "?") else {
            return nil
        }
        let prefix = body[..<body.index(after: questionMark)]
        if prefix.count <= ProvocationContent.maxFollowUpLength {
            return String(prefix)
        }
        return nil
    }

    func normalizeWhitespace(_ text: String) -> String {
        var value = text
            .replacingOccurrences(of: "\0", with: " ")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        while value.contains("\n\n\n") {
            value = value.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return value
    }

    func normalizePanelText(_ text: String, maxLength: Int) -> String {
        let flattened = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(flattened.prefix(maxLength))
    }

    func normalizeOptionalFollowUp(_ value: String?, maxLength: Int) -> String? {
        guard let value else { return nil }
        let normalized = normalizePanelText(value, maxLength: maxLength)
        if normalized.isEmpty || normalized.uppercased() == "NONE" {
            return nil
        }
        return normalized
    }
}
