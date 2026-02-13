import XCTest
@testable import FreeThinker

final class ProvocationResponseParserTests: XCTestCase {
    func testParseStructuredOutput() throws {
        let parser = ProvocationResponseParser()
        let raw = """
        HEADLINE: Efficiency narrative hides fragility
        BODY: The claim assumes optimization equals resilience. In reality, single-point automation failures can amplify systemic risk across dependent teams.
        FOLLOW_UP: What assumptions about failure modes are left unstated?
        """

        let parsed = try parser.parse(rawOutput: raw)

        XCTAssertEqual(parsed.headline, "Efficiency narrative hides fragility")
        XCTAssertTrue(parsed.body.contains("optimization equals resilience"))
        XCTAssertEqual(parsed.followUpQuestion, "What assumptions about failure modes are left unstated?")
    }

    func testParseFallsBackWhenTagsAreMissing() throws {
        let parser = ProvocationResponseParser()
        let raw = """
        This argument treats short-term gains as proof of long-term viability.
        It ignores adaptation by competitors and downstream policy constraints.
        """

        let parsed = try parser.parse(rawOutput: raw)

        XCTAssertEqual(parsed.headline, "This argument treats short-term gains as proof of long-term viability.")
        XCTAssertTrue(parsed.body.contains("It ignores adaptation by competitors"))
    }

    func testParseRejectsEmptyOutput() {
        let parser = ProvocationResponseParser()

        XCTAssertThrowsError(try parser.parse(rawOutput: "   \n\t")) { error in
            XCTAssertEqual(error as? FreeThinkerError, .generationFailed)
        }
    }

    func testParseClampsPanelSafeLengths() throws {
        let parser = ProvocationResponseParser()
        let longHeadline = String(repeating: "H", count: 300)
        let longBody = String(repeating: "B", count: 1_000)
        let raw = """
        HEADLINE: \(longHeadline)
        BODY: \(longBody)
        FOLLOW_UP: NONE
        """

        let parsed = try parser.parse(rawOutput: raw)

        XCTAssertEqual(parsed.headline.count, ProvocationContent.maxHeadlineLength)
        XCTAssertEqual(parsed.body.count, ProvocationContent.maxBodyLength)
        XCTAssertNil(parsed.followUpQuestion)
    }
}
