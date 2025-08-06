import Testing
import Foundation
@testable import HealthRecordingApp

@Suite("ValidationErrorFramework Tests")
struct ValidationErrorFrameworkTests {
    
    // MARK: - Test Properties
    
    private let mockLogger: AILoggerProtocol
    
    init() {
        self.mockLogger = MockAILogger()
    }
    
    // MARK: - DataValidationError Tests
    
    @Test("Test DataValidationError error messages")
    func testDataValidationErrorMessages() {
        let tooHighError = DataValidationError.valueTooHigh(
            value: 350.0,
            maximum: 300.0,
            dataType: .weight,
            suggestion: "体重は300kg以下で入力してください"
        )
        
        let errorMessage = tooHighError.userFriendlyMessage
        #expect(errorMessage.contains("350.0"), "Error message should contain the actual value")
        #expect(errorMessage.contains("300.0"), "Error message should contain the maximum value")
        #expect(errorMessage.contains("体重"), "Error message should contain data type")
        
        let tooLowError = DataValidationError.valueTooLow(
            value: 5.0,
            minimum: 10.0,
            dataType: .weight,
            suggestion: "体重は10kg以上で入力してください"
        )
        
        let lowErrorMessage = tooLowError.userFriendlyMessage
        #expect(lowErrorMessage.contains("5.0"), "Error message should contain the actual value")
        #expect(lowErrorMessage.contains("10.0"), "Error message should contain the minimum value")
    }
    
    @Test("Test DataValidationError localization")
    func testDataValidationErrorLocalization() {
        let suspiciousError = DataValidationError.suspiciousValue(
            value: 25.0,
            dataType: .weight,
            reason: "unusually_low",
            suggestion: "この値は通常より低いです。正しいですか？"
        )
        
        let message = suspiciousError.userFriendlyMessage
        #expect(message.contains("25.0"), "Should contain the suspicious value")
        #expect(message.contains("通常より低い"), "Should contain localized reason")
        #expect(!message.contains("unusually_low"), "Should not contain technical reason code")
    }
    
    @Test("Test DataValidationError severity levels")
    func testDataValidationErrorSeverity() {
        let criticalError = DataValidationError.valueTooHigh(
            value: 400.0,
            maximum: 300.0,
            dataType: .weight,
            suggestion: "値が高すぎます"
        )
        #expect(criticalError.severity == .error, "Value too high should be error severity")
        
        let warningError = DataValidationError.suspiciousValue(
            value: 250.0,
            dataType: .weight,
            reason: "high_but_valid",
            suggestion: "値が高めです"
        )
        #expect(warningError.severity == .warning, "Suspicious value should be warning severity")
        
        let infoError = DataValidationError.invalidPrecision(
            value: 70.55,
            expectedPrecision: 1,
            dataType: .weight,
            suggestion: "小数点以下1桁で入力してください"
        )
        #expect(infoError.severity == .info, "Invalid precision should be info severity")
    }
    
    // MARK: - TimestampValidationError Tests
    
    @Test("Test TimestampValidationError messages")
    func testTimestampValidationErrorMessages() {
        let futureDate = Date().addingTimeInterval(3600)
        let futureError = TimestampValidationError.timestampInFuture(
            timestamp: futureDate,
            reason: .futureDate,
            context: ValidationErrorContext(additionalData: ["max_future_minutes": 5])
        )
        
        let message = futureError.userFriendlyMessage
        #expect(message.contains("未来の日時"), "Should contain future date message")
        #expect(message.contains("現在時刻以前"), "Should contain constraint message")
    }
    
    @Test("Test TimestampValidationError context handling")
    func testTimestampValidationErrorContext() {
        let oldDate = Calendar.current.date(byAdding: .year, value: -6, to: Date())!
        let context = ValidationErrorContext(additionalData: [
            "max_age_years": 5,
            "provided_age_years": 6,
            "user_action": "manual_entry"
        ])
        
        let oldError = TimestampValidationError.timestampTooOld(
            timestamp: oldDate,
            reason: .exceedsMaximumAge,
            context: context
        )
        
        let message = oldError.userFriendlyMessage
        #expect(message.contains("5年以内"), "Should reference max age from context")
        #expect(!message.contains("user_action"), "Should not expose technical context keys")
    }
    
    // MARK: - DataIntegrityError Tests
    
    @Test("Test DataIntegrityError duplicate detection messages")
    func testDataIntegrityErrorDuplicateMessages() {
        let existingRecord = HealthRecord.createTestRecord(
            type: .weight,
            value: 70.0,
            timestamp: Date().addingTimeInterval(-300) // 5 minutes ago
        )
        
        let duplicateError = DataIntegrityError.duplicateDetected(
            newValue: 70.0,
            existingRecords: [existingRecord],
            confidence: 0.95,
            timeWindow: 300,
            dataType: .weight,
            suggestion: "同じ値が最近記録されています"
        )
        
        let message = duplicateError.userFriendlyMessage
        #expect(message.contains("70.0"), "Should contain the duplicate value")
        #expect(message.contains("5分前"), "Should contain relative time")
        #expect(message.contains("同じ値"), "Should contain duplicate explanation")
    }
    
