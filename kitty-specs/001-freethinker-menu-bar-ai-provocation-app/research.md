# Research: FreeThinker Technical Decisions

**Feature**: 001-freethinker-menu-bar-ai-provocation-app  
**Date**: 2026-02-12  
**Research Phase**: Phase 0 - Architecture & Technology Selection

---

## Executive Summary

This document consolidates research findings and technical decisions for the FreeThinker macOS application. All planning questions have been resolved through stakeholder consultation and best practices analysis.

---

## 1. AI Framework Selection

### Decision
**Apple FoundationModels Framework** with SystemLanguageModel API

### Rationale
- **Native Integration**: First-party Apple framework designed for on-device inference
- **Privacy**: All processing happens locally, no network requests
- **Performance**: Optimized for Apple Silicon Neural Engine
- **Simplicity**: Single API for model loading and inference
- **Future-Proof**: Apple's primary path for on-device AI on macOS

### Implementation Approach
```swift
// Default configuration
let model = SystemLanguageModel.default

// User-upgradeable to larger model
let creativeModel = SystemLanguageModel(useCase: .creativeWriting)
```

### Alternatives Considered
| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| MLX Swift | Open source, model flexibility | Requires manual model management, more complex | Rejected - too complex for MVP |
| Apple Intelligence APIs | System integration | Limited to macOS 26+, may not support custom prompts | Rejected - too restrictive |
| Core ML with custom models | Full control | Requires model conversion, maintenance burden | Rejected - overkill for text generation |

### Model Size Strategy
- **Default**: SystemLanguageModel.default (~4GB, fast inference <1s)
- **Optional**: SystemLanguageModel.creativeWriting (~8GB, better reasoning ~2s)
- **User Control**: Settings panel allows switching between models

---

## 2. Distribution Method

### Decision
**Direct Download Only** (NOT Mac App Store)

### Rationale
- **Accessibility API Requirements**: Text capture via AXUIElement requires full Accessibility permissions
- **Sandbox Limitations**: Mac App Store sandboxing severely restricts Accessibility API access
- **Entitlement Flexibility**: Direct distribution allows `com.apple.security.automation.apple-events` without review complications
- **User Experience**: Menu bar apps work better outside sandbox (helper processes, global hotkeys)

### Implementation
- **Distribution**: .dmg/.zip via GitHub Releases or website
- **Code Signing**: Developer ID signing for Gatekeeper compatibility
- **Notarization**: Required for macOS 10.15+ (automated via CI)

### Alternatives Considered
| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| Mac App Store | Easy distribution, auto-updates | Sandbox blocks Accessibility, restricted APIs | Rejected - incompatible with core feature |
| Both channels | Maximum reach | Double build complexity, sandbox vs non-sandbox divergence | Rejected - unnecessary complexity |
| TestFlight (Mac) | Beta distribution | Still sandboxed, limited to testers | Rejected - doesn't solve sandbox issue |

---

## 3. Global Hotkey Strategy

### Decision
**Cmd+Shift+P** (as shown in spec user scenarios)

### Rationale
- **Consistency**: Matches the spec's primary user flow example
- **Conflict Analysis**:
  - Cmd+Shift+O: Conflicts with OmniFocus, Obsidian, other productivity apps
  - Cmd+Shift+P: Less common, primarily used for "Print" (typically Cmd+P)
  - User-customizable via Settings for personal workflows
- **Accessibility**: Easy to remember ("P" for Provocation)

### Implementation
```swift
// Using NSEvent addGlobalMonitorForEvents
let keyMask: NSEvent.ModifierFlags = [.command, .shift]
let keyCode: UInt16 = 0x23 // 'P' key

// User-customizable via Settings
@AppStorage("hotkeyModifiers") var hotkeyModifiers: Int = ...
@AppStorage("hotkeyKeyCode") var hotkeyKeyCode: Int = 0x23
```

---

## 4. Launch at Login

### Decision
**Include in MVP** using SMAppService (macOS 13+)

### Rationale
- **User Expectation**: Menu bar apps conventionally support launch-at-login
- **Low Friction**: Users expect AI tools to be always available
- **Modern API**: SMAppService replaces deprecated SMLoginItemSetEnabled
- **Manageable Complexity**: ~1 day implementation using ServiceManagement framework

### Implementation
```swift
import ServiceManagement

// Register helper app
let helperAppId = "com.freethinker.launcher"
try SMAppService.mainApp.register()
```

### Requirements
- Helper app target in Xcode project
- `SMAppService` entitlement
- User preference stored in UserDefaults
- Toggle in Settings panel

---

## 5. Text Capture Architecture

### Decision
**Accessibility API (AXUIElement)** with fallbacks

### Rationale
- **Universal Support**: Works across all standard macOS apps
- **No Clipboard**: Doesn't interfere with user's pasteboard
- **Precise Positioning**: Can obtain selection bounds for panel placement
- **Standard Pattern**: Used by similar apps (TextSniper, PopClip, etc.)

