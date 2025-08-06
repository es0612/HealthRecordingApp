import Testing
import Foundation
@testable import HealthRecordingApp

@Suite("HealthDataValidationService Tests")
struct HealthDataValidationServiceTests {
    
    // MARK: - Test Properties
    
    private let validationService: HealthDataValidationServiceProtocol
    private let mockLogger: AILoggerProtocol
    
    init() {
        self.mockLogger = MockAILogger()
        self.validationService = HealthDataValidationService(logger: mockLogger)
    }
    
    // MARK: - Validation Service Basic Tests
    
    @Test("Test service initialization")
    func testServiceInitialization() {
        #expect(validationService != nil)
    }
    
    // MARK: - Weight Validation Tests
    
    @Test("Test weight validation - valid values")
    func testWeightValidation_ValidValues() {
        let validWeights = [50.0, 70.5, 100.0, 120.0]
        
        for weight in validWeights {
            let result = validationService.validateValue(weight, for: .weight)
            #expect(result == .success, "Weight \(weight) should be valid")
        }
    }
    
    @Test("Test weight validation - boundary values")
    func testWeightValidation_BoundaryValues() {
        // Test minimum boundary
        let minValidWeight = 10.0
        let belowMinWeight = 9.9
        
        #expect(validationService.validateValue(minValidWeight, for: .weight) == .success)
        
        let belowMinResult = validationService.validateValue(belowMinWeight, for: .weight)
        if case .failure(let errors) = belowMinResult {
            let hasValueTooLowError = errors.contains { error in
                if case .valueTooLow = error { return true }
                return false
            }
            #expect(hasValueTooLowError, "Should have valueTooLow error for weight \(belowMinWeight)")
        } else {
            Issue.record("Expected failure for weight below minimum")
        }
        
        // Test maximum boundary
        let maxValidWeight = 300.0
        let aboveMaxWeight = 300.1
        
        #expect(validationService.validateValue(maxValidWeight, for: .weight) == .success)
        
        let aboveMaxResult = validationService.validateValue(aboveMaxWeight, for: .weight)
        if case .failure(let errors) = aboveMaxResult {
            let hasValueTooHighError = errors.contains { error in
                if case .valueTooHigh = error { return true }
                return false
            }
            #expect(hasValueTooHighError, "Should have valueTooHigh error for weight \(aboveMaxWeight)")
        } else {
            Issue.record("Expected failure for weight above maximum")
        }
    }
    
    @Test("Test weight validation - suspicious values")
    func testWeightValidation_SuspiciousValues() {
        let suspiciousWeights = [35.0, 250.0] // Very low and very high but within bounds
        
        for weight in suspiciousWeights {
            let result = validationService.validateValue(weight, for: .weight)
            if case .failure(let errors) = result {
                let hasSuspiciousValueError = errors.contains { error in
                    if case .suspiciousValue = error { return true }
                    return false
                }
                #expect(hasSuspiciousValueError, "Weight \(weight) should trigger suspicious value warning")
            }
        }
    }
    
    @Test("Test weight validation - precision check")
    func testWeightValidation_PrecisionCheck() {
        // Valid precision (1 decimal place)
        let validPrecisionWeight = 70.5
        #expect(validationService.validateValue(validPrecisionWeight, for: .weight) == .success)
        
        // Invalid precision (2 decimal places)
        let invalidPrecisionWeight = 70.55
        let result = validationService.validateValue(invalidPrecisionWeight, for: .weight)
        if case .failure(let errors) = result {
            let hasInvalidPrecisionError = errors.contains { error in
                if case .invalidPrecision = error { return true }
                return false
            }
            #expect(hasInvalidPrecisionError, "Should have invalidPrecision error for weight \(invalidPrecisionWeight)")
        } else {
            Issue.record("Expected precision validation failure")
        }
    }
    
    // MARK: - Steps Validation Tests
    
    @Test("Test steps validation - valid values")
    func testStepsValidation_ValidValues() {
        let validSteps = [0.0, 5000.0, 10000.0, 15000.0, 50000.0]
        
        for steps in validSteps {
            let result = validationService.validateValue(steps, for: .steps)
            #expect(result == .success, "Steps \(steps) should be valid")
        }
    }
    
