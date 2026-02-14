import AppKit
import Carbon
import Foundation

public enum GlobalHotkeyServiceError: Error, Equatable, Sendable {
    case disabled
    case invalidShortcut(message: String)
    case reservedShortcut(message: String)
    case conflict
    case registrationFailed(status: Int32)
    case handlerInstallFailed(status: Int32)

    public var mappedFreeThinkerError: FreeThinkerError {
        switch self {
        case .disabled:
            return .generationFailed
        case .invalidShortcut:
            return .hotkeyShortcutInvalid
        case .reservedShortcut:
            return .hotkeyShortcutReserved
        case .conflict:
            return .hotkeyRegistrationConflict
        case .registrationFailed, .handlerInstallFailed:
            return .hotkeyRegistrationFailed
        }
    }
}

public protocol GlobalHotkeyRegistering: AnyObject {
    func installHandler(_ handler: @escaping (UInt32) -> Void) throws
    func removeHandler()
    func register(id: UInt32, keyCode: UInt32, modifiers: UInt32) throws
    func unregister(id: UInt32)
}

@MainActor
public protocol GlobalHotkeyServiceProtocol: AnyObject {
    var isRegistered: Bool { get }
    var onTrigger: (() -> Void)? { get set }
    var onRegistrationError: ((GlobalHotkeyServiceError) -> Void)? { get set }

    func validateShortcutProposal(
        _ proposedShortcut: HotkeyShortcut,
        effectiveShortcut: HotkeyShortcut
    ) -> HotkeyValidationResult
    func register(using settings: AppSettings) throws
    func refreshRegistration(using settings: AppSettings)
    func unregister()
}

@MainActor
public final class GlobalHotkeyService: GlobalHotkeyServiceProtocol {
    public private(set) var isRegistered: Bool = false
    public var onTrigger: (() -> Void)?
    public var onRegistrationError: ((GlobalHotkeyServiceError) -> Void)?

    private let hotkeyID: UInt32
    private let registrar: any GlobalHotkeyRegistering
    private var registeredShortcut: HotkeyShortcut?

    public init(
        registrar: any GlobalHotkeyRegistering,
        hotkeyID: UInt32 = 1,
        initialSettings: AppSettings = AppSettings()
    ) {
        self.registrar = registrar
        self.hotkeyID = hotkeyID
        _ = initialSettings
    }

    public convenience init() {
        self.init(registrar: CarbonGlobalHotkeyRegistrar())
    }

    public func validateShortcutProposal(
        _ proposedShortcut: HotkeyShortcut,
        effectiveShortcut: HotkeyShortcut
    ) -> HotkeyValidationResult {
        if let localValidation = localValidationResult(
            for: proposedShortcut,
            effectiveShortcut: effectiveShortcut
        ) {
            return localValidation
        }

        if proposedShortcut == effectiveShortcut {
            return .valid(
                proposedShortcut: proposedShortcut,
                effectiveShortcut: effectiveShortcut
            )
        }

        do {
            try registrar.register(
                id: probeHotkeyID,
                keyCode: UInt32(proposedShortcut.keyCode),
                modifiers: Self.carbonModifiers(from: proposedShortcut.modifiers)
            )
            registrar.unregister(id: probeHotkeyID)

            return .valid(
                proposedShortcut: proposedShortcut,
                effectiveShortcut: proposedShortcut
            )
        } catch let error as GlobalHotkeyServiceError {
            return validationResult(
                for: error,
                proposedShortcut: proposedShortcut,
                effectiveShortcut: effectiveShortcut
            )
        } catch {
            return .invalid(
                proposedShortcut: proposedShortcut,
                effectiveShortcut: effectiveShortcut,
                message: "This shortcut could not be validated. Try a different key combination."
            )
        }
    }

