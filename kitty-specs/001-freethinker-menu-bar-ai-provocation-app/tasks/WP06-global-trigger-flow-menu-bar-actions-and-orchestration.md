---
work_package_id: WP06
title: Global Trigger Flow, Menu Bar Actions & Orchestration
lane: "done"
dependencies:
- WP03
- WP04
- WP05
base_branch: 001-freethinker-menu-bar-ai-provocation-app-WP05
base_commit: e078bb639dc8797382e564372fab9a90854b3df9
created_at: '2026-02-13T09:08:04.420497+00:00'
subtasks:
- T028
- T029
- T030
- T031
- T032
- T033
phase: Phase 3 - User Story Delivery
assignee: ''
agent: "tanner"
shell_pid: "8703"
review_status: "approved"
reviewed_by: "Tanner"
history:
- timestamp: '2026-02-13T05:57:37Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP06 - Global Trigger Flow, Menu Bar Actions & Orchestration

## Objectives & Success Criteria
- Implement global trigger (`Cmd+Shift+P`) and menu-driven trigger paths.
- Orchestrate the end-to-end flow: permission preflight -> text capture -> AI generation -> panel presentation.
- Prevent duplicate/concurrent generations from destabilizing UX.
- Provide graceful, actionable user messaging on operational failures.
- Add integration tests for orchestration behavior with mocked services.

## Implementation Command
- Depends on WP03, WP04, and WP05: `spec-kitty implement WP06 --base WP05`

## Context & Constraints
- This is the core value loop for MVP.
- Orchestration should live in a dedicated coordinator/use-case, not split across views.
- Trigger handling must be deterministic and avoid race conditions when users rapidly retrigger.
- Error handling should not expose low-level details; present clear user guidance.

## Subtasks & Detailed Guidance

### Subtask T028 - Implement global hotkey registration lifecycle
- **Purpose**: Allow users to invoke generation from any app quickly.
- **Steps**:
  1. Implement global hotkey manager registering `Cmd+Shift+P` at app startup.
  2. Add lifecycle hooks for register/unregister on app activation/termination.
  3. Detect registration conflicts/failures and expose typed errors.
  4. Implement fallback behavior on conflict: notify user via panel notification, offer to open settings to disable conflicting app or change hotkey.
  5. Route successful trigger events to orchestration coordinator.
  6. Add optional setting hook for enabling/disabling hotkey.
- **Files**:
  - `FreeThinker/Core/Services/GlobalHotkeyService.swift`
  - `FreeThinker/App/AppDelegate.swift`
  - `FreeThinker/App/AppState.swift`
- **Parallel?**: Yes.
- **Notes**:
  - Keep hotkey implementation swappable/mocked for tests.
  - Conflict resolution: graceful degradation with clear user messaging, not silent failure.

### Subtask T029 - Build end-to-end orchestration coordinator
- **Purpose**: Centralize business flow so trigger origin (menu/hotkey) does not duplicate logic.
- **Steps**:
  1. Create coordinator/use-case object that owns generation pipeline execution.
  2. Sequence steps: permission check -> capture selection -> compose request -> AI generation -> panel update.
  3. Pass structured state updates to `AppState`/panel view model.
  4. Handle recoverable errors with typed result statuses.
  5. Emit concise logs for each stage transition.
- **Files**:
  - `FreeThinker/Core/Services/ProvocationOrchestrator.swift`
  - `FreeThinker/App/AppContainer.swift`
  - `FreeThinker/App/AppState.swift`
- **Parallel?**: No.
- **Notes**:
  - Keep coordinator free of UI framework dependencies except via protocol callbacks/state abstractions.

### Subtask T030 - Implement status bar menu actions
- **Purpose**: Deliver discoverable controls beyond hotkey-only usage.
- **Steps**:
  1. Build menu entries for Generate, Settings, Launch at Login toggle, Check for Updates, and Quit.
  2. Hook Generate to same orchestration path as hotkey.
  3. Hook Settings action to settings window presenter (from WP07 scaffolding if needed).
  4. Reflect dynamic menu state (disabled while generating, checkbox for launch-at-login).
  5. Add clear separation between menu rendering and command handling logic.
