import Testing
import Foundation
import SwiftData
@testable import HealthRecordingApp

@Suite("HealthDataViewModel Tests")
struct HealthDataViewModelTests {
    
    private func createMockUseCases() -> (RecordHealthDataUseCaseProtocol, FetchHealthDataUseCaseProtocol, AILoggerProtocol) {
        let mockRecordUseCase = MockRecordHealthDataUseCase()
        let mockFetchUseCase = MockFetchHealthDataUseCase()
        let mockLogger = MockAILogger()
        return (mockRecordUseCase, mockFetchUseCase, mockLogger)
    }
    
    private func createViewModel() -> HealthDataViewModel {
        let (recordUseCase, fetchUseCase, logger) = createMockUseCases()
        return HealthDataViewModel(
            recordHealthDataUseCase: recordUseCase,
            fetchHealthDataUseCase: fetchUseCase,
            logger: logger
        )
    }
    
    @Test("HealthDataViewModel should initialize with default values")
    func testInitialization() async throws {
        // Given & When
        let viewModel = createViewModel()
        
        // Then
        #expect(viewModel.healthRecords.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isSyncing == false)
        #expect(viewModel.lastSyncDate == nil)
        #expect(viewModel.selectedDataType == .weight)
        #expect(viewModel.selectedDateRange == .week)
        #expect(viewModel.hasData == false)
        #expect(viewModel.recordCount == 0)
    }
    
