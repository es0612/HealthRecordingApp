import Testing
import Foundation
import SwiftData
@testable import HealthRecordingApp

@Suite("TrendAnalyzer Tests")
struct TrendAnalyzerTests {
    
    private func createTestHealthRecords() -> [TestHealthRecordInterface] {
        return TestHealthDataFactory.createTestHealthRecords()
    }
    
    private func createTestRecordsWithAnomalies() -> [TestHealthRecordInterface] {
        return TestHealthDataFactory.createTestRecordsWithAnomalies()
    }
    
    private func createTestAnalyzer() -> TrendAnalyzer {
        let logger = AILogger()
        return TrendAnalyzer(logger: logger)
    }
    
    // MARK: - Moving Average Tests
    
    @Test("TrendAnalyzer should calculate simple moving average correctly")
    func testCalculateMovingAverage() async throws {
        // Given
        let analyzer = createTestAnalyzer()
        let values = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
        let windowSize = 3
        
        // When
        let movingAverage = analyzer.calculateMovingAverage(values: values, windowSize: windowSize)
        
        // Then
        #expect(movingAverage.count == values.count - windowSize + 1)
        #expect(movingAverage[0] == 2.0) // (1+2+3)/3 = 2.0
        #expect(movingAverage[1] == 3.0) // (2+3+4)/3 = 3.0
        #expect(movingAverage[2] == 4.0) // (3+4+5)/3 = 4.0
        #expect(movingAverage.last == 9.0) // (8+9+10)/3 = 9.0
    }
    
    @Test("TrendAnalyzer should handle empty values for moving average")
    func testCalculateMovingAverageEmpty() async throws {
        // Given
        let analyzer = createTestAnalyzer()
        let values: [Double] = []
        let windowSize = 3
        
        // When
        let movingAverage = analyzer.calculateMovingAverage(values: values, windowSize: windowSize)
        
        // Then
        #expect(movingAverage.isEmpty)
    }
    
    @Test("TrendAnalyzer should handle window size larger than values")
    func testCalculateMovingAverageLargeWindow() async throws {
        // Given
        let analyzer = createTestAnalyzer()
        let values = [1.0, 2.0]
        let windowSize = 5
        
        // When
        let movingAverage = analyzer.calculateMovingAverage(values: values, windowSize: windowSize)
        
        // Then
        #expect(movingAverage.isEmpty)
    }
    
    @Test("TrendAnalyzer should calculate weighted moving average correctly")
    func testCalculateWeightedMovingAverage() async throws {
        // Given
        let analyzer = createTestAnalyzer()
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let weights = [0.1, 0.2, 0.3, 0.2, 0.2]
        
        // When
        let weightedMA = analyzer.calculateWeightedMovingAverage(values: values, weights: weights)
        
        // Then
        #expect(weightedMA.count == 1)
        let part1 = 1.0 * 0.1
        let part2 = 2.0 * 0.2
        let part3 = 3.0 * 0.3
        let part4 = 4.0 * 0.2
        let part5 = 5.0 * 0.2
        let expected = part1 + part2 + part3 + part4 + part5
        #expect(abs(weightedMA[0] - expected) < 0.001)
    }
    
    @Test("TrendAnalyzer should calculate exponential moving average correctly")
    func testCalculateExponentialMovingAverage() async throws {
        // Given
        let analyzer = createTestAnalyzer()
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let alpha = 0.3
        
        // When
        let ema = analyzer.calculateExponentialMovingAverage(values: values, alpha: alpha)
        
        // Then
        #expect(ema.count == values.count)
        #expect(ema[0] == values[0]) // First value is unchanged
        
        // Verify EMA calculation: EMA = α * current + (1-α) * previous_EMA
        let expected1 = alpha * values[1] + (1 - alpha) * ema[0]
        #expect(abs(ema[1] - expected1) < 0.001)
    }
    
    // MARK: - Trend Analysis Tests
    
    @Test("TrendAnalyzer should analyze trends correctly")
    func testAnalyzeTrends() async throws {
        // Given
        let analyzer = createTestAnalyzer()
        let records = createTestHealthRecords()
        let timeRange = TimeRange.month
        
        // When
        let analysis = try await analyzer.analyzeTrends(from: records, timeRange: timeRange)
        
        // Then
        #expect(analysis.dataType == .weight)
        #expect(analysis.trendPoints.count > 0)
        #expect(analysis.direction == .decreasing) // Weight is decreasing in test data
        #expect(analysis.slope < 0) // Negative slope for decreasing trend
        #expect(analysis.confidence > 0)
        #expect(analysis.summary.totalDataPoints == records.count)
    }
    
