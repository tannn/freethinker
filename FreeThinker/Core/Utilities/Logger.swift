import Foundation

public enum Logger {
    public enum Category: String, Sendable {
        case aiService = "ai-service"
        case foundationModels = "foundation-models"
        case promptComposer = "prompt-composer"
        case parser = "response-parser"
        case orchestrator = "orchestrator"
        case hotkey = "hotkey"
        case textCapture = "text-capture"
        case menuBar = "menu-bar"
        case settings = "settings"
    }

    private static let subsystem = "com.freethinker.app"

    public static func debug(_ message: @autoclosure () -> String, category: Category) {
        emit(level: "DEBUG", message: message(), category: category)
    }

    public static func info(_ message: @autoclosure () -> String, category: Category) {
        emit(level: "INFO", message: message(), category: category)
    }

    public static func warning(_ message: @autoclosure () -> String, category: Category) {
        emit(level: "WARN", message: message(), category: category)
    }

    public static func error(_ message: @autoclosure () -> String, category: Category) {
        emit(level: "ERROR", message: message(), category: category)
    }

    private static func emit(level: String, message: String, category: Category) {
        if ProcessInfo.processInfo.environment["FREETHINKER_DEBUG"] == "1" {
            print("[\(subsystem)] [\(category.rawValue)] [\(level)] \(message)")
        }
    }
}
