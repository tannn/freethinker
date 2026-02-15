# Research: Provocation Copy & Settings Controls

**Feature**: 002-provocation-copy-settings-controls  
**Date**: 2026-02-13  
**Research Phase**: Phase 0 - UX and integration decisions

---

## Decision 1: Copy behavior should be attached to response content, not a footer action

**Decision**
- Make provocation content itself clickable to trigger copy-to-clipboard.
- Remove the dedicated footer Copy button.

**Rationale**
- Reduces interaction count for the primary copy workflow.
- Aligns with user intent: content click is copy-only and should not trigger regenerate/dismiss.
- Reuses existing `FloatingPanelViewModel.copyCurrentResult()` clipboard path and feedback messaging.

**Alternatives considered**
- Keep both text-click copy and button copy: rejected because it preserves redundant controls.
- Replace copy button with context menu only: rejected due to lower discoverability and slower path.

---

## Decision 2: Hide updates UI while preserving stored settings fields

**Decision**
- Remove/hide Updates section from `GeneralSettingsView`.
- Remove/hide `Check for Updates` menu command and item from menu bar dropdown.
- Keep update-related fields in settings model/storage unchanged for future re-enable.

**Rationale**
- Matches current product direction: updates are intentionally disabled for now.
- Minimizes churn and migration risk by not deleting model fields yet.
- Prevents users from seeing dead controls while preserving forward compatibility.

**Alternatives considered**
- Hard-delete update fields from `AppSettings`: rejected as unnecessarily destructive for a temporary disablement.
- Keep controls but disable them visually: rejected because requirement is explicit hiding.

---

## Decision 3: Hotkey customization should use validation-first save semantics

**Decision**
- Add a hotkey customization UI in settings for key + modifier combination capture.
- Validate proposed shortcut before committing settings.
- On invalid/reserved/conflicting shortcut, keep the previous saved shortcut and show a clear reason.
- Include reset action to default `Cmd+Shift+P`.

**Rationale**
- Preserves app reachability and avoids breaking the primary invocation path.
- Fits existing architecture where `AppState` orchestrates safe settings mutation and `GlobalHotkeyService` reports registration failures.
- Supports testable behaviors for validation outcomes and fallback semantics.

**Alternatives considered**
- Save then rollback on registration failure: rejected because it can cause transient inconsistent UI state.
- Accept any shortcut without reserved-key validation: rejected because it increases system/app conflicts.

---

## Decision 4: Style preset quick-switch should be added to menu state model

**Decision**
- Extend menu state descriptors to include style preset selection actions.
- Reflect current preset in menu check state.
- Route preset changes through existing `AppState.setProvocationStylePreset(_:)` path so settings and menu stay synchronized.

**Rationale**
- Enables fast switching in the same place users trigger generation.
- Avoids state duplication by keeping a single source of truth in `AppState.settings.provocationStylePreset`.
- Keeps implementation cohesive with existing `MenuBarMenuBuilder` and `MenuBarCoordinator` structure.

**Alternatives considered**
- Add style controls to panel instead of menu: rejected because requirement explicitly asks for menu dropdown switching.
- Maintain independent menu-only style state: rejected due to synchronization risk.

---

## Decision 5: Automated coverage expansion is required for this workstream

**Decision**
- Add/expand unit tests for menu descriptor generation, hotkey validation outcomes, and settings sync behavior.
- Add/expand UI tests for hidden updates controls and copy-on-click interaction.

**Rationale**
- Constitution requires feature-corresponding tests.
- This feature touches multi-surface behavior (panel, menu, settings), making regression risk non-trivial.

**Alternatives considered**
- Manual QA only: rejected by explicit stakeholder instruction.

---

## Research Outcome

- All technical clarifications needed for planning are resolved.
- Design can proceed to Phase 1 artifacts without open gate blockers.
