# Contract: Hotkey Customization

**Feature**: 002-provocation-copy-settings-controls  
**Scope**: Shortcut capture, validation, persistence, and reset behavior

---

## Purpose

Define the behavior for editing the global hotkey in settings with safe validation and fallback semantics.

## Domain Types

- `HotkeyShortcut { modifiersRawValue: Int, keyCode: Int }`
- `HotkeyValidationStatus = valid | invalid | reserved | conflict`
- `HotkeyValidationResult { status, message, effectiveShortcut }`

## Contracted Operations

### Operation: `propose_hotkey(shortcut)`

**Input**
- Proposed `HotkeyShortcut`

**Validation rules**
- Reject empty or unsupported combinations.
- Reject reserved combinations.
- Reject combinations that fail registration or conflict with existing bindings.

**Output**
- `HotkeyValidationResult`

**State effect**
- `valid`: persist shortcut and apply registration.
- `invalid|reserved|conflict`: do not persist; keep prior active shortcut.

### Operation: `reset_hotkey_to_default()`

**Expected outcome**
- Persist and apply default shortcut `Cmd+Shift+P`.

## User Feedback Contract

- Any rejected proposal must surface a clear reason message.
- Rejections must not leave settings in a partial state.

## Acceptance mapping

- FR-007, FR-008, FR-009, FR-010, FR-011
