---
work_package_id: WP07
title: Preferences UX & Personalization Controls
lane: "doing"
dependencies:
- WP02
- WP06
base_branch: 001-freethinker-menu-bar-ai-provocation-app-WP06
base_commit: a334828c67d197722fd80326a62871dff47540f7
created_at: '2026-02-13T17:02:07.973606+00:00'
subtasks:
- T034
- T035
- T036
- T037
- T038
phase: Phase 3 - User Story Delivery
assignee: ''
agent: ''
shell_pid: ''
review_status: ''
reviewed_by: ''
history:
- timestamp: '2026-02-13T05:57:37Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP07 - Preferences UX & Personalization Controls

## Objectives & Success Criteria
- Build complete settings window UX for general behavior, provocation style controls, and accessibility guidance.
- Bind preference controls to persisted app settings with immediate and durable effect.
- Support user customization of provocation style and custom instruction text.
- Expose launch-at-login and updater-related controls through clear toggles.
- Add UI tests validating persistence and relaunch behavior.

## Implementation Command
- Depends on WP02 and WP06: `spec-kitty implement WP07 --base WP06`

## Context & Constraints
- Settings must remain local-only and stored in UserDefaults via service layer.
- UI should not bypass `AppState`/services when mutating settings.
- Accessibility guidance is important because permission friction is central to app usability.
- Keep settings content compact and understandable in a menu bar utility context.

## Subtasks & Detailed Guidance

### Subtask T034 - Implement Settings window shell and navigation
- **Purpose**: Provide the structural container for all configurable options.
- **Steps**:
  1. Implement settings window presenter/coordinator with single-instance behavior.
  2. Create sectioned navigation (General, Provocation, Accessibility Help).
  3. Ensure window opening works from menu command and app startup recovery paths.
  4. Add basic empty-state/placeholder content for all sections before full binding.
  5. Ensure settings window lifecycle does not conflict with floating panel lifecycle.
- **Files**:
  - `FreeThinker/UI/Settings/SettingsWindowController.swift`
  - `FreeThinker/UI/Settings/SettingsRootView.swift`
  - `FreeThinker/UI/MenuBar/MenuBarCoordinator.swift`
- **Parallel?**: No.
- **Notes**:
  - Keep navigation structure stable for UI tests.

### Subtask T035 - Bind controls to app state and settings service
- **Purpose**: Make settings interactive and persistent.
- **Steps**:
  1. Add form controls for core preferences (auto-dismiss, pin behavior, fallback capture enablement, etc.).
  2. Wire each control through `AppState` async mutation methods.
  3. Reflect save errors with inline non-blocking feedback.
  4. Ensure values reload accurately when opening settings after relaunch.
  5. Add guardrails to prevent invalid combinations.
- **Files**:
  - `FreeThinker/UI/Settings/GeneralSettingsView.swift`
  - `FreeThinker/App/AppState.swift`
  - `FreeThinker/Core/Services/DefaultSettingsService.swift`
- **Parallel?**: No.
- **Notes**:
  - Avoid direct UserDefaults references in SwiftUI views.

### Subtask T036 - Implement style presets and custom instruction editor
- **Purpose**: Let users tune provocation personality while keeping AI outputs stable.
- **Steps**:
  1. Implement preset picker bound to style enum from shared models.
  2. Implement multiline custom instruction editor with character limit and validation.
  3. Add reset-to-default action for style/custom instruction fields.
  4. Surface validation hints for overlong or malformed custom instruction input.
  5. Verify updated settings feed into prompt composition paths.
- **Files**:
  - `FreeThinker/UI/Settings/ProvocationSettingsView.swift`
  - `FreeThinker/Core/Models/AppSettings.swift`
  - `FreeThinker/Core/Services/ProvocationPromptComposer.swift`
- **Parallel?**: Yes.
- **Notes**:
  - Keep validation user-friendly and avoid blocking normal typing flows.

### Subtask T037 - Add launch-at-login and update controls in settings
- **Purpose**: Expose operational controls in one discoverable place.
- **Steps**:
  1. Add launch-at-login toggle bound to launch service state.
  2. Add updater channel/check options placeholders consistent with WP08 integration.
  3. Show actionable error messages if launch-at-login operation fails.
  4. Ensure toggles stay in sync with menu bar control state.
  5. Add helper text explaining implications of each operational toggle.
- **Files**:
  - `FreeThinker/UI/Settings/GeneralSettingsView.swift`
  - `FreeThinker/App/AppState.swift`
  - `FreeThinker/Core/Services/LaunchAtLoginService.swift`
- **Parallel?**: No.

### Subtask T038 - Add UI tests for settings persistence and relaunch
- **Purpose**: Protect against regressions in user personalization behavior.
- **Steps**:
  1. Add test to toggle key settings and assert immediate UI reflection.
  2. Add relaunch simulation/fixture test to verify persistence.
  3. Add test for custom instruction validation boundaries.
  4. Add test confirming settings changes affect generation style selection state.
  5. Use stable identifiers and deterministic setup for reliable CI execution.
- **Files**:
  - `FreeThinkerUITests/SettingsUITests.swift`
  - `FreeThinker/UI/Settings/` (accessibility identifiers)
- **Parallel?**: Yes.
- **Notes**:
  - Keep tests focused on behavior, not transient layout details.

## Test Strategy
- Run settings UI tests and relevant state/service unit tests.
- Manual validation: change settings, quit app, relaunch, verify persistence and behavior impact.
- Validate accessibility help content is visible and accurate for current macOS navigation.

## Risks & Mitigations
- **State desync between menu/settings/panel**: Use shared `AppState` as single source of truth.
- **Poor validation UX**: Provide inline guidance and non-blocking correction flow.
- **Fragile UI tests**: Rely on identifiers and stable navigation anchors.

## Review Guidance
- Confirm settings window behavior is predictable and single-instance.
- Verify all controls persist through service layer and survive relaunch.
- Ensure personalization settings are consumed by AI prompt builder path.

## Activity Log
- 2026-02-13T05:57:37Z - system - lane=planned - Prompt created.
- 2026-02-13T17:02:07Z – unknown – lane=doing – Automated: start implementation
- 2026-02-13T17:41:11Z – unknown – lane=doing – Automated: start implementation
