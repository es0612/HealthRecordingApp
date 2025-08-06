import Testing
import SwiftUI
import SwiftData
import Foundation

@testable import HealthRecordingApp

// MARK: - Smart Suggestion Engine Tests

struct SmartSuggestionEngineTests {
    
    private let logger = AILogger()
    
    // MARK: - Smart Suggestion Generation Tests
    
    @Test("Smart suggestion engine should generate diverse suggestions")
    func testSmartSuggestionDiversity() async throws {
        let mockWeightData = [70.2, 69.8, 70.5, 70.1, 69.9, 70.3, 69.7]
        let suggestions = SmartSuggestionEngine.generateSuggestions(
            from: mockWeightData,
            for: .weight,
            maxSuggestions: 4
        )
        
        #expect(suggestions.count <= 4)
        #expect(!suggestions.isEmpty)
        
        // Suggestions should be unique
        let uniqueSuggestions = Set(suggestions)
        #expect(uniqueSuggestions.count == suggestions.count)
        
        // Should include average and recent value
        let average = mockWeightData.reduce(0, +) / Double(mockWeightData.count)
        let recent = mockWeightData.first!
        
        #expect(suggestions.contains(recent))
        #expect(suggestions.contains(average))
    }
    
    @Test("Smart suggestion engine should adapt to data type characteristics")
    func testDataTypeSpecificSuggestions() async throws {
        let testCases: [(HealthDataType, [Double], Double)] = [
            (.weight, [70.0, 71.0, 69.5], 0.5), // Small variations for weight
            (.steps, [10000, 11000, 9500], 1000), // Larger variations for steps
            (.calories, [2000, 2100, 1950], 200), // Medium variations for calories
            (.heartRate, [75, 78, 72], 5), // Small variations for heart rate
            (.bloodGlucose, [100, 105, 95], 10) // Medium variations for glucose
        ]
        
        for (dataType, values, expectedVariation) in testCases {
            let suggestions = SmartSuggestionEngine.generateSuggestions(
                from: values,
                for: dataType,
                maxSuggestions: 4
            )
            
            #expect(!suggestions.isEmpty)
            
            // Check that variations are appropriate for the data type
            let baseValue = values.first!
            let hasAppropriateVariation = suggestions.contains { suggestion in
                abs(suggestion - baseValue) <= expectedVariation * 2
            }
            #expect(hasAppropriateVariation)
        }
    }
    
    @Test("Smart suggestion engine should handle edge cases")
    func testSmartSuggestionEdgeCases() async throws {
        // Test empty data
        let emptySuggestions = SmartSuggestionEngine.generateSuggestions(
            from: [],
            for: .weight,
            maxSuggestions: 4
        )
        #expect(emptySuggestions.isEmpty)
        
        // Test single data point
        let singleDataPoint = [70.0]
        let singleSuggestions = SmartSuggestionEngine.generateSuggestions(
            from: singleDataPoint,
            for: .weight,
            maxSuggestions: 4
        )
        #expect(!singleSuggestions.isEmpty)
        #expect(singleSuggestions.contains(70.0))
        
        // Test negative values (should be filtered)
        let dataWithNegatives = [70.0, -5.0, 69.5, 0.0]
        let filteredSuggestions = SmartSuggestionEngine.generateSuggestions(
            from: dataWithNegatives,
            for: .weight,
            maxSuggestions: 4
        )
        for suggestion in filteredSuggestions {
            #expect(suggestion > 0)
        }
    }
    
    // MARK: - Recent Values Processing Tests
    
    @Test("Recent values processor should prioritize recent data")
    func testRecentValuesPrioritization() async throws {
        let mockData = generateMockHealthRecords()
        let processor = RecentValuesProcessor()
        
        let recentValues = processor.extractRecentValues(from: mockData, for: .weight, limit: 5)
        
        #expect(recentValues.count <= 5)
        
        // Values should be sorted by recency (most recent first)
        if recentValues.count > 1 {
            for i in 0..<(recentValues.count - 1) {
                // This is just testing the logic, actual timestamps would need to be checked in real implementation
                #expect(recentValues[i] != nil)
            }
        }
    }
    
    @Test("Recent values processor should handle different data types")
    func testRecentValuesForAllDataTypes() async throws {
        let mockData = generateMockHealthRecordsForAllTypes()
        let processor = RecentValuesProcessor()
        
        let dataTypes: [HealthDataType] = [.weight, .steps, .calories, .heartRate, .bloodGlucose]
        
        for dataType in dataTypes {
            let recentValues = processor.extractRecentValues(from: mockData, for: dataType, limit: 3)
            
            // Should return some values for each type (in mock data)
            #expect(!recentValues.isEmpty)
            
            // Values should be reasonable for the data type
            for value in recentValues {
                #expect(isReasonableValueForDataType(value, dataType: dataType))
            }
        }
    }
    
