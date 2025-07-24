import Testing
import Foundation
import SwiftData
@testable import HealthRecordingApp

@Suite("FetchHealthDataUseCase Tests")
struct FetchHealthDataUseCaseTests {
    
    private func createInMemoryModelContext() throws -> ModelContext {
        let schema = Schema([User.self, HealthRecord.self, Goal.self, Badge.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }
    
    private func createTestUser() -> User {
        return try! User(name: "Test User", age: 30, height: 170.0, targetWeight: 65.0)
    }
    
    private func createTestHealthRecords(for user: User, context: ModelContext) throws -> [HealthRecord] {
        let records = [
            HealthRecord(type: .weight, value: 70.0, unit: "kg", source: .healthKit),
            HealthRecord(type: .weight, value: 69.5, unit: "kg", source: .manual), 
            HealthRecord(type: .steps, value: 8000, unit: "steps", source: .healthKit),
            HealthRecord(type: .steps, value: 10000, unit: "steps", source: .healthKit),
            HealthRecord(type: .calories, value: 2200, unit: "kcal", source: .manual),
            HealthRecord(type: .heartRate, value: 72, unit: "bpm", source: .healthKit)
        ]
        
        // Set different timestamps for trend analysis
        let baseDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        for (index, record) in records.enumerated() {
            record.timestamp = Calendar.current.date(byAdding: .day, value: index, to: baseDate)!
            record.user = user
            context.insert(record)
        }
        
        return records
    }
    
    private func createTestUseCase(modelContext: ModelContext) -> FetchHealthDataUseCase {
        let healthRecordRepository = SwiftDataHealthRecordRepository(modelContext: modelContext)
        let userRepository = SwiftDataUserRepository(modelContext: modelContext)
        let logger = AILogger()
        
        return FetchHealthDataUseCase(
            healthRecordRepository: healthRecordRepository,
            userRepository: userRepository,
            logger: logger
        )
    }
    
    // MARK: - Basic Data Fetching Tests
    
    @Test("FetchHealthDataUseCase should fetch all health records for user")
    func testFetchAllHealthRecords() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        let testRecords = try createTestHealthRecords(for: user, context: modelContext)
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        // When
        let fetchedRecords = try await useCase.fetchHealthRecords(
            for: user,
            type: nil,
            dateRange: nil,
            limit: nil
        )
        
        // Then
        #expect(fetchedRecords.count == testRecords.count)
        #expect(fetchedRecords.allSatisfy { $0.user?.id == user.id })
    }
    
    @Test("FetchHealthDataUseCase should fetch records filtered by type")
    func testFetchRecordsByType() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        _ = try createTestHealthRecords(for: user, context: modelContext)
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        // When
        let weightRecords = try await useCase.fetchHealthRecords(
            for: user,
            type: .weight,
            dateRange: nil,
            limit: nil
        )
        
        // Then
        #expect(weightRecords.count == 2) // Created 2 weight records
        #expect(weightRecords.allSatisfy { $0.type == .weight })
    }
    
