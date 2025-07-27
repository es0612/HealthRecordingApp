import Foundation

final class TrendAnalyzer: TrendAnalyzerProtocol {
    
    private let logger: AILoggerProtocol
    
    init(logger: AILoggerProtocol) {
        self.logger = logger
    }
    
    // MARK: - Core Trend Analysis
    
    func analyzeTrends(from records: [HealthRecordProtocol], timeRange: TimeRange) async throws -> TrendAnalysis {
        let startTime = Date()
        
        guard !records.isEmpty else {
            throw ValidationError.invalidInput("Records cannot be empty", value: "\(records.count)", reason: "Empty record set provided for analysis")
        }
        
        guard records.count >= 2 else {
            throw ValidationError.invalidInput("At least 2 records required for trend analysis", value: "\(records.count)", reason: "Insufficient data points for statistical analysis")
        }
        
        do {
            // Filter records by time range
            let endDate = Date()
            guard let startDate = Calendar.current.date(byAdding: .day, value: -timeRange.days, to: endDate) else {
                throw ValidationError.invalidInput("TrendAnalyzer", value: "date_calculation", reason: "Unable to calculate start date from time range")
            }
            let dateRange = try DateRange(startDate: startDate, endDate: endDate)
            let filteredRecords = filterRecords(records, in: dateRange)
            
            guard !filteredRecords.isEmpty else {
                throw ValidationError.invalidInput("No records found in specified time range", value: "\(filteredRecords.count)", reason: "Date range filter excluded all available records")
            }
            
            // Sort records by timestamp
            let sortedRecords = filteredRecords.sorted { $0.timestamp < $1.timestamp }
            
            // Calculate trend points with moving averages
            let trendPoints = try await calculateTrendPoints(from: sortedRecords, windowSize: timeRange.movingAverageWindow)
            
            // Perform statistical analysis
            let values = sortedRecords.map { $0.value }
            let regression = calculateLinearRegression(from: sortedRecords.enumerated().map { (x: Double($0.offset), y: $0.element.value) })
            let direction = classifyTrend(from: values, threshold: 0.1)
            
            // Detect anomalies
            let anomalies = try await detectAnomalies(in: sortedRecords, sensitivity: 2.0)
            
            // Calculate summary statistics
            let summary = calculateTrendSummary(from: sortedRecords)
            
            // Calculate confidence based on data quality and correlation strength
            let confidence = calculateConfidence(regression: regression, dataQuality: assessDataQuality(records: sortedRecords))
            
            guard let firstRecord = sortedRecords.first else {
                throw ValidationError.invalidInput("TrendAnalyzer", value: "empty_sorted_data", reason: "Sorted records became empty unexpectedly")
            }
            
            let analysis = TrendAnalysis(
                dataType: firstRecord.type,
                timeRange: dateRange,
                trendPoints: trendPoints,
                direction: direction,
                slope: regression.slope,
                correlation: regression.correlation,
                anomalies: anomalies,
                summary: summary,
                confidence: confidence
            )
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("trend_analysis", duration: duration, success: true)
            logger.info("Trend analysis completed", context: [
                "data_type": firstRecord.type.rawValue,
                "records_count": sortedRecords.count,
                "direction": direction.rawValue,
                "confidence": confidence
            ])
            
            return analysis
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("trend_analysis", duration: duration, success: false)
            logger.error(error, context: ["operation": "analyzeTrends"])
            throw error
        }
    }
    
