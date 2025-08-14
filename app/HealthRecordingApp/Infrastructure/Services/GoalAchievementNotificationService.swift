import Foundation
import SwiftData

/// 目標達成通知統合サービス
/// GoalTrackerと通知システムを統合し、目標完了・マイルストーン・ストリーク通知を管理
@MainActor
public final class GoalAchievementNotificationService {
    
    // MARK: - Dependencies
    
    private let goalTracker: GoalTracker
    private let notificationManager: NotificationManager
    private let logger: AILoggerProtocol
    
    // MARK: - State Management
    
    /// 処理済みマイルストーン（重複通知防止）
    private var processedMilestones: Set<String> = []
    
    /// 送信済みストリーク通知（重複防止）
    private var sentStreakNotifications: Set<String> = []
    
    /// 最後の目標チェック時刻
    private var lastGoalCheckTime: Date?
    
    // MARK: - Initialization
    
    public init(
        goalTracker: GoalTracker,
        notificationManager: NotificationManager,
        logger: AILoggerProtocol
    ) {
        self.goalTracker = goalTracker
        self.notificationManager = notificationManager
        self.logger = logger
    }
    
    // MARK: - Goal Achievement Processing
    
    /// 目標達成状況をチェックし、該当する通知を送信
    public func processGoalAchievements(
        goals: [Goal],
        recentRecords: [HealthRecord]
    ) async throws {
        logger.info("目標達成処理開始", context: [
            "goalCount": goals.count,
            "recordCount": recentRecords.count
        ])
        
        let startTime = Date()
        var achievedGoals: [Goal] = []
        var completedMilestones: [GoalMilestone] = []
        var detectedStreaks: [StreakAchievement] = []
        
        for goal in goals where goal.isActive {
            do {
                // 目標進捗を分析
                let progressAnalysis = try await goalTracker.analyzeGoalProgress(
                    for: goal,
                    using: recentRecords
                )
                
                // 目標完了チェック
                if goal.isCompleted && progressAnalysis.progress >= 1.0 {
                    achievedGoals.append(goal)
                    logger.info("目標完了検知", context: [
                        "goalId": goal.id.uuidString,
                        "goalType": goal.type.rawValue,
                        "finalValue": goal.currentValue
                    ])
                }
                
                // マイルストーン達成チェック
                // Convert GoalProgressDetail to GoalProgressAnalysis format
                let goalAnalysis = GoalProgressAnalysis(goal: goal, healthRecords: recentRecords)
                let milestoneUpdates = try await checkMilestoneAchievements(
                    for: goal,
                    progressAnalysis: goalAnalysis
                )
                completedMilestones.append(contentsOf: milestoneUpdates)
                
                // ストリーク達成チェック  
                if let streakAchievement = try await checkStreakAchievements(
                    for: goal,
                    recentRecords: recentRecords
                ) {
                    detectedStreaks.append(streakAchievement)
                }
                
            } catch {
                logger.error(error, context: [
                    "operation": "processGoalAchievements",
                    "goalId": goal.id.uuidString
                ])
            }
        }
        
        // 通知送信
        try await sendAchievementNotifications(
            achievedGoals: achievedGoals,
            completedMilestones: completedMilestones,
            detectedStreaks: detectedStreaks
        )
        
        let processingTime = Date().timeIntervalSince(startTime)
        logger.info("目標達成処理完了", context: [
            "processingTime": processingTime,
            "achievedGoals": achievedGoals.count,
            "milestones": completedMilestones.count,
            "streaks": detectedStreaks.count
        ])
        
        lastGoalCheckTime = Date()
    }
    
    // MARK: - Milestone Achievement Processing
    
