import Foundation

// MARK: - ヘルスケア特化通知機能の拡張実装

extension NotificationService {
    
    // MARK: - データ記録リマインダー
    
    public func scheduleDataReminder(
        for dataType: HealthDataType,
        at times: [Date],
        frequency: NotificationScheduleFrequency
    ) async throws {
        logger.info("データ記録リマインダースケジュール", context: [
            "dataType": dataType.rawValue,
            "frequency": frequency.rawValue,
            "timesCount": times.count
        ])
        
        // 既存のリマインダーをキャンセル
        await cancelDataReminders(for: dataType)
        
        for time in times {
            let content = await createDataReminderContent(for: dataType)
            
            switch frequency {
            case .disabled:
                continue
                
            case .daily:
                _ = try await scheduleNotification(content, at: time, repeating: true)
                
            case .weekly:
                _ = try await scheduleWeeklyNotification(content, at: time)
                
            case .monthly:
                _ = try await scheduleMonthlyNotification(content, at: time)
                
            case .custom:
                // カスタム頻度は設定から取得
                if let settings = await getNotificationSettings(for: .dataReminder),
                   let customDays = settings.customDays {
                    for dayOfWeek in customDays {
                        _ = try await scheduleCustomNotification(content, at: time, dayOfWeek: dayOfWeek)
                    }
                }
            }
        }
    }
    
    // MARK: - 目標達成通知
    
    public func sendGoalAchievementNotification(
        goalType: HealthDataType,
        value: Double,
        streakDays: Int? = nil
    ) async throws {
        logger.info("目標達成通知送信", context: [
            "goalType": goalType.rawValue,
            "value": value,
            "streakDays": streakDays ?? 0
        ])
        
        let content = NotificationTemplate.goalAchievement(goalType: goalType, value: value)
        
        // ストリーク情報があれば追加
        var enhancedContent = content
        if let streak = streakDays, streak > 0 {
            enhancedContent = NotificationContent(
                id: content.id,
                type: content.type,
                title: content.title,
                body: content.body + " \(streak)日連続達成中！",
                badge: content.badge,
                sound: content.sound,
                data: content.data.merging([
                    "streakDays": String(streak),
                    "achievementLevel": getAchievementLevel(for: streak)
                ]) { _, new in new }
            )
        }
        
        try await sendImmediateNotification(enhancedContent)
        
        // 目標達成統計を更新
        await recordGoalAchievement(goalType: goalType, value: value, streakDays: streakDays)
    }
    
    // MARK: - ストリークマイルストーン通知
    
    public func sendStreakMilestoneNotification(
        streak: Int,
        dataType: HealthDataType? = nil
    ) async throws {
        guard isSignificantStreak(streak) else {
            logger.debug("重要でないストリークのため通知スキップ", context: [
                "streak": streak
            ])
            return
        }
        
        logger.info("ストリークマイルストーン通知送信", context: [
            "streak": streak,
            "dataType": dataType?.rawValue ?? "all"
        ])
        
        let content = NotificationTemplate.streakMilestone(streak: streak, dataType: dataType)
        let enhancedContent = await enhanceStreakContent(content, streak: streak, dataType: dataType)
        
        try await sendImmediateNotification(enhancedContent)
        
        // ストリーク統計を更新
        await recordStreakMilestone(streak: streak, dataType: dataType)
    }
    
    // MARK: - 週次インサイト通知
    
    public func scheduleWeeklyInsight(
        summary: String,
        dayOfWeek: Int = 1, // デフォルト: 日曜日
        time: Date
    ) async throws {
        logger.info("週次インサイト通知スケジュール", context: [
            "dayOfWeek": dayOfWeek,
            "summaryLength": summary.count
        ])
        
        let content = NotificationTemplate.weeklyInsight(summary: summary)
        
        // 毎週指定された曜日・時間に配信
        let calendar = Calendar.current
        var components = calendar.dateComponents([.hour, .minute], from: time)
        components.weekday = dayOfWeek
        
        let enhancedContent = await enhanceInsightContent(content)
        _ = try await scheduleNotification(enhancedContent, at: time, repeating: true)
    }
    
    // MARK: - 健康アラート
    
