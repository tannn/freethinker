---
work_package_id: WP01
title: Project Bootstrap & Architecture Guardrails
lane: "done"
dependencies: []
base_branch: main
base_commit: 081f87d5f93fc0cd91c6f206380bd7a4d17147bc
created_at: '2026-02-13T06:32:19.567451+00:00'
subtasks:
- T001
- T002
- T003
- T004
- T005
phase: Phase 1 - Setup
assignee: ''
agent: ''
shell_pid: ''
review_status: ''
reviewed_by: ''
history:
- timestamp: '2026-02-13T05:57:37Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP01 - Project Bootstrap & Architecture Guardrails

## Objectives & Success Criteria
- Build the initial FreeThinker macOS app skeleton with clean layer boundaries (`App`, `Core`, `UI`, `Resources`).
- Configure app/runtime settings required for a menu bar-only, Accessibility-capable, Apple Silicon/macOS 26+ product.
- Define the core domain and service interfaces that downstream WPs depend on.
- Add baseline shared error/logging primitives to keep later integration work consistent.
- Success means this WP can compile, launch as a menu bar app, and provide stable contracts for all subsequent packages.

## Implementation Command
- Run with no base dependency: `spec-kitty implement WP01`

## Context & Constraints
- Mission context indicates this feature targets direct distribution, not Mac App Store.
- Sandboxing must remain disabled for Accessibility API usage.
- Use Swift 5.9+ and SwiftUI with protocol-driven services and actor-safe asynchronous execution.
- The feature docs currently available in feature directory are minimal (`spec.md` is empty), so this WP should codify the architecture assumptions explicitly in code structure and comments/docs.
- Keep new files aligned with the agreed path conventions in `kitty-specs/001-freethinker-menu-bar-ai-provocation-app/tasks.md`.

## Subtasks & Detailed Guidance

### Subtask T001 - Create Xcode project structure and module folders
- **Purpose**: Establish a deterministic project layout that keeps architecture clean and avoids refactors later.
- **Steps**:
  1. Create app and test targets suitable for a macOS status bar app.
  2. Add groups/folders for `FreeThinker/App`, `FreeThinker/Core/{Models,Services,Utilities}`, `FreeThinker/UI/{MenuBar,FloatingPanel,Settings}`, and `FreeThinker/Resources`.
  3. Ensure project references match on-disk folder layout (avoid virtual-only group mismatch).
  4. Add placeholder files in each module (e.g., `README` comments or minimal Swift types) so Xcode keeps structure committed.
  5. Verify clean build succeeds after scaffolding.
- **Files**:
  - `FreeThinker.xcodeproj/project.pbxproj`
  - `FreeThinker/App/`
  - `FreeThinker/Core/`
  - `FreeThinker/UI/`
  - `FreeThinker/Resources/`
- **Parallel?**: No.
- **Notes**:
  - Favor predictable naming and avoid temporary placeholders that will become dead code.
  - Keep this layout consistent with `tasks.md` to preserve downstream automation assumptions.

### Subtask T002 - Configure build settings and app runtime metadata
- **Purpose**: Make runtime behavior match product constraints from day one.
- **Steps**:
  1. Set deployment target to macOS 26.0 and verify Apple Silicon architecture support.
  2. Configure app to run as menu bar utility (`LSUIElement` behavior) rather than Dock-first app.
  3. Ensure required entitlements/settings are compatible with Accessibility API usage (unsandboxed direct distribution).
  4. Add required usage descriptions and metadata entries for user-facing permission prompts.
  5. Validate debug and release configurations both compile with identical essential feature flags (no hidden toggles).
- **Files**:
  - `FreeThinker/Resources/Info.plist`
  - `FreeThinker.entitlements` (if used)
  - `FreeThinker.xcodeproj/project.pbxproj`
- **Parallel?**: No.
- **Notes**:
  - Avoid adding broad permissions not required for this feature set.

### Subtask T003 - Wire app entry points and dependency bootstrap
- **Purpose**: Create the thin composition root and ensure startup path is stable.
- **Steps**:
  1. Implement main app entry (`@main`) and `AppDelegate` bridging where necessary for menu bar lifecycle hooks.
  2. Create a lightweight dependency container/composition root to construct services behind protocols.
  3. Initialize status item shell and menu coordinator placeholders (real behavior added later).
  4. Ensure startup does not instantiate heavyweight services (AI model, AX clients) until needed.
  5. Add startup logging hooks to aid future debugging.
