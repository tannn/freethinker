import Foundation
import ServiceManagement

enum LaunchAtLoginStatus: Equatable, Sendable {
    case enabled
    case disabled
    case requiresApproval
}

enum LaunchAtLoginServiceError: Error, Equatable, LocalizedError, Sendable {
    case statusQueryFailed(details: String)
    case enableFailed(details: String)
    case disableFailed(details: String)
    case stateMismatch(expectedEnabled: Bool, actual: LaunchAtLoginStatus)

    var errorDescription: String? {
        switch self {
        case let .statusQueryFailed(details):
            return "Unable to read launch-at-login status: \(details)"
        case let .enableFailed(details):
            return "Unable to enable launch at login: \(details)"
        case let .disableFailed(details):
            return "Unable to disable launch at login: \(details)"
        case let .stateMismatch(expectedEnabled, actual):
            return "Launch-at-login state mismatch. Expected enabled=\(expectedEnabled), got \(actual)."
        }
    }
}

protocol LaunchAtLoginService: Sendable {
    func status() async -> Result<LaunchAtLoginStatus, LaunchAtLoginServiceError>
    func setEnabled(_ enabled: Bool) async -> Result<Void, LaunchAtLoginServiceError>
}

protocol LaunchAtLoginClient: Sendable {
    func currentStatus() async throws -> LaunchAtLoginStatus
    func register() async throws
    func unregister() async throws
}

struct SMAppServiceClient: LaunchAtLoginClient {
    func currentStatus() async throws -> LaunchAtLoginStatus {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notRegistered:
            return .disabled
        case .notFound:
            return .disabled
        @unknown default:
            return .disabled
        }
    }

    func register() async throws {
        try SMAppService.mainApp.register()
    }

    func unregister() async throws {
        try await SMAppService.mainApp.unregister()
    }
}

actor DefaultLaunchAtLoginService: LaunchAtLoginService {
    private let client: any LaunchAtLoginClient

    init(client: any LaunchAtLoginClient = SMAppServiceClient()) {
        self.client = client
    }

    func status() async -> Result<LaunchAtLoginStatus, LaunchAtLoginServiceError> {
        do {
            return .success(try await client.currentStatus())
        } catch {
            return .failure(.statusQueryFailed(details: error.localizedDescription))
        }
    }

    func setEnabled(_ enabled: Bool) async -> Result<Void, LaunchAtLoginServiceError> {
        let initialStatus: LaunchAtLoginStatus

        do {
            initialStatus = try await client.currentStatus()
        } catch {
            return .failure(.statusQueryFailed(details: error.localizedDescription))
        }

        if enabled {
            if initialStatus == .enabled {
                return .success(())
            }

            do {
                try await client.register()
            } catch {
                if await isServiceStateConsistent(with: enabled) {
                    return .success(())
                }
                return .failure(map(error: error, enabling: enabled))
            }
        } else {
            if initialStatus == .disabled {
                return .success(())
            }

            do {
                try await client.unregister()
            } catch {
                if await isServiceStateConsistent(with: enabled) {
                    return .success(())
                }
                return .failure(map(error: error, enabling: enabled))
            }
        }

        do {
            let finalStatus = try await client.currentStatus()
            let finalIsEnabled = (finalStatus == .enabled || finalStatus == .requiresApproval)
            if finalIsEnabled != enabled {
                return .failure(.stateMismatch(expectedEnabled: enabled, actual: finalStatus))
            }
            return .success(())
        } catch {
            return .failure(.statusQueryFailed(details: error.localizedDescription))
        }
    }

    private func map(error: Error, enabling: Bool) -> LaunchAtLoginServiceError {
        let nsError = error as NSError
        let details = [
            nsError.localizedDescription,
            nsError.localizedFailureReason,
            "(\(nsError.domain):\(nsError.code))"
        ]
        .compactMap { $0 }
        .joined(separator: " ")

        if enabling {
            return .enableFailed(details: details)
        }
        return .disableFailed(details: details)
    }

    private func isServiceStateConsistent(with enabled: Bool) async -> Bool {
        guard case let .success(status) = await status() else {
            return false
        }

        let actualEnabled = (status == .enabled || status == .requiresApproval)
        return actualEnabled == enabled
    }
}
