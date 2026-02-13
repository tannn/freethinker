# SettingsService Contract

**Service**: SettingsService  
**Purpose**: Persist and retrieve user preferences  
**Implementation**: UserDefaultsSettingsService  

---

## Protocol Definition

```swift
protocol SettingsServiceProtocol {
    /// The current application settings
    var settings: AppSettings { get set }
    
    /// Resets all settings to default values
    func resetToDefaults()
    
    /// Exports settings to a JSON file
    func exportSettings(to url: URL) throws
    
    /// Imports settings from a JSON file
    func importSettings(from url: URL) throws
    
    /// Stream of settings changes
    var settingsChangedStream: AsyncStream<AppSettings> { get }
}
```

---

## Properties

### settings

The current application settings object.

**Type**: `AppSettings`  
**Access**: Read/Write

**Behavior**:
- Getting returns the current settings from UserDefaults
- Setting persists to UserDefaults immediately
- Emits update to `settingsChangedStream`

**Example**:
```swift
let service: SettingsServiceProtocol = UserDefaultsSettingsService()

// Read
let currentHotkey = service.settings.hotkeyKeyCode

// Write
service.settings.prompt1 = "Custom prompt text"
// Automatically persisted
```

---

## Methods

### resetToDefaults

Resets all settings to their default values.

**Signature**:
```swift
func resetToDefaults()
```

**Behavior**:
- Creates new `AppSettings()` with default values
- Persists to UserDefaults
- Emits update to `settingsChangedStream`

**Example**:
```swift
// User wants to start fresh
service.resetToDefaults()
// All settings now at factory defaults
```

---

### exportSettings

Exports current settings to a JSON file for backup or sharing.

**Signature**:
```swift
func exportSettings(to url: URL) throws
```

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| url | URL | Destination file URL (must be writable) |

**Throws**:
- `SettingsError.exportFailed` - Cannot write to URL
- `SettingsError.encodingFailed` - Settings cannot be encoded

**Example**:
```swift
let exportURL = FileManager.default
    .urls(for: .documentDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("freethinker-settings.json")

do {
    try service.exportSettings(to: exportURL)
    print("Settings exported to \(exportURL)")
} catch {
    print("Export failed: \(error)")
}
```

---

### importSettings

Imports settings from a JSON file.

**Signature**:
```swift
func importSettings(from url: URL) throws
```

**Parameters**:
| Parameter | Type | Description |
|-----------|------|-------------|
| url | URL | Source file URL (must be readable) |

**Throws**:
- `SettingsError.importFailed` - Cannot read from URL
- `SettingsError.decodingFailed` - Invalid JSON or schema
- `SettingsError.validationFailed` - Settings values invalid

**Example**:
```swift
do {
    try service.importSettings(from: importURL)
    print("Settings imported successfully")
} catch SettingsError.validationFailed {
    print("Invalid settings file")
} catch {
    print("Import failed: \(error)")
}
```

---

### settingsChangedStream

AsyncStream that emits whenever settings are modified.

**Type**: `AsyncStream<AppSettings>`  
**Access**: Read-only

**Emits**:
- Current settings on subscription
- Updated settings after any change

**Usage**:
```swift
Task {
    for await settings in service.settingsChangedStream {
        // React to settings changes
        updateHotkeyMonitor(settings.hotkeyModifiers, settings.hotkeyKeyCode)
    }
}
```

---

## Implementation: UserDefaultsSettingsService

