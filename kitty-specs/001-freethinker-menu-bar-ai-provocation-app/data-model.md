# Data Model: FreeThinker

**Feature**: 001-freethinker-menu-bar-ai-provocation-app  
**Date**: 2026-02-12  
**Phase**: Phase 1 - Design & Contracts

---

## 1. Entity Overview

### Core Entities
1. **ProvocationRequest** - Input to AI service
2. **ProvocationResponse** - Output from AI service  
3. **AppSettings** - User preferences (persistent)
4. **AppState** - Runtime application state (non-persistent)

---

## 2. Entity Definitions

### 2.1 ProvocationRequest

Represents a request to generate provocations for selected text.

```swift
struct ProvocationRequest: Codable, Identifiable {
    let id: UUID
    let selectedText: String
    let provocationType: ProvocationType
    let timestamp: Date
    let prompt: String
    
    init(
        selectedText: String,
        provocationType: ProvocationType,
        prompt: String
    ) {
        self.id = UUID()
        self.selectedText = String(selectedText.prefix(1000)) // Truncate to max
        self.provocationType = provocationType
        self.timestamp = Date()
        self.prompt = prompt
    }
}

enum ProvocationType: String, Codable, CaseIterable {
    case hiddenAssumptions = "hiddenAssumptions"
    case counterargument = "counterargument"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .hiddenAssumptions: return "Hidden Assumptions"
        case .counterargument: return "Counterargument"
        case .custom: return "Custom"
        }
    }
}
```

**Validation Rules**:
- `selectedText`: Max 1000 characters, trimmed whitespace
- `provocationType`: Must be valid enum value
- `timestamp`: Automatically set on creation

---

### 2.2 ProvocationResponse

Represents the result of a provocation generation.

```swift
struct ProvocationResponse: Codable, Identifiable {
    let id: UUID
    let requestId: UUID
    let originalText: String
    let provocationType: ProvocationType
    let content: String
    let generationTime: TimeInterval
    let error: ProvocationError?
    let timestamp: Date
    
    var isSuccess: Bool {
        return error == nil
    }
}

enum ProvocationError: String, Codable, Error {
    case timeout = "timeout"
    case modelUnavailable = "modelUnavailable"
    case generationFailed = "generationFailed"
    case textTooLong = "textTooLong"
    case permissionDenied = "permissionDenied"
    
    var userMessage: String {
        switch self {
        case .timeout:
            return "AI generation timed out. Please try again."
        case .modelUnavailable:
            return "AI model is unavailable. Check system requirements."
        case .generationFailed:
            return "Could not generate provocations. Please try again."
        case .textTooLong:
            return "Selected text is too long. Please select less text."
        case .permissionDenied:
            return "Accessibility permission required. Check System Settings."
        }
    }
}
```

**Validation Rules**:
- `content`: Non-empty string if success
- `generationTime`: Must be >= 0
- Either `content` OR `error` must be present (not both)

---

### 2.3 AppSettings

User-configurable application settings (persisted to UserDefaults).