    public func register(using settings: AppSettings) throws {
        let resolved = settings.validated()
        let proposedShortcut = resolved.hotkeyShortcut

        guard resolved.hotkeyEnabled else {
            unregister()
            isRegistered = false
            throw GlobalHotkeyServiceError.disabled
        }

        if isRegistered, registeredShortcut == proposedShortcut {
            return
        }

        let validationResult = validateShortcutProposal(
            proposedShortcut,
            effectiveShortcut: registeredShortcut ?? proposedShortcut
        )
        guard validationResult.isAccepted else {
            let error = Self.error(for: validationResult)
            onRegistrationError?(error)
            Logger.warning("Global hotkey registration failed error=\(String(describing: error))", category: .hotkey)
            throw error
        }

        let previousShortcut = registeredShortcut
        unregister()

        do {
            try installHandlerIfNeeded()
            try registerHotkey(shortcut: proposedShortcut)
            isRegistered = true
            registeredShortcut = proposedShortcut
            Logger.info("Registered global hotkey keyCode=\(proposedShortcut.keyCode)", category: .hotkey)
        } catch let error as GlobalHotkeyServiceError {
            recoverPreviousRegistration(previousShortcut)
            onRegistrationError?(error)
            Logger.warning("Global hotkey registration failed error=\(String(describing: error))", category: .hotkey)
            throw error
        } catch {
            let wrapped = GlobalHotkeyServiceError.registrationFailed(status: Int32(paramErr))
            recoverPreviousRegistration(previousShortcut)
            onRegistrationError?(wrapped)
            Logger.warning("Global hotkey registration failed error=\(error.localizedDescription)", category: .hotkey)
            throw wrapped
        }
    }

    public func refreshRegistration(using settings: AppSettings) {
        do {
            try register(using: settings)
        } catch GlobalHotkeyServiceError.disabled {
            return
        } catch {
            // registration errors are already surfaced via callback
        }
    }

    public func unregister() {
        registrar.unregister(id: hotkeyID)
        registrar.removeHandler()
        isRegistered = false
        registeredShortcut = nil
        Logger.debug("Unregistered global hotkey", category: .hotkey)
    }
}

private extension GlobalHotkeyService {
    static let supportedModifiers: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
    static let reservedCommandKeyCodes: Set<Int> = [4, 12, 13, 46, 48, 49, 50]

    var probeHotkeyID: UInt32 {
        hotkeyID &+ 10_000
    }

    static func error(for result: HotkeyValidationResult) -> GlobalHotkeyServiceError {
        switch result.status {
        case .valid:
            return .registrationFailed(status: Int32(paramErr))
        case .invalid:
            return .invalidShortcut(
                message: result.message ?? "The selected shortcut is not supported."
            )
        case .reserved:
            return .reservedShortcut(
                message: result.message ?? "This shortcut is reserved by macOS."
            )
        case .conflict:
            return .conflict
        }
    }

    func localValidationResult(
        for proposedShortcut: HotkeyShortcut,
        effectiveShortcut: HotkeyShortcut
    ) -> HotkeyValidationResult? {
        guard (0...127).contains(proposedShortcut.keyCode) else {
            return .invalid(
                proposedShortcut: proposedShortcut,
                effectiveShortcut: effectiveShortcut,
                message: "Select a supported key."
            )
        }

        guard proposedShortcut.modifiers >= 0 else {
            return .invalid(
                proposedShortcut: proposedShortcut,
                effectiveShortcut: effectiveShortcut,
                message: "Use at least one modifier key."
            )
        }

        let modifierFlags = NSEvent.ModifierFlags(rawValue: UInt(proposedShortcut.modifiers))
            .intersection(.deviceIndependentFlagsMask)
        let unsupportedModifiers = modifierFlags.subtracting(Self.supportedModifiers)
        guard unsupportedModifiers.isEmpty else {
            return .invalid(
                proposedShortcut: proposedShortcut,
                effectiveShortcut: effectiveShortcut,
                message: "Use only Command, Shift, Option, or Control."
            )
        }

        let supportedFlags = modifierFlags.intersection(Self.supportedModifiers)
        guard supportedFlags.isEmpty == false else {
            return .invalid(
                proposedShortcut: proposedShortcut,
                effectiveShortcut: effectiveShortcut,
                message: "Use at least one modifier key."
            )
        }

        if isReservedShortcut(keyCode: proposedShortcut.keyCode, modifiers: supportedFlags) {
            return .reserved(
                proposedShortcut: proposedShortcut,
                effectiveShortcut: effectiveShortcut,
                message: "This shortcut is reserved. Choose a different combination."
            )
        }

        return nil
    }

