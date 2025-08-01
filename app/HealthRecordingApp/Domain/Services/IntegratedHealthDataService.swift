import Foundation
import SwiftData

// MARK: - Integrated Health Data Service Protocol

/// Service that provides seamless integration between HealthKit and manual health data
/// Handles data merging, deduplication, and prioritization
protocol IntegratedHealthDataServiceProtocol {
    /// Fetch integrated health data with automatic merging and deduplication
    func fetchIntegratedHealthData(
        for user: User,
        types: Set<HealthDataType>?,
        dateRange: DateRange?,
        limit: Int?
    ) async throws -> IntegratedHealthDataResult
    
    /// Get the latest record for a specific data type from all sources
    func getLatestIntegratedRecord(
        for user: User,
        type: HealthDataType
    ) async throws -> HealthRecord?
    
    /// Sync and merge data from all sources with conflict resolution
    func syncAndMergeAllSources(for user: User) async throws -> DataIntegrationResult
    
    /// Get data quality metrics for integrated dataset
    func getDataQualityMetrics(
        for user: User,
        type: HealthDataType,
        dateRange: DateRange
    ) async throws -> DataQualityMetrics
}

// MARK: - Integrated Health Data Service Implementation

final class IntegratedHealthDataService: IntegratedHealthDataServiceProtocol {
    
    // MARK: - Dependencies
    
    private let fetchHealthDataUseCase: FetchHealthDataUseCaseProtocol
    private let recordHealthDataUseCase: RecordHealthDataUseCaseProtocol
    private let healthKitService: HealthKitServiceProtocol
    private let logger: AILoggerProtocol
    
    // MARK: - Configuration
    
    private let dataSourcePriority: [DataSource] = [.healthKit, .manual]
    private let duplicateDetectionThreshold: TimeInterval = 300 // 5 minutes
    
    // MARK: - Initialization
    
    init(
        fetchHealthDataUseCase: FetchHealthDataUseCaseProtocol,
        recordHealthDataUseCase: RecordHealthDataUseCaseProtocol,
        healthKitService: HealthKitServiceProtocol,
        logger: AILoggerProtocol = AILogger()
    ) {
        self.fetchHealthDataUseCase = fetchHealthDataUseCase
        self.recordHealthDataUseCase = recordHealthDataUseCase
        self.healthKitService = healthKitService
        self.logger = logger
    }
    
    // MARK: - IntegratedHealthDataServiceProtocol Implementation
    
    func fetchIntegratedHealthData(
        for user: User,
        types: Set<HealthDataType>?,
        dateRange: DateRange?,
        limit: Int?
    ) async throws -> IntegratedHealthDataResult {
        
        let startTime = Date()
        
        logger.info("Fetching integrated health data", context: [
            "user_id": user.id.uuidString,
            "data_types": types?.map { $0.rawValue } ?? ["all"],
            "has_date_range": dateRange != nil,
            "limit": limit as Any
        ])
        
        do {
            var allRecords: [HealthRecord] = []
            
            // Fetch data for each requested type or all types
            let typesToFetch = types ?? Set(HealthDataType.allCases)
            
            for dataType in typesToFetch {
                let typeRecords = try await fetchHealthDataUseCase.fetchHealthRecords(
                    for: user,
                    type: dataType,
                    dateRange: dateRange,
                    limit: limit
                )
                allRecords.append(contentsOf: typeRecords)
            }
            
            // Apply data integration and deduplication
            let integratedRecords = await integrateAndDeduplicateRecords(allRecords)
            
            // Apply limit to final integrated result
            let finalRecords = if let limit = limit, limit > 0 {
                Array(integratedRecords.prefix(limit))
            } else {
                integratedRecords
            }
            
            // Calculate integration metrics
            let metrics = calculateIntegrationMetrics(
                originalRecords: allRecords,
                integratedRecords: finalRecords
            )
            
            let result = IntegratedHealthDataResult(
                records: finalRecords,
                totalRecords: finalRecords.count,
                healthKitRecords: finalRecords.filter { $0.source == .healthKit }.count,
                manualRecords: finalRecords.filter { $0.source == .manual }.count,
                duplicatesRemoved: metrics.duplicatesRemoved,
                dataQualityScore: metrics.qualityScore,
                integrationMetrics: metrics
            )
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("fetch_integrated_health_data", duration: duration, success: true)
            
            logger.info("Successfully fetched integrated health data", context: [
                "total_records": result.totalRecords,
                "healthkit_records": result.healthKitRecords,
                "manual_records": result.manualRecords,
                "duplicates_removed": result.duplicatesRemoved,
                "quality_score": result.dataQualityScore,
                "duration_seconds": duration
            ])
            
            return result
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("fetch_integrated_health_data", duration: duration, success: false)
            
            logger.error(error, context: [
                "user_id": user.id.uuidString,
                "operation": "fetch_integrated_health_data"
            ])
            
            throw IntegrationError.dataFetchFailed(error)
        }
    }
    
