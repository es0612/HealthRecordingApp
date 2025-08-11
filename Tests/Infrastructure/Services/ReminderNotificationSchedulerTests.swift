import Testing
import Foundation
@testable import HealthRecordingApp

/// ReminderNotificationScheduler TDDテストスイート
@Suite("ReminderNotificationScheduler Tests")
struct ReminderNotificationSchedulerTests {
    
    // MARK: - Test Data
    
    private let mockLogger = MockAILogger()
    private let mockNotificationService = MockNotificationService()
    
    // MARK: - Initialization Tests
    
    @Test("ReminderScheduler初期化テスト")
    func testReminderSchedulerInitialization() async throws {
        // Given: 初期化パラメータ
        let logger = mockLogger
        let notificationService = mockNotificationService
        
        // When: ReminderSchedulerを初期化
        let scheduler = await ReminderNotificationScheduler(
            notificationService: notificationService,
            logger: logger
        )
        
        // Then: 正常に初期化されること
        #expect(scheduler != nil)
    }
    
    // MARK: - Default Reminders Setup Tests
    
    @Test("標準リマインダーセットアップテスト")
    func testSetupDefaultReminders() async throws {
        // Given: ReminderScheduler
        let scheduler = await createReminderScheduler()
        
        // When: 標準リマインダーをセットアップ
        try await scheduler.setupDefaultReminders()
        
        // Then: 全データタイプでリマインダーがスケジュールされること
        let scheduledReminders = mockNotificationService.scheduledReminders
        #expect(scheduledReminders.count > 0)
        
        // And: ログが記録されること
        #expect(mockLogger.loggedMessages.contains { $0.contains("標準リマインダーセットアップ開始") })
        #expect(mockLogger.loggedMessages.contains { $0.contains("標準リマインダーセットアップ完了") })
    }
    
    @Test("データタイプ別最適時間テスト")
    func testOptimalTimesForDataTypes() async throws {
        // Given: 各データタイプ
        let testCases = [
            (HealthDataType.weight, 1),      // 体重: 朝1回
            (HealthDataType.steps, 2),       // 歩数: 日中・夜2回
            (HealthDataType.calories, 3),    // カロリー: 食事時間3回
            (HealthDataType.heartRate, 2),   // 心拍数: 朝・夜2回
            (HealthDataType.bloodGlucose, 3) // 血糖値: 食前3回
        ]
        
        // When/Then: 各データタイプの最適時間を検証
        for (dataType, expectedCount) in testCases {
            // この実装では最適時間を直接テストできないため、
            // リマインダー設定を通して間接的にテスト
            let scheduler = await createReminderScheduler()
            let testTimes = createTestTimes(count: expectedCount)
            
            try await scheduler.scheduleDataTypeReminder(
                dataType: dataType,
                times: testTimes,
                frequency: .daily
            )
            
            // 適切にスケジュールされることを確認
            #expect(mockNotificationService.scheduledReminders.count > 0)
            
            // 次のテストのためにリセット
            mockNotificationService.reset()
        }
    }
    
    // MARK: - Data Type Reminder Tests
    
    @Test("データタイプリマインダースケジュールテスト")
    func testScheduleDataTypeReminder() async throws {
        // Given: ReminderSchedulerとテストパラメータ
        let scheduler = await createReminderScheduler()
        let dataType = HealthDataType.weight
        let reminderTimes = createTestTimes(count: 1)
        let frequency = NotificationScheduleFrequency.daily
        let customMessage = "体重測定の時間です！"
        
        // When: データタイプリマインダーをスケジュール
        try await scheduler.scheduleDataTypeReminder(
            dataType: dataType,
            times: reminderTimes,
            frequency: frequency,
            customMessage: customMessage
        )
        
        // Then: リマインダーがスケジュールされること
        #expect(mockNotificationService.scheduledReminders.count > 0)
        
        // And: ログが記録されること
        #expect(mockLogger.loggedMessages.contains { $0.contains("データタイプリマインダースケジュール") })
    }
    
    @Test("リマインダー頻度別スケジュールテスト")
    func testReminderFrequencyScheduling() async throws {
        // Given: ReminderSchedulerと各頻度設定
        let scheduler = await createReminderScheduler()
        let dataType = HealthDataType.steps
        let reminderTimes = createTestTimes(count: 2)
        
        let frequencies: [NotificationScheduleFrequency] = [
            .daily, .weekly, .monthly, .custom, .disabled
        ]
        
        // When/Then: 各頻度でスケジュール
        for frequency in frequencies {
            mockNotificationService.reset()
            
            try await scheduler.scheduleDataTypeReminder(
                dataType: dataType,
                times: reminderTimes,
                frequency: frequency
            )
            
            if frequency == .disabled {
                // 無効な場合はスケジュールされないこと
                #expect(mockNotificationService.scheduledReminders.isEmpty)
            } else {
                // その他の場合はスケジュールされること
                #expect(mockNotificationService.scheduledReminders.count > 0)
            }
        }
    }
    
