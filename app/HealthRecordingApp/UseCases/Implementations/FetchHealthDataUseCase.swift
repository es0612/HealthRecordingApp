import Foundation
import SwiftData

/// Use Case for fetching and analyzing health data
/// Implements comprehensive data retrieval, filtering, and analysis capabilities
final class FetchHealthDataUseCase: FetchHealthDataUseCaseProtocol {
    
    // MARK: - Dependencies
    
    private let healthRecordRepository: HealthRecordRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let logger: AILoggerProtocol
    
    // MARK: - Initialization
    
    init(
        healthRecordRepository: HealthRecordRepositoryProtocol,
        userRepository: UserRepositoryProtocol,
        logger: AILoggerProtocol
    ) {
        self.healthRecordRepository = healthRecordRepository
        self.userRepository = userRepository
        self.logger = logger
    }
    
    // MARK: - FetchHealthDataUseCaseProtocol Implementation
    
    func fetchHealthRecords(
        for user: User,
        type: HealthDataType?,
        dateRange: DateRange?,
        limit: Int?
    ) async throws -> [HealthRecord] {
        
        let startTime = Date()
        logger.info("Fetching health records", context: [
            "user_id": user.id.uuidString,
            "data_type": type?.rawValue ?? "all",
            "has_date_range": dateRange != nil,
            "limit": limit as Any
        ])
        
        do {
            // Validate user exists
            let currentUser = try await userRepository.fetchCurrentUser()
            guard currentUser?.id == user.id else {
                throw ValidationError.invalidInput("User", value: user.id.uuidString, reason: "User not found or not current user")
            }
            
            // Convert date range for repository call
            let startDate = dateRange?.startDate
            let endDate = dateRange?.endDate
            
            // Fetch records from repository
            var records = try await healthRecordRepository.fetchRecords(
                for: user,
                type: type,
                from: startDate,
                to: endDate
            )
            
            // Apply limit if specified
            if let limit = limit, limit > 0 {
                records = Array(records.prefix(limit))
            }
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("fetch_health_records", duration: duration, success: true)
            logger.info("Successfully fetched health records", context: [
                "records_count": records.count,
                "execution_time": duration
            ])
            
            return records
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("fetch_health_records", duration: duration, success: false)
            logger.error(error, context: [
                "user_id": user.id.uuidString,
                "data_type": type?.rawValue as Any
            ])
            throw error
        }
    }
    
    func fetchLatestRecord(
        for user: User,
        type: HealthDataType
    ) async throws -> HealthRecord? {
        
        logger.info("Fetching latest record", context: [
            "user_id": user.id.uuidString,
            "data_type": type.rawValue
        ])
        
        do {
            // Validate user exists
            let currentUser = try await userRepository.fetchCurrentUser()
            guard currentUser?.id == user.id else {
                throw ValidationError.invalidInput("User", value: user.id.uuidString, reason: "User not found or not current user")
            }
            
            // Fetch records of the specified type
            let records = try await healthRecordRepository.fetchRecords(
                for: user,
                type: type,
                from: nil,
                to: nil
            )
            
            // Return the most recent record
            let latestRecord = records.max { $0.timestamp < $1.timestamp }
            
            logger.info("Successfully fetched latest record", context: [
                "found_record": latestRecord != nil,
                "latest_timestamp": latestRecord?.timestamp.ISO8601Format() as Any
            ])
            
            return latestRecord
            
        } catch {
            logger.error(error, context: [
                "user_id": user.id.uuidString,
                "data_type": type.rawValue
            ])
            throw error
        }
    }
    
    func fetchRecordsGroupedByDay(
        for user: User,
        type: HealthDataType,
        dateRange: DateRange
    ) async throws -> [Date: [HealthRecord]] {
        
        logger.info("Fetching records grouped by day", context: [
            "user_id": user.id.uuidString,
            "data_type": type.rawValue,
            "date_range_days": dateRange.dayCount
        ])
        
        do {
            // Fetch records within the date range
            let records = try await fetchHealthRecords(
                for: user,
                type: type,
                dateRange: dateRange,
                limit: nil
            )
            
            // Group records by day
            var groupedRecords: [Date: [HealthRecord]] = [:]
            let calendar = Calendar.current
            
            for record in records {
                let dayStart = calendar.startOfDay(for: record.timestamp)
                
                if groupedRecords[dayStart] == nil {
                    groupedRecords[dayStart] = []
                }
                groupedRecords[dayStart]?.append(record)
            }
            
            logger.info("Successfully grouped records by day", context: [
                "total_records": records.count,
                "grouped_days": groupedRecords.count
            ])
            
            return groupedRecords
            
        } catch {
            logger.error(error, context: [
                "user_id": user.id.uuidString,
                "data_type": type.rawValue
            ])
            throw error
        }
    }
    
    func getHealthDataStatistics(
        for user: User,
        type: HealthDataType,
        dateRange: DateRange
    ) async throws -> HealthDataStatistics {
        
        logger.info("Calculating health data statistics", context: [
            "user_id": user.id.uuidString,
            "data_type": type.rawValue,
            "date_range_days": dateRange.dayCount
        ])
        
        do {
            // Fetch records for the specified period
            let records = try await fetchHealthRecords(
                for: user,
                type: type,
                dateRange: dateRange,
                limit: nil
            )
            
            // Create statistics object
            let statistics = HealthDataStatistics(
                dataType: type,
                dateRange: dateRange,
                records: records
            )
            
            logger.info("Successfully calculated statistics", context: [
                "record_count": statistics.recordCount,
                "average_value": statistics.averageValue,
                "trend": statistics.trend.rawValue
            ])
            
            return statistics
            
        } catch {
            logger.error(error, context: [
                "user_id": user.id.uuidString,
                "data_type": type.rawValue
            ])
            throw error
        }
    }
    
