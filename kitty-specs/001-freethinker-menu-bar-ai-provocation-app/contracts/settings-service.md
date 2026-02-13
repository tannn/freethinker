# SettingsService Contract

**Service**: SettingsService  
**Purpose**: Persist and retrieve user preferences  
**Implementation**: UserDefaultsSettingsService

---

## Protocol Definition

```swift
protocol SettingsServiceProtocol {
    /// The current application settings.
    /// Set operations are validated before persistence.
    var settings: AppSettings { get set }

    /// Resets all settings to default values.
    func resetToDefaults()

    /// Exports settings to a JSON file.
    func exportSettings(to url: URL) throws

    /// Imports settings from a JSON file.
    func importSettings(from url: URL) throws

    /// Stream of settings changes.
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
- Getting returns in-memory settings
- Setting validates and persists to UserDefaults immediately
- Emits update to `settingsChangedStream`

**Example**:
```swift
let service: SettingsServiceProtocol = UserDefaultsSettingsService()

// Read
let currentHotkey = service.settings.hotkeyKeyCode

// Write
var updated = service.settings
updated.prompt1 = "Custom prompt text"
service.settings = updated
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

---

### exportSettings

Exports current settings to a JSON file for backup.

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

**Behavior**:
- Decodes `AppSettings`
- Applies schema migration if needed
- Runs `validated()` before commit
- Persists and emits changed settings

---

### settingsChangedStream

AsyncStream that emits whenever settings are modified.

**Type**: `AsyncStream<AppSettings>`  
**Access**: Read-only

**Emits**:
- Current settings on subscription
- Updated settings after any change

---

## Implementation: UserDefaultsSettingsService

```swift
actor UserDefaultsSettingsService: SettingsServiceProtocol {
    private let userDefaults: UserDefaults
    private let settingsKey = "com.freethinker.settings"
    private var settingsContinuation: AsyncStream<AppSettings>.Continuation?

    private var _settings: AppSettings {
        didSet {
            if let encoded = try? JSONEncoder().encode(_settings) {
                userDefaults.set(encoded, forKey: settingsKey)
            }
            settingsContinuation?.yield(_settings)
        }
    }

    var settings: AppSettings {
        get { _settings }
        set { _settings = newValue.validated() }
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

        if let data = userDefaults.data(forKey: settingsKey),
           let loaded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self._settings = Self.migrateIfNeeded(loaded).validated()
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

        settings = Self.migrateIfNeeded(imported).validated()
    }

    private static func migrateIfNeeded(_ settings: AppSettings) -> AppSettings {
        var result = settings

        // Reserved migration hook for future schema updates.
        if result.schemaVersion < AppSettings.currentSchemaVersion {
            result.schemaVersion = AppSettings.currentSchemaVersion
        }

        return result
    }
}

enum SettingsError: Error {
    case encodingFailed
    case decodingFailed(String)
    case exportFailed(String)
    case importFailed(String)
}
```

---

## Data Persistence Details

### Storage Format

Settings are stored as JSON in UserDefaults under key `com.freethinker.settings`.

**Example Storage**:
```json
{
  "schemaVersion": 1,
  "hotkeyModifiers": 1179648,
  "hotkeyKeyCode": 35,
  "prompt1": "Identify hidden assumptions in this text",
  "prompt2": "Provide a strong counterargument",
  "launchAtLogin": true,
  "selectedModel": "default",
  "showMenuBarIcon": true,
  "dismissOnCopy": true
}
```

### Migration Strategy

```swift
struct AppSettings: Codable {
    var schemaVersion: Int = 1

    static func load(from data: Data) throws -> AppSettings {
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppSettings.self, from: data)
        return migrateIfNeeded(decoded).validated()
    }

    private static func migrateIfNeeded(_ settings: AppSettings) -> AppSettings {
        var result = settings
        if result.schemaVersion < 2 {
            // Example migration to version 2.
            result.schemaVersion = 2
        }
        return result
    }
}
```

---

## Testing

### Mock Implementation

```swift
class MockSettingsService: SettingsServiceProtocol {
    var settings: AppSettings = AppSettings()

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
        // Mock successful export
    }

    func importSettings(from url: URL) throws {
        settings = AppSettings(
            prompt1: "Imported prompt 1",
            prompt2: "Imported prompt 2"
        ).validated()
    }
}
```

### Test Cases

1. **Load Defaults**: Fresh install returns default settings
2. **Persist Changes**: Settings survive app restart
3. **Reset**: Reset restores defaults
4. **Export/Import**: Round-trip preserves settings
5. **Invalid Import**: Rejects malformed JSON
6. **Validation on Set/Load/Import**: Invalid values are normalized to valid defaults
7. **Stream Updates**: Changes emit to stream subscribers

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.1 | 2026-02-13 | Added validation-first persistence and schema-version alignment |
| 1.0 | 2026-02-12 | Initial contract |