    @Test("HealthDataViewModel should load health data successfully")
    func testLoadHealthDataSuccess() async throws {
        // Given
        let (recordUseCase, fetchUseCase, logger) = createMockUseCases()
        let mockFetchUseCase = fetchUseCase as! MockFetchHealthDataUseCase
        
        let sampleRecords = [
            HealthRecord(type: .weight, value: 70.0, unit: "kg"),
            HealthRecord(type: .steps, value: 10000.0, unit: "count")
        ]
        mockFetchUseCase.mockRecords = sampleRecords
        
        let viewModel = HealthDataViewModel(
            recordHealthDataUseCase: recordUseCase,
            fetchHealthDataUseCase: fetchUseCase,
            logger: logger
        )
        
        // When
        await viewModel.loadHealthData()
        
        // Then
        #expect(viewModel.healthRecords.count == 2)
        #expect(viewModel.hasData == true)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }
    
    @Test("HealthDataViewModel should handle load error gracefully")
    func testLoadHealthDataError() async throws {
        // Given
        let (recordUseCase, fetchUseCase, logger) = createMockUseCases()
        let mockFetchUseCase = fetchUseCase as! MockFetchHealthDataUseCase
        mockFetchUseCase.shouldThrowError = true
        
        let viewModel = HealthDataViewModel(
            recordHealthDataUseCase: recordUseCase,
            fetchHealthDataUseCase: fetchUseCase,
            logger: logger
        )
        
        // When
        await viewModel.loadHealthData()
        
        // Then
        #expect(viewModel.healthRecords.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage != nil)
    }
    
    @Test("HealthDataViewModel should filter records by selected data type")
    func testFilteredRecords() async throws {
        // Given
        let (recordUseCase, fetchUseCase, logger) = createMockUseCases()
        let mockFetchUseCase = fetchUseCase as! MockFetchHealthDataUseCase
        
        let sampleRecords = [
            HealthRecord(type: .weight, value: 70.0, unit: "kg"),
            HealthRecord(type: .weight, value: 69.5, unit: "kg"),
            HealthRecord(type: .steps, value: 10000.0, unit: "count")
        ]
        mockFetchUseCase.mockRecords = sampleRecords
        
        let viewModel = HealthDataViewModel(
            recordHealthDataUseCase: recordUseCase,
            fetchHealthDataUseCase: fetchUseCase,
            logger: logger
        )
        
        await viewModel.loadHealthData()
        
        // When - Default is weight
        let weightRecords = viewModel.filteredRecords
        
        // Then
        #expect(weightRecords.count == 2)
        #expect(weightRecords.allSatisfy { $0.type == .weight })
        
        // When - Change to steps
        await viewModel.updateDataType(.steps)
        let stepsRecords = viewModel.filteredRecords
        
        // Then
        #expect(stepsRecords.count == 1)
        #expect(stepsRecords.first?.type == .steps)
    }
    
    @Test("HealthDataViewModel should sync with HealthKit successfully")
    func testSyncWithHealthKitSuccess() async throws {
        // Given
        let (recordUseCase, fetchUseCase, logger) = createMockUseCases()
        let mockRecordUseCase = recordUseCase as! MockRecordHealthDataUseCase
        let mockFetchUseCase = fetchUseCase as! MockFetchHealthDataUseCase
        
        let viewModel = HealthDataViewModel(
            recordHealthDataUseCase: recordUseCase,
            fetchHealthDataUseCase: fetchUseCase,
            logger: logger
        )
        
        // When
        await viewModel.syncWithHealthKit()
        
        // Then
        #expect(viewModel.isSyncing == false)
        #expect(viewModel.lastSyncDate != nil)
        #expect(viewModel.errorMessage == nil)
        #expect(mockRecordUseCase.executeCallCount == 1)
    }
    
    @Test("HealthDataViewModel should handle sync error gracefully")
    func testSyncWithHealthKitError() async throws {
        // Given
        let (recordUseCase, fetchUseCase, logger) = createMockUseCases()
        let mockRecordUseCase = recordUseCase as! MockRecordHealthDataUseCase
        mockRecordUseCase.shouldThrowError = true
        
        let viewModel = HealthDataViewModel(
            recordHealthDataUseCase: recordUseCase,
            fetchHealthDataUseCase: fetchUseCase,
            logger: logger
        )
        
        // When
        await viewModel.syncWithHealthKit()
        
        // Then
        #expect(viewModel.isSyncing == false)
        #expect(viewModel.lastSyncDate == nil)
        #expect(viewModel.errorMessage != nil)
    }
    
    @Test("HealthDataViewModel should update date range correctly")
    func testUpdateDateRange() async throws {
        // Given
        let viewModel = createViewModel()
        
        // When
        await viewModel.updateDateRange(.month)
        
        // Then
        #expect(viewModel.selectedDateRange == .month)
    }
    
    @Test("HealthDataViewModel should export data successfully")
    func testExportDataSuccess() async throws {
        // Given
        let (recordUseCase, fetchUseCase, logger) = createMockUseCases()
        let mockFetchUseCase = fetchUseCase as! MockFetchHealthDataUseCase
        
        let sampleRecords = [
            HealthRecord(type: .weight, value: 70.0, unit: "kg")
        ]
        mockFetchUseCase.mockRecords = sampleRecords
        
        let viewModel = HealthDataViewModel(
            recordHealthDataUseCase: recordUseCase,
            fetchHealthDataUseCase: fetchUseCase,
            logger: logger
        )
        
        await viewModel.loadHealthData()
        
        // When
        let jsonURL = try await viewModel.exportData(format: .json)
        let csvURL = try await viewModel.exportData(format: .csv)
        
        // Then
        #expect(jsonURL.pathExtension == "json")
        #expect(csvURL.pathExtension == "csv")
    }
    
    @Test("HealthDataViewModel should clear error message")
    func testClearError() async throws {
        // Given
        let (recordUseCase, fetchUseCase, logger) = createMockUseCases()
        let mockFetchUseCase = fetchUseCase as! MockFetchHealthDataUseCase
        mockFetchUseCase.shouldThrowError = true
        
        let viewModel = HealthDataViewModel(
            recordHealthDataUseCase: recordUseCase,
            fetchHealthDataUseCase: fetchUseCase,
            logger: logger
        )
        
        await viewModel.loadHealthData()
        #expect(viewModel.errorMessage != nil)
        
        // When
        await viewModel.clearError()
        
        // Then
        #expect(viewModel.errorMessage == nil)
    }
    
    @Test("HealthDataViewModel should get latest record correctly")
    func testLatestRecord() async throws {
        // Given
        let (recordUseCase, fetchUseCase, logger) = createMockUseCases()
        let mockFetchUseCase = fetchUseCase as! MockFetchHealthDataUseCase
        
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        
        let sampleRecords = [
            HealthRecord(type: .weight, value: 70.0, unit: "kg"),
            HealthRecord(type: .weight, value: 69.5, unit: "kg")
        ]
        sampleRecords[0].timestamp = yesterday
        sampleRecords[1].timestamp = now
        
        mockFetchUseCase.mockRecords = sampleRecords
        
        let viewModel = HealthDataViewModel(
            recordHealthDataUseCase: recordUseCase,
            fetchHealthDataUseCase: fetchUseCase,
            logger: logger
        )
        
        await viewModel.loadHealthData()
        
        // When
        let latestRecord = viewModel.latestRecord
        
        // Then
        #expect(latestRecord != nil)
        #expect(latestRecord?.value == 69.5)
        #expect(latestRecord?.timestamp == now)
    }
    
    @Test("HealthDataViewModel should prevent concurrent loading")
    func testConcurrentLoadingPrevention() async throws {
        // Given
        let (recordUseCase, fetchUseCase, logger) = createMockUseCases()
        let mockFetchUseCase = fetchUseCase as! MockFetchHealthDataUseCase
        mockFetchUseCase.shouldDelay = true
        
        let viewModel = HealthDataViewModel(
            recordHealthDataUseCase: recordUseCase,
            fetchHealthDataUseCase: fetchUseCase,
            logger: logger
        )
        
        // When - Start two concurrent loads
        async let load1 = viewModel.loadHealthData()
        async let load2 = viewModel.loadHealthData()
        
        await load1
        await load2
        
        // Then - Only one load should have executed
        #expect(mockFetchUseCase.fetchCallCount == 1)
    }
}

// MARK: - Mock Classes
final class MockRecordHealthDataUseCase: RecordHealthDataUseCaseProtocol {
    var shouldThrowError = false
    var executeCallCount = 0
    
