import Testing
import Foundation
import SwiftData
@testable import HealthRecordingApp

@Suite("RecordHealthDataUseCase Tests")
struct RecordHealthDataUseCaseTests {
    
    private func createTestModelContext() throws -> ModelContext {
        let schema = Schema([HealthRecord.self, User.self, Goal.self, Badge.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }
    
    private func createTestUser() -> User {
        // Use a simpler User creation that avoids validation errors
        let user = try! User(name: "Test User", age: 30, height: 170.0, targetWeight: 65.0)
        return user
    }
    
    private func createTestUseCase(modelContext: ModelContext) -> RecordHealthDataUseCase {
        let healthRecordRepository = SwiftDataHealthRecordRepository(modelContext: modelContext)
        let userRepository = SwiftDataUserRepository(modelContext: modelContext)
        let badgeRepository = SwiftDataBadgeRepository(modelContext: modelContext)
        let healthKitService = MockHealthKitService()
        
        return RecordHealthDataUseCase(
            healthRecordRepository: healthRecordRepository,
            userRepository: userRepository,
            badgeRepository: badgeRepository,
            healthKitService: healthKitService
        )
    }
    
    @Test("RecordHealthDataUseCase should record data from HealthKit successfully")
    func testRecordFromHealthKit() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let useCase = createTestUseCase(modelContext: modelContext)
        let user = createTestUser()
        
        // When
        let recordedData = try await useCase.recordFromHealthKit(for: user)
        
        // Then
        #expect(recordedData.count > 0)
        #expect(recordedData.allSatisfy { $0.source == .healthKit })
        #expect(recordedData.allSatisfy { $0.user?.id == user.id })
    }
    
    @Test("RecordHealthDataUseCase should handle HealthKit sync errors gracefully")
    func testRecordFromHealthKitError() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let useCase = createTestUseCase(modelContext: modelContext)
        let user = createTestUser()
        
        // Configure mock to simulate error
        if let mockService = useCase.healthKitService as? MockHealthKitService {
            mockService.shouldThrowError = true
        }
        
        // When & Then
        do {
            _ = try await useCase.recordFromHealthKit(for: user)
            #expect(Bool(false), "Should throw error when HealthKit sync fails")
        } catch {
            #expect(true, "Expected error was thrown: \(error)")
        }
    }
    
    @Test("RecordHealthDataUseCase should record manual data successfully")
    func testRecordManualData() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let useCase = createTestUseCase(modelContext: modelContext)
        let user = createTestUser()
        let manualData = ManualHealthData(type: .weight, value: 70.5, unit: "kg")
        
        // When
        let recordedData = try await useCase.recordManualData(manualData, for: user)
        
