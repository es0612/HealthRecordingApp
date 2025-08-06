import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct MainTabView: View {
    // MARK: - ViewModels (Shared across tabs)
    @State private var healthDataViewModel: HealthDataViewModel
    @State private var trendsViewModel: TrendsViewModel  
    @State private var goalsViewModel: GoalsViewModel
    @State private var dashboardViewModel: DashboardViewModel
    @State private var healthKitAuthManager: HealthKitAuthenticationManager
    
    // MARK: - State
    @State private var selectedTab: AppTab = .dashboard
    @State private var showingOnboarding = false
    @State private var hasCompletedOnboarding = false
    
    // MARK: - Initialization
    init(
        healthDataViewModel: HealthDataViewModel,
        trendsViewModel: TrendsViewModel,
        goalsViewModel: GoalsViewModel,
        dashboardViewModel: DashboardViewModel,
        healthKitAuthManager: HealthKitAuthenticationManager
    ) {
        self._healthDataViewModel = State(initialValue: healthDataViewModel)
        self._trendsViewModel = State(initialValue: trendsViewModel)
        self._goalsViewModel = State(initialValue: goalsViewModel)
        self._dashboardViewModel = State(initialValue: dashboardViewModel)
        self._healthKitAuthManager = State(initialValue: healthKitAuthManager)
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard Tab
            NavigationStack {
                DashboardView(
                    dashboardViewModel: dashboardViewModel,
                    healthDataViewModel: healthDataViewModel,
                    trendsViewModel: trendsViewModel,
                    goalsViewModel: goalsViewModel
                )
            }
            .tabItem {
                Label("ダッシュボード", systemImage: "house.fill")
            }
            .tag(AppTab.dashboard)
            
            // Trends Tab
            NavigationStack {
                TrendsView(
                    viewModel: trendsViewModel,
                    healthDataViewModel: healthDataViewModel
                )
            }
            .tabItem {
                Label("トレンド", systemImage: "chart.line.uptrend.xyaxis")
            }
            .tag(AppTab.trends)
            
            // Goals Tab
            NavigationStack {
                GoalsView(
                    viewModel: goalsViewModel,
                    healthDataViewModel: healthDataViewModel
                )
            }
            .tabItem {
                Label("目標", systemImage: "target")
            }
            .tag(AppTab.goals)
            
            // Data Tab
            NavigationStack {
                HealthDataView(viewModel: healthDataViewModel)
            }
            .tabItem {
                Label("データ", systemImage: "heart.text.square")
            }
            .tag(AppTab.data)
            
            // Settings Tab
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("設定", systemImage: "gearshape.fill")
            }
            .tag(AppTab.settings)
        }
        .tint(.accentColor)
        .sheet(isPresented: $showingOnboarding) {
            OnboardingFlow(
                onComplete: {
                    hasCompletedOnboarding = true
                    showingOnboarding = false
                },
                healthKitAuthManager: healthKitAuthManager
            )
        }
        .task {
            await initializeApp()
        }
        .onAppear {
            setupTabBarAppearance()
        }
    }
    
    // MARK: - Private Methods
    
    private func initializeApp() async {
        // Check if onboarding is needed
        if !hasCompletedOnboarding && !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            showingOnboarding = true
        } else {
            // Load initial data
            await loadInitialData()
        }
    }
    
    private func loadInitialData() async {
        await dashboardViewModel.loadDashboardData()
    }
    
    private func setupTabBarAppearance() {
        #if os(iOS)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        
        // Customize selected item appearance
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemBlue
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.systemBlue
        ]
        
        // Apply appearance
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        #endif
    }
}

// MARK: - Supporting Types

enum AppTab: String, CaseIterable {
    case dashboard = "dashboard"
    case trends = "trends"
    case goals = "goals"
    case data = "data"
    case settings = "settings"
    
    var title: String {
        switch self {
        case .dashboard: return "ダッシュボード"
        case .trends: return "トレンド"
        case .goals: return "目標"
        case .data: return "データ"
        case .settings: return "設定"
        }
    }
    
