---
work_package_id: WP02
title: Settings Persistence & App State Foundation
lane: "done"
dependencies:
- WP01
base_branch: 001-freethinker-menu-bar-ai-provocation-app-WP01
base_commit: 081f87d5f93fc0cd91c6f206380bd7a4d17147bc
created_at: '2026-02-13T07:48:44.446008+00:00'
subtasks:
- T006
- T007
- T008
- T009
- T010
phase: Phase 2 - Foundation
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

# Work Package Prompt: WP02 - Settings Persistence & App State Foundation

## Objectives & Success Criteria
- Implement durable settings storage using UserDefaults behind a testable protocol/actor implementation.
- Expose an observable app state layer consumed by SwiftUI and menu/panel coordinators.
- Support launch-at-login behavior via `SMAppService` with robust error handling.
- Provide migration/versioning and reset defaults behaviors for future-safe preferences evolution.
- Deliver unit coverage for settings core paths and launch-at-login integration boundaries.

## Implementation Command
- Depends on WP01: `spec-kitty implement WP02 --base WP01`

## Context & Constraints
- WP01 establishes contracts and app composition root; this package should fill concrete implementations without breaking those contracts.
- Settings are local-only; no backend integration is allowed.
- The system must stay responsive: all storage operations should be non-blocking and actor-safe.
- Project context requires clean architecture and protocol-driven service design for tests.

## Subtasks & Detailed Guidance

### Subtask T006 - Implement UserDefaults-backed `SettingsService` actor
- **Purpose**: Persist and retrieve user settings reliably with a single source of truth.
- **Steps**:
  1. Implement concrete `SettingsService` actor conforming to the protocol from WP01.
  2. Define centralized key constants and serialization strategy for complex setting types.
  3. Load defaults when keys are absent; ensure defaults are deterministic and documented.
  4. Add save/update methods that write atomically from actor context.
  5. Provide read methods returning strongly typed `AppSettings` values.
- **Files**:
  - `FreeThinker/Core/Services/DefaultSettingsService.swift`
  - `FreeThinker/Core/Models/AppSettings.swift`
- **Parallel?**: No.
- **Notes**:
  - Do not scatter raw string keys across files.
  - Keep conversion logic adjacent to model definitions where practical.

### Subtask T007 - Create `@Observable` app state store
- **Purpose**: Provide a coherent state layer that SwiftUI views can observe and mutate safely.
- **Steps**:
  1. Implement `AppState` (or equivalent) using `@Observable` with published settings and workflow state fields.
  2. Inject `SettingsService` via protocol to keep state object testable.
  3. Add async load/refresh methods to populate state at startup.
  4. Add mutation methods that update service and in-memory state consistently.
  5. Expose derived read-only properties for common UI logic (e.g., launchAtLoginEnabled, selectedStyle).
- **Files**:
  - `FreeThinker/App/AppState.swift`
  - `FreeThinker/App/AppContainer.swift`
  - `FreeThinker/UI/Settings/` (light binding scaffolding if needed)
- **Parallel?**: No.
- **Notes**:
  - Avoid hidden side effects in property setters; prefer explicit async action methods.
  - Ensure main-thread handoff for UI-visible mutations.

### Subtask T008 - Implement launch-at-login wrapper with `SMAppService`
- **Purpose**: Encapsulate login-item behavior and keep system API details out of UI code.
- **Steps**:
  1. Create a dedicated service wrapper handling enable/disable and current-state querying.
  2. Map platform errors to domain errors suitable for user messaging.
  3. Ensure state remains consistent if OS call fails midway.
  4. Provide idempotent toggling behavior when requested state equals current state.
  5. Wire the wrapper into `AppState` and service container.
- **Files**:
  - `FreeThinker/Core/Services/LaunchAtLoginService.swift`
  - `FreeThinker/App/AppState.swift`
  - `FreeThinker/Core/Utilities/FreeThinkerError.swift`
- **Parallel?**: Yes.
- **Notes**:
  - Keep this service isolated so it is easy to mock in tests and in unsupported environments.

### Subtask T009 - Add settings migration/versioning and reset behavior
- **Purpose**: Prevent settings schema drift from breaking users across updates.
- **Steps**:
  1. Add a settings schema version key and migration dispatcher.
  2. Implement migration hooks for known future change points (enum renames, added options).
  3. Add `resetToDefaults()` behavior with selective preservation where appropriate.
  4. Ensure migrations run once and are safe if interrupted/retried.
  5. Emit concise logs for migration actions.
- **Files**:
  - `FreeThinker/Core/Services/DefaultSettingsService.swift`
  - `FreeThinker/Core/Models/AppSettings.swift`
  - `FreeThinker/Core/Utilities/Logger.swift`
- **Parallel?**: No.
- **Notes**:
  - Keep migration logic deterministic and side-effect minimal.
  - Do not delete unknown keys unless intentionally deprecating.

### Subtask T010 - Add unit tests for settings and launch-at-login services
- **Purpose**: Lock core persistence behavior and reduce regression risk as UI workflows are added.
- **Steps**:
  1. Create tests for defaults loading, value persistence, and reload behavior.
  2. Add tests for migration path execution and idempotency.
  3. Mock launch-at-login wrapper behavior and verify state transitions/error mapping.
  4. Add tests for `AppState` synchronization between service and UI-exposed properties.
  5. Ensure tests run deterministically without relying on global system state.
- **Files**:
  - `FreeThinkerTests/SettingsServiceTests.swift`
  - `FreeThinkerTests/LaunchAtLoginServiceTests.swift`
  - `FreeThinkerTests/AppStateTests.swift`
- **Parallel?**: Yes.
- **Notes**:
  - Use isolated UserDefaults suites for tests.
  - Avoid brittle tests tied to exact log strings.

## Test Strategy
- Unit test command for settings modules.
- Validate manual flow: toggle settings, relaunch app, verify values persist.
- Validate launch-at-login toggles and error scenarios on supported macOS runtime.

## Risks & Mitigations
- **Migration bugs**: Add versioned test fixtures and idempotency tests.
- **Threading issues**: Keep state mutations actor-isolated and bridge to main actor for UI.
- **Inconsistent defaults**: Define defaults in one place and use same source for UI labels/help text.

## Review Guidance
- Confirm no UI class directly reads/writes raw `UserDefaults` keys.
- Verify `AppState` remains thin and does not absorb business logic that belongs in services.
- Ensure migration behavior is explicit and covered by tests.

## Activity Log
- 2026-02-13T05:57:37Z - system - lane=planned - Prompt created.
- 2026-02-13T07:48:43Z – unknown – lane=doing – Automated: start implementation
- 2026-02-13T08:05:35Z – unknown – lane=doing – Automated: start implementation
