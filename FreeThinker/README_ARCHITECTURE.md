# FreeThinker Architecture Guardrails

## Layer Boundaries
- `App/`: Composition root and application lifecycle only.
- `Core/Models`: Value types representing domain state and settings.
- `Core/Services`: Protocol contracts and domain error types.
- `Core/Utilities`: Shared cross-cutting primitives (logging, error normalization).
- `UI/`: Presentation coordinators and SwiftUI views.

## Dependency Direction
- `App` may depend on `Core` and `UI`.
- `UI` may depend on `Core` models/protocols.
- `Core` must not depend on `App` or `UI`.

## Concurrency Rules
- Service protocols are asynchronous and `Sendable`.
- Concrete services handling mutable state should use actors.
- Menu/UI orchestration remains `@MainActor`.

## Runtime Constraints
- Target platform: macOS 26+.
- Distribution: direct download, unsandboxed (Accessibility workflows).
- App shell: menu bar utility (`LSUIElement = true`).
- AI inference: on-device only via FoundationModels in downstream work packages.

## Planned Follow-ups
- `TODO(WP02)`: Implement AI generation service with `SystemLanguageModel`.
- `TODO(WP03)`: Implement Accessibility text capture service using `AXUIElement`.
- `TODO(WP04)`: Replace placeholder settings and floating panel views with production UI.
