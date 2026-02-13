import Foundation
import XCTest
@testable import FreeThinker

final class AIServicePerformanceTests: XCTestCase {
    func testPromptComposerPerformance() throws {
        let composer = ProvocationPromptComposer()
        let request = try ProvocationRequest(
            selectedText: loadFixture("large"),
            provocationType: .hiddenAssumptions
        )
        let settings = AppSettings(
            provocationStylePreset: .systemsThinking,
            customStyleInstructions: "Favor compact but dense analysis."
        )

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            _ = composer.composePrompt(for: request, settings: settings)
        }
    }

    func testServiceLatencyDistributionWithMockAdapter() async throws {
        let adapter = PerformanceMockAdapter()
        let service = DefaultAIService(adapter: adapter)
        let fixtures = ["small", "medium", "large"]
        var durations: [TimeInterval] = []

        for fixture in fixtures {
            let text = loadFixture(fixture)
            for _ in 0..<15 {
                let request = try ProvocationRequest(selectedText: text, provocationType: .counterargument)
                let start = Date()
                _ = await service.generateProvocation(
                    request: request,
                    settings: AppSettings(aiTimeoutSeconds: 5)
                )
                durations.append(Date().timeIntervalSince(start))
            }
        }

        let sorted = durations.sorted()
        let p95Index = Int(Double(sorted.count - 1) * 0.95)
        let p95 = sorted[p95Index]

        // Baseline for MVP responsiveness in tests with deterministic adapter.
        XCTAssertLessThan(p95, 0.2, "Mocked 95th percentile latency exceeded baseline.")
    }

    func testLiveFoundationModelsBenchmarkWhenEnabled() async throws {
        if ProcessInfo.processInfo.environment["FREETHINKER_ENABLE_LIVE_AI_PERF"] != "1" {
            throw XCTSkip("Live FoundationModels benchmark disabled. Set FREETHINKER_ENABLE_LIVE_AI_PERF=1 on supported Apple Silicon machines.")
        }

        let adapter = FoundationModelsAdapter()
        guard adapter.availability() == .available else {
            throw XCTSkip("FoundationModels runtime unavailable on this machine.")
        }

        let service = DefaultAIService(adapter: adapter)
        let request = try ProvocationRequest(
            selectedText: loadFixture("medium"),
            provocationType: .hiddenAssumptions
        )
        let start = Date()
        let response = await service.generateProvocation(
            request: request,
            settings: AppSettings(aiTimeoutSeconds: 5)
        )
        let elapsed = Date().timeIntervalSince(start)

        guard case .success = response.outcome else {
            return XCTFail("Expected successful output for live benchmark.")
        }

        XCTAssertLessThan(elapsed, 5.0, "Live benchmark exceeded timeout expectation.")
    }
}

private extension AIServicePerformanceTests {
    func loadFixture(_ name: String) -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: "txt", subdirectory: "Fixtures") else {
            XCTFail("Missing performance fixture: Fixtures/\(name).txt")
            return "Missing fixture \(name)"
        }

        guard
            let data = try? Data(contentsOf: url),
            let text = String(data: data, encoding: .utf8)
        else {
            XCTFail("Could not load performance fixture: Fixtures/\(name).txt")
            return "Unreadable fixture \(name)"
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            XCTFail("Performance fixture was empty: Fixtures/\(name).txt")
            return "Empty fixture \(name)"
        }

        return trimmed
    }
}

private final class PerformanceMockAdapter: FoundationModelsAdapterProtocol, @unchecked Sendable {
    func availability() -> FoundationModelAvailability {
        .available
    }

    func preload(model: ModelOption) async throws {}

    func generate(prompt: String, options: FoundationGenerationOptions) async throws -> String {
        try await Task.sleep(nanoseconds: 12_000_000)
        return """
        HEADLINE: Local optimization risk
        BODY: The argument optimizes for immediate throughput while underweighting systemic fragility and adaptation costs.
        FOLLOW_UP: Which hidden dependency could reverse this expected gain?
        """
    }
}
