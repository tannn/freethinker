import Foundation

public protocol UserNotificationServiceProtocol: Sendable {
    func post(message: String) async
}

public actor LoggerUserNotificationService: UserNotificationServiceProtocol {
    public init() {}

    public func post(message: String) async {
        Logger.info("Notification: \(message)", category: .orchestrator)
    }
}
