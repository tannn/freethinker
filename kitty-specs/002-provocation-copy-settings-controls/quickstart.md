# Quickstart - 002 Provocation Copy + Settings Controls

## Scope
This guide verifies the final UX for feature `002-provocation-copy-settings-controls`:
- Click-to-copy behavior in the floating panel.
- Menu style preset quick-switch behavior.
- Hotkey/style persistence across relaunch.
- Updates controls removed from Settings and menu bar.

## Focused Regression Command
Run this first while iterating on the feature changes.

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

## Full Verification Command
Run this before review/merge.

```bash
xcodebuild test \
  -project FreeThinker.xcodeproj \
  -scheme FreeThinker \
  -destination 'platform=macOS' \
  -skipMacroValidation
```

## Expected Pass Criteria
- All focused suites pass with zero failures.
- Full suite passes with zero failures.
- No test references or assertions for a "Check for Updates" menu action.
- Menu descriptors expose style quick-switch commands with exactly one selected preset at a time.

## Manual Verification Checklist
1. Generate a provocation, click `Copy`, and confirm text reaches the clipboard.
2. Toggle `Dismiss panel after copying` off and verify copy no longer closes the panel.
3. From the menu bar, switch style preset and confirm subsequent prompts follow the selected style.
4. Open Settings and confirm there is no Updates section/button.
5. Open menu bar dropdown and confirm there is no "Check for Updates" command.
6. Relaunch and confirm selected style preset and hotkey values remain persisted.

## Failure Triage Notes
- If focused suite fails, fix there before running full suite.
- If full suite fails after focused passes, inspect cross-module behavior first (menu/state synchronization, persistence race handling).
- If macro validation/build-system errors occur, keep `-skipMacroValidation` in all CI/local verification commands for this feature.
