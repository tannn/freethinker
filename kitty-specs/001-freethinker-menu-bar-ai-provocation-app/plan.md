# Implementation Plan: FreeThinker Menu Bar AI Provocation App
*Path: kitty-specs/001-freethinker-menu-bar-ai-provocation-app/plan.md*


**Branch**: `001-freethinker-menu-bar-ai-provocation-app` | **Date**: 2026-02-12 | **Spec**: kitty-specs/001-freethinker-menu-bar-ai-provocation-app/spec.md
**Input**: Feature specification from `kitty-specs/001-freethinker-menu-bar-ai-provocation-app/spec.md`

**Note**: This template is filled in by the `/spec-kitty.plan` command. See `src/specify_cli/missions/software-dev/command-templates/plan.md` for the execution workflow.

The planner will not begin until all planning questions have been answered—capture those answers in this document before progressing to later phases.

## Summary

FreeThinker is a macOS menu bar application that provides instant AI-powered provocations for selected text using on-device Apple Foundation Models. When users select text and press a global hotkey (Cmd+Shift+P), a floating panel appears displaying hidden assumptions and counterarguments generated locally without network requests. The app features customizable provocation prompts, settings persistence, and launch-at-login support, distributed as a direct-download .app with full Accessibility API access.

## Technical Context

**Language/Version**: Swift 5.9+ with SwiftUI  
**Primary Dependencies**: 
- Apple FoundationModels framework (SystemLanguageModel API)
- ServiceManagement framework (launch at login)
- Sparkle framework (auto-updates for direct distribution)
- Accessibility APIs (AXUIElement for text capture)
- Global hotkey monitoring (NSEvent addGlobalMonitorForEvents/mask:)
  
**Storage**: UserDefaults (settings persistence), no backend  
**Testing**: XCTest (unit tests), XCUITest (UI tests), manual accessibility testing  
**Target Platform**: macOS 26 (Tahoe) with Apple Silicon (M1+) required  
**Project Type**: Single native macOS app  
**Performance Goals**: 
- Panel display within 200ms of hotkey
- AI provocations generated within 3 seconds (95th percentile)
- App memory usage under 200MB during normal operation
  
**Constraints**: 
- Zero network requests for AI processing (offline capable)
- Full Accessibility API access required for text capture
- Sandbox restrictions avoided via direct distribution
- macOS 26 minimum for optimal FoundationModels support
  
**Scale/Scope**: Single-user desktop application, no server-side components, no multi-user support

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Based on `/Users/tanner/Documents/experimental/ideas/freethinker/.kittify/memory/constitution.md`:

**Technical Standards Compliance**:
- ✅ Languages: Swift, SwiftUI - CONFIRMED
- ✅ Testing: Unit, integration, and UI tests required - WILL IMPLEMENT
- ✅ Performance: Smooth, fast UI - TARGET: 200ms panel display, <3s AI response
- ✅ Platform: macOS only, direct distribution - CONFIRMED

**Gate Status**: PASS - All constitution requirements can be met with planned architecture.

**Re-check after Phase 1**: Verify data model supports testability, UI design meets performance goals.

## Project Structure

### Documentation (this feature)

```
kitty-specs/001-freethinker-menu-bar-ai-provocation-app/
├── plan.md              # This file (/spec-kitty.plan command output)
├── research.md          # Phase 0 output (/spec-kitty.plan command)
├── data-model.md        # Phase 1 output (/spec-kitty.plan command)
├── quickstart.md        # Phase 1 output (/spec-kitty.plan command)
├── contracts/           # Phase 1 output (/spec-kitty.plan command)
└── tasks.md             # Phase 2 output (/spec-kitty.tasks command - NOT created by /spec-kitty.plan)
```

### Source Code (repository root)

**Selected Structure**: Single native macOS application using standard Xcode project layout

```
FreeThinker/
├── FreeThinker.xcodeproj/
├── FreeThinker/
│   ├── App/
│   │   ├── FreeThinkerApp.swift          # App entry point, menu bar setup
│   │   └── AppDelegate.swift             # Lifecycle management
│   ├── Core/
│   │   ├── Models/
│   │   │   ├── ProvocationRequest.swift
│   │   │   ├── ProvocationResponse.swift
│   │   │   ├── AppSettings.swift
│   │   │   └── AppState.swift
│   │   ├── Services/
│   │   │   ├── TextCaptureService.swift  # Accessibility API integration
│   │   │   ├── HotkeyService.swift       # Global hotkey monitoring
│   │   │   ├── AIService.swift           # FoundationModels wrapper
│   │   │   └── SettingsService.swift     # UserDefaults persistence
│   │   └── Utilities/
│   │       └── Extensions/
│   ├── UI/
│   │   ├── FloatingPanel/
│   │   │   ├── FloatingPanelView.swift
│   │   │   ├── ProvocationCardView.swift
│   │   │   └── FloatingPanelController.swift
│   │   ├── MenuBar/
│   │   │   ├── MenuBarIcon.swift
│   │   │   └── StatusMenuView.swift
│   │   └── Settings/
│   │       ├── SettingsWindow.swift
│   │       ├── PromptSettingsView.swift
│   │       └── HotkeySettingsView.swift
│   └── Resources/
│       ├── Assets.xcassets/
│       └── Info.plist
├── FreeThinkerTests/
│   ├── Unit/
│   │   ├── AIServiceTests.swift
│   │   ├── TextCaptureServiceTests.swift
│   │   └── SettingsServiceTests.swift
│   └── Integration/
│       └── AccessibilityIntegrationTests.swift
├── FreeThinkerUITests/
│   └── FreeThinkerUITests.swift
└── Frameworks/
    └── Sparkle.framework (auto-update)
```

**Structure Decision**: Standard Xcode project with Clean Architecture separation:
- `App/` - Entry points and lifecycle
- `Core/` - Business logic, models, and services
- `UI/` - SwiftUI views organized by feature
- `Resources/` - Assets and configuration
- Test targets mirror source structure for maintainability

## Complexity Tracking

*Fill ONLY if Constitution Check has violations that must be justified*

**Status**: No constitution violations. All technical decisions align with:
- Swift/SwiftUI mandate
- Testing requirements (unit, integration, UI)
- Performance goals (smooth, fast UI)
- Platform constraints (macOS only, direct distribution)

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | N/A | N/A |