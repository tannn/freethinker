# Contract: Menu Style Switch and Updates Visibility

**Feature**: 002-provocation-copy-settings-controls  
**Scope**: Menu dropdown actions, style preset sync, hidden update controls

---

## Purpose

Define menu-level behavior for style preset quick switching and update-control suppression.

## Menu Descriptor Contract

### Included menu groups
- Generate action
- Settings and onboarding actions
- Launch-at-login toggle
- Style preset quick-switch entries (via menu)
- Quit action

### Excluded menu entries
- `Check for Updates` must not appear.

## Style Preset Quick-Switch Contract

### Action: `select_style_preset(preset)`

**Input**
- `preset: ProvocationStylePreset`

**Expected outcome**
- Persist selected preset to app settings.
- Mark selected preset as checked in menu state.
- Ensure settings UI reflects the same preset value.

## Settings Visibility Contract

### General settings page

**Rule**
- Updates section and update-check controls are hidden.

### Update system behavior

**Rule**
- No automatic or manual update-check trigger is exposed by current UI surfaces.

## Acceptance mapping

- FR-004, FR-005, FR-006, FR-012, FR-013