    @Test("FetchHealthDataUseCase should fetch records with date range filter")
    func testFetchRecordsWithDateRange() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        _ = try createTestHealthRecords(for: user, context: modelContext)
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        // Create date range for last 3 days of records
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -3, to: endDate)!
        let dateRange = try DateRange(startDate: startDate, endDate: endDate)
        
        // When
        let recentRecords = try await useCase.fetchHealthRecords(
            for: user,
            type: nil,
            dateRange: dateRange,
            limit: nil
        )
        
        // Then
        #expect(recentRecords.count >= 1)
        #expect(recentRecords.allSatisfy { dateRange.contains($0.timestamp) })
    }
    
    @Test("FetchHealthDataUseCase should respect limit parameter")
    func testFetchRecordsWithLimit() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        _ = try createTestHealthRecords(for: user, context: modelContext)
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        let limit = 3
        
        // When
        let limitedRecords = try await useCase.fetchHealthRecords(
            for: user,
            type: nil,
            dateRange: nil,
            limit: limit
        )
        
        // Then
        #expect(limitedRecords.count <= limit)
    }
    
    // MARK: - Latest Record Tests
    
    @Test("FetchHealthDataUseCase should fetch latest record by type")
    func testFetchLatestRecord() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        _ = try createTestHealthRecords(for: user, context: modelContext)
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        // When
        let latestWeightRecord = try await useCase.fetchLatestRecord(for: user, type: .weight)
        
        // Then
        #expect(latestWeightRecord != nil)
        #expect(latestWeightRecord?.type == .weight)
        
        // Should be the most recent weight record
        let userWeightRecords = user.healthRecords.filter { $0.type == .weight }
        let expectedLatest = userWeightRecords.max { $0.timestamp < $1.timestamp }
        #expect(latestWeightRecord?.id == expectedLatest?.id)
    }
    
    @Test("FetchHealthDataUseCase should return nil for non-existent record type") 
    func testFetchLatestRecordNonExistent() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        // When
        let latestRecord = try await useCase.fetchLatestRecord(for: user, type: .bloodGlucose)
        
        // Then
        #expect(latestRecord == nil)
    }
    
    // MARK: - Grouped Data Tests
    
    @Test("FetchHealthDataUseCase should group records by day")
    func testFetchRecordsGroupedByDay() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        _ = try createTestHealthRecords(for: user, context: modelContext)
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -10, to: endDate)!
        let dateRange = try DateRange(startDate: startDate, endDate: endDate)
        
        // When
        let groupedRecords = try await useCase.fetchRecordsGroupedByDay(
            for: user,
            type: .weight,
            dateRange: dateRange
        )
        
        // Then
        #expect(groupedRecords.count >= 1)
        
        // Verify each group contains only weight records
        for (_, records) in groupedRecords {
            #expect(records.allSatisfy { $0.type == .weight })
        }
    }
    
    // MARK: - Statistics Tests
    
    @Test("FetchHealthDataUseCase should calculate health data statistics")
    func testGetHealthDataStatistics() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        _ = try createTestHealthRecords(for: user, context: modelContext)
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -10, to: endDate)!
        let dateRange = try DateRange(startDate: startDate, endDate: endDate)
        
        // When
        let statistics = try await useCase.getHealthDataStatistics(
            for: user,
            type: .weight,
            dateRange: dateRange
        )
        
        // Then
        #expect(statistics.dataType == .weight)
        #expect(statistics.recordCount >= 1)
        #expect(statistics.averageValue > 0)
        #expect(statistics.minimumValue <= statistics.maximumValue)
        #expect(statistics.standardDeviation >= 0)
    }
    
    @Test("FetchHealthDataUseCase should handle empty statistics correctly")
    func testGetHealthDataStatisticsEmpty() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -10, to: endDate)!
        let dateRange = try DateRange(startDate: startDate, endDate: endDate)
        
        // When
        let statistics = try await useCase.getHealthDataStatistics(
            for: user,
            type: .bloodGlucose,
            dateRange: dateRange
        )
        
        // Then
        #expect(statistics.recordCount == 0)
        #expect(statistics.averageValue == 0.0)
        #expect(statistics.trend == .stable)
    }
    
    // MARK: - Search Tests
    
    @Test("FetchHealthDataUseCase should search records with multiple criteria")
    func testSearchHealthRecords() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        _ = try createTestHealthRecords(for: user, context: modelContext)
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -10, to: endDate)!
        let dateRange = try DateRange(startDate: startDate, endDate: endDate)
        let valueRange = try ValueRange(minimum: 8000, maximum: 15000)
        
        let criteria = HealthDataSearchCriteria(
            dataTypes: [.steps],
            dateRange: dateRange,
            valueRange: valueRange,
            sources: [.healthKit],
            sortBy: .value,
            sortOrder: .descending,
            limit: 5
        )
        
        // When
        let searchResults = try await useCase.searchHealthRecords(for: user, criteria: criteria)
        
        // Then
        #expect(searchResults.count >= 1)
        #expect(searchResults.allSatisfy { $0.type == .steps })
        #expect(searchResults.allSatisfy { $0.source == .healthKit })
        #expect(searchResults.allSatisfy { valueRange.contains($0.value) })
        
        // Verify descending order by value
        for i in 0..<(searchResults.count - 1) {
            #expect(searchResults[i].value >= searchResults[i + 1].value)
        }
    }
    
    @Test("FetchHealthDataUseCase should handle search with no results")
    func testSearchHealthRecordsNoResults() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        _ = try createTestHealthRecords(for: user, context: modelContext)
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        // Search for impossible value range
        let valueRange = try ValueRange(minimum: 100000, maximum: 200000)
        let criteria = HealthDataSearchCriteria(
            dataTypes: [.steps],
            valueRange: valueRange
        )
        
        // When
        let searchResults = try await useCase.searchHealthRecords(for: user, criteria: criteria)
        
        // Then
        #expect(searchResults.isEmpty)
    }
    
    // MARK: - Export Tests
    
    @Test("FetchHealthDataUseCase should export health data as JSON")
    func testExportHealthDataJSON() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        _ = try createTestHealthRecords(for: user, context: modelContext)
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        // When
        let exportResult = try await useCase.exportHealthData(
            for: user,
            format: .json,
            dateRange: nil
        )
        
        // Then
        #expect(exportResult.format == .json)
        #expect(exportResult.data.count > 0)
        #expect(exportResult.filename.hasSuffix(".json"))
        #expect(exportResult.recordCount >= 1)
        #expect(exportResult.userID == user.id)
        
        // Verify JSON is valid by parsing it
        let jsonObject = try JSONSerialization.jsonObject(with: exportResult.data)
        #expect(jsonObject is [String: Any])
    }
    
    @Test("FetchHealthDataUseCase should export health data as CSV")
    func testExportHealthDataCSV() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        _ = try createTestHealthRecords(for: user, context: modelContext)
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        // When
        let exportResult = try await useCase.exportHealthData(
            for: user,
            format: .csv,
            dateRange: nil
        )
        
        // Then
        #expect(exportResult.format == .csv)
        #expect(exportResult.data.count > 0)
        #expect(exportResult.filename.hasSuffix(".csv"))
        #expect(exportResult.recordCount >= 1)
        
        // Verify CSV format by checking for headers
        let csvString = String(data: exportResult.data, encoding: .utf8)!
        #expect(csvString.contains("timestamp"))
        #expect(csvString.contains("type"))
        #expect(csvString.contains("value"))
    }
    
    // MARK: - Error Handling Tests
    
    @Test("FetchHealthDataUseCase should handle invalid date range")
    func testInvalidDateRange() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        // When & Then
        do {
            let invalidDateRange = try DateRange(
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!
            )
            _ = try await useCase.fetchHealthRecords(
                for: user,
                type: nil,
                dateRange: invalidDateRange,
                limit: nil
            )
            #expect(Bool(false), "Should throw validation error for invalid date range")
        } catch is ValidationError {
            #expect(true, "Expected ValidationError was thrown")
        }
    }
    
    @Test("FetchHealthDataUseCase should handle invalid value range")
    func testInvalidValueRange() async throws {
        // When & Then
        do {
            _ = try ValueRange(minimum: 100, maximum: 50)
            #expect(Bool(false), "Should throw validation error for invalid value range")
        } catch is ValidationError {
            #expect(true, "Expected ValidationError was thrown")
        }
    }
    
    @Test("FetchHealthDataUseCase should handle concurrent operations")
    func testConcurrentOperations() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        _ = try createTestHealthRecords(for: user, context: modelContext)
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        // When - Execute multiple operations concurrently
        async let fetchTask1 = useCase.fetchHealthRecords(for: user, type: .weight, dateRange: nil, limit: nil)
        async let fetchTask2 = useCase.fetchHealthRecords(for: user, type: .steps, dateRange: nil, limit: nil) 
        async let latestTask = useCase.fetchLatestRecord(for: user, type: .heartRate)
        
        let results = try await (fetchTask1, fetchTask2, latestTask)
        
        // Then
        #expect(results.0.allSatisfy { $0.type == .weight })
        #expect(results.1.allSatisfy { $0.type == .steps })
        #expect(results.2?.type == .heartRate)
    }
    
    // MARK: - Performance Tests
    
    @Test("FetchHealthDataUseCase should handle large data sets efficiently")
    func testLargeDataSetHandling() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        // Create a large number of test records
        for i in 0..<1000 {
            let record = HealthRecord(
                type: .steps,
                value: Double(5000 + i),
                unit: "steps",
                source: .healthKit
            )
            record.timestamp = Calendar.current.date(byAdding: .minute, value: i, to: Date())!
            record.user = user
            modelContext.insert(record)
        }
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        // When - Measure performance
        let startTime = Date()
        let records = try await useCase.fetchHealthRecords(
            for: user,
            type: .steps,
            dateRange: nil,
            limit: 100
        )
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Then
        #expect(records.count == 100)
        #expect(executionTime < 2.0) // Should complete within 2 seconds
    }
    
    // MARK: - Data Consistency Tests
    
    @Test("FetchHealthDataUseCase should maintain data consistency across operations")
    func testDataConsistency() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        let testRecords = try createTestHealthRecords(for: user, context: modelContext)
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        // When - Fetch data in different ways
        let allRecords = try await useCase.fetchHealthRecords(for: user, type: nil, dateRange: nil, limit: nil)
        let weightRecords = try await useCase.fetchHealthRecords(for: user, type: .weight, dateRange: nil, limit: nil)
        let stepsRecords = try await useCase.fetchHealthRecords(for: user, type: .steps, dateRange: nil, limit: nil)
        
        // Then - Verify consistency
        let weightCount = allRecords.filter { $0.type == .weight }.count
        let stepsCount = allRecords.filter { $0.type == .steps }.count
        
        #expect(weightRecords.count == weightCount)
        #expect(stepsRecords.count == stepsCount)
        #expect(allRecords.count == testRecords.count)
    }
}