    @Test("リマインダーキャンセルテスト")
    func testCancelDataTypeReminder() async throws {
        // Given: ReminderSchedulerとスケジュール済みリマインダー
        let scheduler = await createReminderScheduler()
        let dataType = HealthDataType.calories
        
        // 先にリマインダーをスケジュール
        try await scheduler.scheduleDataTypeReminder(
            dataType: dataType,
            times: createTestTimes(count: 1),
            frequency: .daily
        )
        
        #expect(mockNotificationService.scheduledReminders.count > 0)
        
        // When: リマインダーをキャンセル
        try await scheduler.cancelDataTypeReminder(for: dataType)
        
        // Then: キャンセル操作が呼ばれること
        #expect(mockNotificationService.cancelledNotifications.count > 0)
        
        // And: ログが記録されること
        #expect(mockLogger.loggedMessages.contains { $0.contains("データタイプリマインダーキャンセル") })
    }
    
    // MARK: - Intelligent Reminders Tests
    
    @Test("インテリジェント・リマインダーテスト")
    func testScheduleIntelligentReminders() async throws {
        // Given: ReminderScheduler
        let scheduler = await createReminderScheduler()
        
        // When: インテリジェント・リマインダーをスケジュール
        try await scheduler.scheduleIntelligentReminders()
        
        // Then: ユーザー習慣に基づいてリマインダーがスケジュールされること
        #expect(mockNotificationService.scheduledReminders.count > 0)
        
        // And: ログが記録されること
        #expect(mockLogger.loggedMessages.contains { $0.contains("インテリジェント・リマインダースケジュール開始") })
        #expect(mockLogger.loggedMessages.contains { $0.contains("インテリジェント・リマインダースケジュール完了") })
    }
    
    @Test("アダプティブ・リマインダー調整テスト")
    func testAdjustRemindersBasedOnSuccessRate() async throws {
        // Given: ReminderScheduler
        let scheduler = await createReminderScheduler()
        
        // When: アダプティブ調整を実行
        try await scheduler.adjustRemindersBasedOnSuccessRate()
        
        // Then: 成功率に基づいて調整が実行されること
        #expect(mockLogger.loggedMessages.contains { $0.contains("アダプティブ・リマインダー調整開始") })
        #expect(mockLogger.loggedMessages.contains { $0.contains("アダプティブ・リマインダー調整完了") })
    }
    
    // MARK: - Conditional Reminder Tests
    
    @Test("条件ベース・リマインダーテスト")
    func testScheduleConditionalReminder() async throws {
        // Given: ReminderSchedulerと条件パラメータ
        let scheduler = await createReminderScheduler()
        let dataType = HealthDataType.weight
        let condition = ReminderCondition.streakEndanger
        let triggerTime = Date().addingTimeInterval(3600) // 1時間後
        
        // When: 条件ベース・リマインダーをスケジュール
        try await scheduler.scheduleConditionalReminder(
            dataType: dataType,
            condition: condition,
            triggerTime: triggerTime
        )
        
        // Then: リマインダーがスケジュールされること
        #expect(mockNotificationService.scheduledReminders.count > 0)
        
        // And: ログが記録されること
        #expect(mockLogger.loggedMessages.contains { $0.contains("条件ベースリマインダースケジュール") })
    }
    
    @Test("リマインダー条件タイプテスト")
    func testReminderConditionTypes() async throws {
        // Given: ReminderSchedulerと全条件タイプ
        let scheduler = await createReminderScheduler()
        let dataType = HealthDataType.steps
        let triggerTime = Date().addingTimeInterval(3600)
        
        // When/Then: 各条件タイプでスケジュール
        for condition in ReminderCondition.allCases {
            mockNotificationService.reset()
            
            try await scheduler.scheduleConditionalReminder(
                dataType: dataType,
                condition: condition,
                triggerTime: triggerTime
            )
            
            // リマインダーがスケジュールされること
            #expect(mockNotificationService.scheduledReminders.count > 0)
            
            // 繰り返し設定が条件に応じて設定されること
            let scheduledReminder = mockNotificationService.scheduledReminders.first!
            #expect(scheduledReminder.isRepeating == condition.shouldRepeat)
        }
    }
    
