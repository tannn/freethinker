import XCTest
@testable import FreeThinker

final class FreeThinkerModelContractTests: XCTestCase {
    func testAppSettingsRoundTripCodable() throws {
        let initial = AppSettings.defaultValue
        let data = try JSONEncoder().encode(initial)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(decoded, initial)
    }

    func testProvocationRequestRoundTripCodable() throws {
        let request = ProvocationRequest(
            selectedText: "All models are wrong, but some are useful.",
            sourceApplication: "Notes",
            tone: .contrarian,
            maxTokens: 180,
            temperature: 0.55
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(ProvocationRequest.self, from: data)

        XCTAssertEqual(decoded, request)
    }

    func testProvocationResponseCarriesMetadata() {
        let requestID = UUID()
        let response = ProvocationResponse(
            requestID: requestID,
            generatedText: "Challenge your assumptions with a stronger opposite case.",
            metadata: .init(modelName: "placeholder", generationDuration: 0.25, tokenCount: 42)
        )

        XCTAssertEqual(response.requestID, requestID)
        XCTAssertEqual(response.metadata.tokenCount, 42)
    }
}