    func analyzeTrends(from records: [HealthRecordProtocol], dateRange: DateRange) async throws -> TrendAnalysis {
        let startTime = Date()
        
        guard !records.isEmpty else {
            throw ValidationError.invalidInput("Records cannot be empty", value: "\(records.count)", reason: "Empty record set provided for analysis")
        }
        
        do {
            // Filter records by date range
            let filteredRecords = filterRecords(records, in: dateRange)
            
            guard filteredRecords.count >= 2 else {
                throw ValidationError.invalidInput("At least 2 records required for trend analysis", value: "\(records.count)", reason: "Insufficient data points for statistical analysis")
            }
            
            // Sort records by timestamp
            let sortedRecords = filteredRecords.sorted { $0.timestamp < $1.timestamp }
            
            // Determine appropriate window size based on data span
            let windowSize = determineOptimalWindowSize(for: sortedRecords)
            
            // Calculate trend points
            let trendPoints = try await calculateTrendPoints(from: sortedRecords, windowSize: windowSize)
            
            // Perform analysis
            let values = sortedRecords.map { $0.value }
            let regression = calculateLinearRegression(from: sortedRecords.enumerated().map { (x: Double($0.offset), y: $0.element.value) })
            let direction = classifyTrend(from: values, threshold: 0.1)
            let anomalies = try await detectAnomalies(in: sortedRecords, sensitivity: 2.0)
            let summary = calculateTrendSummary(from: sortedRecords)
            let confidence = calculateConfidence(regression: regression, dataQuality: assessDataQuality(records: sortedRecords))
            
            guard let firstRecord = sortedRecords.first else {
                throw ValidationError.invalidInput("TrendAnalyzer", value: "empty_sorted_data", reason: "Sorted records became empty unexpectedly")
            }
            
            let analysis = TrendAnalysis(
                dataType: firstRecord.type,
                timeRange: dateRange,
                trendPoints: trendPoints,
                direction: direction,
                slope: regression.slope,
                correlation: regression.correlation,
                anomalies: anomalies,
                summary: summary,
                confidence: confidence
            )
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("trend_analysis_date_range", duration: duration, success: true)
            
            return analysis
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("trend_analysis_date_range", duration: duration, success: false)
            logger.error(error, context: ["operation": "analyzeTrendsWithDateRange"])
            throw error
        }
    }
    
    // MARK: - Moving Average Calculations
    
    func calculateMovingAverage(values: [Double], windowSize: Int) -> [Double] {
        guard !values.isEmpty && windowSize > 0 && windowSize <= values.count else {
            return []
        }
        
        var movingAverages: [Double] = []
        
        for i in (windowSize - 1)..<values.count {
            let windowSum = values[(i - windowSize + 1)...i].reduce(0, +)
            let average = windowSum / Double(windowSize)
            movingAverages.append(average)
        }
        
        return movingAverages
    }
    
    func calculateWeightedMovingAverage(values: [Double], weights: [Double]) -> [Double] {
        guard values.count == weights.count && !values.isEmpty else {
            return []
        }
        
        let weightSum = weights.reduce(0, +)
        guard weightSum > 0 else {
            return []
        }
        
        let weightedSum = zip(values, weights).reduce(0) { $0 + $1.0 * $1.1 }
        return [weightedSum / weightSum]
    }
    
    func calculateExponentialMovingAverage(values: [Double], alpha: Double) -> [Double] {
        guard !values.isEmpty && alpha > 0 && alpha <= 1 else {
            return []
        }
        
        var ema: [Double] = []
        ema.append(values[0]) // First value is unchanged
        
        for i in 1..<values.count {
            let newEMA = alpha * values[i] + (1 - alpha) * ema[i - 1]
            ema.append(newEMA)
        }
        
        return ema
    }
    
    // MARK: - Anomaly Detection
    
    func detectAnomalies(in records: [HealthRecordProtocol], sensitivity: Double) async throws -> [AnomalyPoint] {
        guard records.count >= 3 else {
            return []
        }
        
        let values = records.map { $0.value }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count - 1)
        let standardDeviation = sqrt(variance)
        
        var anomalies: [AnomalyPoint] = []
        