    func searchHealthRecords(
        for user: User,
        criteria: HealthDataSearchCriteria
    ) async throws -> [HealthRecord] {
        
        logger.info("Searching health records", context: [
            "user_id": user.id.uuidString,
            "data_types": criteria.dataTypes?.map { $0.rawValue } as Any,
            "has_value_range": criteria.valueRange != nil,
            "sort_by": "\(criteria.sortBy)",
            "limit": criteria.limit as Any
        ])
        
        do {
            // Start with all user records
            var allRecords = try await healthRecordRepository.fetchRecords(
                for: user,
                type: nil,
                from: criteria.dateRange?.startDate,
                to: criteria.dateRange?.endDate
            )
            
            // Apply data type filter
            if let dataTypes = criteria.dataTypes, !dataTypes.isEmpty {
                allRecords = allRecords.filter { dataTypes.contains($0.type) }
            }
            
            // Apply value range filter
            if let valueRange = criteria.valueRange {
                allRecords = allRecords.filter { valueRange.contains($0.value) }
            }
            
            // Apply source filter
            if let sources = criteria.sources, !sources.isEmpty {
                allRecords = allRecords.filter { sources.contains($0.source) }
            }
            
            // Apply sorting
            switch (criteria.sortBy, criteria.sortOrder) {
            case (.timestamp, .ascending):
                allRecords.sort { $0.timestamp < $1.timestamp }
            case (.timestamp, .descending):
                allRecords.sort { $0.timestamp > $1.timestamp }
            case (.value, .ascending):
                allRecords.sort { $0.value < $1.value }
            case (.value, .descending):
                allRecords.sort { $0.value > $1.value }
            case (.dataType, .ascending):
                allRecords.sort { $0.type.rawValue < $1.type.rawValue }
            case (.dataType, .descending):
                allRecords.sort { $0.type.rawValue > $1.type.rawValue }
            }
            
            // Apply limit
            if let limit = criteria.limit, limit > 0 {
                allRecords = Array(allRecords.prefix(limit))
            }
            
            logger.info("Successfully searched health records", context: [
                "results_count": allRecords.count
            ])
            
            return allRecords
            
        } catch {
            logger.error(error, context: [
                "user_id": user.id.uuidString
            ])
            throw error
        }
    }
    
    func exportHealthData(
        for user: User,
        format: ExportFormat,
        dateRange: DateRange?
    ) async throws -> ExportResult {
        
        logger.info("Exporting health data", context: [
            "user_id": user.id.uuidString,
            "format": "\(format)",
            "has_date_range": dateRange != nil
        ])
        
        do {
            // Fetch records to export
            let records = try await fetchHealthRecords(
                for: user,
                type: nil,
                dateRange: dateRange,
                limit: nil
            )
            
            // Generate export data based on format
            let (data, filename) = try generateExportData(
                records: records,
                format: format,
                user: user
            )
            
            let exportResult = ExportResult(
                format: format,
                data: data,
                filename: filename,
                recordCount: records.count,
                userID: user.id
            )
            
            logger.info("Successfully exported health data", context: [
                "record_count": records.count,
                "data_size": data.count,
                "format": "\(format)"
            ])
            
            return exportResult
            
        } catch {
            logger.error(error, context: [
                "user_id": user.id.uuidString,
                "format": "\(format)"
            ])
            throw error
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func generateExportData(
        records: [HealthRecord],
        format: ExportFormat,
        user: User
    ) throws -> (Data, String) {
        
        let timestamp = DateFormatter.iso8601.string(from: Date())
        let baseFilename = "health_data_\(user.name.replacingOccurrences(of: " ", with: "_"))_\(timestamp)"
        
        switch format {
        case .json:
            return try generateJSONExport(records: records, filename: baseFilename)
        case .csv:
            return try generateCSVExport(records: records, filename: baseFilename)
        }
    }
    
    private func generateJSONExport(records: [HealthRecord], filename: String) throws -> (Data, String) {
        let exportData: [String: Any] = [
            "export_info": [
                "timestamp": DateFormatter.iso8601.string(from: Date()),
                "record_count": records.count,
                "format": "JSON"
            ],
            "records": records.map { record in
                [
                    "id": record.id.uuidString,
                    "type": record.type.rawValue,
                    "value": record.value,
                    "unit": record.unit,
                    "timestamp": DateFormatter.iso8601.string(from: record.timestamp),
                    "source": record.source.rawValue
                ]
            }
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
        return (jsonData, "\(filename).json")
    }
    
    private func generateCSVExport(records: [HealthRecord], filename: String) throws -> (Data, String) {
        var csvContent = "timestamp,type,value,unit,source,id\n"
        
        for record in records.sorted(by: { $0.timestamp > $1.timestamp }) {
            let line = "\(DateFormatter.iso8601.string(from: record.timestamp)),\(record.type.rawValue),\(record.value),\(record.unit),\(record.source.rawValue),\(record.id.uuidString)\n"
            csvContent += line
        }
        
        guard let csvData = csvContent.data(using: .utf8) else {
            throw ValidationError.formatMismatch("CSV", expected: "UTF-8", actual: "unknown")
        }
        
        return (csvData, "\(filename).csv")
    }
    
    private func generatePDFExport(records: [HealthRecord], filename: String) throws -> (Data, String) {
        // For now, return empty PDF data - actual PDF generation would require additional libraries
        let pdfContent = "PDF export not yet implemented"
        guard let pdfData = pdfContent.data(using: .utf8) else {
            throw ValidationError.formatMismatch("PDF", expected: "binary", actual: "text")
        }
        
        return (pdfData, "\(filename).pdf")
    }
}

// MARK: - Extensions

private extension DateFormatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}