    func getLatestIntegratedRecord(
        for user: User,
        type: HealthDataType
    ) async throws -> HealthRecord? {
        
        logger.info("Getting latest integrated record", context: [
            "user_id": user.id.uuidString,
            "data_type": type.rawValue
        ])
        
        do {
            // Fetch all records of this type
            let allRecords = try await fetchHealthDataUseCase.fetchHealthRecords(
                for: user,
                type: type,
                dateRange: nil,
                limit: 50 // Get recent records for analysis
            )
            
            // Apply integration and deduplication
            let integratedRecords = await integrateAndDeduplicateRecords(allRecords)
            
            // Return most recent record
            let latestRecord = integratedRecords.max { $0.timestamp < $1.timestamp }
            
            logger.info("Successfully retrieved latest integrated record", context: [
                "found_record": latestRecord != nil,
                "record_source": latestRecord?.source.rawValue as Any,
                "timestamp": latestRecord?.timestamp.ISO8601Format() as Any
            ])
            
            return latestRecord
            
        } catch {
            logger.error(error, context: [
                "user_id": user.id.uuidString,
                "data_type": type.rawValue,
                "operation": "get_latest_integrated_record"
            ])
            
            throw IntegrationError.latestRecordFetchFailed(error)
        }
    }
    
    func syncAndMergeAllSources(for user: User) async throws -> DataIntegrationResult {
        
        let startTime = Date()
        
        logger.info("Starting sync and merge from all sources", context: [
            "user_id": user.id.uuidString,
            "operation": "sync_and_merge_all_sources"
        ])
        
        do {
            // Step 1: Sync fresh data from HealthKit
            let healthKitRecords = try await recordHealthDataUseCase.recordFromHealthKit(for: user)
            
            // Step 2: Get all existing records
            let allRecords = try await fetchHealthDataUseCase.fetchHealthRecords(
                for: user,
                type: nil,
                dateRange: nil,
                limit: nil
            )
            
            // Step 3: Apply integration and conflict resolution
            let integratedRecords = await integrateAndDeduplicateRecords(allRecords)
            
            // Step 4: Calculate integration results
            let healthKitCount = integratedRecords.filter { $0.source == .healthKit }.count
            let manualCount = integratedRecords.filter { $0.source == .manual }.count
            let duplicatesRemoved = allRecords.count - integratedRecords.count
            
            // Step 5: Calculate data coverage metrics
            let coverageMetrics = await calculateDataCoverageMetrics(
                integratedRecords: integratedRecords,
                user: user
            )
            
            let duration = Date().timeIntervalSince(startTime)
            
            let result = DataIntegrationResult(
                totalRecordsProcessed: allRecords.count,
                finalIntegratedRecords: integratedRecords.count,
                healthKitRecords: healthKitCount,
                manualRecords: manualCount,
                duplicatesRemoved: duplicatesRemoved,
                newHealthKitRecords: healthKitRecords.count,
                dataQualityScore: coverageMetrics.overallQuality,
                integrationDuration: duration,
                coverageMetrics: coverageMetrics
            )
            
            logger.logPerformance("sync_and_merge_all_sources", duration: duration, success: true)
            
            logger.info("Successfully completed sync and merge", context: [
                "total_processed": result.totalRecordsProcessed,
                "final_integrated": result.finalIntegratedRecords,
                "duplicates_removed": result.duplicatesRemoved,
                "new_healthkit_records": result.newHealthKitRecords,
                "quality_score": result.dataQualityScore,
                "duration_seconds": duration
            ])
            
            return result
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("sync_and_merge_all_sources", duration: duration, success: false)
            
            logger.error(error, context: [
                "user_id": user.id.uuidString,
                "operation": "sync_and_merge_all_sources"
            ])
            
            throw IntegrationError.syncAndMergeFailed(error)
        }
    }
    
