import Foundation

public enum PermissionStatus: Equatable, Sendable {
    case authorized
    case denied(canPrompt: Bool, nextPromptDate: Date?)

    public var isAuthorized: Bool {
        if case .authorized = self {
            return true
        }
        return false
    }

    public var canPrompt: Bool {
        switch self {
        case .authorized:
            return false
        case let .denied(canPrompt, _):
            return canPrompt
        }
    }
}
