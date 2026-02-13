import Foundation
import XCTest
@testable import FreeThinker

final class DefaultAIServiceTests: XCTestCase {
    func testGenerateProvocationRetriesTransientFailure() async throws {
        let adapter = MockFoundationModelsAdapter(
            scriptedResults: [
                .failure(FreeThinkerError.transientModelFailure),
                .success(
                    """
                    HEADLINE: Incentive mismatch
                    BODY: The claim assumes private incentives align with public outcomes, but they can diverge under pressure.
                    FOLLOW_UP: What externalities are not priced in this argument?
                    """
                )
            ]
        )
        let service = DefaultAIService(
            adapter: adapter,
            maxInitializationRetries: 2,
            retryBackoffNanoseconds: 1_000_000
        )
        let request = try makeRequest(text: "Automation always creates better outcomes.")

        let response = await service.generateProvocation(
            request: request,
            settings: AppSettings(aiTimeoutSeconds: 5)
        )

        XCTAssertEqual(adapter.generateCallCount, 2)
        guard case .success(let content) = response.outcome else {
            return XCTFail("Expected successful outcome")
        }
        XCTAssertEqual(content.headline, "Incentive mismatch")
    }

    func testGenerateProvocationReturnsTimeoutAndCancelsWork() async throws {
        let adapter = MockFoundationModelsAdapter(
            scriptedResults: [.success("HEADLINE: H\nBODY: B\nFOLLOW_UP: NONE")],
            generateDelayNanoseconds: 1_300_000_000
        )
        let service = DefaultAIService(adapter: adapter)
        let request = try makeRequest(text: "A long running generation should timeout.")

        let response = await service.generateProvocation(
            request: request,
            settings: AppSettings(aiTimeoutSeconds: 1)
        )

        XCTAssertEqual(response.error, .timeout)
        XCTAssertTrue(adapter.didObserveCancellation)
    }

    func testGenerateProvocationPropagatesCancellation() async throws {
        let adapter = MockFoundationModelsAdapter(
            scriptedResults: [.success("HEADLINE: H\nBODY: B\nFOLLOW_UP: NONE")],
            generateDelayNanoseconds: 3_000_000_000
        )
        let service = DefaultAIService(adapter: adapter)
        let request = try makeRequest(text: "Cancellation should be cooperative.")

        let task = Task {
            await service.generateProvocation(
                request: request,
                settings: AppSettings(aiTimeoutSeconds: 10)
            )
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()
        let response = await task.value

        XCTAssertEqual(response.error, .cancelled)
        XCTAssertTrue(adapter.didObserveCancellation)
        XCTAssertEqual(adapter.generateCallCount, 1)
    }

    func testGenerateProvocationMapsUnknownFailure() async throws {
        let adapter = MockFoundationModelsAdapter(
            scriptedResults: [
                .failure(NSError(domain: "test", code: 17))
            ]
        )
        let service = DefaultAIService(adapter: adapter)
        let request = try makeRequest(text: "Unknown errors should map safely.")

        let response = await service.generateProvocation(
            request: request,
            settings: AppSettings(aiTimeoutSeconds: 5)
        )

        XCTAssertEqual(response.error, .generationFailed)
    }
}

private extension DefaultAIServiceTests {
    func makeRequest(text: String) throws -> ProvocationRequest {
        try ProvocationRequest(
            selectedText: text,
            provocationType: .hiddenAssumptions
        )
    }
}

private final class MockFoundationModelsAdapter: FoundationModelsAdapterProtocol, @unchecked Sendable {
    fileprivate actor State {
        var queue: [Result<String, Error>]
        var generateCallCount = 0
        var didObserveCancellation = false

        init(queue: [Result<String, Error>]) {
            self.queue = queue
        }
    }

    private let state: State

    private(set) var generateCallCount = 0
    private(set) var didObserveCancellation = false

    private let availabilityResult: FoundationModelAvailability
    private let preloadError: Error?
    private let generateDelayNanoseconds: UInt64

    init(
        availability: FoundationModelAvailability = .available,
        preloadError: Error? = nil,
        scriptedResults: [Result<String, Error>] = [.success("HEADLINE: H\nBODY: B\nFOLLOW_UP: NONE")],
        generateDelayNanoseconds: UInt64 = 0
    ) {
        self.availabilityResult = availability
        self.preloadError = preloadError
        self.state = State(queue: scriptedResults)
        self.generateDelayNanoseconds = generateDelayNanoseconds
    }

    func availability() -> FoundationModelAvailability {
        availabilityResult
    }

    func preload(model: ModelOption) async throws {
        if let preloadError {
            throw preloadError
        }
    }

    func generate(prompt: String, options: FoundationGenerationOptions) async throws -> String {
        await state.incrementGenerateCallCount(on: self)

        if generateDelayNanoseconds > 0 {
            var remaining = generateDelayNanoseconds
            while remaining > 0 {
                let step = min(remaining, 25_000_000)
                do {
                    try await Task.sleep(nanoseconds: step)
                } catch {
                    await state.setDidObserveCancellation(on: self)
                    throw CancellationError()
                }
                if Task.isCancelled {
                    await state.setDidObserveCancellation(on: self)
                    throw CancellationError()
                }
                remaining -= step
            }
        }

        let result: Result<String, Error> = await state.dequeueOrDefault()

        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}

private extension MockFoundationModelsAdapter.State {
    func incrementGenerateCallCount(on adapter: MockFoundationModelsAdapter) async {
        generateCallCount += 1
        let value = generateCallCount
        adapter.generateCallCount = value
    }

    func setDidObserveCancellation(on adapter: MockFoundationModelsAdapter) async {
        didObserveCancellation = true
        adapter.didObserveCancellation = true
    }

    func dequeueOrDefault() -> Result<String, Error> {
        guard !queue.isEmpty else {
            return .success("HEADLINE: H\nBODY: B\nFOLLOW_UP: NONE")
        }
        return queue.removeFirst()
    }
}