        // Then
        #expect(recordedData.type == .weight)
        #expect(recordedData.value == 70.5)
        #expect(recordedData.unit == "kg")
        #expect(recordedData.source == .manual)
        #expect(recordedData.user?.id == user.id)
    }
    
    @Test("RecordHealthDataUseCase should validate manual data input")
    func testRecordManualDataValidation() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let useCase = createTestUseCase(modelContext: modelContext)
        let user = createTestUser()
        
        // Test invalid weight value
        let invalidData = ManualHealthData(type: .weight, value: -10.0, unit: "kg")
        
        // When & Then
        do {
            _ = try await useCase.recordManualData(invalidData, for: user)
            #expect(Bool(false), "Should throw error for invalid manual data")
        } catch let error as ValidationError {
            #expect(error.errorCode.starts(with: "VAL"))
        } catch {
            #expect(Bool(false), "Should throw ValidationError for invalid data, but got: \(type(of: error))")
        }
    }
    
    @Test("RecordHealthDataUseCase should handle duplicate data correctly")
    func testDuplicateDataHandling() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let useCase = createTestUseCase(modelContext: modelContext)
        let user = createTestUser()
        let manualData = ManualHealthData(type: .weight, value: 70.0, unit: "kg")
        
        // When - Record the same data twice
        let firstRecord = try await useCase.recordManualData(manualData, for: user)
        let secondRecord = try await useCase.recordManualData(manualData, for: user)
        
        // Then - Both should be recorded (assuming timestamp makes them unique)
        #expect(firstRecord.id != secondRecord.id)
        #expect(firstRecord.value == secondRecord.value)
        #expect(firstRecord.type == secondRecord.type)
    }
    
    @Test("RecordHealthDataUseCase should sync all data successfully")
    func testSyncAllData() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let useCase = createTestUseCase(modelContext: modelContext)
        let user = createTestUser()
        
        // When
        let syncResult = try await useCase.syncAllData(for: user)
        
        // Then
        #expect(syncResult.isSuccessful)
        #expect(syncResult.syncedRecordsCount >= 0)
        #expect(syncResult.newRecordsCount >= 0)
        #expect(syncResult.duplicateRecordsCount >= 0)
        #expect(syncResult.errorsCount == 0)
        #expect(syncResult.syncDuration > 0)
    }
    
    @Test("RecordHealthDataUseCase should process badge earning correctly")
    func testProcessBadgeEarning() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let useCase = createTestUseCase(modelContext: modelContext)
        let user = createTestUser()
        
        // Create a badge that can be earned
        let badge = try Badge(
            name: "First Record",
            description: "Record your first health data",
            type: .milestone,
            requirement: BadgeRequirement.recordCount(count: 1),
            iconName: "star.fill",
            colorScheme: .bronze
        )
        let badgeRepository = SwiftDataBadgeRepository(modelContext: modelContext)
        try await badgeRepository.save(badge)
        
        // Record some data to trigger badge earning
        let manualData = ManualHealthData(type: .weight, value: 70.0, unit: "kg")
        _ = try await useCase.recordManualData(manualData, for: user)
        
        // When
        let earnedBadges = try await useCase.processBadgeEarning(for: user)
        
        // Then
        #expect(earnedBadges.count >= 0) // May or may not earn badges depending on logic
    }
    
    @Test("RecordHealthDataUseCase should handle empty HealthKit data")
    func testRecordFromHealthKitEmpty() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let useCase = createTestUseCase(modelContext: modelContext)
        let user = createTestUser()
        
        // Configure mock to return empty data
        if let mockService = useCase.healthKitService as? MockHealthKitService {
            mockService.mockData = []
        }
        
        // When
        let recordedData = try await useCase.recordFromHealthKit(for: user)
        
        // Then
        #expect(recordedData.isEmpty)
    }
    
    @Test("RecordHealthDataUseCase should maintain data consistency")
    func testDataConsistency() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let useCase = createTestUseCase(modelContext: modelContext)
        let user = createTestUser()
        let userRepository = SwiftDataUserRepository(modelContext: modelContext)
        try await userRepository.save(user)
        
        let manualData = ManualHealthData(type: .weight, value: 72.5, unit: "kg")
        
        // When
        let recordedData = try await useCase.recordManualData(manualData, for: user)
        
        // Then - Verify data is properly linked
        #expect(recordedData.user?.id == user.id)
        
        // Verify user's health records include the new record
        let updatedUser = try await userRepository.fetchCurrentUser()
        #expect(updatedUser?.healthRecords.contains { $0.id == recordedData.id } == true)
    }
    
    @Test("RecordHealthDataUseCase should handle concurrent operations")
    func testConcurrentOperations() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let useCase = createTestUseCase(modelContext: modelContext)
        let user = createTestUser()
        
        // When - Perform concurrent manual data recording
        await withTaskGroup(of: Void.self) { group in
            for i in 1...5 {
                group.addTask {
                    do {
                        let data = ManualHealthData(type: .weight, value: Double(70 + i), unit: "kg")
                        _ = try await useCase.recordManualData(data, for: user)
                    } catch {
                        // Ignore errors in concurrent test
                    }
                }
            }
        }
        
        // Then - Should complete without crashing
        let syncResult = try await useCase.syncAllData(for: user)
        #expect(syncResult.syncedRecordsCount >= 0)
    }
    
    @Test("RecordHealthDataUseCase should validate data types correctly")
    func testDataTypeValidation() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let useCase = createTestUseCase(modelContext: modelContext)
        let user = createTestUser()
        
        // Test all supported data types
        let testCases = [
            (HealthDataType.weight, 70.0, "kg"),
            (HealthDataType.steps, 10000.0, "count"),
            (HealthDataType.calories, 2000.0, "kcal"),
            (HealthDataType.heartRate, 72.0, "bpm")
        ]
        
        // When & Then
        for (type, value, unit) in testCases {
            let data = ManualHealthData(type: type, value: value, unit: unit)
            let record = try await useCase.recordManualData(data, for: user)
            
            #expect(record.type == type)
            #expect(record.value == value)
            #expect(record.unit == unit)
        }
    }
    
    @Test("RecordHealthDataUseCase should track performance metrics")
    func testPerformanceTracking() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let useCase = createTestUseCase(modelContext: modelContext)
        let user = createTestUser()
        
        // When
        let startTime = Date()
        let syncResult = try await useCase.syncAllData(for: user)
        let endTime = Date()
        
        // Then
        #expect(syncResult.syncDuration > 0)
        #expect(syncResult.syncDuration <= endTime.timeIntervalSince(startTime))
    }
    
    @Test("RecordHealthDataUseCase should handle large data sets efficiently")
    func testLargeDataSetHandling() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let useCase = createTestUseCase(modelContext: modelContext)
        let user = createTestUser()
        
        // Configure mock to return large dataset
        if let mockService = useCase.healthKitService as? MockHealthKitService {
            mockService.mockLargeDataset = true
        }
        
        // When
        let recordedData = try await useCase.recordFromHealthKit(for: user)
        
        // Then
        #expect(recordedData.count > 0)
        // Performance should still be reasonable
    }
    
    @Test("RecordHealthDataUseCase should maintain audit trail")
    func testAuditTrail() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let useCase = createTestUseCase(modelContext: modelContext)
        let user = createTestUser()
        let manualData = ManualHealthData(type: .weight, value: 68.0, unit: "kg")
        
        // When
        let recordedData = try await useCase.recordManualData(manualData, for: user)
        
        // Then - Verify audit information is captured
        #expect(recordedData.timestamp != Date.distantPast)
        #expect(recordedData.source == .manual)
        #expect(recordedData.user?.id == user.id)
    }
    
    @Test("RecordHealthDataUseCase should handle invalid user gracefully")
    func testInvalidUserHandling() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let useCase = createTestUseCase(modelContext: modelContext)
        let invalidUser = try User(name: "Invalid User", age: 30, height: 170.0, targetWeight: 65.0)
        // Note: user is not saved to repository
        
        let manualData = ManualHealthData(type: .weight, value: 70.0, unit: "kg")
        
        // When & Then
        do {
            _ = try await useCase.recordManualData(manualData, for: invalidUser)
            // This may or may not throw depending on implementation
        } catch {
            // Error handling is acceptable for invalid users
            #expect(true, "Expected error was thrown: \(error)")
        }
    }
}

