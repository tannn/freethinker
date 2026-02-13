---
work_package_id: WP03
title: Accessibility Authorization & Text Capture Pipeline
lane: "done"
dependencies:
- WP01
- WP02
base_branch: 001-freethinker-menu-bar-ai-provocation-app-WP02
base_commit: 081f87d5f93fc0cd91c6f206380bd7a4d17147bc
created_at: '2026-02-13T08:17:31.623377+00:00'
subtasks:
- T011
- T012
- T013
- T014
- T015
- T016
phase: Phase 2 - Foundation
assignee: ''
agent: ''
shell_pid: ''
review_status: "approved"
reviewed_by: "Tanner"
history:
- timestamp: '2026-02-13T05:57:37Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP03 - Accessibility Authorization & Text Capture Pipeline

## Objectives & Success Criteria
- Implement robust Accessibility permission flow and selected-text capture for foreground apps.
- Provide structured capture results and explicit errors so UX can offer useful remediation.
- Add fallback behavior for unsupported selection targets while minimizing user disruption.
- Integrate permission/capture preflight into trigger entry points.
- Deliver integration-level coverage around success and failure capture paths.

## Implementation Command
- Depends on WP01 and WP02: `spec-kitty implement WP03 --base WP02`

## Context & Constraints
- This app intentionally relies on Accessibility APIs and direct distribution.
- Zero network is required for the AI feature; capture work must remain local-only as well.
- Permission experience should be clear and non-spammy (avoid repeated prompts each trigger).
- Captured data can contain sensitive text; avoid long-term storage unless explicitly required.

## Subtasks & Detailed Guidance

### Subtask T011 - Implement Accessibility permission manager
- **Purpose**: Provide a single authoritative component for permission check, prompt initiation, and remediation paths.
- **Steps**:
  1. Implement methods to query whether Accessibility trust is currently granted.
  2. Implement one-shot permission request trigger behavior.
  3. Implement helper for opening relevant macOS settings pane.
  4. Add cooldown/guard logic to avoid repeated prompt spam in short intervals.
  5. Expose domain-friendly status enum for UI and orchestrator consumption.
- **Files**:
  - `FreeThinker/Core/Services/AccessibilityPermissionService.swift`
  - `FreeThinker/Core/Models/PermissionStatus.swift`
  - `FreeThinker/Core/Utilities/FreeThinkerError.swift`
- **Parallel?**: No.
- **Notes**:
  - Keep this service free of UI dependencies.
  - Ensure behavior is deterministic under denied/restricted states.

### Subtask T012 - Build AX-based selected text extraction
- **Purpose**: Capture selected text directly from focused elements where AX support exists.
- **Steps**:
  1. Locate the focused UI element from the system-wide accessibility object.
  2. Attempt to fetch selected text via supported attributes in a robust order.
  3. Handle selected range extraction when full selected text attribute is unavailable.
  4. Normalize line endings/whitespace to stable output for AI prompting.
  5. Return early with explicit typed errors when no selection or unsupported element is detected.
- **Files**:
  - `FreeThinker/Core/Services/AXTextExtractor.swift`
  - `FreeThinker/Core/Models/CaptureResult.swift`
- **Parallel?**: Yes (after T011 contracts are known).
- **Notes**:
  - Attribute variability across apps is expected; probe defensively.
  - Keep extraction code isolated from trigger/orchestration flows.

### Subtask T013 - Add clipboard-assisted fallback capture with restore
- **Purpose**: Increase capture reliability for apps/elements that fail direct AX extraction.
- **Steps**:
  1. Implement fallback strategy that temporarily captures clipboard state.
  2. Simulate copy action only when fallback mode is enabled and safe.
  3. Read copied text with timeout and sanity checks.
  4. Restore prior clipboard contents to reduce user-side side effects.
  5. Return fallback-specific metadata so UX can explain degraded path if needed.
- **Files**:
  - `FreeThinker/Core/Services/ClipboardFallbackCapture.swift`
  - `FreeThinker/Core/Services/TextCaptureService.swift`
