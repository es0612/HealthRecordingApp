import Testing
import Foundation
@testable import HealthRecordingApp

@Suite("TrendAnalyzer Tests")
struct TrendAnalyzerTests {
    
    @Test("TrendAnalyzer should calculate simple moving average")
    func testSimpleMovingAverage() async throws {
        // Given
        let logger = AILogger()
        let analyzer = TrendAnalyzer(logger: logger)
        let records = [
            createHealthRecord(value: 70.0, daysAgo: 0),
            createHealthRecord(value: 71.0, daysAgo: 1),
            createHealthRecord(value: 69.0, daysAgo: 2),
            createHealthRecord(value: 72.0, daysAgo: 3),
            createHealthRecord(value: 68.0, daysAgo: 4)
        ]
        
        // When
        let movingAverage = try analyzer.calculateMovingAverage(records: records, period: 3)
        
        // Then
        #expect(movingAverage.count == 3)
        #expect(movingAverage[0].value == 70.0) // (70+71+69)/3 = 70.0
        #expect(abs(movingAverage[1].value - 70.67) < 0.01) // (71+69+72)/3 = 70.67
        #expect(abs(movingAverage[2].value - 69.67) < 0.01) // (69+72+68)/3 = 69.67
    }
    
    @Test("TrendAnalyzer should detect upward trend")
    func testUpwardTrendDetection() async throws {
        // Given
        let logger = AILogger()
        let analyzer = TrendAnalyzer(logger: logger)
        let records = [
            createHealthRecord(value: 68.0, daysAgo: 4),
            createHealthRecord(value: 69.0, daysAgo: 3),
            createHealthRecord(value: 70.0, daysAgo: 2),
            createHealthRecord(value: 71.0, daysAgo: 1),
            createHealthRecord(value: 72.0, daysAgo: 0)
        ]
        
        // When
        let trend = try analyzer.detectTrend(records: records, timeframe: Timeframe.week)
        
        // Then
        #expect(trend.direction == .increasing)
        #expect(trend.strength > 0.8) // Strong upward trend
        #expect(trend.confidence > 0.9) // High confidence
    }
    
    @Test("TrendAnalyzer should detect downward trend")
    func testDownwardTrendDetection() async throws {
        // Given
        let logger = AILogger()
        let analyzer = TrendAnalyzer(logger: logger)
        let records = [
            createHealthRecord(value: 75.0, daysAgo: 4),
            createHealthRecord(value: 73.0, daysAgo: 3),
            createHealthRecord(value: 71.0, daysAgo: 2),
            createHealthRecord(value: 69.0, daysAgo: 1),
            createHealthRecord(value: 67.0, daysAgo: 0)
        ]
        
        // When
        let trend = try analyzer.detectTrend(records: records, timeframe: Timeframe.week)
        
        // Then
        #expect(trend.direction == .decreasing)
        #expect(trend.strength > 0.8) // Strong downward trend
        #expect(trend.confidence > 0.9) // High confidence
    }
    
    @Test("TrendAnalyzer should detect stable trend")
    func testStableTrendDetection() async throws {
        // Given
        let logger = AILogger()
        let analyzer = TrendAnalyzer(logger: logger)
        let records = [
            createHealthRecord(value: 70.0, daysAgo: 4),
            createHealthRecord(value: 70.2, daysAgo: 3),
            createHealthRecord(value: 69.8, daysAgo: 2),
            createHealthRecord(value: 70.1, daysAgo: 1),
            createHealthRecord(value: 69.9, daysAgo: 0)
        ]
        
        // When
        let trend = try analyzer.detectTrend(records: records, timeframe: Timeframe.week)
        
        // Then
        #expect(trend.direction == .stable)
        #expect(trend.strength < 0.3) // Weak trend strength
    }
    
    @Test("TrendAnalyzer should analyze variance and volatility")
    func testVarianceAnalysis() async throws {
        // Given
        let logger = AILogger()
        let analyzer = TrendAnalyzer(logger: logger)
        let stableRecords = [
            createHealthRecord(value: 70.0, daysAgo: 4),
            createHealthRecord(value: 70.1, daysAgo: 3),
            createHealthRecord(value: 69.9, daysAgo: 2),
            createHealthRecord(value: 70.0, daysAgo: 1),
            createHealthRecord(value: 70.0, daysAgo: 0)
        ]
        
        let volatileRecords = [
            createHealthRecord(value: 65.0, daysAgo: 4),
            createHealthRecord(value: 75.0, daysAgo: 3),
            createHealthRecord(value: 68.0, daysAgo: 2),
            createHealthRecord(value: 73.0, daysAgo: 1),
            createHealthRecord(value: 67.0, daysAgo: 0)
        ]
        
        // When
        let stableVariance = analyzer.calculateVariance(records: stableRecords)
        let volatileVariance = analyzer.calculateVariance(records: volatileRecords)
        
        // Then
        #expect(stableVariance < 1.0) // Low variance for stable data
        #expect(volatileVariance > 10.0) // High variance for volatile data
        #expect(volatileVariance > stableVariance)
    }
    
    @Test("TrendAnalyzer should handle insufficient data gracefully")
    func testInsufficientDataHandling() async throws {
        // Given
        let logger = AILogger()
        let analyzer = TrendAnalyzer(logger: logger)
        let records = [createHealthRecord(value: 70.0, daysAgo: 0)]
        
        // When & Then
        do {
            _ = try analyzer.calculateMovingAverage(records: records, period: 3)
            #expect(Bool(false), "Should throw insufficient data error")
        } catch let error as TrendAnalysisError {
            #expect(error == .insufficientData)
        }
    }
    
    @Test("TrendAnalyzer should generate trend analysis report")
    func testTrendAnalysisReport() async throws {
        // Given
        let logger = AILogger()
        let analyzer = TrendAnalyzer(logger: logger)
        let records = createWeeklyWeightData()
        
        // When
        let report = try analyzer.generateAnalysisReport(
            records: records, 
            timeframe: Timeframe.month,
            includeMovingAverage: true,
            movingAveragePeriod: 7
        )
        
        // Then
        #expect(report.dataPoints.count > 0)
        #expect(report.trend != nil)
        #expect(report.movingAverage != nil)
        #expect(report.variance > 0)
        #expect(report.summary.count > 0)
    }
    
    // MARK: - Helper Methods
    
    private func createHealthRecord(value: Double, daysAgo: Int) -> HealthRecord {
        let record = HealthRecord(type: .weight, value: value, unit: "kg")
        // Adjust timestamp to simulate historical data
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        record.timestamp = date
        return record
    }
    
    private func createWeeklyWeightData() -> [HealthRecord] {
        let values = [70.0, 70.5, 69.8, 71.2, 70.1, 69.5, 71.0, 70.3, 69.9, 70.8,
                     71.5, 70.2, 69.7, 71.3, 70.6, 70.0, 71.1, 69.4, 70.9, 70.7,
                     71.8, 70.4, 70.1, 71.6, 70.8, 69.6, 70.5, 71.2, 70.3, 70.0]
        
        return values.enumerated().map { index, value in
            createHealthRecord(value: value, daysAgo: 29 - index)
        }
    }
}