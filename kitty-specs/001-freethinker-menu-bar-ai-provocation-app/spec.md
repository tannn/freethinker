# Feature Specification: FreeThinker Menu Bar AI Provocation App

**Feature ID**: 001-freethinker-menu-bar-ai-provocation-app  
**Created**: 2026-02-12  
**Mission**: software-dev  
**Status**: Draft

---

## 1. Overview

### 1.1 Purpose
FreeThinker is a macOS menu bar application that helps users think critically about selected text by generating AI-powered provocations using on-device Apple Foundation Models. The app provides instant critical thinking prompts via a floating panel that appears when users select text and press a global hotkey.

### 1.2 Problem Statement
Users often encounter text (articles, emails, arguments, claims) and want to quickly challenge their assumptions or see alternative perspectives. Existing solutions require copying text, opening a separate app or browser, and manually prompting an AI. FreeThinker eliminates this friction by providing instant, contextual provocations directly where the user is reading.

### 1.3 Solution
A lightweight menu bar app that:
- Captures selected text via global hotkey (Cmd+Shift+P)
- Generates 2 parallel provocations (hidden assumptions + counterargument) using on-device Apple Foundation Models
- Displays results in a floating panel near the cursor
- Allows users to request more provocations or dismiss the panel
- Provides customizable provocation styles via menu bar settings

---

## 2. User Scenarios & Testing

### 2.1 Primary User Flow

**Scenario**: User wants to critically analyze an article claim

**Given**: User is reading an article in Safari  
**When**: User selects text "AI will replace all human jobs by 2030"  
**And**: User presses Cmd+Shift+P
**Then**: Floating panel appears within 200ms showing:
  - Hidden Assumptions: "This assumes AI capabilities will advance linearly without regulatory intervention..."
  - Counterargument: "Historical data shows technology typically creates new job categories while displacing others..."
**And**: User can click "More..." to generate additional provocations  
**Or**: User can click outside panel or press Escape to dismiss

### 2.2 Settings Customization Flow

**Scenario**: User wants to customize provocation styles

**Given**: FreeThinker is running in menu bar  
**When**: User clicks menu bar icon → Settings  
**Then**: Settings panel opens showing:
  - Provocation 1 prompt (default: "Identify hidden assumptions in this text")
  - Provocation 2 prompt (default: "Provide a strong counterargument")
  - Global hotkey configuration (default: Cmd+Shift+P)
**And**: User can edit prompts and hotkey  
**And**: Changes persist across app launches

### 2.3 Error Handling Flow

**Scenario**: No text is selected when hotkey is pressed

**Given**: User has not selected any text  
**When**: User presses Cmd+Shift+P
**Then**: Subtle menu bar icon animation indicates "no text selected"  
**And**: No panel appears (non-intrusive feedback)

**Scenario**: AI generation fails or times out

**Given**: User has selected text and pressed hotkey  
**When**: Apple Foundation Model fails to respond within 5 seconds  
**Then**: Panel appears with error message: "Could not generate provocations. Please try again."  
**And**: Retry button is available

### 2.4 Multi-Monitor Support

**Scenario**: User works across multiple displays

**Given**: User has 2 monitors  
**When**: User selects text on secondary monitor and presses hotkey  
**Then**: Panel appears near cursor on the correct monitor  
**And**: Panel respects screen boundaries

---

## 3. Functional Requirements

### 3.1 Core Features

**FR-001**: Global Hotkey Detection  
The app shall register a global hotkey (default: Cmd+Shift+P) that works across all macOS applications.  
*Acceptance*: Hotkey triggers even when app is not frontmost.

**FR-002**: Text Capture  
The app shall capture currently selected text using macOS Accessibility API (`AXUIElementCopyAttributeValue` with `kAXSelectedTextAttribute`) when the hotkey is pressed.
*Acceptance*: Works with text selected in Safari, Mail, Notes, TextEdit, and other standard apps. Requires Accessibility permission.

**FR-003**: Dual Provocation Generation  
The app shall generate 2 parallel provocations using Apple Foundation Models:  
- Provocation 1: Hidden assumptions analysis (default prompt)  
- Provocation 2: Counterargument generation (default prompt)  
*Acceptance*: Both provocations appear in the panel within 3 seconds.

**FR-004**: Floating Panel Display  
The app shall display a floating panel near selection bounds:  
- Original selected text (truncated if >200 chars)  
- Two provocation sections with headers  
- "More..." button for additional provocations  
- Close button (X)  
- Use AXUIElementCopyAttributeValue(systemWideElement,kAXSelectedTextRangeAttribute)) for precise positioning
*Acceptance*: Panel appears within 200ms, is readable, and follows macOS design conventions.

**FR-005**: Panel Interaction  
The panel shall support:  
- Click "More..." to generate 2 new provocations on the same text  
- Click outside panel to dismiss  
- Press Escape to dismiss  
- Click X button to dismiss  
- Clicking the provocation text copies it to clipboard
*Acceptance*: All interaction methods work consistently.

**FR-006**: Menu Bar Presence  
The app shall display an icon (✨) in the macOS menu bar indicating it is running.  
*Acceptance*: Icon visible in menu bar; clicking shows menu with Settings, About, Quit options.

