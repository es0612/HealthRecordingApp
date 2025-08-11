import Foundation
import SwiftUI

/// リマインダー通知の専用スケジューラー
@MainActor
public final class ReminderNotificationScheduler {
    
    // MARK: - Properties
    
    private let notificationService: NotificationServiceProtocol
    private let logger: AILoggerProtocol
    
    /// 標準的なリマインダー時間
    private let defaultReminderTimes: [Date] = {
        let calendar = Calendar.current
        let now = Date()
        return [
            calendar.date(bySettingHour: 8, minute: 0, second: 0, of: now) ?? now,   // 朝8:00
            calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now,  // 昼12:00
            calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now) ?? now   // 夜8:00
        ]
    }()
    
    /// ユーザーの習慣データ追跡
    private struct UserHabit: Codable {
        let dataType: HealthDataType
        let preferredTimes: [Date]
        let frequency: NotificationScheduleFrequency
        let lastRecorded: Date?
        let streakDays: Int
        let isActive: Bool
        let customMessage: String?
        
        init(
            dataType: HealthDataType,
            preferredTimes: [Date] = [],
            frequency: NotificationScheduleFrequency = .daily,
            lastRecorded: Date? = nil,
            streakDays: Int = 0,
            isActive: Bool = true,
            customMessage: String? = nil
        ) {
            self.dataType = dataType
            self.preferredTimes = preferredTimes.isEmpty ? [] : preferredTimes
            self.frequency = frequency
            self.lastRecorded = lastRecorded
            self.streakDays = streakDays
            self.isActive = isActive
            self.customMessage = customMessage
        }
    }
    
    // MARK: - Initialization
    
    public init(
        notificationService: NotificationServiceProtocol,
        logger: AILoggerProtocol
    ) {
        self.notificationService = notificationService
        self.logger = logger
    }
    
    // MARK: - Public Methods
    
    /// 全データタイプの標準リマインダーをセットアップ
    public func setupDefaultReminders() async throws {
        logger.info("標準リマインダーセットアップ開始", context: nil)
        
        for dataType in HealthDataType.allCases {
            try await scheduleDataTypeReminder(
                dataType: dataType,
                times: getOptimalTimesFor(dataType: dataType),
                frequency: .daily
            )
        }
        
        logger.info("標準リマインダーセットアップ完了", context: [
            "dataTypesCount": HealthDataType.allCases.count
        ])
    }
    
    /// 特定のデータタイプのリマインダーをスケジュール
    public func scheduleDataTypeReminder(
        dataType: HealthDataType,
        times: [Date],
        frequency: NotificationScheduleFrequency = .daily,
        customMessage: String? = nil
    ) async throws {
        logger.info("データタイプリマインダースケジュール", context: [
            "dataType": dataType.rawValue,
            "timesCount": times.count,
            "frequency": frequency.rawValue
        ])
        
        // 既存のリマインダーをキャンセル
        try await cancelDataTypeReminder(for: dataType)
        
        // 新しいリマインダーをスケジュール
        try await notificationService.scheduleDataReminder(
            for: dataType,
            at: times,
            frequency: frequency
        )
        
        // ユーザー習慣を更新
        await updateUserHabit(
            dataType: dataType,
            preferredTimes: times,
            frequency: frequency,
            customMessage: customMessage
        )
    }
    
    /// インテリジェント・リマインダー（ユーザーの習慣に基づく）
    public func scheduleIntelligentReminders() async throws {
        logger.info("インテリジェント・リマインダースケジュール開始", context: nil)
        
        let userHabits = await getUserHabits()
        
        for habit in userHabits where habit.isActive {
            let optimizedTimes = await calculateOptimalReminderTimes(for: habit)
            let content = createPersonalizedReminderContent(for: habit)
            
            try await schedulePersonalizedReminder(
                habit: habit,
                times: optimizedTimes,
                content: content
            )
        }
        
        logger.info("インテリジェント・リマインダースケジュール完了", context: [
            "habitsCount": userHabits.count
        ])
    }
    
    /// 特定データタイプのリマインダーをキャンセル
    public func cancelDataTypeReminder(for dataType: HealthDataType) async throws {
        logger.info("データタイプリマインダーキャンセル", context: [
            "dataType": dataType.rawValue
        ])
        
        await notificationService.cancelNotifications(ofType: .dataReminder)
        
        // TODO: より詳細な制御が必要な場合は、通知IDによる個別キャンセル
    }
    
    /// 条件ベース・リマインダー（ストリーク維持など）
    public func scheduleConditionalReminder(
        dataType: HealthDataType,
        condition: ReminderCondition,
        triggerTime: Date
    ) async throws {
        logger.info("条件ベースリマインダースケジュール", context: [
            "dataType": dataType.rawValue,
            "condition": condition.rawValue,
            "triggerTime": triggerTime.ISO8601String
        ])
        
        let content = createConditionalReminderContent(
            dataType: dataType,
            condition: condition
        )
        
        _ = try await notificationService.scheduleNotification(
            content,
            at: triggerTime,
            repeating: condition.shouldRepeat
        )
    }
    
    /// アダプティブ・リマインダー（記録成功率に基づく調整）
    public func adjustRemindersBasedOnSuccessRate() async throws {
        logger.info("アダプティブ・リマインダー調整開始", context: nil)
        
        let habits = await getUserHabits()
        var adjustedCount = 0
        
        for habit in habits where habit.isActive {
            let successRate = await calculateRecordingSuccessRate(for: habit.dataType)
            
            if successRate < 0.5 { // 成功率50%未満の場合
                let newTimes = await increasReminderFrequency(for: habit)
                try await scheduleDataTypeReminder(
                    dataType: habit.dataType,
                    times: newTimes,
                    frequency: habit.frequency
                )
                adjustedCount += 1
            } else if successRate > 0.9 { // 成功率90%以上の場合
                let newTimes = await decreaseReminderFrequency(for: habit)
                try await scheduleDataTypeReminder(
                    dataType: habit.dataType,
                    times: newTimes,
                    frequency: habit.frequency
                )
                adjustedCount += 1
            }
        }
        
        logger.info("アダプティブ・リマインダー調整完了", context: [
            "adjustedCount": adjustedCount
        ])
    }
}

