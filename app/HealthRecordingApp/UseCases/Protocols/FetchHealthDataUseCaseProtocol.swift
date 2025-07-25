import Foundation
import SwiftData

/// Protocol defining the FetchHealthDataUseCase interface
/// Handles retrieval and querying of health data with various filtering options
protocol FetchHealthDataUseCaseProtocol {
    
    /// Fetch health records for a specific user with optional filtering
    /// - Parameters:
    ///   - user: The user to fetch records for
    ///   - type: Optional health data type filter
    ///   - dateRange: Optional date range filter
    ///   - limit: Optional limit on number of records returned
    /// - Returns: Array of HealthRecord objects matching criteria
    /// - Throws: Use case errors if fetching fails
    func fetchHealthRecords(
        for user: User,
        type: HealthDataType?,
        dateRange: DateRange?,
        limit: Int?
    ) async throws -> [HealthRecord]
    
    /// Fetch latest health record for a specific data type
    /// - Parameters:
    ///   - user: The user to fetch record for
    ///   - type: The health data type to fetch
    /// - Returns: Latest HealthRecord of specified type, nil if none found
    /// - Throws: Use case errors if fetching fails
    func fetchLatestRecord(
        for user: User,
        type: HealthDataType
    ) async throws -> HealthRecord?
    
    /// Fetch health records grouped by day for trend analysis
    /// - Parameters:
    ///   - user: The user to fetch records for
    ///   - type: The health data type to group
    ///   - dateRange: Date range for grouping
    /// - Returns: Dictionary with date as key and array of records as value
    /// - Throws: Use case errors if fetching fails
    func fetchRecordsGroupedByDay(
        for user: User,
        type: HealthDataType,
        dateRange: DateRange
    ) async throws -> [Date: [HealthRecord]]
    
    /// Get health data statistics for a user
    /// - Parameters:
    ///   - user: The user to calculate statistics for
    ///   - type: The health data type to analyze
    ///   - dateRange: Date range for analysis
    /// - Returns: HealthDataStatistics containing calculated metrics
    /// - Throws: Use case errors if calculation fails
    func getHealthDataStatistics(
        for user: User,
        type: HealthDataType,
        dateRange: DateRange
    ) async throws -> HealthDataStatistics
    
    /// Search health records based on criteria
    /// - Parameters:
    ///   - user: The user to search records for
    ///   - criteria: Search criteria including filters and sorting
    /// - Returns: Array of HealthRecord objects matching search criteria
    /// - Throws: Use case errors if search fails
    func searchHealthRecords(
        for user: User,
        criteria: HealthDataSearchCriteria
    ) async throws -> [HealthRecord]
    
    /// Export health data for sharing or backup
    /// - Parameters:
    ///   - user: The user to export data for
    ///   - format: Export format (JSON, CSV, etc.)
    ///   - dateRange: Optional date range filter
    /// - Returns: ExportResult containing exported data and metadata
    /// - Throws: Use case errors if export fails  
    func exportHealthData(
        for user: User,
        format: ExportFormat,
        dateRange: DateRange?
    ) async throws -> ExportResult
}

// MARK: - Supporting Data Structures

/// Date range for filtering health data
struct DateRange: Codable {
    let startDate: Date
    let endDate: Date
    
    init(startDate: Date, endDate: Date) throws {
        guard startDate <= endDate else {
            throw ValidationError.invalidInput(
                "DateRange", 
                value: "\(startDate) - \(endDate)",
                reason: "Start date must be before or equal to end date"
            )
        }
        self.startDate = startDate
        self.endDate = endDate
    }
    
    /// Check if a date falls within this range
    func contains(_ date: Date) -> Bool {
        return date >= startDate && date <= endDate
    }
    
    /// Duration of the date range in days
    var durationInDays: Int {
        return Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }
}

/// Health data statistics for analysis
struct HealthDataStatistics {
    let dataType: HealthDataType
    let dateRange: DateRange
    let recordCount: Int
    let averageValue: Double
    let minimumValue: Double
    let maximumValue: Double
    let standardDeviation: Double
    let trend: TrendDirection
    let lastUpdated: Date
    