        for (_, record) in records.enumerated() {
            let zScore = abs(record.value - mean) / standardDeviation
            
            if zScore >= sensitivity {
                let severity = determineSeverity(from: zScore)
                let anomaly = AnomalyPoint(
                    timestamp: record.timestamp,
                    value: record.value,
                    expectedValue: mean,
                    deviationScore: zScore,
                    severity: severity
                )
                anomalies.append(anomaly)
            }
        }
        
        logger.info("Anomaly detection completed", context: [
            "records_count": records.count,
            "anomalies_found": anomalies.count,
            "sensitivity": sensitivity
        ])
        
        return anomalies
    }
    
    func detectOutliers(values: [Double], method: OutlierDetectionMethod) -> [Int] {
        guard values.count >= 3 else {
            return []
        }
        
        switch method {
        case .zScore:
            return detectOutliersZScore(values: values)
        case .iqr:
            return detectOutliersIQR(values: values)
        case .modifiedZScore:
            return detectOutliersModifiedZScore(values: values)
        case .isolation:
            return detectOutliersIsolation(values: values)
        }
    }
    
    // MARK: - Trend Prediction
    
    func predictTrend(from analysis: TrendAnalysis, daysAhead: Int) async throws -> TrendPrediction {
        guard daysAhead > 0 else {
            throw ValidationError.invalidInput("Days ahead must be positive", value: "\(daysAhead)", reason: "Prediction requires positive number of days")
        }
        
        guard let lastPoint = analysis.trendPoints.last else {
            throw ValidationError.invalidInput("TrendAnalyzer", value: "empty_trend_points", reason: "Cannot predict from empty trend points")
        }
        var predictedPoints: [TrendPoint] = []
        
        // Use linear regression for prediction
        for day in 1...daysAhead {
            guard let futureTimestamp = Calendar.current.date(byAdding: .day, value: day, to: lastPoint.timestamp) else {
                throw ValidationError.invalidInput("TrendAnalyzer", value: "future_date_calculation", reason: "Unable to calculate future timestamp for prediction")
            }
            let predictedValue = lastPoint.value + analysis.slope * Double(day)
            
            let point = TrendPoint(
                timestamp: futureTimestamp,
                value: max(0, predictedValue), // Ensure non-negative values
                movingAverage: nil,
                isAnomaly: false
            )
            predictedPoints.append(point)
        }
        
        // Calculate prediction confidence based on historical accuracy
        let confidence = max(0.1, min(0.9, analysis.confidence * 0.8)) // Reduce confidence for predictions
        
        guard let validUntilDate = Calendar.current.date(byAdding: .day, value: daysAhead, to: Date()) else {
            throw ValidationError.invalidInput("TrendAnalyzer", value: "valid_until_calculation", reason: "Unable to calculate validity end date for prediction")
        }
        
        let prediction = TrendPrediction(
            dataType: analysis.dataType,
            predictedPoints: predictedPoints,
            confidence: confidence,
            methodology: "Linear Regression",
            validUntil: validUntilDate
        )
        
        logger.info("Trend prediction completed", context: [
            "data_type": analysis.dataType.rawValue,
            "days_ahead": daysAhead,
            "confidence": confidence
        ])
        
        return prediction
    }
    
    func predictValue(from records: [HealthRecordProtocol], daysAhead: Int, method: PredictionMethod) async throws -> Double {
        guard !records.isEmpty else {
            throw ValidationError.invalidInput("Records cannot be empty", value: "\(records.count)", reason: "Empty record set provided for analysis")
        }
        
        let sortedRecords = records.sorted { $0.timestamp < $1.timestamp }
        let values = sortedRecords.map { $0.value }
        
        switch method {
        case .linearRegression:
            let regression = calculateLinearRegression(from: values.enumerated().map { (x: Double($0.offset), y: $0.element) })
            return regression.predictValue(at: Double(values.count + daysAhead - 1))
            
        case .exponentialSmoothing:
            let alpha = 0.3
            let ema = calculateExponentialMovingAverage(values: values, alpha: alpha)
            return ema.last ?? (values.last ?? 0.0)
            
        case .movingAverage:
            let windowSize = min(7, values.count)
            let ma = calculateMovingAverage(values: values, windowSize: windowSize)
            return ma.last ?? (values.last ?? 0.0)
            
        case .seasonalDecomposition:
            // Simplified seasonal prediction - in a real implementation, this would be more complex
            return values.last ?? 0.0
        }
    }
    
    // MARK: - Statistical Analysis
    
    func calculateCorrelation(between firstSeries: [Double], and secondSeries: [Double]) -> Double {
        guard firstSeries.count == secondSeries.count && !firstSeries.isEmpty else {
            return 0.0
        }
        
        let n = Double(firstSeries.count)
        let mean1 = firstSeries.reduce(0, +) / n
        let mean2 = secondSeries.reduce(0, +) / n
        
        let numerator = zip(firstSeries, secondSeries).reduce(0) { result, pair in
            result + (pair.0 - mean1) * (pair.1 - mean2)
        }
        
        let sumSquares1 = firstSeries.reduce(0) { $0 + pow($1 - mean1, 2) }
        let sumSquares2 = secondSeries.reduce(0) { $0 + pow($1 - mean2, 2) }
        
        let denominator = sqrt(sumSquares1 * sumSquares2)
        
        return denominator == 0 ? 0 : numerator / denominator
    }
    
    func calculateLinearRegression(from points: [(x: Double, y: Double)]) -> LinearRegressionResult {
        guard points.count >= 2 else {
            return LinearRegressionResult(slope: 0, intercept: 0, correlation: 0, rSquared: 0, standardError: 0)
        }
        
        let n = Double(points.count)
        let sumX = points.reduce(0) { $0 + $1.x }
        let sumY = points.reduce(0) { $0 + $1.y }
        let sumXY = points.reduce(0) { $0 + $1.x * $1.y }
        let sumXX = points.reduce(0) { $0 + $1.x * $1.x }
        let sumYY = points.reduce(0) { $0 + $1.y * $1.y }
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)
        let intercept = (sumY - slope * sumX) / n
        
        // Calculate correlation coefficient
        let numerator = n * sumXY - sumX * sumY
        let denominator = sqrt((n * sumXX - sumX * sumX) * (n * sumYY - sumY * sumY))
        let correlation = denominator == 0 ? 0 : numerator / denominator
        
        let rSquared = correlation * correlation
        
        // Calculate standard error
        let predictedValues = points.map { slope * $0.x + intercept }
        let residuals = zip(points, predictedValues).map { $0.0.y - $0.1 }
        let residualSumSquares = residuals.reduce(0) { $0 + $1 * $1 }
        let standardError = sqrt(residualSumSquares / (n - 2))
        
        return LinearRegressionResult(
            slope: slope,
            intercept: intercept,
            correlation: correlation,
            rSquared: rSquared,
            standardError: standardError
        )
    }
    
    func calculateVariability(from values: [Double]) -> VariabilityMetrics {
        guard !values.isEmpty else {
            return VariabilityMetrics(variance: 0, standardDeviation: 0, coefficientOfVariation: 0, range: 0, interquartileRange: 0)
        }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count - 1)
        let standardDeviation = sqrt(variance)
        let coefficientOfVariation = mean == 0 ? 0 : standardDeviation / abs(mean)
        
        let sortedValues = values.sorted()
        let range = (sortedValues.last ?? 0) - (sortedValues.first ?? 0)
        
        // Calculate IQR
        let q1Index = Int(Double(values.count) * 0.25)
        let q3Index = Int(Double(values.count) * 0.75)
        let interquartileRange = sortedValues[q3Index] - sortedValues[q1Index]
        
        return VariabilityMetrics(
            variance: variance,
            standardDeviation: standardDeviation,
            coefficientOfVariation: coefficientOfVariation,
            range: range,
            interquartileRange: interquartileRange
        )
    }
    
    // MARK: - Trend Classification
    
    func classifyTrend(from values: [Double], threshold: Double) -> TrendDirection {
        guard values.count >= 2 else {
            return .stable
        }
        
        let regression = calculateLinearRegression(from: values.enumerated().map { (x: Double($0.offset), y: $0.element) })
        let normalizedSlope = regression.slope / (values.reduce(0, +) / Double(values.count))
        
        // Calculate volatility
        let variability = calculateVariability(from: values)
        let volatility = variability.coefficientOfVariation
        
        // High volatility indicates volatile trend
        if volatility > 0.3 {
            return .volatile
        }
        
        // Classify based on normalized slope
        if abs(normalizedSlope) < threshold {
            return .stable
        } else if normalizedSlope > 0 {
            return .increasing
        } else {
            return .decreasing
        }
    }
    
    func calculateTrendStrength(from analysis: TrendAnalysis) -> Double {
        // Combine correlation strength and consistency
        let correlationStrength = abs(analysis.correlation)
        let consistencyScore = 1.0 - (analysis.summary.standardDeviation / analysis.summary.averageValue)
        let anomalyPenalty = Double(analysis.anomalies.count) / Double(analysis.summary.totalDataPoints)
        
        let strength = (correlationStrength + max(0, consistencyScore)) / 2.0 - anomalyPenalty * 0.1
        return max(0.0, min(1.0, strength))
    }
    
    // MARK: - Data Quality Assessment
    
    func assessDataQuality(records: [HealthRecordProtocol]) -> DataQualityAssessment {
        guard !records.isEmpty else {
            return DataQualityAssessment(
                completeness: 0,
                consistency: 0,
                accuracy: 0,
                timeliness: 0,
                overallScore: 0,
                issues: []
            )
        }
        
        var issues: [DataQualityIssue] = []
        
        // Assess completeness (no missing critical data)
        let completeness = 1.0 // Assume complete since we have the records
        
        // Assess consistency (data follows expected patterns)
        let values = records.map { $0.value }
        let outliers = detectOutliers(values: values, method: .zScore)
        let consistency = 1.0 - (Double(outliers.count) / Double(records.count))
        
        if outliers.count > records.count / 10 { // More than 10% outliers
            issues.append(DataQualityIssue(
                type: .inconsistentData,
                description: "High number of outliers detected",
                severity: .medium,
                affectedRecords: outliers.count,
                suggestedAction: "Review data collection process"
            ))
        }
        
        // Assess accuracy (values within reasonable ranges)
        var accuracy = 1.0
        let unreasonableValues = records.filter { record in
            switch record.type {
            case .weight:
                return record.value <= 0 || record.value > 500 // Unreasonable weight values
            case .steps:
                return record.value < 0 || record.value > 100000 // Unreasonable step counts
            case .calories:
                return record.value < 0 || record.value > 10000 // Unreasonable calorie values
            case .heartRate:
                return record.value < 30 || record.value > 220 // Unreasonable heart rate
            case .bloodGlucose:
                return record.value < 0 || record.value > 600 // Unreasonable glucose levels
            }
        }
        
        if !unreasonableValues.isEmpty {
            accuracy = 1.0 - (Double(unreasonableValues.count) / Double(records.count))
            issues.append(DataQualityIssue(
                type: .outlierData,
                description: "Values outside reasonable range detected",
                severity: .high,
                affectedRecords: unreasonableValues.count,
                suggestedAction: "Verify sensor calibration and data entry"
            ))
        }
        
        // Assess timeliness (data recency)
        guard let latestRecord = records.max(by: { $0.timestamp < $1.timestamp }) else {
            // This should not happen since we already checked for empty records, but safety first
            let timeliness = 0.0
            return DataQualityAssessment(
                completeness: completeness,
                consistency: consistency,
                accuracy: accuracy,
                timeliness: timeliness,
                overallScore: (completeness + consistency + accuracy + timeliness) / 4.0,
                issues: issues
            )
        }
        let daysSinceLatest = Date().timeIntervalSince(latestRecord.timestamp) / (24 * 60 * 60)
        let timeliness = max(0.0, 1.0 - daysSinceLatest / 30.0) // Penalize data older than 30 days
        
        if daysSinceLatest > 7 {
            issues.append(DataQualityIssue(
                type: .staleData,
                description: "Latest data is more than a week old",
                severity: .medium,
                affectedRecords: 1,
                suggestedAction: "Update data collection frequency"
            ))
        }
        
        let overallScore = (completeness + consistency + accuracy + timeliness) / 4.0
        
        return DataQualityAssessment(
            completeness: completeness,
            consistency: consistency,
            accuracy: accuracy,
            timeliness: timeliness,
            overallScore: overallScore,
            issues: issues
        )
    }
    
    func identifyDataGaps(in records: [HealthRecordProtocol], expectedFrequency: DataFrequency) -> [DateRange] {
        guard records.count >= 2 else {
            return []
        }
        
        let sortedRecords = records.sorted { $0.timestamp < $1.timestamp }
        var gaps: [DateRange] = []
        
        let expectedInterval: TimeInterval
        switch expectedFrequency {
        case .daily:
            expectedInterval = 24 * 60 * 60 // 1 day
        case .weekly:
            expectedInterval = 7 * 24 * 60 * 60 // 1 week
        case .monthly:
            expectedInterval = 30 * 24 * 60 * 60 // 30 days
        case .irregular:
            return gaps // No gaps expected for irregular frequency
        }
        
        for i in 0..<(sortedRecords.count - 1) {
            let currentRecord = sortedRecords[i]
            let nextRecord = sortedRecords[i + 1]
            let gap = nextRecord.timestamp.timeIntervalSince(currentRecord.timestamp)
            
            if gap > expectedInterval * 1.5 { // Allow 50% tolerance
                do {
                    guard let gapStartDate = Calendar.current.date(byAdding: .day, value: 1, to: currentRecord.timestamp),
                          let gapEndDate = Calendar.current.date(byAdding: .day, value: -1, to: nextRecord.timestamp) else {
                        // Skip if date calculation fails
                        continue
                    }
                    let gapRange = try DateRange(startDate: gapStartDate, endDate: gapEndDate)
                    gaps.append(gapRange)
                } catch {
                    // Skip invalid gap ranges
                    continue
                }
            }
        }
        
        return gaps
    }
}

