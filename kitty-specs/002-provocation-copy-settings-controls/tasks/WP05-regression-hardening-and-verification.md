---
work_package_id: "WP05"
subtasks:
  - "T019"
  - "T020"
  - "T021"
  - "T022"
title: "Regression Hardening and Verification"
phase: "Phase 3 - Polish & Verification"
lane: "planned"
dependencies:
  - "WP02"
  - "WP03"
  - "WP04"
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

# Work Package Prompt: WP05 - Regression Hardening and Verification

## ⚠️ IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- Check `review_status` for review feedback requirements.
- Append all activity log entries in chronological order.

---

## Review Feedback

*[This section is empty initially.]*

---

## Objectives & Success Criteria

- Deliver comprehensive automated regression coverage for all new feature behaviors.
- Confirm persistence and relaunch scenarios for style preset and hotkey updates.
- Refresh verification docs so implementation/review follow the same command matrix.
- Define a repeatable focused + full test run workflow with expected pass criteria.

## Implementation Command

- Run with dependency base: `spec-kitty implement WP05 --base WP04`

## Context & Constraints

- This package should be executed after feature behavior is implemented in WP02-WP04.
- Tests are explicitly required for this feature; no manual-only signoff.
- Use `-skipMacroValidation` for CLI invocations as environment guardrail.
- Keep documentation updates limited to this feature’s artifacts and verification steps.

## Subtasks & Detailed Guidance

### Subtask T019 - Expand UI-level regression coverage across feature flows
- **Purpose**: Ensure user-visible behavior aligns with spec acceptance criteria.
- **Steps**:
  1. Add/extend tests for click-to-copy behavior and copy-only side effect guarantees.
  2. Add/extend tests for hidden updates controls in settings/menu.
  3. Add/extend tests for style preset quick-switch synchronization.
  4. Add assertions that removed controls/commands are absent.
- **Files**:
  - `FreeThinkerUITests/FloatingPanelUITests.swift`
  - `FreeThinkerUITests/SettingsUITests.swift`
  - `FreeThinkerTests/` (menu builder/coordinator tests if introduced)
- **Parallel?**: No.
- **Notes**:
  - Keep scenario names directly traceable to FR and SC IDs.

### Subtask T020 - Add persistence and relaunch regression tests
- **Purpose**: Confirm durable behavior for accepted settings and fallback behavior for rejected ones.
- **Steps**:
  1. Add tests for persisted hotkey + style preset values across relaunch simulation.
  2. Add tests proving rejected hotkey proposals do not persist.
  3. Add tests for reset-to-default persistence semantics.
  4. Keep tests in deterministic in-memory stores and mock services.
- **Files**:
  - `FreeThinkerUITests/SettingsUITests.swift`
  - `FreeThinkerTests/DefaultSettingsServiceTests.swift`
  - `FreeThinkerTests/GlobalHotkeyServiceTests.swift`
- **Parallel?**: No.
- **Notes**:
  - Avoid relying on mutable global user defaults in tests.

### Subtask T021 - Update quickstart and validation guidance
- **Purpose**: Keep implementation/review runbook aligned with final UX.
- **Steps**:
  1. Update feature quickstart checklist for new copy interaction and hotkey customization behavior.
  2. Remove stale references to updates UI/check-for-updates action.
  3. Add concise manual verification points that complement automated tests.
- **Files**:
  - `kitty-specs/002-provocation-copy-settings-controls/quickstart.md`
  - `kitty-specs/002-provocation-copy-settings-controls/tasks.md` (only if references need alignment)
- **Parallel?**: Yes.
- **Notes**:
  - Keep documentation scoped to this feature directory.

### Subtask T022 - Define and run canonical test matrix
- **Purpose**: Standardize quality gate expectations for implementation and review.
- **Steps**:
  1. Define focused test command set for changed modules.
  2. Define full-suite command for final verification.
  3. Record expected success criteria and failure triage notes in activity/review output.
  4. Ensure commands include `-skipMacroValidation`.
- **Files**:
  - `kitty-specs/002-provocation-copy-settings-controls/quickstart.md`
  - WP05 activity log + review notes
- **Parallel?**: No.
- **Notes**:
  - If command flakiness appears, document reproduction details for reviewers.

## Test Strategy

- Focused regression command:
```bash
xcodebuild test \
  -project FreeThinker.xcodeproj \
  -scheme FreeThinker \
  -destination 'platform=macOS' \
  -skipMacroValidation \
  -only-testing:FreeThinkerUITests/FloatingPanelUITests \
  -only-testing:FreeThinkerUITests/SettingsUITests \
  -only-testing:FreeThinkerTests/GlobalHotkeyServiceTests
```

- Full suite command:
```bash
xcodebuild test \
  -project FreeThinker.xcodeproj \
  -scheme FreeThinker \
  -destination 'platform=macOS' \
  -skipMacroValidation
```

## Risks & Mitigations

- **Risk**: Partial regression coverage misses multi-surface state sync bugs.
- **Mitigation**: Include cross-surface assertions (menu action -> settings value, settings value -> menu state).
- **Risk**: Documentation drift from actual commands.
- **Mitigation**: Keep quickstart commands identical to verified CLI test matrix.

## Review Guidance

- Verify test cases map back to FR-001 through FR-013.
- Verify quickstart accurately reflects final UI (no updates controls, style switch in menu, hotkey customization present).
- Verify command matrix is reproducible on clean checkout.

## Activity Log

- 2026-02-14T07:24:26Z - system - lane=planned - Prompt created.