- **Files**:
  - `FreeThinker/UI/MenuBar/MenuBarCoordinator.swift`
  - `FreeThinker/UI/MenuBar/MenuBarMenuBuilder.swift`
  - `FreeThinker/App/AppState.swift`
- **Parallel?**: Yes.
- **Notes**:
  - Avoid hard-coded string duplication; centralize menu labels.

### Subtask T031 - Add concurrency controls and debouncing
- **Purpose**: Prevent stacked requests and unpredictable panel state.
- **Steps**:
  1. Add single-flight guard in orchestrator so only one generation runs at a time.
  2. Add debounce interval for rapid repeated trigger events.
  3. Support cancellation of in-flight generation when explicit regenerate/close actions occur.
  4. Ensure cancellation propagates to capture/AI services.
  5. Add metrics/log counters for dropped/debounced triggers.
- **Files**:
  - `FreeThinker/Core/Services/ProvocationOrchestrator.swift`
  - `FreeThinker/Core/Services/DefaultAIService.swift`
  - `FreeThinker/Core/Services/DefaultTextCaptureService.swift`
- **Parallel?**: No.
- **Notes**:
  - Behavior should be deterministic and clearly documented for future maintainers.

### Subtask T032 - Map failures to user-visible messaging
- **Purpose**: Provide clear actionable feedback instead of silent failures.
- **Steps**:
  1. Define mapping from domain errors to user-facing message strings/actions.
  2. Display errors in panel state when relevant.
  3. Use lightweight notifications for background failures where panel is not visible.
  4. Include suggested remediation actions (grant permission, retry, open settings).
  5. Ensure messaging is concise and non-technical.
- **Files**:
  - `FreeThinker/UI/FloatingPanel/FloatingPanelViewModel.swift`
  - `FreeThinker/Core/Utilities/ErrorPresentationMapper.swift`
  - `FreeThinker/UI/MenuBar/MenuBarCoordinator.swift`
- **Parallel?**: No.
- **Notes**:
  - Do not leak raw exception messages from system APIs.

### Subtask T033 - Add integration tests for orchestration flow
- **Purpose**: Validate pipeline correctness across trigger types and failure branches.
- **Steps**:
  1. Test hotkey trigger success path end-to-end with mocked dependencies.
  2. Test menu trigger path uses same orchestrator behavior.
  3. Test permission denial and no-selection outcomes produce correct state transitions.
  4. Test single-flight/debounce behavior under rapid trigger bursts.
  5. Test cancellation propagation from UI actions.
  6. Test mid-generation cancellation: verify cleanup, no orphaned tasks, and correct state reset.
  7. Test cancellation during text capture vs AI generation phases.
- **Files**:
  - `FreeThinkerTests/ProvocationOrchestratorIntegrationTests.swift`
  - `FreeThinkerTests/GlobalHotkeyServiceTests.swift`
  - `FreeThinkerTests/CancellationIntegrationTests.swift`
- **Parallel?**: Yes.
- **Notes**:
  - Keep orchestration tests deterministic by stubbing clocks/timers where needed.
  - Cancellation tests must verify resource cleanup and state consistency.

## Test Strategy
- Run integration suite for orchestrator and trigger services.
- Manual verification: use hotkey in at least two apps with selected text and confirm consistent behavior.
- Validate that repeated hotkey presses do not spawn duplicate generations.

## Risks & Mitigations
- **Hotkey conflicts**: Expose clear fallback message and optional disable setting.
- **Race conditions**: Centralize in-flight state in orchestrator actor.
- **Fragmented trigger behavior**: Route both menu and hotkey through one pipeline function.

## Review Guidance
- Confirm trigger paths are unified and no duplicated business logic exists.
- Verify single-flight and debounce behavior with tests, not just manual assumptions.
- Check error messaging coverage for all major domain error categories.

## Activity Log
- 2026-02-13T05:57:37Z - system - lane=planned - Prompt created.
- 2026-02-13T09:08:03Z – unknown – lane=doing – Automated: start implementation
- 2026-02-13T16:53:57Z – tanner – shell_pid=8703 – lane=doing – Started review via workflow command
- 2026-02-13T17:00:00Z – tanner – shell_pid=8703 – lane=done – Review passed: Global hotkey, orchestration, menu bar, concurrency, error mapping all implemented. Build succeeds, core tests pass.
