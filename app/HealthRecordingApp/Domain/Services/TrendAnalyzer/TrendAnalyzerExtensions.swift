import Foundation

// MARK: - Additional Types for TrendAnalyzer Tests

enum TrendAnalysisError: Error, Equatable {
    case insufficientData
    case invalidPeriod
    case invalidTimeframe
    case calculationFailed(String)
}

enum Timeframe {
    case day
    case week
    case month
    case year
    
    var days: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        case .year: return 365
        }
    }
}

struct MovingAveragePoint {
    let timestamp: Date
    let value: Double
    let originalValue: Double
}

struct TrendResult {
    let direction: TrendDirection
    let strength: Double
    let confidence: Double
    let slope: Double
    let analysis: String
}

struct AnalysisReport {
    let dataPoints: [TrendPoint]
    let trend: TrendResult?
    let movingAverage: [MovingAveragePoint]?
    let variance: Double
    let summary: String
    let timeframe: Timeframe
    let generatedAt: Date
}

// MARK: - TrendAnalyzer Test-Compatible Extensions

extension TrendAnalyzer {
    
    /// Calculate moving average with test-compatible signature
    func calculateMovingAverage(records: [HealthRecord], period: Int) throws -> [MovingAveragePoint] {
        guard !records.isEmpty else {
            throw TrendAnalysisError.insufficientData
        }
        
        guard period > 0 && period <= records.count else {
            throw TrendAnalysisError.insufficientData  // Use same error type as test expects
        }
        
        // Sort records by timestamp (newest first for moving average calculation)
        let sortedRecords = records.sorted { $0.timestamp > $1.timestamp }
        
        var result: [MovingAveragePoint] = []
        
        // Calculate moving average for each valid window
        for i in 0...(sortedRecords.count - period) {
            let windowRecords = Array(sortedRecords[i..<(i + period)])
            let avgValue = windowRecords.map { $0.value }.reduce(0, +) / Double(period)
            
            let point = MovingAveragePoint(
                timestamp: windowRecords[0].timestamp,  // Use the newest timestamp in window
                value: avgValue,
                originalValue: windowRecords[0].value
            )
            result.append(point)
        }
        
        return result
    }
    
    /// Detect trend with test-compatible signature
    func detectTrend(records: [HealthRecord], timeframe: Timeframe) throws -> TrendResult {
        guard records.count >= 2 else {
            throw TrendAnalysisError.insufficientData
        }
        
        let sortedRecords = records.sorted { $0.timestamp < $1.timestamp }
        let values = sortedRecords.map { $0.value }
        
        // Calculate linear regression
        let regression = calculateLinearRegression(from: values.enumerated().map { (x: Double($0.offset), y: $0.element) })
        
        // Determine trend direction with more sensitive threshold for test data
        let direction = classifyTrend(from: values, threshold: 0.01)
        
        // Calculate trend strength based on correlation
        let strength = abs(regression.correlation)
        
        // Calculate confidence based on R-squared and data quality
        let confidence = regression.rSquared
        
        // Generate analysis summary
        let analysis = generateTrendAnalysisText(
            direction: direction,
            strength: strength,
            confidence: confidence,
            timeframe: timeframe
        )
        
        return TrendResult(
            direction: direction,
            strength: strength,
            confidence: confidence,
            slope: regression.slope,
            analysis: analysis
        )
    }
    
    /// Calculate variance with test-compatible signature
    func calculateVariance(records: [HealthRecord]) -> Double {
        let values = records.map { $0.value }
        let variability = calculateVariability(from: values)
        return variability.variance
    }
    
    /// Generate comprehensive analysis report
    func generateAnalysisReport(
        records: [HealthRecord],
        timeframe: Timeframe,
        includeMovingAverage: Bool,
        movingAveragePeriod: Int
    ) throws -> AnalysisReport {
        guard !records.isEmpty else {
            throw TrendAnalysisError.insufficientData
        }
        
        let sortedRecords = records.sorted { $0.timestamp < $1.timestamp }
        
        // Create trend points
        let dataPoints = sortedRecords.map { record in
            TrendPoint(
                timestamp: record.timestamp,
                value: record.value,
                movingAverage: nil,
                isAnomaly: false
            )
        }
        
        // Calculate trend
        let trend = try detectTrend(records: records, timeframe: timeframe)
        
        // Calculate moving average if requested
        var movingAverage: [MovingAveragePoint]? = nil
        if includeMovingAverage && records.count >= movingAveragePeriod {
            movingAverage = try calculateMovingAverage(records: records, period: movingAveragePeriod)
        }
        
        // Calculate variance
        let variance = calculateVariance(records: records)
        
        // Generate summary
        let summary = generateReportSummary(
            records: records,
            trend: trend,
            variance: variance,
            timeframe: timeframe
        )
        
        return AnalysisReport(
            dataPoints: dataPoints,
            trend: trend,
            movingAverage: movingAverage,
            variance: variance,
            summary: summary,
            timeframe: timeframe,
            generatedAt: Date()
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func generateTrendAnalysisText(
        direction: TrendDirection,
        strength: Double,
        confidence: Double,
        timeframe: Timeframe
    ) -> String {
        let directionText = switch direction {
        case .increasing: "upward"
        case .decreasing: "downward"
        case .stable: "stable"
        case .volatile: "volatile"
        }
        
        let strengthText = strength > 0.8 ? "strong" : strength > 0.5 ? "moderate" : "weak"
        let confidenceText = confidence > 0.8 ? "high" : confidence > 0.5 ? "moderate" : "low"
        
        return "A \(strengthText) \(directionText) trend detected over \(timeframe) with \(confidenceText) confidence."
    }
    
    private func generateReportSummary(
        records: [HealthRecord],
        trend: TrendResult,
        variance: Double,
        timeframe: Timeframe
    ) -> String {
        let values = records.map { $0.value }
        let average = values.reduce(0, +) / Double(values.count)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 0
        
        return """
        Analysis Summary:
        • Time Period: \(timeframe)
        • Data Points: \(records.count)
        • Average Value: \(String(format: "%.1f", average))
        • Range: \(String(format: "%.1f", minValue)) - \(String(format: "%.1f", maxValue))
        • Variance: \(String(format: "%.2f", variance))
        • Trend: \(trend.analysis)
        """
    }
}

// MARK: - TrendDirection Extensions

extension TrendDirection: Equatable {
    public static func == (lhs: TrendDirection, rhs: TrendDirection) -> Bool {
        switch (lhs, rhs) {
        case (.increasing, .increasing),
             (.decreasing, .decreasing),
             (.stable, .stable),
             (.volatile, .volatile):
            return true
        default:
            return false
        }
    }
}