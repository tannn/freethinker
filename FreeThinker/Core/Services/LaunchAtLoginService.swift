import Foundation

#if canImport(ServiceManagement)
import ServiceManagement
#endif

public protocol LaunchAtLoginControlling: Sendable {
    func isEnabled() -> Bool
    func setEnabled(_ isEnabled: Bool) throws
}

public enum LaunchAtLoginError: Error, Equatable, Sendable {
    case unsupported
    case failed(String)
}

public final class LaunchAtLoginService: LaunchAtLoginControlling, @unchecked Sendable {
    public init() {}

    public func isEnabled() -> Bool {
        #if canImport(ServiceManagement)
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
        #else
        return false
        #endif
    }

    public func setEnabled(_ isEnabled: Bool) throws {
        #if canImport(ServiceManagement)
        if #available(macOS 13.0, *) {
            do {
                if isEnabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                return
            } catch {
                throw LaunchAtLoginError.failed(error.localizedDescription)
            }
        }
        throw LaunchAtLoginError.unsupported
        #else
        throw LaunchAtLoginError.unsupported
        #endif
    }
}
