import Foundation
import SwiftUI

/// 通知機能の統合管理クラス
@MainActor
@Observable
public final class NotificationManager {
    
    // MARK: - Properties
    
    private let notificationService: NotificationServiceProtocol
    private let reminderScheduler: ReminderNotificationScheduler
    private let logger: AILoggerProtocol
    
    /// 通知権限の状態
    public private(set) var authorizationStatus: NotificationAuthorizationStatus = .notDetermined
    
    /// 通知設定
    public private(set) var notificationSettings: [NotificationSettings] = []
    
    /// アクティブなリマインダー
    public private(set) var activeReminders: [ScheduledNotification] = []
    
    /// 通知統計
    public private(set) var notificationStats: NotificationStats?
    
    /// 初期化完了フラグ
    public private(set) var isInitialized: Bool = false
    
    // MARK: - Initialization
    
    public init(logger: AILoggerProtocol) {
        self.logger = logger
        self.notificationService = NotificationService(logger: logger)
        self.reminderScheduler = ReminderNotificationScheduler(
            notificationService: notificationService,
            logger: logger
        )
    }
    
    // MARK: - Lifecycle Methods
    
    /// 通知マネージャーを初期化
    public func initialize() async {
        logger.info("NotificationManager初期化開始", context: nil)
        
        do {
            // 権限状態を確認
            await updateAuthorizationStatus()
            
            // 通知設定を読み込み
            await loadNotificationSettings()
            
            // アクティブなリマインダーを読み込み
            await loadActiveReminders()
            
            // 通知統計を読み込み
            await loadNotificationStats()
            
            // 初期化完了
            isInitialized = true
            
            logger.info("NotificationManager初期化完了", context: [
                "authStatus": authorizationStatus.rawValue,
                "settingsCount": notificationSettings.count,
                "remindersCount": activeReminders.count
            ])
            
        } catch {
            logger.error(error, context: ["operation": "initialize"])
        }
    }
    
    // MARK: - Authorization Management
    
    /// 通知権限を要求
    public func requestNotificationPermission() async throws -> Bool {
        logger.info("通知権限要求", context: nil)
        
        let granted = try await notificationService.requestAuthorization()
        
        if granted {
            await updateAuthorizationStatus()
            
            // 権限が許可されたら標準リマインダーをセットアップ
            try await setupDefaultReminders()
        }
        
        return granted
    }
    
    /// 設定画面への遷移を案内
    public func showSettingsPrompt() async {
        await notificationService.promptForSettings()
    }
    
    // MARK: - Reminder Management
    
    /// 標準リマインダーのセットアップ
    public func setupDefaultReminders() async throws {
        guard authorizationStatus.isAuthorized else {
            throw NotificationServiceError.authorizationDenied
        }
        
        logger.info("標準リマインダーセットアップ", context: nil)
        
        try await reminderScheduler.setupDefaultReminders()
        await loadActiveReminders()
    }
    
    /// 特定データタイプのリマインダー設定
    public func configureReminder(
        for dataType: HealthDataType,
        times: [Date],
        frequency: NotificationScheduleFrequency,
        enabled: Bool
    ) async throws {
        logger.info("リマインダー設定", context: [
            "dataType": dataType.rawValue,
            "enabled": enabled,
            "timesCount": times.count
        ])
        
        if enabled {
            try await reminderScheduler.scheduleDataTypeReminder(
                dataType: dataType,
                times: times,
                frequency: frequency
            )
        } else {
            try await reminderScheduler.cancelDataTypeReminder(for: dataType)
        }
        
        await loadActiveReminders()
    }
    
    /// インテリジェント・リマインダーの開始
    public func enableIntelligentReminders() async throws {
        logger.info("インテリジェント・リマインダー開始", context: nil)
        
        try await reminderScheduler.scheduleIntelligentReminders()
        await loadActiveReminders()
    }
    
    /// アダプティブ調整の実行
    public func performAdaptiveAdjustment() async throws {
        logger.info("アダプティブ調整実行", context: nil)
        
        try await reminderScheduler.adjustRemindersBasedOnSuccessRate()
        await loadActiveReminders()
    }
    
    // MARK: - Goal Achievement Notifications
    