    func getDataQualityMetrics(
        for user: User,
        type: HealthDataType,
        dateRange: DateRange
    ) async throws -> DataQualityMetrics {
        
        logger.info("Calculating data quality metrics", context: [
            "user_id": user.id.uuidString,
            "data_type": type.rawValue,
            "date_range_days": dateRange.dayCount
        ])
        
        do {
            // Fetch records for the specified period
            let records = try await fetchHealthDataUseCase.fetchHealthRecords(
                for: user,
                type: type,
                dateRange: dateRange,
                limit: nil
            )
            
            let integratedRecords = await integrateAndDeduplicateRecords(records)
            
            // Calculate quality metrics
            let metrics = await calculateDataQualityMetrics(
                records: integratedRecords,
                type: type,
                dateRange: dateRange
            )
            
            logger.info("Successfully calculated data quality metrics", context: [
                "completeness_score": metrics.completenessScore,
                "accuracy_score": metrics.accuracyScore,
                "consistency_score": metrics.consistencyScore,
                "overall_quality": metrics.overallQuality
            ])
            
            return metrics
            
        } catch {
            logger.error(error, context: [
                "user_id": user.id.uuidString,
                "data_type": type.rawValue,
                "operation": "get_data_quality_metrics"
            ])
            
            throw IntegrationError.qualityAnalysisFailed(error)
        }
    }
    
    // MARK: - Private Integration Methods
    
    private func integrateAndDeduplicateRecords(_ records: [HealthRecord]) async -> [HealthRecord] {
        logger.info("Starting data integration and deduplication", context: [
            "input_records": records.count
        ])
        
        // Group records by data type and time windows
        var integratedRecords: [HealthRecord] = []
        let groupedByType = Dictionary(grouping: records) { $0.type }
        
        for (dataType, typeRecords) in groupedByType {
            logger.debug("Processing integration for data type", context: [
                "data_type": dataType.rawValue,
                "records_count": typeRecords.count
            ])
            
            let integratedTypeRecords = await integrateRecordsForType(typeRecords, dataType: dataType)
            integratedRecords.append(contentsOf: integratedTypeRecords)
        }
        
        // Sort by timestamp (most recent first)
        integratedRecords.sort { $0.timestamp > $1.timestamp }
        
        logger.info("Completed data integration and deduplication", context: [
            "input_records": records.count,
            "output_records": integratedRecords.count,
            "duplicates_removed": records.count - integratedRecords.count
        ])
        
        return integratedRecords
    }
    
    private func integrateRecordsForType(_ records: [HealthRecord], dataType: HealthDataType) async -> [HealthRecord] {
        // Sort records by timestamp
        let sortedRecords = records.sorted { $0.timestamp < $1.timestamp }
        var integratedRecords: [HealthRecord] = []
        var processedTimeWindows: Set<TimeInterval> = []
        
        for record in sortedRecords {
            let timeWindow = record.timestamp.timeIntervalSince1970
            let normalizedWindow = (timeWindow / duplicateDetectionThreshold).rounded() * duplicateDetectionThreshold
            
            // Check if we already have a record in this time window
            if processedTimeWindows.contains(normalizedWindow) {
                // Find existing record in this window
                if let existingIndex = integratedRecords.firstIndex(where: {
                    abs($0.timestamp.timeIntervalSince1970 - normalizedWindow) < duplicateDetectionThreshold
                }) {
                    
                    let existingRecord = integratedRecords[existingIndex]
                    
                    // Apply source priority for conflict resolution
                    let preferredRecord = resolveDataConflict(existing: existingRecord, new: record)
                    integratedRecords[existingIndex] = preferredRecord
                    
                    logger.debug("Resolved data conflict", context: [
                        "data_type": dataType.rawValue,
                        "existing_source": existingRecord.source.rawValue,
                        "new_source": record.source.rawValue,
                        "preferred_source": preferredRecord.source.rawValue,
                        "time_window": normalizedWindow
                    ])
                }
            } else {
                // No conflict, add the record
                integratedRecords.append(record)
                processedTimeWindows.insert(normalizedWindow)
            }
        }
        
        return integratedRecords
    }
    