    @Test("Test steps validation - boundary values")
    func testStepsValidation_BoundaryValues() {
        // Test minimum boundary (0 is valid)
        #expect(validationService.validateValue(0.0, for: .steps) == .success)
        
        // Test negative value (invalid)
        let negativeSteps = -1.0
        let negativeResult = validationService.validateValue(negativeSteps, for: .steps)
        if case .failure(let errors) = negativeResult {
            let hasValueTooLowError = errors.contains { error in
                if case .valueTooLow = error { return true }
                return false
            }
            #expect(hasValueTooLowError, "Should have valueTooLow error for negative steps")
        } else {
            Issue.record("Expected failure for negative steps")
        }
        
        // Test maximum boundary
        let maxValidSteps = 100000.0
        let aboveMaxSteps = 100001.0
        
        #expect(validationService.validateValue(maxValidSteps, for: .steps) == .success)
        
        let aboveMaxResult = validationService.validateValue(aboveMaxSteps, for: .steps)
        if case .failure(let errors) = aboveMaxResult {
            let hasValueTooHighError = errors.contains { error in
                if case .valueTooHigh = error { return true }
                return false
            }
            #expect(hasValueTooHighError, "Should have valueTooHigh error for steps above maximum")
        } else {
            Issue.record("Expected failure for steps above maximum")
        }
    }
    
    @Test("Test steps validation - suspicious values")
    func testStepsValidation_SuspiciousValues() {
        let suspiciousSteps = [75000.0, 90000.0] // Very high step counts
        
        for steps in suspiciousSteps {
            let result = validationService.validateValue(steps, for: .steps)
            if case .failure(let errors) = result {
                let hasSuspiciousValueError = errors.contains { error in
                    if case .suspiciousValue = error { return true }
                    return false
                }
                #expect(hasSuspiciousValueError, "Steps \(steps) should trigger suspicious value warning")
            }
        }
    }
    
    // MARK: - Calories Validation Tests
    
    @Test("Test calories validation - valid values") 
    func testCaloriesValidation_ValidValues() {
        let validCalories = [1200.0, 1800.0, 2500.0, 3000.0]
        
        for calories in validCalories {
            let result = validationService.validateValue(calories, for: .calories)
            #expect(result == .success, "Calories \(calories) should be valid")
        }
    }
    
    @Test("Test calories validation - boundary values")
    func testCaloriesValidation_BoundaryValues() {
        // Test minimum boundary (0 is valid)
        #expect(validationService.validateValue(0.0, for: .calories) == .success)
        
        // Test negative value (invalid)
        let negativeCalories = -1.0
        let negativeResult = validationService.validateValue(negativeCalories, for: .calories)
        if case .failure(let errors) = negativeResult {
            let hasValueTooLowError = errors.contains { error in
                if case .valueTooLow = error { return true }
                return false
            }
            #expect(hasValueTooLowError, "Should have valueTooLow error for negative calories")
        } else {
            Issue.record("Expected failure for negative calories")
        }
        
        // Test maximum boundary
        let maxValidCalories = 10000.0
        let aboveMaxCalories = 10001.0
        
        #expect(validationService.validateValue(maxValidCalories, for: .calories) == .success)
        
        let aboveMaxResult = validationService.validateValue(aboveMaxCalories, for: .calories)
        if case .failure(let errors) = aboveMaxResult {
            let hasValueTooHighError = errors.contains { error in
                if case .valueTooHigh = error { return true }
                return false
            }
            #expect(hasValueTooHighError, "Should have valueTooHigh error for calories above maximum")
        } else {
            Issue.record("Expected failure for calories above maximum")
        }
    }
    
    @Test("Test calories validation - suspicious values")
    func testCaloriesValidation_SuspiciousValues() {
        let suspiciousCalories = [8000.0, 9500.0] // Very high calorie counts
        
        for calories in suspiciousCalories {
            let result = validationService.validateValue(calories, for: .calories)
            if case .failure(let errors) = result {
                let hasSuspiciousValueError = errors.contains { error in
                    if case .suspiciousValue = error { return true }
                    return false
                }
                #expect(hasSuspiciousValueError, "Calories \(calories) should trigger suspicious value warning")
            }
        }
    }
    
