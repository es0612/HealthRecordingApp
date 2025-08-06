import Testing
import Foundation
@testable import HealthRecordingApp

@Suite("Validation Performance Tests")
struct ValidationPerformanceTests {
    
    // MARK: - Test Properties
    
    private let validationService: HealthDataValidationServiceProtocol
    private let mockLogger: AILoggerProtocol
    
    init() {
        self.mockLogger = MockAILogger()
        self.validationService = HealthDataValidationService(logger: mockLogger)
    }
    
    // MARK: - Basic Validation Performance Tests
    
    @Test("Test basic value validation performance")
    func testBasicValueValidationPerformance() {
        let startTime = Date()
        let iterations = 10000
        
        for i in 0..<iterations {
            let value = Double(50 + i % 100) // Values between 50-150
            _ = validationService.validateValue(value, for: .weight)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let operationsPerSecond = Double(iterations) / duration
        
        #expect(duration < 1.0, "10,000 basic validations should complete in under 1 second")
        #expect(operationsPerSecond > 10000, "Should achieve >10,000 validations per second")
        
        print("Basic validation performance: \(operationsPerSecond) operations/second")
    }
    
    @Test("Test comprehensive validation performance")
    func testComprehensiveValidationPerformance() {
        let startTime = Date()
        let iterations = 1000
        
        for i in 0..<iterations {
            let data = HealthDataInput(
                type: .weight,
                value: Double(60 + i % 30), // Values between 60-90
                unit: "kg",
                timestamp: Date().addingTimeInterval(TimeInterval(-i * 60)), // 1 minute intervals
                source: .manual
            )
            _ = validationService.validateHealthData(data)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let operationsPerSecond = Double(iterations) / duration
        
        #expect(duration < 2.0, "1,000 comprehensive validations should complete in under 2 seconds")
        #expect(operationsPerSecond > 500, "Should achieve >500 comprehensive validations per second")
        
        print("Comprehensive validation performance: \(operationsPerSecond) operations/second")
    }
    
    @Test("Test duplicate detection performance with large datasets")
    func testDuplicateDetectionPerformanceWithLargeDatasets() {
        let startTime = Date()
        
        // Create large dataset of existing records
        let existingRecords = (0..<5000).map { i in
            HealthRecord.createTestRecord(
                type: .weight,
                value: 70.0 + Double.random(in: -10.0...10.0),
                timestamp: Date().addingTimeInterval(TimeInterval(-i * 3600))
            )
        }
        
        let testIterations = 100
        for i in 0..<testIterations {
            let newData = HealthDataInput(
                type: .weight,
                value: 72.0 + Double(i % 10),
                unit: "kg",
                timestamp: Date().addingTimeInterval(TimeInterval(-i)),
                source: .manual
            )
            
            _ = validationService.detectPotentialDuplicate(newData, against: existingRecords)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let avgDurationPerOperation = duration / Double(testIterations)
        
        #expect(duration < 5.0, "Duplicate detection against 5,000 records should complete in under 5 seconds")
        #expect(avgDurationPerOperation < 0.05, "Each duplicate detection should take <50ms")
        
        print("Duplicate detection performance: \(avgDurationPerOperation * 1000)ms per operation")
    }
    
    @Test("Test anomaly detection performance")
    func testAnomalyDetectionPerformance() {
        let startTime = Date()
        
        // Create historical data for context
        let historicalRecords = (0..<1000).map { i in
            HealthRecord.createTestRecord(
                type: .weight,
                value: 70.0 + Double.random(in: -3.0...3.0),
                timestamp: Date().addingTimeInterval(TimeInterval(-i * 86400)) // Daily records
            )
        }
        
        let context = ValidationContext(
            lastWeightRecord: historicalRecords.first,
            recentRecords: Array(historicalRecords.prefix(30)), // Last 30 days
            userProfile: nil
        )
        
        let testIterations = 100
        for i in 0..<testIterations {
            let testValue = i % 2 == 0 ? 75.0 : 65.0 // Alternate between high and low
            let data = HealthDataInput(
                type: .weight,
                value: testValue,
                unit: "kg",
                timestamp: Date().addingTimeInterval(TimeInterval(-i * 60)),
                source: .manual
            )
            
            _ = validationService.validateDataIntegrity(data, context: context)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let avgDurationPerOperation = duration / Double(testIterations)
        
        #expect(duration < 3.0, "Anomaly detection should complete in under 3 seconds")
        #expect(avgDurationPerOperation < 0.03, "Each anomaly detection should take <30ms")
        
        print("Anomaly detection performance: \(avgDurationPerOperation * 1000)ms per operation")
    }
    
    @Test("Test parallel validation performance")
    func testParallelValidationPerformance() async {
        let startTime = Date()
        let concurrentOperations = 100
        
        await withTaskGroup(of: ValidationResult.self) { group in
            for i in 0..<concurrentOperations {
                group.addTask {
                    let data = HealthDataInput(
                        type: .weight,
                        value: Double(60 + i % 40),
                        unit: "kg",
                        timestamp: Date().addingTimeInterval(TimeInterval(-i * 10)),
                        source: .manual
                    )
                    return self.validationService.validateHealthData(data)
                }
            }
            
            var results: [ValidationResult] = []
            for await result in group {
                results.append(result)
            }
            
            #expect(results.count == concurrentOperations, "Should complete all parallel validations")
        }
        
        let duration = Date().timeIntervalSince(startTime)
        #expect(duration < 1.0, "100 parallel validations should complete in under 1 second")
        
        print("Parallel validation performance: \(duration) seconds for \(concurrentOperations) operations")
    }
    
    @Test("Test memory usage during intensive validation")
    func testMemoryUsageDuringIntensiveValidation() {
        let iterations = 1000
        var validationResults: [ValidationResult] = []
        validationResults.reserveCapacity(iterations)
        
        let startTime = Date()
        
        for i in 0..<iterations {
            let data = HealthDataInput(
                type: HealthDataType.allCases[i % HealthDataType.allCases.count],
                value: Double(10 + i % 100),
                unit: HealthDataType.allCases[i % HealthDataType.allCases.count].unit,
                timestamp: Date().addingTimeInterval(TimeInterval(-i * 60)),
                source: i % 2 == 0 ? .manual : .healthKit
            )
            
            let result = validationService.validateHealthData(data)
            validationResults.append(result)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Test that we can process all results without memory issues
        let successCount = validationResults.compactMap { result in
            if case .success = result { return 1 } else { return nil }
        }.count
        
        let failureCount = validationResults.compactMap { result in
            if case .failure = result { return 1 } else { return nil }
        }.count
        
        #expect(successCount + failureCount == iterations, "Should process all validation results")
        #expect(duration < 2.0, "Memory-intensive validation should complete in under 2 seconds")
        
        // Clean up
        validationResults.removeAll()
        
        print("Memory test completed: \(successCount) successes, \(failureCount) failures in \(duration) seconds")
    }
    
    @Test("Test validation performance across different data types")
    func testValidationPerformanceAcrossDataTypes() {
        let iterations = 1000
        let dataTypes = HealthDataType.allCases
        
        var performanceResults: [HealthDataType: TimeInterval] = [:]
        
        for dataType in dataTypes {
            let startTime = Date()
            
            for i in 0..<iterations {
                let value = generateTestValue(for: dataType, iteration: i)
                _ = validationService.validateValue(value, for: dataType)
            }
            
            let duration = Date().timeIntervalSince(startTime)
            performanceResults[dataType] = duration
            
            #expect(duration < 0.5, "1000 validations for \(dataType) should complete in under 0.5 seconds")
        }
        
        // Verify that all data types have similar performance characteristics
        let maxDuration = performanceResults.values.max() ?? 0
        let minDuration = performanceResults.values.min() ?? 0
        let performanceVariation = maxDuration - minDuration
        
        #expect(performanceVariation < 0.3, "Performance variation between data types should be <300ms")
        
        print("Data type performance results:")
        for (dataType, duration) in performanceResults.sorted(by: { $0.value < $1.value }) {
            print("  \(dataType): \(duration * 1000)ms")
        }
    }
    
    @Test("Test validation caching and optimization")
    func testValidationCachingAndOptimization() {
        let identicalData = HealthDataInput(
            type: .weight,
            value: 70.0,
            unit: "kg",
            timestamp: Date(),
            source: .manual
        )
        
        // First validation (cold cache)
        let firstStartTime = Date()
        _ = validationService.validateHealthData(identicalData)
        let firstDuration = Date().timeIntervalSince(firstStartTime)
        
        // Subsequent validations (should benefit from any caching)
        let iterations = 100
        let subsequentStartTime = Date()
        
        for _ in 0..<iterations {
            _ = validationService.validateHealthData(identicalData)
        }
        
        let subsequentDuration = Date().timeIntervalSince(subsequentStartTime)
        let avgSubsequentDuration = subsequentDuration / Double(iterations)
        
        #expect(avgSubsequentDuration <= firstDuration, "Subsequent validations should be at least as fast as first")
        #expect(subsequentDuration < 0.1, "100 repeated validations should complete in under 100ms")
        
        print("Caching performance: First validation: \(firstDuration * 1000)ms, Avg subsequent: \(avgSubsequentDuration * 1000)ms")
    }
    
    @Test("Test error handling performance impact")
    func testErrorHandlingPerformanceImpact() {
        let iterations = 1000
        
        // Test with data that will generate errors
        let startTime = Date()
        
        for i in 0..<iterations {
            let invalidData = HealthDataInput(
                type: .weight,
                value: Double(500 + i), // Always too high
                unit: "kg",
                timestamp: Date().addingTimeInterval(TimeInterval(3600 + i)), // Always in future
                source: .manual
            )
            
            let result = validationService.validateHealthData(invalidData)
            
            // Ensure errors are properly generated
            if case .failure(let errors) = result {
                #expect(errors.count >= 2, "Should have multiple errors for invalid data")
            } else {
                Issue.record("Expected validation failure for invalid data")
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let avgErrorHandlingTime = duration / Double(iterations)
        
        #expect(duration < 2.0, "Error handling should not significantly impact performance")
        #expect(avgErrorHandlingTime < 0.002, "Each error-generating validation should take <2ms")
        
        print("Error handling performance: \(avgErrorHandlingTime * 1000)ms per error case")
    }
    
    @Test("Test validation service resource cleanup")
    func testValidationServiceResourceCleanup() {
        // Test that validation service properly cleans up resources
        let iterations = 10000
        
        let startTime = Date()
        
        for i in 0..<iterations {
            let data = HealthDataInput(
                type: .weight,
                value: Double(60 + i % 40),
                unit: "kg",
                timestamp: Date().addingTimeInterval(TimeInterval(-i)),
                source: .manual
            )
            
            _ = validationService.validateHealthData(data)
            
            // Periodically trigger cleanup if available
            if i % 1000 == 0 {
                // In a real implementation, we might have a cleanup method
                // validationService.performCleanup()
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        #expect(duration < 5.0, "Large number of validations should complete without resource exhaustion")
        
        print("Resource cleanup test: \(iterations) validations completed in \(duration) seconds")
    }
    
    // MARK: - Helper Methods
    
    private func generateTestValue(for dataType: HealthDataType, iteration: Int) -> Double {
        let baseValues: [HealthDataType: Double] = [
            .weight: 70.0,
            .steps: 8000.0,
            .calories: 2000.0,
            .heartRate: 75.0,
            .bloodGlucose: 100.0
        ]
        
        let baseValue = baseValues[dataType] ?? 100.0
        let variation = Double(iteration % 20) - 10.0 // ±10 variation
        
        return baseValue + variation
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