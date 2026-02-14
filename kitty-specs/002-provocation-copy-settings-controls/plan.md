# Implementation Plan: Provocation Copy & Settings Controls
*Path: kitty-specs/002-provocation-copy-settings-controls/plan.md*


**Branch**: `main` | **Date**: 2026-02-13 | **Spec**: kitty-specs/002-provocation-copy-settings-controls/spec.md
**Input**: Feature specification from `kitty-specs/002-provocation-copy-settings-controls/spec.md`

**Note**: This template is filled in by the `/spec-kitty.plan` command. See `src/specify_cli/missions/software-dev/command-templates/plan.md` for the execution workflow.

Planning alignment confirmed with stakeholder:
- Implement as one cohesive workstream.
- Include automated test coverage updates (unit + UI where applicable).

## Summary

This feature streamlines key interaction points in FreeThinker by making provocation text directly copyable, removing redundant copy controls, hiding currently disabled update controls, enabling customizable global hotkeys with robust validation and safe rollback behavior, and exposing style preset switching directly in the menu bar dropdown. The implementation keeps existing provocation generation behavior intact while improving discoverability and reducing friction in daily use.

## Technical Context

**Language/Version**: Swift 5.9+ with SwiftUI  
**Primary Dependencies**:
- AppKit + SwiftUI for macOS menu bar and settings UI
- Carbon hotkey APIs via existing `GlobalHotkeyService`
- UserDefaults-backed `DefaultSettingsService` for persistence
- Existing app state orchestration in `FreeThinker/App/AppState.swift`
  
**Storage**: UserDefaults via existing settings service (no backend)  
**Testing**: XCTest unit/integration tests and XCUITest UI tests in existing test targets  
**Target Platform**: macOS 26+ (Tahoe), Apple Silicon  
**Project Type**: Single native macOS app  
**Performance Goals**:
- Copy action from panel click responds immediately (<100ms perceived)
- Menu and settings state updates remain visually immediate
- No regressions to existing panel display or hotkey trigger responsiveness
  
**Constraints**:
- Preserve existing generation/regenerate/dismiss behavior; click on provocation text is copy-only
- Keep updates functionally disabled and hidden from visible controls
- Reject invalid/reserved/conflicting hotkeys without mutating the last valid saved shortcut
- Maintain settings sync across settings window and menu dropdown style selection
  
**Scale/Scope**: Targeted UX enhancement across floating panel, settings, menu builder/coordinator, and hotkey settings/persistence paths

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Based on `.kittify/memory/constitution.md`:

**Pre-Phase 0 Gate**:
- PASS: Languages/frameworks remain Swift + SwiftUI.
- PASS: Plan includes automated test updates in unit and UI suites.
- PASS: Performance expectation remains smooth/fast UI with no new heavy runtime work.
- PASS: Deployment constraints (macOS-only, direct distribution) remain unchanged.

**Gate Status Before Phase 0**: PASS

**Post-Phase 1 Re-check**:
- PASS: Data model and contracts are incremental and do not introduce unsupported architecture.
- PASS: Quickstart verification flow includes automated tests and regression checks.
- PASS: No constitution conflicts introduced by design artifacts.

**Gate Status After Phase 1**: PASS

## Project Structure

### Documentation (this feature)

```
kitty-specs/002-provocation-copy-settings-controls/
├── plan.md              # This file (/spec-kitty.plan command output)
├── research.md          # Phase 0 output (/spec-kitty.plan command)
├── data-model.md        # Phase 1 output (/spec-kitty.plan command)
├── quickstart.md        # Phase 1 output (/spec-kitty.plan command)
├── contracts/           # Phase 1 output (/spec-kitty.plan command)
└── tasks.md             # Phase 2 output (/spec-kitty.tasks command - NOT created by /spec-kitty.plan)
```

### Source Code (repository root)

**Selected Structure**: Existing single-project macOS app with feature-scoped UI and service layers.

```
FreeThinker/
├── App/
│   ├── AppState.swift
│   ├── AppContainer.swift
│   └── AppDelegate.swift
├── Core/
│   ├── Models/
│   │   └── AppSettings.swift
│   └── Services/
│       ├── DefaultSettingsService.swift
│       └── GlobalHotkeyService.swift
├── UI/
│   ├── FloatingPanel/
│   │   ├── FloatingPanelView.swift
│   │   ├── FloatingPanelComponents.swift
│   │   └── FloatingPanelViewModel.swift
│   ├── MenuBar/
│   │   ├── MenuBarMenuBuilder.swift
│   │   └── MenuBarCoordinator.swift
│   └── Settings/
│       ├── GeneralSettingsView.swift
│       ├── ProvocationSettingsView.swift
│       └── SettingsRootView.swift

FreeThinkerTests/
├── GlobalHotkeyServiceTests.swift
├── DefaultSettingsServiceTests.swift
└── AppStateOnboardingTests.swift

FreeThinkerUITests/
├── FloatingPanelUITests.swift
└── SettingsUITests.swift
```

**Structure Decision**: Keep existing Clean Architecture boundaries and implement all changes in place. No new top-level modules are required.

## Complexity Tracking

*Fill ONLY if Constitution Check has violations that must be justified*

No constitution violations identified.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | N/A | N/A |