    init(
        dataType: HealthDataType,
        dateRange: DateRange, 
        records: [HealthRecord]
    ) {
        self.dataType = dataType
        self.dateRange = dateRange
        self.recordCount = records.count
        self.lastUpdated = Date()
        
        let values = records.map { $0.value }
        
        if values.isEmpty {
            self.averageValue = 0.0
            self.minimumValue = 0.0
            self.maximumValue = 0.0
            self.standardDeviation = 0.0
            self.trend = .stable
        } else {
            let average = values.reduce(0, +) / Double(values.count)
            self.averageValue = average
            self.minimumValue = values.min() ?? 0.0
            self.maximumValue = values.max() ?? 0.0
            
            // Calculate standard deviation
            let squaredDiffs = values.map { pow($0 - average, 2) }
            self.standardDeviation = sqrt(squaredDiffs.reduce(0, +) / Double(values.count))
            
            // Determine trend (simplified: compare first and last half)
            if values.count >= 4 {
                let midPoint = values.count / 2
                let firstHalf = Array(values[0..<midPoint])
                let secondHalf = Array(values[midPoint..<values.count])
                
                let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
                let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)
                
                let trendThreshold = average * 0.05 // 5% threshold
                
                if secondAvg > firstAvg + trendThreshold {
                    self.trend = .increasing
                } else if secondAvg < firstAvg - trendThreshold {
                    self.trend = .decreasing
                } else {
                    self.trend = .stable
                }
            } else {
                self.trend = .stable
            }
        }
    }
}

/// Trend direction for health data analysis
enum TrendDirection: String, CaseIterable, Codable {
    case increasing = "増加傾向"
    case decreasing = "減少傾向"
    case stable = "安定"
    case volatile = "変動大"
    
    var emoji: String {
        switch self {
        case .increasing: return "📈"
        case .decreasing: return "📉"
        case .stable: return "➡️"
        case .volatile: return "🌊"
        }
    }
}

/// Search criteria for health data queries
struct HealthDataSearchCriteria {
    let dataTypes: [HealthDataType]?
    let dateRange: DateRange?
    let valueRange: ValueRange?
    let sources: [DataSource]?
    let sortBy: SortOption
    let sortOrder: SortOrder
    let limit: Int?
    
    init(
        dataTypes: [HealthDataType]? = nil,
        dateRange: DateRange? = nil,
        valueRange: ValueRange? = nil,
        sources: [DataSource]? = nil,
        sortBy: SortOption = .timestamp,
        sortOrder: SortOrder = .descending,
        limit: Int? = nil
    ) {
        self.dataTypes = dataTypes
        self.dateRange = dateRange
        self.valueRange = valueRange
        self.sources = sources
        self.sortBy = sortBy
        self.sortOrder = sortOrder
        self.limit = limit
    }
}

/// Value range for filtering by health data values
struct ValueRange {
    let minimum: Double?
    let maximum: Double?
    
    init(minimum: Double? = nil, maximum: Double? = nil) throws {
        if let min = minimum, let max = maximum {
            guard min <= max else {
                throw ValidationError.invalidInput(
                    "ValueRange",
                    value: "\(min) - \(max)",
                    reason: "Minimum value must be less than or equal to maximum value"
                )
            }
        }
        self.minimum = minimum
        self.maximum = maximum
    }
    
    /// Check if a value falls within this range
    func contains(_ value: Double) -> Bool {
        if let min = minimum, value < min { return false }
        if let max = maximum, value > max { return false }
        return true
    }
}

/// Sort options for health data queries
enum SortOption {
    case timestamp
    case value
    case dataType
}

/// Sort order for queries
enum SortOrder {
    case ascending
    case descending
}

/// Export format options
enum ExportFormat {
    case json
    case csv
    case pdf
}

/// Export result containing data and metadata
struct ExportResult {
    let format: ExportFormat
    let data: Data
    let filename: String
    let recordCount: Int
    let exportDate: Date
    let userID: UUID
    
    init(
        format: ExportFormat,
        data: Data,
        filename: String,
        recordCount: Int,
        userID: UUID
    ) {
        self.format = format
        self.data = data
        self.filename = filename
        self.recordCount = recordCount
        self.exportDate = Date()
        self.userID = userID
    }
}