```swift
struct AppSettings: Codable {
    // MARK: - Hotkey Configuration
    var hotkeyModifiers: Int        // NSEvent.ModifierFlags.rawValue
    var hotkeyKeyCode: Int          // CGKeyCode
    
    // MARK: - Provocation Prompts
    var prompt1: String             // Hidden assumptions prompt
    var prompt2: String             // Counterargument prompt
    
    // MARK: - Behavior
    var launchAtLogin: Bool
    var selectedModel: ModelOption
    
    // MARK: - UI Preferences
    var showMenuBarIcon: Bool
    var dismissOnCopy: Bool         // Auto-dismiss after copying provocation
    
    // MARK: - Initialization
    init(
        hotkeyModifiers: Int = 1179648,  // Cmd+Shift
        hotkeyKeyCode: Int = 35,         // 'P' key
        prompt1: String = AppSettings.defaultPrompt1,
        prompt2: String = AppSettings.defaultPrompt2,
        launchAtLogin: Bool = false,
        selectedModel: ModelOption = .default,
        showMenuBarIcon: Bool = true,
        dismissOnCopy: Bool = true
    ) {
        self.hotkeyModifiers = hotkeyModifiers
        self.hotkeyKeyCode = hotkeyKeyCode
        self.prompt1 = prompt1
        self.prompt2 = prompt2
        self.launchAtLogin = launchAtLogin
        self.selectedModel = selectedModel
        self.showMenuBarIcon = showMenuBarIcon
        self.dismissOnCopy = dismissOnCopy
    }
    
    // MARK: - Default Prompts
    static let defaultPrompt1 = "Identify hidden assumptions, unstated premises, or implicit biases in the following text:"
    static let defaultPrompt2 = "Provide a strong, well-reasoned counterargument or alternative perspective to the following claim:"
}

enum ModelOption: String, Codable, CaseIterable, Identifiable {
    case `default` = "default"
    case creativeWriting = "creativeWriting"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .default: return "Balanced (Fast)"
        case .creativeWriting: return "Creative (Higher Quality)"
        }
    }
    
    var description: String {
        switch self {
        case .default:
            return "Optimized for speed with good quality provocations"
        case .creativeWriting:
            return "Higher quality output with more detailed reasoning"
        }
    }
}
```

**Validation Rules**:
- `hotkeyModifiers`: Must be valid NSEvent.ModifierFlags combination
- `hotkeyKeyCode`: Must be valid CGKeyCode (0-127)
- `prompt1`, `prompt2`: Non-empty, max 1000 characters each
- `selectedModel`: Must be valid enum value

**Persistence**:
```swift
extension AppSettings {
    private static let settingsKey = "com.freethinker.settings"
    
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: Self.settingsKey)
        }
    }
    
    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings() // Return defaults
        }
        return settings
    }
}
```

---

### 2.4 AppState

Runtime application state (not persisted).

```swift
@Observable
class AppState {
    // MARK: - Generation State
    var isGenerating: Bool = false
    var currentRequest: ProvocationRequest?
    var provocations: [ProvocationResponse] = []
    var errorMessage: String?
    
    // MARK: - UI State
    var isPanelVisible: Bool = false
    var panelPosition: CGPoint = .zero
    var selectedTextPreview: String = ""
    
    // MARK: - Permissions
    var hasAccessibilityPermission: Bool = false
    
    // MARK: - Settings
    var settings: AppSettings = .load()
    
    // MARK: - Computed Properties
    var canGenerate: Bool {
        !isGenerating && hasAccessibilityPermission
    }
    
    var hasError: Bool {
        errorMessage != nil
    }
    
    // MARK: - Methods
    func clearProvocations() {
        provocations.removeAll()
        errorMessage = nil
    }
    
    func addProvocation(_ response: ProvocationResponse) {
        provocations.append(response)
    }
    
    func setError(_ error: ProvocationError) {
        self.errorMessage = error.userMessage
    }
}
```

---

## 3. State Transitions

### 3.1 Provocation Generation Flow

```
State: IDLE
  |
  | User presses hotkey
  v
State: CAPTURING_TEXT
  |
  | Text captured successfully
  v
State: GENERATING
  |
  | AI responds (success/failure)
  v
State: DISPLAYING_RESULTS
  |
  | User dismisses panel or requests more
  v
State: IDLE
```

**Transitions**:

| From | To | Trigger | Action |
|------|-----|---------|--------|
| IDLE | CAPTURING_TEXT | Hotkey pressed | Check permissions, capture text |
| CAPTURING_TEXT | IDLE | No text selected | Show menu bar animation |
| CAPTURING_TEXT | GENERATING | Text captured | Create request, call AI service |
| GENERATING | DISPLAYING_RESULTS | AI response received | Parse response, update UI |
| GENERATING | DISPLAYING_RESULTS | AI error/timeout | Show error with retry option |
| DISPLAYING_RESULTS | IDLE | User dismisses panel | Clear state |
| DISPLAYING_RESULTS | GENERATING | User clicks "More..." | Generate additional provocations |

