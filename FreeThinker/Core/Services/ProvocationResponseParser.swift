import Foundation

public struct ProvocationResponseParser: ProvocationResponseParsing, Sendable {
    public init() {}

    public func parse(rawOutput: String) throws -> ProvocationContent {
        let trimmed = normalizeWhitespace(rawOutput)
        guard !trimmed.isEmpty else {
            throw FreeThinkerError.generationFailed
        }

        let extracted = extractTaggedSections(from: trimmed)

        let headline = normalizePanelText(
            extracted.headline ?? fallbackHeadline(from: trimmed),
            maxLength: ProvocationContent.maxHeadlineLength
        )
        let body = normalizePanelText(
            extracted.body ?? fallbackBody(from: trimmed, excludingHeadline: headline),
            maxLength: ProvocationContent.maxBodyLength
        )
        let followUp = normalizeOptionalFollowUp(
            extracted.followUp ?? fallbackFollowUp(from: body),
            maxLength: ProvocationContent.maxFollowUpLength
        )

        guard !headline.isEmpty, !body.isEmpty else {
            throw FreeThinkerError.invalidResponse
        }

        return ProvocationContent(
            headline: headline,
            body: body,
            followUpQuestion: followUp
        )
    }
}

private extension ProvocationResponseParser {
    struct ExtractedSections {
        let headline: String?
        let body: String?
        let followUp: String?
    }

    func extractTaggedSections(from text: String) -> ExtractedSections {
        var headline: String?
        var body: String?
        var followUp: String?

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            let lower = line.lowercased()

            if lower.hasPrefix("headline:") {
                headline = String(line.dropFirst("headline:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if lower.hasPrefix("body:") {
                body = String(line.dropFirst("body:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if lower.hasPrefix("follow_up:") || lower.hasPrefix("follow-up:") || lower.hasPrefix("followup:") {
                let suffix = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).dropFirst().first ?? ""
                followUp = String(suffix).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return ExtractedSections(headline: headline, body: body, followUp: followUp)
    }

    func fallbackHeadline(from text: String) -> String {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let first = lines.first else { return "" }
        return first
    }

    func fallbackBody(from text: String, excludingHeadline headline: String) -> String {
        if text == headline { return "" }
        let withoutHeadline = text.replacingOccurrences(of: headline, with: "", options: [.anchored], range: nil)
        let normalized = normalizeWhitespace(withoutHeadline)
        if !normalized.isEmpty {
            return normalized
        }
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
