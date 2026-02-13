import Foundation

struct ProvocationResponse: Codable, Equatable, Sendable {
    struct Metadata: Codable, Equatable, Sendable {
        var modelName: String
        var generationDuration: TimeInterval
        var tokenCount: Int

        init(
            modelName: String,
            generationDuration: TimeInterval,
            tokenCount: Int
        ) {
            self.modelName = modelName
            self.generationDuration = generationDuration
            self.tokenCount = tokenCount
        }
    }

    var requestID: UUID
    var generatedText: String
    var createdAt: Date
    var metadata: Metadata
    var warnings: [String]

    init(
        requestID: UUID,
        generatedText: String,
        createdAt: Date = Date(),
        metadata: Metadata,
        warnings: [String] = []
    ) {
        self.requestID = requestID
        self.generatedText = generatedText
        self.createdAt = createdAt
        self.metadata = metadata
        self.warnings = warnings
    }
}
