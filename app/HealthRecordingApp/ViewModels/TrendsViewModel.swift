import SwiftUI
import SwiftData
import Foundation

@Observable
final class TrendsViewModel {
    // MARK: - Published Properties
    var trendData: [TrendPoint] = []
    var healthInsights: [HealthInsight] = []
    var isLoading = false
    var errorMessage: String?
    var selectedTimeRange: TimeRange = .month
    var selectedDataType: HealthDataType = .weight
    var trendAnalysis: TrendAnalysis?
    
    // MARK: - Computed Properties
    var hasData: Bool {
        !trendData.isEmpty
    }
    
    var latestTrend: TrendDirection? {
        trendAnalysis?.direction
    }
    
    var trendConfidence: Double {
        trendAnalysis?.confidence ?? 0.0
    }
    
    var chartDataPoints: [ChartDataPoint] {
        trendData.map { point in
            ChartDataPoint(
                date: point.timestamp,
                value: point.value,
                movingAverage: point.movingAverage
            )
        }
    }
    
    var insightCount: Int {
        healthInsights.count
    }
    
    var positiveInsights: [HealthInsight] {
        healthInsights.filter { $0.priority == .informational || $0.priority == .low }
    }
    
    var warningInsights: [HealthInsight] {
        healthInsights.filter { $0.priority == .high || $0.priority == .critical }
    }
    
    // MARK: - Dependencies
    private let fetchHealthDataUseCase: FetchHealthDataUseCaseProtocol
    private let trendAnalyzer: TrendAnalyzerProtocol
    private let logger: AILoggerProtocol
    
    // MARK: - Initialization
    init(
        fetchHealthDataUseCase: FetchHealthDataUseCaseProtocol,
        trendAnalyzer: TrendAnalyzerProtocol = TrendAnalyzer(logger: AILogger()),
        logger: AILoggerProtocol = AILogger()
    ) {
        self.fetchHealthDataUseCase = fetchHealthDataUseCase
        self.trendAnalyzer = trendAnalyzer
        self.logger = logger
        
        logger.debug("TrendsViewModel initialized", context: [
            "selectedTimeRange": selectedTimeRange.rawValue,
            "selectedDataType": selectedDataType.rawValue
        ])
    }
    
    // MARK: - Data Loading & Analysis
    @MainActor
    func loadTrendData() async {
        logger.debug("Starting trend data load", context: nil)
        guard !isLoading else {
            logger.warning("Load already in progress, skipping", context: nil)
            return
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let startTime = Date()
            logger.info("Loading trend data", context: [
                "timeRange": selectedTimeRange.rawValue,
                "dataType": selectedDataType.rawValue
            ])
            
            // Fetch health records (using default user for now)
            let defaultUser = try User(name: "Default", age: 30, height: 170.0, targetWeight: 65.0)
            let allRecords = try await fetchHealthDataUseCase.fetchHealthRecords(
                for: defaultUser,
                type: selectedDataType,
                dateRange: nil,
                limit: nil
            )
            let filteredRecords = filterRecords(allRecords, by: selectedDataType, timeRange: selectedTimeRange)
            
            // Perform trend analysis
            let analysis = try await analyzeTrends(from: filteredRecords)
            
            // Update state
            trendData = analysis.trendPoints
            healthInsights = [] // TODO: Generate insights from analysis
            trendAnalysis = analysis
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("load_trend_data", duration: duration, success: true)
            logger.info("Successfully loaded trend data", context: [
                "trendPointCount": trendData.count,
                "insightCount": healthInsights.count,
                "trendDirection": analysis.direction.rawValue,
                "confidence": analysis.confidence
            ])
            
        } catch {
            let duration = Date().timeIntervalSince(Date())
            logger.logPerformance("load_trend_data", duration: duration, success: false)
            logger.error(error, context: [
                "operation": "load_trend_data",
                "timeRange": selectedTimeRange.rawValue,
                "dataType": selectedDataType.rawValue
            ])
            
            errorMessage = handleError(error)
        }
    }
    
    @MainActor
    func refreshTrendData() async {
        logger.logUserAction("refresh_trend_data", parameters: [
            "timeRange": selectedTimeRange.rawValue,
            "dataType": selectedDataType.rawValue,
            "currentTrendPointCount": trendData.count
        ])
        
        await loadTrendData()
    }
    
    // MARK: - Configuration Updates
    @MainActor
    func updateTimeRange(_ newRange: TimeRange) async {
        logger.logUserAction("change_trend_time_range", parameters: [
            "previousRange": selectedTimeRange.rawValue,
            "newRange": newRange.rawValue
        ])
        
        selectedTimeRange = newRange
        await loadTrendData()
    }
    
    @MainActor
    func updateDataType(_ newType: HealthDataType) async {
        logger.logUserAction("change_trend_data_type", parameters: [
            "previousType": selectedDataType.rawValue,
            "newType": newType.rawValue
        ])
        
        selectedDataType = newType
        await loadTrendData()
    }
    
