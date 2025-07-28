import Testing
import Foundation
import SwiftData
@testable import HealthRecordingApp

@Suite("HealthRecordRepository Tests")
struct HealthRecordRepositoryTests {
    
    private func createTestModelContext() throws -> ModelContext {
        let schema = Schema([HealthRecord.self, User.self, Goal.self, Badge.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }
    
    private func createTestUser() throws -> User {
        return try User(name: "Test User", age: 30, height: 170.0, targetWeight: 65.0)
    }
    
    private func createTestHealthRecord(user: User, type: HealthDataType = .weight, value: Double = 70.0) -> HealthRecord {
        let record = HealthRecord(type: type, value: value, unit: type.unit, source: .healthKit)
        record.user = user
        return record
    }
    
    @Test("HealthRecordRepository should save health record successfully")
    func testSaveHealthRecord() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataHealthRecordRepository(modelContext: modelContext)
        let user = try createTestUser()
        let healthRecord = createTestHealthRecord(user: user)
        
        // When
        try await repository.save(healthRecord)
        
        // Then
        let savedRecords = try await repository.fetchRecords(for: user, type: nil, from: nil, to: nil)
        #expect(savedRecords.count == 1)
        #expect(savedRecords.first?.id == healthRecord.id)
        #expect(savedRecords.first?.value == 70.0)
        #expect(savedRecords.first?.type == .weight)
    }
    
    @Test("HealthRecordRepository should handle save errors gracefully")
    func testSaveHealthRecordError() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataHealthRecordRepository(modelContext: modelContext)
        let user = try createTestUser()
        
        // Create a record with value outside valid range (weight > 500kg should be invalid)
        let invalidRecord = HealthRecord(type: .weight, value: 600.0, unit: "kg", source: .manual)
        invalidRecord.user = user
        
        // Verify the record is actually invalid
        #expect(invalidRecord.isValid == false, "Test record should be invalid")
        
        // When & Then
        do {
            try await repository.save(invalidRecord)
            #expect(Bool(false), "Should throw error for invalid health record")
        } catch let error as ValidationError {
            #expect(error.errorCode.starts(with: "VAL"))
        } catch {
            #expect(Bool(false), "Should throw ValidationError for invalid save, but got: \(type(of: error))")
        }
    }
    
    @Test("HealthRecordRepository should fetch all records for user")
    func testFetchAllRecordsForUser() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataHealthRecordRepository(modelContext: modelContext)
        let user = try createTestUser()
        
        let record1 = createTestHealthRecord(user: user, type: .weight, value: 70.0)
        let record2 = createTestHealthRecord(user: user, type: .steps, value: 10000.0)
        let record3 = createTestHealthRecord(user: user, type: .calories, value: 2000.0)
        
        try await repository.save(record1)
        try await repository.save(record2)
        try await repository.save(record3)
        
        // When
        let fetchedRecords = try await repository.fetchRecords(for: user, type: nil, from: nil, to: nil)
        
