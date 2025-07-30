import Testing
import Foundation
import SwiftData
@testable import HealthRecordingApp

@Suite("TrendsViewModel Tests")
struct TrendsViewModelTests {
    
    private func createMockDependencies() -> (FetchHealthDataUseCaseProtocol, TrendAnalyzerProtocol, AILoggerProtocol) {
        let mockFetchUseCase = MockFetchHealthDataUseCase()
        let mockTrendAnalyzer = MockTrendAnalyzer()
        let mockLogger = MockAILogger()
        return (mockFetchUseCase, mockTrendAnalyzer, mockLogger)
    }
    
    private func createViewModel() -> TrendsViewModel {
        let (fetchUseCase, trendAnalyzer, logger) = createMockDependencies()
        return TrendsViewModel(
            fetchHealthDataUseCase: fetchUseCase,
            trendAnalyzer: trendAnalyzer,
            logger: logger
        )
    }
    
    @Test("TrendsViewModel should initialize with default values")
    func testInitialization() async throws {
        // Given & When
        let viewModel = createViewModel()
        
        // Then
        #expect(viewModel.trendData.isEmpty)
        #expect(viewModel.healthInsights.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.selectedTimeRange == .month)
        #expect(viewModel.selectedDataType == .weight)
        #expect(viewModel.hasData == false)
        #expect(viewModel.trendConfidence == 0.0)
        #expect(viewModel.insightCount == 0)
    }
    
