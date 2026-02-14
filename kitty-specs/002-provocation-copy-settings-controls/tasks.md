# Work Packages: Provocation Copy & Settings Controls

**Inputs**: Design documents from `kitty-specs/002-provocation-copy-settings-controls/`
**Prerequisites**: `plan.md` (required), `spec.md` (required), `research.md`, `data-model.md`, `contracts/`, `quickstart.md`

**Tests**: Included because stakeholder explicitly required automated coverage updates for this feature.

**Organization**: Fine-grained subtasks (`Txxx`) roll up into independently deliverable work packages (`WPxx`).

**Prompt Files**: Each work package references a matching prompt in `kitty-specs/002-provocation-copy-settings-controls/tasks/`.

## Subtask Format: `[Txxx] [P?] Description`
- **[P]** means the subtask is safe to parallelize when dependencies are satisfied.
- Subtasks call out concrete files/components in the existing macOS app structure.

## Path Conventions
- **App orchestration**: `FreeThinker/App/`
- **Core models/services**: `FreeThinker/Core/Models/`, `FreeThinker/Core/Services/`, `FreeThinker/Core/Utilities/`
- **UI surfaces**: `FreeThinker/UI/FloatingPanel/`, `FreeThinker/UI/MenuBar/`, `FreeThinker/UI/Settings/`
- **Automated tests**: `FreeThinkerTests/`, `FreeThinkerUITests/`

---

## Phase 1 - Foundation

## Work Package WP01: Hotkey Validation Foundation (Priority: P0)

**Goal**: Establish reusable hotkey validation/apply/reset primitives so customization can be implemented safely.
**Independent Test**: Unit tests prove valid shortcuts apply, invalid/reserved/conflicting shortcuts are rejected, and reset restores `Cmd+Shift+P`.
**Prompt**: `kitty-specs/002-provocation-copy-settings-controls/tasks/WP01-hotkey-validation-foundation.md`
**Estimated Prompt Size**: ~340 lines

### Included Subtasks
- [ ] T001 Define hotkey value and validation result models used by settings + registration flows.
- [ ] T002 Implement shortcut validation rules (invalid/reserved/conflict) against `GlobalHotkeyService` and known constraints.
- [ ] T003 Add `AppState` APIs for propose/apply/reset hotkey that preserve previous shortcut on failure and expose user feedback.
- [ ] T004 Add/expand unit tests for validation outcomes, fallback retention, and default reset behavior.

### Implementation Notes
- Keep validation logic deterministic and test-first in Core (not embedded ad hoc inside view code).
- Use existing registration error mapping paths to classify conflicts clearly.
- Ensure behavior is persistence-safe: only validated shortcuts are written.

### Parallel Opportunities
- T004 can be developed in parallel with T003 once model contracts from T001 are stable.

### Dependencies
Dependencies: None

### Risks & Mitigations
- **Risk**: Overly permissive validation can break global hotkey registration and app reachability.
- **Mitigation**: Validate before persistence and keep previous shortcut active on every rejection path.

---

## Phase 2 - User Story Delivery

## Work Package WP02: Copy-on-Click Floating Panel UX (Priority: P1) 🎯 MVP

**Goal**: Make provocation text itself the copy trigger and remove redundant copy button without changing other panel behaviors.
**Independent Test**: Clicking provocation text copies content; regenerate/close/pin behavior remains unchanged; no copy button is rendered.
**Prompt**: `kitty-specs/002-provocation-copy-settings-controls/tasks/WP02-copy-on-click-floating-panel-ux.md`
**Estimated Prompt Size**: ~300 lines

### Included Subtasks
- [ ] T005 Refactor floating panel response rendering to support explicit text-click copy affordance.
- [ ] T006 Remove footer Copy button and wire copy-only behavior through response content interaction.
- [ ] T007 Update floating panel accessibility identifiers/labels for copy target semantics and remove stale copy-button references.
- [ ] T008 Add/adjust automated tests for click-to-copy success and no-secondary-action regression coverage.

