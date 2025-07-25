import Foundation

struct TrendPoint: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let value: Double
    let movingAverage: Double?
    let isAnomaly: Bool
    
    init(timestamp: Date, value: Double, movingAverage: Double? = nil, isAnomaly: Bool = false) {
        self.id = UUID()
        self.timestamp = timestamp
        self.value = value
        self.movingAverage = movingAverage
        self.isAnomaly = isAnomaly
    }
}

struct AnomalyPoint: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let value: Double
    let expectedValue: Double
    let deviationScore: Double
    let severity: AnomalySeverity
    
    init(timestamp: Date, value: Double, expectedValue: Double, deviationScore: Double, severity: AnomalySeverity) {
        self.id = UUID()
        self.timestamp = timestamp
        self.value = value
        self.expectedValue = expectedValue
        self.deviationScore = deviationScore
        self.severity = severity
    }
}

enum AnomalySeverity: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "軽微"
        case .medium: return "中程度"
        case .high: return "高"
        case .critical: return "重要"
        }
    }
    
    var threshold: Double {
        switch self {
        case .low: return 1.5
        case .medium: return 2.0
        case .high: return 2.5
        case .critical: return 3.0
        }
    }
}

struct TrendAnalysis: Codable {
    let dataType: HealthDataType
    let timeRange: DateRange
    let trendPoints: [TrendPoint]
    let direction: TrendDirection
    let slope: Double
    let correlation: Double
    let anomalies: [AnomalyPoint]
    let summary: TrendSummary
    let confidence: Double
    
    init(
        dataType: HealthDataType,
        timeRange: DateRange,
        trendPoints: [TrendPoint],
        direction: TrendDirection,
        slope: Double,
        correlation: Double,
        anomalies: [AnomalyPoint] = [],
        summary: TrendSummary,
        confidence: Double
    ) {
        self.dataType = dataType
        self.timeRange = timeRange
        self.trendPoints = trendPoints
        self.direction = direction
        self.slope = slope
        self.correlation = correlation
        self.anomalies = anomalies
        self.summary = summary
        self.confidence = confidence
    }
}

struct TrendSummary: Codable {
    let totalDataPoints: Int
    let averageValue: Double
    let minimumValue: Double
    let maximumValue: Double
    let standardDeviation: Double
    let changePercentage: Double
    let lastValue: Double
    let firstValue: Double
    
    init(
        totalDataPoints: Int,
        averageValue: Double,
        minimumValue: Double,
        maximumValue: Double,
        standardDeviation: Double,
        changePercentage: Double,
        lastValue: Double,
        firstValue: Double
    ) {
        self.totalDataPoints = totalDataPoints
        self.averageValue = averageValue
        self.minimumValue = minimumValue
        self.maximumValue = maximumValue
        self.standardDeviation = standardDeviation
        self.changePercentage = changePercentage
        self.lastValue = lastValue
        self.firstValue = firstValue
    }
}

struct TrendPrediction: Codable {
    let dataType: HealthDataType
    let predictedPoints: [TrendPoint]
    let confidence: Double
    let methodology: String
    let validUntil: Date
    
    init(
        dataType: HealthDataType,
        predictedPoints: [TrendPoint],
        confidence: Double,
        methodology: String,
        validUntil: Date
    ) {
        self.dataType = dataType
        self.predictedPoints = predictedPoints
        self.confidence = confidence
        self.methodology = methodology
        self.validUntil = validUntil
    }
}

enum TimeRange: String, CaseIterable, Codable {
    case week = "week"
    case month = "month"
    case quarter = "quarter"
    case year = "year"
    
    var displayName: String {
        switch self {
        case .week: return "週間"
        case .month: return "月間"
        case .quarter: return "四半期"
        case .year: return "年間"
        }
    }
    
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        }
    }
    
    var movingAverageWindow: Int {
        switch self {
        case .week: return 3
        case .month: return 7
        case .quarter: return 14
        case .year: return 30
        }
    }
}