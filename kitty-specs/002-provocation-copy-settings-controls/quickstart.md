# Quickstart: Implement and Verify Feature 002

**Feature**: 002-provocation-copy-settings-controls  
**Date**: 2026-02-13  
**Phase**: Phase 1 - Design & Contracts

---

## Prerequisites

- macOS 26+ on Apple Silicon
- Xcode with FreeThinker project dependencies available
- Accessibility permission already configured for app run/testing

---

## 1) Open Project

```bash
cd /Users/tanner/Documents/experimental/ideas/freethinker
open FreeThinker.xcodeproj
```

---

## 2) Build Baseline

```bash
xcodebuild \
  -project FreeThinker.xcodeproj \
  -scheme FreeThinker \
  -destination 'platform=macOS' \
  -skipMacroValidation \
  build
```

---

## 3) Implement Feature Changes

Target areas:
- `FreeThinker/UI/FloatingPanel/FloatingPanelView.swift`
- `FreeThinker/UI/FloatingPanel/FloatingPanelComponents.swift`
- `FreeThinker/UI/FloatingPanel/FloatingPanelViewModel.swift`
- `FreeThinker/UI/Settings/GeneralSettingsView.swift`
- `FreeThinker/UI/MenuBar/MenuBarMenuBuilder.swift`
- `FreeThinker/UI/MenuBar/MenuBarCoordinator.swift`
- `FreeThinker/App/AppState.swift`
- Hotkey capture/validation UI files under `FreeThinker/UI/Settings/`
- Hotkey validation/service logic under `FreeThinker/Core/Services/`

---

## 4) Run Automated Tests

Run focused tests first, then full suite.

```bash
xcodebuild test \
  -project FreeThinker.xcodeproj \
  -scheme FreeThinker \
  -destination 'platform=macOS' \
  -skipMacroValidation \
  -only-testing:FreeThinkerTests/GlobalHotkeyServiceTests \
  -only-testing:FreeThinkerTests/DefaultSettingsServiceTests \
  -only-testing:FreeThinkerUITests/SettingsUITests \
  -only-testing:FreeThinkerUITests/FloatingPanelUITests
```

```bash
xcodebuild test \
  -project FreeThinker.xcodeproj \
  -scheme FreeThinker \
  -destination 'platform=macOS' \
  -skipMacroValidation
```

---

## 5) Functional Verification Checklist

- Clicking provocation text copies text to clipboard.
- No copy button is visible in floating panel.
- Clicking provocation text does not regenerate or dismiss panel.
- Settings screen has no Updates section.
- Menu dropdown has no `Check for Updates` item.
- Hotkey customization accepts valid combinations and applies immediately.
- Invalid/reserved/conflicting hotkeys are rejected with clear message and previous shortcut retained.
- Reset returns hotkey to `Cmd+Shift+P`.
- Style preset can be switched in menu dropdown.
- Style preset selected in menu appears identically in settings and persists after relaunch.

---

## 6) Regression Checks

- Trigger generation via hotkey and via menu generate action.
- Confirm panel close, pin, and regenerate actions still work.
- Confirm launch-at-login toggle behavior unchanged.

---

## References

- Spec: `kitty-specs/002-provocation-copy-settings-controls/spec.md`
- Plan: `kitty-specs/002-provocation-copy-settings-controls/plan.md`
- Research: `kitty-specs/002-provocation-copy-settings-controls/research.md`
- Data model: `kitty-specs/002-provocation-copy-settings-controls/data-model.md`
- Contracts: `kitty-specs/002-provocation-copy-settings-controls/contracts/`