    func validationResult(
        for error: GlobalHotkeyServiceError,
        proposedShortcut: HotkeyShortcut,
        effectiveShortcut: HotkeyShortcut
    ) -> HotkeyValidationResult {
        switch error {
        case .conflict:
            return .conflict(
                proposedShortcut: proposedShortcut,
                effectiveShortcut: effectiveShortcut,
                message: "That shortcut is already used by another app."
            )
        case .invalidShortcut(let message):
            return .invalid(
                proposedShortcut: proposedShortcut,
                effectiveShortcut: effectiveShortcut,
                message: message
            )
        case .reservedShortcut(let message):
            return .reserved(
                proposedShortcut: proposedShortcut,
                effectiveShortcut: effectiveShortcut,
                message: message
            )
        case .disabled, .registrationFailed, .handlerInstallFailed:
            return .invalid(
                proposedShortcut: proposedShortcut,
                effectiveShortcut: effectiveShortcut,
                message: "This shortcut could not be validated. Try a different key combination."
            )
        }
    }

    func isReservedShortcut(keyCode: Int, modifiers: NSEvent.ModifierFlags) -> Bool {
        modifiers.contains(.command) && Self.reservedCommandKeyCodes.contains(keyCode)
    }

    func installHandlerIfNeeded() throws {
        try registrar.installHandler { [weak self] id in
            guard let self else { return }
            guard id == self.hotkeyID else { return }
            self.onTrigger?()
        }
    }

    func registerHotkey(shortcut: HotkeyShortcut) throws {
        try registrar.register(
            id: hotkeyID,
            keyCode: UInt32(shortcut.keyCode),
            modifiers: Self.carbonModifiers(from: shortcut.modifiers)
        )
    }

    func recoverPreviousRegistration(_ previousShortcut: HotkeyShortcut?) {
        guard let previousShortcut else {
            isRegistered = false
            registeredShortcut = nil
            return
        }

        do {
            try installHandlerIfNeeded()
            try registerHotkey(shortcut: previousShortcut)
            isRegistered = true
            registeredShortcut = previousShortcut
            Logger.warning(
                "Restored previous global hotkey after failed update keyCode=\(previousShortcut.keyCode)",
                category: .hotkey
            )
        } catch {
            isRegistered = false
            registeredShortcut = nil
            Logger.warning(
                "Failed to restore previous global hotkey error=\(error.localizedDescription)",
                category: .hotkey
            )
        }
    }

    static func carbonModifiers(from cocoaRawValue: Int) -> UInt32 {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(max(cocoaRawValue, 0)))
        var result: UInt32 = 0

        if flags.contains(.command) {
            result |= UInt32(cmdKey)
        }
        if flags.contains(.shift) {
            result |= UInt32(shiftKey)
        }
        if flags.contains(.option) {
            result |= UInt32(optionKey)
        }
        if flags.contains(.control) {
            result |= UInt32(controlKey)
        }

        return result
    }
}

public final class CarbonGlobalHotkeyRegistrar: GlobalHotkeyRegistering {
    private var eventHandlerRef: EventHandlerRef?
    private var hotKeys: [UInt32: EventHotKeyRef] = [:]
    private var onPressed: ((UInt32) -> Void)?

    public init() {}

    public func installHandler(_ handler: @escaping (UInt32) -> Void) throws {
        onPressed = handler

        if eventHandlerRef != nil {
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotkeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        guard status == noErr else {
            throw GlobalHotkeyServiceError.handlerInstallFailed(status: status)
        }
    }

    public func removeHandler() {
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
        eventHandlerRef = nil
        onPressed = nil
    }

    public func register(id: UInt32, keyCode: UInt32, modifiers: UInt32) throws {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr else {
            if status == eventHotKeyExistsErr {
                throw GlobalHotkeyServiceError.conflict
            }
            throw GlobalHotkeyServiceError.registrationFailed(status: status)
        }

        if let hotKeyRef {
            hotKeys[id] = hotKeyRef
        }
    }

    public func unregister(id: UInt32) {
        guard let hotKey = hotKeys.removeValue(forKey: id) else {
            return
        }
        UnregisterEventHotKey(hotKey)
    }
}

fileprivate extension CarbonGlobalHotkeyRegistrar {
    static let signature = OSType(UInt32(ascii: "FRTH"))

    func handlePressed(id: UInt32) {
        onPressed?(id)
    }
}

private func carbonHotkeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else {
        return noErr
    }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    guard status == noErr else {
        return status
    }

    let registrar = Unmanaged<CarbonGlobalHotkeyRegistrar>.fromOpaque(userData).takeUnretainedValue()
    registrar.handlePressed(id: hotKeyID.id)
    return noErr
}

private extension UInt32 {
    init(ascii: String) {
        precondition(ascii.utf8.count == 4, "Expected four ASCII bytes")
        self = ascii.utf8.reduce(0) { ($0 << 8) + UInt32($1) }
    }
}
