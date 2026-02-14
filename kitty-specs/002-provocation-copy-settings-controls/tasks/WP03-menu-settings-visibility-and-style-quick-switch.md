---
work_package_id: "WP03"
subtasks:
  - "T009"
  - "T010"
  - "T011"
  - "T012"
  - "T013"
title: "Menu/Settings Visibility and Style Quick Switch"
phase: "Phase 2 - User Story Delivery"
lane: "doing"
dependencies:
  - "WP01"
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

# Work Package Prompt: WP03 - Menu/Settings Visibility and Style Quick Switch

## ⚠️ IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- Check `review_status` in frontmatter.
- Address any populated feedback before requesting review.

---

## Review Feedback

*[This section is empty initially.]*

---

## Objectives & Success Criteria

- Hide update controls from settings and remove update-check action from menu.
- Keep update-related persistence fields intact for future re-enable.
- Add style preset quick-switch entries in menu dropdown.
- Ensure style selection from menu is reflected in settings state and persisted across sessions.
- Add automated coverage for menu descriptor composition and synchronization behavior.

## Implementation Command

- Run with dependency base: `spec-kitty implement WP03 --base WP01`

## Context & Constraints

- Must satisfy FR-004, FR-005, FR-006, FR-012, and FR-013.
- This package touches shared menu/settings wiring; avoid introducing stale callbacks.
- Keep one source of truth for selected style preset (`AppState.settings.provocationStylePreset`).
- No update check UI or menu control should remain visible in current build.

## Subtasks & Detailed Guidance

### Subtask T009 - Hide updates controls in settings and disconnect callbacks
- **Purpose**: Remove disabled feature affordances from settings UI.
- **Steps**:
  1. Remove/hide the Updates group from `GeneralSettingsView`.
  2. Remove update-specific accessibility identifiers that no longer apply.
  3. Remove update callback plumbing from `SettingsRootView` and `SettingsWindowController` where no longer needed.
  4. Keep launch-at-login and other general settings controls untouched.
- **Files**:
  - `FreeThinker/UI/Settings/GeneralSettingsView.swift`
  - `FreeThinker/UI/Settings/SettingsRootView.swift`
  - `FreeThinker/UI/Settings/SettingsWindowController.swift`
  - `FreeThinker/UI/Settings/SettingsAccessibility.swift`
- **Parallel?**: No.
- **Notes**:
  - Hiding means absent from UI; do not leave disabled placeholders.

### Subtask T010 - Remove check-for-updates menu command and app wiring
- **Purpose**: Eliminate menu-level update action entry points.
- **Steps**:
  1. Remove `checkForUpdates` command enum path and menu label constants.
  2. Remove menu descriptor for update action.
  3. Remove coordinator callback and command handling branch.
  4. Remove no-longer-used `AppContainer` update callback wiring paths tied to menu/settings controls.
- **Files**:
  - `FreeThinker/UI/MenuBar/MenuBarMenuBuilder.swift`
  - `FreeThinker/UI/MenuBar/MenuBarCoordinator.swift`
  - `FreeThinker/App/AppContainer.swift`
- **Parallel?**: No.
- **Notes**:
  - If the internal helper method for updates remains for future use, ensure it is not reachable from UI.

### Subtask T011 - Extend menu descriptor model for style preset quick-switch
- **Purpose**: Make style selection accessible directly from menu dropdown.
- **Steps**:
  1. Extend menu state to include currently selected style preset.
  2. Add menu descriptors for each preset with checkmark state.
  3. Keep menu grouping readable (generate/settings/toggles/style/quit).
  4. Ensure descriptor generation remains deterministic for tests.
- **Files**:
  - `FreeThinker/UI/MenuBar/MenuBarMenuBuilder.swift`
  - `FreeThinker/UI/MenuBar/MenuBarCoordinator.swift`
  - `FreeThinker/Core/Models/AppSettings.swift` (read-only integration reference)
- **Parallel?**: No.
- **Notes**:
  - Use existing `ProvocationStylePreset` enum values; no new presets in this feature.

### Subtask T012 - Handle style preset menu command dispatch and synchronization
- **Purpose**: Connect menu actions to persisted settings updates.
- **Steps**:
  1. Add command representation for style preset selection.
  2. Dispatch selected preset through `AppState.setProvocationStylePreset(_:)`.
  3. Confirm menu reload reflects updated check state immediately.
  4. Verify settings view picker reads the same updated value without manual refresh.
- **Files**:
  - `FreeThinker/UI/MenuBar/MenuBarCoordinator.swift`
  - `FreeThinker/App/AppState.swift`
  - `FreeThinker/UI/Settings/ProvocationSettingsView.swift`
- **Parallel?**: No.
- **Notes**:
  - Avoid duplicate state caches that can drift from `AppState.settings`.

### Subtask T013 - Add automated tests for menu visibility and style synchronization
- **Purpose**: Prevent regressions in menu content and state sync.
- **Steps**:
  1. Add unit tests for menu descriptor output ensuring no update-check item appears.
  2. Add tests asserting style preset descriptors reflect current selected preset.
  3. Add tests proving menu-triggered preset changes propagate to settings state.
  4. Ensure tests cover at least two different presets for synchronization confidence.
- **Files**:
  - `FreeThinkerTests/` (new `MenuBarMenuBuilderTests.swift` and/or `MenuBarCoordinatorTests.swift`)
  - `FreeThinkerUITests/SettingsUITests.swift`
- **Parallel?**: Yes (after T011/T012 contracts are stable).
- **Notes**:
  - Keep tests self-contained; mock orchestration dependencies where needed.

## Test Strategy

- Run menu/settings-focused tests:
```bash
xcodebuild test \
  -project FreeThinker.xcodeproj \
  -scheme FreeThinker \
  -destination 'platform=macOS' \
  -skipMacroValidation \
  -only-testing:FreeThinkerTests \
  -only-testing:FreeThinkerUITests/SettingsUITests
```
- Add focused test execution notes in Activity Log when implemented.

## Risks & Mitigations

- **Risk**: Callback removal leaves dead references causing compile/runtime warnings.
- **Mitigation**: Remove enum cases, labels, handler branches, and callback wiring in one coherent change.
- **Risk**: Menu-state and settings-state drift after style change.
- **Mitigation**: Use single mutation path through `AppState` and validate with automated tests.

## Review Guidance

- Verify update controls are absent in both settings and menu.
- Verify style preset quick-switch appears and checkmark state is accurate.
- Verify menu-driven style changes persist and match settings picker state.
- Verify no unrelated menu behavior regressions.

## Activity Log

- 2026-02-14T07:24:26Z - system - lane=planned - Prompt created.
- 2026-02-14T07:51:09Z – unknown – lane=doing – Automated: start implementation
