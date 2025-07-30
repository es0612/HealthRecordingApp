import SwiftUI
import SwiftData
import Foundation

@Observable
final class DashboardViewModel {
    // MARK: - Published Properties
    var isLoading = false
    var errorMessage: String?
    var lastUpdated: Date?
    var healthSummary: HealthSummary?
    var todayStats: DailyStats?
    var recentAchievements: [Achievement] = []
    var urgentNotifications: [DashboardNotification] = []
    var quickActions: [QuickAction] = []
    
    // MARK: - Computed Properties
    var hasData: Bool {
        healthSummary != nil || todayStats != nil
    }
    
    var needsAttention: Bool {
        !urgentNotifications.isEmpty
    }
    
    var overallHealthScore: Double {
        healthSummary?.overallScore ?? 0.0
    }
    
    var todayProgress: Double {
        todayStats?.completionRate ?? 0.0
    }
    
    var streakCount: Int {
        healthSummary?.currentStreak ?? 0
    }
    
    var formattedLastUpdated: String {
        guard let lastUpdated = lastUpdated else {
            return "未更新"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: lastUpdated)
    }
    
    // MARK: - Child ViewModels
    private let healthDataViewModel: HealthDataViewModel
    private let trendsViewModel: TrendsViewModel
    private let goalsViewModel: GoalsViewModel
    
    // MARK: - Dependencies
    private let logger: AILoggerProtocol
    
    // MARK: - Initialization
    init(
        healthDataViewModel: HealthDataViewModel,
        trendsViewModel: TrendsViewModel,
        goalsViewModel: GoalsViewModel,
        logger: AILoggerProtocol = AILogger()
    ) {
        self.healthDataViewModel = healthDataViewModel
        self.trendsViewModel = trendsViewModel
        self.goalsViewModel = goalsViewModel
        self.logger = logger
        
        logger.debug("DashboardViewModel initialized", context: nil)
        setupQuickActions()
    }
    
    // MARK: - Data Loading
    @MainActor
    func loadDashboardData() async {
        logger.debug("Starting dashboard data load", context: nil)
        guard !isLoading else {
            logger.warning("Load already in progress, skipping", context: nil)
            return
        }
        
        isLoading = true
        errorMessage = nil
        defer { 
            isLoading = false
            lastUpdated = Date()
        }
        
        do {
            let startTime = Date()
            logger.info("Loading dashboard data", context: nil)
            
            // Load data from child ViewModels concurrently
            async let healthDataLoad = healthDataViewModel.loadHealthData()
            async let trendsDataLoad = trendsViewModel.loadTrendData()
            async let goalsLoad = goalsViewModel.loadGoals()
            
            // Wait for all loads to complete
            _ = try await (healthDataLoad, trendsDataLoad, goalsLoad)
            
            // Generate dashboard summaries
            await generateHealthSummary()
            await generateTodayStats()
            await loadRecentAchievements()
            await generateNotifications()
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("load_dashboard_data", duration: duration, success: true)
            logger.info("Successfully loaded dashboard data", context: [
                "healthScore": overallHealthScore,
                "todayProgress": todayProgress,
                "streakCount": streakCount,
                "achievementCount": recentAchievements.count,
                "notificationCount": urgentNotifications.count
            ])
            
        } catch {
            let duration = Date().timeIntervalSince(Date())
            logger.logPerformance("load_dashboard_data", duration: duration, success: false)
            logger.error(error, context: ["operation": "load_dashboard_data"])
            errorMessage = handleError(error)
        }
    }
    
    @MainActor
    func refreshDashboard() async {
        logger.logUserAction("refresh_dashboard", parameters: [
            "currentHealthScore": overallHealthScore,
            "streakCount": streakCount
        ])
        
        await loadDashboardData()
    }
    
    // MARK: - Quick Actions
    @MainActor
    func executeQuickAction(_ action: QuickAction) async {
        logger.logUserAction("execute_quick_action", parameters: [
            "actionType": action.type.rawValue
        ])
        
        switch action.type {
        case .syncHealthKit:
            await healthDataViewModel.syncWithHealthKit()
        case .updateGoalProgress:
            await goalsViewModel.updateGoalProgress()
        case .viewTrends:
            await trendsViewModel.refreshTrendData()
        case .recordManualData:
            // This would trigger manual data entry UI
            logger.info("Manual data entry requested", context: nil)
        }
        
        // Refresh dashboard after action
        await generateHealthSummary()
        await generateTodayStats()
        await generateNotifications()
    }
    