    @Test("Test DataIntegrityError anomaly detection messages")
    func testDataIntegrityErrorAnomalyMessages() {
        let anomalyError = DataIntegrityError.anomalyDetected(
            value: 25.0,
            dataType: .weight,
            reason: .outlier(standardDeviations: 3.5),
            context: ValidationErrorContext(additionalData: [
                "user_avg": 70.0,
                "std_dev": 12.5,
                "z_score": 3.5
            ]),
            suggestion: "この値は通常のパターンと大きく異なります"
        )
        
        let message = anomalyError.userFriendlyMessage
        #expect(message.contains("25.0"), "Should contain the anomalous value")
        #expect(message.contains("通常のパターン"), "Should explain the anomaly")
        #expect(!message.contains("z_score"), "Should not expose technical statistics")
    }
    
    // MARK: - EnhancedValidationError Tests
    
    @Test("Test EnhancedValidationError user guidance")
    func testEnhancedValidationErrorUserGuidance() {
        let enhancedError = EnhancedValidationError.valueOutOfRange(
            value: 350.0,
            validRange: 10.0...300.0,
            dataType: .weight
        )
        
        #expect(enhancedError.isRecoverable, "Value out of range should be recoverable")
        #expect(enhancedError.priority == .high, "Should have high priority")
        
        let actionableSteps = enhancedError.actionableSteps
        #expect(actionableSteps.count >= 2, "Should provide multiple actionable steps")
        #expect(actionableSteps.contains { $0.contains("10") && $0.contains("300") }, 
                "Should contain valid range information")
    }
    
    @Test("Test EnhancedValidationError recovery suggestions")
    func testEnhancedValidationErrorRecoverySuggestions() {
        let timestampError = EnhancedValidationError.invalidTimestamp(
            timestamp: Date().addingTimeInterval(3600),
            reason: .futureDate
        )
        
        let suggestions = timestampError.recoverySuggestions
        #expect(suggestions.count >= 2, "Should provide multiple recovery suggestions")
        #expect(suggestions.contains { $0.contains("現在時刻") }, 
                "Should suggest using current time")
        #expect(suggestions.contains { $0.contains("日時を確認") }, 
                "Should suggest checking the date/time")
    }
    
    // MARK: - ValidationErrorContext Tests
    
    @Test("Test ValidationErrorContext creation and access")
    func testValidationErrorContextCreation() {
        let context = ValidationErrorContext(additionalData: [
            "user_profile": "test_user",
            "recent_values": [68.5, 69.0, 70.2],
            "validation_timestamp": Date().ISO8601Format()
        ])
        
        #expect(context.additionalData["user_profile"] as? String == "test_user",
                "Should store and retrieve string values")
        
        let recentValues = context.additionalData["recent_values"] as? [Double]
        #expect(recentValues?.count == 3, "Should store and retrieve array values")
        #expect(recentValues?[1] == 69.0, "Should preserve array element values")
    }
    
    @Test("Test ValidationErrorContext debug descriptions")
    func testValidationErrorContextDebugDescription() {
        let context = ValidationErrorContext(additionalData: [
            "operation": "manual_input",
            "data_source": "user_entry",
            "validation_rules_applied": ["range_check", "duplicate_check", "anomaly_check"]
        ])
        
        let debugDescription = context.debugDescription
        #expect(debugDescription.contains("manual_input"), "Debug description should contain operation")
        #expect(debugDescription.contains("validation_rules_applied"), "Should contain applied rules")
        #expect(debugDescription.contains("3 validation rules"), "Should summarize array contents")
    }
    
    // MARK: - UserFriendlyError Protocol Tests
    
    @Test("Test UserFriendlyError protocol conformance")
    func testUserFriendlyErrorProtocolConformance() {
        let errors: [any UserFriendlyError] = [
            DataValidationError.valueTooHigh(value: 400, maximum: 300, dataType: .weight, suggestion: "Too high"),
            TimestampValidationError.timestampInFuture(timestamp: Date().addingTimeInterval(3600), reason: .futureDate, context: nil),
            DataIntegrityError.duplicateDetected(newValue: 70, existingRecords: [], confidence: 0.9, timeWindow: 300, dataType: .weight, suggestion: "Duplicate"),
            EnhancedValidationError.valueOutOfRange(value: 400, validRange: 10...300, dataType: .weight)
        ]
        
        for error in errors {
            #expect(!error.userFriendlyMessage.isEmpty, "Every error should have a user-friendly message")
            #expect(!error.technicalDetails.isEmpty, "Every error should have technical details")
            
            // Check that user-friendly messages don't contain technical jargon
            let message = error.userFriendlyMessage.lowercased()
            #expect(!message.contains("null"), "User message should not contain null")
            #expect(!message.contains("error"), "User message should avoid technical terms")
            #expect(!message.contains("exception"), "User message should avoid technical terms")
        }
    }
    
    // MARK: - Error Severity and Priority Tests
    
    @Test("Test error severity classification")
    func testErrorSeverityClassification() {
        // Critical errors that block data entry
        let criticalErrors: [any UserFriendlyError] = [
            DataValidationError.valueTooHigh(value: 400, maximum: 300, dataType: .weight, suggestion: "Too high"),
            DataValidationError.valueTooLow(value: 5, minimum: 10, dataType: .weight, suggestion: "Too low"),
            TimestampValidationError.timestampInFuture(timestamp: Date().addingTimeInterval(3600), reason: .futureDate, context: nil)
        ]
        
        for error in criticalErrors {
            #expect(error.severity == .error, "Critical validation issues should have error severity")
        }
        
        // Warning errors that allow data entry with confirmation
        let warningErrors: [any UserFriendlyError] = [
            DataValidationError.suspiciousValue(value: 250, dataType: .weight, reason: "high_but_valid", suggestion: "High value"),
            DataIntegrityError.anomalyDetected(value: 25, dataType: .weight, reason: .outlier(standardDeviations: 2.5), context: nil, suggestion: "Unusual")
        ]
        
        for error in warningErrors {
            #expect(error.severity == .warning, "Suspicious values should have warning severity")
        }
        
        // Info errors that provide guidance
        let infoErrors: [any UserFriendlyError] = [
            DataValidationError.invalidPrecision(value: 70.55, expectedPrecision: 1, dataType: .weight, suggestion: "Round to 1 decimal")
        ]
        
        for error in infoErrors {
            #expect(error.severity == .info, "Formatting issues should have info severity")
        }
    }
    
    // MARK: - Error Localization Tests
    
    @Test("Test error message localization consistency")
    func testErrorMessageLocalizationConsistency() {
        let weightErrors = [
            DataValidationError.valueTooHigh(value: 400, maximum: 300, dataType: .weight, suggestion: "高すぎます"),
            DataValidationError.valueTooLow(value: 5, minimum: 10, dataType: .weight, suggestion: "低すぎます")
        ]
        
        for error in weightErrors {
            let message = error.userFriendlyMessage
            #expect(message.contains("体重") || message.contains("weight"), "Weight errors should mention weight")
            #expect(!message.contains("valueTooHigh") && !message.contains("valueTooLow"), 
                    "Should not contain English technical terms")
        }
        
        let stepsErrors = [
            DataValidationError.valueTooHigh(value: 200000, maximum: 100000, dataType: .steps, suggestion: "歩数が多すぎます")
        ]
        
        for error in stepsErrors {
            let message = error.userFriendlyMessage
            #expect(message.contains("歩数") || message.contains("steps"), "Steps errors should mention steps")
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Test error message generation performance")
    func testErrorMessageGenerationPerformance() {
        let startTime = Date()
        
        // Generate many error messages to test performance
        for i in 0..<1000 {
            let error = DataValidationError.valueTooHigh(
                value: Double(i + 400),
                maximum: 300.0,
                dataType: .weight,
                suggestion: "Value too high"
            )
            _ = error.userFriendlyMessage
        }
        
        let duration = Date().timeIntervalSince(startTime)
        #expect(duration < 1.0, "Generating 1000 error messages should take less than 1 second")
    }
}