    /// マイルストーン達成をチェック
    private func checkMilestoneAchievements(
        for goal: Goal,
        progressAnalysis: GoalProgressAnalysis
    ) async throws -> [GoalMilestone] {
        
        // 目標のマイルストーンを取得または生成
        let milestones = try await getOrGenerateMilestones(for: goal)
        
        // 進捗に基づいてマイルストーン達成状況を更新
        // Convert GoalMilestone to Milestone for GoalTracker compatibility
        let standardMilestones = milestones.map { goalMilestone in
            Milestone(
                goalId: goal.id,
                title: goalMilestone.title,
                description: goalMilestone.description,
                targetValue: goalMilestone.targetValue,
                currentValue: progressAnalysis.goal.currentValue,
                progress: progressAnalysis.goal.currentValue / goalMilestone.targetValue,
                isCompleted: goalMilestone.isCompleted,
                completedDate: goalMilestone.completedAt,
                targetDate: goalMilestone.targetDate,
                priority: goalMilestone.priority,
                category: goalMilestone.category
            )
        }
        
        let updatedStandardMilestones = goalTracker.updateMilestoneProgress(
            milestones: standardMilestones,
            currentValue: progressAnalysis.goal.currentValue
        )
        
        // 新たに達成されたマイルストーンを特定
        let newlyCompleted = goalTracker.checkMilestoneCompletion(
            milestones: updatedStandardMilestones,
            currentValue: progressAnalysis.goal.currentValue
        )
        
        // 重複処理を防ぐため処理済みマイルストーンをフィルタリング
        let unprocessedMilestones = newlyCompleted.filter { milestone in
            let milestoneKey = "\\(goal.id.uuidString)-\\(milestone.id.uuidString)"
            return !processedMilestones.contains(milestoneKey)
        }
        
        // 処理済みリストに追加
        for milestone in unprocessedMilestones {
            let milestoneKey = "\\(goal.id.uuidString)-\\(milestone.id.uuidString)"
            processedMilestones.insert(milestoneKey)
        }
        
        if !unprocessedMilestones.isEmpty {
            logger.info("新規マイルストーン達成検知", context: [
                "goalId": goal.id.uuidString,
                "milestoneCount": unprocessedMilestones.count
            ])
        }
        
        // Convert back to GoalMilestone format
        let completedGoalMilestones = unprocessedMilestones.map { milestone in
            GoalMilestone(
                id: milestone.id,
                title: milestone.title,
                description: milestone.description,
                targetValue: milestone.targetValue,
                isCompleted: milestone.isCompleted,
                completedAt: milestone.completedDate,
                createdAt: Date() // Use current date as fallback
            )
        }
        
        return completedGoalMilestones
    }
    
    /// 目標のマイルストーンを取得または生成
    private func getOrGenerateMilestones(for goal: Goal) async throws -> [GoalMilestone] {
        // 既存のマイルストーンがある場合は取得
        // Note: Goal doesn't have milestones property yet, so we always generate new ones
        // if let existingMilestones = goal.milestones, !existingMilestones.isEmpty {
        //     return existingMilestones
        // }
        
        // マイルストーンがない場合は生成
        let standardMilestones = try await goalTracker.generateMilestones(
            for: goal,
            strategy: .adaptive // アダプティブなマイルストーン戦略
        )
        
        // Convert Milestone to GoalMilestone format
        let generatedMilestones = standardMilestones.map { milestone in
            GoalMilestone(
                title: milestone.title,
                description: milestone.description,
                targetValue: milestone.targetValue,
                isCompleted: milestone.isCompleted,
                category: milestone.category,
                priority: milestone.priority,
                targetDate: milestone.targetDate
            )
        }
        
        logger.info("マイルストーン生成", context: [
            "goalId": goal.id.uuidString,
            "milestoneCount": generatedMilestones.count
        ])
        
        return generatedMilestones
    }
    
    // MARK: - Streak Achievement Processing
    
    /// ストリーク達成をチェック
    private func checkStreakAchievements(
        for goal: Goal,
        recentRecords: [HealthRecord]
    ) async throws -> StreakAchievement? {
        
        // 目標タイプに関連するレコードのみフィルタリング
        let relevantRecords = recentRecords.filter { $0.type == goal.type }
        
        // ストリーク計算
        let streakInfo = calculateStreak(from: relevantRecords)
        
        // ストリークマイルストーンチェック（7日、30日、100日など）
        let significantMilestones = [7, 14, 30, 50, 100, 200, 365]
        
        for milestone in significantMilestones {
            if streakInfo.currentStreak == milestone {
                let streakKey = "\\(goal.type.rawValue)-streak-\\(milestone)"
                
                // 重複通知防止
                if !sentStreakNotifications.contains(streakKey) {
                    sentStreakNotifications.insert(streakKey)
                    
                    return StreakAchievement(
                        dataType: goal.type,
                        streakDays: milestone,
                        achievedAt: Date(),
                        isSignificant: milestone >= 30
                    )
                }
            }
        }
        
        return nil
    }
    
