import Foundation

protocol TrendAnalyzerProtocol {
    
    // MARK: - Core Trend Analysis
    
    func analyzeTrends(
        from records: [HealthRecord],
        timeRange: TimeRange
    ) async throws -> TrendAnalysis
    
    func analyzeTrends(
        from records: [HealthRecord],
        dateRange: DateRange
    ) async throws -> TrendAnalysis
    
    // MARK: - Moving Average Calculations
    
    func calculateMovingAverage(
        values: [Double],
        windowSize: Int
    ) -> [Double]
    
    func calculateWeightedMovingAverage(
        values: [Double],
        weights: [Double]
    ) -> [Double]
    
    func calculateExponentialMovingAverage(
        values: [Double],
        alpha: Double
    ) -> [Double]
    
    // MARK: - Anomaly Detection
    
    func detectAnomalies(
        in records: [HealthRecord],
        sensitivity: Double
    ) async throws -> [AnomalyPoint]
    
    func detectOutliers(
        values: [Double],
        method: OutlierDetectionMethod
    ) -> [Int]
    
    // MARK: - Trend Prediction
    
    func predictTrend(
        from analysis: TrendAnalysis,
        daysAhead: Int
    ) async throws -> TrendPrediction
    
    func predictValue(
        from records: [HealthRecord],
        daysAhead: Int,
        method: PredictionMethod
    ) async throws -> Double
    
    // MARK: - Statistical Analysis
    
    func calculateCorrelation(
        between firstSeries: [Double],
        and secondSeries: [Double]
    ) -> Double
    
    func calculateLinearRegression(
        from points: [(x: Double, y: Double)]
    ) -> LinearRegressionResult
    
    func calculateVariability(
        from values: [Double]
    ) -> VariabilityMetrics
    
    // MARK: - Trend Classification
    
    func classifyTrend(
        from values: [Double],
        threshold: Double
    ) -> TrendDirection
    
    func calculateTrendStrength(
        from analysis: TrendAnalysis
    ) -> Double
    
    // MARK: - Data Quality Assessment
    
    func assessDataQuality(
        records: [HealthRecord]
    ) -> DataQualityAssessment
    
    func identifyDataGaps(
        in records: [HealthRecord],
        expectedFrequency: DataFrequency
    ) -> [DateRange]
}

// MARK: - Supporting Types

enum OutlierDetectionMethod: String, CaseIterable {
    case zScore = "z_score"
    case iqr = "iqr"
    case modifiedZScore = "modified_z_score"
    case isolation = "isolation"
    
    var displayName: String {
        switch self {
        case .zScore: return "Zスコア法"
        case .iqr: return "四分位範囲法"
        case .modifiedZScore: return "修正Zスコア法"
        case .isolation: return "分離法"
        }
    }
}

enum PredictionMethod: String, CaseIterable {
    case linearRegression = "linear_regression"
    case exponentialSmoothing = "exponential_smoothing"
    case movingAverage = "moving_average"
    case seasonalDecomposition = "seasonal_decomposition"
    
    var displayName: String {
        switch self {
        case .linearRegression: return "線形回帰"
        case .exponentialSmoothing: return "指数平滑法"
        case .movingAverage: return "移動平均"
        case .seasonalDecomposition: return "季節分解"
        }
    }
}

struct LinearRegressionResult: Codable {
    let slope: Double
    let intercept: Double
    let correlation: Double
    let rSquared: Double
    let standardError: Double
    
    init(slope: Double, intercept: Double, correlation: Double, rSquared: Double, standardError: Double) {
        self.slope = slope
        self.intercept = intercept
        self.correlation = correlation
        self.rSquared = rSquared
        self.standardError = standardError
    }
    
    func predictValue(at x: Double) -> Double {
        return slope * x + intercept
    }
}

struct VariabilityMetrics: Codable {
    let variance: Double
    let standardDeviation: Double
    let coefficientOfVariation: Double
    let range: Double
    let interquartileRange: Double
    
    init(variance: Double, standardDeviation: Double, coefficientOfVariation: Double, range: Double, interquartileRange: Double) {
        self.variance = variance
        self.standardDeviation = standardDeviation
        self.coefficientOfVariation = coefficientOfVariation
        self.range = range
        self.interquartileRange = interquartileRange
    }
}

struct DataQualityAssessment: Codable {
    let completeness: Double
    let consistency: Double
    let accuracy: Double
    let timeliness: Double
    let overallScore: Double
    let issues: [DataQualityIssue]
    
    init(completeness: Double, consistency: Double, accuracy: Double, timeliness: Double, overallScore: Double, issues: [DataQualityIssue]) {
        self.completeness = completeness
        self.consistency = consistency
        self.accuracy = accuracy
        self.timeliness = timeliness
        self.overallScore = overallScore
        self.issues = issues
    }
}

struct DataQualityIssue: Codable, Identifiable {
    let id: UUID
    let type: DataQualityIssueType
    let description: String
    let severity: DataQualityIssueSeverity
    let affectedRecords: Int
    let suggestedAction: String
    
    init(type: DataQualityIssueType, description: String, severity: DataQualityIssueSeverity, affectedRecords: Int, suggestedAction: String) {
        self.id = UUID()
        self.type = type
        self.description = description
        self.severity = severity
        self.affectedRecords = affectedRecords
        self.suggestedAction = suggestedAction
    }
}

enum DataQualityIssueType: String, CaseIterable, Codable {
    case missingData = "missing_data"
    case duplicateData = "duplicate_data"
    case inconsistentData = "inconsistent_data"
    case outlierData = "outlier_data"
    case staleData = "stale_data"
    
    var displayName: String {
        switch self {
        case .missingData: return "データ欠損"
        case .duplicateData: return "重複データ"
        case .inconsistentData: return "不整合データ"
        case .outlierData: return "外れ値"
        case .staleData: return "古いデータ"
        }
    }
}

enum DataQualityIssueSeverity: String, CaseIterable, Codable {
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
}

enum DataFrequency: String, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case irregular = "irregular"
    
    var displayName: String {
        switch self {
        case .daily: return "日次"
        case .weekly: return "週次"
        case .monthly: return "月次"
        case .irregular: return "不定期"
        }
    }
}