// MARK: - Private Helper Methods

private extension ReminderNotificationScheduler {
    
    /// データタイプに最適な時間を取得
    func getOptimalTimesFor(dataType: HealthDataType) -> [Date] {
        let calendar = Calendar.current
        let now = Date()
        
        switch dataType {
        case .weight:
            // 体重は朝一番が最適
            return [calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now) ?? now]
            
        case .steps:
            // 歩数は日中と夜に確認
            return [
                calendar.date(bySettingHour: 14, minute: 0, second: 0, of: now) ?? now,  // 午後2:00
                calendar.date(bySettingHour: 21, minute: 0, second: 0, of: now) ?? now   // 夜9:00
            ]
            
        case .calories:
            // カロリーは食事時間に合わせて
            return [
                calendar.date(bySettingHour: 8, minute: 0, second: 0, of: now) ?? now,   // 朝8:00
                calendar.date(bySettingHour: 12, minute: 30, second: 0, of: now) ?? now, // 昼12:30
                calendar.date(bySettingHour: 19, minute: 0, second: 0, of: now) ?? now   // 夜7:00
            ]
            
        case .heartRate:
            // 心拍数は朝と夜
            return [
                calendar.date(bySettingHour: 8, minute: 30, second: 0, of: now) ?? now,  // 朝8:30
                calendar.date(bySettingHour: 22, minute: 0, second: 0, of: now) ?? now   // 夜10:00
            ]
            
        case .bloodGlucose:
            // 血糖値は食前・食後
            return [
                calendar.date(bySettingHour: 7, minute: 30, second: 0, of: now) ?? now,  // 朝食前
                calendar.date(bySettingHour: 11, minute: 30, second: 0, of: now) ?? now, // 昼食前
                calendar.date(bySettingHour: 18, minute: 30, second: 0, of: now) ?? now  // 夕食前
            ]
        }
    }
    
    /// ユーザー習慣を取得
    func getUserHabits() async -> [UserHabit] {
        // TODO: 実際の実装では、UserDefaultsまたはSwiftDataから取得
        return HealthDataType.allCases.map { dataType in
            UserHabit(
                dataType: dataType,
                preferredTimes: getOptimalTimesFor(dataType: dataType),
                frequency: .daily,
                streakDays: Int.random(in: 0...30)
            )
        }
    }
    
    /// ユーザー習慣を更新
    func updateUserHabit(
        dataType: HealthDataType,
        preferredTimes: [Date],
        frequency: NotificationScheduleFrequency,
        customMessage: String?
    ) async {
        // TODO: 実際の実装では、UserDefaultsまたはSwiftDataに保存
        logger.debug("ユーザー習慣更新", context: [
            "dataType": dataType.rawValue,
            "timesCount": preferredTimes.count
        ])
    }
    
    /// 最適なリマインダー時間を計算
    func calculateOptimalReminderTimes(for habit: UserHabit) async -> [Date] {
        // 機械学習的アプローチ（簡易版）
        let historicalSuccessRates = await getHistoricalSuccessRates(for: habit.dataType)
        let optimalTimes = habit.preferredTimes.filter { time in
            let hour = Calendar.current.component(.hour, from: time)
            return historicalSuccessRates[hour] ?? 0 > 0.6
        }
        
        return optimalTimes.isEmpty ? habit.preferredTimes : optimalTimes
    }
    
    /// 記録成功率を取得
    func getHistoricalSuccessRates(for dataType: HealthDataType) async -> [Int: Double] {
        // TODO: 実際の実装では、過去のデータから計算
        // 現在は時間帯別のダミーデータを返す
        switch dataType {
        case .weight:
            return [7: 0.9, 8: 0.8, 9: 0.6]  // 朝の時間帯が高い成功率
        case .steps:
            return [14: 0.7, 18: 0.8, 21: 0.9]  // 午後〜夜が高い成功率
        case .calories:
            return [8: 0.8, 12: 0.7, 19: 0.8]  // 食事時間が高い成功率
        case .heartRate:
            return [8: 0.7, 22: 0.8]  // 朝と夜が高い成功率
        case .bloodGlucose:
            return [7: 0.9, 11: 0.8, 18: 0.8]  // 食前が高い成功率
        }
    }
    
    /// パーソナライズドリマインダーコンテンツを作成
    func createPersonalizedReminderContent(for habit: UserHabit) -> NotificationContent {
        let streak = habit.streakDays
        let dataType = habit.dataType
        
        let personalizedMessage: String
        if let customMessage = habit.customMessage {
            personalizedMessage = customMessage
        } else if streak > 7 {
            personalizedMessage = "\(dataType.displayName)記録、\(streak)日連続中！今日も続けましょう 💪"
        } else if streak > 0 {
            personalizedMessage = "\(dataType.displayName)を記録して、\(streak)日連続記録を伸ばしましょう！"
        } else {
            personalizedMessage = "\(dataType.displayName)の記録をお忘れなく 📝"
        }
        
        return NotificationContent(
            type: .dataReminder,
            title: "健康記録のお時間です",
            body: personalizedMessage,
            badge: 1,
            data: [
                "dataType": dataType.rawValue,
                "streak": String(streak),
                "personalized": "true"
            ]
        )
    }
    
    /// 条件ベースリマインダーコンテンツを作成
    func createConditionalReminderContent(
        dataType: HealthDataType,
        condition: ReminderCondition
    ) -> NotificationContent {
        let title: String
        let body: String
        
        switch condition {
        case .streakEndanger:
            title = "ストリークが途切れそうです！"
            body = "\(dataType.displayName)の記録を忘れずに。連続記録を維持しましょう！"
            
        case .weeklyGoalProgress:
            title = "今週の目標進捗確認"
            body = "\(dataType.displayName)の今週の記録状況を確認してみましょう。"
            
        case .unusualPattern:
            title = "いつもと違うパターンを検知"
            body = "\(dataType.displayName)の記録パターンに変化がありました。確認してみませんか？"
            
        case .motivationalBoost:
            title = "頑張っているあなたへ 🌟"
            body = "\(dataType.displayName)の継続記録、素晴らしいです！今日も一歩前進しましょう。"
        }
        
        return NotificationContent(
            type: .dataReminder,
            title: title,
            body: body,
            badge: 1,
            sound: condition.soundName,
            data: [
                "dataType": dataType.rawValue,
                "condition": condition.rawValue,
                "conditional": "true"
            ]
        )
    }
    
    /// パーソナライズドリマインダーをスケジュール
    func schedulePersonalizedReminder(
        habit: UserHabit,
        times: [Date],
        content: NotificationContent
    ) async throws {
        for time in times {
            _ = try await notificationService.scheduleNotification(
                content,
                at: time,
                repeating: habit.frequency != .disabled
            )
        }
    }
    
    /// 記録成功率を計算
    func calculateRecordingSuccessRate(for dataType: HealthDataType) async -> Double {
        // TODO: 実際の実装では、過去30日のデータから計算
        // 現在はダミーデータを返す
        return Double.random(in: 0.3...0.95)
    }
    
    /// リマインダー頻度を増やす
    func increasReminderFrequency(for habit: UserHabit) async -> [Date] {
        let currentTimes = habit.preferredTimes
        let additionalTimes = getAdditionalReminderTimes(for: habit.dataType)
        return currentTimes + additionalTimes
    }
    
    /// リマインダー頻度を減らす
    func decreaseReminderFrequency(for habit: UserHabit) async -> [Date] {
        let currentTimes = habit.preferredTimes
        return currentTimes.count > 1 ? Array(currentTimes.dropLast()) : currentTimes
    }
    
    /// 追加のリマインダー時間を取得
    func getAdditionalReminderTimes(for dataType: HealthDataType) -> [Date] {
        let calendar = Calendar.current
        let now = Date()
        
        switch dataType {
        case .weight:
            return [calendar.date(bySettingHour: 19, minute: 0, second: 0, of: now) ?? now]
        case .steps:
            return [calendar.date(bySettingHour: 17, minute: 0, second: 0, of: now) ?? now]
        case .calories:
            return [calendar.date(bySettingHour: 16, minute: 0, second: 0, of: now) ?? now]
        case .heartRate:
            return [calendar.date(bySettingHour: 15, minute: 0, second: 0, of: now) ?? now]
        case .bloodGlucose:
            return [calendar.date(bySettingHour: 14, minute: 0, second: 0, of: now) ?? now]
        }
    }
}

// MARK: - Supporting Types

/// リマインダー条件
public enum ReminderCondition: String, CaseIterable {
    case streakEndanger = "streak_endanger"           // ストリーク危険
    case weeklyGoalProgress = "weekly_goal_progress"  // 週次目標進捗
    case unusualPattern = "unusual_pattern"           // 異常パターン
    case motivationalBoost = "motivational_boost"     // モチベーション向上
    
    var shouldRepeat: Bool {
        switch self {
        case .streakEndanger:
            return false  // 一回限り
        case .weeklyGoalProgress:
            return true   // 週次
        case .unusualPattern:
            return false  // 一回限り
        case .motivationalBoost:
            return false  // 一回限り
        }
    }
    
    var soundName: String {
        switch self {
        case .streakEndanger:
            return "streak_alert.wav"
        case .weeklyGoalProgress:
            return "progress_check.wav"
        case .unusualPattern:
            return "pattern_alert.wav"
        case .motivationalBoost:
            return "motivation_boost.wav"
        }
    }
}

// MARK: - Extensions

private extension Date {
    var ISO8601String: String {
        return ISO8601DateFormatter().string(from: self)
    }
}