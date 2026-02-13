import Foundation

struct ProvocationRequest: Codable, Equatable, Sendable {
    enum Tone: String, Codable, CaseIterable, Sendable {
        case challenging
        case contrarian
        case reflective
        case strategic
    }

    var id: UUID
    var selectedText: String
    var sourceApplication: String?
    var tone: Tone
    var maxTokens: Int
    var temperature: Double
    var createdAt: Date

    init(
        id: UUID = UUID(),
        selectedText: String,
        sourceApplication: String? = nil,
        tone: Tone = .challenging,
        maxTokens: Int = 240,
        temperature: Double = 0.7,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.selectedText = selectedText
        self.sourceApplication = sourceApplication
        self.tone = tone
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.createdAt = createdAt
    }
}
