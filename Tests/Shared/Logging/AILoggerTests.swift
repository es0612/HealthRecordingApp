import Testing
import Foundation
@testable import HealthRecordingApp

@Suite("AILogger Tests")
struct AILoggerTests {
    
    @Test("AILogger should be created with default configuration")
    func testAILoggerCreation() async throws {
        // Given & When
        let logger = AILogger()
        
        // Then
        #expect(logger.logLevel == .info) // デフォルトレベル
        #expect(logger.isEnabled == true) // デフォルトで有効
        #expect(logger.shouldRedactPII == true) // デフォルトでPII削除
    }
    
    @Test("AILogger should be created with custom configuration")
    func testAILoggerCustomConfiguration() async throws {
        // Given
        let config = AILoggerConfiguration(
            logLevel: .debug,
            isEnabled: true,
            shouldRedactPII: false,
            maxLogSize: 1000
        )
        
        // When
        let logger = AILogger(configuration: config)
        
        // Then
        #expect(logger.logLevel == .debug)
        #expect(logger.isEnabled == true)
        #expect(logger.shouldRedactPII == false)
    }
    
    @Test("AILogger should log debug messages correctly")
    func testAILoggerDebugLogging() async throws {
        // Given
        let mockOutput = MockLogOutput()
        let config = AILoggerConfiguration(logLevel: .debug, isEnabled: true)
        let logger = AILogger(configuration: config, output: mockOutput)
        
        // When
        logger.debug("Debug message", context: ["key": "value"])
        
        // Then
        #expect(mockOutput.loggedMessages.count == 1)
        let loggedMessage = mockOutput.loggedMessages.first
        #expect(loggedMessage?.level == .debug)
        #expect(loggedMessage?.message == "Debug message")
        #expect(loggedMessage?.context?["key"] as? String == "value")
    }
    
    @Test("AILogger should log info messages correctly")
    func testAILoggerInfoLogging() async throws {
        // Given
        let mockOutput = MockLogOutput()
        let logger = AILogger(output: mockOutput)
        
        // When
        logger.info("Info message", context: ["operation": "test"])
        
        // Then
        #expect(mockOutput.loggedMessages.count == 1)
        let loggedMessage = mockOutput.loggedMessages.first
        #expect(loggedMessage?.level == .info)
        #expect(loggedMessage?.message == "Info message")
        #expect(loggedMessage?.context?["operation"] as? String == "test")
    }
    
    @Test("AILogger should log warning messages correctly")
    func testAILoggerWarningLogging() async throws {
        // Given
        let mockOutput = MockLogOutput()
        let logger = AILogger(output: mockOutput)
        
        // When
        logger.warning("Warning message", context: ["severity": "medium"])
        
        // Then
        #expect(mockOutput.loggedMessages.count == 1)
        let loggedMessage = mockOutput.loggedMessages.first
        #expect(loggedMessage?.level == .warning)
        #expect(loggedMessage?.message == "Warning message")
        #expect(loggedMessage?.context?["severity"] as? String == "medium")
    }
    
    @Test("AILogger should log error messages correctly")
    func testAILoggerErrorLogging() async throws {
        // Given
        let mockOutput = MockLogOutput()
        let logger = AILogger(output: mockOutput)
        let testError = NSError(domain: "TestDomain", code: 404, userInfo: [NSLocalizedDescriptionKey: "Not found"])
        
        // When
        logger.error(testError, context: ["action": "fetch_data"])
        
        // Then
        #expect(mockOutput.loggedMessages.count == 1)
        let loggedMessage = mockOutput.loggedMessages.first
        #expect(loggedMessage?.level == .error)
        #expect(loggedMessage?.message.contains("Not found") == true)
        #expect(loggedMessage?.context?["action"] as? String == "fetch_data")
        #expect(loggedMessage?.context?["error_code"] as? Int == 404)
    }
    
    @Test("AILogger should log user actions correctly")
    func testAILoggerUserActionLogging() async throws {
        // Given
        let mockOutput = MockLogOutput()
        let logger = AILogger(output: mockOutput)
        
        // When
        logger.logUserAction("sync_health_data", parameters: ["data_count": 15, "source": "healthkit"])
        
        // Then
        #expect(mockOutput.loggedMessages.count == 1)
        let loggedMessage = mockOutput.loggedMessages.first
        #expect(loggedMessage?.level == .info)
        #expect(loggedMessage?.message == "User action: sync_health_data")
        #expect(loggedMessage?.context?["action_type"] as? String == "user_interaction")
        #expect(loggedMessage?.context?["data_count"] as? Int == 15)
        #expect(loggedMessage?.context?["source"] as? String == "healthkit")
    }
    
    @Test("AILogger should log performance metrics correctly")
    func testAILoggerPerformanceLogging() async throws {
        // Given
        let mockOutput = MockLogOutput()
        let logger = AILogger(output: mockOutput)
        
        // When
        logger.logPerformance("data_sync", duration: 2.5, success: true)
        
        // Then
        #expect(mockOutput.loggedMessages.count == 1)
        let loggedMessage = mockOutput.loggedMessages.first
        #expect(loggedMessage?.level == .info)
        #expect(loggedMessage?.message == "Performance: data_sync")
        #expect(loggedMessage?.context?["operation"] as? String == "data_sync")
        #expect(loggedMessage?.context?["duration"] as? Double == 2.5)
        #expect(loggedMessage?.context?["success"] as? Bool == true)
    }
    
    @Test("AILogger should redact PII when enabled")
    func testAILoggerPIIRedaction() async throws {
        // Given
        let mockOutput = MockLogOutput()
        let config = AILoggerConfiguration(shouldRedactPII: true)
        let logger = AILogger(configuration: config, output: mockOutput)
        
        // When
        logger.info("User email: user@example.com", context: ["user_id": "12345", "email": "user@example.com"])
        
        // Then
        #expect(mockOutput.loggedMessages.count == 1)
        let loggedMessage = mockOutput.loggedMessages.first
        #expect(loggedMessage?.message.contains("[REDACTED]") == true)
        #expect(loggedMessage?.context?["user_id"] as? String == "[REDACTED]")
        #expect(loggedMessage?.context?["email"] as? String == "[REDACTED]")
    }
    
    @Test("AILogger should not log when disabled")  
    func testAILoggerDisabledLogging() async throws {
        // Given
        let mockOutput = MockLogOutput()
        let config = AILoggerConfiguration(isEnabled: false)
        let logger = AILogger(configuration: config, output: mockOutput)
        
        // When
        logger.info("This should not be logged")
        logger.debug("Debug message")
        logger.warning("Warning message")
        
        // Then
        #expect(mockOutput.loggedMessages.isEmpty)
    }
    
    @Test("AILogger should filter logs by level")
    func testAILoggerLevelFiltering() async throws {
        // Given
        let mockOutput = MockLogOutput()
        let config = AILoggerConfiguration(logLevel: .warning) // Only warning and error
        let logger = AILogger(configuration: config, output: mockOutput)
        
        // When
        logger.debug("Debug message") // Should be filtered
        logger.info("Info message")   // Should be filtered
        logger.warning("Warning message") // Should be logged
        logger.error(NSError(domain: "Test", code: 1), context: nil) // Should be logged
        
        // Then
        #expect(mockOutput.loggedMessages.count == 2)
        #expect(mockOutput.loggedMessages[0].level == .warning)
        #expect(mockOutput.loggedMessages[1].level == .error)
    }
}