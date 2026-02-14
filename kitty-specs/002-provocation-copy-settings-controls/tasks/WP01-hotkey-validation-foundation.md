---
work_package_id: "WP01"
subtasks:
  - "T001"
  - "T002"
  - "T003"
  - "T004"
title: "Hotkey Validation Foundation"
phase: "Phase 1 - Foundation"
lane: "planned"
dependencies: []
assignee: ""
agent: ""
shell_pid: ""
review_status: ""
reviewed_by: ""
history:
  - timestamp: "2026-02-14T07:24:26Z"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
---

# Work Package Prompt: WP01 - Hotkey Validation Foundation

## ⚠️ IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately.
- **You must address all feedback** before your work is complete.
- **Mark as acknowledged**: When you begin addressing feedback, set `review_status: acknowledged`.

---

## Review Feedback

*[This section is empty initially. Reviewers will populate it if rework is needed.]*

---

## Objectives & Success Criteria

- Introduce a dedicated, testable hotkey validation pathway that can evaluate a proposed shortcut before persistence.
- Ensure invalid, reserved, or conflicting shortcuts are rejected without overwriting the previously active shortcut.
- Provide API-level support for reset-to-default (`Cmd+Shift+P`) and user-facing feedback hooks.
- Pass all new/updated unit tests covering valid apply, rejection outcomes, and rollback semantics.

## Implementation Command

- Base command: `spec-kitty implement WP01`

## Context & Constraints

- This is the foundation package for all hotkey customization UI work.
- Keep behavior aligned with `kitty-specs/002-provocation-copy-settings-controls/spec.md` FR-007 through FR-011.
- Preserve current app reachability guardrail: hotkey/menu bar icon safety logic must remain intact.
- Do not introduce network dependencies or persistence layers beyond existing UserDefaults-backed settings.
- Align with constitution in `.kittify/memory/constitution.md` (Swift/SwiftUI and automated tests required).

## Subtasks & Detailed Guidance

### Subtask T001 - Define hotkey model + validation result types
- **Purpose**: Create explicit types for proposed/effective shortcuts and validation outcomes.
- **Steps**:
  1. Add value types (or extend existing model surfaces) to represent a hotkey combo (`modifiers`, `keyCode`, display helper).
  2. Define a validation result type that distinguishes `valid`, `invalid`, `reserved`, and `conflict`.
  3. Include payload fields needed for UI messaging and rollback (`message`, `effective shortcut`).
  4. Keep types `Sendable`/`Equatable` where appropriate for testability.
- **Files**:
  - `FreeThinker/Core/Models/AppSettings.swift`
  - `FreeThinker/Core/Models/` (new file(s) if needed)
  - `FreeThinker/Core/Utilities/` (formatter helpers if needed)
- **Parallel?**: No.
- **Notes**:
  - Prefer a dedicated type over reusing raw integers throughout view and service layers.

### Subtask T002 - Implement validation rules and conflict classification
- **Purpose**: Centralize all shortcut acceptance/rejection logic before settings mutation.
- **Steps**:
  1. Add a validation pathway that checks unsupported key codes and empty/invalid modifier combos.
  2. Add reserved-shortcut checks for combinations the app must not accept.
  3. Integrate with existing `GlobalHotkeyService` registration behavior to classify conflicts safely.
  4. Ensure mapping remains consistent with existing error handling (`conflict` vs generic registration failure).
  5. Keep validation callable without mutating persisted settings until acceptance is confirmed.
- **Files**:
  - `FreeThinker/Core/Services/GlobalHotkeyService.swift`
  - `FreeThinker/Core/Utilities/FreeThinkerError.swift`
  - `FreeThinker/Core/Utilities/ErrorPresentationMapper.swift`
- **Parallel?**: No.
- **Notes**:
  - Avoid re-registering global hotkeys unnecessarily during pure validation checks.

### Subtask T003 - Add AppState hotkey propose/apply/reset APIs
- **Purpose**: Provide a safe mutation surface for settings UI to use.
- **Steps**:
  1. Add `AppState` methods for proposing/applying a new shortcut with validation result return.
  2. Ensure failed proposals keep prior saved values intact.
  3. Add reset method that restores default `Cmd+Shift+P` values.
  4. Expose actionable feedback message fields used by settings UI.
  5. Confirm settings persistence callbacks only run for successful changes.
- **Files**:
  - `FreeThinker/App/AppState.swift`
  - `FreeThinker/App/AppContainer.swift` (if callback wiring adjustments are needed)
- **Parallel?**: No.
- **Notes**:
  - Keep this API free of view-specific concerns; return structured result types.

### Subtask T004 - Add unit tests for validation, rollback, and reset
- **Purpose**: Lock expected behavior before UI package depends on it.
- **Steps**:
  1. Add test cases for successful apply of a valid shortcut.
  2. Add test cases for invalid/reserved/conflict proposals preserving previous shortcut.
  3. Add test cases for reset-to-default.
  4. Add regression test ensuring rejected proposals do not trigger persisted settings writes.
  5. Verify tests are deterministic and do not require OS-level hotkey registration.
- **Files**:
  - `FreeThinkerTests/GlobalHotkeyServiceTests.swift`
  - `FreeThinkerUITests/SettingsUITests.swift` (or move to unit target if better fit)
  - `FreeThinkerTests/` (new targeted test file if needed)
- **Parallel?**: Yes (after T001 contracts stabilize).
- **Notes**:
  - Use mock registrar and in-memory settings to avoid flaky integration coupling.

## Test Strategy

- Run targeted tests for this package:
```bash
xcodebuild test \
  -project FreeThinker.xcodeproj \
  -scheme FreeThinker \
  -destination 'platform=macOS' \
  -skipMacroValidation \
  -only-testing:FreeThinkerTests/GlobalHotkeyServiceTests \
  -only-testing:FreeThinkerUITests/SettingsUITests
```
- Confirm new tests cover all validation statuses and reset behavior.

## Risks & Mitigations

- **Risk**: Validation logic split across UI and service layers creates inconsistent outcomes.
- **Mitigation**: Keep one canonical validation path used by all entry points.
- **Risk**: Regression to existing hotkey behavior while adding new APIs.
- **Mitigation**: Preserve existing registration tests and extend rather than replace assertions.

## Review Guidance

- Verify shortcuts are not persisted on failed validation.
- Verify reset route always lands on `Cmd+Shift+P`.
- Verify conflict/rejection reasons are specific enough for UI messaging.
- Verify tests prove behavior rather than merely asserting method calls.

## Activity Log

- 2026-02-14T07:24:26Z - system - lane=planned - Prompt created.