    @Test("TrendsViewModel should load trend data successfully")
    func testLoadTrendDataSuccess() async throws {
        // Given
        let (fetchUseCase, trendAnalyzer, logger) = createMockDependencies()
        let mockFetchUseCase = fetchUseCase as! MockFetchHealthDataUseCase
        let mockTrendAnalyzer = trendAnalyzer as! MockTrendAnalyzer
        
        let sampleRecords = [
            HealthRecord(type: .weight, value: 70.0, unit: "kg"),
            HealthRecord(type: .weight, value: 69.5, unit: "kg")
        ]
        mockFetchUseCase.mockRecords = sampleRecords
        
        let mockAnalysis = TrendAnalysis(
            trendPoints: [
                TrendPoint(date: Date(), value: 70.0, movingAverage: 69.75),
                TrendPoint(date: Date(), value: 69.5, movingAverage: 69.75)
            ],
            insights: [
                HealthInsight(
                    title: "体重減少トレンド",
                    description: "体重が順調に減少しています",
                    type: .positive,
                    confidence: 0.8,
                    generatedAt: Date()
                )
            ],
            overallTrend: .decreasing,
            confidence: 0.8,
            timeRange: .month,
            dataType: .weight
        )
        mockTrendAnalyzer.mockAnalysis = mockAnalysis
        
        let viewModel = TrendsViewModel(
            fetchHealthDataUseCase: fetchUseCase,
            trendAnalyzer: trendAnalyzer,
            logger: logger
        )
        
        // When
        await viewModel.loadTrendData()
        
        // Then
        #expect(viewModel.trendData.count == 2)
        #expect(viewModel.healthInsights.count == 1)
        #expect(viewModel.hasData == true)
        #expect(viewModel.latestTrend == .decreasing)
        #expect(viewModel.trendConfidence == 0.8)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }
    
    @Test("TrendsViewModel should handle load error gracefully")
    func testLoadTrendDataError() async throws {
        // Given
        let (fetchUseCase, trendAnalyzer, logger) = createMockDependencies()
        let mockFetchUseCase = fetchUseCase as! MockFetchHealthDataUseCase
        mockFetchUseCase.shouldThrowError = true
        
        let viewModel = TrendsViewModel(
            fetchHealthDataUseCase: fetchUseCase,
            trendAnalyzer: trendAnalyzer,
            logger: logger
        )
        
        // When
        await viewModel.loadTrendData()
        
        // Then
        #expect(viewModel.trendData.isEmpty)
        #expect(viewModel.healthInsights.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage != nil)
    }
    
    @Test("TrendsViewModel should update time range and reload data")
    func testUpdateTimeRange() async throws {
        // Given
        let (fetchUseCase, trendAnalyzer, logger) = createMockDependencies()
        let mockTrendAnalyzer = trendAnalyzer as! MockTrendAnalyzer
        
        let viewModel = TrendsViewModel(
            fetchHealthDataUseCase: fetchUseCase,
            trendAnalyzer: trendAnalyzer,
            logger: logger
        )
        
        // When
        await viewModel.updateTimeRange(.year)
        
        // Then
        #expect(viewModel.selectedTimeRange == .year)
        #expect(mockTrendAnalyzer.analyzeTrendsCallCount == 1)
    }
    
    @Test("TrendsViewModel should update data type and reload data")
    func testUpdateDataType() async throws {
        // Given
        let (fetchUseCase, trendAnalyzer, logger) = createMockDependencies()
        let mockTrendAnalyzer = trendAnalyzer as! MockTrendAnalyzer
        
        let viewModel = TrendsViewModel(
            fetchHealthDataUseCase: fetchUseCase,
            trendAnalyzer: trendAnalyzer,
            logger: logger
        )
        
        // When
        await viewModel.updateDataType(.steps)
        
        // Then
        #expect(viewModel.selectedDataType == .steps)
        #expect(mockTrendAnalyzer.analyzeTrendsCallCount == 1)
    }
    
    @Test("TrendsViewModel should generate chart data points correctly")
    func testChartDataPoints() async throws {
        // Given
        let (fetchUseCase, trendAnalyzer, logger) = createMockDependencies()
        let mockTrendAnalyzer = trendAnalyzer as! MockTrendAnalyzer
        
        let date1 = Date()
        let date2 = Calendar.current.date(byAdding: .day, value: 1, to: date1)!
        
        let mockAnalysis = TrendAnalysis(
            trendPoints: [
                TrendPoint(date: date1, value: 70.0, movingAverage: 69.75),
                TrendPoint(date: date2, value: 69.5, movingAverage: 69.75)
            ],
            insights: [],
            overallTrend: .decreasing,
            confidence: 0.8,
            timeRange: .month,
            dataType: .weight
        )
        mockTrendAnalyzer.mockAnalysis = mockAnalysis
        
        let viewModel = TrendsViewModel(
            fetchHealthDataUseCase: fetchUseCase,
            trendAnalyzer: trendAnalyzer,
            logger: logger
        )
        
        await viewModel.loadTrendData()
        
        // When
        let chartDataPoints = viewModel.chartDataPoints
        
        // Then
        #expect(chartDataPoints.count == 2)
        #expect(chartDataPoints[0].value == 70.0)
        #expect(chartDataPoints[0].movingAverage == 69.75)
        #expect(chartDataPoints[1].value == 69.5)
    }
    
    @Test("TrendsViewModel should categorize insights correctly")
    func testInsightCategorization() async throws {
        // Given
        let (fetchUseCase, trendAnalyzer, logger) = createMockDependencies()
        let mockTrendAnalyzer = trendAnalyzer as! MockTrendAnalyzer
        
        let mockAnalysis = TrendAnalysis(
            trendPoints: [],
            insights: [
                HealthInsight(
                    title: "Good Progress",
                    description: "Positive trend",
                    type: .positive,
                    confidence: 0.8,
                    generatedAt: Date()
                ),
                HealthInsight(
                    title: "Needs Attention",
                    description: "Warning trend",
                    type: .warning,
                    confidence: 0.7,
                    generatedAt: Date()
                ),
                HealthInsight(
                    title: "Stable",
                    description: "Neutral trend",
                    type: .neutral,
                    confidence: 0.6,
                    generatedAt: Date()
                )
            ],
            overallTrend: .stable,
            confidence: 0.7,
            timeRange: .month,
            dataType: .weight
        )
        mockTrendAnalyzer.mockAnalysis = mockAnalysis
        
        let viewModel = TrendsViewModel(
            fetchHealthDataUseCase: fetchUseCase,
            trendAnalyzer: trendAnalyzer,
            logger: logger
        )
        
        await viewModel.loadTrendData()
        
        // When
        let positiveInsights = viewModel.positiveInsights
        let warningInsights = viewModel.warningInsights
        
        // Then
        #expect(positiveInsights.count == 1)
        #expect(warningInsights.count == 1)
        #expect(positiveInsights.first?.type == .positive)
        #expect(warningInsights.first?.type == .warning)
    }
    
    @Test("TrendsViewModel should get insight detail with recommendations")
    func testGetInsightDetail() async throws {
        // Given
        let viewModel = createViewModel()
        let insight = HealthInsight(
            title: "Test Insight",
            description: "Test Description",
            type: .positive,
            confidence: 0.8,
            generatedAt: Date()
        )
        
        // When
        let insightDetail = await viewModel.getInsightDetail(insight)
        
        // Then
        #expect(insightDetail.insight.title == "Test Insight")
        #expect(!insightDetail.recommendations.isEmpty)
        #expect(insightDetail.recommendations.contains("現在の調子を維持しましょう"))
        #expect(insightDetail.relatedDataPoints.isEmpty) // No trend data loaded
    }
    
    @Test("TrendsViewModel should generate chart configuration correctly")
    func testGetChartConfiguration() async throws {
        // Given
        let (fetchUseCase, trendAnalyzer, logger) = createMockDependencies()
        let mockTrendAnalyzer = trendAnalyzer as! MockTrendAnalyzer
        
        let mockAnalysis = TrendAnalysis(
            trendPoints: [],
            insights: [],
            overallTrend: .increasing,
            confidence: 0.8,
            timeRange: .month,
            dataType: .weight
        )
        mockTrendAnalyzer.mockAnalysis = mockAnalysis
        
        let viewModel = TrendsViewModel(
            fetchHealthDataUseCase: fetchUseCase,
            trendAnalyzer: trendAnalyzer,
            logger: logger
        )
        
        await viewModel.loadTrendData()
        
        // When
        let chartConfig = viewModel.getChartConfiguration()
        
        // Then
        #expect(chartConfig.dataType == .weight)
        #expect(chartConfig.timeRange == .month)
        #expect(chartConfig.showMovingAverage == true)
        #expect(chartConfig.showTrendLine == true) // Confidence > 0.6
        #expect(chartConfig.colorScheme == .warning) // Weight increasing is warning
    }
    
    @Test("TrendsViewModel should clear error message")
    func testClearError() async throws {
        // Given
        let (fetchUseCase, trendAnalyzer, logger) = createMockDependencies()
        let mockFetchUseCase = fetchUseCase as! MockFetchHealthDataUseCase
        mockFetchUseCase.shouldThrowError = true
        
        let viewModel = TrendsViewModel(
            fetchHealthDataUseCase: fetchUseCase,
            trendAnalyzer: trendAnalyzer,
            logger: logger
        )
        
        await viewModel.loadTrendData()
        #expect(viewModel.errorMessage != nil)
        
        // When
        await viewModel.clearError()
        
        // Then
        #expect(viewModel.errorMessage == nil)
    }
    
    @Test("TrendsViewModel should handle trend analysis error")
    func testTrendAnalysisError() async throws {
        // Given
        let (fetchUseCase, trendAnalyzer, logger) = createMockDependencies()
        let mockTrendAnalyzer = trendAnalyzer as! MockTrendAnalyzer
        mockTrendAnalyzer.shouldThrowError = true
        
        let viewModel = TrendsViewModel(
            fetchHealthDataUseCase: fetchUseCase,
            trendAnalyzer: trendAnalyzer,
            logger: logger
        )
        
        // When
        await viewModel.loadTrendData()
        
        // Then
        #expect(viewModel.trendData.isEmpty)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("トレンド分析中にエラーが発生しました") == true)
    }
    
    @Test("TrendsViewModel should prevent concurrent loading")
    func testConcurrentLoadingPrevention() async throws {
        // Given
        let (fetchUseCase, trendAnalyzer, logger) = createMockDependencies()
        let mockTrendAnalyzer = trendAnalyzer as! MockTrendAnalyzer
        mockTrendAnalyzer.shouldDelay = true
        
        let viewModel = TrendsViewModel(
            fetchHealthDataUseCase: fetchUseCase,
            trendAnalyzer: trendAnalyzer,
            logger: logger
        )
        
        // When - Start two concurrent loads
        async let load1 = viewModel.loadTrendData()
        async let load2 = viewModel.loadTrendData()
        
        await load1
        await load2
        
        // Then - Only one load should have executed
        #expect(mockTrendAnalyzer.analyzeTrendsCallCount == 1)
    }
}

// MARK: - Mock Classes
final class MockTrendAnalyzer: TrendAnalyzerProtocol {
    var mockAnalysis: TrendAnalysis?
    var shouldThrowError = false
    var shouldDelay = false
    var analyzeTrendsCallCount = 0
    
