# WP05 Activity Log and Review Notes

## Activity Log (Chronological)
- 2026-02-14T07:24:26Z - system - lane=planned - Prompt created.
- 2026-02-14T08:16:33Z - unknown - lane=doing - Automated: start implementation.
- 2026-02-14T09:03:24Z - codex - lane=doing - Implemented regression hardening updates: removed Updates UI/menu commands, added menu style quick-switch commands, and expanded regression coverage in UI/unit tests.
- 2026-02-14T09:04:05Z - codex - lane=doing - Focused `xcodebuild test` rerun with writable derived data path surfaced project-level test bundle Info.plist generation gap.
- 2026-02-14T09:04:28Z - codex - lane=doing - Added CLI override `GENERATE_INFOPLIST_FILE=YES`; compile then surfaced existing `FreeThinkerPerformanceTests/AIServicePerformanceTests.swift` errors.
- 2026-02-14T09:05:00Z - codex - lane=doing - Applied minimal compile fix in performance test fixture loader (`Bundle(for:)`, explicit `CharacterSet.whitespacesAndNewlines`).
- 2026-02-14T09:05:23Z - codex - lane=doing - Verified app build succeeds: `xcodebuild build ... -skipMacroValidation GENERATE_INFOPLIST_FILE=YES` (exit 0).
- 2026-02-14T09:05:47Z - codex - lane=doing - Verified test target compilation succeeds: `xcodebuild build-for-testing ... -skipMacroValidation GENERATE_INFOPLIST_FILE=YES` (exit 0).
- 2026-02-14T09:06:15Z - codex - lane=doing - `xcodebuild test-without-building` blocked by sandbox restrictions (writes to `~/Library/Developer/Xcode/DerivedData` and distributed-notification posting denied), so runtime test execution could not complete in this environment.

## Canonical Test Matrix
### Focused
```bash
xcodebuild test \
  -project FreeThinker.xcodeproj \
  -scheme FreeThinker \
  -destination 'platform=macOS' \
  -skipMacroValidation \
  -only-testing:FreeThinkerUITests/FloatingPanelUITests \
  -only-testing:FreeThinkerUITests/SettingsUITests \
  -only-testing:FreeThinkerTests/GlobalHotkeyServiceTests \
  -only-testing:FreeThinkerTests/DefaultSettingsServiceTests \
  -only-testing:FreeThinkerTests/MenuBarMenuBuilderTests
```

### Full Suite
```bash
xcodebuild test \
  -project FreeThinker.xcodeproj \
  -scheme FreeThinker \
  -destination 'platform=macOS' \
  -skipMacroValidation
```

## Expected Success Criteria
- Focused regression command exits `0`.
- Full suite command exits `0`.
- No failing assertions for copy-only side effects, removed updates controls, style quick-switch sync, or relaunch persistence semantics.

## Execution Outcome
- Compile verification completed successfully for app and all test targets via `build` and `build-for-testing`.
- Runtime test execution is currently blocked by sandbox constraints in this environment; focused/full `xcodebuild test` commands could not be completed to a passing exit code.

## Failure Triage
- Prioritize failing tests by scope: targeted suite failures first, then full-suite only regressions.
- For persistence issues, inspect `AppSettings.validated()`, `AppState` persistence queueing, and `DefaultSettingsService` encode/decode paths.
- For menu/state sync issues, inspect `MenuBarCoordinator.menuState()` and style command routing in `perform(_:)`.
