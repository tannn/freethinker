import Foundation
import os

/// A thin, zero-dependency wrapper around `os.Logger` that routes messages to
/// subsystem-scoped categories.
///
/// All log messages are emitted at `privacy: .public` so they appear in the
/// Console app without requiring a profile. Call the static level methods
/// (`debug`, `info`, `warning`, `error`) and pass a ``Category`` to route the
/// message to the correct `os.Logger` channel.
public enum Logger {
    private enum Level {
        case debug
        case info
        case warning
        case error
    }

    /// Identifies the subsystem area that produced a log message.
    public enum Category: String, Sendable {
        /// Messages from the AI network or model service layer.
        case aiService = "ai-service"
        /// Messages from the on-device Foundation Models integration.
        case foundationModels = "foundation-models"
        /// Messages from the prompt composition pipeline.
        case promptComposer = "prompt-composer"
        /// Messages from the AI response parser.
        case parser = "response-parser"
        /// Messages from the provocation orchestrator.
        case orchestrator = "orchestrator"
        /// Messages from the global hotkey registration and event handling.
        case hotkey = "hotkey"
        /// Messages from the selected-text and clipboard capture service.
        case textCapture = "text-capture"
        /// Messages from the menu bar coordinator and status item lifecycle.
        case menuBar = "menu-bar"
        /// Messages from settings loading, validation, and persistence.
        case settings = "settings"
        /// Messages from the diagnostics logger and export pipeline.
        case diagnostics = "diagnostics"
        /// Messages from the onboarding flow.
        case onboarding = "onboarding"
    }

    private static let subsystem = "com.freethinker.app"

    /// Emits a debug-level message for the given category.
    ///
    /// - Parameters:
    ///   - message: The message string, evaluated lazily.
    ///   - category: The subsystem area producing the message.
    public static func debug(_ message: @autoclosure () -> String, category: Category) {
        emit(message(), category: category, level: .debug)
    }

    /// Emits an info-level message for the given category.
    ///
    /// - Parameters:
    ///   - message: The message string, evaluated lazily.
    ///   - category: The subsystem area producing the message.
    public static func info(_ message: @autoclosure () -> String, category: Category) {
        emit(message(), category: category, level: .info)
    }

    /// Emits a warning-level message for the given category.
    ///
    /// - Parameters:
    ///   - message: The message string, evaluated lazily.
    ///   - category: The subsystem area producing the message.
    public static func warning(_ message: @autoclosure () -> String, category: Category) {
        emit(message(), category: category, level: .warning)
    }

    /// Emits an error-level message for the given category.
    ///
    /// - Parameters:
    ///   - message: The message string, evaluated lazily.
    ///   - category: The subsystem area producing the message.
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