### Implementation Strategy
```swift
// Get system-wide accessibility element
let systemWide = AXUIElementCreateSystemWide()

// Get focused UI element
var focusedElement: CFTypeRef?
AXUIElementCopyAttributeValue(
    systemWide,
    kAXFocusedUIElementAttribute as CFString,
    &focusedElement
)

// Get selected text
var selectedText: CFTypeRef?
AXUIElementCopyAttributeValue(
    focusedElement as! AXUIElement,
    kAXSelectedTextAttribute as CFString,
    &selectedText
)

// Get selection bounds for positioning
var selectedRange: CFTypeRef?
AXUIElementCopyAttributeValue(
    focusedElement as! AXUIElement,
    kAXSelectedTextRangeAttribute as CFString,
    &selectedRange
)
```

### Permission Handling
- **Request on First Launch**: Guide user to System Settings -> Privacy & Security -> Accessibility
- **Check Before Capture**: Verify permission granted before attempting capture
- **Graceful Degradation**: If no permission, show instructional panel

### Fallbacks
- **Pasteboard Access**: If Accessibility fails, optional pasteboard monitoring (user opt-in)
- **Manual Input**: Settings panel allows manual text entry for testing

---

## 6. UI Architecture

### Decision
**SwiftUI with AppKit Integration**

### Rationale
- **Modern**: SwiftUI is Apple's preferred UI framework
- **Rapid Development**: Declarative syntax speeds up implementation
- **Integration**: NSHostingController allows embedding in AppKit components (NSPanel, NSStatusBar)
- **Future-Proof**: Better long-term support than pure AppKit

### Component Breakdown

#### Floating Panel
- **Type**: NSPanel subclass with SwiftUI content
- **Behavior**: 
  - Non-activating (doesn't steal focus from source app)
  - Auto-dismisses on outside click
  - Positions near selection bounds
- **Content**: SwiftUI view with provocation cards

#### Menu Bar Icon
- **Type**: NSStatusItem
- **SwiftUI Integration**: Menu content via NSHostingView
- **Features**:
  - Status icon (sparkle emoji  [✨] or custom SF Symbol)
  - Dropdown menu with Settings, About, Quit
  - Animation support for "no text selected" feedback

#### Settings Window
- **Type**: Settings SwiftUI scene (macOS 13+)
- **Tabs**:
  - General (hotkey, launch at login)
  - Prompts (customize provocation prompts)
  - About (version, acknowledgments)

---

## 7. Data Persistence

### Decision
**UserDefaults** with Codable models

### Rationale
- **Simple**: No external dependencies
- **Appropriate Scale**: Small amount of structured data (settings only)
- **Performance**: Synchronous, zero-latency access
- **iCloud Sync**: Automatic via NSUbiquitousKeyValueStore (optional)

### Data Model
```swift
struct AppSettings: Codable {
    var hotkeyModifiers: Int
    var hotkeyKeyCode: Int
    var prompt1: String
    var prompt2: String
    var launchAtLogin: Bool
    var selectedModel: ModelOption
}

enum ModelOption: String, Codable {
    case `default` = "default"
    case creativeWriting = "creativeWriting"
}
```

### Migration Strategy
- **Versioning**: Store settings version in UserDefaults
- **Defaults**: Hardcoded defaults for missing values
- **No Migration Needed for MVP**: First version, no legacy data

---

## 8. Testing Strategy

### Unit Tests
- **AIService**: Mock SystemLanguageModel, test prompt construction
- **SettingsService**: Verify UserDefaults read/write
- **TextCaptureService**: Mock AXUIElement responses

### Integration Tests
- **Accessibility API**: Test with real macOS apps (Notes, TextEdit)
- **End-to-End**: Select text -> hotkey -> provocations displayed

### UI Tests
- **XCUITest**: Settings panel navigation, hotkey recording
- **Manual**: Multi-monitor support, dark mode, various text sources

### Performance Tests
- **Panel Display**: <200ms from hotkey to visible (instrumented)
- **AI Response**: <3s for 500 char text (95th percentile)
- **Memory**: <200MB during normal operation (Activity Monitor)

---

## 9. Open Questions Resolved

All planning questions have been answered:

| Question | Answer | Rationale |
|----------|--------|-----------|
| AI Framework | Apple FoundationModels | Native, private, performant |
| Model Size | Default with creative option | Fast default, quality option available |
| Default Hotkey | Cmd+Shift+P | Matches spec, less conflicts |
| Launch at Login | Include in MVP | User expectation, manageable complexity |
| Distribution | Direct Download | Accessibility API requires non-sandbox |

---

## 10. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Accessibility API permission friction | High | Medium | Clear onboarding, instructional UI |
| FoundationModels API changes | Low | High | Abstract behind AIService protocol |
| AI response time >3s | Medium | Medium | User-selectable model sizes, progress UI |
| Multi-monitor positioning bugs | Medium | Low | Test on various configurations |
| macOS version compatibility | Low | Medium | Target macOS 26+ only |

---

## References

- [Apple FoundationModels Documentation](https://developer.apple.com/documentation/foundationmodels)
- [Accessibility Programming Guide](https://developer.apple.com/library/archive/documentation/Accessibility/Conceptual/AccessibilityMacOSX/)
- [SMAppService Documentation](https://developer.apple.com/documentation/servicemanagement/smappservice)
- [SwiftUI App Lifecycle](https://developer.apple.com/documentation/swiftui/app)

---

**Status**: COMPLETE - All Phase 0 research questions resolved  
**Next Step**: Phase 1 - Generate data-model.md and contracts/