    // MARK: - Heart Rate Validation Tests
    
    @Test("Test heart rate validation - valid values")
    func testHeartRateValidation_ValidValues() {
        let validHeartRates = [60.0, 70.0, 100.0, 120.0, 180.0]
        
        for heartRate in validHeartRates {
            let result = validationService.validateValue(heartRate, for: .heartRate)
            #expect(result == .success, "Heart rate \(heartRate) should be valid")
        }
    }
    
    @Test("Test heart rate validation - boundary values")
    func testHeartRateValidation_BoundaryValues() {
        // Test minimum boundary
        let minValidHeartRate = 30.0
        let belowMinHeartRate = 29.0
        
        #expect(validationService.validateValue(minValidHeartRate, for: .heartRate) == .success)
        
        let belowMinResult = validationService.validateValue(belowMinHeartRate, for: .heartRate)
        if case .failure(let errors) = belowMinResult {
            let hasValueTooLowError = errors.contains { error in
                if case .valueTooLow = error { return true }
                return false
            }
            #expect(hasValueTooLowError, "Should have valueTooLow error for heart rate below minimum")
        } else {
            Issue.record("Expected failure for heart rate below minimum")
        }
        
        // Test maximum boundary
        let maxValidHeartRate = 200.0
        let aboveMaxHeartRate = 201.0
        
        #expect(validationService.validateValue(maxValidHeartRate, for: .heartRate) == .success)
        
        let aboveMaxResult = validationService.validateValue(aboveMaxHeartRate, for: .heartRate)
        if case .failure(let errors) = aboveMaxResult {
            let hasValueTooHighError = errors.contains { error in
                if case .valueTooHigh = error { return true }
                return false
            }
            #expect(hasValueTooHighError, "Should have valueTooHigh error for heart rate above maximum")
        } else {
            Issue.record("Expected failure for heart rate above maximum")
        }
    }
    
    @Test("Test heart rate validation - suspicious values")
    func testHeartRateValidation_SuspiciousValues() {
        let suspiciousHeartRates = [35.0, 40.0, 190.0, 195.0] // Very low and high rates
        
        for heartRate in suspiciousHeartRates {
            let result = validationService.validateValue(heartRate, for: .heartRate)
            if case .failure(let errors) = result {
                let hasSuspiciousValueError = errors.contains { error in
                    if case .suspiciousValue = error { return true }
                    return false
                }
                #expect(hasSuspiciousValueError, "Heart rate \(heartRate) should trigger suspicious value warning")
            }
        }
    }
    
    // MARK: - Blood Glucose Validation Tests
    
    @Test("Test blood glucose validation - valid values")
    func testBloodGlucoseValidation_ValidValues() {
        let validBloodGlucose = [80.0, 100.0, 120.0, 140.0]
        
        for glucose in validBloodGlucose {
            let result = validationService.validateValue(glucose, for: .bloodGlucose)
            #expect(result == .success, "Blood glucose \(glucose) should be valid")
        }
    }
    
    @Test("Test blood glucose validation - boundary values")
    func testBloodGlucoseValidation_BoundaryValues() {
        // Test minimum boundary
        let minValidGlucose = 20.0
        let belowMinGlucose = 19.0
        
        #expect(validationService.validateValue(minValidGlucose, for: .bloodGlucose) == .success)
        
        let belowMinResult = validationService.validateValue(belowMinGlucose, for: .bloodGlucose)
        if case .failure(let errors) = belowMinResult {
            let hasValueTooLowError = errors.contains { error in
                if case .valueTooLow = error { return true }
                return false
            }
            #expect(hasValueTooLowError, "Should have valueTooLow error for glucose below minimum")
        } else {
            Issue.record("Expected failure for glucose below minimum")
        }
        
        // Test maximum boundary
        let maxValidGlucose = 600.0
        let aboveMaxGlucose = 601.0
        
        #expect(validationService.validateValue(maxValidGlucose, for: .bloodGlucose) == .success)
        
        let aboveMaxResult = validationService.validateValue(aboveMaxGlucose, for: .bloodGlucose)
        if case .failure(let errors) = aboveMaxResult {
            let hasValueTooHighError = errors.contains { error in
                if case .valueTooHigh = error { return true }
                return false
            }
            #expect(hasValueTooHighError, "Should have valueTooHigh error for glucose above maximum")
        } else {
            Issue.record("Expected failure for glucose above maximum")
        }
    }
    
