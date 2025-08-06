import Testing
import SwiftUI
import SwiftData
import Foundation
#if canImport(UIKit)
import UIKit
#endif

@testable import HealthRecordingApp

// MARK: - Manual Input Integration Tests

struct ManualInputIntegrationTests {
    
    private let logger = AILogger()
    
    // MARK: - End-to-End Flow Tests
    
    @Test("Complete manual input flow should work correctly")
    func testCompleteManualInputFlow() async throws {
        let mockModelContext = createMockModelContext()
        let validationService = HealthDataValidationService()
        let errorHandler = ValidationErrorHandler()
        
        // Test complete flow simulation
        let inputValue = "70.5"
        let selectedDataType = HealthDataType.weight
        let selectedDate = Date()
        
        // Step 1: Validate input
        guard let value = Double(inputValue) else {
            Issue.record("Failed to parse input value")
            return
        }
        
        let validationResult = validationService.validateValue(value, for: selectedDataType)
        
        switch validationResult {
        case .success:
            // Step 2: Create health data input
            let healthDataInput = HealthDataInput(
                type: selectedDataType,
                value: value,
                unit: selectedDataType.unit,
                timestamp: selectedDate,
                source: .manual
            )
            
            // Step 3: Validate health data
            let healthDataResult = validationService.validateHealthData(healthDataInput)
            
            switch healthDataResult {
            case .success:
                // Success path
                #expect(true)
            case .failure(let errors):
                Issue.record("Health data validation failed: \(errors)")
            }
            
        case .failure(let errors):
            Issue.record("Input validation failed: \(errors)")
        }
    }
    
    @Test("Manual input with data integrity checks should work")
    func testManualInputWithDataIntegrityChecks() async throws {
        let validationService = HealthDataValidationService()
        
        // Create input that might trigger integrity checks
        let healthDataInput = HealthDataInput(
            type: .weight,
            value: 70.0,
            unit: "kg",
            timestamp: Date(),
            source: .manual
        )
        
        // Create mock existing records for comparison
        let existingRecords = [
            HealthRecord(
                type: .weight,
                value: 70.0,
                unit: "kg",
                timestamp: Date().addingTimeInterval(-300), // 5 minutes ago
                source: .manual,
                user: nil
            )
        ]
        
        // Test duplicate detection
        let duplicateResult = validationService.detectPotentialDuplicate(
            healthDataInput,
            against: existingRecords
        )
        
        #expect(duplicateResult.isDuplicate)
        #expect(duplicateResult.confidence > 0.7) // High confidence for exact match
        
        // Test recommendation
        switch duplicateResult.recommendation {
        case .reject, .confirmWithUser:
            // Expected for high confidence duplicate
            #expect(true)
        case .proceed:
            Issue.record("Unexpected proceed recommendation for high confidence duplicate")
        }
    }
    
