import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif


/// 通知設定画面のViewModel
/// 通知権限、設定の管理と永続化を担当
@MainActor
@Observable
final class NotificationSettingsViewModel {
    
    // MARK: - Published Properties
    
    // 権限状態
    var authorizationStatus: NotificationAuthorizationStatus = .notDetermined
    
    // 通知種別の有効/無効状態
    var isDataRemindersEnabled: Bool = false
    var isGoalAchievementEnabled: Bool = false
    var isStreakMilestoneEnabled: Bool = false
    var isHealthAlertEnabled: Bool = false
    var isWeeklyInsightEnabled: Bool = false
    
    // データリマインダー詳細設定
    var dataReminderFrequency: NotificationScheduleFrequency = .daily
    var dataReminderTimes: [Date] = []
    var isIntelligentRemindersEnabled: Bool = false
    
    // 目標達成通知設定
    var notifyGoalCompletion: Bool = true
    var notifyMilestoneAchievement: Bool = true
    var notifyGoalDeadline: Bool = true
    
    // ストリーク通知設定
    var enabledStreakMilestones: Set<Int> = [7, 30, 100]
    
    // 健康アラート設定
    var enabledAlertSeverities: Set<HealthAlertSeverity> = [.normal, .high, .critical]
    
    // MARK: - Dependencies
    
    private let notificationManager: NotificationManager
    private let logger: AILoggerProtocol
    
    // MARK: - Internal State
    
    private var isInitialized: Bool = false
    
    // MARK: - Initialization
    
    init(
        notificationManager: NotificationManager? = nil,
        logger: AILoggerProtocol = AILogger()
    ) {
        self.notificationManager = notificationManager ?? NotificationManager(logger: logger)
        self.logger = logger
    }
    
    // MARK: - Public Methods
    
    /// ViewModelを初期化し、現在の設定を読み込み
    func initialize() async {
        guard !isInitialized else { return }
        
        logger.info("通知設定ViewModel初期化開始", context: nil)
        
        do {
            // NotificationManagerを初期化
            await notificationManager.initialize()
            
            // 現在の権限状態を取得
            await updateAuthorizationStatus()
            
            // 現在の設定を読み込み
            await loadCurrentSettings()
            
            isInitialized = true
            
            logger.info("通知設定ViewModel初期化完了", context: [
                "authStatus": authorizationStatus.rawValue,
                "dataReminders": isDataRemindersEnabled,
                "goalAchievement": isGoalAchievementEnabled
            ])
            
        } catch {
            logger.error(error, context: ["operation": "initialize"])
        }
    }
    
    /// 通知権限を要求
    func requestNotificationPermission() async {
        logger.info("通知権限要求", context: nil)
        
        do {
            let granted = try await notificationManager.requestNotificationPermission()
            
            if granted {
                await updateAuthorizationStatus()
                
                // 権限が許可されたら標準リマインダーを設定
                try await notificationManager.setupDefaultReminders()
                await loadCurrentSettings()
            }
            
            logger.info("通知権限要求完了", context: ["granted": granted])
            
        } catch {
            logger.error(error, context: ["operation": "requestPermission"])
        }
    }
    
