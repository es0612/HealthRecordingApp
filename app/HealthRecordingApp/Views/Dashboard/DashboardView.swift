import SwiftUI
import SwiftData

struct DashboardView: View {
    // MARK: - ViewModels
    let dashboardViewModel: DashboardViewModel
    let healthDataViewModel: HealthDataViewModel
    let trendsViewModel: TrendsViewModel
    let goalsViewModel: GoalsViewModel
    
    // MARK: - State
    @State private var showingHealthKitPermissions = false
    @State private var selectedTab: DashboardTab = .overview
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Tab Selection
                tabSelectionView
                
                // Content
                contentView
                
                Spacer()
            }
            .navigationTitle("ヘルスダッシュボード")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    syncButton
                }
            }
            .sheet(isPresented: $showingHealthKitPermissions) {
                HealthKitPermissionView()
            }
            .refreshable {
                await refreshData()
            }
        }
    }
    
    // MARK: - Views
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Health Summary
            if let summary = dashboardViewModel.healthSummary {
                HealthSummaryCard(summary: summary)
            }
            
            // Today's Stats
            if let todayStats = dashboardViewModel.todayStats {
                TodayStatsRow(stats: todayStats)
            }
            
            // Urgent Notifications
            if !dashboardViewModel.urgentNotifications.isEmpty {
                NotificationBanner(notifications: dashboardViewModel.urgentNotifications)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }
    
    private var tabSelectionView: some View {
        HStack(spacing: 0) {
            ForEach(DashboardTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 20, weight: .medium))
                        
                        Text(tab.title)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                switch selectedTab {
                case .overview:
                    overviewContent
                case .trends:
                    trendsContent
                case .goals:
                    goalsContent
                case .achievements:
                    achievementsContent
                }
            }
            .padding()
        }
    }
    
    private var overviewContent: some View {
        VStack(spacing: 16) {
            // Recent Health Data
            HealthDataSummaryCard(
                viewModel: healthDataViewModel,
                isLoading: healthDataViewModel.isLoading
            )
            
            // Quick Actions
            QuickActionsGrid(
                actions: dashboardViewModel.quickActions,
                onActionTap: { action in
                    handleQuickAction(action)
                }
            )
            
            // Recent Achievements
            if !dashboardViewModel.recentAchievements.isEmpty {
                RecentAchievementsCard(
                    achievements: dashboardViewModel.recentAchievements
                )
            }
        }
    }
    
    private var trendsContent: some View {
        VStack(spacing: 16) {
            // Trend Analysis
            if trendsViewModel.hasData {
                TrendAnalysisCard(
                    trendData: trendsViewModel.chartDataPoints,
                    insights: trendsViewModel.healthInsights,
                    isLoading: trendsViewModel.isLoading
                )
            } else {
                EmptyTrendsCard()
            }
            
            // Data Type Selector
            DataTypeSelector(
                selectedType: healthDataViewModel.selectedDataType,
                onSelectionChange: { type in
                    healthDataViewModel.updateDataType(type)
                }
            )
        }
    }
    
    private var goalsContent: some View {
        VStack(spacing: 16) {
            // Active Goals
            if !goalsViewModel.activeGoals.isEmpty {
                ActiveGoalsCard(
                    goals: goalsViewModel.activeGoals,
                    progressDetails: goalsViewModel.goalProgressDetails
                )
            }
            
            // Goal Suggestions
            if !goalsViewModel.goalSuggestions.isEmpty {
                GoalSuggestionsCard(
                    suggestions: goalsViewModel.goalSuggestions.filter { $0.isRecommended }
                )
            }
            
            // Goal Creation Button
            CreateGoalButton {
                // Handle goal creation
            }
        }
    }
    
    private var achievementsContent: some View {
        VStack(spacing: 16) {
            // Recent Achievements
            RecentAchievementsCard(
                achievements: dashboardViewModel.recentAchievements
            )
            
            // Badge Progress
            BadgeProgressCard()
        }
    }
    
    private var syncButton: some View {
        Button(action: {
            Task {
                await syncWithHealthKit()
            }
        }) {
            Image(systemName: healthDataViewModel.isSyncing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                .foregroundColor(.accentColor)
                .rotationEffect(.degrees(healthDataViewModel.isSyncing ? 360 : 0))
                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: healthDataViewModel.isSyncing)
        }
        .disabled(healthDataViewModel.isSyncing)
    }
    
    // MARK: - Actions
    
    private func refreshData() async {
        await dashboardViewModel.loadDashboardData()
    }
    
    private func syncWithHealthKit() async {
        await healthDataViewModel.syncWithHealthKit()
    }
    
    private func handleQuickAction(_ action: QuickAction) {
        switch action.type {
        case .recordData:
            dashboardViewModel.requestManualDataEntry()
        case .viewTrends:
            selectedTab = .trends
        case .manageGoals:
            selectedTab = .goals
        case .shareProgress:
            // Handle share progress
            break
        }
    }
}