    /// 目標達成通知を送信
    public func sendGoalAchievementNotification(
        goalType: HealthDataType,
        value: Double,
        streakDays: Int? = nil
    ) async throws {
        logger.info("目標達成通知送信", context: [
            "goalType": goalType.rawValue,
            "value": value
        ])
        
        try await notificationService.sendGoalAchievementNotification(
            goalType: goalType,
            value: value,
            streakDays: streakDays
        )
        
        await updateNotificationStats()
    }
    
    /// ストリークマイルストーン通知を送信
    public func sendStreakMilestoneNotification(
        streak: Int,
        dataType: HealthDataType? = nil
    ) async throws {
        logger.info("ストリークマイルストーン通知送信", context: [
            "streak": streak,
            "dataType": dataType?.rawValue ?? "all"
        ])
        
        try await notificationService.sendStreakMilestoneNotification(
            streak: streak,
            dataType: dataType
        )
        
        await updateNotificationStats()
    }
    
    // MARK: - Settings Management
    
    /// 通知設定を更新
    public func updateNotificationSetting(_ setting: NotificationSettings) async throws {
        logger.info("通知設定更新", context: [
            "type": setting.type.rawValue,
            "enabled": setting.isEnabled
        ])
        
        try await notificationService.updateNotificationSettings(setting)
        await loadNotificationSettings()
        
        // リマインダーが更新された場合はアクティブリストも更新
        if setting.type == .dataReminder {
            await loadActiveReminders()
        }
    }
    
    /// 通知設定をリセット
    public func resetNotificationSettings() async throws {
        logger.info("通知設定リセット", context: nil)
        
        try await notificationService.resetNotificationSettings()
        await loadNotificationSettings()
        await loadActiveReminders()
    }
    
    // MARK: - Health Alerts
    
    /// 健康アラートを送信
    public func sendHealthAlert(
        message: String,
        severity: HealthAlertSeverity = .normal,
        immediate: Bool = true
    ) async throws {
        logger.info("健康アラート送信", context: [
            "severity": severity.rawValue,
            "immediate": immediate
        ])
        
        try await notificationService.sendHealthAlert(
            message: message,
            severity: severity.rawValue,
            immediate: immediate
        )
        
        await updateNotificationStats()
    }
    
    // MARK: - Notification History
    
    /// 配信済み通知をクリア
    public func clearDeliveredNotifications() async {
        logger.info("配信済み通知クリア", context: nil)
        
        await notificationService.clearDeliveredNotifications()
        await updateNotificationStats()
    }
    
    /// 特定タイプの配信済み通知をクリア
    public func clearDeliveredNotifications(ofType type: AppNotificationType) async {
        logger.info("タイプ別配信済み通知クリア", context: ["type": type.rawValue])
        
        await notificationService.clearDeliveredNotifications(ofType: type)
        await updateNotificationStats()
    }
    
    // MARK: - Analytics and Insights
    
    /// 通知効果分析
    public func analyzeNotificationEffectiveness() async -> NotificationEffectivenessReport {
        logger.info("通知効果分析実行", context: nil)
        
        let stats = await notificationService.getNotificationStats()
        let effectiveness = calculateEffectiveness(from: stats)
        
        return NotificationEffectivenessReport(
            overallEngagementRate: stats.engagementRate,
            deliveryRate: stats.deliveryRate,
            typeEffectiveness: effectiveness.typeEffectiveness,
            recommendations: effectiveness.recommendations,
            generatedAt: Date()
        )
    }
    
    /// 週次通知レポートを生成
    public func generateWeeklyNotificationReport() async throws {
        logger.info("週次通知レポート生成", context: nil)
        
        let effectiveness = await analyzeNotificationEffectiveness()
        let summary = createWeeklySummary(from: effectiveness)
        
        try await notificationService.scheduleWeeklyInsight(
            summary: summary,
            dayOfWeek: 1, // 日曜日
            time: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        )
    }
}

// MARK: - Private Helper Methods

private extension NotificationManager {
    
    /// 権限状態を更新
    func updateAuthorizationStatus() async {
        let status = await notificationService.getAuthorizationStatus()
        authorizationStatus = status
    }
    
