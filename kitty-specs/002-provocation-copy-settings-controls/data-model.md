# Data Model: Provocation Copy & Settings Controls

**Feature**: 002-provocation-copy-settings-controls  
**Date**: 2026-02-13  
**Phase**: Phase 1 - Design

---

## 1. Overview

This feature extends existing FreeThinker state and menu descriptors with interaction-focused models for:
- copy-on-click behavior in the floating panel,
- safe hotkey customization with validation,
- style preset quick-switch in menu,
- hidden (non-exposed) update controls.

Existing persistent source-of-truth remains `AppSettings` (UserDefaults-backed).

---

## 2. Entities

## 2.1 AppSettings (existing, extended usage)

**Purpose**: Persist user-configurable behavior across launches.

**Relevant fields**
- `hotkeyEnabled: Bool`
- `hotkeyModifiers: Int`
- `hotkeyKeyCode: Int`
- `provocationStylePreset: ProvocationStylePreset`
- `automaticallyCheckForUpdates: Bool` (retained, hidden in UI)
- `appUpdateChannel: AppUpdateChannel` (retained, hidden in UI)

**Validation rules**
- `hotkeyKeyCode` must be within supported key-code range.
- Invalid hotkey proposals are not persisted.
- Default reset value is `Cmd+Shift+P`.

---

## 2.2 HotkeyShortcut (new value object)

**Purpose**: Canonical representation of a proposed or saved key combination.

**Fields**
- `modifiersRawValue: Int`
- `keyCode: Int`
- `displayText: String`

**Validation rules**
- Must include at least one non-empty modifier.
- Must not be in reserved/prohibited combination list.
- Must be registrable by global hotkey service without conflict.

---

## 2.3 HotkeyValidationResult (new transient model)

**Purpose**: Communicate save outcome for shortcut changes.

**Fields**
- `status: HotkeyValidationStatus` (`valid`, `invalid`, `reserved`, `conflict`)
- `message: String?`
- `proposedShortcut: HotkeyShortcut`
- `effectiveShortcut: HotkeyShortcut` (remains previous value when rejected)

**Usage**
- Drives UI feedback in settings and determines whether persistence should occur.

---

## 2.4 MenuBarMenuState (existing, extended)

**Purpose**: Menu rendering input for status item dropdown.

**Existing fields**
- `isGenerating: Bool`
- `launchAtLoginEnabled: Bool`

**New fields (planned)**
- `selectedStylePreset: ProvocationStylePreset`

**Derived behavior**
- Menu descriptors include style preset options with checked state for current selection.
- Update-check menu entry is omitted.

---

## 2.5 MenuBarMenuItemDescriptor (existing, extended usage)

**Purpose**: Declarative menu item model.

**Relevant fields**
- `title: String`
- `command: MenuBarCommand?`
- `isEnabled: Bool`
- `isSeparator: Bool`
- `isOn: Bool`

**Behavioral constraints**
- No descriptor for `Check for Updates` in this feature.
- Style preset descriptors must map one-to-one with available preset values.

---

## 2.6 ProvocationInteractionState (new transient model)

**Purpose**: Track copy interaction feedback without changing response lifecycle.

**Fields**
- `canCopy: Bool`
- `copyFeedbackMessage: String?`
- `copyFeedbackTimestamp: Date?`

**State constraints**
- Clicking content triggers copy path only.
- Copy feedback can be shown transiently; panel state remains `success` unless separately changed by other controls.

---

## 3. Relationships

- `AppSettings.hotkeyModifiers/hotkeyKeyCode` <-> `HotkeyShortcut`
- `HotkeyShortcut` -> `HotkeyValidationResult`
- `AppSettings.provocationStylePreset` -> `MenuBarMenuState.selectedStylePreset`
- `MenuBarMenuState` -> `[MenuBarMenuItemDescriptor]`
- Floating panel response display -> `ProvocationInteractionState`

---

## 4. State Transitions

## 4.1 Hotkey Update Flow

1. User proposes a shortcut in settings.
2. Proposed value maps to `HotkeyShortcut`.
3. Validation produces `HotkeyValidationResult`.
4. If `valid`: persist to `AppSettings` and refresh registration.
5. If `invalid/reserved/conflict`: do not persist; keep previous effective shortcut and present message.

## 4.2 Style Preset Menu Switch Flow

1. User selects style preset from menu.
2. App updates `AppSettings.provocationStylePreset` via app state mutation.
3. Menu state reload marks selected preset as checked.
4. Settings view reflects the same selected preset on next presentation/update cycle.

## 4.3 Copy-on-Click Flow

1. User clicks provocation text content.
2. App copies displayed content to clipboard.
3. `ProvocationInteractionState.copyFeedbackMessage` updates for user confirmation.
4. No regenerate/dismiss/navigation state transitions occur from this click.

---

## 5. Backward Compatibility

- Existing persisted update fields remain in schema and storage.
- No destructive migration required.
- Existing default hotkey (`Cmd+Shift+P`) remains baseline reset target.
