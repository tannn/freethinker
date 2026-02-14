---
work_package_id: "WP02"
subtasks:
  - "T005"
  - "T006"
  - "T007"
  - "T008"
title: "Copy-on-Click Floating Panel UX"
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

# Work Package Prompt: WP02 - Copy-on-Click Floating Panel UX

## ⚠️ IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check `review_status` in frontmatter.
- **Address all feedback** before completing implementation.
- **Update lane and activity log** in chronological order.

---

## Review Feedback

*[This section is empty initially.]*

---

## Objectives & Success Criteria

- Clicking visible provocation text copies the full provocation payload to clipboard.
- Copy button is removed from floating panel footer in all states.
- Click-to-copy is copy-only and does not trigger regenerate/close/navigation side effects.
- Existing panel interactions (regenerate, pin, close, escape) remain unchanged.
- Automated tests enforce the new interaction contract.

## Implementation Command

- Run with dependency base: `spec-kitty implement WP02 --base WP01`

## Context & Constraints

- Must satisfy FR-001, FR-002, and FR-003 from spec.
- Preserve current `FloatingPanelViewModel.copyCurrentResult()` semantics for copy feedback and optional dismiss-on-copy behavior.
- Do not degrade accessibility after removing explicit copy button.
- Keep scope to floating panel surfaces and related tests; do not mix with menu/settings update visibility work.

## Subtasks & Detailed Guidance

### Subtask T005 - Make provocation text an explicit copy target
- **Purpose**: Enable direct content interaction as the primary copy affordance.
- **Steps**:
  1. Refactor response card rendering to attach click gesture/button semantics to provocation content.
  2. Ensure the click target includes headline/body/follow-up composition users see.
  3. Keep visual treatment clear but non-disruptive (no accidental "link-style" appearance unless intentionally designed).
  4. Preserve scrollability and text selection/reading behavior.
- **Files**:
  - `FreeThinker/UI/FloatingPanel/FloatingPanelComponents.swift`
  - `FreeThinker/UI/FloatingPanel/FloatingPanelView.swift`
- **Parallel?**: No.
- **Notes**:
  - If gesture conflicts with scroll behavior, prefer a contained action wrapper that preserves smooth scrolling.

### Subtask T006 - Remove copy button and enforce copy-only click behavior
- **Purpose**: Eliminate redundant control and prevent side effects.
- **Steps**:
  1. Remove footer copy button UI and related keyboard shortcut binding for that removed control.
  2. Route text-click action to view-model copy method only.
  3. Verify no click path calls regenerate/close/pin handlers.
  4. Preserve existing copy feedback label behavior in panel header.
- **Files**:
  - `FreeThinker/UI/FloatingPanel/FloatingPanelView.swift`
  - `FreeThinker/UI/FloatingPanel/FloatingPanelViewModel.swift`
- **Parallel?**: No.
- **Notes**:
  - Keep regenerate action in footer; only copy control is removed.

### Subtask T007 - Update accessibility contract for copy affordance
- **Purpose**: Ensure assistive technologies still expose a clear copy action.
- **Steps**:
  1. Replace copy-button accessibility identifier constants with content-copy target identifiers.
  2. Add/adjust labels/hints describing click-to-copy behavior.
  3. Remove stale constants/tests that reference non-existent copy button.
  4. Keep existing identifiers for regenerate, close, and pin stable.
- **Files**:
  - `FreeThinker/UI/FloatingPanel/FloatingPanelAccessibility.swift`
  - `FreeThinker/UI/FloatingPanel/FloatingPanelComponents.swift`
  - `FreeThinker/UI/FloatingPanel/FloatingPanelView.swift`
- **Parallel?**: Yes (after T005 interaction design is decided).
- **Notes**:
  - Do not churn unrelated identifiers; stability matters for tests and automation.

### Subtask T008 - Add automated regression tests for copy-on-click behavior
- **Purpose**: Lock behavior and prevent accidental reintroduction of copy button side effects.
- **Steps**:
  1. Update existing panel tests to assert copy works via content interaction path.
  2. Add assertion that copy action does not mutate regenerate state unexpectedly.
  3. Add assertion that removed copy-button identifier is no longer expected.
  4. Keep tests deterministic with injected pasteboard writer and timing stubs.
- **Files**:
  - `FreeThinkerUITests/FloatingPanelUITests.swift`
  - `FreeThinker/UI/FloatingPanel/FloatingPanelAccessibility.swift` (for constant assertions)
- **Parallel?**: No.
- **Notes**:
  - Prefer behavior assertions over snapshot-style brittle UI text checks.

## Test Strategy

- Run panel-focused test subset:
```bash
xcodebuild test \
  -project FreeThinker.xcodeproj \
  -scheme FreeThinker \
  -destination 'platform=macOS' \
  -skipMacroValidation \
  -only-testing:FreeThinkerUITests/FloatingPanelUITests
```
- Optionally run all tests touched in WP01 + WP02 before review handoff.

## Risks & Mitigations

- **Risk**: Loss of obvious copy affordance after removing button.
- **Mitigation**: Add clear accessibility hint + copy feedback text and keep click target discoverable.
- **Risk**: Gesture conflicts with panel scrolling.
- **Mitigation**: Constrain gesture target and test long-response scrolling.

## Review Guidance

- Verify copy button is absent in rendered footer.
- Verify clicking response content copies expected text and only that action.
- Verify no regressions to regenerate/close/pin controls.
- Verify accessibility identifiers remain stable except intentionally changed copy identifier.

## Activity Log

- 2026-02-14T07:24:26Z - system - lane=planned - Prompt created.
- 2026-02-14T07:51:09Z – unknown – lane=doing – Automated: start implementation
