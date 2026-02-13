---
work_package_id: "WP08"
subtasks:
  - "T039"
  - "T040"
  - "T041"
  - "T042"
  - "T043"
  - "T044"
title: "Update Delivery, QA Hardening & Release Readiness"
phase: "Phase 4 - Polish"
lane: "planned"
dependencies:
  - "WP06"
  - "WP07"
assignee: ""
agent: ""
shell_pid: ""
review_status: ""
reviewed_by: ""
history:
  - timestamp: "2026-02-13T05:57:37Z"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
---

# Work Package Prompt: WP08 - Update Delivery, QA Hardening & Release Readiness

## Objectives & Success Criteria
- Integrate Sparkle update flow appropriate for direct-distribution macOS app.
- Deliver first-run onboarding guidance for permission/model readiness.
- Add privacy-safe diagnostics support for local troubleshooting.
- Produce quickstart/manual QA/release docs for repeatable validation and shipment.
- Complete final regression and performance sign-off checklist for release candidate readiness.

## Implementation Command
- Depends on WP06 and WP07: `spec-kitty implement WP08 --base WP07`

## Context & Constraints
- Distribution channel is direct download; update framework must align with this route.
- Diagnostics must avoid persisting sensitive selected text by default.
- This package should not introduce new core feature scope; it hardens and prepares release.
- Testing requirements from project context include integration, UI, and performance validation.

## Subtasks & Detailed Guidance

### Subtask T039 - Integrate Sparkle updater into app lifecycle
- **Purpose**: Enable safe update checks and delivery for non-App-Store distribution.
- **Steps**:
  1. Add Sparkle dependency/framework integration to project and build settings.
  2. Initialize updater in app lifecycle with safe failure fallback.
  3. Wire menu action for manual update check.
  4. Add configuration points for feed URL/channel and signature requirements.
  5. Validate updater integration does not block app startup.
- **Files**:
  - `FreeThinker/App/AppDelegate.swift`
  - `FreeThinker/Core/Services/UpdateService.swift`
  - `FreeThinker/UI/MenuBar/MenuBarCoordinator.swift`
  - `FreeThinker/Resources/Info.plist` (if required keys)
- **Parallel?**: No.
- **Notes**:
  - Keep updater initialization optional in debug/developer environments where feed is absent.

### Subtask T040 - Implement first-run onboarding and readiness checklist
- **Purpose**: Reduce first-use confusion around permissions and model support.
- **Steps**:
  1. Detect first launch and show lightweight onboarding panel/sheet.
  2. Include checklist items for Accessibility permission, hotkey awareness, and on-device AI support.
  3. Add links/actions to open relevant system settings.
  4. Store completion status in settings with option to reopen guide later.
  5. Ensure onboarding is non-blocking and dismissible.
- **Files**:
  - `FreeThinker/UI/Settings/OnboardingView.swift`
  - `FreeThinker/App/AppState.swift`
  - `FreeThinker/Core/Services/DefaultSettingsService.swift`
- **Parallel?**: No.
- **Notes**:
  - Keep copy concise and actionable; avoid long-form tutorials.

### Subtask T041 - Add privacy-safe diagnostics logging/export
- **Purpose**: Support troubleshooting without violating user trust.
- **Steps**:
  1. Define structured diagnostic event model (timestamps, stage, error category, no raw selected text).
  2. Implement local rolling log storage with size bounds.
  3. Add export action to write logs to user-chosen location.
  4. Add setting toggle to enable/disable diagnostics.
  5. Redact any potentially sensitive values before persistence/export.
- **Files**:
  - `FreeThinker/Core/Utilities/DiagnosticsLogger.swift`
  - `FreeThinker/Core/Models/DiagnosticEvent.swift`
  - `FreeThinker/UI/Settings/GeneralSettingsView.swift`
- **Parallel?**: Yes.
- **Notes**:
  - Keep diagnostics implementation lightweight and local.

### Subtask T042 - Author quickstart and manual QA checklist
- **Purpose**: Provide a concrete execution guide for validation and new contributors.
- **Steps**:
  1. Write quickstart steps for build, run, permissions setup, and first generation.
  2. Add manual QA matrix covering hotkey, menu action, capture failures, AI failures, panel actions, settings persistence.
  3. Include expected outcomes and troubleshooting hints per scenario.
  4. Link required system constraints (macOS 26+, Apple Silicon, unsandboxed direct distribution).
  5. Keep checklist tightly aligned to `tasks.md` independent test criteria.
- **Files**:
  - `kitty-specs/001-freethinker-menu-bar-ai-provocation-app/quickstart.md`
  - `kitty-specs/001-freethinker-menu-bar-ai-provocation-app/research/manual-qa-checklist.md`
  - `README.md`
- **Parallel?**: Yes.
- **Notes**:
  - Prefer concise task-oriented documentation over narrative prose.

### Subtask T043 - Add release scripts/docs
- **Purpose**: Make unsigned release process reproducible and less error-prone.
- **Steps**:
  1. Add release script skeleton for archive/staple/package operations.
  2. Externalize secrets and credentials to environment variables.
  3. Document required tooling
  4. Add preflight checks to script (required env vars, certificate presence, appcast prerequisites).
  5. Add failure guidance and rollback notes.
- **Files**:
  - `scripts/release.sh`
  - `docs/release.md`
  - `.env.example` (if needed for local guidance)
- **Parallel?**: Yes.
- **Notes**:
  - Keep script non-destructive by default; require explicit publish flag for distribution actions.

### Subtask T044 - Run final regression/performance pass and define sign-off gates
- **Purpose**: Declare clear release readiness criteria with objective pass/fail checks.
- **Steps**:
  1. Run unit, integration, UI, and performance test suites.
  2. Execute manual QA checklist from T042 and capture outcomes.
  3. Record known limitations and deferred items explicitly.
  4. Define release sign-off checklist with required approvals/artifacts.
  5. Store summary in feature docs for traceability.
- **Files**:
  - `kitty-specs/001-freethinker-menu-bar-ai-provocation-app/research/release-signoff.md`
  - `kitty-specs/001-freethinker-menu-bar-ai-provocation-app/tasks.md` (checkbox updates as work completes)
- **Parallel?**: No.
- **Notes**:
  - This task is completion-gated and should run after preceding WP outputs are ready.

## Test Strategy
- Ensure all automated test suites are runnable and documented.
- Verify updater menu action and safe behavior when update feed is unavailable.
- Validate onboarding and diagnostics behavior with clean install and upgraded install scenarios.

## Risks & Mitigations
- **Update path instability**: Keep updater initialization isolated and fail-safe.
- **Sensitive data leakage in diagnostics**: Enforce redaction and default-off persistence for content fields.
- **Release process drift**: Script and document one canonical release flow.

## Review Guidance
- Confirm Sparkle integration does not regress core trigger workflow.
- Verify docs are actionable and not placeholders.
- Check release and QA artifacts are complete enough for another engineer to execute without guesswork.

## Activity Log
- 2026-02-13T05:57:37Z - system - lane=planned - Prompt created.

