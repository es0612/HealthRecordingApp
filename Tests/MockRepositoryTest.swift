import Testing
import Foundation
@testable import HealthRecordingApp

// MARK: - Mock Repository Implementation

final class MockHealthRecordRepository: HealthRecordRepositoryProtocol {
    private var records: [HealthRecord] = []
    private var errorToThrow: Error?
    
    func setErrorToThrow(_ error: Error?) {
        errorToThrow = error
    }
    
    func save(_ record: HealthRecord) async throws {
        if let error = errorToThrow { throw error }
        records.append(record)
    }
    
    func fetchRecords(
        for user: User,
        type: HealthDataType?,
        from startDate: Date?,
        to endDate: Date?
    ) async throws -> [HealthRecord] {
        if let error = errorToThrow { throw error }
        
        var filteredRecords = records.filter { $0.user?.id == user.id }
        
        if let type = type {
            filteredRecords = filteredRecords.filter { $0.type == type }
        }
        
        if let startDate = startDate {
            filteredRecords = filteredRecords.filter { $0.timestamp >= startDate }
        }
        
        if let endDate = endDate {
            filteredRecords = filteredRecords.filter { $0.timestamp <= endDate }
        }
        
        return filteredRecords
    }
    
    func delete(_ record: HealthRecord) async throws {
        if let error = errorToThrow { throw error }
        records.removeAll { $0.id == record.id }
    }
    
    func syncWithHealthKit() async throws {
        if let error = errorToThrow { throw error }
        // Mock implementation - do nothing for sync
    }
    
    // Test helper methods
    func getRecordsCount() -> Int {
        return records.count
    }
    
    func clearRecords() {
        records.removeAll()
        errorToThrow = nil
    }
    
    func getAllRecords() -> [HealthRecord] {
        return records
    }
}

@Suite("Mock Repository Tests")
struct MockRepositoryTest {
    
    @Test("MockRepository should save and retrieve records")
    func testSaveAndRetrieve() async throws {
        // Given
        let repository = MockHealthRecordRepository()
        let user = try User(name: "Test User", age: 30, height: 175.0, targetWeight: 70.0)
        let record = HealthRecord(type: .weight, value: 70.0, unit: "kg")
        record.user = user
        
        // When
        try await repository.save(record)
        let allRecords = try await repository.fetchRecords(for: user, type: nil, from: nil, to: nil)
        
        // Then
        #expect(allRecords.count == 1)
        #expect(allRecords.first?.type == .weight)
        #expect(allRecords.first?.value == 70.0)
    }
    
    @Test("MockRepository should filter records by type")
    func testFilterByType() async throws {
        // Given
        let repository = MockHealthRecordRepository()
        let user = try User(name: "Test User", age: 30, height: 175.0, targetWeight: 70.0)
        let weightRecord = HealthRecord(type: .weight, value: 70.0, unit: "kg")
        let stepsRecord = HealthRecord(type: .steps, value: 10000, unit: "歩")
        
        weightRecord.user = user
        stepsRecord.user = user
        
        try await repository.save(weightRecord)
        try await repository.save(stepsRecord)
        
        // When
        let weightRecords = try await repository.fetchRecords(for: user, type: .weight, from: nil, to: nil)
        let stepsRecords = try await repository.fetchRecords(for: user, type: .steps, from: nil, to: nil)
        
        // Then
        #expect(weightRecords.count == 1)
        #expect(weightRecords.first?.type == .weight)
        #expect(stepsRecords.count == 1)
        #expect(stepsRecords.first?.type == .steps)
    }
    
    @Test("MockRepository should filter records by date range")
    func testFilterByDateRange() async throws {
        // Given
        let repository = MockHealthRecordRepository()
        let user = try User(name: "Test User", age: 30, height: 175.0, targetWeight: 70.0)
        let record = HealthRecord(type: .weight, value: 70.0, unit: "kg")
        record.user = user
        
        try await repository.save(record)
        
        let startDate = Calendar.current.date(byAdding: .hour, value: -1, to: Date())!
        let endDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        
        // When
        let recordsInRange = try await repository.fetchRecords(for: user, type: nil, from: startDate, to: endDate)
        let recordsOutOfRange = try await repository.fetchRecords(for: user, type: nil, from: Calendar.current.date(byAdding: .day, value: 1, to: Date())!, to: Calendar.current.date(byAdding: .day, value: 2, to: Date())!)
        
        // Then
        #expect(recordsInRange.count == 1)
        #expect(recordsOutOfRange.count == 0)
    }
    
    @Test("MockRepository should delete records")
    func testDelete() async throws {
        // Given
        let repository = MockHealthRecordRepository()
        let user = try User(name: "Test User", age: 30, height: 175.0, targetWeight: 70.0)
        let record = HealthRecord(type: .weight, value: 70.0, unit: "kg")
        record.user = user
        
        try await repository.save(record)
        #expect(repository.getRecordsCount() == 1)
        
        // When
        try await repository.delete(record)
        
        // Then
        #expect(repository.getRecordsCount() == 0)
        let allRecords = try await repository.fetchRecords(for: user, type: nil, from: nil, to: nil)
        #expect(allRecords.isEmpty)
    }
    
    @Test("MockRepository should handle errors")
    func testErrorHandling() async throws {
        // Given
        let repository = MockHealthRecordRepository()
        let user = try User(name: "Test User", age: 30, height: 175.0, targetWeight: 70.0)
        let testError = NSError(domain: "TestError", code: 1, userInfo: nil)
        repository.setErrorToThrow(testError)
        
        // When & Then
        do {
            _ = try await repository.fetchRecords(for: user, type: nil, from: nil, to: nil)
            #expect(Bool(false), "Should have thrown an error")
        } catch {
            #expect(error.localizedDescription == testError.localizedDescription)
        }
    }
    
    @Test("MockRepository should sync with HealthKit")
    func testSyncWithHealthKit() async throws {
        // Given
        let repository = MockHealthRecordRepository()
        
        // When & Then - should not throw
        try await repository.syncWithHealthKit()
        #expect(true) // If we reach here, no exception was thrown
    }
}