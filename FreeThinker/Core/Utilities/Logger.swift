import Foundation
import os

/// Lightweight structured logging façade backed by the unified `os.Logger` system.
///
/// All log messages are emitted with `.public` privacy so they appear in Console.app
/// without redaction. Use the four static methods — ``debug(_:category:)``,
/// ``info(_:category:)``, ``warning(_:category:)``, and ``error(_:category:)`` — to
/// write messages tagged with a ``Category`` that maps to a subsystem category in the
/// unified logging system.
public enum Logger {
    private enum Level {
        case debug
        case info
        case warning
        case error
    }

    /// Identifies which subsystem of the app a log message originates from.
    ///
    /// Each case maps to an `os.Logger` category string used in Console.app and
    /// Instruments for filtering.
    public enum Category: String, Sendable {
        /// Messages from the remote AI service layer.
        case aiService = "ai-service"
        /// Messages from the on-device Foundation Models integration.
        case foundationModels = "foundation-models"
        /// Messages from the prompt composition step.
        case promptComposer = "prompt-composer"
        /// Messages from the AI response parser.
        case parser = "response-parser"
        /// Messages from the provocation orchestrator.
        case orchestrator = "orchestrator"
        /// Messages from the global hotkey registration and event handling subsystem.
        case hotkey = "hotkey"
        /// Messages from selected-text capture, including Accessibility and clipboard fallback.
        case textCapture = "text-capture"
        /// Messages from the menu bar status item and coordinator.
        case menuBar = "menu-bar"
        /// Messages from settings loading, validation, and persistence.
        case settings = "settings"
        /// Messages from the diagnostics recording and export subsystem.
        case diagnostics = "diagnostics"
        /// Messages from the onboarding flow.
        case onboarding = "onboarding"
    }

    private static let subsystem = "com.freethinker.app"

    /// Emits a debug-level message for the given category.
    ///
    /// The message closure is evaluated lazily; it is not called when the log level
    /// would suppress this entry.
    ///
    /// - Parameters:
    ///   - message: An autoclosure producing the log message string.
    ///   - category: The subsystem category to tag this message with.
    public static func debug(_ message: @autoclosure () -> String, category: Category) {
        emit(message(), category: category, level: .debug)
    }

    /// Emits an info-level message for the given category.
    ///
    /// - Parameters:
    ///   - message: An autoclosure producing the log message string.
    ///   - category: The subsystem category to tag this message with.
    public static func info(_ message: @autoclosure () -> String, category: Category) {
        emit(message(), category: category, level: .info)
    }

    /// Emits a warning-level message for the given category.
    ///
    /// - Parameters:
    ///   - message: An autoclosure producing the log message string.
    ///   - category: The subsystem category to tag this message with.
    public static func warning(_ message: @autoclosure () -> String, category: Category) {
        emit(message(), category: category, level: .warning)
    }

    /// Emits an error-level message for the given category.
    ///
    /// - Parameters:
    ///   - message: An autoclosure producing the log message string.
    ///   - category: The subsystem category to tag this message with.
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