    public func sendHealthAlert(
        message: String,
        severity: String = "normal",
        immediate: Bool = true
    ) async throws {
        logger.warning("健康アラート送信", context: [
            "severity": severity,
            "immediate": immediate,
            "messageLength": message.count
        ])
        
        let content = NotificationTemplate.healthAlert(message: message, severity: severity)
        let enhancedContent = await enhanceAlertContent(content, severity: severity)
        
        if immediate {
            try await sendImmediateNotification(enhancedContent)
        } else {
            // 次の適切な時間（30分後）にスケジュール
            let scheduledTime = Date().addingTimeInterval(1800) // 30分後
            _ = try await scheduleNotification(enhancedContent, at: scheduledTime, repeating: false)
        }
        
        // 緊急度が高い場合は追加のアクションを実行
        if severity == "urgent" {
            await handleUrgentAlert(message: message)
        }
    }
}

// MARK: - Private Helper Methods

private extension NotificationService {
    
    func createDataReminderContent(for dataType: HealthDataType) async -> NotificationContent {
        // ユーザーの現在のストリークを取得（実装時に実際のデータソースから取得）
        let currentStreak = await getCurrentStreak(for: dataType)
        
        return NotificationTemplate.dataReminder(dataType: dataType, streak: currentStreak)
    }
    
    func getCurrentStreak(for dataType: HealthDataType) async -> Int {
        // TODO: 実際のデータソースからストリークを取得
        // 現在はダミーデータを返す
        return Int.random(in: 0...30)
    }
    
    func cancelDataReminders(for dataType: HealthDataType) async {
        let pending = await getPendingNotifications()
        let remindersToCancel = pending.filter { notification in
            guard notification.type == .dataReminder else { return false }
            return notification.content.data["dataType"] == dataType.rawValue
        }
        
        for reminder in remindersToCancel {
            await cancelNotification(withId: reminder.id)
        }
    }
    
    func getAchievementLevel(for streak: Int) -> String {
        switch streak {
        case 1...7:
            return "beginner"
        case 8...30:
            return "intermediate"
        case 31...90:
            return "advanced"
        case 91...365:
            return "expert"
        default:
            return "master"
        }
    }
    
    func isSignificantStreak(_ streak: Int) -> Bool {
        // 重要なマイルストーンの判定
        let milestones = [3, 7, 14, 21, 30, 50, 100, 200, 365]
        return milestones.contains(streak)
    }
    
    func enhanceStreakContent(_ content: NotificationContent, streak: Int, dataType: HealthDataType?) async -> NotificationContent {
        var enhancedBody = content.body
        var enhancedData = content.data
        
        // ストリークレベルに応じた励ましのメッセージを追加
        let encouragement = getEncouragementMessage(for: streak)
        if !encouragement.isEmpty {
            enhancedBody += " " + encouragement
        }
        
        // バッジレベルの追加情報
        enhancedData["encouragement"] = encouragement
        enhancedData["milestoneLevel"] = getMilestoneLevel(for: streak)
        
        return NotificationContent(
            id: content.id,
            type: content.type,
            title: content.title,
            body: enhancedBody,
            badge: content.badge,
            sound: content.sound,
            data: enhancedData,
            createdAt: content.createdAt
        )
    }
    
    func enhanceInsightContent(_ content: NotificationContent) async -> NotificationContent {
        var enhancedData = content.data
        
        // 週次統計を追加
        let weeklyStats = await getWeeklyStats()
        enhancedData["weeklyDataPoints"] = String(weeklyStats.totalDataPoints)
        enhancedData["weeklyGoalsAchieved"] = String(weeklyStats.goalsAchieved)
        enhancedData["weeklyStreak"] = String(weeklyStats.longestStreak)
        
        return NotificationContent(
            id: content.id,
            type: content.type,
            title: content.title,
            body: content.body,
            badge: content.badge,
            sound: content.sound,
            data: enhancedData,
            createdAt: content.createdAt
        )
    }
    
