import OSLog

enum LogLevel {
    case debug
    case info
    case notice
    case error
    case fault
}

enum LogCategory: String {
    case lifecycle
    case menuBar
    case services
    case settings
    case general
}

struct FTLogger {
    private let logger: Logger

    init(_ category: LogCategory) {
        logger = Logger(subsystem: "com.freethinker.app", category: category.rawValue)
    }

    func log(_ message: String, level: LogLevel = .info) {
        switch level {
        case .debug:
            logger.debug("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .notice:
            logger.notice("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        case .fault:
            logger.fault("\(message, privacy: .public)")
        }
    }

    func debug(_ message: String) { log(message, level: .debug) }
    func info(_ message: String) { log(message, level: .info) }
    func notice(_ message: String) { log(message, level: .notice) }
    func error(_ message: String) { log(message, level: .error) }
    func fault(_ message: String) { log(message, level: .fault) }
}

enum AppLog {
    static let lifecycle = FTLogger(.lifecycle)
    static let menuBar = FTLogger(.menuBar)
    static let services = FTLogger(.services)
    static let settings = FTLogger(.settings)
    static let general = FTLogger(.general)
}