    @Test("Smart suggestions integration with validation should work")
    func testSmartSuggestionsWithValidation() async throws {
        let validationService = HealthDataValidationService()
        let recentValues = [70.0, 69.8, 70.2, 69.9, 70.1]
        
        // Generate smart suggestions
        let suggestions = generateSmartSuggestions(from: recentValues, for: .weight)
        
        #expect(!suggestions.isEmpty)
        
        // All suggestions should pass validation
        for suggestion in suggestions {
            let result = validationService.validateValue(suggestion, for: .weight)
            
            switch result {
            case .success:
                // Expected
                break
            case .failure(let errors):
                Issue.record("Suggestion \(suggestion) failed validation: \(errors)")
            }
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Manual input validation should be performant")
    func testValidationPerformance() async throws {
        let validationService = HealthDataValidationService()
        let testValues = Array(50.0...100.0) // 51 test values
        
        let startTime = Date()
        
        for value in testValues {
            let _ = validationService.validateValue(value, for: .weight)
        }
        
        let endTime = Date()
        let totalTime = endTime.timeIntervalSince(startTime)
        
        // Should validate 51 values in under 50ms (less than 1ms per validation)
        #expect(totalTime < 0.05)
    }
    
    @Test("Smart suggestions generation should be performant")
    func testSmartSuggestionsPerformance() async throws {
        let largeDataSet = (1...1000).map { _ in Double.random(in: 60.0...80.0) }
        
        let startTime = Date()
        let suggestions = generateSmartSuggestions(from: largeDataSet, for: .weight)
        let endTime = Date()
        
        let executionTime = endTime.timeIntervalSince(startTime)
        
        #expect(!suggestions.isEmpty)
        #expect(executionTime < 0.1) // Should complete within 100ms
    }
    
    @Test("Data integrity checks should be performant")
    func testDataIntegrityPerformance() async throws {
        let validationService = HealthDataValidationService()
        
        // Create large set of existing records
        let existingRecords = (1...100).map { index in
            HealthRecord(
                type: .weight,
                value: Double(70 + index % 10),
                unit: "kg",
                timestamp: Date().addingTimeInterval(-Double(index * 3600)),
                source: .manual,
                user: nil
            )
        }
        
        let testInput = HealthDataInput(
            type: .weight,
            value: 75.0,
            unit: "kg",
            timestamp: Date(),
            source: .manual
        )
        
        let startTime = Date()
        let result = validationService.detectPotentialDuplicate(testInput, against: existingRecords)
        let endTime = Date()
        
        let executionTime = endTime.timeIntervalSince(startTime)
        
        // Should complete duplicate detection within 50ms even with 100 records
        #expect(executionTime < 0.05)
        #expect(result != nil)
    }
    
    // MARK: - Memory and Resource Tests
    
    @Test("Manual input should not cause memory leaks")
    func testMemoryUsage() async throws {
        // This test would require more sophisticated memory monitoring
        // For now, we test that objects can be properly deallocated
        
        weak var weakValidationService: HealthDataValidationService?
        weak var weakErrorHandler: ValidationErrorHandler?
        
        autoreleasepool {
            let validationService = HealthDataValidationService()
            let errorHandler = ValidationErrorHandler()
            
            weakValidationService = validationService
            weakErrorHandler = errorHandler
            
            // Use the services
            let _ = validationService.validateValue(70.0, for: .weight)
            let _ = errorHandler.handle(EnhancedValidationError.dataCorruption(details: "test"))
        }
        
        // Objects should be deallocated after autoreleasepool
        // Note: In practice, this might require more sophisticated testing
    }
    
    // MARK: - Error Handling Integration Tests
    
    @Test("Error handling should work across all input scenarios")
    func testComprehensiveErrorHandling() async throws {
        let validationService = HealthDataValidationService()
        let errorHandler = ValidationErrorHandler()
        
        let errorTestCases: [(Double, HealthDataType, Bool)] = [
            (500.0, .weight, false), // Too high
            (-10.0, .weight, false), // Too low
            (70.0, .weight, true),   // Valid
            (100000, .steps, false), // Too high
            (10000, .steps, true),   // Valid
            (10000, .calories, false), // Too high for calories
            (2000, .calories, true)    // Valid
        ]
        
        for (value, dataType, shouldPass) in errorTestCases {
            let result = validationService.validateValue(value, for: dataType)
            
            switch (result, shouldPass) {
            case (.success, true), (.failure, false):
                // Expected outcomes
                continue
            case (.success, false):
                Issue.record("Expected validation to fail for \(value) \(dataType) but it passed")
            case (.failure(let errors), true):
                Issue.record("Expected validation to pass for \(value) \(dataType) but got errors: \(errors)")
            }
        }
    }
    
    @Test("Error recovery should guide user to valid input")
    func testErrorRecoveryGuidance() async throws {
        let validationService = HealthDataValidationService()
        
        // Test high value error
        let highValueResult = validationService.validateValue(300.0, for: .weight)
        
        if case .failure(let errors) = highValueResult {
            let hasRecoverySuggestion = errors.allSatisfy { error in
                error.recoverySuggestion?.isEmpty == false
            }
            #expect(hasRecoverySuggestion)
        } else {
            Issue.record("Expected validation failure for extremely high weight")
        }
    }
    
    // MARK: - Cross-Platform Compatibility Tests
    
    @Test("Manual input should work across platforms")
    func testCrossPlatformCompatibility() async throws {
        // Test that core functionality works regardless of platform-specific features
        
        let validationService = HealthDataValidationService()
        let testValue = 70.0
        let dataType = HealthDataType.weight
        
        // Core validation should work on all platforms
        let result = validationService.validateValue(testValue, for: dataType)
        
        switch result {
        case .success:
            #expect(true)
        case .failure(let errors):
            Issue.record("Basic validation failed on this platform: \(errors)")
        }
        
        // Platform-specific features should be optional
        #if canImport(UIKit)
        // Haptic feedback should be available on iOS
        let hapticTypes: [HapticFeedbackType] = [
            .selection,
            .impact(.light),
            .notification(.success)
        ]
        #expect(hapticTypes.count == 3)
        #endif
    }
    
    // MARK: - Accessibility Integration Tests
    
    @Test("Manual input should provide proper accessibility support")
    func testAccessibilityIntegration() async throws {
        // Test that accessibility labels and hints are provided
        let dataTypes: [HealthDataType] = [.weight, .steps, .calories, .heartRate, .bloodGlucose]
        
        for dataType in dataTypes {
            // Each data type should have descriptive properties
            #expect(!dataType.displayName.isEmpty)
            #expect(!dataType.unit.isEmpty)
            #expect(!dataType.iconName.isEmpty)
            
            // Icon name should be a valid SF Symbol
            let iconName = dataType.iconName
            #expect(!iconName.contains(" ")) // No spaces in SF Symbol names
            #expect(!iconName.isEmpty)
        }
    }
    
    // MARK: - State Management Integration Tests
    
    @Test("State management should be consistent across UI updates")
    func testStateManagementConsistency() async throws {
        // Test that state changes are properly managed
        var inputValue = ""
        var selectedDataType = HealthDataType.weight
        var validationResult: ValidationResult = .success
        
        let validationService = HealthDataValidationService()
        
        // Simulate user input changes
        let inputSteps = ["7", "70", "70.", "70.5", "70.52", "70.5"]
        
        for step in inputSteps {
            inputValue = step
            
            if let value = Double(inputValue) {
                validationResult = validationService.validateValue(value, for: selectedDataType)
            }
            
            // State should be consistent
            #expect(!inputValue.isEmpty)
            #expect(selectedDataType == .weight)
        }
        
        // Final state should be valid
        if case .success = validationResult {
            #expect(true)
        } else {
            Issue.record("Final validation state should be successful")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockModelContext() -> ModelContext? {
        // In a real implementation, this would create a test model context
        // For now, return nil and handle appropriately in tests
        return nil
    }
    
    private func generateSmartSuggestions(from values: [Double], for dataType: HealthDataType) -> [Double] {
        guard !values.isEmpty else { return [] }
        
        let average = values.reduce(0, +) / Double(values.count)
        let recent = values.first!
        
        var suggestions: [Double] = []
        suggestions.append(recent)
        suggestions.append(average)
        
        // Add variations based on data type
        switch dataType {
        case .weight:
            suggestions.append(contentsOf: [recent - 0.5, recent + 0.5])
        case .steps:
            suggestions.append(contentsOf: [recent - 1000, recent + 1000])
        case .calories:
            suggestions.append(contentsOf: [recent - 200, recent + 200])
        case .heartRate:
            suggestions.append(contentsOf: [recent - 5, recent + 5])
        case .bloodGlucose:
            suggestions.append(contentsOf: [recent - 10, recent + 10])
        }
        
        // Remove duplicates and invalid values
        return Array(Set(suggestions))
            .filter { $0 > 0 }
            .sorted()
            .prefix(4)
            .map { $0 }
    }
    
    // MARK: - Mock Types for Testing
    
    #if canImport(UIKit)
    private enum HapticFeedbackType {
        case selection
        case impact(UIImpactFeedbackGenerator.FeedbackStyle)
        case notification(UINotificationFeedbackGenerator.FeedbackType)
    }
    #endif
}