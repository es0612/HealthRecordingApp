import SwiftUI
import SwiftData
import Foundation

@Observable
final class HealthDataViewModel {
    // MARK: - Published Properties
    var healthRecords: [HealthRecord] = []
    var allHealthRecords: [HealthRecord] = []
    var isLoading = false
    var errorMessage: String?
    var isSyncing = false
    var lastSyncDate: Date?
    var selectedDataType: HealthDataType = .weight
    var selectedDateRange: DateRangeOption = .week
    
    // MARK: - Integration Properties
    var dataQualityScore: Double = 0.0
    var healthKitRecordsCount: Int = 0
    var manualRecordsCount: Int = 0
    var duplicatesRemoved: Int = 0
    var integrationMetrics: IntegrationMetrics?
    
    // MARK: - Computed Properties
    var filteredRecords: [HealthRecord] {
        let filtered = allHealthRecords.filter { $0.type == selectedDataType }
        return filterByDateRange(records: filtered, dateRange: selectedDateRange)
    }
    
    var latestRecord: HealthRecord? {
        filteredRecords.sorted { $0.timestamp > $1.timestamp }.first
    }
    
    var recordCount: Int {
        filteredRecords.count
    }
    
    var hasData: Bool {
        !allHealthRecords.isEmpty
    }
    
    var dataSourceSummary: String {
        let total = allHealthRecords.count
        guard total > 0 else { return "データなし" }
        
        let healthKitRatio = Double(healthKitRecordsCount) / Double(total) * 100
        let manualRatio = Double(manualRecordsCount) / Double(total) * 100
        
        return String(format: "HealthKit: %.0f%% (%d件), 手動: %.0f%% (%d件)", 
                     healthKitRatio, healthKitRecordsCount, 
                     manualRatio, manualRecordsCount)
    }
    
    // MARK: - Dependencies
    private let integratedHealthDataService: IntegratedHealthDataServiceProtocol
    private let recordHealthDataUseCase: RecordHealthDataUseCaseProtocol
    private let fetchHealthDataUseCase: FetchHealthDataUseCaseProtocol
    private let logger: AILoggerProtocol
    
    // MARK: - Initialization
    init(
        integratedHealthDataService: IntegratedHealthDataServiceProtocol,
        recordHealthDataUseCase: RecordHealthDataUseCaseProtocol,
        fetchHealthDataUseCase: FetchHealthDataUseCaseProtocol,
        logger: AILoggerProtocol = AILogger()
    ) {
        self.integratedHealthDataService = integratedHealthDataService
        self.recordHealthDataUseCase = recordHealthDataUseCase
        self.fetchHealthDataUseCase = fetchHealthDataUseCase
        self.logger = logger
        
        logger.debug("HealthDataViewModel initialized with integrated service", context: [
            "selectedDataType": selectedDataType.rawValue,
            "selectedDateRange": selectedDateRange.rawValue
        ])
    }
    
    // Convenience initializer for backward compatibility
    convenience init(
        recordHealthDataUseCase: RecordHealthDataUseCaseProtocol,
        fetchHealthDataUseCase: FetchHealthDataUseCaseProtocol,
        logger: AILoggerProtocol = AILogger()
    ) {
        let integratedService = IntegratedHealthDataService(
            fetchHealthDataUseCase: fetchHealthDataUseCase,
            recordHealthDataUseCase: recordHealthDataUseCase,
            healthKitService: HealthKitService(),
            logger: logger
        )
        
        self.init(
            integratedHealthDataService: integratedService,
            recordHealthDataUseCase: recordHealthDataUseCase,
            fetchHealthDataUseCase: fetchHealthDataUseCase,
            logger: logger
        )
    }
    
