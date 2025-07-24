import Foundation
import os.log

/// AI連携対応のログ機能を提供するメインクラス
final class AILogger: AILoggerProtocol {
    private let configuration: AILoggerConfiguration
    private let output: AILogOutputProtocol
    private let queue: DispatchQueue
    
    var logLevel: AILogLevel {
        return configuration.logLevel
    }
    
    var isEnabled: Bool {
        return configuration.isEnabled
    }
    
    var shouldRedactPII: Bool {
        return configuration.shouldRedactPII
    }
    
    init(configuration: AILoggerConfiguration = AILoggerConfiguration(), output: AILogOutputProtocol? = nil) {
        self.configuration = configuration
        self.output = output ?? ConsoleLogOutput()
        self.queue = DispatchQueue(label: "com.healthrecordingapp.ailogger", qos: .utility)
    }
    
    func debug(_ message: String, context: [String: Any]? = nil) {
        log(level: .debug, message: message, context: context)
    }
    
    func info(_ message: String, context: [String: Any]? = nil) {
        log(level: .info, message: message, context: context)
    }
    
    func warning(_ message: String, context: [String: Any]? = nil) {
        log(level: .warning, message: message, context: context)
    }
    
    func error(_ error: Error, context: [String: Any]? = nil) {
        var errorContext = context ?? [:]
        errorContext["error_domain"] = (error as NSError).domain
        errorContext["error_code"] = (error as NSError).code
        errorContext["error_description"] = error.localizedDescription
        
        log(level: .error, message: error.localizedDescription, context: errorContext)
    }
    
    func logUserAction(_ action: String, parameters: [String: Any]? = nil) {
        var actionContext: [String: Any] = [
            "action_type": "user_interaction",
            "action": action
        ]
        
        if let parameters = parameters {
            for (key, value) in parameters {
                actionContext[key] = value
            }
        }
        
        log(level: .info, message: "User action: \(action)", context: actionContext)
    }
    
    func logPerformance(_ operation: String, duration: TimeInterval, success: Bool) {
        let performanceContext: [String: Any] = [
            "operation": operation,
            "duration": duration,
            "success": success,
            "performance_type": "operation_timing"
        ]
        
        log(level: .info, message: "Performance: \(operation)", context: performanceContext)
    }
    
    private func log(level: AILogLevel, message: String, context: [String: Any]?) {
        guard configuration.isEnabled else { return }
        guard level.rawValue >= configuration.logLevel.rawValue else { return }
        
        let processedMessage = self.shouldRedactPII ? self.redactPII(from: message) : message
        let processedContext = self.shouldRedactPII ? self.redactPII(from: context) : context
        
        let logMessage = AILogMessage(
            level: level,
            message: processedMessage,
            context: processedContext,
            timestamp: Date(),
            source: self.extractSourceInfo()
        )
        
        // テスト環境か確認 - MockLogOutputの場合は同期実行
        if output is MockLogOutput {
            // テスト実行中は同期実行
            self.output.write(logMessage)
        } else {
            // プロダクションでは非同期実行
            queue.async { [weak self] in
                self?.output.write(logMessage)
            }
        }
    }
    
    private func extractSourceInfo() -> AILogSource {
        // デバッグビルドでのみソース情報を含める
        #if DEBUG
        if let callStackSymbols = Thread.callStackSymbols.dropFirst(4).first {
            // シンプルな実装 - 実際にはより詳細な解析が可能
            return AILogSource(
                file: "Unknown",
                function: "Unknown",
                line: 0
            )
        }
        #endif
        
        return AILogSource(file: "Unknown", function: "Unknown", line: 0)
    }
    
    private func redactPII(from message: String) -> String {
        var redactedMessage = message
        
        // Email パターンをredact
        let emailPattern = #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"#
        redactedMessage = redactedMessage.replacingOccurrences(
            of: emailPattern,
            with: "[REDACTED]",
            options: .regularExpression
        )
        
        return redactedMessage
    }
    
    private func redactPII(from context: [String: Any]?) -> [String: Any]? {
        guard let context = context else { return nil }
        
        var redactedContext: [String: Any] = [:]
        let piiKeys = ["user_id", "email", "phone", "name", "address"]
        
        for (key, value) in context {
            if piiKeys.contains(key.lowercased()) {
                redactedContext[key] = "[REDACTED]"
            } else {
                redactedContext[key] = value
            }
        }
        
        return redactedContext
    }
}

/// AILoggerの設定
struct AILoggerConfiguration {
    let logLevel: AILogLevel
    let isEnabled: Bool
    let shouldRedactPII: Bool
    let maxLogSize: Int
    
    init(
        logLevel: AILogLevel = .info,
        isEnabled: Bool = true,
        shouldRedactPII: Bool = true,
        maxLogSize: Int = 10000
    ) {
        self.logLevel = logLevel
        self.isEnabled = isEnabled
        self.shouldRedactPII = shouldRedactPII
        self.maxLogSize = maxLogSize
    }
}

/// ログレベルの定義
enum AILogLevel: Int, CaseIterable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    
    var description: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        }
    }
}

/// ログメッセージの構造
struct AILogMessage {
    let level: AILogLevel
    let message: String
    let context: [String: Any]?
    let timestamp: Date
    let source: AILogSource
}

/// ソース情報
struct AILogSource {
    let file: String
    let function: String
    let line: Int
}

/// AILoggerプロトコル
protocol AILoggerProtocol {
    var logLevel: AILogLevel { get }
    var isEnabled: Bool { get }
    var shouldRedactPII: Bool { get }
    
    func debug(_ message: String, context: [String: Any]?)
    func info(_ message: String, context: [String: Any]?)
    func warning(_ message: String, context: [String: Any]?)
    func error(_ error: Error, context: [String: Any]?)
    func logUserAction(_ action: String, parameters: [String: Any]?)
    func logPerformance(_ operation: String, duration: TimeInterval, success: Bool)
}

/// ログ出力プロトコル
protocol AILogOutputProtocol {
    func write(_ message: AILogMessage)
    func flush()
}

/// コンソール出力実装
final class ConsoleLogOutput: AILogOutputProtocol {
    private let logger = Logger(subsystem: "com.healthrecordingapp", category: "ailogger")
    
    func write(_ message: AILogMessage) {
        let timestamp = ISO8601DateFormatter().string(from: message.timestamp)
        let contextString = formatContext(message.context)
        let logText = "[\(timestamp)] [\(message.level.description)] \(message.message)\(contextString)"
        
        switch message.level {
        case .debug:
            logger.debug("\(logText)")
        case .info:
            logger.info("\(logText)")
        case .warning:
            logger.warning("\(logText)")
        case .error:
            logger.error("\(logText)")
        }
    }
    
    func flush() {
        // os.log automatically handles flushing
    }
    
    private func formatContext(_ context: [String: Any]?) -> String {
        guard let context = context, !context.isEmpty else { return "" }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: context, options: [.prettyPrinted])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return " Context: \(jsonString)"
            }
        } catch {
            return " Context: [serialization_error]"
        }
        
        return ""
    }
}

/// テスト用のMockログ出力
final class MockLogOutput: AILogOutputProtocol {
    var loggedMessages: [AILogMessage] = []
    
    func write(_ message: AILogMessage) {
        loggedMessages.append(message)
    }
    
    func flush() {
        // Mock implementation - do nothing
    }
}