    func enhanceAlertContent(_ content: NotificationContent, severity: String) async -> NotificationContent {
        var enhancedData = content.data
        
        enhancedData["alertLevel"] = severity
        enhancedData["timestamp"] = Date().ISO8601String
        enhancedData["requiresAction"] = severity == "urgent" ? "true" : "false"
        
        // 緊急度に応じてサウンドを調整
        let sound: String? = switch severity {
        case "urgent":
            "urgent_alert.wav"
        case "warning":
            "warning_alert.wav"
        default:
            nil
        }
        
        return NotificationContent(
            id: content.id,
            type: content.type,
            title: content.title,
            body: content.body,
            badge: content.badge,
            sound: sound ?? content.sound,
            data: enhancedData,
            createdAt: content.createdAt
        )
    }
    
    func getEncouragementMessage(for streak: Int) -> String {
        switch streak {
        case 3:
            return "良いスタートです！"
        case 7:
            return "1週間継続、素晴らしい！"
        case 14:
            return "2週間継続、習慣になってきましたね！"
        case 21:
            return "3週間継続、もう立派な習慣です！"
        case 30:
            return "1ヶ月継続、驚異的な継続力です！"
        case 50:
            return "50日継続、あなたは健康管理の達人です！"
        case 100:
            return "100日継続達成！これは本当に素晴らしい偉業です！"
        case 365:
            return "1年間継続！あなたの健康への献身は本当に感動的です！"
        default:
            return ""
        }
    }
    
    func getMilestoneLevel(for streak: Int) -> String {
        switch streak {
        case 1...6:
            return "bronze"
        case 7...20:
            return "silver"
        case 21...49:
            return "gold"
        case 50...99:
            return "platinum"
        case 100...:
            return "diamond"
        default:
            return "none"
        }
    }
    
    func handleUrgentAlert(message: String) async {
        logger.warning("緊急アラートハンドリング", context: [
            "message": message
        ])
        
        // 緊急アラートの場合の追加アクション
        // 1. 複数の通知チャンネルで送信
        // 2. バッジカウントを増やす
        // 3. より目立つサウンドを使用
        // 4. 必要に応じて連絡先への通知（将来実装）
        
        // 5分後に再通知をスケジュール（未確認の場合）
        let followUpContent = NotificationContent(
            type: .healthAlert,
            title: "重要：健康アラートの確認",
            body: "先ほどの健康アラートをご確認ください：\(message)",
            badge: 2,
            sound: "urgent_followup.wav",
            data: [
                "isFollowUp": "true",
                "originalMessage": message
            ]
        )
        
        let followUpTime = Date().addingTimeInterval(300) // 5分後
        _ = try? await scheduleNotification(followUpContent, at: followUpTime, repeating: false)
    }
    
    func recordGoalAchievement(goalType: HealthDataType, value: Double, streakDays: Int?) async {
        var achievements = userDefaults.array(forKey: "goal_achievements") as? [[String: Any]] ?? []
        
        let achievement: [String: Any] = [
            "goalType": goalType.rawValue,
            "value": value,
            "streakDays": streakDays ?? 0,
            "achievedAt": Date().timeIntervalSince1970,
            "notificationSent": true
        ]
        
        achievements.append(achievement)
        
        // 最新500件のみ保持
        if achievements.count > 500 {
            achievements = Array(achievements.suffix(500))
        }
        
        userDefaults.set(achievements, forKey: "goal_achievements")
    }
    
    func recordStreakMilestone(streak: Int, dataType: HealthDataType?) async {
        var milestones = userDefaults.array(forKey: "streak_milestones") as? [[String: Any]] ?? []
        
        let milestone: [String: Any] = [
            "streak": streak,
            "dataType": dataType?.rawValue ?? "all",
            "achievedAt": Date().timeIntervalSince1970,
            "level": getMilestoneLevel(for: streak),
            "notificationSent": true
        ]
        
        milestones.append(milestone)
        
        // 最新200件のみ保持
        if milestones.count > 200 {
            milestones = Array(milestones.suffix(200))
        }
        
        userDefaults.set(milestones, forKey: "streak_milestones")
    }
    
    func getWeeklyStats() async -> WeeklyStats {
        // TODO: 実際のデータソースから週次統計を取得
        // 現在はダミーデータを返す
        return WeeklyStats(
            totalDataPoints: Int.random(in: 15...50),
            goalsAchieved: Int.random(in: 0...7),
            longestStreak: Int.random(in: 3...14)
        )
    }
}

// MARK: - Supporting Types

private struct WeeklyStats {
    let totalDataPoints: Int
    let goalsAchieved: Int
    let longestStreak: Int
}