    func analyzeTrends(from records: [HealthRecordProtocol], timeRange: TimeRange) async throws -> TrendAnalysis {
        analyzeTrendsCallCount += 1
        
        if shouldDelay {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        if shouldThrowError {
            throw TrendAnalysisError.insufficientData
        }
        
        return mockAnalysis ?? TrendAnalysis(
            trendPoints: [],
            insights: [],
            overallTrend: .stable,
            confidence: 0.5,
            timeRange: timeRange,
            dataType: .weight
        )
    }
    
    func calculateMovingAverage(from records: [HealthRecordProtocol], windowSize: Int) -> [TrendPoint] {
        return []
    }
    
    func detectTrendDirection(from trendPoints: [TrendPoint]) -> TrendDirection {
        return .stable
    }
    
    func generateHealthInsights(from analysis: TrendAnalysis) -> [HealthInsight] {
        return []
    }
    
    func calculateTrendConfidence(from trendPoints: [TrendPoint]) -> Double {
        return 0.5
    }
    
    func analyzeVarianceAndVolatility(from records: [HealthRecordProtocol]) -> VarianceAnalysis {
        return VarianceAnalysis(variance: 0.0, volatility: 0.0, consistency: 0.5)
    }
}

// TrendAnalysisError for testing
enum TrendAnalysisError: Error {
    case insufficientData
    case invalidTimeRange
    case invalidDataType
}