    /// システム設定を開く
    func openSystemSettings() async {
        #if canImport(UIKit)
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            await UIApplication.shared.open(settingsUrl)
        }
        #endif
    }
    
    // MARK: - Notification Type Management
    
    /// 通知種別の有効/無効を切り替え
    func toggleNotificationType(_ type: AppNotificationType, enabled: Bool) async {
        logger.info("通知種別切り替え", context: [
            "type": type.rawValue,
            "enabled": enabled
        ])
        
        do {
            // 対応する設定を取得または作成
            let currentSettings = await notificationManager.getNotificationSettings(for: type)
            
            let updatedSettings = NotificationSettings(
                type: type,
                isEnabled: enabled,
                scheduledTimes: currentSettings.scheduledTimes.isEmpty ? getDefaultTimes(for: type) : currentSettings.scheduledTimes,
                frequency: currentSettings.frequency
            )
            
            try await notificationManager.updateNotificationSetting(updatedSettings)
            
            // UI状態を更新
            await updateUIState(for: type, enabled: enabled)
            
        } catch {
            logger.error(error, context: [
                "operation": "toggleNotificationType",
                "type": type.rawValue
            ])
        }
    }
    
    // MARK: - Data Reminder Settings
    
    /// データリマインダーの頻度を更新
    func updateDataReminderFrequency(_ frequency: NotificationScheduleFrequency) async {
        dataReminderFrequency = frequency
        
        logger.info("データリマインダー頻度更新", context: [
            "frequency": frequency.rawValue
        ])
        
        do {
            let settings = NotificationSettings(
                type: .dataReminder,
                isEnabled: isDataRemindersEnabled,
                scheduledTimes: dataReminderTimes,
                frequency: frequency
            )
            
            try await notificationManager.updateNotificationSetting(settings)
            
        } catch {
            logger.error(error, context: ["operation": "updateFrequency"])
        }
    }
    
    /// データリマインダーの時間を追加
    func addDataReminderTime() async {
        guard dataReminderTimes.count < 5 else { return }
        
        // デフォルトで9時を追加
        let calendar = Calendar.current
        let defaultTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        
        dataReminderTimes.append(defaultTime)
        await updateDataReminderSettings()
    }
    
    /// データリマインダーの時間を削除
    func removeDataReminderTime(at index: Int) async {
        guard index >= 0 && index < dataReminderTimes.count else { return }
        
        dataReminderTimes.remove(at: index)
        await updateDataReminderSettings()
    }
    
    /// データリマインダーの時間を更新
    func updateNotificationTime(for type: AppNotificationType, at index: Int, to newTime: Date) async {
        switch type {
        case .dataReminder:
            guard index >= 0 && index < dataReminderTimes.count else { return }
            dataReminderTimes[index] = newTime
            await updateDataReminderSettings()
            
        default:
            logger.warning("指定された通知タイプの時間更新はサポートされていません", context: [
                "type": type.rawValue
            ])
        }
    }
    
    /// インテリジェント・リマインダーの有効/無効を切り替え
    func toggleIntelligentReminders(_ enabled: Bool) async {
        isIntelligentRemindersEnabled = enabled
        
        logger.info("インテリジェント・リマインダー切り替え", context: ["enabled": enabled])
        
        do {
            if enabled {
                try await notificationManager.enableIntelligentReminders()
            }
            // 無効化の場合は特別な処理は不要（通常のリマインダーのみ使用）
            
        } catch {
            logger.error(error, context: ["operation": "toggleIntelligentReminders"])
        }
    }
    
    // MARK: - Goal Achievement Settings
    
    func updateGoalCompletionNotification(_ enabled: Bool) async {
        notifyGoalCompletion = enabled
        await updateGoalNotificationSettings()
    }
    
    func updateMilestoneNotification(_ enabled: Bool) async {
        notifyMilestoneAchievement = enabled
        await updateGoalNotificationSettings()
    }
    
    func updateGoalDeadlineNotification(_ enabled: Bool) async {
        notifyGoalDeadline = enabled
        await updateGoalNotificationSettings()
    }
    
    // MARK: - Streak Notification Settings
    
    func toggleStreakMilestone(_ days: Int, enabled: Bool) async {
        if enabled {
            enabledStreakMilestones.insert(days)
        } else {
            enabledStreakMilestones.remove(days)
        }
        
        logger.info("ストリークマイルストーン切り替え", context: [
            "days": days,
            "enabled": enabled
        ])
        
        // 設定を永続化
        await updateStreakNotificationSettings()
    }
    
    // MARK: - Health Alert Settings
    
    func toggleAlertSeverity(_ severity: HealthAlertSeverity, enabled: Bool) async {
        if enabled {
            enabledAlertSeverities.insert(severity)
        } else {
            enabledAlertSeverities.remove(severity)
        }
        
        logger.info("健康アラート重要度切り替え", context: [
            "severity": severity.rawValue,
            "enabled": enabled
        ])
        
        await updateHealthAlertSettings()
    }
    
    // MARK: - Bulk Settings
    
    /// すべての通知を有効化
    func enableAllNotifications() async {
        logger.info("すべての通知を有効化", context: nil)
        
        await toggleNotificationType(.dataReminder, enabled: true)
        await toggleNotificationType(.goalAchievement, enabled: true)
        await toggleNotificationType(.streakMilestone, enabled: true)
        await toggleNotificationType(.healthAlert, enabled: true)
        
        isIntelligentRemindersEnabled = true
        notifyGoalCompletion = true
        notifyMilestoneAchievement = true
        notifyGoalDeadline = true
        
        enabledStreakMilestones = [7, 14, 30, 50, 100]
        enabledAlertSeverities = Set(HealthAlertSeverity.allCases)
        
        await updateAllSettings()
    }
    
    /// すべての通知を無効化
    func disableAllNotifications() async {
        logger.info("すべての通知を無効化", context: nil)
        
        await toggleNotificationType(.dataReminder, enabled: false)
        await toggleNotificationType(.goalAchievement, enabled: false)
        await toggleNotificationType(.streakMilestone, enabled: false)
        await toggleNotificationType(.healthAlert, enabled: false)
        
        isIntelligentRemindersEnabled = false
        notifyGoalCompletion = false
        notifyMilestoneAchievement = false
        notifyGoalDeadline = false
        
        enabledStreakMilestones.removeAll()
        enabledAlertSeverities.removeAll()
        
        await updateAllSettings()
    }
    
    /// すべての設定をリセット
    func resetAllSettings() async {
        logger.info("すべての設定をリセット", context: nil)
        
        do {
            try await notificationManager.resetNotificationSettings()
            await loadDefaultSettings()
            
        } catch {
            logger.error(error, context: ["operation": "resetAllSettings"])
        }
    }
    
    // MARK: - Private Methods
    
    private func updateAuthorizationStatus() async {
        authorizationStatus = await notificationManager.getAuthorizationStatus()
    }
    
    private func loadCurrentSettings() async {
        let settings = await notificationManager.getNotificationSettings()
        
        for setting in settings {
            await updateUIState(for: setting.type, enabled: setting.isEnabled)
            
            if setting.type == .dataReminder {
                dataReminderFrequency = setting.frequency
                dataReminderTimes = setting.scheduledTimes
            }
        }
    }
    
    private func loadDefaultSettings() async {
        // デフォルト設定を読み込み
        isDataRemindersEnabled = true
        isGoalAchievementEnabled = true
        isStreakMilestoneEnabled = true
        isHealthAlertEnabled = true
        
        dataReminderFrequency = .daily
        dataReminderTimes = getDefaultTimes(for: .dataReminder)
        isIntelligentRemindersEnabled = false
        
        notifyGoalCompletion = true
        notifyMilestoneAchievement = true
        notifyGoalDeadline = true
        
        enabledStreakMilestones = [7, 30, 100]
        enabledAlertSeverities = [.normal, .high, .critical]
    }
    
    private func updateUIState(for type: AppNotificationType, enabled: Bool) async {
        switch type {
        case .dataReminder:
            isDataRemindersEnabled = enabled
        case .goalAchievement:
            isGoalAchievementEnabled = enabled
        case .streakMilestone:
            isStreakMilestoneEnabled = enabled
        case .healthAlert:
            isHealthAlertEnabled = enabled
        case .weeklyInsight:
            isWeeklyInsightEnabled = enabled
        default:
            break
        }
    }
    
    private func getDefaultTimes(for type: AppNotificationType) -> [Date] {
        let calendar = Calendar.current
        let now = Date()
        
        switch type {
        case .dataReminder:
            // 朝9時と夜8時
            return [
                calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now),
                calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now)
            ].compactMap { $0 }
            
        default:
            // 朝10時
            return [
                calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now)
            ].compactMap { $0 }
        }
    }
    
    private func updateDataReminderSettings() async {
        let settings = NotificationSettings(
            type: .dataReminder,
            isEnabled: isDataRemindersEnabled,
            scheduledTimes: dataReminderTimes,
            frequency: dataReminderFrequency
        )
        
        do {
            try await notificationManager.updateNotificationSetting(settings)
        } catch {
            logger.error(error, context: ["operation": "updateDataReminderSettings"])
        }
    }
    
    private func updateGoalNotificationSettings() async {
        // 目標通知設定の詳細は必要に応じてNotificationSettingsモデルを拡張
        let settings = NotificationSettings(
            type: .goalAchievement,
            isEnabled: isGoalAchievementEnabled,
            scheduledTimes: getDefaultTimes(for: .goalAchievement),
            frequency: .disabled, // 目標達成時のイベント駆動型
            customMessage: nil,
            additionalData: [
                "notifyCompletion": notifyGoalCompletion,
                "notifyMilestone": notifyMilestoneAchievement,
                "notifyDeadline": notifyGoalDeadline
            ]
        )
        
        do {
            try await notificationManager.updateNotificationSetting(settings)
        } catch {
            logger.error(error, context: ["operation": "updateGoalNotificationSettings"])
        }
    }
    
    private func updateStreakNotificationSettings() async {
        let milestoneData = enabledStreakMilestones.map { "\($0)" }.joined(separator: ",")
        
        let settings = NotificationSettings(
            type: .streakMilestone,
            isEnabled: isStreakMilestoneEnabled,
            scheduledTimes: getDefaultTimes(for: .streakMilestone),
            frequency: .disabled, // イベント駆動型
            additionalData: ["enabledMilestones": milestoneData]
        )
        
        do {
            try await notificationManager.updateNotificationSetting(settings)
        } catch {
            logger.error(error, context: ["operation": "updateStreakNotificationSettings"])
        }
    }
    
    private func updateHealthAlertSettings() async {
        let severityData = enabledAlertSeverities.map { $0.rawValue }.joined(separator: ",")
        
        let settings = NotificationSettings(
            type: .healthAlert,
            isEnabled: isHealthAlertEnabled,
            scheduledTimes: [],
            frequency: .disabled, // 即座配信
            additionalData: ["enabledSeverities": severityData]
        )
        
        do {
            try await notificationManager.updateNotificationSetting(settings)
        } catch {
            logger.error(error, context: ["operation": "updateHealthAlertSettings"])
        }
    }
    
    private func updateAllSettings() async {
        await updateDataReminderSettings()
        await updateGoalNotificationSettings()
        await updateStreakNotificationSettings()
        await updateHealthAlertSettings()
    }
}

// MARK: - Extensions for Additional Data

extension NotificationSettings {
    init(
        type: AppNotificationType,
        isEnabled: Bool,
        scheduledTimes: [Date],
        frequency: NotificationScheduleFrequency,
        customMessage: String? = nil,
        additionalData: [String: Any] = [:]
    ) {
        self.init(
            type: type,
            isEnabled: isEnabled,
            scheduledTimes: scheduledTimes,
            frequency: frequency,
            customMessage: customMessage
        )
        // additionalDataの処理は実装に応じて追加
        // 現在のNotificationSettingsモデルに存在しない場合は拡張が必要
    }
}