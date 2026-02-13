# AIService Contract

**Service**: AIService  
**Purpose**: Abstract interface for AI provocation generation  
**Implementation**: FoundationModelsService (uses SystemLanguageModel)

---

## Protocol Definition

```swift
protocol AIServiceProtocol {
    /// Generates a provocation for the given request.
    /// This method never throws. Failures are returned as ProvocationResponse.outcome = .failure(...).
    func generateProvocation(request: ProvocationRequest) async -> ProvocationResponse

    /// Preloads the AI model to improve first-response latency.
    func preloadModel() async throws

    /// Checks if the AI service is available and ready.
    var isAvailable: Bool { get }

    /// Current model configuration.
    var currentModel: ModelOption { get set }
}
```

---

## Methods

### generateProvocation

Generates a provocation based on request parameters.

**Signature**:
```swift
func generateProvocation(request: ProvocationRequest) async -> ProvocationResponse
```

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| request | ProvocationRequest | Validated text, prompt, and provocation type |

**Returns**:
- Success: `ProvocationResponse` with `outcome = .success(content: ...)`
- Failure: `ProvocationResponse` with `outcome = .failure(error: ...)`

**Failure outcomes**:
- `.timeout` - Generation exceeded 5 second timeout
- `.modelUnavailable` - `SystemLanguageModel` not available
- `.generationFailed` - Empty/invalid model output

**Example**:
```swift
let service: AIServiceProtocol = FoundationModelsService()

let request = try ProvocationRequest(
    selectedText: "AI will replace all jobs",
    provocationType: .hiddenAssumptions,
    prompt: "Identify hidden assumptions"
)

let response = await service.generateProvocation(request: request)

switch response.outcome {
case .success(let content):
    print(content)
case .failure(let error):
    print(error.userMessage)
}
```

**Performance Requirements**:
- 95th percentile response time: <3 seconds
- Timeout threshold: 5 seconds
- Max text length: 1000 characters

---

### preloadModel

Preloads the AI model into memory to reduce first-request latency.

**Signature**:
```swift
func preloadModel() async throws
```

**Throws**:
- `ProvocationError.modelUnavailable` - Model cannot be loaded

**Usage**:
Call during app launch or when user enables the service.

---

## Properties

### isAvailable

Indicates whether AI service can generate provocations.

**Type**: `Bool`  
**Access**: Read-only

**Returns `false` when**:
- FoundationModels framework unavailable
- Insufficient memory
- macOS version incompatible

---

### currentModel

The currently selected AI model configuration.

**Type**: `ModelOption`  
**Access**: Read/Write

**Behavior**:
- Setting this property switches the active model
- Change takes effect on next `generateProvocation` call
- Preloaded model is released when switching

---

## Implementation: FoundationModelsService

```swift
import FoundationModels

actor FoundationModelsService: AIServiceProtocol {
    private var model: SystemLanguageModel?
    var currentModel: ModelOption = .default

    var isAvailable: Bool {
        SystemLanguageModel.isAvailable
    }

    func preloadModel() async throws {
        guard SystemLanguageModel.isAvailable else {
            throw ProvocationError.modelUnavailable
        }

        model = switch currentModel {
        case .default: SystemLanguageModel.default
        case .creativeWriting: SystemLanguageModel(useCase: .creativeWriting)
        }
    }

    func generateProvocation(request: ProvocationRequest) async -> ProvocationResponse {
        let startTime = Date()

        do {
            if model == nil {
                try await preloadModel()
            }

            guard let model else {
                throw ProvocationError.modelUnavailable
            }

            let fullPrompt = """
            \(request.prompt)

            Text: \(request.selectedText)
            """

            let generatedText = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    try await model.generate(text: fullPrompt)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    throw ProvocationError.timeout
                }

                let first = try await group.next()!
                group.cancelAll()
                return first
            }

            let normalized = generatedText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else {
                throw ProvocationError.generationFailed
            }

            return ProvocationResponse(
                id: UUID(),
                requestId: request.id,
                originalText: request.selectedText,
                provocationType: request.provocationType,
                outcome: .success(content: normalized),
                generationTime: Date().timeIntervalSince(startTime),
                timestamp: Date()
            )
        } catch {
            let mapped = mapError(error)
            return ProvocationResponse(
                id: UUID(),
                requestId: request.id,
                originalText: request.selectedText,
                provocationType: request.provocationType,
                outcome: .failure(error: mapped),
                generationTime: Date().timeIntervalSince(startTime),
                timestamp: Date()
            )
        }
    }

    private func mapError(_ error: Error) -> ProvocationError {
        if let known = error as? ProvocationError {
            return known
        }
        if error is CancellationError {
            return .timeout
        }
        return .generationFailed
    }
}
```

---

## Error Handling

Failures are modeled as `ProvocationResponse.outcome = .failure(...)` to keep response handling consistent in UI flows and support partial rendering.

**Error Mapping**:

| Internal Error | ProvocationError | User Message |
|----------------|------------------|--------------|
| Model load failure | `.modelUnavailable` | "AI model is unavailable..." |
| Timeout | `.timeout` | "AI generation timed out..." |
| Empty response | `.generationFailed` | "Could not generate provocations..." |
| Cancelled | `.timeout` | "AI generation timed out..." |
| Unknown generation error | `.generationFailed` | "Could not generate provocations..." |

---

## Testing

### Mock Implementation

```swift
class MockAIService: AIServiceProtocol {
    var isAvailable: Bool = true
    var currentModel: ModelOption = .default
    var mockResponse: String = "Mock provocation response"
    var shouldFail: Bool = false
    var failure: ProvocationError = .generationFailed
    var delay: TimeInterval = 0.1

    func preloadModel() async throws {
        if !isAvailable {
            throw ProvocationError.modelUnavailable
        }
    }

    func generateProvocation(request: ProvocationRequest) async -> ProvocationResponse {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        if shouldFail {
            return ProvocationResponse(
                id: UUID(),
                requestId: request.id,
                originalText: request.selectedText,
                provocationType: request.provocationType,
                outcome: .failure(error: failure),
                generationTime: delay,
                timestamp: Date()
            )
        }

        return ProvocationResponse(
            id: UUID(),
            requestId: request.id,
            originalText: request.selectedText,
            provocationType: request.provocationType,
            outcome: .success(content: mockResponse),
            generationTime: delay,
            timestamp: Date()
        )
    }
}
```

### Test Cases

1. **Happy Path**: Valid request returns success outcome with non-empty content
2. **Timeout**: Long generation returns timeout failure outcome
3. **Model Unavailable**: Service unavailable returns modelUnavailable failure outcome
4. **Model Switching**: Changing `currentModel` updates behavior
5. **Preload**: Preloading reduces first-request latency
6. **Invariant**: Response never includes both content and error simultaneously

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.1 | 2026-02-13 | Aligned with typed outcome model and non-throwing generation path |
| 1.0 | 2026-02-12 | Initial contract |