    // MARK: - Notifications
    @MainActor
    func dismissNotification(_ notification: DashboardNotification) {
        logger.logUserAction("dismiss_notification", parameters: [
            "notificationType": notification.type.rawValue
        ])
        
        urgentNotifications.removeAll { $0.id == notification.id }
    }
    
    @MainActor
    func dismissAllNotifications() {
        logger.logUserAction("dismiss_all_notifications", parameters: [
            "notificationCount": urgentNotifications.count
        ])
        
        urgentNotifications.removeAll()
    }
    
    // MARK: - Data Generation
    private func generateHealthSummary() async {
        logger.debug("Generating health summary", context: nil)
        
        let currentScore = calculateOverallHealthScore()
        let streak = calculateCurrentStreak()
        let weeklyAverage = calculateWeeklyAverage()
        let improvement = calculateImprovementRate()
        
        await MainActor.run {
            healthSummary = HealthSummary(
                overallScore: currentScore,
                currentStreak: streak,
                weeklyAverage: weeklyAverage,
                improvementRate: improvement,
                lastCalculated: Date()
            )
        }
        
        logger.debug("Health summary generated", context: [
            "score": currentScore,
            "streak": streak,
            "weeklyAverage": weeklyAverage
        ])
    }
    
    private func generateTodayStats() async {
        logger.debug("Generating today stats", context: nil)
        
        let today = Calendar.current.startOfDay(for: Date())
        let todayRecords = healthDataViewModel.healthRecords.filter {
            Calendar.current.isDate($0.timestamp, inSameDayAs: today)
        }
        
        let goalProgress = calculateTodayGoalProgress()
        let dataPoints = todayRecords.count
        let completionRate = goalProgress
        
        await MainActor.run {
            todayStats = DailyStats(
                date: today,
                dataPointsRecorded: dataPoints,
                goalsProgress: goalProgress,
                completionRate: completionRate,
                recordsByType: groupRecordsByType(todayRecords)
            )
        }
        
        logger.debug("Today stats generated", context: [
            "dataPoints": dataPoints,
            "goalProgress": goalProgress,
            "completionRate": completionRate
        ])
    }
    
    private func loadRecentAchievements() async {
        logger.debug("Loading recent achievements", context: nil)
        
        // Get recent achievements from goals and health data
        let goalAchievements = goalsViewModel.completedGoals
            .compactMap { goal in
                // For now, treat recently completed goals as achievements
                // In a real implementation, we'd track completion date
                if goal.isCompleted {
                    return Achievement(
                        id: UUID(),
                        type: .goalCompleted,
                        title: "目標達成",
                        description: "\(goal.type.displayName)の目標を達成しました",
                        date: Date(), // Use current date as placeholder
                        value: goal.targetValue,
                        unit: goal.type.unit
                    )
                }
                return nil
            }
        
        let streakAchievements = generateStreakAchievements()
        
        await MainActor.run {
            recentAchievements = (goalAchievements + streakAchievements)
                .sorted { $0.date > $1.date }
                .prefix(5)
                .map { $0 }
        }
        
        logger.debug("Recent achievements loaded", context: [
            "achievementCount": recentAchievements.count
        ])
    }
    
    private func generateNotifications() async {
        logger.debug("Generating notifications", context: nil)
        
        var notifications: [DashboardNotification] = []
        
        // Check for goals needing attention
        for goal in goalsViewModel.goalsNeedingAttention {
            notifications.append(DashboardNotification(
                id: UUID(),
                type: .goalNeedsAttention,
                title: "目標に注意が必要",
                message: "\(goal.type.displayName)の目標の進捗が遅れています",
                priority: .high,
                actionRequired: true,
                relatedId: goal.id
            ))
        }
        
        // Check for missing data
        if healthDataViewModel.healthRecords.isEmpty {
            notifications.append(DashboardNotification(
                id: UUID(),
                type: .noDataRecorded,
                title: "データが記録されていません",
                message: "健康データの記録を開始しましょう",
                priority: .medium,
                actionRequired: true
            ))
        }
        
        // Check for sync issues
        if let lastSync = healthDataViewModel.lastSyncDate,
           Date().timeIntervalSince(lastSync) > 24 * 60 * 60 {
            notifications.append(DashboardNotification(
                id: UUID(),
                type: .syncNeeded,
                title: "同期が必要",
                message: "HealthKitとの同期が24時間以上行われていません",
                priority: .medium,
                actionRequired: true
            ))
        }
        
        await MainActor.run {
            urgentNotifications = notifications.sorted { $0.priority.rawValue > $1.priority.rawValue }
        }
        
        logger.debug("Notifications generated", context: [
            "notificationCount": notifications.count
        ])
    }
    
