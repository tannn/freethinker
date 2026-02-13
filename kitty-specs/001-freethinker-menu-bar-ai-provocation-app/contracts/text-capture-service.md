# TextCaptureService Contract

**Service**: TextCaptureService  
**Purpose**: Capture selected text from any macOS application using Accessibility APIs  
**Implementation**: AccessibilityTextCaptureService  

---

## Protocol Definition

```swift
protocol TextCaptureServiceProtocol {
    /// Captures the currently selected text from the frontmost application
    /// - Returns: Captured text and selection bounds for positioning
    /// - Throws: TextCaptureError if capture fails
    func captureSelectedText() async throws -> TextCaptureResult
    
    /// Checks if the app has Accessibility permission
    var hasAccessibilityPermission: Bool { get }
    
    /// Requests Accessibility permission from the user
    func requestAccessibilityPermission()
    
    /// Stream of permission status updates
    var permissionStatusStream: AsyncStream<Bool> { get }
}

struct TextCaptureResult {
    let text: String
    let selectionBounds: CGRect?
    let sourceApp: String?
    
    var isEmpty: Bool {
        text.isEmpty
    }
}

enum TextCaptureError: Error {
    case permissionDenied
    case noFocusedElement
    case noSelection
    case captureFailed(String)
}
```

---

## Methods

### captureSelectedText

Captures the currently selected text from the active application.

**Signature**:
```swift
func captureSelectedText() async throws -> TextCaptureResult
```

**Returns**:
| Property | Type | Description |
|----------|------|-------------|
| text | String | The selected text (empty if no selection) |
| selectionBounds | CGRect? | Screen coordinates of selection (nil if unavailable) |
| sourceApp | String? | Name of source application (nil if unavailable) |

**Throws**:
- `TextCaptureError.permissionDenied` - Accessibility permission not granted
- `TextCaptureError.noFocusedElement` - No focused UI element found
- `TextCaptureError.captureFailed` - Internal accessibility API error

**Example**:
```swift
let service: TextCaptureServiceProtocol = AccessibilityTextCaptureService()

do {
    let result = try await service.captureSelectedText()
    
    if result.isEmpty {
        print("No text selected")
    } else {
        print("Selected: \(result.text)")
        print("From app: \(result.sourceApp ?? "Unknown")")
        print("Position: \(String(describing: result.selectionBounds))")
    }
} catch TextCaptureError.permissionDenied {
    // Guide user to System Settings
} catch {
    print("Capture failed: \(error)")
}
```

**Performance Requirements**:
- Execution time: <50ms
- Synchronous check for permission
- Asynchronous capture operation

---

### requestAccessibilityPermission

Opens System Settings and guides the user to enable Accessibility permission.

**Signature**:
```swift
func requestAccessibilityPermission()
```

**Behavior**:
- Opens `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`
- Shows instructional alert before opening
- Does not block - returns immediately

**Example**:
```swift
if !service.hasAccessibilityPermission {
    service.requestAccessibilityPermission()
    // Show UI explaining how to enable permission
}
```

---

## Properties

### hasAccessibilityPermission

Checks whether the app has been granted Accessibility permission.

**Type**: `Bool`  
**Access**: Read-only

**Implementation**:
```swift
var hasAccessibilityPermission: Bool {
    // Check AXIsProcessTrusted without prompting
    return AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: false] as CFDictionary)
}
```

**Usage**:
Check before attempting capture to provide graceful degradation.

---

### permissionStatusStream

AsyncStream that emits permission status changes.

**Type**: `AsyncStream<Bool>`  
**Access**: Read-only

**Emits**:
- `true` when permission is granted
- `false` when permission is revoked

**Usage**:
```swift
Task {
    for await hasPermission in service.permissionStatusStream {
        await MainActor.run {
            appState.hasAccessibilityPermission = hasPermission
        }
    }
}
```

---

## Implementation: AccessibilityTextCaptureService

