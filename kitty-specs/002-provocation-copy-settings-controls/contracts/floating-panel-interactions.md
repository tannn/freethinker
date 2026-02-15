# Contract: Floating Panel Interactions

**Feature**: 002-provocation-copy-settings-controls  
**Scope**: Copy-on-click behavior and panel action integrity

---

## Purpose

Define interaction rules for provocation content clicks in the floating panel.

## Interaction Contract

### Action: `provocation_text_clicked`

**Input**
- `responseID: UUID`
- `renderedText: String`

**Preconditions**
- Panel is in a success state with copyable content.

**Expected outcome**
- Clipboard is updated with `renderedText`.
- Copy feedback state is updated for user confirmation.
- No implicit call is made to regenerate or dismiss actions.

**Failure behavior**
- If clipboard write fails, show non-blocking error feedback.
- Panel remains visible and state remains unchanged.

## Removed Control Contract

### Deprecated action: `copy_button_pressed`

**Rule**
- No copy button descriptor or UI control should exist in panel footer for this feature.

## Acceptance mapping

- FR-001, FR-002, FR-003
