# Copilot instructions for FreeThinker

## Project context
- FreeThinker is a macOS menu bar app built with Swift 5.9+, SwiftUI, and AppKit.
- The app is local-first and uses Apple FoundationModels (`SystemLanguageModel`) for on-device AI.
- Keep architecture boundaries intact (`FreeThinker/App`, `FreeThinker/Core`, `FreeThinker/UI`).

## Coding expectations
- Make the smallest safe change needed for the request.
- Prefer existing services/protocols and current patterns over introducing new abstractions.
- Keep code testable and consistent with async/await and actor/thread-safety patterns already used in the repository.

## Validation
- Run existing tests with `swift test` for SwiftPM-based validation when possible.
- If building with `xcodebuild`, you may need `-skipMacroValidation`.

## Platform constraints
- Target is macOS 26+ on Apple Silicon.
- Do not introduce network-based AI dependencies; AI behavior must remain on-device.