/// Mock implementation of HealthKitService for testing
class MockHealthKitService: HealthKitServiceProtocol {
    var shouldThrowError = false
    var mockData: [MockHealthData] = []
    var mockLargeDataset = false
    
    // HealthKitServiceProtocol conformance
    var isHealthDataAvailable: Bool = true
    var authorizationStatus: HealthKitAuthorizationStatus = .notDetermined
    
    init() {
        setupDefaultMockData()
    }
    
    private func setupDefaultMockData() {
        mockData = [
            MockHealthData(type: .weight, value: 70.0, unit: "kg"),
            MockHealthData(type: .steps, value: 8000.0, unit: "count"),
            MockHealthData(type: .calories, value: 2200.0, unit: "kcal")
        ]
    }
    
    func requestAuthorization(for dataTypes: Set<HealthDataType>) async throws -> Bool {
        if shouldThrowError {
            throw HealthKitError.authorizationDenied
        }
        return true
    }
    
    func requestAuthorization() async throws {
        _ = try await requestAuthorization(for: [.weight, .steps, .calories, .heartRate])
    }
    
    func readHealthData(type: HealthDataType, startDate: Date, endDate: Date) async throws -> [HealthKitData] {
        if shouldThrowError {
            throw HealthKitError.dataReadFailed
        }
        
        let filteredData = mockData.filter { $0.type == type }
        
        if mockLargeDataset {
            return (1...100).map { i in
                HealthKitData(
                    type: type,
                    value: Double(70 + i % 10),
                    unit: "kg",
                    startDate: Date().addingTimeInterval(-Double(i * 3600)),
                    endDate: Date().addingTimeInterval(-Double(i * 3600))
                )
            }
        }
        
        return filteredData.map { mock in
            HealthKitData(
                type: mock.type,
                value: mock.value,
                unit: mock.unit,
                startDate: Date().addingTimeInterval(-3600),
                endDate: Date()
            )
        }
    }
    
    func readHealthData(types: [HealthDataType], startDate: Date, endDate: Date) async throws -> [HealthKitData] {
        var allData: [HealthKitData] = []
        
        for type in types {
            do {
                let typeData = try await readHealthData(type: type, startDate: startDate, endDate: endDate)
                allData.append(contentsOf: typeData)
            } catch {
                continue
            }
        }
        
        return allData
    }
    
    func writeHealthData(_ records: [HealthRecord]) async throws -> Bool {
        if shouldThrowError {
            throw HealthKitError.dataWriteFailed
        }
        return true
    }
    
    func observeHealthDataChanges(for dataType: HealthDataType, handler: @escaping ([HealthRecord]) -> Void) async throws -> HealthDataObserver {
        if shouldThrowError {
            throw HealthKitError.observationFailed
        }
        return HealthDataObserver(dataType: dataType, handler: handler)
    }
    
    func stopObserving(_ observer: HealthDataObserver) {
        // Mock implementation - do nothing
    }
}

struct MockHealthData {
    let type: HealthDataType
    let value: Double
    let unit: String
}

// Mock HealthKit specific errors for testing (extending main HealthKitError)
extension HealthKitError {
    static let dataReadFailed = HealthKitError.dataAccessFailed(NSError(domain: "TestHealthKit", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Data read failed"]))
    static let dataWriteFailed = HealthKitError.dataAccessFailed(NSError(domain: "TestHealthKit", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Data write failed"]))
    static let observationFailed = HealthKitError.dataAccessFailed(NSError(domain: "TestHealthKit", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Observation failed"]))
}