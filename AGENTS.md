# Agent Context: FreeThinker

**Agent**: opencode  
**Feature**: 001-freethinker-menu-bar-ai-provocation-app  
**Updated**: 2026-02-12

---

## Active Technologies

- Swift 5.9+ with SwiftUI + - Apple FoundationModels framework (SystemLanguageModel API) (001-freethinker-menu-bar-ai-provocation-app)
- UserDefaults (settings persistence), no backend (001-freethinker-menu-bar-ai-provocation-app)
### Primary Stack
- **Language**: Swift 5.9+
- **Framework**: SwiftUI
- **Platform**: macOS 26 (Tahoe)
- **Architecture**: Native macOS app with Clean Architecture

### Core Dependencies
- **Apple FoundationModels**: On-device AI inference via SystemLanguageModel API
- **ServiceManagement**: Launch at login support (SMAppService)
- **Sparkle**: Auto-update framework for direct distribution
- **Accessibility APIs**: AXUIElement for text capture

### Project Structure
```
FreeThinker/
├── App/              # Entry points (AppDelegate, main)
├── Core/             # Business logic
│   ├── Models/       # ProvocationRequest, ProvocationResponse, AppSettings
│   ├── Services/     # AIService, TextCaptureService, SettingsService
│   └── Utilities/    # Extensions
├── UI/               # SwiftUI views
│   ├── FloatingPanel/# Provocation display panel
│   ├── MenuBar/      # Status bar icon and menu
│   └── Settings/     # Preferences window
└── Resources/        # Assets, Info.plist
```

---

## Recent Changes
- 001-freethinker-menu-bar-ai-provocation-app: Added Swift 5.9+ with SwiftUI + - Apple FoundationModels framework (SystemLanguageModel API)
### Phase 1 - Design Complete (2026-02-12)
- ✅ Data models defined (data-model.md)
- ✅ Service contracts documented (contracts/)
- ✅ Quickstart guide created (quickstart.md)
- ✅ Research document complete (research.md)

### Key Decisions
- **Distribution**: Direct download (NOT Mac App Store) for Accessibility API access
- **AI Framework**: Apple FoundationModels with SystemLanguageModel.default
- **Global Hotkey**: Cmd+Shift+P
- **Launch at Login**: Included in MVP using SMAppService

---

## Development Guidelines

### Code Patterns
- Use `async/await` for asynchronous operations
- Implement services as protocols for testability
- Use `@Observable` for SwiftUI state management
- Follow Actor isolation for thread safety in services

### Testing Requirements
- Unit tests for all services (mock protocols)
- Integration tests for Accessibility API
- UI tests for critical user flows
- Performance tests for AI response time

### Constraints
- Sandboxing disabled (Accessibility requirement)
- macOS 26+ only (FoundationModels requirement)
- Apple Silicon required (Neural Engine)
- Zero network requests for AI processing

---

## Reference Documents

- **Plan**: `kitty-specs/001-freethinker-menu-bar-ai-provocation-app/plan.md`
- **Spec**: `kitty-specs/001-freethinker-menu-bar-ai-provocation-app/spec.md`
- **Research**: `kitty-specs/001-freethinker-menu-bar-ai-provocation-app/research.md`
- **Data Model**: `kitty-specs/001-freethinker-menu-bar-ai-provocation-app/data-model.md`
- **Contracts**: `kitty-specs/001-freethinker-menu-bar-ai-provocation-app/contracts/`
- **Quickstart**: `kitty-specs/001-freethinker-menu-bar-ai-provocation-app/quickstart.md`

---

<!-- MANUAL ADDITIONS - These will be preserved by update-context command -->

<!-- END MANUAL ADDITIONS -->
