# Quickstart Guide: FreeThinker Development

**Feature**: 001-freethinker-menu-bar-ai-provocation-app  
**Date**: 2026-02-12  
**Phase**: Phase 1 - Design & Contracts

---

## Prerequisites

### System Requirements
- macOS 26 (Tahoe) or later
- Apple Silicon Mac (M1, M2, M3, or later)
- Xcode 16.0 or later
- Swift 5.9 or later

### Required Tools
```bash
# Verify Xcode installation
xcode-select --version

# Verify Swift version
swift --version

# Install Homebrew dependencies (if needed)
brew install --cask sparkle
```

---

## Project Setup

### 1. Clone and Open

```bash
# Navigate to project root
cd /Users/tanner/Documents/experimental/ideas/freethinker

# Open Xcode project
open FreeThinker/FreeThinker.xcodeproj
```

### 2. Configure Signing

1. Select FreeThinker project in Xcode navigator
2. Select "FreeThinker" target
3. Go to "Signing & Capabilities" tab
4. Set Team to your Apple Developer account (or Personal Team)
5. Update Bundle Identifier (e.g., `com.yourname.freethinker`)

### 3. Add Sparkle Framework

**Option A: Swift Package Manager (Recommended)**
1. File -> Add Package Dependencies
2. Enter: `https://github.com/sparkle-project/Sparkle`
3. Select version 2.6.0 or later
4. Add to FreeThinker target

**Option B: Manual Download**
1. Download from https://sparkle-project.org/
2. Drag `Sparkle.framework` into project
3. Add to "Frameworks, Libraries, and Embedded Content"

### 4. Configure Entitlements

Ensure `FreeThinker.entitlements` includes:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
    <array>
        <string>com.apple.accessibility.Accessibility</string>
    </array>
</dict>
</plist>
```

**Note**: Sandboxing must be disabled for Accessibility API access.

---

## Build and Run

### Debug Build

```bash
# Build from command line
xcodebuild -project FreeThinker/FreeThinker.xcodeproj \
           -scheme FreeThinker \
           -configuration Debug \
           build

# Or use Xcode:
# Product -> Build (Cmd+B)
# Product -> Run (Cmd+R)
```

### Release Build

```bash
xcodebuild -project FreeThinker/FreeThinker.xcodeproj \
           -scheme FreeThinker \
           -configuration Release \
           -destination 'platform=macOS' \
           build
```

---

## First Time Setup

### 1. Grant Accessibility Permission

On first launch, FreeThinker requires Accessibility permission:

1. Launch the app
2. Click "Open System Settings" when prompted
3. Navigate to: Privacy & Security -> Accessibility
4. Add FreeThinker to the list and enable it
5. Relaunch the app

### 2. Test Text Capture

1. Open any text editor (TextEdit, Notes, Safari)
2. Select some text
3. Press `Cmd+Shift+P` (default hotkey)
4. Floating panel should appear with provocations

### 3. Customize Settings

1. Click menu bar icon (✨)
2. Select "Settings..."
3. Customize:
   - Hotkey combination
   - Provocation prompts
   - Launch at login preference
   - AI model selection

---

## Development Workflow

### Project Structure

```
FreeThinker/
├── FreeThinker/
│   ├── App/                 # App entry point
│   ├── Core/                # Business logic
│   │   ├── Models/          # Data models
│   │   ├── Services/        # Core services
│   │   └── Utilities/       # Extensions
│   ├── UI/                  # SwiftUI views
│   │   ├── FloatingPanel/
│   │   ├── MenuBar/
│   │   └── Settings/
│   └── Resources/
├── FreeThinkerTests/        # Unit tests
├── FreeThinkerUITests/      # UI tests
└── Frameworks/
```

### Running Tests

```bash
# All tests
xcodebuild test -project FreeThinker/FreeThinker.xcodeproj \
                -scheme FreeThinker \
                -destination 'platform=macOS'

# Specific test target
xcodebuild test -project FreeThinker/FreeThinker.xcodeproj \
                -scheme FreeThinker \
                -destination 'platform=macOS' \
                -only-testing:FreeThinkerTests
```

Or in Xcode:
- Product -> Test (Cmd+U)

### Debug Features

Enable debug logging:

```bash
# In Terminal before running
export FREETHINKER_DEBUG=1
./FreeThinker.app/Contents/MacOS/FreeThinker
```

---

## Key Services

### TextCaptureService

Captures selected text from any app:

```swift
let textService = AccessibilityTextCaptureService()

// Check permission
if !textService.hasAccessibilityPermission {
    textService.requestAccessibilityPermission()
}

// Capture text
do {
    let result = try await textService.captureSelectedText()
    print("Selected: \(result.text)")
} catch {
    print("Capture failed: \(error)")
}
```

### AIService

Generates provocations using on-device AI:

```swift
let aiService = FoundationModelsService()

