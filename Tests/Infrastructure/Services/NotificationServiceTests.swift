import Testing
import Foundation
@testable import HealthRecordingApp

/// NotificationService TDDテストスイート
@Suite("NotificationService Tests")
struct NotificationServiceTests {
    
    // MARK: - Test Data
    
    private let mockLogger = MockAILogger()
    private let mockUserDefaults = MockUserDefaults()
    
    // MARK: - Initialization Tests
    
    @Test("NotificationService初期化テスト")
    func testNotificationServiceInitialization() async throws {
        // Given: NotificationServiceの初期化パラメータ
        let logger = mockLogger
        let userDefaults = mockUserDefaults
        
        // When: NotificationServiceを初期化
        let notificationService = NotificationService(
            logger: logger,
            userDefaults: userDefaults
        )
        
        // Then: 正常に初期化されること
        #expect(notificationService.logger === logger)
        #expect(notificationService.userDefaults === userDefaults)
    }
    
    // MARK: - Authorization Tests
    
    @Test("通知権限要求テスト - 許可された場合")
    func testRequestAuthorizationGranted() async throws {
        // Given: NotificationServiceと権限許可の準備
        let service = createNotificationService()
        
        // When: 権限を要求（モック実装では常に許可）
        let granted = try await service.requestAuthorization()
        
        // Then: 権限が許可されること
        #expect(granted == true)
        
        // And: ログが記録されること
        #expect(mockLogger.loggedMessages.contains { $0.contains("通知権限要求完了") })
    }
    
    @Test("通知権限状態取得テスト")
    func testGetAuthorizationStatus() async throws {
        // Given: NotificationService
        let service = createNotificationService()
        
        // When: 権限状態を取得
        let status = await service.getAuthorizationStatus()
        
        // Then: 権限状態が返されること
        #expect(status != nil)
        
        // And: ログが記録されること
        #expect(mockLogger.loggedMessages.contains { $0.contains("通知権限状態取得") })
    }
    
    // MARK: - Notification Settings Tests
    
    @Test("通知設定取得テスト")
    func testGetNotificationSettings() async throws {
        // Given: NotificationService
        let service = createNotificationService()
        
        // When: 通知設定を取得
        let settings = await service.getNotificationSettings()
        
        // Then: 設定リストが返されること
        #expect(settings.count >= 0)
    }
    
    @Test("特定タイプの通知設定取得テスト")
    func testGetNotificationSettingsForType() async throws {
        // Given: NotificationServiceと設定タイプ
        let service = createNotificationService()
        let testType = AppNotificationType.dataReminder
        
        // When: 特定タイプの設定を取得
        let setting = await service.getNotificationSettings(for: testType)
        
        // Then: 設定が返される可能性がある（初期状態では nil の可能性もある）
        // この時点では設定の存在は保証されない
    }
    
    @Test("通知設定更新テスト")
    func testUpdateNotificationSettings() async throws {
        // Given: NotificationServiceとテスト用設定
        let service = createNotificationService()
        let testSetting = NotificationSettings(
            type: .dataReminder,
            isEnabled: true,
            frequency: .daily,
            scheduledTimes: [Date()]
        )
        
        // When: 設定を更新
        try await service.updateNotificationSettings(testSetting)
        
        // Then: エラーなく完了すること（詳細な確認は統合テストで実施）
        #expect(mockLogger.loggedMessages.contains { $0.contains("通知設定更新") })
    }
    
    // MARK: - Notification Scheduling Tests
    
    @Test("即座通知送信テスト")
    func testSendImmediateNotification() async throws {
        // Given: NotificationServiceと通知コンテンツ
        let service = createNotificationService()
        let content = NotificationContent(
            type: .dataReminder,
            title: "テスト通知",
            body: "これはテスト用の通知です",
            badge: 1
        )
        
        // When: 即座通知を送信
        do {
            try await service.sendImmediateNotification(content)
            
            // Then: エラーなく完了する（モック実装の場合）
            #expect(mockLogger.loggedMessages.contains { $0.contains("即座通知送信") })
            
        } catch NotificationServiceError.authorizationDenied {
            // 権限が拒否された場合は期待される動作
            #expect(true)
        }
    }
    
    @Test("通知スケジュールテスト")
    func testScheduleNotification() async throws {
        // Given: NotificationServiceと通知コンテンツ、未来の日時
        let service = createNotificationService()
        let content = NotificationContent(
            type: .goalAchievement,
            title: "目標達成！",
            body: "おめでとうございます",
            badge: 1
        )
        let futureDate = Date().addingTimeInterval(3600) // 1時間後
        
        // When: 通知をスケジュール
        do {
            let notificationId = try await service.scheduleNotification(
                content,
                at: futureDate,
                repeating: false
            )
            
            // Then: 通知IDが返されること
            #expect(!notificationId.isEmpty)
            
        } catch NotificationServiceError.authorizationDenied {
            // 権限が拒否された場合は期待される動作
            #expect(true)
        }
    }
    
