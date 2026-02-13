# Release Sign-off (WP08)

## Candidate
- Feature: `001-freethinker-menu-bar-ai-provocation-app`
- Work package: `WP08`
- Date: `2026-02-13`

## Automated Regression + Performance
- Command:
  ```bash
  swift test
  ```
- Result: `46 passed, 1 skipped, 0 failed`
- Known skip: `AIServicePerformanceTests.testLiveFoundationModelsBenchmarkWhenEnabled` (requires `FREETHINKER_ENABLE_LIVE_AI_PERF=1` on supported Apple Silicon machines)

## QA Outcome Capture
- Source checklist: `kitty-specs/001-freethinker-menu-bar-ai-provocation-app/research/manual-qa-checklist.md`
- Outcome:

| Scenario | Status | Evidence |
|---|---|---|
| QA-01 First-run onboarding appears | COVERED (automated test present, execution pending) | `FreeThinkerTests/AppStateOnboardingTests.swift` (`testFirstLaunchPresentsOnboarding`) |
| QA-02 Reopen onboarding later | COVERED (automated test present, execution pending) | `FreeThinkerTests/AppStateOnboardingTests.swift` (`testPresentOnboardingCanReopenGuide`) |
| QA-03 Accessibility checklist action | PENDING (manual) | Requires System Settings deep-link verification |
| QA-04 Model readiness checklist | PENDING (manual) | Requires runtime/model-availability checks on target machine |
| QA-05 Hotkey awareness checklist | COVERED (automated test present, execution pending) | `FreeThinkerTests/AppStateOnboardingTests.swift` (`testCompleteOnboardingPersistsCompletionAndHotkeyAwareness`) |
| QA-06 Hotkey generation path | COVERED (automated test present, execution pending) | `FreeThinkerTests/ProvocationOrchestratorIntegrationTests.swift` (`testHotkeyTriggerSuccessPathRunsFullPipeline`) |
| QA-07 Menu generate path | COVERED (automated test present, execution pending) | `FreeThinkerTests/ProvocationOrchestratorIntegrationTests.swift` (`testMenuTriggerUsesSameOrchestratorPipeline`, `testMenuCoordinatorGenerateUsesSameOrchestratorPath`) |
| QA-08 Capture failure UX | COVERED (automated test present, execution pending) | `FreeThinkerTests/ProvocationOrchestratorIntegrationTests.swift` (`testNoSelectionProducesRetryGuidance`) |
| QA-09 AI failure UX | COVERED (automated test present, execution pending) | `FreeThinkerTests/DefaultAIServiceTests.swift` (`testGenerateProvocationReturnsTimeoutAndCancelsWork`, `testGenerateProvocationMapsUnknownFailure`) |
| QA-10 Panel actions | COVERED (automated test present, execution pending) | `FreeThinkerUITests/FloatingPanelUITests.swift` |
| QA-11 Settings persistence | PARTIAL | Persisted settings covered by `FreeThinkerTests/DefaultSettingsServiceTests.swift`; launch-at-login system sync still requires manual verification |
| QA-12 Diagnostics privacy/export | COVERED (automated test present, execution pending) | `FreeThinkerTests/DiagnosticsLoggerTests.swift` |

## Known Limitations / Deferred Items
- `Check for Updates` remains direct-download/manual unless `FREETHINKER_RELEASE_URL` is configured.
- Manual validation is still required for OS-driven readiness flows (QA-03, QA-04, QA-11 system sync path).

## Sign-off Gates
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] UI tests pass
- [ ] Performance suite passes (with live benchmark intentionally skipped)
- [ ] Manual QA checklist fully completed with human-run evidence
- [ ] Release artifacts produced with `scripts/release.sh --publish`
- [ ] Product/engineering approval recorded

## Required Artifacts
- Test run log
- Exported diagnostics sample (redaction verified)
- Release archive/checksum
- Release notes + rollback plan
