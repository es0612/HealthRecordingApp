import Foundation
import SwiftUI

@Observable
final class HealthInsightsViewModel {
    // MARK: - Published Properties
    
    var healthInsights: [HealthInsight] = []
    var quickInsights: [HealthInsight] = []
    var priorityRecommendations: [PersonalizedRecommendation] = []
    var latestAnomalies: [AnomalousPattern] = []
    var keyCorrelations: [AdvancedCorrelationResult] = []
    var monthlyReport: ComprehensiveMonthlyReport?
    var monthlyReportPreview: MonthlyReportPreview?
    var enhancedAnomalyResult: EnhancedAnomalyResult?
    var advancedCorrelationResults: [AdvancedCorrelationResult] = []
    
    var dataQualityScore: Double = 0.85
    var lastUpdated: Date = Date()
    var currentMonth: Date = Date()
    var isLoading: Bool = false
    var errorMessage: String?
    
    // MARK: - Dependencies
    
    private let insightEngine: InsightEngineProtocol
    private let userRepository: UserRepositoryProtocol
    private let healthRecordRepository: HealthRecordRepositoryProtocol
    private let logger: AILoggerProtocol
    
    // MARK: - Initialization
    
    init(
        insightEngine: InsightEngineProtocol = InsightEngine(),
        userRepository: UserRepositoryProtocol = SwiftDataUserRepository(),
        healthRecordRepository: HealthRecordRepositoryProtocol = SwiftDataHealthRecordRepository(),
        logger: AILoggerProtocol = AILogger()
    ) {
        self.insightEngine = insightEngine
        self.userRepository = userRepository
        self.healthRecordRepository = healthRecordRepository
        self.logger = logger
    }
    
    // MARK: - Public Methods
    
    @MainActor
    func loadInsights(timeframe: InsightTimeframe, focusAreas: Set<HealthFocusArea>) async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            logger.debug("Loading health insights", context: [
                "timeframe": timeframe.rawValue,
                "focusAreas": focusAreas.map { $0.rawValue }
            ])
            
            // Get current user
            guard let currentUser = try await getCurrentUser() else {
                throw ValidationError.invalidInput("HealthInsightsViewModel", value: "no_user", reason: "No current user found")
            }
            
            // Load comprehensive insights
            await loadComprehensiveInsights(for: currentUser, timeframe: timeframe, focusAreas: focusAreas)
            
            // Update data quality score
            dataQualityScore = calculateDataQualityScore(for: currentUser)
            lastUpdated = Date()
            