// MARK: - Supporting Types

enum DashboardTab: String, CaseIterable {
    case overview = "概要"
    case trends = "トレンド"
    case goals = "目標"
    case achievements = "実績"
    
    var title: String {
        return self.rawValue
    }
    
    var iconName: String {
        switch self {
        case .overview: return "house.fill"
        case .trends: return "chart.line.uptrend.xyaxis"
        case .goals: return "target"
        case .achievements: return "rosette"
        }
    }
}

// MARK: - Supporting Cards

struct HealthSummaryCard: View {
    let summary: HealthSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("健康スコア")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(Int(summary.overallScore * 100))点")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor)
                }
                
                Spacer()
                
                CircularProgressView(
                    value: summary.overallScore,
                    color: scoreColor
                )
                .frame(width: 60, height: 60)
            }
            
            if let insight = summary.primaryInsight {
                Text(insight)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    private var scoreColor: Color {
        switch summary.overallScore {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
}

struct TodayStatsRow: View {
    let stats: DailyStats
    
    var body: some View {
        HStack(spacing: 16) {
            StatItem(
                title: "歩数",
                value: "\(Int(stats.steps))",
                unit: "歩",
                icon: "figure.walk",
                color: .blue
            )
            
            StatItem(
                title: "カロリー",
                value: "\(Int(stats.calories))",
                unit: "kcal",
                icon: "flame.fill",
                color: .orange
            )
            
            if let weight = stats.weight {
                StatItem(
                    title: "体重",
                    value: String(format: "%.1f", weight),
                    unit: "kg",
                    icon: "scalemass.fill",
                    color: .purple
                )
            }
        }
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CircularProgressView: View {
    let value: Double
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 6)
            
            Circle()
                .trim(from: 0, to: value)
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: value)
        }
    }
}

// Placeholder views for missing components
struct NotificationBanner: View {
    let notifications: [DashboardNotification]
    
