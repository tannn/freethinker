import Foundation
import os

public enum Logger {
    private enum Level {
        case debug
        case info
        case warning
        case error
    }

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
        case diagnostics = "diagnostics"
        case onboarding = "onboarding"
    }

    private static let subsystem = "com.freethinker.app"
    public static func debug(_ message: @autoclosure () -> String, category: Category) {
        emit(message(), category: category, level: .debug)
    }

    public static func info(_ message: @autoclosure () -> String, category: Category) {
        emit(message(), category: category, level: .info)
    }

    public static func warning(_ message: @autoclosure () -> String, category: Category) {
        emit(message(), category: category, level: .warning)
    }

    public static func error(_ message: @autoclosure () -> String, category: Category) {
        emit(message(), category: category, level: .error)
    }

    private static func logger(for category: Category) -> os.Logger {
        os.Logger(subsystem: subsystem, category: category.rawValue)
    }

    private static func emit(_ message: String, category: Category, level: Level) {
        let target = logger(for: category)
        switch level {
        case .debug:
            target.debug("\(message, privacy: .public)")
        case .info:
            target.info("\(message, privacy: .public)")
        case .warning:
            target.warning("\(message, privacy: .public)")
        case .error:
            target.error("\(message, privacy: .public)")
        }
    }
}