### Implementation Notes
- Preserve existing copy feedback messaging and dismiss-on-copy logic where applicable.
- Ensure click handler does not trigger regenerate, close, or navigation side effects.
- Keep keyboard shortcuts and panel focus behavior intact.

### Parallel Opportunities
- T007 can run in parallel with T005 after the interaction contract is agreed.

### Dependencies
Dependencies: WP01

### Risks & Mitigations
- **Risk**: Removing copy button can leave no discoverable copy affordance for accessibility tools.
- **Mitigation**: Add clear accessibility label/hint on click target and keep copy feedback visible.

---

## Work Package WP03: Menu/Settings Updates Visibility + Style Quick Switch (Priority: P1)

**Goal**: Hide update controls and add style preset quick-switching in the menu while keeping settings/menu state synchronized.
**Independent Test**: No update controls appear in settings/menu, style preset can be changed from menu, and settings reflects the same value.
**Prompt**: `kitty-specs/002-provocation-copy-settings-controls/tasks/WP03-menu-settings-visibility-and-style-quick-switch.md`
**Estimated Prompt Size**: ~360 lines

### Included Subtasks
- [ ] T009 Remove/hide updates section from settings UI and detach update callbacks from settings window plumbing.
- [ ] T010 Remove `Check for Updates` command, labels, and menu action wiring from menu/app coordinators.
- [ ] T011 Extend menu state/descriptor generation to include style preset quick-switch items with checked state.
- [ ] T012 Implement style preset menu command handling via `AppState` so changes persist and remain synchronized with settings.
- [ ] T013 Add automated menu/state tests validating update-item absence and style preset synchronization.

### Implementation Notes
- Do not delete update-related persisted fields; only hide/disable visible controls and actions.
- Keep menu rebuild behavior efficient to avoid flicker when settings change.
- Ensure menu-driven preset changes do not bypass existing settings persistence path.

### Parallel Opportunities
- T013 can be started in parallel after descriptor/command contracts from T010-T012 are locked.

### Dependencies
Dependencies: WP01

### Risks & Mitigations
- **Risk**: Hidden update controls may still be reachable through stale callbacks.
- **Mitigation**: Remove wiring at source (menu command enum + coordinator callback + settings button path).

---

## Work Package WP04: Hotkey Customization Settings UX (Priority: P1)

**Goal**: Deliver configurable key-combo editing with validation feedback, conflict handling, and reset to default.
**Independent Test**: Users can set valid shortcuts, receive clear rejection feedback for invalid ones, retain prior shortcut on failure, and reset to default.
**Prompt**: `kitty-specs/002-provocation-copy-settings-controls/tasks/WP04-hotkey-customization-settings-ux.md`
**Estimated Prompt Size**: ~420 lines

### Included Subtasks
- [ ] T014 Add hotkey customization UI controls in settings (capture key combo + display current shortcut).
- [ ] T015 Connect UI actions to WP01 hotkey propose/apply/reset APIs with explicit success/error feedback states.
- [ ] T016 Ensure apply flow re-registers active hotkey and persists only validated values.
- [ ] T017 Add accessibility identifiers for hotkey editing feedback/reset controls and keep existing identifiers stable.
- [ ] T018 Add automated tests for valid change, invalid/reserved/conflict rejection, previous-shortcut retention, and reset-to-default.

### Implementation Notes
- Maintain existing reachability guardrail (hotkey/menu bar icon cannot both be disabled).
- Favor a dedicated subview/component for hotkey editing to keep `GeneralSettingsView` maintainable.
- Use clear, user-facing messaging for each rejection reason.

### Parallel Opportunities
- T017 can proceed in parallel with T014 once UI layout and identifiers are agreed.

### Dependencies
Dependencies: WP01, WP03

### Risks & Mitigations
- **Risk**: Hotkey UI can drift from underlying registered shortcut.
- **Mitigation**: Treat `AppState.settings` as single source of truth and verify registration after apply/reset.

---

## Phase 3 - Polish & Verification

## Work Package WP05: Regression Hardening and Verification (Priority: P2)

