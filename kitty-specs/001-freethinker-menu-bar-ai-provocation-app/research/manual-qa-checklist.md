# Manual QA Checklist

## Preconditions
- macOS 26+ on Apple Silicon
- App launched from direct-download unsandboxed build
- Test account can grant Accessibility permissions

## Matrix
| ID | Scenario | Steps | Expected Outcome | Troubleshooting Hint |
|---|---|---|---|---|
| QA-01 | First-run onboarding appears | Clean settings, launch app | Onboarding window appears and is dismissible | If missing, delete persisted settings and relaunch |
| QA-02 | Reopen onboarding later | Menu bar > `Onboarding Guide...` | Onboarding opens again | Verify menu item visible and enabled |
| QA-03 | Accessibility checklist action | In onboarding, click `Open Settings` for Accessibility | System settings opens Accessibility page | If deep link fails, System Settings still opens |
| QA-04 | Model readiness checklist | In onboarding, click `Refresh Status` | Model status updates to available/unavailable with reason | Validate on unsupported hardware shows warning |
| QA-05 | Hotkey awareness checklist | Click `I Understand` for hotkey item | Item changes to confirmed | Confirm persisted after relaunch |
| QA-06 | Hotkey generation path | Select text, press `Cmd+Shift+P` | Loading then provocation success in panel | If no result, verify permission and selected text |
| QA-07 | Menu generate path | Menu bar > `Generate Provocation` | Same pipeline result as hotkey | Verify single-flight behavior during in-flight request |
| QA-08 | Capture failure UX | Trigger with no selected text | User receives retry guidance | Confirm no raw text is shown in diagnostics |
| QA-09 | AI failure UX | Force model unavailable/timeout | User sees mapped, actionable error message | Ensure app remains responsive and retry works |
| QA-10 | Panel actions | Generate response, use Copy/Regenerate/Close | Actions execute correctly; pin state persists across cycles | Validate dismiss-on-copy setting |
| QA-11 | Settings persistence | Toggle show icon, dismiss-on-copy, diagnostics, launch-at-login | Values persist after restart | Launch-at-login should reflect system state |
| QA-12 | Diagnostics privacy and export | Enable diagnostics, generate flows, export JSON | Export contains stage/error metadata only; sensitive keys redacted | Verify no raw selected text/prompt fields are stored |

## Pass Criteria
- All scenarios QA-01 through QA-12 pass.
- Any deviation is documented with repro steps and severity.