    @Test("TrendAnalyzer should analyze trends with date range")
    func testAnalyzeTrendsWithDateRange() async throws {
        // Given
        let analyzer = createTestAnalyzer()
        let records = createTestHealthRecords()
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!
        let dateRange = try DateRange(startDate: startDate, endDate: endDate)
        
        // When
        let analysis = try await analyzer.analyzeTrends(from: records, dateRange: dateRange)
        
        // Then
        #expect(analysis.dataType == .weight)
        #expect(analysis.trendPoints.count <= records.count)
        #expect(analysis.timeRange.startDate == dateRange.startDate)
        #expect(analysis.timeRange.endDate == dateRange.endDate)
    }
    
    @Test("TrendAnalyzer should handle empty records")
    func testAnalyzeTrendsEmpty() async throws {
        // Given
        let analyzer = createTestAnalyzer()
        let records: [TestHealthRecordInterface] = []
        let timeRange = TimeRange.week
        
        // When & Then
        do {
            _ = try await analyzer.analyzeTrends(from: records, timeRange: timeRange)
            #expect(Bool(false), "Should throw error for empty records")
        } catch is ValidationError {
            #expect(true, "Expected ValidationError was thrown")
        }
    }
    
    @Test("TrendAnalyzer should classify trend direction correctly")
    func testClassifyTrend() async throws {
        // Given
        let analyzer = createTestAnalyzer()
        let threshold = 0.1
        
        // When & Then - Increasing trend
        let increasingValues = [1.0, 2.0, 3.0, 4.0, 5.0]
        let increasingTrend = analyzer.classifyTrend(from: increasingValues, threshold: threshold)
        #expect(increasingTrend == .increasing)
        
        // When & Then - Decreasing trend
        let decreasingValues = [5.0, 4.0, 3.0, 2.0, 1.0]
        let decreasingTrend = analyzer.classifyTrend(from: decreasingValues, threshold: threshold)
        #expect(decreasingTrend == .decreasing)
        
        // When & Then - Stable trend
        let stableValues = [3.0, 3.1, 2.9, 3.0, 3.05]
        let stableTrend = analyzer.classifyTrend(from: stableValues, threshold: threshold)
        #expect(stableTrend == .stable)
        
        // When & Then - Volatile trend
        let volatileValues = [1.0, 5.0, 2.0, 4.0, 1.5]
        let volatileTrend = analyzer.classifyTrend(from: volatileValues, threshold: threshold)
        #expect(volatileTrend == .volatile)
    }
    
    // MARK: - Anomaly Detection Tests
    
    @Test("TrendAnalyzer should detect anomalies correctly")
    func testDetectAnomalies() async throws {
        // Given
        let analyzer = createTestAnalyzer()
        let records = createTestRecordsWithAnomalies()
        let sensitivity = 2.0
        
        // When
        let anomalies = try await analyzer.detectAnomalies(in: records, sensitivity: sensitivity)
        
        // Then
        #expect(anomalies.count >= 2) // Should detect the 75.0 and 65.0 values as anomalies
        
        // Check if the anomalous values are detected
        let anomalousValues = anomalies.map { $0.value }
        #expect(anomalousValues.contains(75.0))
        #expect(anomalousValues.contains(65.0))
        
        // Verify anomaly properties
        for anomaly in anomalies {
            #expect(anomaly.deviationScore >= sensitivity)
            #expect(anomaly.severity != .low) // Should be at least medium severity
        }
    }
    
    @Test("TrendAnalyzer should detect outliers using different methods")
    func testDetectOutliers() async throws {
        // Given
        let analyzer = createTestAnalyzer()
        let values = [1.0, 2.0, 3.0, 100.0, 4.0, 5.0, -50.0, 6.0] // Contains outliers: 100.0, -50.0
        
        // When - Z-Score method
        let zScoreOutliers = analyzer.detectOutliers(values: values, method: .zScore)
        
        // Then
        #expect(zScoreOutliers.count >= 2) // Should detect at least 2 outliers
        #expect(zScoreOutliers.contains(3)) // Index of 100.0
        #expect(zScoreOutliers.contains(6)) // Index of -50.0
        
        // When - IQR method
        let iqrOutliers = analyzer.detectOutliers(values: values, method: .iqr)
        
        // Then
        #expect(iqrOutliers.count >= 1) // Should detect outliers
    }
    