**Goal**: Close feature with cross-surface regression coverage and updated verification workflow.
**Independent Test**: Focused and full automated suites pass with feature-specific assertions for copy behavior, hidden updates, hotkey customization, and style sync.
**Prompt**: `kitty-specs/002-provocation-copy-settings-controls/tasks/WP05-regression-hardening-and-verification.md`
**Estimated Prompt Size**: ~300 lines

### Included Subtasks
- [ ] T019 Expand `FloatingPanelUITests` and `SettingsUITests` with end-to-end assertions mapped to FR-001 through FR-013.
- [ ] T020 Add/adjust persistence tests to prove hotkey + style choices survive relaunch and rejected hotkeys do not persist.
- [ ] T021 Update quickstart/manual validation notes for removed update UI and new copy/hotkey/menu style flows.
- [ ] T022 Define and execute canonical test command matrix (focused + full suite) with `-skipMacroValidation` and record expected pass criteria.

### Implementation Notes
- Keep test scenarios crisp and directly traceable to functional requirements.
- Preserve determinism by using in-memory stores/mocks where system APIs are not available in test runtime.
- Keep docs aligned with current UI surface so implementation agents and reviewers run the same checks.

### Parallel Opportunities
- T021 can proceed in parallel with T019/T020 while test implementation is in progress.

### Dependencies
Dependencies: WP02, WP03, WP04

### Risks & Mitigations
- **Risk**: Regression gaps if only happy-path tests are updated.
- **Mitigation**: Include failure-path assertions for hotkey rejection and copy interaction side effects.

---

## Dependency & Execution Summary

- **Recommended sequence**: WP01 → (WP02 + WP03 in parallel) → WP04 → WP05.
- **Primary parallelization window**: WP02 and WP03 can run concurrently after WP01 completes.
- **MVP scope recommendation**: WP02 (copy-on-click flow) as first shippable increment, then WP03 and WP04 for complete user-facing scope.

---

## Subtask Index (Reference)

| Subtask ID | Summary | Work Package | Priority | Parallel? |
|------------|---------|--------------|----------|-----------|
| T001 | Define hotkey model + validation result types | WP01 | P0 | No |
| T002 | Implement hotkey validation rules and conflict classification | WP01 | P0 | No |
| T003 | Add AppState hotkey propose/apply/reset APIs | WP01 | P0 | No |
| T004 | Unit tests for hotkey validation and fallback behavior | WP01 | P0 | Yes |
| T005 | Make response content clickable for copy interaction | WP02 | P1 | No |
| T006 | Remove copy button and enforce copy-only content click | WP02 | P1 | No |
| T007 | Update floating panel accessibility constants for new copy affordance | WP02 | P1 | Yes |
| T008 | Automated tests for click-copy and no-secondary-action behavior | WP02 | P1 | No |
| T009 | Hide updates section and detach settings update callbacks | WP03 | P1 | No |
| T010 | Remove check-for-updates menu command and wiring | WP03 | P1 | No |
| T011 | Add style preset quick-switch descriptors to menu model | WP03 | P1 | No |
| T012 | Handle style preset menu actions and sync with settings | WP03 | P1 | No |
| T013 | Automated tests for menu visibility and style sync | WP03 | P1 | Yes |
| T014 | Build hotkey customization controls in settings | WP04 | P1 | No |
| T015 | Wire hotkey UI to apply/reset validation APIs and feedback | WP04 | P1 | No |
| T016 | Ensure valid apply persists and re-registers active hotkey | WP04 | P1 | No |
| T017 | Add accessibility identifiers for hotkey customization UI | WP04 | P1 | Yes |
| T018 | Automated tests for valid/invalid/reset customization paths | WP04 | P1 | No |
| T019 | Expand UI-level regression coverage for feature requirements | WP05 | P2 | No |
| T020 | Persistence/regression tests for hotkey + style synchronization | WP05 | P2 | No |
| T021 | Update quickstart and validation guidance documentation | WP05 | P2 | Yes |
| T022 | Define and run focused/full test command matrix | WP05 | P2 | No |

---

> All work package prompt files must remain flat under `kitty-specs/002-provocation-copy-settings-controls/tasks/`.