---

## 4. Relationships

```
┌─────────────────────┐         ┌─────────────────────┐
│   AppSettings       │         │     AppState        │
│  (Persistent)       │         │   (Runtime)         │
├─────────────────────┤         ├─────────────────────┤
│ - hotkeyModifiers   │         │ - isGenerating      │
│ - hotkeyKeyCode     │◄────────│ - provocations[]    │
│ - prompt1/2         │         │ - settings          │
│ - selectedModel     │         └─────────────────────┘
└─────────────────────┘                    │
                                           │ owns
                                           v
┌─────────────────────┐         ┌─────────────────────┐
│  ProvocationRequest │         │ ProvocationResponse │
│   (Input)           │         │    (Output)         │
├─────────────────────┤         ├─────────────────────┤
│ - selectedText      │         │ - requestId         │
│ - provocationType   │         │ - content           │
│ - prompt            │         │ - error             │
│ - timestamp         │         │ - generationTime    │
└─────────────────────┘         └─────────────────────┘
```

---

## 5. Constraints & Limits

| Constraint | Value | Rationale |
|------------|-------|-----------|
| Max text length | 1000 chars | AI model input limits, UI readability |
| Max prompt length | 1000 chars | Prevent abuse, UI constraints |
| AI timeout | 5 seconds | UX responsiveness requirement |
| Max provocations stored | 10 | Memory management, UI limits |
| Settings schema version | 1 | Future migration support |

---

## 6. JSON Examples

### 6.1 ProvocationRequest (API)
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "selectedText": "AI will replace all human jobs by 2030",
  "provocationType": "hiddenAssumptions",
  "timestamp": "2026-02-12T10:30:00Z",
  "prompt": "Identify hidden assumptions in this text"
}
```

### 6.2 ProvocationResponse (API)
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440001",
  "requestId": "550e8400-e29b-41d4-a716-446655440000",
  "originalText": "AI will replace all human jobs by 2030",
  "provocationType": "hiddenAssumptions",
  "content": "This assumes AI capabilities will advance linearly without regulatory intervention...",
  "generationTime": 1.234,
  "error": null,
  "timestamp": "2026-02-12T10:30:01Z"
}
```

### 6.3 AppSettings (UserDefaults)
```json
{
  "hotkeyModifiers": 1179648,
  "hotkeyKeyCode": 35,
  "prompt1": "Identify hidden assumptions in this text",
  "prompt2": "Provide a strong counterargument",
  "launchAtLogin": true,
  "selectedModel": "default",
  "showMenuBarIcon": true,
  "dismissOnCopy": true
}
```

---

## 7. Testing Data

### 7.1 Valid Test Cases

**Short text**:
```swift
ProvocationRequest(
    selectedText: "The sky is blue.",
    provocationType: .hiddenAssumptions,
    prompt: AppSettings.defaultPrompt1
)
```

**Long text (exactly 1000 chars)**:
```swift
ProvocationRequest(
    selectedText: String(repeating: "A", count: 1000),
    provocationType: .counterargument,
    prompt: AppSettings.defaultPrompt2
)
```

### 7.2 Invalid Test Cases

**Empty text** (should fail validation):
```swift
ProvocationRequest(
    selectedText: "",
    provocationType: .hiddenAssumptions,
    prompt: AppSettings.defaultPrompt1
)
// Error: selectedText cannot be empty
```

**Text too long** (should truncate):
```swift
ProvocationRequest(
    selectedText: String(repeating: "A", count: 1500),
    provocationType: .hiddenAssumptions,
    prompt: AppSettings.defaultPrompt1
)
// Result: Truncated to 1000 chars
```

---

## 8. Migration Notes

**Version 1.0**:
- Initial schema
- All fields required
- No migration needed (first version)

**Future Versions**:
- Add `schemaVersion` field to AppSettings
- Implement migration closure in `AppSettings.load()`
- Maintain backward compatibility

---

**Status**: COMPLETE  
**Next Step**: Generate API contracts in `/contracts/`