    // MARK: - Trend Analysis
    private func analyzeTrends(from records: [HealthRecord]) async throws -> TrendAnalysis {
        let startTime = Date()
        
        do {
            let analysis = try await trendAnalyzer.analyzeTrends(from: records, timeRange: selectedTimeRange)
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("trend_analysis", duration: duration, success: true)
            
            return analysis
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("trend_analysis", duration: duration, success: false)
            logger.error(error, context: [
                "operation": "trend_analysis",
                "recordCount": records.count
            ])
            
            throw error
        }
    }
    
    // MARK: - Data Processing
    private func filterRecords(_ records: [HealthRecord], by type: HealthDataType, timeRange: TimeRange) -> [HealthRecord] {
        let now = Date()
        let startDate: Date
        
        switch timeRange {
        case .week:
            startDate = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            startDate = Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now
        case .threeMonths:
            startDate = Calendar.current.date(byAdding: .month, value: -3, to: now) ?? now
        case .sixMonths:
            startDate = Calendar.current.date(byAdding: .month, value: -6, to: now) ?? now
        case .year:
            startDate = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now
        }
        
        return records
            .filter { $0.type == type }
            .filter { $0.timestamp >= startDate }
            .sorted { $0.timestamp < $1.timestamp }
    }
    
    // MARK: - Insight Management
    @MainActor
    func getInsightDetail(_ insight: HealthInsight) -> InsightDetail {
        logger.logUserAction("view_insight_detail", parameters: [
            "insightType": insight.category.rawValue,
            "confidence": insight.confidence
        ])
        
        return InsightDetail(
            insight: insight,
            relatedDataPoints: getRelatedDataPoints(for: insight),
            recommendations: generateRecommendations(for: insight)
        )
    }
    
    private func getRelatedDataPoints(for insight: HealthInsight) -> [TrendPoint] {
        // Find trend points related to this insight's time period
        let relatedPoints = trendData.filter { point in
            // Simple implementation - could be more sophisticated
            abs(point.timestamp.timeIntervalSince(insight.generatedAt)) < 7 * 24 * 60 * 60 // Within 7 days
        }
        
        return relatedPoints
    }
    
    private func generateRecommendations(for insight: HealthInsight) -> [String] {
        // Generate contextual recommendations based on insight type and trend
        switch insight.priority {
        case .informational, .low:
            return [
                "現在の調子を維持しましょう",
                "この成果を記録して継続のモチベーションに活用しましょう"
            ]
        case .medium:
            return [
                "安定した状態です",
                "小さな改善を積み重ねていきましょう"
            ]
        case .high, .critical:
            return [
                "注意が必要な傾向が見られます",
                "生活習慣を見直してみることをお勧めします",
                "必要に応じて専門家に相談することを検討してください"
            ]
        }
    }
    
    // MARK: - Chart Configuration
    func getChartConfiguration() -> ChartConfiguration {
        return ChartConfiguration(
            dataType: selectedDataType,
            timeRange: selectedTimeRange,
            showMovingAverage: true,
            showTrendLine: trendConfidence > 0.6,
            colorScheme: getColorScheme()
        )
    }
    
    private func getColorScheme() -> ChartColorScheme {
        switch latestTrend {
        case .increasing:
            return selectedDataType == .weight ? .warning : .positive
        case .decreasing:
            return selectedDataType == .weight ? .positive : .warning
        case .stable:
            return .neutral
        case .volatile:
            return .warning
        case .none:
            return .neutral
        }
    }
    
    // MARK: - Error Handling
    @MainActor
    func clearError() {
        errorMessage = nil
        logger.debug("Trend error message cleared by user", context: nil)
    }
    
    private func handleError(_ error: Error) -> String {
        if let trendAnalysisError = error as? TrendAnalysisError {
            switch trendAnalysisError {
            case .insufficientData:
                return "トレンド分析には十分なデータが必要です。もう少しデータを蓄積してからお試しください。"
            case .invalidPeriod:
                return "無効な期間が指定されました。"
            case .invalidTimeframe:
                return "無効な時間フレームが指定されました。"
            case .calculationFailed(let message):
                return "計算エラー: \(message)"
            }
        }
        
        if let healthAppError = error as? any HealthAppError {
            return healthAppError.localizedDescription
        }
        
        return "トレンド分析中にエラーが発生しました: \(error.localizedDescription)"
    }
}

// MARK: - Supporting Types
// Note: TimeRange is defined in CommonTypes.swift to avoid duplication

struct ChartDataPoint {
    let date: Date
    let value: Double
    let movingAverage: Double?
    
    var formattedValue: String {
        String(format: "%.1f", value)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct InsightDetail {
    let insight: HealthInsight
    let relatedDataPoints: [TrendPoint]
    let recommendations: [String]
}

struct ChartConfiguration {
    let dataType: HealthDataType
    let timeRange: TimeRange
    let showMovingAverage: Bool
    let showTrendLine: Bool
    let colorScheme: ChartColorScheme
}

enum ChartColorScheme {
    case positive
    case warning
    case neutral
    
    var primaryColor: Color {
        switch self {
        case .positive: return .green
        case .warning: return .orange
        case .neutral: return .blue
        }
    }
    
    var secondaryColor: Color {
        switch self {
        case .positive: return .green.opacity(0.3)
        case .warning: return .orange.opacity(0.3)
        case .neutral: return .blue.opacity(0.3)
        }
    }
}