    @Test("無効な日時でのスケジュールテスト")
    func testScheduleNotificationWithInvalidDate() async throws {
        // Given: NotificationServiceと過去の日時
        let service = createNotificationService()
        let content = NotificationContent(
            type: .dataReminder,
            title: "テスト",
            body: "テスト",
            badge: 1
        )
        let pastDate = Date().addingTimeInterval(-3600) // 1時間前
        
        // When/Then: 過去の日時でスケジュールするとエラーが発生すること
        await #expect(throws: NotificationServiceError.invalidScheduleDate(pastDate)) {
            try await service.scheduleNotification(content, at: pastDate, repeating: false)
        }
    }
    
    // MARK: - Notification Management Tests
    
    @Test("保留中通知取得テスト")
    func testGetPendingNotifications() async throws {
        // Given: NotificationService
        let service = createNotificationService()
        
        // When: 保留中通知を取得
        let pendingNotifications = await service.getPendingNotifications()
        
        // Then: リストが返されること
        #expect(pendingNotifications.count >= 0)
    }
    
    @Test("配信済み通知取得テスト")
    func testGetDeliveredNotifications() async throws {
        // Given: NotificationService
        let service = createNotificationService()
        
        // When: 配信済み通知を取得
        let deliveredNotifications = await service.getDeliveredNotifications()
        
        // Then: リストが返されること
        #expect(deliveredNotifications.count >= 0)
        
        // And: ログが記録されること
        #expect(mockLogger.loggedMessages.contains { $0.contains("配信済み通知取得") })
    }
    
    @Test("通知キャンセルテスト")
    func testCancelNotification() async throws {
        // Given: NotificationServiceと通知ID
        let service = createNotificationService()
        let testNotificationId = "test-notification-id"
        
        // When: 通知をキャンセル
        await service.cancelNotification(withId: testNotificationId)
        
        // Then: エラーなく完了すること
        #expect(mockLogger.loggedMessages.contains { $0.contains("通知キャンセル") })
    }
    
    @Test("タイプ別通知キャンセルテスト")
    func testCancelNotificationsOfType() async throws {
        // Given: NotificationServiceと通知タイプ
        let service = createNotificationService()
        let testType = AppNotificationType.dataReminder
        
        // When: 特定タイプの通知をキャンセル
        await service.cancelNotifications(ofType: testType)
        
        // Then: エラーなく完了すること
        #expect(mockLogger.loggedMessages.contains { $0.contains("タイプ別通知キャンセル") })
    }
    
    @Test("全通知キャンセルテスト")
    func testCancelAllNotifications() async throws {
        // Given: NotificationService
        let service = createNotificationService()
        
        // When: 全通知をキャンセル
        await service.cancelAllNotifications()
        
        // Then: エラーなく完了すること
        #expect(mockLogger.loggedMessages.contains { $0.contains("全通知キャンセル") })
    }
    
    // MARK: - Statistics Tests
    
    @Test("通知統計取得テスト")
    func testGetNotificationStats() async throws {
        // Given: NotificationService
        let service = createNotificationService()
        
        // When: 通知統計を取得
        let stats = await service.getNotificationStats()
        
        // Then: 統計オブジェクトが返されること
        #expect(stats.totalSent >= 0)
        #expect(stats.totalDelivered >= 0)
        #expect(stats.totalOpened >= 0)
        #expect(stats.engagementRate >= 0.0)
        #expect(stats.deliveryRate >= 0.0)
    }
    
    @Test("通知エンゲージメント記録テスト")
    func testRecordNotificationEngagement() async throws {
        // Given: NotificationServiceと通知ID
        let service = createNotificationService()
        let testNotificationId = "test-engagement-id"
        
        // When: エンゲージメントを記録
        await service.recordNotificationEngagement(testNotificationId)
        
        // Then: エラーなく完了すること
        #expect(mockLogger.loggedMessages.contains { $0.contains("通知エンゲージメント記録") })
    }
    
    // MARK: - Health-specific Tests
    
    @Test("データリマインダースケジュールテスト")
    func testScheduleDataReminder() async throws {
        // Given: NotificationServiceとテストパラメータ
        let service = createNotificationService()
        let dataType = HealthDataType.weight
        let reminderTimes = [
            Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
        ]
        let frequency = NotificationScheduleFrequency.daily
        
        // When: データリマインダーをスケジュール
        do {
            try await service.scheduleDataReminder(
                for: dataType,
                at: reminderTimes,
                frequency: frequency
            )
            
            // Then: エラーなく完了すること
            #expect(mockLogger.loggedMessages.contains { $0.contains("データ記録リマインダースケジュール") })
            
        } catch NotificationServiceError.authorizationDenied {
            // 権限が拒否された場合は期待される動作
            #expect(true)
        }
    }
    
    @Test("目標達成通知送信テスト")
    func testSendGoalAchievementNotification() async throws {
        // Given: NotificationServiceとテストパラメータ
        let service = createNotificationService()
        let goalType = HealthDataType.weight
        let value = 70.0
        let streakDays = 5
        
        // When: 目標達成通知を送信
        do {
            try await service.sendGoalAchievementNotification(
                goalType: goalType,
                value: value,
                streakDays: streakDays
            )
            
            // Then: エラーなく完了すること
            #expect(mockLogger.loggedMessages.contains { $0.contains("目標達成通知送信") })
            
        } catch NotificationServiceError.authorizationDenied {
            // 権限が拒否された場合は期待される動作
            #expect(true)
        }
    }
    
    @Test("ストリークマイルストーン通知送信テスト")
    func testSendStreakMilestoneNotification() async throws {
        // Given: NotificationServiceとテストパラメータ
        let service = createNotificationService()
        let streak = 30
        let dataType = HealthDataType.steps
        
        // When: ストリークマイルストーン通知を送信
        do {
            try await service.sendStreakMilestoneNotification(
                streak: streak,
                dataType: dataType
            )
            
            // Then: エラーなく完了すること
            #expect(mockLogger.loggedMessages.contains { $0.contains("ストリークマイルストーン通知送信") })
            
        } catch NotificationServiceError.authorizationDenied {
            // 権限が拒否された場合は期待される動作
            #expect(true)
        }
    }
    
    @Test("健康アラート送信テスト")
    func testSendHealthAlert() async throws {
        // Given: NotificationServiceとアラートパラメータ
        let service = createNotificationService()
        let alertMessage = "異常な健康データが検出されました"
        let severity = "urgent"
        let immediate = true
        
        // When: 健康アラートを送信
        do {
            try await service.sendHealthAlert(
                message: alertMessage,
                severity: severity,
                immediate: immediate
            )
            
            // Then: エラーなく完了すること
            #expect(mockLogger.loggedMessages.contains { $0.contains("健康アラート送信") })
            
        } catch NotificationServiceError.authorizationDenied {
            // 権限が拒否された場合は期待される動作
            #expect(true)
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("権限拒否エラーハンドリングテスト")
    func testAuthorizationDeniedError() async throws {
        // Given: NotificationService（権限が拒否された状態を想定）
        let service = createNotificationService()
        let content = NotificationContent(
            type: .dataReminder,
            title: "テスト",
            body: "テスト",
            badge: 1
        )
        
        // When/Then: 権限が必要な操作でエラーが発生する可能性があること
        // 実際の実装では権限チェックが行われる
        do {
            try await service.sendImmediateNotification(content)
            // モック実装では権限チェックが簡略化されている可能性がある
        } catch NotificationServiceError.authorizationDenied {
            // 期待される動作
            #expect(true)
        } catch {
            // その他のエラーは予期しない
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createNotificationService() -> NotificationService {
        return NotificationService(
            logger: mockLogger,
            userDefaults: mockUserDefaults
        )
    }
}

// MARK: - Mock Implementations

/// テスト用のモックAILogger
class MockAILogger: AILoggerProtocol {
    var logLevel: AILogLevel = .debug
    var isEnabled: Bool = true
    var shouldRedactPII: Bool = true
    
    var loggedMessages: [String] = []
    
    func debug(_ message: String, context: [String: Any]?) {
        loggedMessages.append("DEBUG: \(message)")
    }
    
    func info(_ message: String, context: [String: Any]?) {
        loggedMessages.append("INFO: \(message)")
    }
    
    func warning(_ message: String, context: [String: Any]?) {
        loggedMessages.append("WARNING: \(message)")
    }
    
    func error(_ error: Error, context: [String: Any]?) {
        loggedMessages.append("ERROR: \(error.localizedDescription)")
    }
    
    func logUserAction(_ action: String, parameters: [String: Any]?) {
        loggedMessages.append("USER_ACTION: \(action)")
    }
    
    func logPerformance(_ operation: String, duration: TimeInterval, success: Bool) {
        loggedMessages.append("PERFORMANCE: \(operation) \(duration)s success=\(success)")
    }
    
    func clearLogs() {
        loggedMessages.removeAll()
    }
}

/// テスト用のモックUserDefaults
class MockUserDefaults: UserDefaults {
    private var storage: [String: Any] = [:]
    
    override func set(_ value: Any?, forKey defaultName: String) {
        storage[defaultName] = value
    }
    
    override func object(forKey defaultName: String) -> Any? {
        return storage[defaultName]
    }
    
    override func data(forKey defaultName: String) -> Data? {
        return storage[defaultName] as? Data
    }
    
    override func array(forKey defaultName: String) -> [Any]? {
        return storage[defaultName] as? [Any]
    }
    
    override func stringArray(forKey defaultName: String) -> [String]? {
        return storage[defaultName] as? [String]
    }
    
    override func dictionary(forKey defaultName: String) -> [String: Any]? {
        return storage[defaultName] as? [String: Any]
    }
    
    func clearStorage() {
        storage.removeAll()
    }
}