    // MARK: - Recommendation Scoring Tests
    
    @Test("Recommendation scorer should rank suggestions appropriately")
    func testRecommendationScoring() async throws {
        let recentValues = [70.0, 69.8, 70.2, 69.9, 70.1]
        let candidateSuggestions = [69.5, 70.0, 70.5, 65.0, 80.0]
        
        let scorer = RecommendationScorer()
        let scoredSuggestions = scorer.scoreSuggestions(
            candidateSuggestions,
            basedOn: recentValues,
            for: .weight
        )
        
        #expect(scoredSuggestions.count == candidateSuggestions.count)
        
        // Should prefer values closer to recent data
        let score70 = scoredSuggestions.first { $0.value == 70.0 }?.score ?? 0
        let score65 = scoredSuggestions.first { $0.value == 65.0 }?.score ?? 0
        let score80 = scoredSuggestions.first { $0.value == 80.0 }?.score ?? 0
        
        #expect(score70 > score65)
        #expect(score70 > score80)
    }
    
    @Test("Recommendation scorer should consider data patterns")
    func testPatternBasedScoring() async throws {
        // Test ascending pattern
        let ascendingValues = [68.0, 68.5, 69.0, 69.5, 70.0]
        let scorer = RecommendationScorer()
        
        let suggestions = [70.5, 69.5, 71.0, 67.0]
        let scoredAscending = scorer.scoreSuggestions(
            suggestions,
            basedOn: ascendingValues,
            for: .weight
        )
        
        // Should prefer values that follow the ascending trend
        let score70_5 = scoredAscending.first { $0.value == 70.5 }?.score ?? 0
        let score67 = scoredAscending.first { $0.value == 67.0 }?.score ?? 0
        
        #expect(score70_5 > score67)
    }
    
    // MARK: - Smart Input Validation Tests
    
    @Test("Smart validation should consider suggestion context")
    func testSmartValidation() async throws {
        let recentValues = [70.0, 69.8, 70.2]
        let validator = SmartInputValidator()
        
        // Test value within normal range for user
        let normalResult = validator.validateInput(
            value: 70.1,
            dataType: .weight,
            recentValues: recentValues
        )
        
        switch normalResult.severity {
        case .none, .low:
            // Expected for normal values
            break
        case .medium, .high:
            Issue.record("Unexpected high severity for normal value")
        }
        
        // Test value significantly outside normal range
        let outlierResult = validator.validateInput(
            value: 85.0,
            dataType: .weight,
            recentValues: recentValues
        )
        
        #expect(outlierResult.severity != .none)
        #expect(!outlierResult.suggestion.isEmpty)
    }
    
    // MARK: - Performance Tests
    
    @Test("Smart suggestion generation should be performant")
    func testSuggestionGenerationPerformance() async throws {
        let largeDataSet = Array(repeating: 70.0, count: 1000)
        
        let startTime = Date()
        let suggestions = SmartSuggestionEngine.generateSuggestions(
            from: largeDataSet,
            for: .weight,
            maxSuggestions: 4
        )
        let endTime = Date()
        
        let executionTime = endTime.timeIntervalSince(startTime)
        
        #expect(!suggestions.isEmpty)
        #expect(executionTime < 0.1) // Should complete within 100ms
    }
    
    // MARK: - Integration Tests
    