    // MARK: - Data Loading
    @MainActor
    func loadHealthData() async {
        logger.debug("Starting integrated health data load", context: nil)
        guard !isLoading else {
            logger.warning("Load already in progress, skipping", context: nil)
            return
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let startTime = Date()
            logger.info("Fetching integrated health data", context: [
                "dataType": selectedDataType.rawValue,
                "dateRange": selectedDateRange.rawValue
            ])
            
            let mockUser = createMockUser()
            let result = try await integratedHealthDataService.fetchIntegratedHealthData(
                for: mockUser,
                types: nil, // Fetch all types
                dateRange: nil,
                limit: nil
            )
            
            // Update all health records and integration metrics
            allHealthRecords = result.records
            healthRecords = result.records // For backward compatibility
            dataQualityScore = result.dataQualityScore
            healthKitRecordsCount = result.healthKitRecords
            manualRecordsCount = result.manualRecords
            duplicatesRemoved = result.duplicatesRemoved
            integrationMetrics = result.integrationMetrics
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("load_integrated_health_data", duration: duration, success: true)
            logger.info("Successfully loaded integrated health data", context: [
                "totalRecords": result.totalRecords,
                "healthKitRecords": result.healthKitRecords,
                "manualRecords": result.manualRecords,
                "duplicatesRemoved": result.duplicatesRemoved,
                "dataQualityScore": result.dataQualityScore,
                "duration_ms": Int(duration * 1000)
            ])
            
        } catch {
            let duration = Date().timeIntervalSince(Date())
            logger.logPerformance("load_integrated_health_data", duration: duration, success: false)
            logger.error(error, context: [
                "operation": "load_integrated_health_data",
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
        logger.debug("Starting integrated HealthKit synchronization", context: nil)
        guard !isSyncing else {
            logger.warning("Sync already in progress, skipping", context: nil)
            return
        }
        
        isSyncing = true
        errorMessage = nil
        defer { isSyncing = false }
        
        do {
            let startTime = Date()
            logger.info("Synchronizing and merging all data sources", context: nil)
            
            let mockUser = createMockUser()
            let result = try await integratedHealthDataService.syncAndMergeAllSources(for: mockUser)
            
            // Update integration metrics from sync result
            dataQualityScore = result.dataQualityScore
            healthKitRecordsCount = result.healthKitRecords
            manualRecordsCount = result.manualRecords
            duplicatesRemoved = result.duplicatesRemoved
            
            // Reload data after sync to get the integrated view
            await loadHealthData()
            
            lastSyncDate = Date()
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("integrated_sync", duration: duration, success: true)
            logger.info("Successfully synchronized and merged all sources", context: [
                "totalProcessed": result.totalRecordsProcessed,
                "finalIntegrated": result.finalIntegratedRecords,
                "newHealthKitRecords": result.newHealthKitRecords,
                "duplicatesRemoved": result.duplicatesRemoved,
                "dataQualityScore": result.dataQualityScore,
                "duration_ms": Int(duration * 1000)
            ])
            
        } catch {
            let duration = Date().timeIntervalSince(Date())
            logger.logPerformance("integrated_sync", duration: duration, success: false)
            logger.error(error, context: [
                "operation": "integrated_sync"
            ])
            
            errorMessage = handleError(error)
        }
    }
    
    // MARK: - Integration-Specific Methods
    
    @MainActor
    func refreshAllData() async {
        logger.logUserAction("refresh_all_data", parameters: [
            "currentDataQualityScore": dataQualityScore,
            "currentTotalRecords": allHealthRecords.count
        ])
        
        await syncWithHealthKit()
    }
    
    @MainActor
    func loadHealthRecords(for dataType: HealthDataType) async {
        logger.debug("Loading records for specific data type", context: [
            "dataType": dataType.rawValue
        ])
        
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let mockUser = createMockUser()
            let result = try await integratedHealthDataService.fetchIntegratedHealthData(
                for: mockUser,
                types: [dataType],
                dateRange: nil,
                limit: 100
            )
            
            // Update records for this specific type while preserving others
            let existingOtherTypes = allHealthRecords.filter { $0.type != dataType }
            allHealthRecords = existingOtherTypes + result.records
            healthRecords = allHealthRecords // For backward compatibility
            
            // Update integration metrics
            dataQualityScore = result.dataQualityScore
            
            logger.info("Successfully loaded records for data type", context: [
                "dataType": dataType.rawValue,
                "recordCount": result.totalRecords,
                "qualityScore": result.dataQualityScore
            ])
            
        } catch {
            logger.error(error, context: [
                "operation": "load_records_for_type",
                "dataType": dataType.rawValue
            ])
            errorMessage = handleError(error)
        }
    }
    
    func getLatestRecord(for dataType: HealthDataType) -> HealthRecord? {
        return allHealthRecords
            .filter { $0.type == dataType }
            .sorted { $0.timestamp > $1.timestamp }
            .first
    }
    
    @MainActor
    func getDataQualityMetrics(for dataType: HealthDataType) async -> DataQualityMetrics? {
        logger.debug("Getting data quality metrics", context: [
            "dataType": dataType.rawValue
        ])
        
        do {
            let mockUser = createMockUser()
            let dateRange = try selectedDateRange.toDateRange()
            
            let metrics = try await integratedHealthDataService.getDataQualityMetrics(
                for: mockUser,
                type: dataType,
                dateRange: dateRange
            )
            
            logger.info("Successfully retrieved data quality metrics", context: [
                "dataType": dataType.rawValue,
                "completenessScore": metrics.completenessScore,
                "accuracyScore": metrics.accuracyScore,
                "consistencyScore": metrics.consistencyScore,
                "overallQuality": metrics.overallQuality
            ])
            
            return metrics
            
        } catch {
            logger.error(error, context: [
                "operation": "get_data_quality_metrics",
                "dataType": dataType.rawValue
            ])
            return nil
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