    /// レコードからストリーク情報を計算
    private func calculateStreak(from records: [HealthRecord]) -> StreakInfo {
        guard !records.isEmpty else {
            return StreakInfo(currentStreak: 0, longestStreak: 0, lastRecordDate: nil)
        }
        
        // 日付でグループ化（同日の複数レコードを統合）
        let calendar = Calendar.current
        let recordsByDate = Dictionary(grouping: records) { record in
            calendar.startOfDay(for: record.timestamp)
        }
        
        let sortedDates = recordsByDate.keys.sorted()
        
        var currentStreak = 0
        var longestStreak = 0
        var tempStreak = 1
        
        // 連続日数を計算
        for i in 0..<sortedDates.count {
            if i > 0 {
                let previousDate = sortedDates[i - 1]
                let currentDate = sortedDates[i]
                
                if calendar.dateComponents([.day], from: previousDate, to: currentDate).day == 1 { // 1日差
                    tempStreak += 1
                } else {
                    longestStreak = max(longestStreak, tempStreak)
                    tempStreak = 1
                }
            }
        }
        
        longestStreak = max(longestStreak, tempStreak)
        
        // 現在のストリークを計算（最新日から逆算）
        if let lastDate = sortedDates.last {
            let daysSinceLastRecord = calendar.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
            
            if daysSinceLastRecord <= 1 { // 昨日または今日まで継続
                currentStreak = calculateCurrentStreakFromEnd(sortedDates: sortedDates, calendar: calendar)
            }
        }
        
        return StreakInfo(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastRecordDate: sortedDates.last
        )
    }
    
    /// 最新日から逆算して現在のストリークを計算
    private func calculateCurrentStreakFromEnd(sortedDates: [Date], calendar: Calendar) -> Int {
        guard !sortedDates.isEmpty else { return 0 }
        
        var streak = 1
        
        for i in stride(from: sortedDates.count - 2, through: 0, by: -1) {
            let currentDate = sortedDates[i + 1]
            let previousDate = sortedDates[i]
            
            if calendar.dateComponents([.day], from: previousDate, to: currentDate).day == 1 {
                streak += 1
            } else {
                break
            }
        }
        
        return streak
    }
    
    // MARK: - Notification Sending
    
    /// 達成通知を送信
    private func sendAchievementNotifications(
        achievedGoals: [Goal],
        completedMilestones: [GoalMilestone], 
        detectedStreaks: [StreakAchievement]
    ) async throws {
        
        // 目標完了通知
        for goal in achievedGoals {
            try await notificationManager.sendGoalAchievementNotification(
                goalType: goal.type,
                value: goal.targetValue,
                streakDays: nil
            )
            
            logger.info("目標達成通知送信", context: [
                "goalId": goal.id.uuidString,
                "goalType": goal.type.rawValue,
                "targetValue": goal.targetValue
            ])
        }
        
        // マイルストーン通知
        for milestone in completedMilestones {
            try await sendMilestoneNotification(milestone)
        }
        
        // ストリーク通知
        for streak in detectedStreaks {
            try await notificationManager.sendStreakMilestoneNotification(
                streak: streak.streakDays,
                dataType: streak.dataType
            )
            
            logger.info("ストリーク通知送信", context: [
                "dataType": streak.dataType.rawValue,
                "streakDays": streak.streakDays,
                "isSignificant": streak.isSignificant
            ])
        }
    }
    
    /// マイルストーン達成通知を送信
    private func sendMilestoneNotification(_ milestone: GoalMilestone) async throws {
        let content = NotificationContent(
            type: .milestoneAchievement,
            title: "マイルストーン達成！🎯",
            body: "\\(milestone.title)を達成しました！",
            badge: 1,
            data: [
                "milestoneId": milestone.id.uuidString,
                "targetValue": "\\(milestone.targetValue)",
                "category": milestone.category.rawValue
            ]
        )
        
        try await notificationManager.notificationService.sendImmediateNotification(content)
        
        logger.info("マイルストーン通知送信", context: [
            "milestoneId": milestone.id.uuidString,
            "title": milestone.title,
            "category": milestone.category.rawValue
        ])
    }
    
    // MARK: - Cleanup and Maintenance
    