    // MARK: - Edge Cases and Error Handling Tests
    
    @Test("空の時間リストでのスケジュールテスト")
    func testScheduleWithEmptyTimes() async throws {
        // Given: ReminderSchedulerと空の時間リスト
        let scheduler = await createReminderScheduler()
        let dataType = HealthDataType.heartRate
        let emptyTimes: [Date] = []
        
        // When: 空の時間リストでスケジュール
        try await scheduler.scheduleDataTypeReminder(
            dataType: dataType,
            times: emptyTimes,
            frequency: .daily
        )
        
        // Then: エラーなく完了すること（内部でデフォルト時間が使用される可能性）
        // 実装によってはスケジュールされない場合もある
    }
    
    @Test("過去の時間でのスケジュールテスト")
    func testScheduleWithPastTime() async throws {
        // Given: ReminderSchedulerと過去の時間
        let scheduler = await createReminderScheduler()
        let dataType = HealthDataType.bloodGlucose
        let pastTimes = [Date().addingTimeInterval(-3600)] // 1時間前
        
        // When: 過去の時間でスケジュール
        try await scheduler.scheduleDataTypeReminder(
            dataType: dataType,
            times: pastTimes,
            frequency: .daily
        )
        
        // Then: 内部でNotificationServiceが適切にハンドリングすること
        // （実装によってはエラーが発生する可能性もある）
    }
    
    // MARK: - Performance Tests
    
    @Test("大量リマインダー処理パフォーマンステスト")
    func testBulkReminderPerformance() async throws {
        // Given: ReminderSchedulerと大量のリマインダー
        let scheduler = await createReminderScheduler()
        let startTime = Date()
        
        // When: 大量のリマインダーを一度にスケジュール
        for dataType in HealthDataType.allCases {
            for _ in 0..<5 { // 各データタイプで5回
                try await scheduler.scheduleDataTypeReminder(
                    dataType: dataType,
                    times: createTestTimes(count: 2),
                    frequency: .daily
                )
            }
        }
        
        // Then: 合理的な時間内で完了すること
        let processingTime = Date().timeIntervalSince(startTime)
        #expect(processingTime < 5.0) // 5秒以内
        
        // And: 適切にスケジュールされること
        #expect(mockNotificationService.scheduledReminders.count > 0)
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func createReminderScheduler() -> ReminderNotificationScheduler {
        return ReminderNotificationScheduler(
            notificationService: mockNotificationService,
            logger: mockLogger
        )
    }
    
    private func createTestTimes(count: Int) -> [Date] {
        let calendar = Calendar.current
        let now = Date()
        
        return (0..<count).compactMap { index in
            calendar.date(bySettingHour: 8 + index * 4, minute: 0, second: 0, of: now)
        }
    }
}

// MARK: - Mock NotificationService for Testing

class MockNotificationService: NotificationServiceProtocol {
    
    // MARK: - Mock State
    
    var scheduledReminders: [ScheduledNotification] = []
    var cancelledNotifications: [String] = []
    var authorizationStatus: NotificationAuthorizationStatus = .authorized
    var notificationSettings: [NotificationSettings] = []
    
    // MARK: - Authorization Methods
    
    func getAuthorizationStatus() async -> NotificationAuthorizationStatus {
        return authorizationStatus
    }
    
    func requestAuthorization() async throws -> Bool {
        authorizationStatus = .authorized
        return true
    }
    
    func promptForSettings() async {
        // Mock implementation
    }
    
    // MARK: - Settings Methods
    
    func getNotificationSettings() async -> [NotificationSettings] {
        return notificationSettings
    }
    
    func getNotificationSettings(for type: AppNotificationType) async -> NotificationSettings? {
        return notificationSettings.first { $0.type == type }
    }
    
    func updateNotificationSettings(_ settings: NotificationSettings) async throws {
        if let index = notificationSettings.firstIndex(where: { $0.type == settings.type }) {
            notificationSettings[index] = settings
        } else {
            notificationSettings.append(settings)
        }
    }
    
    func resetNotificationSettings() async throws {
        notificationSettings.removeAll()
    }
    
    // MARK: - Scheduling Methods
    
    func sendImmediateNotification(_ content: NotificationContent) async throws {
        let notification = ScheduledNotification(
            id: UUID().uuidString,
            type: content.type,
            content: content,
            scheduledDate: Date(),
            isRepeating: false
        )
        scheduledReminders.append(notification)
    }
    