    // MARK: - Calculations
    private func calculateOverallHealthScore() -> Double {
        // Combine multiple factors into a health score (0.0 - 1.0)
        var score = 0.0
        var factors = 0
        
        // Goal progress factor
        if goalsViewModel.hasActiveGoals {
            score += goalsViewModel.overallProgress
            factors += 1
        }
        
        // Data consistency factor
        let recentDataCount = healthDataViewModel.healthRecords.filter {
            Date().timeIntervalSince($0.timestamp) < 7 * 24 * 60 * 60
        }.count
        
        if recentDataCount > 0 {
            score += min(1.0, Double(recentDataCount) / 7.0) // Ideal: 1 record per day
            factors += 1
        }
        
        // Trend factor
        if let trend = trendsViewModel.latestTrend {
            switch trend {
            case .increasing:
                score += trendsViewModel.selectedDataType == .weight ? 0.3 : 0.8
            case .decreasing:
                score += trendsViewModel.selectedDataType == .weight ? 0.8 : 0.3
            case .stable:
                score += 0.6
            case .volatile:
                score += 0.4 // Volatile trends get lower score
            }
            factors += 1
        }
        
        return factors > 0 ? score / Double(factors) : 0.0
    }
    
    private func calculateCurrentStreak() -> Int {
        let sortedRecords = healthDataViewModel.healthRecords
            .sorted { $0.timestamp > $1.timestamp }
        
        guard !sortedRecords.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        for record in sortedRecords {
            let recordDate = calendar.startOfDay(for: record.timestamp)
            
            if calendar.isDate(recordDate, inSameDayAs: currentDate) {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else if recordDate < currentDate {
                break
            }
        }
        
        return streak
    }
    
    private func calculateWeeklyAverage() -> Double {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentRecords = healthDataViewModel.healthRecords.filter {
            $0.timestamp >= oneWeekAgo
        }
        
        guard !recentRecords.isEmpty else { return 0.0 }
        
        let totalValue = recentRecords.reduce(0.0) { $0 + $1.value }
        return totalValue / Double(recentRecords.count)
    }
    
    private func calculateImprovementRate() -> Double {
        // Calculate improvement over the last month
        let now = Date()
        let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now
        let twoMonthsAgo = Calendar.current.date(byAdding: .month, value: -2, to: now) ?? now
        
        let recentRecords = healthDataViewModel.healthRecords.filter {
            $0.timestamp >= oneMonthAgo
        }
        
        let olderRecords = healthDataViewModel.healthRecords.filter {
            $0.timestamp >= twoMonthsAgo && $0.timestamp < oneMonthAgo
        }
        
        guard !recentRecords.isEmpty && !olderRecords.isEmpty else { return 0.0 }
        
        let recentAverage = recentRecords.reduce(0.0) { $0 + $1.value } / Double(recentRecords.count)
        let olderAverage = olderRecords.reduce(0.0) { $0 + $1.value } / Double(olderRecords.count)
        
        return ((recentAverage - olderAverage) / olderAverage) * 100
    }
    
    private func calculateTodayGoalProgress() -> Double {
        guard goalsViewModel.hasActiveGoals else { return 0.0 }
        
        let today = Calendar.current.startOfDay(for: Date())
        let todayRecords = healthDataViewModel.healthRecords.filter {
            Calendar.current.isDate($0.timestamp, inSameDayAs: today)
        }
        
        // Simple implementation - could be more sophisticated
        return todayRecords.isEmpty ? 0.0 : min(1.0, Double(todayRecords.count) / 3.0)
    }
    
    private func groupRecordsByType(_ records: [HealthRecord]) -> [HealthDataType: Int] {
        var grouped: [HealthDataType: Int] = [:]
        
        for record in records {
            grouped[record.type, default: 0] += 1
        }
        
        return grouped
    }
    
    private func generateStreakAchievements() -> [Achievement] {
        let currentStreak = calculateCurrentStreak()
        var achievements: [Achievement] = []
        
        // Generate achievements for streak milestones
        let milestones = [7, 14, 30, 60, 100]
        
        for milestone in milestones {
            if currentStreak >= milestone {
                achievements.append(Achievement(
                    id: UUID(),
                    type: .streakMilestone,
                    title: "\(milestone)日連続記録",
                    description: "\(milestone)日間連続で健康データを記録しました",
                    date: Date(),
                    value: Double(milestone),
                    unit: "日"
                ))
            }
        }
        
        return achievements
    }
    
    private func setupQuickActions() {
        quickActions = [
            QuickAction(
                id: UUID(),
                type: .syncHealthKit,
                title: "HealthKit同期",
                icon: "heart.fill",
                color: .red
            ),
            QuickAction(
                id: UUID(),
                type: .updateGoalProgress,
                title: "目標進捗更新",
                icon: "target",
                color: .blue
            ),
            QuickAction(
                id: UUID(),
                type: .viewTrends,
                title: "トレンド表示",
                icon: "chart.line.uptrend.xyaxis",
                color: .green
            ),
            QuickAction(
                id: UUID(),
                type: .recordManualData,
                title: "手動データ入力",
                icon: "plus.circle.fill",
                color: .orange
            )
        ]
    }
    
    // MARK: - Error Handling
    @MainActor
    func clearError() {
        errorMessage = nil
        logger.debug("Dashboard error message cleared by user", context: nil)
    }
    
    private func handleError(_ error: Error) -> String {
        if let healthAppError = error as? HealthAppError {
            return healthAppError.localizedDescription
        }
        return "ダッシュボードの読み込み中にエラーが発生しました: \(error.localizedDescription)"
    }
}

// MARK: - Supporting Types
struct HealthSummary {
    let overallScore: Double
    let currentStreak: Int
    let weeklyAverage: Double
    let improvementRate: Double
    let lastCalculated: Date
    