    private func resolveDataConflict(existing: HealthRecord, new: HealthRecord) -> HealthRecord {
        // Priority-based conflict resolution
        let existingPriority = dataSourcePriority.firstIndex(of: existing.source) ?? dataSourcePriority.count
        let newPriority = dataSourcePriority.firstIndex(of: new.source) ?? dataSourcePriority.count
        
        // Lower index = higher priority
        if newPriority < existingPriority {
            return new
        } else if existingPriority < newPriority {
            return existing
        } else {
            // Same priority, prefer more recent timestamp
            return new.timestamp > existing.timestamp ? new : existing
        }
    }
    
    private func calculateIntegrationMetrics(
        originalRecords: [HealthRecord],
        integratedRecords: [HealthRecord]
    ) -> IntegrationMetrics {
        
        let duplicatesRemoved = originalRecords.count - integratedRecords.count
        let healthKitCount = integratedRecords.filter { $0.source == .healthKit }.count
        let manualCount = integratedRecords.filter { $0.source == .manual }.count
        
        // Calculate quality score based on data source distribution and completeness
        let healthKitRatio = Double(healthKitCount) / Double(integratedRecords.count.max(1))
        let qualityScore = min(1.0, healthKitRatio * 0.8 + 0.2) // HealthKit weighted higher
        
        return IntegrationMetrics(
            duplicatesRemoved: duplicatesRemoved,
            qualityScore: qualityScore,
            healthKitRatio: healthKitRatio,
            manualRatio: Double(manualCount) / Double(integratedRecords.count.max(1)),
            integrationEfficiency: Double(integratedRecords.count) / Double(originalRecords.count.max(1))
        )
    }
    
    private func calculateDataCoverageMetrics(
        integratedRecords: [HealthRecord],
        user: User
    ) async -> DataCoverageMetrics {
        
        let dataTypes = Set(integratedRecords.map { $0.type })
        let totalDays = Calendar.current.dateInterval(from: integratedRecords.first?.timestamp ?? Date(), to: integratedRecords.last?.timestamp ?? Date())?.duration ?? 0
        let daysCovered = totalDays / (24 * 60 * 60)
        
        var typeMetrics: [HealthDataType: Double] = [:]
        
        for dataType in dataTypes {
            let typeRecords = integratedRecords.filter { $0.type == dataType }
            let coverage = Double(typeRecords.count) / max(1.0, daysCovered)
            typeMetrics[dataType] = min(1.0, coverage)
        }
        
        let overallCoverage = typeMetrics.values.reduce(0, +) / Double(typeMetrics.count.max(1))
        let qualityScore = min(1.0, overallCoverage * 0.7 + 0.3)
        
        return DataCoverageMetrics(
            totalDataTypes: dataTypes.count,
            daysCovered: Int(daysCovered),
            recordsPerDay: Double(integratedRecords.count) / max(1.0, daysCovered),
            typeSpecificMetrics: typeMetrics,
            overallCoverage: overallCoverage,
            overallQuality: qualityScore
        )
    }
    
    private func calculateDataQualityMetrics(
        records: [HealthRecord],
        type: HealthDataType,
        dateRange: DateRange
    ) async -> DataQualityMetrics {
        
        let totalDays = dateRange.dayCount
        let actualRecords = records.count
        let expectedRecords = totalDays // Assuming daily records as ideal
        
        // Completeness: how much of the expected data we have
        let completenessScore = min(1.0, Double(actualRecords) / Double(expectedRecords.max(1)))
        
        // Accuracy: based on data source reliability (HealthKit preferred)
        let healthKitCount = records.filter { $0.source == .healthKit }.count
        let accuracyScore = Double(healthKitCount) / Double(actualRecords.max(1)) * 0.9 + 0.1
        
        // Consistency: check for outliers and data anomalies
        let values = records.map { $0.value }
        let consistencyScore = calculateConsistencyScore(values: values, dataType: type)
        
        // Overall quality score
        let overallQuality = (completenessScore * 0.4 + accuracyScore * 0.4 + consistencyScore * 0.2)
        
        return DataQualityMetrics(
            completenessScore: completenessScore,
            accuracyScore: accuracyScore,
            consistencyScore: consistencyScore,
            overallQuality: overallQuality,
            totalRecords: actualRecords,
            healthKitRecords: healthKitCount,
            manualRecords: actualRecords - healthKitCount,
            dateRange: dateRange
        )
    }
    