```swift
import ApplicationServices

actor AccessibilityTextCaptureService: TextCaptureServiceProtocol {
    private var permissionCheckTimer: Timer?
    private var permissionContinuation: AsyncStream<Bool>.Continuation?
    
    var hasAccessibilityPermission: Bool {
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: false] as CFDictionary)
    }
    
    var permissionStatusStream: AsyncStream<Bool> {
        AsyncStream { continuation in
            self.permissionContinuation = continuation
            
            // Initial value
            continuation.yield(hasAccessibilityPermission)
            
            // Poll for changes
            self.permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                let currentStatus = self.hasAccessibilityPermission
                continuation.yield(currentStatus)
            }
            
            continuation.onTermination = { _ in
                self.permissionCheckTimer?.invalidate()
            }
        }
    }
    
    func requestAccessibilityPermission() {
        // Show alert first
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "FreeThinker needs Accessibility permission to capture selected text. Please enable it in System Settings."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Open accessibility preferences
            guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
                return
            }
            NSWorkspace.shared.open(url)
        }
    }
    
    func captureSelectedText() async throws -> TextCaptureResult {
        guard hasAccessibilityPermission else {
            throw TextCaptureError.permissionDenied
        }
        
        // Get system-wide accessibility element
        let systemWideElement = AXUIElementCreateSystemWide()
        
        // Get the focused UI element
        var focusedElementRef: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementRef
        )
        
        guard focusedResult == .success, let focusedElement = focusedElementRef else {
            throw TextCaptureError.noFocusedElement
        }
        
        // Get selected text
        var selectedTextRef: CFTypeRef?
        let textResult = AXUIElementCopyAttributeValue(
            focusedElement as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedTextRef
        )
        
        let selectedText: String
        if textResult == .success, let textValue = selectedTextRef {
            selectedText = textValue as? String ?? ""
        } else {
            selectedText = ""
        }
        
        // Get selection bounds for positioning
        var bounds: CGRect?
        var selectedRangeRef: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(
            focusedElement as! AXElement,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRangeRef
        )
        
        if rangeResult == .success, let rangeValue = selectedRangeRef {
            // Convert AXValue to CFRange, then get bounds
            // This requires additional AXUIElement calls to get position
            // Implementation simplified for contract - actual code more complex
            bounds = nil // Placeholder
        }
        
        // Get source app name
        var appRef: CFTypeRef?
        var appName: String?
        let appResult = AXUIElementCopyAttributeValue(
            focusedElement as! AXUIElement,
            kAXTitleUIElementAttribute as CFString,
            &appRef
        )
        
        if appResult == .success {
            // Extract app name from element
            appName = nil // Implementation detail
        }
        
        return TextCaptureResult(
            text: selectedText,
            selectionBounds: bounds,
            sourceApp: appName
        )
    }
}
```

---

## Error Handling

| Error | Cause | User Action |
|-------|-------|-------------|
| `permissionDenied` | Accessibility permission not granted | Guide user to System Settings |
| `noFocusedElement` | No UI element has focus | User may need to click on text area |
| `noSelection` | No text selected in focused element | User needs to select text first |
| `captureFailed` | Internal AX API error | Retry or report issue |

---

## Testing

### Mock Implementation

```swift
class MockTextCaptureService: TextCaptureServiceProtocol {
    var hasAccessibilityPermission: Bool = true
    var mockText: String = "Mock selected text"
    var mockBounds: CGRect? = CGRect(x: 100, y: 100, width: 200, height: 50)
    var mockSourceApp: String? = "Safari"
    var shouldFail: Bool = false
    var failWith: TextCaptureError = .captureFailed("Mock error")
    
    var permissionStatusStream: AsyncStream<Bool> {
        AsyncStream { continuation in
            continuation.yield(hasAccessibilityPermission)
            continuation.finish()
        }
    }
    
    func requestAccessibilityPermission() {
        // Mock implementation - no-op
    }
    
    func captureSelectedText() async throws -> TextCaptureResult {
        if shouldFail {
            throw failWith
        }
        
        return TextCaptureResult(
            text: mockText,
            selectionBounds: mockBounds,
            sourceApp: mockSourceApp
        )
    }
}
```

### Test Scenarios

1. **Happy Path**: Valid selection returns text and bounds
2. **No Selection**: Empty text returned (not error)
3. **Permission Denied**: Throws permission error
4. **No Focus**: Throws noFocusedElement error
5. **Long Text**: Correctly handles text up to 1000 chars
6. **Special Characters**: Handles emoji, unicode correctly

---

## Security Considerations

- **User Consent**: Accessibility permission requires explicit user approval
- **Sandbox**: Cannot be used in sandboxed Mac App Store apps
- **Privacy**: Only captures text from currently focused app
- **Audit**: macOS logs accessibility API usage for security

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-02-12 | Initial contract |