    var iconName: String {
        switch self {
        case .dashboard: return "house.fill"
        case .trends: return "chart.line.uptrend.xyaxis"
        case .goals: return "target"
        case .data: return "heart.text.square"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Placeholder Views

struct TrendsView: View {
    let viewModel: TrendsViewModel
    let healthDataViewModel: HealthDataViewModel
    
    var body: some View {
        VStack {
            Text("トレンド分析")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("近日実装予定")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .navigationTitle("トレンド")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }
}

struct GoalsView: View {
    let viewModel: GoalsViewModel
    let healthDataViewModel: HealthDataViewModel
    
    var body: some View {
        VStack {
            Text("目標管理")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("近日実装予定")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .navigationTitle("目標")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }
}

// HealthDataView is now implemented in Views/Data/HealthDataView.swift

struct SettingsView: View {
    var body: some View {
        List {
            Section("アプリ") {
                NavigationLink(destination: Text("通知設定")) {
                    Label("通知", systemImage: "bell")
                }
                
                NavigationLink(destination: Text("データエクスポート")) {
                    Label("データエクスポート", systemImage: "square.and.arrow.up")
                }
            }
            
            Section("HealthKit") {
                NavigationLink(destination: Text("HealthKit設定")) {
                    Label("HealthKit設定", systemImage: "heart.text.square")
                }
                
                NavigationLink(destination: Text("データ同期")) {
                    Label("データ同期", systemImage: "arrow.triangle.2.circlepath")
                }
            }
            
            Section("プライバシー") {
                NavigationLink(destination: Text("プライバシーポリシー")) {
                    Label("プライバシーポリシー", systemImage: "hand.raised")
                }
                
                NavigationLink(destination: Text("データ削除")) {
                    Label("データ削除", systemImage: "trash")
                        .foregroundColor(.red)
                }
            }
            
            Section("サポート") {
                NavigationLink(destination: Text("ヘルプ")) {
                    Label("ヘルプ", systemImage: "questionmark.circle")
                }
                
                NavigationLink(destination: Text("フィードバック")) {
                    Label("フィードバック", systemImage: "envelope")
                }
            }
            
            Section("アプリについて") {
                HStack {
                    Text("バージョン")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                NavigationLink(destination: Text("ライセンス")) {
                    Label("ライセンス", systemImage: "doc.text")
                }
            }
        }
        .navigationTitle("設定")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }
}

// MARK: - Onboarding Flow

struct OnboardingFlow: View {
    let onComplete: () -> Void
    let healthKitAuthManager: HealthKitAuthenticationManager
    
    @State private var currentStep = 0
    @State private var showingHealthKitPermission = false
    
    private let steps = ["welcome", "features", "healthkit", "complete"]
    
    var body: some View {
        NavigationView {
            VStack {
                // Progress Indicator
                ProgressView(value: Double(currentStep), total: Double(steps.count - 1))
                    .padding()
                
                // Content
                TabView(selection: $currentStep) {
                    WelcomeStep()
                        .tag(0)
                    
                    FeaturesStep()
                        .tag(1)
                    
                    HealthKitStep(
                        onRequestPermission: {
                            showingHealthKitPermission = true
                        }
                    )
                    .tag(2)
                    
                    CompleteStep(onComplete: onComplete)
                        .tag(3)
                }
                #if os(iOS)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                #endif
                
                // Navigation
                HStack {
                    if currentStep > 0 {
                        Button("戻る") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                    }
                    
                    Spacer()
                    
                    if currentStep < steps.count - 1 {
                        Button("次へ") {
                            withAnimation {
                                currentStep += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            #if os(iOS)
            .navigationBarHidden(true)
            #else
            .navigationBarBackButtonHidden(true)
            #endif
        }
        .sheet(isPresented: $showingHealthKitPermission) {
            HealthKitPermissionView(
                authManager: healthKitAuthManager,
                onPermissionGranted: {
                    showingHealthKitPermission = false
                    withAnimation {
                        currentStep = 3
                    }
                },
                onPermissionDenied: {
                    showingHealthKitPermission = false
                    withAnimation {
                        currentStep = 3
                    }
                }
            )
        }
    }
}

// MARK: - Onboarding Steps

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            VStack(spacing: 16) {
                Text("ヘルスレコーディングアプリへようこそ")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("あなたの健康データを記録し、長期的なトレンドを分析して、より良い健康習慣をサポートします。")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

struct FeaturesStep: View {
    var body: some View {
        VStack(spacing: 32) {
            Text("主な機能")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 24) {
                FeatureCard(
                    icon: "arrow.triangle.2.circlepath",
                    title: "自動データ同期",
                    description: "HealthKitと連携して、手動入力の手間なく健康データを記録"
                )
                
                FeatureCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "トレンド分析",
                    description: "長期間のデータから意味のあるインサイトと改善提案を生成"
                )
                
                FeatureCard(
                    icon: "target",
                    title: "目標管理",
                    description: "あなたに最適化された現実的な健康目標を設定・追跡"
                )
            }
        }
        .padding()
    }
}

struct HealthKitStep: View {
    let onRequestPermission: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            VStack(spacing: 16) {
                Text("HealthKitとの連携")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Apple ヘルスケアからデータを読み取り、より正確で包括的な健康管理を実現します。")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("HealthKitアクセスを設定") {
                onRequestPermission()
            }
            .buttonStyle(.borderedProminent)
            .font(.headline)
        }
        .padding()
    }
}

struct CompleteStep: View {
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            VStack(spacing: 16) {
                Text("セットアップ完了！")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("健康データの記録と分析を開始する準備が整いました。")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("開始する") {
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .font(.headline)
        }
        .padding()
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.accentColor)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

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
    
    let mockAuthManager = HealthKitAuthenticationManager.preview()
    
    MainTabView(
        healthDataViewModel: mockHealthDataVM,
        trendsViewModel: mockTrendsVM,
        goalsViewModel: mockGoalsVM,
        dashboardViewModel: mockDashboardVM,
        healthKitAuthManager: mockAuthManager
    )
}

// Mock implementations for preview (reuse from DashboardView)
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