    var body: some View {
        Text("通知バナー: \(notifications.count)件")
            .padding()
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct HealthDataSummaryCard: View {
    let viewModel: HealthDataViewModel
    let isLoading: Bool
    
    var body: some View {
        VStack {
            Text("健康データサマリー")
                .font(.headline)
            Text("記録数: \(viewModel.filteredRecords.count)")
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct QuickActionsGrid: View {
    let actions: [QuickAction]
    let onActionTap: (QuickAction) -> Void
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
            ForEach(actions, id: \.id) { action in
                Button(action: { onActionTap(action) }) {
                    VStack(spacing: 8) {
                        Image(systemName: action.iconName)
                            .font(.title2)
                        Text(action.title)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct RecentAchievementsCard: View {
    let achievements: [Achievement]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("最近の実績")
                .font(.headline)
            
            ForEach(achievements.prefix(3), id: \.id) { achievement in
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text(achievement.title)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct TrendAnalysisCard: View {
    let trendData: [ChartDataPoint]
    let insights: [HealthInsight]
    let isLoading: Bool
    
    var body: some View {
        VStack {
            Text("トレンド分析")
                .font(.headline)
            Text("データポイント: \(trendData.count)")
            Text("インサイト: \(insights.count)")
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct EmptyTrendsCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("データが不足しています")
                .font(.headline)
            
            Text("トレンド分析には少なくとも1週間分のデータが必要です")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct DataTypeSelector: View {
    let selectedType: HealthDataType
    let onSelectionChange: (HealthDataType) -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("データタイプ")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(HealthDataType.allCases, id: \.self) { type in
                        Button(action: { onSelectionChange(type) }) {
                            Text(type.displayName)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedType == type ? Color.accentColor : Color(.systemGray5))
                                .foregroundColor(selectedType == type ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct ActiveGoalsCard: View {
    let goals: [Goal]
    let progressDetails: [UUID: GoalProgressDetail]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("アクティブな目標")
                .font(.headline)
            
            ForEach(Array(goals.prefix(3)), id: \.id) { goal in
                VStack(alignment: .leading) {
                    Text(goal.type.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if let progress = progressDetails[goal.id] {
                        ProgressView(value: progress.completionPercentage / 100.0)
                            .tint(.accentColor)
                        
                        Text("\(Int(progress.completionPercentage))% 達成")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct GoalSuggestionsCard: View {
    let suggestions: [GoalSuggestion]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("おすすめの目標")
                .font(.headline)
            
            ForEach(Array(suggestions.prefix(2)), id: \.type) { suggestion in
                VStack(alignment: .leading) {
                    Text(suggestion.displayTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(suggestion.reasoning)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CreateGoalButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("新しい目標を作成")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct BadgeProgressCard: View {
    var body: some View {
        VStack {
            Text("バッジ進捗")
                .font(.headline)
            Text("近日実装予定")
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// HealthKitPermissionView is now defined in Views/Onboarding/HealthKitPermissionView.swift

/*
#Preview {
    // Create mock dependencies for preview
    let mockHealthDataVM = HealthDataViewModel(
        recordHealthDataUseCase: MockRecordHealthDataUseCase(),
        fetchHealthDataUseCase: MockFetchHealthDataUseCase()
    )
    
    let mockTrendsVM = TrendsViewModel(
        fetchHealthDataUseCase: MockFetchHealthDataUseCase(),
        trendAnalyzer: MockTrendAnalyzer()
    )
    
    let mockGoalsVM = GoalsViewModel(
        manageGoalsUseCase: MockManageGoalsUseCase(),
        fetchHealthDataUseCase: MockFetchHealthDataUseCase(),
        goalTracker: MockGoalTracker()
    )
    
    let mockDashboardVM = DashboardViewModel(
        healthDataViewModel: mockHealthDataVM,
        trendsViewModel: mockTrendsVM,
        goalsViewModel: mockGoalsVM
    )
    
    DashboardView(
        dashboardViewModel: mockDashboardVM,
        healthDataViewModel: mockHealthDataVM,
        trendsViewModel: mockTrendsVM,
        goalsViewModel: mockGoalsVM
    )
}

// Mock implementations for preview
private struct MockFetchHealthDataUseCase: FetchHealthDataUseCaseProtocol {
    func fetchHealthRecords(for user: User, type: HealthDataType?, dateRange: DateRange?, limit: Int?) async throws -> [HealthRecord] { [] }
    
    func fetchLatestRecord(for user: User, type: HealthDataType) async throws -> HealthRecord? { nil }
    
    func fetchRecordsGroupedByDay(for user: User, type: HealthDataType, dateRange: DateRange) async throws -> [Date: [HealthRecord]] { [:] }
    
    func getHealthDataStatistics(for user: User, type: HealthDataType, dateRange: DateRange) async throws -> HealthDataStatistics {
        HealthDataStatistics(dataType: type, dateRange: dateRange, records: [])
    }
    
    func searchHealthRecords(for user: User, criteria: HealthDataSearchCriteria) async throws -> [HealthRecord] { [] }
    
    func exportHealthData(for user: User, format: ExportFormat, dateRange: DateRange?) async throws -> ExportResult {
        ExportResult(format: .json, data: Data(), filename: "test.json", recordCount: 0, userID: user.id)
    }
}

private struct MockRecordHealthDataUseCase: RecordHealthDataUseCaseProtocol {
    func recordFromHealthKit(for user: User) async throws -> [HealthRecord] { [] }
    
    func recordManualData(_ data: ManualHealthData, for user: User) async throws -> HealthRecord {
        return HealthRecord(type: .weight, value: 70.0, unit: "kg", source: .manual)
    }
    
    func syncAllData(for user: User) async throws -> HealthSyncResult {
        return HealthSyncResult(
            syncedRecordsCount: 0,
            failedRecordsCount: 0,
            lastSyncDate: Date(),
            syncStatus: .completed,
            errors: []
        )
    }
    
    func processBadgeEarning(for user: User) async throws -> [Badge] { [] }
}

private struct MockTrendAnalyzer: TrendAnalyzerProtocol {
    func analyzeTrends(from records: [any HealthRecordProtocol], timeRange: TimeRange) async throws -> TrendAnalysis {
        TrendAnalysis(
            dataType: .weight,
            timeRange: .week,
            trendPoints: [],
            direction: .stable,
            slope: 0.0,
            correlation: 0.0,
            anomalies: [],
            summary: TrendSummary(
                totalDataPoints: 0,
                averageValue: 0.0,
                minimumValue: 0.0,
                maximumValue: 0.0,
                standardDeviation: 0.0,
                changePercentage: 0.0,
                lastValue: 0.0,
                firstValue: 0.0
            ),
            confidence: 0.0
        )
    }
    
    func analyzeTrends(from records: [any HealthRecordProtocol], dateRange: DateRange) async throws -> TrendAnalysis {
        TrendAnalysis(
            dataType: .weight,
            timeRange: .week,
            trendPoints: [],
            direction: .stable,
            slope: 0.0,
            correlation: 0.0,
            anomalies: [],
            summary: TrendSummary(
                totalDataPoints: 0,
                averageValue: 0.0,
                minimumValue: 0.0,
                maximumValue: 0.0,
                standardDeviation: 0.0,
                changePercentage: 0.0,
                lastValue: 0.0,
                firstValue: 0.0
            ),
            confidence: 0.0
        )
    }
    
    func calculateMovingAverage(values: [Double], windowSize: Int) -> [Double] { [] }
    func calculateWeightedMovingAverage(values: [Double], weights: [Double]) -> [Double] { [] }
    func calculateExponentialMovingAverage(values: [Double], alpha: Double) -> [Double] { [] }
    func detectAnomalies(in records: [any HealthRecordProtocol], sensitivity: Double) async throws -> [AnomalyPoint] { [] }
    func detectOutliers(values: [Double], method: OutlierDetectionMethod) -> [Int] { [] }
    func predictTrend(from analysis: TrendAnalysis, daysAhead: Int) async throws -> TrendPrediction {
        TrendPrediction(dataType: .weight, predictedPoints: [], confidence: 0.0, methodology: "mock", validUntil: Date())
    }
    func predictValue(from records: [any HealthRecordProtocol], daysAhead: Int, method: PredictionMethod) async throws -> Double { 0.0 }
    func calculateCorrelation(between firstSeries: [Double], and secondSeries: [Double]) -> Double { 0.0 }
    func calculateLinearRegression(from points: [(x: Double, y: Double)]) -> LinearRegressionResult {
        LinearRegressionResult(slope: 0.0, intercept: 0.0, rSquared: 0.0, standardError: 0.0)
    }
    func calculateVariability(from values: [Double]) -> VariabilityMetrics {
        VariabilityMetrics(standardDeviation: 0.0, variance: 0.0, coefficientOfVariation: 0.0, range: 0.0)
    }
}

private struct MockManageGoalsUseCase: ManageGoalsUseCaseProtocol {
    func createGoal(for user: User, goalData: GoalCreationData) async throws -> Goal { 
        try Goal(type: .weight, targetValue: 70.0, deadline: Date())
    }
    func updateGoal(_ goal: Goal, updates: GoalUpdateData) async throws -> Goal { goal }
    func deleteGoal(_ goal: Goal, for user: User) async throws {}
    func fetchAllGoals(for user: User) async throws -> [Goal] { [] }
    func fetchActiveGoals(for user: User) async throws -> [Goal] { [] }
    func fetchCompletedGoals(for user: User) async throws -> [Goal] { [] }
    func suggestGoals(for user: User) async throws -> [GoalSuggestion] { [] }
}

private struct MockGoalTracker: GoalTrackerProtocol {
    func updateGoalProgress(for goal: Goal, with records: [any HealthRecordProtocol]) async throws -> GoalProgressDetail {
        GoalProgressDetail(
            goalId: goal.id,
            goalType: goal.type,
            targetValue: goal.targetValue,
            currentValue: 0.0,
            progress: 0.0,
            progressPercentage: 0.0,
            remainingValue: goal.targetValue,
            remainingDays: 30,
            dailyRequiredProgress: 0.0,
            isOnTrack: true,
            achievabilityScore: 0.8,
            motivationLevel: .medium,
            milestones: [],
            recommendations: []
        )
    }
    func calculateGoalProgress(for goal: Goal, with records: [any HealthRecordProtocol]) -> GoalProgressDetail {
        GoalProgressDetail(
            goalId: goal.id,
            goalType: goal.type,
            targetValue: goal.targetValue,
            currentValue: 0.0,
            progress: 0.0,
            progressPercentage: 0.0,
            remainingValue: goal.targetValue,
            remainingDays: 30,
            dailyRequiredProgress: 0.0,
            isOnTrack: true,
            achievabilityScore: 0.8,
            motivationLevel: .medium,
            milestones: [],
            recommendations: []
        )
    }
}
*/