    // MARK: - Statistical Analysis Tests
    
    @Test("TrendAnalyzer should calculate correlation correctly")
    func testCalculateCorrelation() async throws {
        // Given
        let analyzer = createTestAnalyzer()
        
        // Perfect positive correlation
        let series1 = [1.0, 2.0, 3.0, 4.0, 5.0]
        let series2 = [2.0, 4.0, 6.0, 8.0, 10.0]
        
        // When
        let correlation = analyzer.calculateCorrelation(between: series1, and: series2)
        
        // Then
        #expect(abs(correlation - 1.0) < 0.001) // Should be close to 1.0
        
        // Perfect negative correlation
        let series3 = [5.0, 4.0, 3.0, 2.0, 1.0]
        let negativeCorrelation = analyzer.calculateCorrelation(between: series1, and: series3)
        #expect(abs(negativeCorrelation - (-1.0)) < 0.001) // Should be close to -1.0
    }
    
    @Test("TrendAnalyzer should calculate linear regression correctly")
    func testCalculateLinearRegression() async throws {
        // Given
        let analyzer = createTestAnalyzer()
        let points = [(x: 1.0, y: 2.0), (x: 2.0, y: 4.0), (x: 3.0, y: 6.0), (x: 4.0, y: 8.0)]
        
        // When
        let regression = analyzer.calculateLinearRegression(from: points)
        
        // Then
        #expect(abs(regression.slope - 2.0) < 0.001) // y = 2x
        #expect(abs(regression.intercept - 0.0) < 0.001) // y-intercept = 0
        #expect(abs(regression.correlation - 1.0) < 0.001) // Perfect correlation
        #expect(abs(regression.rSquared - 1.0) < 0.001) // Perfect fit
        
        // Test prediction
        let predictedValue = regression.predictValue(at: 5.0)
        #expect(abs(predictedValue - 10.0) < 0.001) // Should predict 10.0
    }
    
    @Test("TrendAnalyzer should calculate variability metrics correctly")
    func testCalculateVariability() async throws {
        // Given
        let analyzer = createTestAnalyzer()
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        
        // When
        let metrics = analyzer.calculateVariability(from: values)
        
        // Then
        #expect(metrics.variance > 0)
        #expect(metrics.standardDeviation > 0)
        #expect(metrics.coefficientOfVariation > 0)
        #expect(metrics.range == 4.0) // 5.0 - 1.0 = 4.0
        #expect(metrics.interquartileRange > 0)
        
        // Verify standard deviation calculation
        let expectedStdDev = sqrt(2.0)
        #expect(abs(metrics.standardDeviation - expectedStdDev) < 0.001)
    }
    
    // MARK: - Prediction Tests
    
    @Test("TrendAnalyzer should predict trends correctly")
    func testPredictTrend() async throws {
        // Given
        let analyzer = createTestAnalyzer()
        let records = createTestHealthRecords()
        let analysis = try await analyzer.analyzeTrends(from: records, timeRange: .month)
        let daysAhead = 7
        
        // When
        let prediction = try await analyzer.predictTrend(from: analysis, daysAhead: daysAhead)
        
        // Then
        #expect(prediction.dataType == analysis.dataType)
        #expect(prediction.predictedPoints.count == daysAhead)
        #expect(prediction.confidence > 0)
        #expect(prediction.confidence <= 1.0)
        #expect(prediction.validUntil > Date())
        
        // Verify predicted points are in chronological order
        for i in 0..<(prediction.predictedPoints.count - 1) {
            #expect(prediction.predictedPoints[i].timestamp < prediction.predictedPoints[i + 1].timestamp)
        }
    }
    
    @Test("TrendAnalyzer should predict single value correctly")
    func testPredictValue() async throws {
        // Given
        let analyzer = createTestAnalyzer()
        let records = createTestHealthRecords()
        let daysAhead = 3
        
        // When
        let predictedValue = try await analyzer.predictValue(
            from: records,
            daysAhead: daysAhead,
            method: .linearRegression
        )
        
        // Then
        #expect(predictedValue > 0) // Should be a reasonable value
        #expect(predictedValue < 100) // Should be within reasonable range for weight
    }
    
