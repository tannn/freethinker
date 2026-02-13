import AppKit
import Carbon
import Foundation

public enum GlobalHotkeyServiceError: Error, Equatable, Sendable {
    case disabled
    case conflict
    case registrationFailed(status: Int32)
    case handlerInstallFailed(status: Int32)

    public var mappedFreeThinkerError: FreeThinkerError {
        switch self {
        case .disabled:
            return .generationFailed
        case .conflict:
            return .hotkeyRegistrationConflict
        case .registrationFailed, .handlerInstallFailed:
            return .hotkeyRegistrationFailed
        }
    }
}

public protocol GlobalHotkeyRegistering {
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

    public func register(using settings: AppSettings) throws {
        let resolved = settings.validated()

        unregister()

        guard resolved.hotkeyEnabled else {
            isRegistered = false
            throw GlobalHotkeyServiceError.disabled
        }

        do {
            try registrar.installHandler { [weak self] id in
                guard let self else { return }
                guard id == self.hotkeyID else { return }
                self.onTrigger?()
            }

            try registrar.register(
                id: hotkeyID,
                keyCode: UInt32(resolved.hotkeyKeyCode),
                modifiers: Self.carbonModifiers(from: resolved.hotkeyModifiers)
            )
            isRegistered = true
            Logger.info("Registered global hotkey keyCode=\(resolved.hotkeyKeyCode)", category: .hotkey)
        } catch let error as GlobalHotkeyServiceError {
            isRegistered = false
            onRegistrationError?(error)
            Logger.warning("Global hotkey registration failed error=\(String(describing: error))", category: .hotkey)
            throw error
        } catch {
            let wrapped = GlobalHotkeyServiceError.registrationFailed(status: Int32(paramErr))
            isRegistered = false
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
        Logger.debug("Unregistered global hotkey", category: .hotkey)
    }
}

private extension GlobalHotkeyService {
    static func carbonModifiers(from cocoaRawValue: Int) -> UInt32 {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(cocoaRawValue))
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