    /// 古い処理済みマイルストーン記録をクリーンアップ
    public func cleanupProcessedMilestones(olderThan days: Int = 30) {
        let cutoffDate = Date().addingTimeInterval(-Double(days * 24 * 3600))
        
        // 実際の実装では、処理済みマイルストーンに日付を関連付けて管理する必要がある
        // ここでは簡易実装として一定期間後に全クリア
        if let lastCheck = lastGoalCheckTime,
           lastCheck.timeIntervalSince(cutoffDate) < 0 {
            processedMilestones.removeAll()
            sentStreakNotifications.removeAll()
            
            logger.info("処理済み記録クリーンアップ", context: [
                "cutoffDate": cutoffDate.description
            ])
        }
    }
    
    /// 緊急目標アラートの送信（目標期限切迫時）
    public func sendGoalDeadlineAlerts(for goals: [Goal]) async throws {
        let calendar = Calendar.current
        let now = Date()
        
        for goal in goals where goal.isActive && !goal.isCompleted {
            let daysUntilDeadline = calendar.dateComponents([.day], from: now, to: goal.deadline).day ?? 0
            
            // 期限まで3日、1日前にアラート送信
            if daysUntilDeadline == 3 || daysUntilDeadline == 1 {
                try await sendDeadlineAlert(for: goal, daysRemaining: daysUntilDeadline)
            }
        }
    }
    
    /// 期限切迫アラートを送信
    private func sendDeadlineAlert(for goal: Goal, daysRemaining: Int) async throws {
        let message = daysRemaining == 1
            ? "目標期限まで残り1日です！最後のスパートをかけましょう。"
            : "目標期限まで残り\\(daysRemaining)日です。進捗を確認してみましょう。"
        
        try await notificationManager.sendHealthAlert(
            message: message,
            severity: daysRemaining == 1 ? .high : .normal,
            immediate: true
        )
        
        logger.info("期限アラート送信", context: [
            "goalId": goal.id.uuidString,
            "daysRemaining": daysRemaining
        ])
    }
}

// MARK: - Supporting Data Models

/// ストリーク達成情報
struct StreakAchievement {
    let dataType: HealthDataType
    let streakDays: Int
    let achievedAt: Date
    let isSignificant: Bool // 30日以上の重要なマイルストーン
}

/// ストリーク情報
struct StreakInfo {
    let currentStreak: Int
    let longestStreak: Int
    let lastRecordDate: Date?
}

// MARK: - Extensions



// 一時的なマイルストーンモデル定義（実際は別ファイルに配置）
struct GoalMilestone {
    let id: UUID
    let title: String
    let description: String
    let targetValue: Double
    let isCompleted: Bool
    let completedAt: Date?
    let createdAt: Date
    let category: MilestoneCategory
    let priority: MilestonePriority
    let targetDate: Date
    
    init(title: String, description: String, targetValue: Double, isCompleted: Bool = false, category: MilestoneCategory, priority: MilestonePriority, targetDate: Date) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.targetValue = targetValue
        self.isCompleted = isCompleted
        self.completedAt = isCompleted ? Date() : nil
        self.createdAt = Date()
        self.category = category
        self.priority = priority
        self.targetDate = targetDate
    }
    
    init(id: UUID, title: String, description: String, targetValue: Double, isCompleted: Bool, completedAt: Date?, createdAt: Date) {
        self.id = id
        self.title = title
        self.description = description
        self.targetValue = targetValue
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.category = .weekly // Default category
        self.priority = .medium // Default priority
        self.targetDate = Date() // Default target date
    }
}

// MilestoneCategory and MilestonePriority are defined in GoalProgressDetail.swift
// Using typealias to reference the existing definitions
typealias ServiceMilestoneCategory = MilestoneCategory
typealias ServiceMilestonePriority = MilestonePriority

// 一時的なNotificationContent拡張
extension NotificationContent {
    /// マイルストーン達成通知用の初期化
    init(milestoneNotification milestone: GoalMilestone) {
        self.init(
            type: .milestoneAchievement,
            title: "マイルストーン達成！🎯",
            body: "\\(milestone.title)を達成しました！",
            badge: 1,
            data: [
                "milestoneId": milestone.id.uuidString,
                "targetValue": "\\(milestone.targetValue)"
            ]
        )
    }
}

// マイルストーン達成通知タイプを追加
extension AppNotificationType {
    static let milestoneAchievement = AppNotificationType(rawValue: "milestoneAchievement")!
}