// MARK: - Private Helper Methods

private extension TrendAnalyzer {
    
    func filterRecords(_ records: [HealthRecordProtocol], in dateRange: DateRange) -> [HealthRecordProtocol] {
        return records.filter { dateRange.contains($0.timestamp) }
    }
    
    func determineOptimalWindowSize(for records: [HealthRecordProtocol]) -> Int {
        let recordCount = records.count
        
        if recordCount <= 7 {
            return max(3, recordCount / 3)
        } else if recordCount <= 30 {
            return 7
        } else if recordCount <= 90 {
            return 14
        } else {
            return 30
        }
    }
    
    func calculateTrendPoints(from records: [HealthRecordProtocol], windowSize: Int) async throws -> [TrendPoint] {
        let values = records.map { $0.value }
        let movingAverages = calculateMovingAverage(values: values, windowSize: windowSize)
        
        var points: [TrendPoint] = []
        
        for (index, record) in records.enumerated() {
            let movingAverage = index >= windowSize - 1 ? movingAverages[index - windowSize + 1] : nil
            let point = TrendPoint(
                timestamp: record.timestamp,
                value: record.value,
                movingAverage: movingAverage,
                isAnomaly: false
            )
            points.append(point)
        }
        
        return points
    }
    
    func calculateTrendSummary(from records: [HealthRecordProtocol]) -> TrendSummary {
        guard !records.isEmpty else {
            return TrendSummary(
                totalDataPoints: 0,
                averageValue: 0,
                minimumValue: 0,
                maximumValue: 0,
                standardDeviation: 0,
                changePercentage: 0,
                lastValue: 0,
                firstValue: 0
            )
        }
        
        let values = records.map { $0.value }
        let totalDataPoints = records.count
        let averageValue = values.reduce(0, +) / Double(values.count)
        let minimumValue = values.min() ?? 0.0
        let maximumValue = values.max() ?? 0.0
        
        let variance = values.reduce(0) { $0 + pow($1 - averageValue, 2) } / Double(values.count - 1)
        let standardDeviation = sqrt(variance)
        
        let firstValue = values.first ?? 0.0
        let lastValue = values.last ?? 0.0
        let changePercentage = firstValue == 0 ? 0 : ((lastValue - firstValue) / firstValue) * 100
        
        return TrendSummary(
            totalDataPoints: totalDataPoints,
            averageValue: averageValue,
            minimumValue: minimumValue,
            maximumValue: maximumValue,
            standardDeviation: standardDeviation,
            changePercentage: changePercentage,
            lastValue: lastValue,
            firstValue: firstValue
        )
    }
    
