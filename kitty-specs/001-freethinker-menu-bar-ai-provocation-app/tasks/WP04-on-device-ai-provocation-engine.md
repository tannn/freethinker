---
work_package_id: "WP04"
subtasks:
  - "T017"
  - "T018"
  - "T019"
  - "T020"
  - "T021"
  - "T022"
title: "On-Device AI Provocation Engine"
phase: "Phase 2 - Foundation"
lane: "planned"
dependencies:
  - "WP01"
  - "WP02"
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

# Work Package Prompt: WP04 - On-Device AI Provocation Engine

## Objectives & Success Criteria
- Implement a production-ready `AIService` powered by Apple FoundationModels (`SystemLanguageModel.default`).
- Generate concise provocations from captured text without any network requests.
- Support configurable style/tone instructions from settings.
- Provide robust timeout/cancellation/error handling to keep UI responsive.
- Deliver unit and performance tests for prompt quality contract and latency reliability.

## Implementation Command
- Depends on WP01 and WP02: `spec-kitty implement WP04 --base WP02`

## Context & Constraints
- This feature requires macOS 26+ and Apple Silicon; unsupported environments should fail gracefully.
- AI runs fully on-device; no remote fallback model is permitted.
- Service must be actor-safe and expose async APIs that integrate with global trigger flow.
- Prompt quality should bias toward thought-provoking, concise output suitable for panel display.

## Subtasks & Detailed Guidance

### Subtask T017 - Implement FoundationModels adapter
- **Purpose**: Encapsulate platform model APIs and isolate framework-specific details.
- **Steps**:
  1. Create adapter around `SystemLanguageModel.default` with lazy initialization.
  2. Add availability checks for OS version and hardware support.
  3. Expose a minimal generate interface that accepts prompt text and generation options.
  4. Map framework-level failures to domain-level errors.
  5. Log model availability diagnostics without leaking user content.
- **Files**:
  - `FreeThinker/Core/Services/FoundationModelsAdapter.swift`
  - `FreeThinker/Core/Utilities/FreeThinkerError.swift`
- **Parallel?**: No.
- **Notes**:
  - Keep wrapper interface mockable for tests.
  - Avoid tight coupling between adapter and settings logic.

### Subtask T018 - Build prompt composer for provocation generation
- **Purpose**: Ensure prompts are consistent, controllable, and aligned with product tone.
- **Steps**:
  1. Implement prompt template builder that takes selected text + style settings.
  2. Add style presets (e.g., contrarian, Socratic, systems-thinking) and custom instruction injection.
  3. Add guardrails to cap input length and sanitize unsupported content structure.
  4. Define deterministic output formatting instructions for parser compatibility.
  5. Add helper methods to generate follow-up prompts (for regenerate action).
- **Files**:
  - `FreeThinker/Core/Services/ProvocationPromptComposer.swift`
  - `FreeThinker/Core/Models/AppSettings.swift`
- **Parallel?**: Yes.
- **Notes**:
  - Keep templates centralized to avoid duplicated prompt logic across UI/action handlers.

### Subtask T019 - Implement `AIService` actor with timeout and cancellation
- **Purpose**: Provide resilient orchestration around adapter and prompt composer.
- **Steps**:
  1. Implement concrete `AIService` actor conforming to protocol from WP01.
  2. Generate prompts through composer and invoke model adapter asynchronously.
  3. Add timeout handling to prevent hanging UI interactions.
  4. Respect cancellation propagation from caller when user re-triggers/aborts.
  5. Add retry policy for transient model initialization failures (bounded attempts only).
- **Files**:
  - `FreeThinker/Core/Services/DefaultAIService.swift`
  - `FreeThinker/Core/Services/AIService.swift`
  - `FreeThinker/Core/Utilities/Logger.swift`
- **Parallel?**: No.
- **Notes**:
  - Keep retry policy conservative to avoid confusing delays.
  - Ensure every failure mode returns typed errors.

### Subtask T020 - Normalize model output into `ProvocationResponse`
- **Purpose**: Convert raw model output into consistent UI-facing shape.
- **Steps**:
  1. Implement response parser/normalizer for expected format (headline + provocative body + optional follow-up).
  2. Trim malformed/empty outputs and map to `generationFailed` when unusable.
  3. Stamp response metadata (timestamps, style used, generation duration where available).
  4. Guarantee panel-safe text lengths and line-break formatting.
  5. Add parser utilities that are independently unit testable.
- **Files**:
  - `FreeThinker/Core/Services/ProvocationResponseParser.swift`
  - `FreeThinker/Core/Models/ProvocationResponse.swift`
- **Parallel?**: No.
- **Notes**:
  - Be tolerant of minor model format drift while preserving strict minimum output validity.

### Subtask T021 - Add unit tests for prompt and error mapping
- **Purpose**: Protect prompt contracts and failure semantics from regressions.
- **Steps**:
  1. Test prompt composer output across preset styles and custom instructions.
  2. Test length capping and sanitization behavior.
  3. Mock adapter failures and verify `AIService` error mapping.
  4. Test parser handling for good, partial, and malformed model output.
  5. Validate cancellation/timeout branches in service logic.
- **Files**:
  - `FreeThinkerTests/ProvocationPromptComposerTests.swift`
  - `FreeThinkerTests/DefaultAIServiceTests.swift`
  - `FreeThinkerTests/ProvocationResponseParserTests.swift`
- **Parallel?**: Yes.
- **Notes**:
  - Keep tests deterministic by avoiding live model calls.

### Subtask T022 - Add AI performance tests
- **Purpose**: Establish measurable latency/performance confidence for the interactive trigger flow.
- **Steps**:
  1. Add performance benchmark harness for representative prompt sizes.
  2. Measure generation latency distribution and memory overhead.
  3. Set initial acceptance thresholds for MVP responsiveness.
  4. Record performance notes in test comments or docs for future regression comparison.
  5. Ensure benchmarks can be skipped or marked appropriately in CI where FoundationModels runtime is unavailable.
- **Files**:
  - `FreeThinkerPerformanceTests/AIServicePerformanceTests.swift`
  - `FreeThinkerPerformanceTests/Fixtures/`
- **Parallel?**: Yes.
- **Notes**:
  - Separate synthetic benchmark fixtures from real user text.

## Test Strategy
- Run unit tests for composer/parser/service logic.
- Run performance tests on supported Apple Silicon machine.
- Manual smoke: feed sample text and verify output structure and response timing in debug logs.

## Risks & Mitigations
- **Model unavailability**: Gate adapter initialization and return actionable user-facing errors.
- **Unbounded generation latency**: Enforce timeout with cancellation and fallback messaging.
- **Prompt drift from settings UI**: Keep style enum definitions centralized in shared models.

## Review Guidance
- Confirm no network dependencies were introduced.
- Verify AI service APIs are actor-safe and cancellation-aware.
- Check parser behavior on malformed model output is defensive and user-safe.

## Activity Log
- 2026-02-13T05:57:37Z - system - lane=planned - Prompt created.