// Generate provocation
let request = try ProvocationRequest(
    selectedText: "AI will replace all jobs",
    provocationType: .hiddenAssumptions,
    prompt: "Identify hidden assumptions"
)

let response = await aiService.generateProvocation(request: request)
switch response.outcome {
case .success(let content):
    print(content)
case .failure(let error):
    print("Generation failed: \(error.userMessage)")
}
```

### SettingsService

Persists user preferences:

```swift
let settingsService = UserDefaultsSettingsService()

// Read
let hotkey = settingsService.settings.hotkeyKeyCode

// Write
settingsService.settings.prompt1 = "Custom prompt"
// Automatically persisted
```

---

## Troubleshooting

### Build Errors

**"Sparkle framework not found"**
```bash
# Verify Sparkle is linked
# Project -> FreeThinker target -> General -> Frameworks
# Should see Sparkle.framework
```

**"Accessibility permission denied"**
- Check System Settings -> Privacy & Security -> Accessibility
- Ensure FreeThinker is checked
- May need to remove and re-add if bundle ID changed

### Runtime Issues

**Hotkey not working**
1. Check if Accessibility permission granted
2. Verify no other app using same hotkey
3. Check Console.app for errors

**AI not responding**
1. Verify Apple Silicon Mac (FoundationModels requires Neural Engine)
2. Check available memory (models require 4-8GB)
3. Try smaller model in Settings

**Panel not appearing**
1. Check `isPanelVisible` state in debugger
2. Verify `NSPanel` window level
3. Check if app is frontmost (panel may be behind)

### Debugging Tips

Enable verbose logging:
```swift
// In FreeThinkerApp.swift init
UserDefaults.standard.set(true, forKey: "FREETHINKER_DEBUG")
```

View logs:
```bash
# Stream logs
log stream --predicate 'subsystem == "com.freethinker"'
```

---

## Distribution

### Direct Download (.dmg)

1. Build Release version
2. Create .app bundle
3. Create DMG:

```bash
# Using create-dmg (install via Homebrew)
create-dmg \
  --volname "FreeThinker" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --app-drop-link 450 185 \
  "FreeThinker.dmg" \
  "build/Release/FreeThinker.app"
```

### Code Signing

```bash
# Sign the app
codesign --force --options runtime \
         --sign "Developer ID Application: Your Name" \
         --entitlements FreeThinker/FreeThinker.entitlements \
         build/Release/FreeThinker.app

# Notarize (for Gatekeeper)
xcrun altool --notarize-app \
             --primary-bundle-id "com.yourname.freethinker" \
             --username "your@email.com" \
             --password "@keychain:AC_PASSWORD" \
             --file FreeThinker.dmg
```

### Auto-Updates with Sparkle

1. Host appcast.xml on your server
2. Configure SUFeedURL in Info.plist
3. Sign updates with EdDSA key

```xml
<!-- appcast.xml -->
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>FreeThinker Changelog</title>
    <item>
      <title>Version 1.0</title>
      <sparkle:version>1.0</sparkle:version>
      <sparkle:shortVersionString>1.0</sparkle:shortVersionString>
      <pubDate>Thu, 12 Feb 2026 12:00:00 +0000</pubDate>
      <enclosure url="https://yourserver.com/FreeThinker-1.0.dmg"
                 sparkle:edSignature="..."
                 length="12345678"
                 type="application/octet-stream"/>
    </item>
  </channel>
</rss>
```

---

## Contributing

### Code Style

- Follow Swift API Design Guidelines
- Use SwiftUI for all UI
- Document public APIs with Swift documentation comments
- Add unit tests for new features

### Testing Requirements

Before submitting changes:
1. Run full test suite: `Cmd+U` in Xcode
2. Test on clean macOS install (VM recommended)
3. Verify Accessibility permission flow
4. Test with multiple apps (Safari, Mail, Notes, etc.)

---

## Resources

- **Specification**: `kitty-specs/001-freethinker-menu-bar-ai-provocation-app/spec.md`
- **Data Model**: `kitty-specs/001-freethinker-menu-bar-ai-provocation-app/data-model.md`
- **API Contracts**: `kitty-specs/001-freethinker-menu-bar-ai-provocation-app/contracts/`
- **Apple Documentation**:
  - [FoundationModels](https://developer.apple.com/documentation/foundationmodels)
  - [Accessibility](https://developer.apple.com/library/archive/documentation/Accessibility/Conceptual/AccessibilityMacOSX/)
  - [SwiftUI](https://developer.apple.com/documentation/swiftui)

---

**Status**: COMPLETE  
**Next Step**: Generate work packages with `/spec-kitty.tasks`