    var scoreGrade: String {
        switch overallScore {
        case 0.9...1.0: return "A"
        case 0.8..<0.9: return "B"
        case 0.7..<0.8: return "C"
        case 0.6..<0.7: return "D"
        default: return "F"
        }
    }
    
    var scoreColor: Color {
        switch overallScore {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
}

struct DailyStats {
    let date: Date
    let dataPointsRecorded: Int
    let goalsProgress: Double
    let completionRate: Double
    let recordsByType: [HealthDataType: Int]
    
    var isComplete: Bool {
        completionRate >= 1.0
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct Achievement {
    let id: UUID
    let type: AchievementType
    let title: String
    let description: String
    let date: Date
    let value: Double
    let unit: String
    
    var displayValue: String {
        if unit == "日" {
            return "\(Int(value))\(unit)"
        } else {
            return String(format: "%.1f%@", value, unit)
        }
    }
}

enum AchievementType {
    case goalCompleted
    case streakMilestone
    case personalBest
    case consistency
}

struct DashboardNotification {
    let id: UUID
    let type: NotificationType
    let title: String
    let message: String
    let priority: NotificationPriority
    let actionRequired: Bool
    let relatedId: UUID?
    
    init(id: UUID, type: NotificationType, title: String, message: String, priority: NotificationPriority, actionRequired: Bool, relatedId: UUID? = nil) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.priority = priority
        self.actionRequired = actionRequired
        self.relatedId = relatedId
    }
}

enum NotificationType: String {
    case goalNeedsAttention = "goal_needs_attention"
    case noDataRecorded = "no_data_recorded"
    case syncNeeded = "sync_needed"
    case achievementUnlocked = "achievement_unlocked"
    case reminder = "reminder"
}

enum NotificationPriority: Int {
    case low = 1
    case medium = 2
    case high = 3
}

struct QuickAction {
    let id: UUID
    let type: QuickActionType
    let title: String
    let icon: String
    let color: Color
}

enum QuickActionType: String {
    case syncHealthKit = "sync_healthkit"
    case updateGoalProgress = "update_goal_progress"
    case viewTrends = "view_trends"
    case recordManualData = "record_manual_data"
}