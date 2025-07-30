import SwiftUI
import SwiftData
import Foundation

@Observable
final class HealthDataViewModel {
    // MARK: - Published Properties
    var healthRecords: [HealthRecord] = []
    var isLoading = false
    var errorMessage: String?
    var isSyncing = false
    var lastSyncDate: Date?
    var selectedDataType: HealthDataType = .weight
    var selectedDateRange: DateRangeOption = .week
    
    // MARK: - Computed Properties
    var filteredRecords: [HealthRecord] {
        let filtered = healthRecords.filter { $0.type == selectedDataType }
        return filterByDateRange(records: filtered, dateRange: selectedDateRange)
    }
    
    var latestRecord: HealthRecord? {
        filteredRecords.sorted { $0.timestamp > $1.timestamp }.first
    }
    
    var recordCount: Int {
        filteredRecords.count
    }
    
    var hasData: Bool {
        !healthRecords.isEmpty
    }
    
    // MARK: - Dependencies
    private let recordHealthDataUseCase: RecordHealthDataUseCaseProtocol
    private let fetchHealthDataUseCase: FetchHealthDataUseCaseProtocol
    private let logger: AILoggerProtocol
    
    // MARK: - Initialization
    init(
        recordHealthDataUseCase: RecordHealthDataUseCaseProtocol,
        fetchHealthDataUseCase: FetchHealthDataUseCaseProtocol,
        logger: AILoggerProtocol = AILogger()
    ) {
        self.recordHealthDataUseCase = recordHealthDataUseCase
        self.fetchHealthDataUseCase = fetchHealthDataUseCase
        self.logger = logger
        
        logger.debug("HealthDataViewModel initialized", context: [
            "selectedDataType": selectedDataType.rawValue,
            "selectedDateRange": selectedDateRange.rawValue
        ])
    }
    
    // MARK: - Data Loading
    @MainActor
    func loadHealthData() async {
        logger.debug("Starting health data load", context: nil)
        guard !isLoading else {
            logger.warning("Load already in progress, skipping", context: nil)
            return
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let startTime = Date()
            logger.info("Fetching health data", context: [
                "dataType": selectedDataType.rawValue,
                "dateRange": selectedDateRange.rawValue
            ])
            
            let mockUser = createMockUser()
            let records = try await fetchHealthDataUseCase.fetchHealthRecords(
                for: mockUser,
                type: nil,
                dateRange: nil,
                limit: nil
            )
            healthRecords = records
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("load_health_data", duration: duration, success: true)
            logger.info("Successfully loaded health data", context: [
                "recordCount": records.count,
                "duration_ms": Int(duration * 1000)
            ])
            
        } catch {
            let duration = Date().timeIntervalSince(Date())
            logger.logPerformance("load_health_data", duration: duration, success: false)
            logger.error(error, context: [
                "operation": "load_health_data",
                "dataType": selectedDataType.rawValue
            ])
            
            errorMessage = handleError(error)
        }
    }
    
    @MainActor
    func refreshData() async {
        logger.logUserAction("refresh_health_data", parameters: [
            "dataType": selectedDataType.rawValue,
            "currentRecordCount": healthRecords.count
        ])
        
        await loadHealthData()
    }
    
    // MARK: - HealthKit Synchronization
    @MainActor
    func syncWithHealthKit() async {
        logger.debug("Starting HealthKit synchronization", context: nil)
        guard !isSyncing else {
            logger.warning("Sync already in progress, skipping", context: nil)
            return
        }
        
        isSyncing = true
        errorMessage = nil
        defer { isSyncing = false }
        
        do {
            let startTime = Date()
            logger.info("Synchronizing with HealthKit", context: nil)
            
            // For now, we use a mock user - this will be replaced with actual user management
            let mockUser = createMockUser()
            _ = try await recordHealthDataUseCase.recordFromHealthKit(for: mockUser)
            
            // Reload data after sync
            await loadHealthData()
            
            lastSyncDate = Date()
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("healthkit_sync", duration: duration, success: true)
            logger.info("Successfully synchronized with HealthKit", context: [
                "newRecordCount": healthRecords.count,
                "duration_ms": Int(duration * 1000)
            ])
            
        } catch {
            let duration = Date().timeIntervalSince(Date())
            logger.logPerformance("healthkit_sync", duration: duration, success: false)
            logger.error(error, context: [
                "operation": "healthkit_sync"
            ])
            
            errorMessage = handleError(error)
        }
    }
    
    // MARK: - Data Filtering
    @MainActor
    func updateDataType(_ newType: HealthDataType) {
        logger.logUserAction("change_data_type", parameters: [
            "previousType": selectedDataType.rawValue,
            "newType": newType.rawValue
        ])
        
        selectedDataType = newType
    }
    
    @MainActor
    func updateDateRange(_ newRange: DateRangeOption) {
        logger.logUserAction("change_date_range", parameters: [
            "previousRange": selectedDateRange.rawValue,
            "newRange": newRange.rawValue
        ])
        
        selectedDateRange = newRange
    }
    
    // MARK: - Data Export
    @MainActor
    func exportData(format: ExportFormat) async throws -> URL {
        logger.logUserAction("export_health_data", parameters: [
            "format": format.rawValue,
            "recordCount": filteredRecords.count,
            "dataType": selectedDataType.rawValue
        ])
        
        let startTime = Date()
        
        do {
            let mockUser = createMockUser()
            let dateRange = try selectedDateRange.toDateRange()
            
            let exportResult = try await fetchHealthDataUseCase.exportHealthData(
                for: mockUser,
                format: format,
                dateRange: dateRange
            )
            
            // Save the exported data to a temporary file and return its URL
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(exportResult.filename)
            
            try exportResult.data.write(to: tempURL)
            let exportURL = tempURL
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("export_health_data", duration: duration, success: true)
            logger.info("Successfully exported health data", context: [
                "format": format.rawValue,
                "recordCount": filteredRecords.count,
                "fileURL": exportURL.absoluteString
            ])
            
            return exportURL
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("export_health_data", duration: duration, success: false)
            logger.error(error, context: [
                "operation": "export_health_data",
                "format": format.rawValue
            ])
            
            throw error
        }
    }
    
    // MARK: - Error Handling
    @MainActor
    func clearError() {
        errorMessage = nil
        logger.debug("Error message cleared by user", context: nil)
    }
    
    private func handleError(_ error: Error) -> String {
        if let healthAppError = error as? HealthAppError {
            return healthAppError.localizedDescription
        }
        return "予期しないエラーが発生しました: \(error.localizedDescription)"
    }
    
    // MARK: - Helper Methods
    private func filterByDateRange(records: [HealthRecord], dateRange: DateRangeOption) -> [HealthRecord] {
        do {
            let absoluteRange = try dateRange.toDateRange()
            return records.filter { absoluteRange.contains($0.timestamp) }
        } catch {
            logger.error(error, context: ["operation": "filter_by_date_range", "dateRange": dateRange.rawValue])
            // Fallback to returning all records if date range conversion fails
            return records
        }
    }
    
    private func createMockUser() -> User {
        // This is a temporary mock - will be replaced with proper user management
        do {
            return try User(name: "テストユーザー", age: 30, height: 175.0, targetWeight: 70.0)
        } catch {
            logger.error(error, context: ["operation": "create_mock_user"])
            // Fallback to basic initialization if validation fails
            fatalError("Failed to create mock user: \(error)")
        }
    }
}

// MARK: - Supporting Types
// Note: DateRange and ExportFormat are defined in CommonTypes.swift to avoid duplication