    /// 通知設定を読み込み
    func loadNotificationSettings() async {
        let settings = await notificationService.getNotificationSettings()
        notificationSettings = settings
    }
    
    /// アクティブなリマインダーを読み込み
    func loadActiveReminders() async {
        let reminders = await notificationService.getPendingNotifications()
        activeReminders = reminders
    }
    
    /// 通知統計を読み込み
    func loadNotificationStats() async {
        let stats = await notificationService.getNotificationStats()
        notificationStats = stats
    }
    
    /// 通知統計を更新
    func updateNotificationStats() async {
        await loadNotificationStats()
    }
    
    /// 通知効果を計算
    func calculateEffectiveness(from stats: NotificationStats) -> NotificationEffectivenessAnalysis {
        var typeEffectiveness: [AppNotificationType: Double] = [:]
        
        for (type, count) in stats.typeBreakdown {
            // 簡易的な効果計算（実際にはより複雑な分析が必要）
            let effectiveness = min(Double(count) / 100.0, 1.0) * stats.engagementRate
            typeEffectiveness[type] = effectiveness
        }
        
        let recommendations = generateRecommendations(
            from: typeEffectiveness,
            overallRate: stats.engagementRate
        )
        
        return NotificationEffectivenessAnalysis(
            typeEffectiveness: typeEffectiveness,
            recommendations: recommendations
        )
    }
    
    /// レコメンデーション生成
    func generateRecommendations(
        from typeEffectiveness: [AppNotificationType: Double],
        overallRate: Double
    ) -> [String] {
        var recommendations: [String] = []
        
        if overallRate < 0.3 {
            recommendations.append("通知の頻度を見直してください。")
            recommendations.append("より個人化されたメッセージを検討してください。")
        }
        
        for (type, effectiveness) in typeEffectiveness {
            if effectiveness < 0.2 {
                recommendations.append("\(type.displayName)通知のタイミングを調整することをお勧めします。")
            }
        }
        
        if recommendations.isEmpty {
            recommendations.append("現在の通知設定は良好に機能しています。")
        }
        
        return recommendations
    }
    
    /// 週次サマリー作成
    func createWeeklySummary(from effectiveness: NotificationEffectivenessReport) -> String {
        let engagementPercent = Int(effectiveness.overallEngagementRate * 100)
        let deliveryPercent = Int(effectiveness.deliveryRate * 100)
        
        return """
        今週の通知レポート 📊
        
        • 通知応答率: \(engagementPercent)%
        • 配信成功率: \(deliveryPercent)%
        
        \(effectiveness.recommendations.first ?? "継続して健康管理を頑張りましょう！")
        """
    }
}

// MARK: - Supporting Types

/// 健康アラートの重要度
public enum HealthAlertSeverity: String, CaseIterable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"
}

/// 通知効果分析結果
struct NotificationEffectivenessAnalysis {
    let typeEffectiveness: [AppNotificationType: Double]
    let recommendations: [String]
}

/// 通知効果レポート
public struct NotificationEffectivenessReport: Codable {
    public let overallEngagementRate: Double
    public let deliveryRate: Double
    public let typeEffectiveness: [String: Double]  // AppNotificationTypeのrawValue
    public let recommendations: [String]
    public let generatedAt: Date
    
    init(
        overallEngagementRate: Double,
        deliveryRate: Double,
        typeEffectiveness: [AppNotificationType: Double],
        recommendations: [String],
        generatedAt: Date
    ) {
        self.overallEngagementRate = overallEngagementRate
        self.deliveryRate = deliveryRate
        self.typeEffectiveness = typeEffectiveness.reduce(into: [:]) { result, pair in
            result[pair.key.rawValue] = pair.value
        }
        self.recommendations = recommendations
        self.generatedAt = generatedAt
    }
}

// MARK: - Mock Implementation (for testing)

#if DEBUG
/// テスト用のモック実装
public final class MockNotificationManager: NotificationManager {
    
    public override init(logger: AILoggerProtocol) {
        super.init(logger: logger)
    }
    
    public override func requestNotificationPermission() async throws -> Bool {
        authorizationStatus = .authorized
        return true
    }
    
    public override func setupDefaultReminders() async throws {
        // モック実装：何もしない
        isInitialized = true
    }
}
#endif