    func calculateConfidence(regression: LinearRegressionResult, dataQuality: DataQualityAssessment) -> Double {
        let regressionConfidence = regression.rSquared
        let qualityConfidence = dataQuality.overallScore
        return (regressionConfidence + qualityConfidence) / 2.0
    }
    
    func determineSeverity(from zScore: Double) -> AnomalySeverity {
        if zScore >= AnomalySeverity.critical.threshold {
            return .critical
        } else if zScore >= AnomalySeverity.high.threshold {
            return .high
        } else if zScore >= AnomalySeverity.medium.threshold {
            return .medium
        } else {
            return .low
        }
    }
    
    func detectOutliersZScore(values: [Double]) -> [Int] {
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count - 1)
        let standardDeviation = sqrt(variance)
        
        var outliers: [Int] = []
        
        for (index, value) in values.enumerated() {
            let zScore = abs(value - mean) / standardDeviation
            if zScore >= 2.0 { // Standard threshold for outliers
                outliers.append(index)
            }
        }
        
        return outliers
    }
    
    func detectOutliersIQR(values: [Double]) -> [Int] {
        let sortedValues = values.sorted()
        let n = sortedValues.count
        
        let q1Index = n / 4
        let q3Index = 3 * n / 4
        
        let q1 = sortedValues[q1Index]
        let q3 = sortedValues[q3Index]
        let iqr = q3 - q1
        
        let lowerBound = q1 - 1.5 * iqr
        let upperBound = q3 + 1.5 * iqr
        
        var outliers: [Int] = []
        
        for (index, value) in values.enumerated() {
            if value < lowerBound || value > upperBound {
                outliers.append(index)
            }
        }
        
        return outliers
    }
    
    func detectOutliersModifiedZScore(values: [Double]) -> [Int] {
        let median = calculateMedian(values: values)
        let deviations = values.map { abs($0 - median) }
        let medianDeviation = calculateMedian(values: deviations)
        
        var outliers: [Int] = []
        
        for (index, value) in values.enumerated() {
            let modifiedZScore = 0.6745 * (value - median) / medianDeviation
            if abs(modifiedZScore) >= 3.5 {
                outliers.append(index)
            }
        }
        
        return outliers
    }
    
    func detectOutliersIsolation(values: [Double]) -> [Int] {
        // Simplified isolation forest - in a real implementation, this would be more sophisticated
        return detectOutliersZScore(values: values)
    }
    
    func calculateMedian(values: [Double]) -> Double {
        let sortedValues = values.sorted()
        let count = sortedValues.count
        
        if count % 2 == 0 {
            return (sortedValues[count / 2 - 1] + sortedValues[count / 2]) / 2
        } else {
            return sortedValues[count / 2]
        }
    }
}