---
work_package_id: WP04
title: Hotkey Customization Settings UX
lane: "planned"
dependencies:
- WP01
- WP03
base_branch: 002-provocation-copy-settings-controls-WP03
base_commit: a110118b26a2988343afe00c72b4f33483fd1eb6
created_at: '2026-02-14T07:56:48.417183+00:00'
subtasks:
- T014
- T015
- T016
- T017
- T018
phase: Phase 2 - User Story Delivery
assignee: ''
agent: ''
shell_pid: ''
review_status: "has_feedback"
reviewed_by: "Tanner"
history:
- timestamp: '2026-02-14T07:24:26Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP04 - Hotkey Customization Settings UX

## ⚠️ IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- If `review_status` is `has_feedback`, handle every feedback item before completion.
- Keep activity log appended in chronological order.

---

## Review Feedback

*[This section is empty initially.]*

---

---

**Reviewed by**: Tanner
**Status**: ❌ Changes Requested
**Date**: 2026-02-14

**Issue 1 (dependency contract mismatch)**: `WP04` duplicates hotkey validation/application logic in `FreeThinker/App/AppState.swift` (`applyHotkeyShortcut(modifiers:keyCode:)`, local reserved/invalid checks, and `onHotkeyRegistrationValidationRequested`) instead of consuming the WP01 canonical hotkey API/result pathway. This breaks the dependency intent (`WP04` depends on `WP01`) and risks divergent behavior/messages between settings and hotkey service.  
**How to fix**: Rebase WP04 onto latest `main`, remove the duplicate AppState validation pathway, and wire `GeneralSettingsView` to WP01 hotkey types/APIs (single canonical validation/apply/reset path and status messaging).

**Issue 2 (FR-009 rollback gap)**: The current flow validates first (`onHotkeyRegistrationValidationRequested`) and then persists via `updateSettings`, while actual registration happens later in `onSettingsUpdated -> hotkeyService.refreshRegistration(...)` (`FreeThinker/App/AppContainer.swift`). If registration fails after precheck (timing/race/unavailable state), settings can be persisted even though the hotkey did not register, violating FR-009 (“current saved shortcut remains unchanged” on rejection).  
**How to fix**: Make hotkey apply atomic with registration outcome before persistence (or reuse WP01 rollback semantics), so rejected/unavailable registrations never mutate persisted shortcut values.

**Dependent Rebase Warning**: WP05 depends on WP04 and must rebase after WP04 is fixed.  
Command: `cd /Users/tanner/Documents/experimental/ideas/freethinker/.worktrees/002-provocation-copy-settings-controls-WP05 && git rebase 002-provocation-copy-settings-controls-WP04`

## Objectives & Success Criteria

- Provide a user-facing settings control to customize the global hotkey key combo.
- Reject invalid/reserved/conflicting combos with clear reason messaging.
- Keep previous valid shortcut active when a proposal is rejected.
- Provide reset-to-default action restoring `Cmd+Shift+P`.
- Cover the full flow with automated tests for acceptance and rejection paths.

## Implementation Command

- Run with dependency base: `spec-kitty implement WP04 --base WP03`

## Context & Constraints

- WP01 provides validation/apply/reset primitives; consume those APIs instead of duplicating logic.
- Must satisfy FR-007 to FR-011.
- This package will likely modify `GeneralSettingsView`; coordinate with WP03 changes (updates section removal) to avoid merge drift.
- Keep behavior consistent with existing settings persistence and hotkey re-registration lifecycle in `AppContainer`.
- Preserve reachability guardrail (cannot disable both menu bar icon and hotkey).

## Subtasks & Detailed Guidance

### Subtask T014 - Add settings UI for hotkey capture and display
- **Purpose**: Provide discoverable customization controls in Settings.
- **Steps**:
  1. Add a hotkey customization group to settings (recommended inside General section unless a dedicated subview improves maintainability).
  2. Display current shortcut in a user-friendly label.
  3. Add capture/edit interaction for modifier + key combination.
  4. Add explicit reset button for default shortcut.
- **Files**:
  - `FreeThinker/UI/Settings/GeneralSettingsView.swift`
  - `FreeThinker/UI/Settings/` (new helper view file if needed)
- **Parallel?**: No.
- **Notes**:
  - Avoid custom UI complexity that cannot be tested in unit/UI tests.