    @Test("Test blood glucose validation - suspicious values")
    func testBloodGlucoseValidation_SuspiciousValues() {
        let suspiciousGlucose = [30.0, 50.0, 400.0, 500.0] // Very low and high glucose levels
        
        for glucose in suspiciousGlucose {
            let result = validationService.validateValue(glucose, for: .bloodGlucose)
            if case .failure(let errors) = result {
                let hasSuspiciousValueError = errors.contains { error in
                    if case .suspiciousValue = error { return true }
                    return false
                }
                #expect(hasSuspiciousValueError, "Blood glucose \(glucose) should trigger suspicious value warning")
            }
        }
    }
    
    // MARK: - Data Integrity Protection Tests
    
    @Test("Test duplicate detection - exact match")
    func testDuplicateDetection_ExactMatch() {
        let timestamp = Date()
        let existingRecord = HealthRecord(type: .weight, value: 70.0, unit: "kg")
        existingRecord.timestamp = timestamp
        
        let newData = HealthDataInput(
            type: .weight,
            value: 70.0,
            unit: "kg", 
            timestamp: timestamp,
            source: .manual
        )
        
        let result = validationService.detectPotentialDuplicate(newData, against: [existingRecord])
        
        #expect(result.isDuplicate, "Should detect exact duplicate")
        #expect(result.confidence > 0.8, "Confidence should be high for exact match")
        #expect(result.recommendation == .reject, "Should recommend rejecting exact duplicate")
        #expect(result.existingRecords.count == 1, "Should find one existing record")
    }
    
    @Test("Test duplicate detection - similar values within threshold")
    func testDuplicateDetection_SimilarValues() {
        let timestamp = Date()
        let existingRecord = HealthRecord(type: .weight, value: 70.0, unit: "kg")
        existingRecord.timestamp = timestamp
        
        // Similar value within 5% threshold (70.0 * 0.05 = 3.5, so 73.0 is within threshold)
        let newData = HealthDataInput(
            type: .weight,
            value: 72.0, // 2.86% difference
            unit: "kg",
            timestamp: timestamp,
            source: .manual
        )
        
        let result = validationService.detectPotentialDuplicate(newData, against: [existingRecord])
        
        #expect(result.isDuplicate, "Should detect similar duplicate")
        #expect(result.confidence > 0.5, "Confidence should be medium for similar values")
        #expect(result.existingRecords.count == 1, "Should find one existing record")
    }
    
    @Test("Test duplicate detection - different time windows")
    func testDuplicateDetection_TimeWindows() {
        let baseTime = Date()
        let existingRecord = HealthRecord(type: .weight, value: 70.0, unit: "kg")
        existingRecord.timestamp = baseTime
        
        // Test within time window (3 minutes apart, threshold is 5 minutes)
        let newDataWithinWindow = HealthDataInput(
            type: .weight,
            value: 70.0,
            unit: "kg",
            timestamp: baseTime.addingTimeInterval(180), // 3 minutes later
            source: .manual
        )
        
        let resultWithin = validationService.detectPotentialDuplicate(newDataWithinWindow, against: [existingRecord])
        #expect(resultWithin.isDuplicate, "Should detect duplicate within time window")
        
        // Test outside time window (10 minutes apart, beyond 5 minute threshold)
        let newDataOutsideWindow = HealthDataInput(
            type: .weight,
            value: 70.0,
            unit: "kg",
            timestamp: baseTime.addingTimeInterval(600), // 10 minutes later
            source: .manual
        )
        
        let resultOutside = validationService.detectPotentialDuplicate(newDataOutsideWindow, against: [existingRecord])
        #expect(!resultOutside.isDuplicate, "Should not detect duplicate outside time window")
        #expect(resultOutside.recommendation == .proceed, "Should recommend proceeding for non-duplicate")
    }
    