    private func calculateConsistencyScore(values: [Double], dataType: HealthDataType) -> Double {
        guard values.count > 1 else { return 1.0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        let standardDeviation = sqrt(variance)
        
        // Define reasonable variation thresholds by data type
        let expectedVariationThreshold: Double
        switch dataType {
        case .weight:
            expectedVariationThreshold = 5.0 // 5kg variation seems reasonable
        case .steps:
            expectedVariationThreshold = 5000 // 5000 steps variation
        case .calories:
            expectedVariationThreshold = 500 // 500 calorie variation
        case .heartRate:
            expectedVariationThreshold = 20 // 20 bpm variation
        case .bloodGlucose:
            expectedVariationThreshold = 30 // 30 mg/dL variation
        }
        
        // Calculate consistency score based on standard deviation vs expected variation
        let consistencyScore = max(0.0, 1.0 - (standardDeviation / expectedVariationThreshold))
        return min(1.0, consistencyScore)
    }
}

// MARK: - Supporting Types

struct IntegratedHealthDataResult {
    let records: [HealthRecord]
    let totalRecords: Int
    let healthKitRecords: Int
    let manualRecords: Int
    let duplicatesRemoved: Int
    let dataQualityScore: Double
    let integrationMetrics: IntegrationMetrics
}

struct DataIntegrationResult {
    let totalRecordsProcessed: Int
    let finalIntegratedRecords: Int
    let healthKitRecords: Int
    let manualRecords: Int
    let duplicatesRemoved: Int
    let newHealthKitRecords: Int
    let dataQualityScore: Double
    let integrationDuration: TimeInterval
    let coverageMetrics: DataCoverageMetrics
}

struct IntegrationMetrics {
    let duplicatesRemoved: Int
    let qualityScore: Double
    let healthKitRatio: Double
    let manualRatio: Double
    let integrationEfficiency: Double
}

struct DataCoverageMetrics {
    let totalDataTypes: Int
    let daysCovered: Int
    let recordsPerDay: Double
    let typeSpecificMetrics: [HealthDataType: Double]
    let overallCoverage: Double
    let overallQuality: Double
}

struct DataQualityMetrics {
    let completenessScore: Double
    let accuracyScore: Double
    let consistencyScore: Double
    let overallQuality: Double
    let totalRecords: Int
    let healthKitRecords: Int
    let manualRecords: Int
    let dateRange: DateRange
}

// MARK: - Integration Errors

enum IntegrationError: Error, LocalizedError {
    case dataFetchFailed(Error)
    case latestRecordFetchFailed(Error)
    case syncAndMergeFailed(Error)
    case qualityAnalysisFailed(Error)
    case conflictResolutionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .dataFetchFailed(let error):
            return "Failed to fetch integrated health data: \(error.localizedDescription)"
        case .latestRecordFetchFailed(let error):
            return "Failed to fetch latest integrated record: \(error.localizedDescription)"
        case .syncAndMergeFailed(let error):
            return "Failed to sync and merge data sources: \(error.localizedDescription)"
        case .qualityAnalysisFailed(let error):
            return "Failed to analyze data quality: \(error.localizedDescription)"
        case .conflictResolutionFailed(let message):
            return "Failed to resolve data conflict: \(message)"
        }
    }
}

// MARK: - Extensions

private extension Int {
    func max(_ other: Int) -> Int {
        return Swift.max(self, other)
    }
}

private extension Double {
    func max(_ other: Double) -> Double {
        return Swift.max(self, other)
    }
}