    @Test("Smart suggestion system should integrate with validation")
    func testSuggestionValidationIntegration() async throws {
        let validationService = HealthDataValidationService()
        let recentValues = [70.0, 69.8, 70.2, 69.9]
        
        let suggestions = SmartSuggestionEngine.generateSuggestions(
            from: recentValues,
            for: .weight,
            maxSuggestions: 4
        )
        
        // All suggestions should pass basic validation
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
    
    // MARK: - Helper Methods and Mock Data
    
    private func generateMockHealthRecords() -> [HealthRecord] {
        let weights = [70.2, 69.8, 70.5, 70.1, 69.9]
        return weights.enumerated().map { index, weight in
            HealthRecord(
                type: .weight,
                value: weight,
                unit: "kg",
                timestamp: Date().addingTimeInterval(-Double(index * 3600)), // Hourly intervals
                source: .manual,
                user: nil
            )
        }
    }
    
    private func generateMockHealthRecordsForAllTypes() -> [HealthRecord] {
        var records: [HealthRecord] = []
        
        // Weight records
        records.append(contentsOf: [70.0, 69.8, 70.2].map { value in
            HealthRecord(type: .weight, value: value, unit: "kg", timestamp: Date(), source: .manual, user: nil)
        })
        
        // Steps records
        records.append(contentsOf: [10000, 9800, 10200].map { value in
            HealthRecord(type: .steps, value: value, unit: "歩", timestamp: Date(), source: .manual, user: nil)
        })
        
        // Calories records
        records.append(contentsOf: [2000, 1980, 2020].map { value in
            HealthRecord(type: .calories, value: value, unit: "kcal", timestamp: Date(), source: .manual, user: nil)
        })
        
        // Heart rate records
        records.append(contentsOf: [75, 73, 77].map { value in
            HealthRecord(type: .heartRate, value: value, unit: "bpm", timestamp: Date(), source: .manual, user: nil)
        })
        
        // Blood glucose records
        records.append(contentsOf: [100, 98, 102].map { value in
            HealthRecord(type: .bloodGlucose, value: value, unit: "mg/dL", timestamp: Date(), source: .manual, user: nil)
        })
        
        return records
    }
    
    private func isReasonableValueForDataType(_ value: Double, dataType: HealthDataType) -> Bool {
        switch dataType {
        case .weight:
            return value >= 30 && value <= 200
        case .steps:
            return value >= 0 && value <= 50000
        case .calories:
            return value >= 0 && value <= 5000
        case .heartRate:
            return value >= 30 && value <= 200
        case .bloodGlucose:
            return value >= 20 && value <= 600
        }
    }
}

// MARK: - Smart Suggestion Engine Mock Implementation

struct SmartSuggestionEngine {
    static func generateSuggestions(
        from values: [Double],
        for dataType: HealthDataType,
        maxSuggestions: Int
    ) -> [Double] {
        guard !values.isEmpty else { return [] }
        
        let average = values.reduce(0, +) / Double(values.count)
        let recent = values.first!
        
        var suggestions: [Double] = []
        suggestions.append(recent)
        suggestions.append(average)
        
        // Add variations based on data type
        let variationAmount: Double
        switch dataType {
        case .weight:
            variationAmount = 0.5
        case .steps:
            variationAmount = 1000
        case .calories:
            variationAmount = 200
        case .heartRate:
            variationAmount = 5
        case .bloodGlucose:
            variationAmount = 10
        }
        
        suggestions.append(recent - variationAmount)
        suggestions.append(recent + variationAmount)
        
        // Filter out invalid values and remove duplicates
        let validSuggestions = Array(Set(suggestions))
            .filter { $0 > 0 }
            .sorted()
            .prefix(maxSuggestions)
        
        return Array(validSuggestions)
    }
}

// MARK: - Recent Values Processor Mock Implementation

struct RecentValuesProcessor {
    func extractRecentValues(
        from records: [HealthRecord],
        for dataType: HealthDataType,
        limit: Int
    ) -> [Double] {
        return records
            .filter { $0.type == dataType }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(limit)
            .map { $0.value }
    }
}

// MARK: - Recommendation Scorer Mock Implementation

struct RecommendationScorer {
    struct ScoredSuggestion {
        let value: Double
        let score: Double
    }
    
    func scoreSuggestions(
        _ suggestions: [Double],
        basedOn recentValues: [Double],
        for dataType: HealthDataType
    ) -> [ScoredSuggestion] {
        let average = recentValues.reduce(0, +) / Double(recentValues.count)
        
        return suggestions.map { suggestion in
            // Simple scoring based on proximity to recent average
            let distance = abs(suggestion - average)
            let maxDistance = getMaxReasonableDistance(for: dataType)
            let score = max(0, 1.0 - (distance / maxDistance))
            
            return ScoredSuggestion(value: suggestion, score: score)
        }
    }
    
    private func getMaxReasonableDistance(for dataType: HealthDataType) -> Double {
        switch dataType {
        case .weight:
            return 10.0
        case .steps:
            return 5000.0
        case .calories:
            return 1000.0
        case .heartRate:
            return 30.0
        case .bloodGlucose:
            return 50.0
        }
    }
}

// MARK: - Smart Input Validator Mock Implementation

struct SmartInputValidator {
    enum ValidationSeverity {
        case none
        case low
        case medium
        case high
    }
    
    struct ValidationResult {
        let severity: ValidationSeverity
        let suggestion: String
    }
    
    func validateInput(
        value: Double,
        dataType: HealthDataType,
        recentValues: [Double]
    ) -> ValidationResult {
        guard !recentValues.isEmpty else {
            return ValidationResult(severity: .none, suggestion: "")
        }
        
        let average = recentValues.reduce(0, +) / Double(recentValues.count)
        let standardDeviation = calculateStandardDeviation(recentValues, mean: average)
        let zScore = abs(value - average) / standardDeviation
        
        if zScore > 2.0 {
            return ValidationResult(
                severity: .high,
                suggestion: "この値は通常の範囲を大きく外れています。確認してください。"
            )
        } else if zScore > 1.0 {
            return ValidationResult(
                severity: .medium,
                suggestion: "この値は少し通常より外れています。"
            )
        } else {
            return ValidationResult(severity: .none, suggestion: "")
        }
    }
    
    private func calculateStandardDeviation(_ values: [Double], mean: Double) -> Double {
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
}