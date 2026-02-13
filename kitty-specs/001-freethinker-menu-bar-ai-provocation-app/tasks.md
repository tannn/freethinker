# Work Packages: FreeThinker Menu Bar AI Provocation App

**Inputs**: Design intent from `/kitty-specs/001-freethinker-menu-bar-ai-provocation-app/` and `meta.json` source description
**Prerequisites**: `plan.md` (not present), `spec.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`

**Tests**: Included because project context explicitly requires service unit tests, accessibility integration tests, UI tests, and AI performance tests.

**Organization**: Fine-grained subtasks (`Txxx`) roll up into independently shippable work packages (`WPxx`).

**Prompt Files**: Each work package has a matching prompt in `/tasks/WPxx-*.md`.

## Subtask Format: `[Txxx] [P?] Description`
- **[P]** indicates work that can proceed in parallel without creating merge hazards.
- Subtasks reference intended production file paths.

## Path Conventions
- **App Entry**: `FreeThinker/App/`
- **Core Logic**: `FreeThinker/Core/Models/`, `FreeThinker/Core/Services/`, `FreeThinker/Core/Utilities/`
- **UI**: `FreeThinker/UI/MenuBar/`, `FreeThinker/UI/FloatingPanel/`, `FreeThinker/UI/Settings/`
- **Tests**: `FreeThinkerTests/`, `FreeThinkerUITests/`, `FreeThinkerPerformanceTests/`

---

## Phase 1 - Setup

## Work Package WP01: Project Bootstrap & Architecture Guardrails (Priority: P0)

**Goal**: Stand up the macOS app skeleton, enforce Clean Architecture boundaries, and establish the baseline dependency graph.
**Independent Test**: App launches as a menu bar app on macOS 26+ with status item visible and no runtime crashes from missing app wiring.
**Prompt**: `/tasks/WP01-project-bootstrap-and-architecture-guardrails.md`
**Estimated Prompt Size**: ~360 lines

### Included Subtasks
- [ ] T001 Create Xcode project structure and module folders to match `App/Core/UI/Resources` architecture.
- [ ] T002 Configure build settings for macOS 26+, Apple Silicon target, and unsandboxed Accessibility-compatible distribution.
- [ ] T003 Wire application entry points (`App`, `AppDelegate`, dependency container bootstrap) for menu bar lifecycle.
- [ ] T004 Define core domain models (`ProvocationRequest`, `ProvocationResponse`, `AppSettings`) and service protocols.
- [ ] T005 Add shared error/logging primitives and architecture documentation notes to prevent boundary drift.

### Implementation Notes
- Establish file and target layout first so every later WP lands in stable paths.
- Keep service interfaces protocol-driven to preserve testability.
- Keep app boot code thin; orchestration should remain in Core services/use-cases.

### Parallel Opportunities
- T004 and T005 can run in parallel after T001 defines the folder and target structure.

### Dependencies
Dependencies: None

### Risks & Mitigations
- **Risk**: Wrong app lifecycle setup can force Dock app behavior instead of menu bar behavior.
- **Mitigation**: Validate `LSUIElement` and status item creation during this package.

---

## Phase 2 - Foundation

## Work Package WP02: Settings Persistence & App State Foundation (Priority: P0)

**Goal**: Implement durable settings and app-wide observable state so feature workflows can consume user preferences safely.
**Independent Test**: Settings survive relaunch, default values load correctly, and launch-at-login state toggles without crashing.
**Prompt**: `/tasks/WP02-settings-persistence-and-app-state-foundation.md`
**Estimated Prompt Size**: ~340 lines

### Included Subtasks
- [ ] T006 Implement `SettingsService` as an actor backed by UserDefaults with schema-aware defaults.
- [ ] T007 Create `@Observable` app state store that syncs settings and exposes reactive values to SwiftUI views.
- [ ] T008 Implement launch-at-login wrapper via `SMAppService` with deterministic error mapping.
- [ ] T009 Add settings validation, migration/versioning hooks, and reset-to-default behavior.
- [ ] T010 Add unit tests for settings persistence, migration, and launch-at-login behavior using protocol mocks.

### Implementation Notes
- Keep settings keys centralized to prevent divergent key names.
- Prevent UI thread blocking by keeping reads/writes isolated in actor context.
- Ensure defaults cover all toggles required by downstream WPs (hotkey, panel behavior, style preferences).

### Parallel Opportunities
- T008 can proceed in parallel with T006/T007 once `AppSettings` is finalized.
- T010 can be split by service area between contributors.

### Dependencies
Dependencies: WP01

