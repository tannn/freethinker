import XCTest
@testable import FreeThinker

final class ProvocationPromptComposerTests: XCTestCase {
    func testComposePromptIncludesStylePresetInstruction() throws {
        let composer = ProvocationPromptComposer()
        let request = try ProvocationRequest(
            selectedText: "AI will replace all human jobs by 2030.",
            provocationType: .hiddenAssumptions
        )

        let settings = AppSettings(
            provocationStylePreset: .contrarian,
            customStyleInstructions: "Focus on policy and incentives."
        )

        let prompt = composer.composePrompt(for: request, settings: settings)

        XCTAssertTrue(prompt.contains("Take a rigorous contrary angle."))
        XCTAssertTrue(prompt.contains("Focus on policy and incentives."))
        XCTAssertTrue(prompt.contains("HEADLINE:"))
        XCTAssertTrue(prompt.contains("BODY:"))
        XCTAssertTrue(prompt.contains("FOLLOW_UP:"))
    }

    func testComposePromptCapsAndSanitizesInputText() throws {
        let composer = ProvocationPromptComposer()
        let noisy = String(repeating: "A", count: 1_200) + "\0\r\n\r\n\r\nTail"
        let request = try ProvocationRequest(
            selectedText: noisy,
            provocationType: .counterargument
        )

        let prompt = composer.composePrompt(for: request, settings: AppSettings())

        XCTAssertFalse(prompt.contains("\0"))
        XCTAssertFalse(prompt.contains("\r"))
        XCTAssertFalse(prompt.contains("\n\n\n"))
    }

    func testComposeFollowUpPromptCarriesPriorResponseContext() throws {
        let composer = ProvocationPromptComposer()
        let request = try ProvocationRequest(
            selectedText: "Automation in hiring always improves fairness.",
            provocationType: .custom
        )
        let previous = ProvocationContent(
            headline: "Hidden tradeoff in hiring automation",
            body: "Automated screening can encode historical bias while claiming neutrality."
        )

        let prompt = composer.composeFollowUpPrompt(
            for: request,
            previousResponse: previous,
            settings: AppSettings(provocationStylePreset: .systemsThinking)
        )

        XCTAssertTrue(prompt.contains("Generate a distinctly different provocation"))
        XCTAssertTrue(prompt.contains(previous.headline))
        XCTAssertTrue(prompt.contains(previous.body))
        XCTAssertTrue(prompt.contains("Analyze second-order effects"))
    }
}