### Subtask T015 - Wire UI to apply/reset APIs and feedback state
- **Purpose**: Connect interaction controls to validation-backed state mutation.
- **Steps**:
  1. Bind proposed shortcut edits to WP01 `AppState` APIs.
  2. Surface success and failure messages near the hotkey controls.
  3. Ensure failure messages distinguish invalid/reserved/conflict outcomes.
  4. Confirm rejected edits do not mutate displayed saved shortcut.
- **Files**:
  - `FreeThinker/UI/Settings/GeneralSettingsView.swift`
  - `FreeThinker/App/AppState.swift`
- **Parallel?**: No.
- **Notes**:
  - Keep feedback messaging concise and actionable.

### Subtask T016 - Ensure apply flow persists and re-registers safely
- **Purpose**: Guarantee valid changes become active and survive relaunch.
- **Steps**:
  1. Confirm valid apply path updates settings and triggers persistence callback.
  2. Confirm registration refresh occurs through existing `onSettingsUpdated` wiring.
  3. Confirm rejected proposals do not trigger persistence writes.
  4. Confirm reset path follows the same safe apply flow.
- **Files**:
  - `FreeThinker/App/AppContainer.swift`
  - `FreeThinker/App/AppState.swift`
  - `FreeThinker/Core/Services/DefaultSettingsService.swift`
  - `FreeThinker/Core/Services/GlobalHotkeyService.swift`
- **Parallel?**: No.
- **Notes**:
  - Do not add hidden fallback side effects; deterministic behavior is required.

### Subtask T017 - Add/maintain accessibility identifiers for hotkey UX
- **Purpose**: Keep UI automation stable and assistive tooling clear.
- **Steps**:
  1. Add new accessibility IDs for hotkey editor input, reset button, and feedback text.
  2. Preserve existing settings identifiers unless intentionally replaced.
  3. Update any identifier assertion tests impacted by the new controls.
- **Files**:
  - `FreeThinker/UI/Settings/SettingsAccessibility.swift`
  - `FreeThinker/UI/Settings/GeneralSettingsView.swift`
  - `FreeThinkerUITests/SettingsUITests.swift`
- **Parallel?**: Yes (after T014 control layout decisions).
- **Notes**:
  - Keep identifier naming consistent with current conventions (`settings.general.*`).

### Subtask T018 - Add automated tests for valid/invalid/reset hotkey flows
- **Purpose**: Enforce safe behavior and prevent regressions.
- **Steps**:
  1. Add tests for successful hotkey update and persistence.
  2. Add tests for invalid/reserved/conflict attempts preserving previous shortcut.
  3. Add tests for reset-to-default behavior.
  4. Add assertions for user feedback messaging semantics where feasible.
  5. Ensure tests cover synchronization between UI representation and underlying settings values.
- **Files**:
  - `FreeThinkerUITests/SettingsUITests.swift`
  - `FreeThinkerTests/GlobalHotkeyServiceTests.swift`
  - `FreeThinkerTests/DefaultSettingsServiceTests.swift` (if persistence edge cases are added)
- **Parallel?**: No.
- **Notes**:
  - Prefer scenario-driven assertions over implementation-detail checks.

## Test Strategy

- Run hotkey-focused tests first:
```bash
xcodebuild test \
  -project FreeThinker.xcodeproj \
  -scheme FreeThinker \
  -destination 'platform=macOS' \
  -skipMacroValidation \
  -only-testing:FreeThinkerTests/GlobalHotkeyServiceTests \
  -only-testing:FreeThinkerUITests/SettingsUITests
```
- Run broader suite before review handoff.

## Risks & Mitigations

- **Risk**: UI shows new shortcut while underlying registration failed.
- **Mitigation**: Apply only after validation and registration success; keep old state otherwise.
- **Risk**: Shortcut capture UX becomes brittle or hard to test.
- **Mitigation**: Keep capture model simple and backed by deterministic value types.

## Review Guidance

- Verify valid shortcut updates become active and persisted.
- Verify invalid/reserved/conflict proposals keep prior shortcut unchanged.
- Verify reset reliably restores `Cmd+Shift+P`.
- Verify accessibility IDs and feedback strings are stable and testable.

## Activity Log

- 2026-02-14T07:24:26Z - system - lane=planned - Prompt created.
- 2026-02-14T07:56:47Z – unknown – lane=doing – Automated: start implementation
- 2026-02-14T08:07:48Z – unknown – lane=doing – Automated: start implementation
- 2026-02-14T17:51:47Z – unknown – lane=planned – Moved to planned