### Risks & Mitigations
- **Risk**: Unversioned settings make future migrations brittle.
- **Mitigation**: Include schema/version key and migration switch in T009.

---

## Work Package WP03: Accessibility Authorization & Text Capture Pipeline (Priority: P0)

**Goal**: Provide reliable selected-text capture from active applications with clear accessibility permission handling.
**Independent Test**: With accessibility granted, selected text from a supported app is captured and returned; without permission, user receives actionable remediation guidance.
**Prompt**: `/tasks/WP03-accessibility-authorization-and-text-capture-pipeline.md`
**Estimated Prompt Size**: ~420 lines

### Included Subtasks
- [x] T011 Implement Accessibility permission manager (check/request/open system settings).
- [x] T012 Build AXUIElement-based selected text extractor for focused UI element and selected range.
- [x] T013 Add safe fallback capture path (clipboard-assisted capture + restoration) for unsupported elements.
- [x] T014 Implement `TextCaptureService` actor with structured `CaptureResult` and error taxonomy.
- [x] T015 Integrate preflight permission checks into hotkey/menu trigger entry points.
- [x] T016 Add integration tests for permission denied, empty selection, and successful capture scenarios.

### Implementation Notes
- Permission handling must avoid repeated prompt loops.
- Keep clipboard fallback opt-in and restore previous clipboard content to reduce user disruption.
- Return explicit errors (`permissionDenied`, `noSelection`, `unsupportedElement`, `captureFailed`) for UX mapping.

### Parallel Opportunities
- T012 and T013 can proceed in parallel after permission manager contract (T011) is set.
- T016 can be prepared in parallel with T014 using mocks/stubs.

### Dependencies
Dependencies: WP01, WP02

### Risks & Mitigations
- **Risk**: AX attributes vary across apps and break extraction logic.
- **Mitigation**: Implement attribute probing fallback sequence and robust error typing in T014.

---

## Work Package WP04: On-Device AI Provocation Engine (Priority: P0)

**Goal**: Implement FoundationModels-backed provocation generation with deterministic prompt construction and resilient failure handling.
**Independent Test**: Given captured text, AI service returns a formatted provocation within latency budget and no network calls.
**Prompt**: `/tasks/WP04-on-device-ai-provocation-engine.md`
**Estimated Prompt Size**: ~440 lines

### Included Subtasks
- [x] T017 Implement FoundationModels adapter around `SystemLanguageModel.default` with availability checks.
- [x] T018 Build prompt composer for provocation style, tone, and user custom instruction blending.
- [x] T019 Implement `AIService` actor with async generation, cancellation support, and timeout handling.
- [x] T020 Normalize model output into `ProvocationResponse` (headline, body, optional follow-up prompt).
- [x] T021 Add unit tests for prompt composition and AI error mapping using service protocol mocks.
- [x] T022 Add performance tests for response time and memory usage under representative prompt sizes.

### Implementation Notes
- Keep all prompt creation local and deterministic for reproducibility.
- Build explicit error map for `modelUnavailable`, `generationTimeout`, `generationFailed`, `unsafeOutputFiltered`.
- Ensure model access is actor-isolated to avoid race conditions.

### Parallel Opportunities
- T018 and T019 can proceed in parallel once domain contracts from WP01 are locked.
- T021/T022 can run in parallel after service surface stabilizes.

### Dependencies
Dependencies: WP01, WP02

### Risks & Mitigations
- **Risk**: FoundationModels availability differences on unsupported hardware.
- **Mitigation**: Gate service initialization with clear user-facing fallback in T017.

---

## Phase 3 - User Story Delivery

## Work Package WP05: Floating Panel UI & Interaction States (Priority: P1) 🎯 MVP

**Goal**: Deliver the floating panel experience that renders provocations and supports key user actions (close, copy, regenerate, pin).
**Independent Test**: Triggering generation shows a non-blocking floating panel with loading, success, and error states that are keyboard-accessible.
**Prompt**: `/tasks/WP05-floating-panel-ui-and-interaction-states.md`
**Estimated Prompt Size**: ~390 lines

### Included Subtasks
- [x] T023 Implement floating `NSPanel` host integrated with SwiftUI content view.
- [x] T024 Build panel state view hierarchy (idle/loading/success/error) and associated view models.
- [ ] T025 Implement user actions: copy provocation, regenerate, close, and pin/unpin behavior.
- [ ] T026 Add keyboard and accessibility affordances (Escape, tab order, VoiceOver labels).
- [ ] T027 Create UI tests for core panel flows and state transitions.

### Implementation Notes
- Keep panel above other windows without stealing focus unnecessarily.
- Use concise state machine to avoid view-state drift.
- Keep panel sizing adaptive for short and long model responses.

