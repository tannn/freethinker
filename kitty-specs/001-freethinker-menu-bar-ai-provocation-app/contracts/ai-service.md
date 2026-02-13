# AIService Contract

**Service**: AIService  
**Purpose**: Abstract interface for AI provocation generation  
**Implementation**: FoundationModelsService (uses SystemLanguageModel)  

---

## Protocol Definition

```swift
protocol AIServiceProtocol {
    /// Generates a provocation for the given request
    /// - Parameter request: The provocation request containing text and prompt
    /// - Returns: ProvocationResponse with generated content or error
    /// - Throws: ProvocationError if generation fails
    func generateProvocation(request: ProvocationRequest) async throws -> ProvocationResponse
    
    /// Preloads the AI model to improve first-response latency
    func preloadModel() async throws
    
    /// Checks if the AI service is available and ready
    var isAvailable: Bool { get }
    
    /// Current model configuration
    var currentModel: ModelOption { get set }
}
```

---

## Methods

### generateProvocation

Generates a provocation based on the request parameters.

**Signature**:
```swift
func generateProvocation(request: ProvocationRequest) async throws -> ProvocationResponse
```

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| request | ProvocationRequest | Contains selected text, prompt, and provocation type |

**Returns**:
- `ProvocationResponse` with `content` populated on success
- `ProvocationResponse` with `error` populated on failure

**Throws**:
- `ProvocationError.timeout` - Generation exceeded 5 second timeout
- `ProvocationError.modelUnavailable` - SystemLanguageModel not available
- `ProvocationError.generationFailed` - Model returned empty or invalid response

**Example**:
```swift
let service: AIServiceProtocol = FoundationModelsService()

let request = ProvocationRequest(
    selectedText: "AI will replace all jobs",
    provocationType: .hiddenAssumptions,
    prompt: "Identify hidden assumptions"
)

do {
    let response = try await service.generateProvocation(request: request)
    print(response.content) // "This assumes linear progression..."
} catch let error as ProvocationError {
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

Indicates whether the AI service can generate provocations.

**Type**: `Bool`  
**Access**: Read-only

**Returns `false` when**:
- SystemLanguageModel framework unavailable
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
    
    func generateProvocation(request: ProvocationRequest) async throws -> ProvocationResponse {
        // Ensure model is loaded
        if model == nil {
            try await preloadModel()
        }
        
        guard let model = model else {
            throw ProvocationError.modelUnavailable
        }
        
        // Construct prompt
        let fullPrompt = """
        \(request.prompt)
        
        Text: \(request.selectedText)
        """
        
        // Generate with timeout
        let generationTask = Task {
            let response = try await model.generate(text: fullPrompt)
            return response
        }
        
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            generationTask.cancel()
        }
        
        do {
            let startTime = Date()
            let generatedText = try await generationTask.value
            let generationTime = Date().timeIntervalSince(startTime)
            
            timeoutTask.cancel()
            
            return ProvocationResponse(
                requestId: request.id,
                originalText: request.selectedText,
                provocationType: request.provocationType,
                content: generatedText,
                generationTime: generationTime,
                error: nil
            )
        } catch {
            return ProvocationResponse(
                requestId: request.id,
                originalText: request.selectedText,
                provocationType: request.provocationType,
                content: "",
                generationTime: 0,
                error: .timeout
            )
        }
    }
}
```

---

## Error Handling

All errors are wrapped in `ProvocationResponse.error` rather than thrown at the protocol level. This allows the UI to display partial results and recovery options.

**Error Mapping**:

| Internal Error | ProvocationError | User Message |
|----------------|------------------|--------------|
| Model load failure | `.modelUnavailable` | "AI model is unavailable..." |
| Timeout | `.timeout` | "AI generation timed out..." |
| Empty response | `.generationFailed` | "Could not generate provocations..." |
| Cancelled | `.timeout` | "AI generation timed out..." |

---

## Testing

### Mock Implementation

```swift
class MockAIService: AIServiceProtocol {
    var isAvailable: Bool = true
    var currentModel: ModelOption = .default
    var mockResponse: String = "Mock provocation response"
    var shouldFail: Bool = false
    var delay: TimeInterval = 0.1
    
    func preloadModel() async throws {
        if !isAvailable {
            throw ProvocationError.modelUnavailable
        }
    }
    
    func generateProvocation(request: ProvocationRequest) async throws -> ProvocationResponse {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        if shouldFail {
            return ProvocationResponse(
                requestId: request.id,
                originalText: request.selectedText,
                provocationType: request.provocationType,
                content: "",
                generationTime: delay,
                error: .generationFailed
            )
        }
        
        return ProvocationResponse(
            requestId: request.id,
            originalText: request.selectedText,
            provocationType: request.provocationType,
            content: mockResponse,
            generationTime: delay,
            error: nil
        )
    }
}
```

### Test Cases

1. **Happy Path**: Valid request returns response with content
2. **Timeout**: Long generation returns timeout error
3. **Model Unavailable**: Service unavailable returns appropriate error
4. **Model Switching**: Changing `currentModel` updates behavior
5. **Preload**: Preloading reduces first-request latency

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-02-12 | Initial contract |
