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
- Executed: `2026-02-13`
- Result: `55 passed, 1 skipped, 0 failed`
- Known skip: `AIServicePerformanceTests.testLiveFoundationModelsBenchmarkWhenEnabled` (requires `FREETHINKER_ENABLE_LIVE_AI_PERF=1` on supported Apple Silicon machines)

## QA Outcome Capture
- Source checklist: `kitty-specs/001-freethinker-menu-bar-ai-provocation-app/research/manual-qa-checklist.md`
- Outcome:

| Scenario | Status | Evidence |
|---|---|---|
| QA-01 First-run onboarding appears | PASS (automated) | `FreeThinkerTests/AppStateOnboardingTests.swift` (`testFirstLaunchPresentsOnboarding`) |
| QA-02 Reopen onboarding later | PASS (automated) | `FreeThinkerTests/AppStateOnboardingTests.swift` (`testPresentOnboardingCanReopenGuide`) |
| QA-03 Accessibility checklist action | PENDING (manual) | Requires System Settings deep-link verification |
| QA-04 Model readiness checklist | PENDING (manual) | Requires runtime/model-availability checks on target machine |
| QA-05 Hotkey awareness checklist | PASS (automated) | `FreeThinkerTests/AppStateOnboardingTests.swift` (`testCompleteOnboardingPersistsCompletionAndHotkeyAwareness`) |
| QA-06 Hotkey generation path | PASS (automated) | `FreeThinkerTests/ProvocationOrchestratorIntegrationTests.swift` (`testHotkeyTriggerSuccessPathRunsFullPipeline`) |
| QA-07 Menu generate path | PASS (automated) | `FreeThinkerTests/ProvocationOrchestratorIntegrationTests.swift` (`testMenuTriggerUsesSameOrchestratorPipeline`, `testMenuCoordinatorGenerateUsesSameOrchestratorPath`) |
| QA-08 Capture failure UX | PASS (automated) | `FreeThinkerTests/ProvocationOrchestratorIntegrationTests.swift` (`testNoSelectionProducesRetryGuidance`) |
| QA-09 AI failure UX | PASS (automated) | `FreeThinkerTests/DefaultAIServiceTests.swift` (`testGenerateProvocationReturnsTimeoutAndCancelsWork`, `testGenerateProvocationMapsUnknownFailure`) |
| QA-10 Panel actions | PASS (automated) | `FreeThinkerUITests/FloatingPanelUITests.swift` |
| QA-11 Settings persistence | PARTIAL | Persisted settings covered by `FreeThinkerTests/DefaultSettingsServiceTests.swift`; launch-at-login system sync still requires manual verification |
| QA-12 Diagnostics privacy/export | PASS (automated) | `FreeThinkerTests/DiagnosticsLoggerTests.swift` |

## Known Limitations / Deferred Items
- `Check for Updates` remains direct-download/manual unless `FREETHINKER_RELEASE_URL` is configured.
- Manual validation is still required for OS-driven readiness flows (QA-03, QA-04, QA-11 system sync path).

## Sign-off Gates
- [x] Unit tests pass
- [x] Integration tests pass
- [x] UI tests pass
- [x] Performance suite passes (with live benchmark intentionally skipped)
- [ ] Manual QA checklist fully completed with human-run evidence
- [ ] Release artifacts produced with `scripts/release.sh --publish`
- [ ] Product/engineering approval recorded

## Required Artifacts
- Test run log
- Exported diagnostics sample (redaction verified)
- Release archive/checksum
- Release notes + rollback plan