### Parallel Opportunities
- T024 and T026 can run in parallel after base panel host from T023 is in place.
- T027 can be staged in parallel once screen identifiers/accessibility labels are stable.

### Dependencies
Dependencies: WP03, WP04

### Risks & Mitigations
- **Risk**: Panel focus behavior can interfere with active app workflows.
- **Mitigation**: Validate non-activating panel flags and keyboard routing during T023/T026.

---

## Work Package WP06: Global Trigger Flow, Menu Bar Actions & Orchestration (Priority: P1) 🎯 MVP

**Goal**: Connect hotkey/menu commands to the end-to-end pipeline (capture → generate → display) with robust concurrency and failure UX.
**Independent Test**: Pressing Cmd+Shift+P on selected text produces a provocation in the panel; repeated triggers are debounced and recover gracefully from errors.
**Prompt**: `/tasks/WP06-global-trigger-flow-menu-bar-actions-and-orchestration.md`
**Estimated Prompt Size**: ~470 lines

### Included Subtasks
- [ ] T028 Implement global hotkey registration/lifecycle for Cmd+Shift+P.
- [ ] T029 Build orchestration use-case coordinating `TextCaptureService`, `AIService`, and panel presenter.
- [ ] T030 Implement status bar menu actions (Generate, Settings, Launch at Login toggle, Check for Updates, Quit).
- [ ] T031 Add concurrency control (single-flight generation, cancellation, and trigger debouncing).
- [ ] T032 Map operational failures to user-visible messaging and non-intrusive notifications.
- [ ] T033 Add integration tests for end-to-end orchestration with mocked dependencies.

### Implementation Notes
- Centralize flow orchestration in one coordinator to avoid duplicated trigger logic.
- Ensure trigger path checks permissions before capture to reduce confusing errors.
- Keep notifications brief and actionable.

### Parallel Opportunities
- T028 and T030 can progress in parallel before orchestration merge.
- T033 can be prepared in parallel once orchestration contract is fixed.

### Dependencies
Dependencies: WP03, WP04, WP05

### Risks & Mitigations
- **Risk**: Hotkey conflicts or duplicate registration across app lifecycle events.
- **Mitigation**: Add lifecycle registration guards and teardown paths in T028/T031.

---

## Work Package WP07: Preferences UX & Personalization Controls (Priority: P1)

**Goal**: Deliver a complete settings window for behavior tuning, personalization, and accessibility guidance.
**Independent Test**: User can change provocation style/settings, relaunch app, and see preferences persist and influence generated output.
**Prompt**: `/tasks/WP07-preferences-ux-and-personalization-controls.md`
**Estimated Prompt Size**: ~360 lines

### Included Subtasks
- [ ] T034 Implement Settings window shell and navigation (General, Provocation, Accessibility Help sections).
- [ ] T035 Bind UI controls to observable state and `SettingsService` with two-way updates.
- [ ] T036 Implement provocation style presets plus custom instruction editor with validation.
- [ ] T037 Integrate launch-at-login and update-channel controls with state feedback.
- [ ] T038 Add UI tests covering settings mutation, persistence, and relaunch validation.

### Implementation Notes
- Keep settings UX responsive with optimistic updates and rollback on service failure.
- Validate custom instructions length/content before persisting.
- Ensure accessibility guidance includes system navigation steps.

### Parallel Opportunities
- T034 and T036 can proceed in parallel once settings state contract is stable.
- T038 can be prepared using screen identifiers while UI development continues.

### Dependencies
Dependencies: WP02, WP06

### Risks & Mitigations
- **Risk**: Settings UI drift from underlying defaults and enum values.
- **Mitigation**: Use shared enums/models from Core and compile-time bindings.

---

## Phase 4 - Polish

## Work Package WP08: Update Delivery, QA Hardening & Release Readiness (Priority: P2)

**Goal**: Prepare unsigned app for operational diagnostics and final validation artifacts.
**Independent Test**: Quickstart checklist passes and release build is reproducible with documented workflow.
**Prompt**: `/tasks/WP08-update-delivery-qa-hardening-and-release-readiness.md`
**Estimated Prompt Size**: ~410 lines

### Included Subtasks
- [ ] T040 Implement first-run onboarding/checklist for accessibility and model readiness.
- [ ] T041 Add local diagnostics logging/export flow with privacy-safe redaction.
- [ ] T042 Author quickstart and manual QA checklist for critical feature scenarios.
- [ ] T043 Add release scripts/docs for unsigned app direct distribution packaging.
- [ ] T044 Run final regression/performance pass and document release sign-off gates.

