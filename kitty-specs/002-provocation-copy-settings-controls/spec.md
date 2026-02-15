# Feature Specification: Provocation Copy & Settings Controls

**Feature ID**: 002-provocation-copy-settings-controls  
**Created**: 2026-02-13  
**Mission**: software-dev  
**Status**: Draft

---

## 1. Overview

### 1.1 Purpose
Improve day-to-day usability of FreeThinker by making provocation actions faster, simplifying menus, and giving users direct control over key interaction settings.

### 1.2 Problem Statement
Users currently face avoidable friction in four places:
- Copying provocation text requires a dedicated button instead of direct interaction.
- Update-related controls are still visible even though update checking is currently disabled.
- The global hotkey cannot be customized to fit personal workflows.
- Style preset changes are buried in settings rather than available where users trigger provocations.

### 1.3 Solution
Deliver a focused UX update that:
- Copies provocation text when the text itself is clicked.
- Removes the dedicated copy button from the provocation panel.
- Hides update-related controls in both settings and the menu.
- Adds configurable global hotkey controls with validation, conflict handling, and reset to default.
- Adds style preset quick-switch controls directly in the menu dropdown.

---

## 2. User Scenarios & Testing

### 2.1 Copy by Clicking Provocation Text

**Given** a provocation is visible in the panel  
**When** the user clicks the provocation text  
**Then** the full provocation text is copied to the clipboard  
**And** no other action is triggered by that click.

### 2.2 Hidden Update Controls

**Given** the user opens settings  
**When** they navigate through available sections  
**Then** no Updates panel or update-checking controls are shown.

**Given** the user opens the menu dropdown  
**When** they scan available actions  
**Then** there is no "Check for Updates" menu item.

### 2.3 Hotkey Customization

**Given** the user opens hotkey settings  
**When** they enter a valid shortcut combination  
**Then** the new shortcut is saved and becomes the active trigger.

**Given** the user enters an invalid, reserved, or conflicting shortcut  
**When** they attempt to save it  
**Then** the app keeps the previous shortcut  
**And** shows a clear explanation of why the new shortcut was rejected.

**Given** the user wants default behavior restored  
**When** they choose reset  
**Then** the shortcut is set to `Cmd+Shift+P`.

### 2.4 Style Preset Quick Switch

**Given** multiple style presets exist  
**When** the user changes style from the menu dropdown  
**Then** the selected style is applied to subsequent provocations  
**And** the selection is reflected consistently across app settings and menu state.

### 2.5 Edge Cases

- Clicking rapidly on the same provocation should still copy the latest displayed text without side effects.
- If clipboard write fails, users should receive a clear, non-blocking error message.
- If a saved hotkey becomes unavailable later, the app should preserve the last known valid shortcut and prompt users to choose another.

---

## 3. Functional Requirements

**FR-001**: Clicking provocation text copies that exact provocation content to the clipboard.  
*Acceptance*: Clipboard content matches displayed text in full.

**FR-002**: The dedicated copy button is removed from the provocation panel UI.  
*Acceptance*: No copy button is visible in any panel state.

**FR-003**: Clicking provocation text performs copy only and does not trigger any additional interaction (such as regenerate, dismiss, or navigation).  
*Acceptance*: No secondary action occurs from the click.

**FR-004**: Update-related settings are hidden from the settings interface.  
*Acceptance*: Users cannot see update-checking controls in settings.

**FR-005**: The "Check for Updates" menu action is hidden from the menu dropdown.  
*Acceptance*: Menu no longer includes an update-check action.

**FR-006**: Automatic or manual update checking remains disabled while this feature is active.  
*Acceptance*: App does not initiate update-check prompts during normal use.

**FR-007**: Settings provide a control for customizing the global hotkey.  
*Acceptance*: Users can enter and attempt to save a new key combination.

**FR-008**: Invalid or reserved key combinations are blocked.  
*Acceptance*: Blocked combinations are not saved and a clear reason is shown.

**FR-009**: If a requested shortcut conflicts with an unavailable or prohibited combination, the current saved shortcut remains unchanged.  
*Acceptance*: Previous shortcut remains active after rejected changes.

**FR-010**: Settings include a reset control that restores the default hotkey (`Cmd+Shift+P`).  
*Acceptance*: Reset immediately restores and saves the default shortcut.

**FR-011**: The selected hotkey persists between sessions.  
*Acceptance*: After relaunch, the last valid saved hotkey is still active.

**FR-012**: The menu dropdown includes a quick-switch control for style preset selection.  
*Acceptance*: Users can change style preset directly from menu dropdown.

**FR-013**: Style preset changes made in the menu and settings remain synchronized.  
*Acceptance*: A change in one location is reflected in the other without manual refresh.

---

## 4. Success Criteria

| ID | Criterion | Measurement |
|----|-----------|-------------|
| SC-001 | Users can copy provocations in one click | 100% of tested clicks copy text without extra actions |
| SC-002 | Update controls are fully hidden during disabled period | 0 update-related controls visible in settings/menu audits |
| SC-003 | Users can successfully personalize shortcuts | At least one non-default valid shortcut can be saved and reused after relaunch |
| SC-004 | Invalid shortcut attempts fail safely | 100% of invalid/conflicting attempts preserve prior shortcut and show feedback |
| SC-005 | Style switching becomes faster | Users can change style preset from menu in 2 interactions or fewer |
| SC-006 | Settings consistency is maintained | 100% of style and hotkey changes remain synchronized across entry points |

---

## 5. Key Entities

**Provocation Display Item**
- Text content shown in the floating panel
- Click interaction state for copy action

**Application Settings**
- Global hotkey value
- Selected style preset
- Update visibility/availability state

**Menu State**
- Available actions visible in dropdown
- Current style preset quick-switch selection

**Hotkey Validation Result**
- Proposed key combination
- Validation status (valid/invalid/conflict/reserved)
- User-facing rejection reason when not valid

---

## 6. Assumptions

1. The app already has a defined set of style presets that can be selected in settings.
2. Clipboard permissions and behavior follow standard desktop expectations for local text copying.
3. Hiding update controls is temporary and should not remove the ability to re-enable updates in a future feature.
4. Existing provocation generation behavior remains unchanged except for copy interaction updates.

---

## 7. Dependencies

1. Existing floating provocation panel and menu dropdown remain available as current user entry points.
2. Existing settings storage can persist both hotkey and style preset values.
3. Existing shortcut registration behavior can apply a newly saved valid shortcut.

---

## 8. Out of Scope

1. Changing style preset definitions or adding new preset content.
2. Reintroducing or redesigning the update system.
3. Multi-shortcut profiles or context-specific hotkeys.
4. Changes to provocation generation quality, model behavior, or prompt logic.

---

## 9. Revision History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2026-02-13 | 1.0 | spec-kitty | Initial specification for copy behavior, update control hiding, hotkey customization, and style quick switch |