    @Test("Test duplicate detection - different data types")
    func testDuplicateDetection_DifferentDataTypes() {
        let timestamp = Date()
        let existingWeightRecord = HealthRecord(type: .weight, value: 70.0, unit: "kg")
        existingWeightRecord.timestamp = timestamp
        
        // Different data type with same value should not be considered duplicate
        let newStepsData = HealthDataInput(
            type: .steps,
            value: 70.0, // Same value but different type
            unit: "歩",
            timestamp: timestamp,
            source: .manual
        )
        
        let result = validationService.detectPotentialDuplicate(newStepsData, against: [existingWeightRecord])
        
        #expect(!result.isDuplicate, "Should not detect duplicate for different data types")
        #expect(result.recommendation == .proceed, "Should recommend proceeding for different data types")
    }
    
    @Test("Test rapid weight change detection")
    func testRapidWeightChangeDetection() {
        let baseTime = Date()
        
        // Create previous weight record
        let previousRecord = HealthRecord(type: .weight, value: 70.0, unit: "kg")
        previousRecord.timestamp = Calendar.current.date(byAdding: .day, value: -2, to: baseTime)!
        
        let validationContext = ValidationContext(
            lastWeightRecord: previousRecord,
            recentRecords: [previousRecord],
            userProfile: nil
        )
        
        // Test reasonable weight change (1kg in 2 days = 0.5kg/day, which is at threshold)
        let reasonableChangeData = HealthDataInput(
            type: .weight,
            value: 69.0, // 1kg change
            unit: "kg",
            timestamp: baseTime,
            source: .manual
        )
        
        let reasonableResult = validationService.validateDataIntegrity(reasonableChangeData, context: validationContext)
        #expect(reasonableResult == .success, "Reasonable weight change should be valid")
        
        // Test unreasonable weight change (5kg in 2 days = 2.5kg/day, above 0.5kg/day threshold)
        let unreasonableChangeData = HealthDataInput(
            type: .weight,
            value: 65.0, // 5kg change
            unit: "kg",
            timestamp: baseTime,
            source: .manual
        )
        
        let unreasonableResult = validationService.validateDataIntegrity(unreasonableChangeData, context: validationContext)
        if case .failure(let errors) = unreasonableResult {
            let hasSuspiciousValueError = errors.contains { error in
                if case .suspiciousValue = error { return true }
                return false
            }
            #expect(hasSuspiciousValueError, "Should detect suspicious rapid weight change")
        } else {
            Issue.record("Expected validation failure for rapid weight change")
        }
    }
    
    @Test("Test anomaly detection for weight")
    func testAnomalyDetection_Weight() {
        // Test extremely low weight (below 30kg threshold)
        let lowWeightData = HealthDataInput(
            type: .weight,
            value: 25.0,
            unit: "kg",
            timestamp: Date(),
            source: .manual
        )
        
        let lowWeightResult = validationService.validateDataIntegrity(lowWeightData, context: nil)
        if case .failure(let errors) = lowWeightResult {
            let hasSuspiciousValueError = errors.contains { error in
                if case .suspiciousValue = error { return true }
                return false
            }
            #expect(hasSuspiciousValueError, "Should detect anomalous low weight")
        } else {
            Issue.record("Expected anomaly detection for extremely low weight")
        }
        
        // Test extremely high weight (above 250kg threshold)
        let highWeightData = HealthDataInput(
            type: .weight,
            value: 300.0,
            unit: "kg",
            timestamp: Date(),
            source: .manual
        )
        
        let highWeightResult = validationService.validateDataIntegrity(highWeightData, context: nil)
        if case .failure(let errors) = highWeightResult {
            let hasSuspiciousValueError = errors.contains { error in
                if case .suspiciousValue = error { return true }
                return false
            }
            #expect(hasSuspiciousValueError, "Should detect anomalous high weight")
        } else {
            Issue.record("Expected anomaly detection for extremely high weight")
        }
    }
    
    @Test("Test comprehensive health data validation")
    func testComprehensiveHealthDataValidation() {
        let validData = HealthDataInput(
            type: .weight,
            value: 70.5,
            unit: "kg",
            timestamp: Date(),
            source: .manual
        )
        
        let result = validationService.validateHealthData(validData)
        #expect(result == .success, "Valid health data should pass comprehensive validation")
    }
    