// MARK: - Test Helper Extensions

extension HealthRecord {
    static func createTestRecord(
        type: HealthDataType = .weight,
        value: Double = 70.0,
        unit: String? = nil,
        timestamp: Date = Date(),
        source: DataSource = .manual
    ) -> HealthRecord {
        let record = HealthRecord(type: type, value: value, unit: unit ?? type.unit, source: source)
        record.timestamp = timestamp
        return record
    }
}

// MARK: - Mock AILogger for Testing

private class MockAILogger: AILoggerProtocol {
    var debugMessages: [String] = []
    var infoMessages: [String] = []
    var warningMessages: [String] = []
    var errorMessages: [String] = []
    var userActions: [String] = []
    var performanceEntries: [(String, TimeInterval, Bool)] = []
    
    func debug(_ message: String, context: [String : Any]?) {
        debugMessages.append(message)
    }
    
    func info(_ message: String, context: [String : Any]?) {
        infoMessages.append(message)
    }
    
    func warning(_ message: String, context: [String : Any]?) {
        warningMessages.append(message)
    }
    
    func error(_ error: Error, context: [String : Any]?) {
        errorMessages.append(error.localizedDescription)
    }
    
    func logUserAction(_ action: String, parameters: [String : Any]?) {
        userActions.append(action)
    }
    
    func logPerformance(_ operation: String, duration: TimeInterval, success: Bool) {
        performanceEntries.append((operation, duration, success))
    }
}