            logger.info("Health insights loaded successfully", context: [
                "insightsCount": healthInsights.count,
                "anomaliesCount": latestAnomalies.count,
                "correlationsCount": keyCorrelations.count,
                "dataQualityScore": dataQualityScore
            ])
            
        } catch {
            logger.error(error, context: [
                "operation": "loadInsights",
                "timeframe": timeframe.rawValue
            ])
            errorMessage = "インサイトの読み込みに失敗しました: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    @MainActor
    func refreshInsights(timeframe: InsightTimeframe, focusAreas: Set<HealthFocusArea>) async {
        await loadInsights(timeframe: timeframe, focusAreas: focusAreas)
    }
    
    @MainActor
    func generateMonthlyReport(for month: Date) async {
        guard !isLoading else { return }
        
        isLoading = true
        
        do {
            guard let currentUser = try await getCurrentUser() else {
                throw ValidationError.invalidInput("HealthInsightsViewModel", value: "no_user", reason: "No current user found")
            }
            
            logger.debug("Generating monthly report", context: [
                "userId": currentUser.id.uuidString,
                "month": ISO8601DateFormatter().string(from: month)
            ])
            
            let report = try await insightEngine.generateComprehensiveMonthlyReport(
                for: currentUser,
                month: month,
                includeAdvancedAnalytics: true
            )
            
            monthlyReport = report
            monthlyReportPreview = createReportPreview(from: report)
            
            logger.info("Monthly report generated successfully", context: [
                "reportId": report.id.uuidString,
                "recommendationsCount": report.personalizedRecommendations.count
            ])
            
        } catch {
            logger.error(error, context: [
                "operation": "generateMonthlyReport",
                "month": ISO8601DateFormatter().string(from: month)
            ])
            errorMessage = "月次レポートの生成に失敗しました: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    private func getCurrentUser() async throws -> User? {
        // In a real app, this would get the current authenticated user
        // For now, we'll create a mock user or get from repository
        return try await userRepository.getAllUsers().first
    }
    
    private func loadComprehensiveInsights(
        for user: User,
        timeframe: InsightTimeframe,
        focusAreas: Set<HealthFocusArea>
    ) async {
        async let insightsTask = loadHealthInsights(for: user, timeframe: timeframe, focusAreas: focusAreas)
        async let anomaliesTask = loadAnomalyDetection(for: user)
        async let correlationsTask = loadCorrelationAnalysis(for: user)
        async let monthlyReportTask = loadMonthlyReport(for: user)
        
        do {
            let (insights, anomalies, correlations, report) = try await (
                insightsTask,
                anomaliesTask,
                correlationsTask,
                monthlyReportTask
            )
            
            healthInsights = insights
            quickInsights = insights.prefix(4).map { $0 }
            priorityRecommendations = extractPriorityRecommendations(from: insights)
            latestAnomalies = anomalies?.detectedAnomalies.prefix(3).map { $0 } ?? []
            keyCorrelations = correlations.prefix(3).map { $0 }
            enhancedAnomalyResult = anomalies
            advancedCorrelationResults = correlations
            monthlyReport = report
            monthlyReportPreview = report.map(createReportPreview)
            
        } catch {
            logger.warning("Some insights failed to load", context: [
                "error": error.localizedDescription
            ])
        }
    }
    
    private func loadHealthInsights(
        for user: User,
        timeframe: InsightTimeframe,
        focusAreas: Set<HealthFocusArea>
    ) async throws -> [HealthInsight] {
        return try await insightEngine.generateHealthInsights(
            for: user,
            timeframe: timeframe,
            focusAreas: focusAreas
        )
    }
    
    private func loadAnomalyDetection(for user: User) async throws -> EnhancedAnomalyResult? {
        let healthRecords = user.healthRecords
        guard !healthRecords.isEmpty else { return nil }
        
        // Get baseline data (previous month)
        let calendar = Calendar.current
        let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let baselineData = healthRecords.filter { $0.timestamp < oneMonthAgo }
        
        guard !baselineData.isEmpty else { return nil }
        
        let recentData = healthRecords.filter { $0.timestamp >= oneMonthAgo }
        
        return try await insightEngine.detectEnhancedAnomalousPatterns(
            in: recentData,
            baselineData: baselineData,
            detectionMethods: [.statisticalThreshold, .isolationForest, .timeSeriesDecomposition]
        )
    }
    
    private func loadCorrelationAnalysis(for user: User) async throws -> [AdvancedCorrelationResult] {
        let healthRecords = user.healthRecords
        guard healthRecords.count >= 20 else { return [] }
        
        // Group by data types
        let dataTypes = Set(healthRecords.map { $0.type })
        guard dataTypes.count >= 2 else { return [] }
        
        var correlationResults: [AdvancedCorrelationResult] = []
        let dataTypeArray = Array(dataTypes)
        
        // Analyze correlations between data types
        for i in 0..<min(dataTypeArray.count - 1, 3) {
            for j in (i + 1)..<min(dataTypeArray.count, 4) {
                let primaryType = dataTypeArray[i]
                let secondaryType = dataTypeArray[j]
                
                let primaryData = healthRecords.filter { $0.type == primaryType }
                let secondaryData = healthRecords.filter { $0.type == secondaryType }
                
                if primaryData.count >= 10 && secondaryData.count >= 10 {
                    do {
                        let result = try await insightEngine.analyzeAdvancedCorrelations(
                            between: primaryData,
                            and: secondaryData,
                            analysisOptions: AdvancedCorrelationOptions(
                                minimumSampleSize: 10,
                                timeWindow: .weekly,
                                maxLagDays: 7
                            )
                        )
                        correlationResults.append(result)
                    } catch {
                        logger.warning("Correlation analysis failed", context: [
                            "primaryType": primaryType.rawValue,
                            "secondaryType": secondaryType.rawValue,
                            "error": error.localizedDescription
                        ])
                    }
                }
            }
        }
        
        return correlationResults.sorted { 
            abs($0.correlationResults[.pearson] ?? 0) > abs($1.correlationResults[.pearson] ?? 0)
        }
    }
    
    private func loadMonthlyReport(for user: User) async throws -> ComprehensiveMonthlyReport? {
        let calendar = Calendar.current
        let currentMonth = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        
        do {
            return try await insightEngine.generateComprehensiveMonthlyReport(
                for: user,
                month: currentMonth,
                includeAdvancedAnalytics: true
            )
        } catch {
            logger.warning("Monthly report generation failed", context: [
                "error": error.localizedDescription
            ])
            return nil
        }
    }
    
    private func extractPriorityRecommendations(from insights: [HealthInsight]) -> [PersonalizedRecommendation] {
        return insights
            .compactMap { insight -> PersonalizedRecommendation? in
                guard insight.actionability == .high,
                      let recommendation = insight.recommendations.first else { return nil }
                
                return PersonalizedRecommendation(
                    title: insight.title,
                    description: insight.summary,
                    category: insight.category,
                    actionItem: recommendation,
                    personalizationFactors: [],
                    implementationComplexity: .medium,
                    expectedImpact: .high,
                    timeline: .immediate,
                    adaptationOptions: []
                )
            }
            .prefix(5)
            .map { $0 }
    }
    
    private func createReportPreview(from report: ComprehensiveMonthlyReport) -> MonthlyReportPreview {
        let keyMetrics = report.keyMetrics.prefix(4).compactMap { insight -> MonthlyReportPreview.KeyMetric? in
            // Extract metric information from insight
            return MonthlyReportPreview.KeyMetric(
                type: .weight, // This would be derived from insight
                displayValue: "72.5 kg",
                trend: .improving,
                changeText: "+0.5kg"
            )
        }
        
        return MonthlyReportPreview(
            keyMetrics: Array(keyMetrics),
            insightCount: report.keyMetrics.count,
            anomalyCount: report.anomalyAnalysis.detectedAnomalies.count,
            recommendationCount: report.personalizedRecommendations.count
        )
    }
    
    private func calculateDataQualityScore(for user: User) -> Double {
        let healthRecords = user.healthRecords
        guard !healthRecords.isEmpty else { return 0.0 }
        
        // Calculate based on data completeness, consistency, and recency
        let calendar = Calendar.current
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let recentRecords = healthRecords.filter { $0.timestamp >= lastMonth }
        
        let completenessScore = min(1.0, Double(recentRecords.count) / 30.0) // Aim for daily records
        let dataTypesDiversity = min(1.0, Double(Set(healthRecords.map { $0.type }).count) / 5.0) // Aim for 5 different types
        let recencyScore = recentRecords.isEmpty ? 0.0 : 1.0
        
        return (completenessScore + dataTypesDiversity + recencyScore) / 3.0
    }
}

// MARK: - Supporting Types

struct MonthlyReportPreview: Identifiable {
    let id = UUID()
    let keyMetrics: [KeyMetric]
    let insightCount: Int
    let anomalyCount: Int
    let recommendationCount: Int
    
    struct KeyMetric: Identifiable, Equatable {
        let id = UUID()
        let type: HealthDataType
        let displayValue: String
        let trend: TrendDirection
        let changeText: String
        
        static func == (lhs: KeyMetric, rhs: KeyMetric) -> Bool {
            lhs.id == rhs.id
        }
    }
}

// MARK: - Extensions

extension InsightTimeframe {
    var displayName: String {
        switch self {
        case .week: return "週"
        case .month: return "月"
        case .quarter: return "四半期"
        case .year: return "年"
        }
    }
}

extension HealthFocusArea {
    var displayName: String {
        switch self {
        case .physical: return "身体"
        case .mental: return "精神"
        case .behavioral: return "行動"
        case .nutrition: return "栄養"
        case .sleep: return "睡眠"
        case .exercise: return "運動"
        }
    }
}

extension InsightCategory {
    var iconName: String {
        switch self {
        case .trend: return "chart.line.uptrend.xyaxis"
        case .anomaly: return "exclamationmark.triangle"
        case .correlation: return "link"
        case .prediction: return "crystal.ball"
        case .recommendation: return "lightbulb"
        case .achievement: return "trophy"
        case .risk: return "shield.lefthalf.filled"
        case .behavioral: return "person.fill"
        }
    }
}

extension InsightPriority {
    var color: Color {
        switch self {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        case .info: return .gray
        }
    }
    
    var displayName: String {
        switch self {
        case .critical: return "緊急"
        case .high: return "高"
        case .medium: return "中"
        case .low: return "低"
        case .info: return "情報"
        }
    }
}

// Note: InsightAnomalySeverity extensions are now in InsightEngineModels.swift

extension TrendDirection {
    var iconName: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        case .volatile: return "arrow.up.and.down"
        }
    }
    
    var color: Color {
        switch self {
        case .improving: return .green
        case .stable: return .blue
        case .declining: return .red
        case .volatile: return .orange
        }
    }
}

extension ImplementationComplexity {
    var displayName: String {
        switch self {
        case .veryLow: return "とても簡単"
        case .low: return "簡単"
        case .medium: return "中程度"
        case .high: return "難しい"
        case .veryHigh: return "とても難しい"
        }
    }
}

extension RecommendationImpact {
    var displayName: String {
        switch self {
        case .veryHigh: return "とても高い"
        case .high: return "高い"
        case .medium: return "中程度"
        case .low: return "低い"
        case .minimal: return "最小限"
        }
    }
}