    @Test("Test comprehensive health data validation with multiple errors")
    func testComprehensiveHealthDataValidation_MultipleErrors() {
        let futureTime = Date().addingTimeInterval(3600) // 1 hour in future
        
        let invalidData = HealthDataInput(
            type: .weight,
            value: 5.0, // Too low
            unit: "lbs", // Different unit but valid
            timestamp: futureTime, // Future timestamp
            source: .manual
        )
        
        let result = validationService.validateHealthData(invalidData)
        if case .failure(let errors) = result {
            #expect(errors.count >= 2, "Should have multiple validation errors")
            
            let hasValueTooLowError = errors.contains { error in
                if case .valueTooLow = error { return true }
                return false
            }
            let hasFutureTimestampError = errors.contains { error in
                if case .timestampInFuture = error { return true }
                return false
            }
            
            #expect(hasValueTooLowError, "Should have value too low error")
            #expect(hasFutureTimestampError, "Should have future timestamp error")
        } else {
            Issue.record("Expected validation failure for invalid health data")
        }
    }
    
    @Test("Test timestamp validation - future dates")
    func testTimestampValidation_FutureDates() {
        let futureTime = Date().addingTimeInterval(600) // 10 minutes in future
        
        let result = validationService.validateTimestamp(futureTime)
        if case .failure(let errors) = result {
            let hasFutureTimestampError = errors.contains { error in
                if case .timestampInFuture = error { return true }
                return false
            }
            #expect(hasFutureTimestampError, "Should detect future timestamp")
        } else {
            Issue.record("Expected failure for future timestamp")
        }
    }
    
    @Test("Test timestamp validation - too old dates")
    func testTimestampValidation_TooOldDates() {
        let oldTime = Calendar.current.date(byAdding: .year, value: -6, to: Date())!
        
        let result = validationService.validateTimestamp(oldTime)
        if case .failure(let errors) = result {
            let hasTooOldTimestampError = errors.contains { error in
                if case .timestampTooOld = error { return true }
                return false
            }
            #expect(hasTooOldTimestampError, "Should detect too old timestamp")
        } else {
            Issue.record("Expected failure for too old timestamp")
        }
    }
    
    @Test("Test unit validation")
    func testUnitValidation() {
        // Test valid unit
        let validResult = validationService.validateUnit("kg", for: .weight)
        #expect(validResult == .success, "Valid unit should pass validation")
        
        // Test invalid unit
        let invalidResult = validationService.validateUnit("invalid_unit", for: .weight)
        if case .failure(let errors) = invalidResult {
            let hasInvalidUnitError = errors.contains { error in
                if case .invalidUnit = error { return true }
                return false
            }
            #expect(hasInvalidUnitError, "Should detect invalid unit")
        } else {
            Issue.record("Expected failure for invalid unit")
        }
    }
    
    @Test("Test constraints retrieval")
    func testConstraintsRetrieval() {
        let weightConstraints = validationService.getConstraints(for: .weight)
        #expect(weightConstraints.minimumValue == 10.0, "Weight minimum should be 10.0")
        #expect(weightConstraints.maximumValue == 300.0, "Weight maximum should be 300.0")
        #expect(weightConstraints.unit == "kg", "Weight unit should be kg")
        #expect(weightConstraints.allowedUnits.contains("kg"), "Should allow kg unit")
        #expect(weightConstraints.allowedPrecisions.contains(1), "Should allow 1 decimal precision")
        
        let stepsConstraints = validationService.getConstraints(for: .steps)
        #expect(stepsConstraints.minimumValue == 0, "Steps minimum should be 0")
        #expect(stepsConstraints.maximumValue == 100000, "Steps maximum should be 100000")
        #expect(stepsConstraints.allowedPrecisions.contains(0), "Steps should only allow integer precision")
    }
}

// MARK: - Test Helper Extensions

extension HealthDataInput {
    static func createTestData(
        type: HealthDataType = .weight,
        value: Double = 70.0,
        unit: String? = nil,
        timestamp: Date = Date(),
        source: DataSource = .manual
    ) -> HealthDataInput {
        return HealthDataInput(
            type: type,
            value: value,
            unit: unit ?? type.unit,
            timestamp: timestamp,
            source: source
        )
    }
}

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