```swift
import Combine

actor UserDefaultsSettingsService: SettingsServiceProtocol {
    private let userDefaults: UserDefaults
    private let settingsKey = "com.freethinker.settings"
    private var settingsContinuation: AsyncStream<AppSettings>.Continuation?
    private var cancellables = Set<AnyCancellable>()
    
    private var _settings: AppSettings {
        didSet {
            // Persist to UserDefaults
            if let encoded = try? JSONEncoder().encode(_settings) {
                userDefaults.set(encoded, forKey: settingsKey)
            }
            // Emit change
            settingsContinuation?.yield(_settings)
        }
    }
    
    var settings: AppSettings {
        get { _settings }
        set { _settings = newValue }
    }
    
    var settingsChangedStream: AsyncStream<AppSettings> {
        AsyncStream { continuation in
            self.settingsContinuation = continuation
            continuation.yield(_settings)
            
            continuation.onTermination = { _ in
                self.settingsContinuation = nil
            }
        }
    }
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        
        // Load existing or create defaults
        if let data = userDefaults.data(forKey: settingsKey),
           let loaded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self._settings = loaded
        } else {
            self._settings = AppSettings()
        }
    }
    
    func resetToDefaults() {
        settings = AppSettings()
    }
    
    func exportSettings(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        guard let data = try? encoder.encode(settings) else {
            throw SettingsError.encodingFailed
        }
        
        do {
            try data.write(to: url)
        } catch {
            throw SettingsError.exportFailed(error.localizedDescription)
        }
    }
    
    func importSettings(from url: URL) throws {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw SettingsError.importFailed(error.localizedDescription)
        }
        
        let decoder = JSONDecoder()
        let imported: AppSettings
        do {
            imported = try decoder.decode(AppSettings.self, from: data)
        } catch {
            throw SettingsError.decodingFailed(error.localizedDescription)
        }
        
        // Validate imported settings
        guard validateSettings(imported) else {
            throw SettingsError.validationFailed
        }
        
        settings = imported
    }
    
    private func validateSettings(_ settings: AppSettings) -> Bool {
        // Validate hotkey
        guard settings.hotkeyKeyCode >= 0 && settings.hotkeyKeyCode <= 127 else {
            return false
        }
        
        // Validate prompts
        guard !settings.prompt1.isEmpty && settings.prompt1.count <= 1000,
              !settings.prompt2.isEmpty && settings.prompt2.count <= 1000 else {
            return false
        }
        
        // Validate model option
        switch settings.selectedModel {
        case .default, .creativeWriting:
            break
        }
        
        return true
    }
}

enum SettingsError: Error {
    case encodingFailed
    case decodingFailed(String)
    case exportFailed(String)
    case importFailed(String)
    case validationFailed
}
```

---

## Data Persistence Details

### Storage Format

Settings are stored as JSON in UserDefaults under key `com.freethinker.settings`.

**Example Storage**:
```json
{
  "hotkeyModifiers": 1179648,
  "hotkeyKeyCode": 35,
  "prompt1": "Identify hidden assumptions in this text",
  "prompt2": "Provide a strong counterargument",
  "launchAtLogin": true,
  "selectedModel": "default",
  "showMenuBarIcon": true,
  "dismissOnCopy": true,
  "_schemaVersion": 1
}
```

### Migration Strategy

```swift
struct AppSettings: Codable {
    // ... existing fields ...
    
    // Schema version for future migrations
    var schemaVersion: Int = 1
    
    // Migration logic
    static func load(from data: Data) throws -> AppSettings {
        let decoder = JSONDecoder()
        var settings = try decoder.decode(AppSettings.self, from: data)
        
        // Apply migrations
        if settings.schemaVersion < 2 {
            // Migration to version 2
            settings = migrateToV2(settings)
        }
        
        return settings
    }
}
```

---

## Testing

### Mock Implementation

```swift
class MockSettingsService: SettingsServiceProtocol {
    var settings: AppSettings = AppSettings()
    var shouldFailExport: Bool = false
    var shouldFailImport: Bool = false
    
    var settingsChangedStream: AsyncStream<AppSettings> {
        AsyncStream { continuation in
            continuation.yield(settings)
            continuation.finish()
        }
    }
    
    func resetToDefaults() {
        settings = AppSettings()
    }
    
    func exportSettings(to url: URL) throws {
        if shouldFailExport {
            throw SettingsError.exportFailed("Mock export failure")
        }
        // Mock successful export
    }
    
    func importSettings(from url: URL) throws {
        if shouldFailImport {
            throw SettingsError.importFailed("Mock import failure")
        }
        // Mock successful import
        settings = AppSettings(
            prompt1: "Imported prompt 1",
            prompt2: "Imported prompt 2"
        )
    }
}
```

### Test Cases

1. **Load Defaults**: Fresh install returns default settings
2. **Persist Changes**: Settings survive app restart
3. **Reset**: Reset restores defaults
4. **Export/Import**: Round-trip preserves settings
5. **Invalid Import**: Rejects malformed JSON
6. **Validation**: Rejects invalid values (e.g., bad keycode)
7. **Stream Updates**: Changes emit to stream subscribers

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-02-12 | Initial contract |