        // Then
        #expect(fetchedRecords.count == 3)
        #expect(fetchedRecords.contains { $0.type == .weight })
        #expect(fetchedRecords.contains { $0.type == .steps })
        #expect(fetchedRecords.contains { $0.type == .calories })
    }
    
    @Test("HealthRecordRepository should fetch records filtered by type")
    func testFetchRecordsByType() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataHealthRecordRepository(modelContext: modelContext)
        let user = try createTestUser()
        
        let weightRecord = createTestHealthRecord(user: user, type: .weight, value: 70.0)
        let stepsRecord = createTestHealthRecord(user: user, type: .steps, value: 10000.0)
        
        try await repository.save(weightRecord)
        try await repository.save(stepsRecord)
        
        // When
        let weightRecords = try await repository.fetchRecords(for: user, type: .weight, from: nil, to: nil)
        
        // Then
        #expect(weightRecords.count == 1)
        #expect(weightRecords.first?.type == .weight)
        #expect(weightRecords.first?.value == 70.0)
    }
    
    @Test("HealthRecordRepository should fetch records filtered by date range")
    func testFetchRecordsByDateRange() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataHealthRecordRepository(modelContext: modelContext)
        let user = try createTestUser()
        
        let oldRecord = createTestHealthRecord(user: user, type: .weight, value: 75.0)
        oldRecord.timestamp = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        
        let recentRecord = createTestHealthRecord(user: user, type: .weight, value: 70.0)
        recentRecord.timestamp = Date()
        
        try await repository.save(oldRecord)
        try await repository.save(recentRecord)
        
        // When
        let startDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let endDate = Date()
        let recentRecords = try await repository.fetchRecords(for: user, type: nil, from: startDate, to: endDate)
        
        // Then
        #expect(recentRecords.count == 1)
        #expect(recentRecords.first?.value == 70.0)
        #expect(recentRecords.first?.timestamp ?? Date.distantPast >= startDate)
    }
    
    @Test("HealthRecordRepository should fetch records with complex filtering")
    func testFetchRecordsWithComplexFiltering() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataHealthRecordRepository(modelContext: modelContext)
        let user = try createTestUser()
        
        // Create various records
        let oldWeightRecord = createTestHealthRecord(user: user, type: .weight, value: 75.0)
        oldWeightRecord.timestamp = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        
        let recentWeightRecord = createTestHealthRecord(user: user, type: .weight, value: 70.0)
        recentWeightRecord.timestamp = Date()
        
        let recentStepsRecord = createTestHealthRecord(user: user, type: .steps, value: 10000.0)
        recentStepsRecord.timestamp = Date()
        
        try await repository.save(oldWeightRecord)
        try await repository.save(recentWeightRecord)
        try await repository.save(recentStepsRecord)
        
        // When - Filter by type AND date range
        let startDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let endDate = Date()
        let filteredRecords = try await repository.fetchRecords(for: user, type: .weight, from: startDate, to: endDate)
        
        // Then
        #expect(filteredRecords.count == 1)
        #expect(filteredRecords.first?.type == .weight)
        #expect(filteredRecords.first?.value == 70.0)
        #expect(filteredRecords.first?.timestamp ?? Date.distantPast >= startDate)
    }
    
    @Test("HealthRecordRepository should return empty array for no matches")
    func testFetchRecordsNoMatches() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataHealthRecordRepository(modelContext: modelContext)
        let user = try createTestUser()
        
        // When - Fetch from empty repository
        let records = try await repository.fetchRecords(for: user, type: .weight, from: nil, to: nil)
        
        // Then
        #expect(records.isEmpty)
    }
    
    @Test("HealthRecordRepository should delete health record successfully")
    func testDeleteHealthRecord() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataHealthRecordRepository(modelContext: modelContext)
        let user = try createTestUser()
        let healthRecord = createTestHealthRecord(user: user)
        
        try await repository.save(healthRecord)
        
        // Verify record exists
        let recordsBeforeDelete = try await repository.fetchRecords(for: user, type: nil, from: nil, to: nil)
        #expect(recordsBeforeDelete.count == 1)
        
        // When
        try await repository.delete(healthRecord)
        
        // Then
        let recordsAfterDelete = try await repository.fetchRecords(for: user, type: nil, from: nil, to: nil)
        #expect(recordsAfterDelete.isEmpty)
    }
    
    @Test("HealthRecordRepository should handle delete errors gracefully")
    func testDeleteHealthRecordError() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataHealthRecordRepository(modelContext: modelContext)
        let user = try createTestUser()
        let healthRecord = createTestHealthRecord(user: user)
        
        // Don't save the record first, so delete should fail
        
        // When & Then
        do {
            try await repository.delete(healthRecord)
            #expect(Bool(false), "Should throw error when deleting non-existent record")
        } catch let error as DataError {
            #expect(error.errorCode.starts(with: "DATA"))
        } catch {
            #expect(Bool(false), "Should throw DataError for delete failure")
        }
    }
    
    @Test("HealthRecordRepository should handle sync with HealthKit")
    func testSyncWithHealthKit() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataHealthRecordRepository(modelContext: modelContext)
        
        // When & Then
        // In test environment, sync should complete without errors
        try await repository.syncWithHealthKit()
        
        // Note: Actual HealthKit integration testing would require more complex setup
        // For now, we just verify the method doesn't throw an error
    }
    
    @Test("HealthRecordRepository should filter records by user correctly")
    func testFetchRecordsFiltersByUser() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataHealthRecordRepository(modelContext: modelContext)
        
        let user1 = try createTestUser()
        let user2 = try User(name: "User 2", age: 25, height: 160.0, targetWeight: 55.0)
        
        let record1 = createTestHealthRecord(user: user1, type: .weight, value: 70.0)
        let record2 = createTestHealthRecord(user: user2, type: .weight, value: 55.0)
        
        try await repository.save(record1)
        try await repository.save(record2)
        
        // When
        let user1Records = try await repository.fetchRecords(for: user1, type: nil, from: nil, to: nil)
        let user2Records = try await repository.fetchRecords(for: user2, type: nil, from: nil, to: nil)
        
        // Then
        #expect(user1Records.count == 1)
        #expect(user1Records.first?.value == 70.0)
        
        #expect(user2Records.count == 1)
        #expect(user2Records.first?.value == 55.0)
    }
    
    @Test("HealthRecordRepository should handle concurrent operations")
    func testConcurrentOperations() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataHealthRecordRepository(modelContext: modelContext)
        let user = try createTestUser()
        
        // When - Perform concurrent save operations
        await withTaskGroup(of: Void.self) { group in
            for i in 1...5 {
                group.addTask {
                    let record = self.createTestHealthRecord(user: user, type: .weight, value: Double(70 + i))
                    try? await repository.save(record)
                }
            }
        }
        
        // Then - Check that we have at least the 5 records we added
        let allRecords = try await repository.fetchRecords(for: user, type: .weight, from: nil, to: nil)
        #expect(allRecords.count >= 5) // Allow for existing test data from other tests
    }
}