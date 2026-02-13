---
work_package_id: WP05
title: Floating Panel UI & Interaction States
lane: "done"
dependencies:
- WP03
- WP04
base_branch: 001-freethinker-menu-bar-ai-provocation-app-WP04
base_commit: 51ad4f69915b8fd41b63f84780e8b4239422a441
created_at: '2026-02-13T08:53:49.351584+00:00'
subtasks:
- T023
- T024
- T025
- T026
- T027
phase: Phase 3 - User Story Delivery
assignee: ''
agent: "OpenCode"
shell_pid: "36901"
review_status: "approved"
reviewed_by: "Tanner"
history:
- timestamp: '2026-02-13T05:57:37Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP05 - Floating Panel UI & Interaction States

## Objectives & Success Criteria
- Implement a polished floating panel surface to show loading, success, and error generation states.
- Support user actions: copy result, regenerate, close, and pin/unpin persistence behavior.
- Provide keyboard navigation and accessibility labels suitable for VoiceOver.
- Ensure panel behavior remains non-disruptive to the user’s active application context.
- Add UI test coverage for critical panel interactions.

## Implementation Command
- Depends on WP03 and WP04: `spec-kitty implement WP05 --base WP04`

## Context & Constraints
- Panel should feel lightweight and immediate, not a full-window app.
- This package consumes outputs from text capture and AI services but should keep presentation logic isolated.
- Maintain consistent style across short and long provocations.
- Accessibility support is a first-class requirement, not optional polish.

## Subtasks & Detailed Guidance

### Subtask T023 - Implement floating `NSPanel` host
- **Purpose**: Create the native windowing container that can be shown from menu/hotkey flow.
- **Steps**:
  1. Implement an `NSPanel` wrapper configured for floating, non-activating behavior where appropriate.
  2. Attach SwiftUI root view as panel content.
  3. Add panel positioning logic near active screen/focus context with safe fallback.
  4. Add show/hide APIs with idempotent behavior.
  5. Ensure lifecycle cleanup avoids leaked windows/controllers.
- **Files**:
  - `FreeThinker/UI/FloatingPanel/FloatingPanelController.swift`
  - `FreeThinker/UI/FloatingPanel/FloatingPanelWindow.swift`
- **Parallel?**: No.
- **Notes**:
  - Avoid focus stealing that interrupts current text-editing flow.

### Subtask T024 - Build panel state views and view model
- **Purpose**: Give users clear visual feedback across generation lifecycle states.
- **Steps**:
  1. Define panel state enum (`idle`, `loading`, `success`, `error`).
  2. Implement SwiftUI view model driving state transitions.
  3. Build composable views for loading indicator, response card, and error callout.
  4. Ensure long responses wrap/scroll gracefully without clipping.
  5. Add lightweight design tokens (spacing, typography, accent usage) for visual consistency.
- **Files**:
  - `FreeThinker/UI/FloatingPanel/FloatingPanelViewModel.swift`
  - `FreeThinker/UI/FloatingPanel/FloatingPanelView.swift`
  - `FreeThinker/UI/FloatingPanel/FloatingPanelComponents.swift`
- **Parallel?**: No.
- **Notes**:
  - Keep UI state model simple to avoid impossible state combinations.

### Subtask T025 - Implement panel actions (copy/regenerate/close/pin)
- **Purpose**: Enable primary user interactions required for daily utility.
- **Steps**:
  1. Add copy action writing generated text to system pasteboard with success feedback.
  2. Wire regenerate action callback to orchestration trigger.
  3. Add close action and auto-dismiss timer behavior.
  4. Add pin/unpin action and persist preference through settings layer.
  5. Ensure all actions are disabled/enabled correctly by state.
- **Files**:
  - `FreeThinker/UI/FloatingPanel/FloatingPanelViewModel.swift`
  - `FreeThinker/UI/FloatingPanel/FloatingPanelView.swift`
  - `FreeThinker/App/AppState.swift`
- **Parallel?**: No.
- **Notes**:
  - Regenerate should not duplicate concurrent requests; rely on WP06 orchestration guards.

### Subtask T026 - Add keyboard and accessibility affordances
- **Purpose**: Ensure panel is efficient for keyboard users and accessible technologies.
- **Steps**:
  1. Implement keyboard shortcuts for close (`Esc`) and primary actions.
  2. Verify tab ordering across controls and focus behavior on panel open.
  3. Add descriptive accessibility labels/hints for stateful controls.
  4. Ensure error messages are reachable by assistive tech.
  5. Validate high contrast/readability constraints with current styling.
- **Files**:
  - `FreeThinker/UI/FloatingPanel/FloatingPanelView.swift`
  - `FreeThinker/UI/FloatingPanel/FloatingPanelAccessibility.swift`
- **Parallel?**: Yes.
- **Notes**:
  - Keep accessibility strings centralized for later localization.

### Subtask T027 - Create UI tests for panel flows
- **Purpose**: Catch regressions in state transitions and user actions.
- **Steps**:
  1. Add UI test for loading → success transition after mocked generation.
  2. Add UI test for error state and retry/regenerate path.
  3. Add UI test for copy and close actions.
  4. Add UI test for pinned panel behavior across trigger cycles.
  5. Make tests resilient via stable accessibility identifiers.
- **Files**:
  - `FreeThinkerUITests/FloatingPanelUITests.swift`
  - `FreeThinker/UI/FloatingPanel/FloatingPanelView.swift` (identifiers)
- **Parallel?**: Yes.
- **Notes**:
  - Avoid timing-flaky assertions; synchronize via deterministic state markers.

## Test Strategy
- Run UI tests focused on panel state transitions.
- Manual verification of panel placement/focus behavior on multi-monitor setups.
- Confirm keyboard/VoiceOver access across all action buttons.

## Risks & Mitigations
- **Window/focus quirks**: Keep panel controller logic isolated and manually validate edge cases.
- **State complexity growth**: Use explicit enum-based state model and centralized transitions.
- **Action race conditions**: Disable conflicting actions while generation is in progress.

## Review Guidance
- Confirm panel remains lightweight and non-disruptive.
- Verify copy/regenerate/close/pin all work from both mouse and keyboard.
- Ensure accessibility IDs are stable and tests use them.

## Activity Log
- 2026-02-13T05:57:37Z - system - lane=planned - Prompt created.
- 2026-02-13T08:53:48Z – unknown – lane=doing – Automated: start implementation
- 2026-02-13T09:07:47Z – unknown – lane=done – Review passed: All 5 subtasks (T023-T027) implemented - floating panel UI, state management, actions, accessibility, and UI tests complete. Note: pre-existing build error in WP04's FoundationModelsAdapter.swift blocks full build.