    func scheduleNotification(_ content: NotificationContent, at date: Date, repeating: Bool) async throws -> String {
        let id = UUID().uuidString
        let notification = ScheduledNotification(
            id: id,
            type: content.type,
            content: content,
            scheduledDate: date,
            isRepeating: repeating
        )
        scheduledReminders.append(notification)
        return id
    }
    
    func scheduleRecurringNotification(for settings: NotificationSettings) async throws -> [String] {
        var ids: [String] = []
        
        for _ in settings.scheduledTimes {
            let id = UUID().uuidString
            let content = NotificationContent(type: settings.type, title: "Test", body: "Test", badge: 1)
            let notification = ScheduledNotification(
                id: id,
                type: settings.type,
                content: content,
                scheduledDate: Date(),
                isRepeating: settings.frequency != .disabled
            )
            scheduledReminders.append(notification)
            ids.append(id)
        }
        
        return ids
    }
    
    func cancelNotification(withId id: String) async {
        scheduledReminders.removeAll { $0.id == id }
        cancelledNotifications.append(id)
    }
    
    func cancelNotifications(ofType type: AppNotificationType) async {
        let toCancel = scheduledReminders.filter { $0.type == type }
        scheduledReminders.removeAll { $0.type == type }
        cancelledNotifications.append(contentsOf: toCancel.map(\.id))
    }
    
    func cancelAllNotifications() async {
        cancelledNotifications.append(contentsOf: scheduledReminders.map(\.id))
        scheduledReminders.removeAll()
    }
    
    // MARK: - Management Methods
    
    func getPendingNotifications() async -> [ScheduledNotification] {
        return scheduledReminders
    }
    
    func getDeliveredNotifications() async -> [UNNotification] {
        return [] // Mock implementation
    }
    
    func clearDeliveredNotifications() async {
        // Mock implementation
    }
    
    func clearDeliveredNotifications(ofType type: AppNotificationType) async {
        // Mock implementation
    }
    
    // MARK: - Statistics Methods
    
    func getNotificationStats() async -> NotificationStats {
        return NotificationStats(
            totalSent: scheduledReminders.count,
            totalDelivered: scheduledReminders.count,
            totalOpened: 0,
            typeBreakdown: [:],
            recentActivity: []
        )
    }
    
    func recordNotificationEngagement(_ notificationId: String) async {
        // Mock implementation
    }
    
    // MARK: - Health-specific Methods
    
    func scheduleDataReminder(for dataType: HealthDataType, at times: [Date], frequency: NotificationScheduleFrequency) async throws {
        for time in times {
            let content = NotificationContent(
                type: .dataReminder,
                title: "Data Reminder",
                body: "記録してください: \(dataType.displayName)",
                badge: 1,
                data: ["dataType": dataType.rawValue]
            )
            
            _ = try await scheduleNotification(content, at: time, repeating: frequency != .disabled)
        }
    }
    
    func sendGoalAchievementNotification(goalType: HealthDataType, value: Double, streakDays: Int?) async throws {
        let content = NotificationContent(
            type: .goalAchievement,
            title: "目標達成！",
            body: "\(goalType.displayName): \(value)\(goalType.unit)",
            badge: 1
        )
        try await sendImmediateNotification(content)
    }
    
    func sendStreakMilestoneNotification(streak: Int, dataType: HealthDataType?) async throws {
        let content = NotificationContent(
            type: .streakMilestone,
            title: "ストリーク達成！",
            body: "\(streak)日連続記録",
            badge: 1
        )
        try await sendImmediateNotification(content)
    }
    
    func scheduleWeeklyInsight(summary: String, dayOfWeek: Int, time: Date) async throws {
        let content = NotificationContent(
            type: .weeklyInsight,
            title: "週次レポート",
            body: summary,
            badge: 1
        )
        _ = try await scheduleNotification(content, at: time, repeating: true)
    }
    
    func sendHealthAlert(message: String, severity: String, immediate: Bool) async throws {
        let content = NotificationContent(
            type: .healthAlert,
            title: "健康アラート",
            body: message,
            badge: 1
        )
        
        if immediate {
            try await sendImmediateNotification(content)
        } else {
            let futureTime = Date().addingTimeInterval(1800)
            _ = try await scheduleNotification(content, at: futureTime, repeating: false)
        }
    }
    
    // MARK: - Mock Control Methods
    
    func reset() {
        scheduledReminders.removeAll()
        cancelledNotifications.removeAll()
        notificationSettings.removeAll()
        authorizationStatus = .authorized
    }
}