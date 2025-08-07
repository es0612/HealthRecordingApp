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
    
    // MARK: - Chart Data Properties
    
    var latestValue: Double? {
        chartDataPoints.last?.value
    }
    
    var averageValue: Double? {
        guard !chartDataPoints.isEmpty else { return nil }
        let total = chartDataPoints.reduce(0.0) { $0 + $1.value }
        return total / Double(chartDataPoints.count)
    }
    
    var maximumValue: Double? {
        chartDataPoints.map(\.value).max()
    }
    
    var minimumValue: Double? {
        chartDataPoints.map(\.value).min()
    }
    
    var changeRate: Double? {
        guard chartDataPoints.count >= 2,
              let firstValue = chartDataPoints.first?.value,
              let lastValue = chartDataPoints.last?.value,
              firstValue > 0 else { return nil }
        
        return ((lastValue - firstValue) / firstValue) * 100
    }
    
    // MARK: - Health Data Type Specific Properties
    
    var targetWeight: Double? {
        // TODO: Get from user's active weight goal
        selectedDataType == .weight ? 70.0 : nil
    }
    
    var dailyStepsGoal: Double? {
        // TODO: Get from user's active steps goal
        selectedDataType == .steps ? 10000 : nil
    }
    
    var dailyCaloriesGoal: Double? {
        // TODO: Get from user's active calories goal or calculated BMR
        selectedDataType == .calories ? 2200 : nil
    }
    
    var restingHeartRate: Double? {
        // TODO: Calculate from user's heart rate history
        selectedDataType == .heartRate ? 65.0 : nil
    }
    
    var maxHeartRate: Double? {
        // TODO: Calculate based on age (220 - age formula)
        selectedDataType == .heartRate ? 190.0 : nil
    }
    
    // MARK: - Data Type Specific Insights
    
    var isAboveTarget: Bool {
        guard let latest = latestValue else { return false }
        
        switch selectedDataType {
        case .weight:
            return targetWeight.map { latest > $0 } ?? false
        case .steps:
            return dailyStepsGoal.map { latest > $0 } ?? false
        case .calories:
            return dailyCaloriesGoal.map { latest > $0 } ?? false
        case .heartRate:
            return maxHeartRate.map { latest > $0 * 0.85 } ?? false
        case .bloodGlucose:
            return latest > 100 // Normal upper limit
        }
    }
    
    var isBelowTarget: Bool {
        guard let latest = latestValue else { return false }
        
        switch selectedDataType {
        case .weight:
            return targetWeight.map { latest < $0 * 0.95 } ?? false
        case .steps:
            return dailyStepsGoal.map { latest < $0 * 0.8 } ?? false
        case .calories:
            return dailyCaloriesGoal.map { latest < $0 * 0.8 } ?? false
        case .heartRate:
            return restingHeartRate.map { latest < $0 } ?? false
        case .bloodGlucose:
            return latest < 70 // Low blood sugar threshold
        }
    }
    
    var progressPercentage: Double {
        guard let latest = latestValue else { return 0.0 }
        
        switch selectedDataType {
        case .weight:
            guard let target = targetWeight else { return 0.0 }
            return (latest / target) * 100
        case .steps:
            guard let goal = dailyStepsGoal else { return 0.0 }
            return min((latest / goal) * 100, 100)
        case .calories:
            guard let goal = dailyCaloriesGoal else { return 0.0 }
            return (latest / goal) * 100
        case .heartRate:
            guard let max = maxHeartRate else { return 0.0 }
            return (latest / max) * 100
        case .bloodGlucose:
            // Return percentage within normal range (80-100 mg/dL)
            let normalRange = 100.0 - 80.0
            let position = min(max(latest - 80.0, 0), normalRange)
            return (position / normalRange) * 100
        }
    }
    
    // MARK: - Trend Performance Analysis
    
    var weeklyPerformanceTrend: PerformanceTrend {
        guard chartDataPoints.count >= 7 else { return .insufficient }
        
        let recentWeek = Array(chartDataPoints.suffix(7))
        let averageRecent = recentWeek.reduce(0.0) { $0 + $1.value } / 7.0
        
        if chartDataPoints.count >= 14 {
            let previousWeek = Array(chartDataPoints.dropLast(7).suffix(7))
            let averagePrevious = previousWeek.reduce(0.0) { $0 + $1.value } / 7.0
            
            let changePercent = ((averageRecent - averagePrevious) / averagePrevious) * 100
            
            switch selectedDataType {
            case .weight:
                if abs(changePercent) < 1.0 { return .stable }
                return targetWeight.map { averageRecent > $0 } == true ?
                    (changePercent > 0 ? .declining : .improving) :
                    (changePercent > 0 ? .improving : .declining)
            case .steps:
                if abs(changePercent) < 5.0 { return .stable }
                return changePercent > 0 ? .improving : .declining
            case .calories:
                if abs(changePercent) < 3.0 { return .stable }
                return changePercent > 0 ? .improving : .declining
            case .heartRate:
                if abs(changePercent) < 2.0 { return .stable }
                return changePercent < 0 ? .improving : .declining
            case .bloodGlucose:
                if abs(changePercent) < 5.0 { return .stable }
                return changePercent < 0 ? .improving : .declining
            }
        }
        
        return .stable
    }
    
    var streakCount: Int {
        // Calculate consecutive days meeting goals
        guard !chartDataPoints.isEmpty else { return 0 }
        
        var streak = 0
        for dataPoint in chartDataPoints.reversed() {
            let meetsGoal = checkGoalMetForDataPoint(dataPoint)
            if meetsGoal {
                streak += 1
            } else {
                break
            }
        }
        
        return streak
    }
    
    var bestStreak: Int {
        guard !chartDataPoints.isEmpty else { return 0 }
        
        var bestStreak = 0
        var currentStreak = 0
        
        for dataPoint in chartDataPoints {
            let meetsGoal = checkGoalMetForDataPoint(dataPoint)
            if meetsGoal {
                currentStreak += 1
                bestStreak = max(bestStreak, currentStreak)
            } else {
                currentStreak = 0
            }
        }
        
        return bestStreak
    }
    
    private func checkGoalMetForDataPoint(_ dataPoint: ChartDataPoint) -> Bool {
        switch selectedDataType {
        case .weight:
            return targetWeight.map { abs(dataPoint.value - $0) <= $0 * 0.02 } ?? false
        case .steps:
            return dailyStepsGoal.map { dataPoint.value >= $0 } ?? false
        case .calories:
            return dailyCaloriesGoal.map { abs(dataPoint.value - $0) <= $0 * 0.1 } ?? false
        case .heartRate:
            // Goal is to stay within healthy resting range during rest
            return dataPoint.value >= 60 && dataPoint.value <= 100
        case .bloodGlucose:
            // Goal is to stay within normal range
            return dataPoint.value >= 80 && dataPoint.value <= 100
        }
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
    
    // MARK: - Data Update Methods
    
    @MainActor
    func updateTimeRange(_ newRange: TrendTimeRange) {
        logger.logUserAction("update_time_range", parameters: [
            "oldRange": selectedTimeRange.rawValue,
            "newRange": newRange.rawValue
        ])
        
        // Convert TrendTimeRange to TimeRange
        let timeRange: TimeRange
        switch newRange {
        case .week:
            timeRange = .week
        case .month:
            timeRange = .month
        case .quarter:
            timeRange = .threeMonths
        case .year:
            timeRange = .year
        }
        
        selectedTimeRange = timeRange
        
        // Reload data with new time range
        Task {
            await loadTrendData()
        }
    }
    
    @MainActor
    func updateDataType(_ newType: HealthDataType) {
        logger.logUserAction("update_data_type", parameters: [
            "oldType": selectedDataType.rawValue,
            "newType": newType.rawValue
        ])
        
        selectedDataType = newType
        
        // Reload data with new data type
        Task {
            await loadTrendData()
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

enum PerformanceTrend: String, CaseIterable {
    case improving = "improving"
    case declining = "declining"
    case stable = "stable"
    case insufficient = "insufficient"
    
    var displayName: String {
        switch self {
        case .improving: return "改善中"
        case .declining: return "悪化中"
        case .stable: return "安定"
        case .insufficient: return "データ不足"
        }
    }
    
    var color: Color {
        switch self {
        case .improving: return .green
        case .declining: return .red
        case .stable: return .blue
        case .insufficient: return .gray
        }
    }
    
    var iconName: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .declining: return "arrow.down.right"
        case .stable: return "arrow.right"
        case .insufficient: return "questionmark"
        }
    }
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let movingAverage: Double?
    var isSelected: Bool = false
    
    // Convenience computed property for Charts framework compatibility
    var timestamp: Date {
        return date
    }
    
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