- **Parallel?**: Yes.
- **Notes**:
  - Do not silently overwrite clipboard contents.
  - Respect user settings if fallback is configurable.

### Subtask T014 - Implement `TextCaptureService` actor with typed errors
- **Purpose**: Provide one clean API that orchestrates direct AX capture and fallback capture.
- **Steps**:
  1. Implement service actor conforming to protocol from WP01.
  2. Compose permission service + AX extractor + clipboard fallback strategy.
  3. Map underlying failures to stable domain errors.
  4. Include capture metadata (source method, timestamp, active app identifier if available).
  5. Ensure service is cancellation-aware for integration with hotkey trigger flow.
- **Files**:
  - `FreeThinker/Core/Services/DefaultTextCaptureService.swift`
  - `FreeThinker/Core/Models/CaptureResult.swift`
  - `FreeThinker/Core/Utilities/FreeThinkerError.swift`
- **Parallel?**: No.
- **Notes**:
  - Keep method signatures straightforward to reduce orchestration complexity in WP06.

### Subtask T015 - Integrate capture preflight into trigger entry points
- **Purpose**: Ensure users receive clear guidance before failing deeper in the pipeline.
- **Steps**:
  1. Add preflight call in menu-bar action path and hotkey trigger path.
  2. Block generation early when permission is missing, with actionable next steps.
  3. Provide a retry hook after permission is granted.
  4. Capture lightweight telemetry/logging for permission-denied events.
  5. Ensure behavior is identical regardless of trigger origin.
- **Files**:
  - `FreeThinker/UI/MenuBar/MenuBarCoordinator.swift`
  - `FreeThinker/App/AppState.swift`
  - `FreeThinker/Core/Services/DefaultTextCaptureService.swift`
- **Parallel?**: No.
- **Notes**:
  - Keep UX messaging concise and respectful (no intrusive modal loops).

### Subtask T016 - Add integration tests for capture flows
- **Purpose**: Validate the hard-to-mock boundary behavior of permission and capture orchestration.
- **Steps**:
  1. Add tests for permission denied and remediation path outputs.
  2. Add tests for empty selection, unsupported element, and fallback success.
  3. Add tests for direct AX success and metadata correctness.
  4. Add tests for cancellation and timeout behavior where applicable.
  5. Ensure tests isolate OS dependencies through abstraction layers/stubs.
- **Files**:
  - `FreeThinkerTests/TextCaptureServiceIntegrationTests.swift`
  - `FreeThinkerTests/AccessibilityPermissionServiceTests.swift`
- **Parallel?**: Yes.
- **Notes**:
  - Use test doubles for AX APIs where possible; reserve any true end-to-end checks for manual QA checklist in WP08.

## Test Strategy
- Execute integration tests covering permission + capture matrix.
- Manual smoke: select text in at least two macOS apps, trigger capture, verify captured output and failure messaging.
- Confirm clipboard fallback restores prior clipboard value.

## Risks & Mitigations
- **AX inconsistency across apps**: Implement prioritized attribute probing and explicit fallback path.
- **Clipboard side effects**: Guard fallback with restore logic and clear opt-out setting if needed.
- **Permission dead-ends**: Provide open-settings helper and re-check flow.

## Review Guidance
- Verify all capture failures map to stable domain errors.
- Ensure no captured content is persisted in logs by default.
- Confirm preflight checks exist in all user trigger paths, not just one code path.

## Activity Log
- 2026-02-13T05:57:37Z - system - lane=planned - Prompt created.
- 2026-02-13T08:17:31Z – unknown – lane=doing – Automated: start implementation
- 2026-02-13T08:37:57Z – unknown – lane=done – Review passed: All subtasks T011-T016 complete. Excellent protocol-based design with proper dependency injection, Actor isolation, comprehensive error handling, and thorough integration tests. Permission cooldown, AX extraction with fallback, clipboard restore, and preflight integration all implemented correctly.