    func execute(for user: User) async throws {
        executeCallCount += 1
        
        if shouldThrowError {
            throw HealthAppError.healthKitAuthorizationDenied
        }
        
        // Simulate work
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
    }
}

final class MockFetchHealthDataUseCase: FetchHealthDataUseCaseProtocol {
    var mockRecords: [HealthRecord] = []
    var shouldThrowError = false
    var shouldDelay = false
    var fetchCallCount = 0
    
    func fetchAllHealthRecords() async throws -> [HealthRecord] {
        fetchCallCount += 1
        
        if shouldDelay {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        if shouldThrowError {
            throw HealthAppError.dataFetchFailed(underlying: NSError(domain: "Test", code: 1))
        }
        
        return mockRecords
    }
    
    func fetchHealthRecords(for user: User, type: HealthDataType?, from startDate: Date?, to endDate: Date?) async throws -> [HealthRecord] {
        return mockRecords.filter { record in
            let typeMatches = type == nil || record.type == type
            let dateMatches = (startDate == nil || record.timestamp >= startDate!) &&
                             (endDate == nil || record.timestamp <= endDate!)
            return typeMatches && dateMatches
        }
    }
    
    func fetchLatestRecord(for user: User, type: HealthDataType) async throws -> HealthRecord? {
        return mockRecords.filter { $0.type == type }.max { $0.timestamp < $1.timestamp }
    }
    
    func getHealthDataStatistics(for user: User, type: HealthDataType, from startDate: Date, to endDate: Date) async throws -> HealthDataStatistics {
        let records = mockRecords.filter { $0.type == type }
        let values = records.map { $0.value }
        
        return HealthDataStatistics(
            count: records.count,
            average: values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count),
            minimum: values.min() ?? 0,
            maximum: values.max() ?? 0,
            total: values.reduce(0, +)
        )
    }
    
    func exportHealthDataAsJSON(records: [HealthRecord]) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("export.json")
        try "[]".write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    func exportHealthDataAsCSV(records: [HealthRecord]) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("export.csv")
        try "header\n".write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    func searchHealthRecords(for user: User, criteria: HealthRecordSearchCriteria) async throws -> [HealthRecord] {
        return mockRecords
    }
    
    func fetchRecordsGroupedByDay(for user: User, type: HealthDataType, from startDate: Date, to endDate: Date) async throws -> [Date: [HealthRecord]] {
        return [:]
    }
}

final class MockAILogger: AILoggerProtocol {
    var logs: [String] = []
    
    func debug(_ message: String, context: [String : Any]?) {
        logs.append("DEBUG: \(message)")
    }
    
    func info(_ message: String, context: [String : Any]?) {
        logs.append("INFO: \(message)")
    }
    
    func warning(_ message: String, context: [String : Any]?) {
        logs.append("WARNING: \(message)")
    }
    
    func error(_ error: Error, context: [String : Any]?) {
        logs.append("ERROR: \(error.localizedDescription)")
    }
    
    func logUserAction(_ action: String, parameters: [String : Any]?) {
        logs.append("USER_ACTION: \(action)")
    }
    
    func logPerformance(_ operation: String, duration: TimeInterval, success: Bool) {
        logs.append("PERFORMANCE: \(operation) - \(duration)ms - \(success)")
    }
}