    @Test("TrendAnalyzer should calculate trend strength correctly")
    func testCalculateTrendStrength() async throws {
        // Given
        let analyzer = createTestAnalyzer()
        let records = createTestHealthRecords()
        let analysis = try await analyzer.analyzeTrends(from: records, timeRange: .month)
        
        // When
        let trendStrength = analyzer.calculateTrendStrength(from: analysis)
        
        // Then
        #expect(trendStrength >= 0.0)
        #expect(trendStrength <= 1.0)
    }
    
    // MARK: - Data Quality Tests
    
    @Test("TrendAnalyzer should assess data quality correctly")
    func testAssessDataQuality() async throws {
        // Given
        let analyzer = createTestAnalyzer()
        let records = createTestHealthRecords()
        
        // When
        let assessment = analyzer.assessDataQuality(records: records)
        
        // Then
        #expect(assessment.completeness >= 0.0)
        #expect(assessment.completeness <= 1.0)
        #expect(assessment.consistency >= 0.0)
        #expect(assessment.consistency <= 1.0)
        #expect(assessment.accuracy >= 0.0)
        #expect(assessment.accuracy <= 1.0)
        #expect(assessment.timeliness >= 0.0)
        #expect(assessment.timeliness <= 1.0)
        #expect(assessment.overallScore >= 0.0)
        #expect(assessment.overallScore <= 1.0)
    }
    
    @Test("TrendAnalyzer should identify data gaps correctly")
    func testIdentifyDataGaps() async throws {
        // Given
        let analyzer = createTestAnalyzer()
        let records = createTestHealthRecords()
        
        // Remove some records to create gaps
        let recordsWithGaps = [records[0], records[2], records[5], records[9]]
        
        // When
        let gaps = analyzer.identifyDataGaps(in: recordsWithGaps, expectedFrequency: .daily)
        
        // Then
        #expect(gaps.count > 0) // Should identify gaps
        
        // Verify gaps are valid date ranges
        for gap in gaps {
            #expect(gap.startDate <= gap.endDate)
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("TrendAnalyzer should handle large data sets efficiently")
    func testLargeDataSetPerformance() async throws {
        // Given
        let analyzer = createTestAnalyzer()
        let baseDate = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        
        // Create 365 records (1 year of daily data)
        let largeRecordSet: [TestHealthRecordInterface] = (0..<365).map { i in
            var mockRecord = MockHealthRecord(
                type: .weight,
                value: 70.0 + sin(Double(i) * 0.1) * 2.0, // Simulate weight fluctuation
                unit: "kg",
                source: .healthKit
            )
            mockRecord.timestamp = Calendar.current.date(byAdding: .day, value: i, to: baseDate)!
            return mockRecord.toHealthRecord()
        }
        
        // When - Measure performance
        let startTime = Date()
        let analysis = try await analyzer.analyzeTrends(from: largeRecordSet, timeRange: .year)
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Then
        #expect(analysis.trendPoints.count == largeRecordSet.count)
        #expect(executionTime < 2.0) // Should complete within 2 seconds
        #expect(analysis.confidence > 0)
    }
    
    // MARK: - Edge Case Tests
    
    @Test("TrendAnalyzer should handle single data point")
    func testSingleDataPoint() async throws {
        // Given
        let analyzer = createTestAnalyzer()
        var mockRecord = MockHealthRecord(type: .weight, value: 70.0, unit: "kg", source: .healthKit)
        mockRecord.timestamp = Date()
        let singleRecord = [mockRecord.toHealthRecord()]
        
        // When & Then
        do {
            _ = try await analyzer.analyzeTrends(from: singleRecord, timeRange: .week)
            #expect(Bool(false), "Should throw error for insufficient data")
        } catch is ValidationError {
            #expect(true, "Expected ValidationError was thrown")
        }
    }
    
    @Test("TrendAnalyzer should handle identical values")
    func testIdenticalValues() async throws {
        // Given
        let analyzer = createTestAnalyzer()
        let baseDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let identicalRecords = (0..<10).map { index in
            var mockRecord = MockHealthRecord(type: .weight, value: 70.0, unit: "kg", source: .healthKit)
            mockRecord.timestamp = Calendar.current.date(byAdding: .day, value: index, to: baseDate)!
            return mockRecord.toHealthRecord()
        }
        
        // When
        let analysis = try await analyzer.analyzeTrends(from: identicalRecords, timeRange: .month)
        
        // Then
        #expect(analysis.direction == .stable)
        #expect(abs(analysis.slope) < 0.001) // Should be close to 0
        #expect(analysis.summary.standardDeviation == 0.0)
    }
}