**FR-007**: Settings Panel  
The settings panel shall allow customization of:  
- Provocation 1 system prompt text  
- Provocation 2 system prompt text  
- Global hotkey combination  
*Acceptance*: All settings persist between app launches via UserDefaults.

**FR-008**: On-Device AI Processing  
All AI provocations shall be generated using Apple Foundation Models running locally on device.  
*Acceptance*: No network requests made for AI generation; works offline.

### 3.2 Performance Requirements

**FR-009**: Panel Display Speed  
The floating panel shall appear within 200ms of hotkey press (excluding AI generation time).  
*Acceptance*: Measured from hotkey to visible panel with loading state.

**FR-010**: AI Response Time  
Provocations shall generate within 3 seconds for text up to 500 characters.  
*Acceptance*: 95th percentile response time < 3s on M1 Mac or newer.

**FR-011**: Memory Efficiency  
The app shall use less than 200MB RAM during normal operation.  
*Acceptance*: Measured via Activity Monitor during typical usage.

### 3.3 Error Handling

**FR-012**: No Text Selected  
If hotkey is pressed with no text selected, the app shall show a subtle menu bar icon animation instead of an error dialog.  
*Acceptance*: Non-intrusive feedback; no panel appears.

**FR-013**: AI Generation Failure  
If AI generation fails or times out (>5s), the panel shall display an error message with a retry option.  
*Acceptance*: User can retry without reselecting text.

**FR-014**: Long Text Handling  
If selected text exceeds 1000 characters, the app shall truncate to first 1000 chars with visual indicator.  
*Acceptance*: Provocations generated on truncated portion; UI shows truncation notice.

---

## 4. Success Criteria

| ID | Criterion | Measurement |
|----|-----------|-------------|
| SC-001 | Users can trigger provocations from any macOS app | Tested in Safari, Mail, Notes, TextEdit, Pages |
| SC-002 | Provocations generate in under 3 seconds | 95th percentile timing on M1+ Mac |
| SC-003 | Panel appears within 200ms of hotkey | Measured via screen recording |
| SC-004 | Zero network requests for AI processing | Verified via network monitoring tools |
| SC-005 | Settings persist across app restarts | Verified via UserDefaults inspection |
| SC-006 | App uses less than 200MB RAM | Activity Monitor measurement |
| SC-007 | Works on macOS 26 (Tahoe) | Tested on target OS versions |

---

## 5. Key Entities

### 5.1 Data Models

**ProvocationRequest**
```
- selectedText: String (max 1000 chars)
- provocationType: Enum [Assumptions, Counterargument, Custom]
- timestamp: Date
```

**ProvocationResponse**
```
- originalText: String
- provocationType: Enum
- outcome: ProvocationOutcome (.success(content) | .failure(error))
- generationTime: TimeInterval
```

**AppSettings**
```
- hotkey: KeyCombination (default: Cmd+Shift+P)
- prompt1: String (default: "Identify hidden assumptions in this text")
- prompt2: String (default: "Provide a strong counterargument to this claim")
- launchAtLogin: Bool (default: false)
```

**AppState**
- isGenerating: Bool
- provocations: [ProvocationResponse]
- currentError: ProvocationError?


### 5.2 UI Components

**FloatingPanel**
- Modal panel positioned near cursor
- Contains: header, original text, provocation cards, action buttons
- Auto-dismisses on outside click

**MenuBarIcon**
- NSStatusItem in system menu bar
- Shows running state
- Menu with Settings, About, Quit

**SettingsWindow**
- Preferences window for configuration
- Prompt editing with examples
- Hotkey recording interface

---

## 6. Assumptions

1. **Target Platform**: macOS 26+ (Tahoe) with Apple Silicon required for FoundationModels support
2. **AI Framework**: Apple FoundationModels framework via `SystemLanguageModel`
3. **Accessibility**: System Accessibility permissions may be required for global hotkey and text capture
4. **Text Selection**: Accessibility APIs (`AXUIElement`) can capture selected text across most standard macOS applications
5. **Distribution**: Distributed as standalone .app via direct download (no Mac App Store sandbox)
6. **Privacy**: No user data leaves the device; no analytics or telemetry

---

## 7. Dependencies

### 7.1 System Dependencies
- macOS 26+
- Apple Silicon Mac (required)
- Accessibility permissions (for text capture)

### 7.2 Framework Dependencies
- SwiftUI (UI)
- Apple FoundationModels (on-device AI inference)
- ServiceManagement (launch at login)

### 7.3 External Dependencies
- None (fully self-contained, on-device processing)

---

## 8. Out of Scope

The following features are explicitly **not included** in this version:

1. **Multiple AI Models**: Only Apple Foundation Models; no OpenAI, Claude, or other API integrations
2. **History/Archive**: No persistence of past provocations
3. **Sharing**: No export or share functionality for provocations
4. **Custom Model Training**: Users cannot train or fine-tune models
5. **Non-English Languages**: Initial version optimized for English text
6. **iOS/iPadOS**: macOS only (no Universal app)
8. **Collaboration**: No multi-user or sync features

---

## 10. Revision History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2026-02-12 | 1.0 | spec-kitty | Initial specification |
