import Foundation

// MARK: - Time Range Types

/// Time range for data analysis and filtering
enum TimeRange: String, CaseIterable, Codable {
    case week = "週"
    case month = "月"
    case threeMonths = "3ヶ月"
    case sixMonths = "6ヶ月"
    case year = "年"
    
    var displayName: String {
        return self.rawValue
    }
    
    var dayCount: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        case .sixMonths: return 180
        case .year: return 365
        }
    }
    
    var movingAverageWindow: Int {
        switch self {
        case .week: return 3
        case .month: return 7
        case .threeMonths: return 14
        case .sixMonths: return 21
        case .year: return 30
        }
    }
}

/// Date range for data filtering with specific start and end dates
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
    
    var duration: TimeInterval {
        return endDate.timeIntervalSince(startDate)
    }
    
    var dayCount: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        return components.day ?? 0
    }
    
    func contains(_ date: Date) -> Bool {
        return date >= startDate && date <= endDate
    }
}

/// Date range options for filtering (relative periods)
enum DateRangeOption: String, CaseIterable, Codable {
    case week = "週"
    case month = "月"
    case threeMonths = "3ヶ月"
    case year = "年"
    case all = "全期間"
    
    var displayName: String {
        return self.rawValue
    }
    
    var dayCount: Int {
        switch self {
        case .week: return 7
        case .month: return 30 
        case .threeMonths: return 90
        case .year: return 365
        case .all: return Int.max
        }
    }
    
    /// Convert to absolute DateRange from current date
    func toDateRange(from currentDate: Date = Date()) throws -> DateRange {
        let calendar = Calendar.current
        let endDate = currentDate
        
        let startDate: Date
        switch self {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
        case .threeMonths:
            startDate = calendar.date(byAdding: .month, value: -3, to: endDate) ?? endDate
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        case .all:
            startDate = Date.distantPast
        }
        
        return try DateRange(startDate: startDate, endDate: endDate)
    }
}

// MARK: - Export and Display Types

/// Export format options for health data
enum ExportFormat: String, CaseIterable, Codable {
    case json = "JSON"
    case csv = "CSV"
    
    var displayName: String {
        return self.rawValue
    }
    
    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        }
    }
    
    var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .csv: return "text/csv"
        }
    }
}