- **Files**:
  - `FreeThinker/App/FreeThinkerApp.swift`
  - `FreeThinker/App/AppDelegate.swift`
  - `FreeThinker/App/AppContainer.swift`
  - `FreeThinker/UI/MenuBar/MenuBarCoordinator.swift`
- **Parallel?**: No.
- **Notes**:
  - Keep this layer orchestration-only; business logic belongs in Core.
  - Ensure object lifetimes are explicit to avoid retain cycles in menu/panel coordinators.

### Subtask T004 - Define domain models and service protocols
- **Purpose**: Lock the contracts required by all downstream feature implementations.
- **Steps**:
  1. Define `ProvocationRequest` model with selected text payload and generation options.
  2. Define `ProvocationResponse` model with generated content, metadata, and timestamps.
  3. Define `AppSettings` model with sensible defaults (hotkey behavior, panel behavior, style options, launch-at-login).
  4. Create service protocol interfaces for AI, text capture, and settings persistence.
  5. Keep models value-type oriented and serialization-safe for UserDefaults where needed.
- **Files**:
  - `FreeThinker/Core/Models/ProvocationRequest.swift`
  - `FreeThinker/Core/Models/ProvocationResponse.swift`
  - `FreeThinker/Core/Models/AppSettings.swift`
  - `FreeThinker/Core/Services/AIService.swift`
  - `FreeThinker/Core/Services/TextCaptureService.swift`
  - `FreeThinker/Core/Services/SettingsService.swift`
- **Parallel?**: Yes, after folder scaffolding exists.
- **Notes**:
  - Keep protocol method signatures async-friendly.
  - Prefer explicit error types over generic `Error` in service contracts where practical.

### Subtask T005 - Add shared errors/logging primitives and architecture notes
- **Purpose**: Prevent fragmented error handling and clarify intended boundaries for all contributors.
- **Steps**:
  1. Create shared error enums (e.g., `FreeThinkerError`, service-specific domain errors) with user-displayable messaging hooks.
  2. Add minimal structured logging utility wrapper for consistent log categories and levels.
  3. Document architecture boundaries and dependency direction inside a concise developer note.
  4. Ensure every protocol/service has an initial comment describing thread-safety expectations.
  5. Add TODO markers only where a downstream WP explicitly owns the remaining work.
- **Files**:
  - `FreeThinker/Core/Utilities/FreeThinkerError.swift`
  - `FreeThinker/Core/Utilities/Logger.swift`
  - `FreeThinker/README_ARCHITECTURE.md` (or equivalent concise doc)
- **Parallel?**: Yes.
- **Notes**:
  - Keep comments succinct and non-redundant.
  - Avoid overengineering a full observability stack at this stage.

## Test Strategy
- Confirm project builds from command line (`xcodebuild`) and from Xcode.
- Launch app and validate menu bar-only runtime behavior.
- Validate no runtime fatal errors during startup with logging enabled.
- Add at least smoke-level unit compile checks for model/protocol modules.

## Risks & Mitigations
- **Project layout drift**: Lock folder and target naming early; avoid ad hoc directories.
- **Lifecycle regressions**: Keep startup path simple and isolate app delegate responsibilities.
- **Over-coupling at bootstrap**: Use protocol-based dependencies in the container; no concrete cross-layer imports.

## Review Guidance
- Confirm all required scaffold paths exist and match `tasks.md` path conventions.
- Verify `LSUIElement` and runtime behavior align with a status bar utility.
- Check that model/service contracts are complete enough for WP02-WP04 to implement without rework.
- Ensure no dead placeholder code was left behind.

## Activity Log
- 2026-02-13T05:57:37Z - system - lane=planned - Prompt created.
- 2026-02-13T06:32:19Z – unknown – lane=doing – Automated: start implementation
- 2026-02-13T06:53:14Z – unknown – lane=doing – Automated: start implementation
- 2026-02-13T07:03:00Z – unknown – lane=doing – Automated: start implementation
- 2026-02-13T07:03:00Z – claude-opus – shell_pid=92754 – lane=for_review – Ready for review: <summary>
- 2026-02-13T07:03:00Z – claude-opus – shell_pid=10981 – lane=doing – Started review via workflow command
- 2026-02-13T07:03:00Z – claude-opus – shell_pid=10981 – lane=done – Review passed: All subtasks implemented correctly.