### Implementation Notes
- Keep updater integration optional at runtime when feed URL is unavailable in dev.
- Diagnostics must avoid storing user selected text unless explicitly consented.
- Final QA checklist should map 1:1 to acceptance criteria from this tasks file.

### Parallel Opportunities
- T042 and T043 can run in parallel with T040/T041 implementation.
- T044 can proceed after all MVP WPs reach implementation-complete.

### Dependencies
Dependencies: WP06, WP07

### Risks & Mitigations
- **Risk**: Missing onboarding may lead to user confusion about permissions.
- **Mitigation**: Ensure T040 onboarding clearly guides users through accessibility and AI model requirements.

---

## Dependency & Execution Summary

- **Recommended sequence**: WP01 → WP02 → (WP03 + WP04 in parallel) → WP05 → WP06 → WP07 → WP08.
- **High-value parallelization window**: WP03 and WP04 can run concurrently once WP01/WP02 complete.
- **MVP scope recommendation**: WP01 through WP06 deliver the core value loop (capture, provoke, display).

---

## Subtask Index (Reference)

| Subtask ID | Summary | Work Package | Priority | Parallel? |
|------------|---------|--------------|----------|-----------|
| T001 | Create Xcode project/module structure | WP01 | P0 | No |
| T002 | Configure build settings and entitlements | WP01 | P0 | No |
| T003 | Wire app entry and dependency bootstrap | WP01 | P0 | No |
| T004 | Define core models and service protocols | WP01 | P0 | Yes |
| T005 | Add shared logging/error primitives | WP01 | P0 | Yes |
| T006 | Implement UserDefaults settings actor | WP02 | P0 | No |
| T007 | Create observable app state | WP02 | P0 | No |
| T008 | Implement launch-at-login wrapper | WP02 | P0 | Yes |
| T009 | Add settings migration/reset behavior | WP02 | P0 | No |
| T010 | Unit tests for settings services | WP02 | P0 | Yes |
| T011 | Accessibility permission manager | WP03 | P0 | No |
| T012 | AX selected text extraction | WP03 | P0 | Yes |
| T013 | Clipboard-assisted fallback capture | WP03 | P0 | Yes |
| T014 | TextCaptureService actor and errors | WP03 | P0 | No |
| T015 | Trigger preflight permission gating | WP03 | P0 | No |
| T016 | Integration tests for capture flows | WP03 | P0 | Yes |
| T017 | FoundationModels adapter | WP04 | P0 | No |
| T018 | Prompt composer for provocation styles | WP04 | P0 | Yes |
| T019 | AIService actor with timeout/cancel | WP04 | P0 | No |
| T020 | Normalize AI response payload | WP04 | P0 | No |
| T021 | Unit tests for AI prompt/error mapping | WP04 | P0 | Yes |
| T022 | AI performance tests | WP04 | P0 | Yes |
| T023 | Implement floating NSPanel host | WP05 | P1 | No |
| T024 | Build panel state views/viewmodel | WP05 | P1 | No |
| T025 | Implement panel user actions | WP05 | P1 | No |
| T026 | Keyboard/VoiceOver affordances | WP05 | P1 | Yes |
| T027 | UI tests for panel flows | WP05 | P1 | Yes |
| T028 | Register Cmd+Shift+P global hotkey | WP06 | P1 | Yes |
| T029 | Build capture→AI→panel orchestrator | WP06 | P1 | No |
| T030 | Implement status menu actions | WP06 | P1 | Yes |
| T031 | Concurrency control/debouncing | WP06 | P1 | No |
| T032 | Map failures to user messaging | WP06 | P1 | No |
| T033 | Integration tests for orchestration | WP06 | P1 | Yes |
| T034 | Build Settings window shell | WP07 | P1 | No |
| T035 | Bind controls to app state/service | WP07 | P1 | No |
| T036 | Style presets + custom instructions | WP07 | P1 | Yes |
| T037 | Launch-at-login + update controls | WP07 | P1 | No |
| T038 | UI tests for settings persistence | WP07 | P1 | Yes |
| T039 | REMOVED | WP08 | P2 | No |
| T040 | First-run onboarding checklist | WP08 | P2 | No |
| T041 | Add diagnostics logging/export | WP08 | P2 | Yes |
| T042 | Write quickstart + manual QA checklist | WP08 | P2 | Yes |
| T043 | Release scripts | WP08 | P2 | Yes |
| T044 | Final regression + sign-off gates | WP08 | P2 | No | `kitty-specs/001-freethinker-menu-bar-ai-provocation-app/research/release-signoff.md` |

