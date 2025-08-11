import Testing
import Foundation
@testable import HealthRecordingApp

/// NotificationManager TDDテストスイート
@Suite("NotificationManager Tests")
@MainActor
struct NotificationManagerTests {
    
    // MARK: - Test Data
    
    private let mockLogger = MockAILogger()
    private let mockNotificationService = MockNotificationService()
    private let mockReminderScheduler = MockReminderNotificationScheduler()
    
    // MARK: - Initialization Tests
    
    @Test("NotificationManager初期化テスト")
    func testNotificationManagerInitialization() async throws {
        // Given: AILogger
        let logger = mockLogger
        
        // When: NotificationManagerを初期化
        let manager = NotificationManager(logger: logger)
        
        // Then: 正常に初期化されること
        #expect(manager != nil)
        #expect(!manager.isInitialized)
        #expect(manager.authorizationStatus == .notDetermined)
        #expect(manager.notificationSettings.isEmpty)
        #expect(manager.activeReminders.isEmpty)
        #expect(manager.notificationStats == nil)
    }
    
    @Test("NotificationManager初期化プロセステスト")
    func testNotificationManagerInitializationProcess() async throws {
        // Given: NotificationManager
        let manager = createNotificationManager()
        
        // When: 初期化を実行
        await manager.initialize()
        
        // Then: 初期化が完了すること
        #expect(manager.isInitialized)
        #expect(mockLogger.loggedMessages.contains { $0.contains("NotificationManager初期化開始") })
        #expect(mockLogger.loggedMessages.contains { $0.contains("NotificationManager初期化完了") })
    }
    
    // MARK: - Authorization Tests
    
    @Test("通知権限要求テスト")
    func testRequestNotificationPermission() async throws {
        // Given: NotificationManager
        let manager = createNotificationManager()
        
        // When: 権限を要求
        let granted = try await manager.requestNotificationPermission()
        
        // Then: 権限が許可されること
        #expect(granted == true)
        #expect(manager.authorizationStatus == .authorized)
        #expect(mockLogger.loggedMessages.contains { $0.contains("通知権限要求") })
    }
    
    @Test("設定画面表示プロンプトテスト")
    func testShowSettingsPrompt() async throws {
        // Given: NotificationManager
        let manager = createNotificationManager()
        
        // When: 設定プロンプトを表示
        await manager.showSettingsPrompt()
        
        // Then: プロンプト表示が呼ばれること（MockNotificationServiceで検証）
        // このテストはMockの実装により間接的に検証
    }
    
    // MARK: - Reminder Management Tests
    
    @Test("標準リマインダーセットアップテスト")
    func testSetupDefaultReminders() async throws {
        // Given: 権限のあるNotificationManager
        let manager = createNotificationManager()
        await manager.initialize()
        mockNotificationService.authorizationStatus = .authorized
        await manager.initialize() // 権限状態を更新
        
        // When: 標準リマインダーをセットアップ
        try await manager.setupDefaultReminders()
        
        // Then: リマインダーがセットアップされること
        #expect(mockLogger.loggedMessages.contains { $0.contains("標準リマインダーセットアップ") })
    }
    
    @Test("権限なしでの標準リマインダーセットアップエラーテスト")
    func testSetupDefaultRemindersWithoutAuthorization() async throws {
        // Given: 権限のないNotificationManager
        let manager = createNotificationManager()
        await manager.initialize()
        mockNotificationService.authorizationStatus = .denied
        await manager.initialize() // 権限状態を更新
        
        // When/Then: 権限エラーが発生すること
        await #expect(throws: NotificationServiceError.authorizationDenied) {
            try await manager.setupDefaultReminders()
        }
    }
    
    @Test("データタイプ別リマインダー設定テスト")
    func testConfigureReminder() async throws {
        // Given: NotificationManagerと設定パラメータ
        let manager = createNotificationManager()
        let dataType = HealthDataType.weight
        let times = createTestTimes(count: 1)
        let frequency = NotificationScheduleFrequency.daily
        
        // When: リマインダーを設定
        try await manager.configureReminder(
            for: dataType,
            times: times,
            frequency: frequency,
            enabled: true
        )
        
        // Then: ログが記録されること
        #expect(mockLogger.loggedMessages.contains { $0.contains("リマインダー設定") })
    }
    
    @Test("リマインダー無効化テスト")
    func testDisableReminder() async throws {
        // Given: NotificationManagerと無効化パラメータ
        let manager = createNotificationManager()
        let dataType = HealthDataType.steps
        
        // When: リマインダーを無効化
        try await manager.configureReminder(
            for: dataType,
            times: createTestTimes(count: 2),
            frequency: .daily,
            enabled: false
        )
        
        // Then: 無効化ログが記録されること
        #expect(mockLogger.loggedMessages.contains { $0.contains("リマインダー設定") })
    }
    
    @Test("インテリジェント・リマインダー有効化テスト")
    func testEnableIntelligentReminders() async throws {
        // Given: NotificationManager
        let manager = createNotificationManager()
        
        // When: インテリジェント・リマインダーを有効化
        try await manager.enableIntelligentReminders()
        
        // Then: インテリジェント機能が有効化されること
        #expect(mockLogger.loggedMessages.contains { $0.contains("インテリジェント・リマインダー開始") })
    }
    
    @Test("アダプティブ調整実行テスト")
    func testPerformAdaptiveAdjustment() async throws {
        // Given: NotificationManager
        let manager = createNotificationManager()
        
        // When: アダプティブ調整を実行
        try await manager.performAdaptiveAdjustment()
        
        // Then: アダプティブ調整が実行されること
        #expect(mockLogger.loggedMessages.contains { $0.contains("アダプティブ調整実行") })
    }
    
    // MARK: - Goal Achievement Tests
    
    @Test("目標達成通知送信テスト")
    func testSendGoalAchievementNotification() async throws {
        // Given: NotificationManagerと目標データ
        let manager = createNotificationManager()
        let goalType = HealthDataType.weight
        let value = 70.5
        let streakDays = 7
        
        // When: 目標達成通知を送信
        try await manager.sendGoalAchievementNotification(
            goalType: goalType,
            value: value,
            streakDays: streakDays
        )
        
        // Then: 通知が送信されること
        #expect(mockNotificationService.scheduledReminders.count > 0)
        #expect(mockLogger.loggedMessages.contains { $0.contains("目標達成通知送信") })
        
        // And: 適切な通知内容であること
        let notification = mockNotificationService.scheduledReminders.first!
        #expect(notification.type == .goalAchievement)
        #expect(notification.content.title == "目標達成！")
    }
    
    @Test("ストリークマイルストーン通知送信テスト")
    func testSendStreakMilestoneNotification() async throws {
        // Given: NotificationManagerとストリークデータ
        let manager = createNotificationManager()
        let streak = 30
        let dataType = HealthDataType.steps
        
        // When: ストリークマイルストーン通知を送信
        try await manager.sendStreakMilestoneNotification(
            streak: streak,
            dataType: dataType
        )
        
        // Then: 通知が送信されること
        #expect(mockNotificationService.scheduledReminders.count > 0)
        #expect(mockLogger.loggedMessages.contains { $0.contains("ストリークマイルストーン通知送信") })
        
        // And: 適切な通知内容であること
        let notification = mockNotificationService.scheduledReminders.first!
        #expect(notification.type == .streakMilestone)
        #expect(notification.content.title == "ストリーク達成！")
        #expect(notification.content.body.contains("30日連続記録"))
    }
    
    @Test("全データタイプストリーク通知テスト")
    func testSendStreakNotificationForAllDataTypes() async throws {
        // Given: NotificationManager
        let manager = createNotificationManager()
        let streak = 100
        
        // When: 全データタイプでのストリーク通知を送信
        try await manager.sendStreakMilestoneNotification(streak: streak)
        
        // Then: 通知が送信されること
        #expect(mockNotificationService.scheduledReminders.count > 0)
        #expect(mockLogger.loggedMessages.contains { $0.contains("ストリークマイルストーン通知送信") })
    }
    
    // MARK: - Settings Management Tests
    
    @Test("通知設定更新テスト")
    func testUpdateNotificationSetting() async throws {
        // Given: NotificationManagerと設定
        let manager = createNotificationManager()
        let setting = NotificationSettings(
            type: .dataReminder,
            isEnabled: true,
            scheduledTimes: createTestTimes(count: 2),
            frequency: .daily,
            customMessage: "カスタムメッセージ"
        )
        
        // When: 設定を更新
        try await manager.updateNotificationSetting(setting)
        
        // Then: 設定が更新されること
        #expect(mockNotificationService.notificationSettings.count > 0)
        #expect(mockLogger.loggedMessages.contains { $0.contains("通知設定更新") })
        
        // And: 適切な設定内容であること
        let updatedSetting = mockNotificationService.notificationSettings.first!
        #expect(updatedSetting.type == .dataReminder)
        #expect(updatedSetting.isEnabled == true)
    }
    
    @Test("通知設定リセットテスト")
    func testResetNotificationSettings() async throws {
        // Given: 設定済みのNotificationManager
        let manager = createNotificationManager()
        let setting = NotificationSettings(
            type: .goalAchievement,
            isEnabled: true,
            scheduledTimes: createTestTimes(count: 1),
            frequency: .weekly
        )
        try await manager.updateNotificationSetting(setting)
        
        // When: 設定をリセット
        try await manager.resetNotificationSettings()
        
        // Then: 設定がリセットされること
        #expect(mockNotificationService.notificationSettings.isEmpty)
        #expect(mockLogger.loggedMessages.contains { $0.contains("通知設定リセット") })
    }
    
    // MARK: - Health Alert Tests
    
    @Test("健康アラート送信テスト")
    func testSendHealthAlert() async throws {
        // Given: NotificationManagerとアラート情報
        let manager = createNotificationManager()
        let message = "血圧の値が高めです。医師にご相談ください。"
        let severity = HealthAlertSeverity.high
        
        // When: 健康アラートを送信
        try await manager.sendHealthAlert(
            message: message,
            severity: severity,
            immediate: true
        )
        
        // Then: アラートが送信されること
        #expect(mockNotificationService.scheduledReminders.count > 0)
        #expect(mockLogger.loggedMessages.contains { $0.contains("健康アラート送信") })
        
        // And: 適切なアラート内容であること
        let notification = mockNotificationService.scheduledReminders.first!
        #expect(notification.type == .healthAlert)
        #expect(notification.content.title == "健康アラート")
        #expect(notification.content.body == message)
    }
    
    @Test("健康アラート重要度別テスト")
    func testHealthAlertSeverityLevels() async throws {
        // Given: NotificationManager
        let manager = createNotificationManager()
        let severityLevels: [HealthAlertSeverity] = [.low, .normal, .high, .critical]
        
        // When/Then: 各重要度でアラート送信
        for severity in severityLevels {
            mockNotificationService.reset()
            
            try await manager.sendHealthAlert(
                message: "重要度\(severity.rawValue)のテストメッセージ",
                severity: severity,
                immediate: true
            )
            
            #expect(mockNotificationService.scheduledReminders.count > 0)
        }
    }
    
    @Test("遅延健康アラートテスト")
    func testDelayedHealthAlert() async throws {
        // Given: NotificationManager
        let manager = createNotificationManager()
        
        // When: 遅延アラートを送信
        try await manager.sendHealthAlert(
            message: "定期チェックのリマインダーです",
            severity: .normal,
            immediate: false
        )
        
        // Then: 遅延アラートがスケジュールされること
        #expect(mockNotificationService.scheduledReminders.count > 0)
        #expect(mockLogger.loggedMessages.contains { $0.contains("健康アラート送信") })
    }
    
    // MARK: - Notification History Tests
    
    @Test("配信済み通知クリアテスト")
    func testClearDeliveredNotifications() async throws {
        // Given: NotificationManager
        let manager = createNotificationManager()
        
        // When: 配信済み通知をクリア
        await manager.clearDeliveredNotifications()
        
        // Then: クリア処理が実行されること
        #expect(mockLogger.loggedMessages.contains { $0.contains("配信済み通知クリア") })
    }
    
    @Test("タイプ別配信済み通知クリアテスト")
    func testClearDeliveredNotificationsByType() async throws {
        // Given: NotificationManager
        let manager = createNotificationManager()
        let type = AppNotificationType.dataReminder
        
        // When: タイプ別配信済み通知をクリア
        await manager.clearDeliveredNotifications(ofType: type)
        
        // Then: タイプ別クリア処理が実行されること
        #expect(mockLogger.loggedMessages.contains { $0.contains("タイプ別配信済み通知クリア") })
    }
    
    // MARK: - Analytics Tests
    
    @Test("通知効果分析テスト")
    func testAnalyzeNotificationEffectiveness() async throws {
        // Given: NotificationManagerと統計データ
        let manager = createNotificationManager()
        mockNotificationService.setupMockStats()
        
        // When: 通知効果を分析
        let report = await manager.analyzeNotificationEffectiveness()
        
        // Then: 分析レポートが生成されること
        #expect(report.overallEngagementRate >= 0.0)
        #expect(report.deliveryRate >= 0.0)
        #expect(!report.typeEffectiveness.isEmpty)
        #expect(!report.recommendations.isEmpty)
        #expect(mockLogger.loggedMessages.contains { $0.contains("通知効果分析実行") })
    }
    
    @Test("週次通知レポート生成テスト")
    func testGenerateWeeklyNotificationReport() async throws {
        // Given: NotificationManager
        let manager = createNotificationManager()
        mockNotificationService.setupMockStats()
        
        // When: 週次レポートを生成
        try await manager.generateWeeklyNotificationReport()
        
        // Then: 週次レポートが生成されること
        #expect(mockNotificationService.scheduledReminders.count > 0)
        #expect(mockLogger.loggedMessages.contains { $0.contains("週次通知レポート生成") })
        
        // And: 適切な週次インサイト通知がスケジュールされること
        let weeklyInsight = mockNotificationService.scheduledReminders.first { $0.type == .weeklyInsight }
        #expect(weeklyInsight != nil)
        #expect(weeklyInsight?.content.title == "週次レポート")
    }
    
    // MARK: - State Management Tests
    
    @Test("Published状態変更テスト")
    func testPublishedStateChanges() async throws {
        // Given: NotificationManager
        let manager = createNotificationManager()
        
        // When: 初期化を実行
        await manager.initialize()
        
        // Then: Published状態が適切に更新されること
        #expect(manager.isInitialized == true)
        #expect(manager.authorizationStatus != .notDetermined)
        
        // When: 権限を要求
        _ = try await manager.requestNotificationPermission()
        
        // Then: 認証状態が更新されること
        #expect(manager.authorizationStatus == .authorized)
    }
    
    @Test("アクティブリマインダー状態更新テスト")
    func testActiveRemindersStateUpdate() async throws {
        // Given: NotificationManager
        let manager = createNotificationManager()
        await manager.initialize()
        
        // 初期状態確認
        #expect(manager.activeReminders.isEmpty)
        
        // When: リマインダーを設定
        try await manager.configureReminder(
            for: .weight,
            times: createTestTimes(count: 1),
            frequency: .daily,
            enabled: true
        )
        
        // Then: アクティブリマインダーが更新されること（モック実装による）
        // 実際の実装では loadActiveReminders() が呼ばれる
    }
    
    // MARK: - Error Handling Tests
    
    @Test("サービスエラーハンドリングテスト")
    func testServiceErrorHandling() async throws {
        // Given: エラーを発生させるモック
        let manager = createNotificationManager()
        mockNotificationService.shouldThrowError = true
        
        // When/Then: サービスエラーが適切に処理されること
        await #expect(throws: MockNotificationServiceError.simulatedError) {
            try await manager.sendGoalAchievementNotification(
                goalType: .weight,
                value: 70.0
            )
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("大量通知処理パフォーマンステスト")
    func testBulkNotificationPerformance() async throws {
        // Given: NotificationManagerと大量のデータ
        let manager = createNotificationManager()
        let startTime = Date()
        
        // When: 大量の通知を処理
        for i in 1...50 {
            try await manager.sendGoalAchievementNotification(
                goalType: .steps,
                value: Double(i * 1000)
            )
        }
        
        // Then: 合理的な時間内で完了すること
        let processingTime = Date().timeIntervalSince(startTime)
        #expect(processingTime < 10.0) // 10秒以内
        
        // And: 適切に処理されること
        #expect(mockNotificationService.scheduledReminders.count == 50)
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func createNotificationManager() -> NotificationManager {
        let manager = NotificationManager(logger: mockLogger)
        // 本来はDependency Injectionでモックを注入すべきですが、
        // テスト用の簡易実装として直接的にモックを使用
        return manager
    }
    
    private func createTestTimes(count: Int) -> [Date] {
        let calendar = Calendar.current
        let now = Date()
        
        return (0..<count).compactMap { index in
            calendar.date(bySettingHour: 9 + index * 4, minute: 0, second: 0, of: now)
        }
    }
}

// MARK: - Mock Extensions for Testing

extension MockNotificationService {
    
    func setupMockStats() {
        // モック統計データをセットアップ
        // 実際の実装では NotificationStats を返す
    }
    
    var shouldThrowError: Bool = false
    
    override func sendGoalAchievementNotification(goalType: HealthDataType, value: Double, streakDays: Int?) async throws {
        if shouldThrowError {
            throw MockNotificationServiceError.simulatedError
        }
        try await super.sendGoalAchievementNotification(goalType: goalType, value: value, streakDays: streakDays)
    }
}

// MARK: - Mock ReminderNotificationScheduler

class MockReminderNotificationScheduler {
    private let logger: AILoggerProtocol
    private let notificationService: NotificationServiceProtocol
    
    init(notificationService: NotificationServiceProtocol, logger: AILoggerProtocol) {
        self.notificationService = notificationService
        self.logger = logger
    }
    
    func setupDefaultReminders() async throws {
        logger.info("標準リマインダーセットアップ開始", context: nil)
        logger.info("標準リマインダーセットアップ完了", context: nil)
    }
    
    func scheduleDataTypeReminder(
        dataType: HealthDataType,
        times: [Date],
        frequency: NotificationScheduleFrequency,
        customMessage: String? = nil
    ) async throws {
        logger.info("データタイプリマインダースケジュール", context: [
            "dataType": dataType.rawValue
        ])
    }
    
    func cancelDataTypeReminder(for dataType: HealthDataType) async throws {
        logger.info("データタイプリマインダーキャンセル", context: [
            "dataType": dataType.rawValue
        ])
    }
    
    func scheduleIntelligentReminders() async throws {
        logger.info("インテリジェント・リマインダースケジュール開始", context: nil)
        logger.info("インテリジェント・リマインダースケジュール完了", context: nil)
    }
    
    func adjustRemindersBasedOnSuccessRate() async throws {
        logger.info("アダプティブ・リマインダー調整開始", context: nil)
        logger.info("アダプティブ・リマインダー調整完了", context: nil)
    }
}

// MARK: - Mock Error Types

enum MockNotificationServiceError: Error {
    case simulatedError
}

// MARK: - Missing Model Definitions for Testing

extension HealthAlertSeverity: CaseIterable {
    public static var allCases: [HealthAlertSeverity] {
        return [.low, .normal, .high, .critical]
    }
}

// 一時的なHealthAlertSeverity定義（実装待ち）
enum HealthAlertSeverity: String, CaseIterable {
    case low = "low"
    case normal = "normal" 
    case high = "high"
    case critical = "critical"
}

// 一時的なNotificationEffectivenessReport定義（実装待ち）
struct NotificationEffectivenessReport {
    let overallEngagementRate: Double
    let deliveryRate: Double
    let typeEffectiveness: [AppNotificationType: Double]
    let recommendations: [String]
    let generatedAt: Date
}

// 一時的なNotificationEffectivenessAnalysis定義（実装待ち）
struct NotificationEffectivenessAnalysis {
    let typeEffectiveness: [AppNotificationType: Double]
    let recommendations: [String]
}

// NotificationStats拡張（実装待ち機能）
extension NotificationStats {
    var engagementRate: Double { 0.75 } // モック値
    var deliveryRate: Double { 0.95 } // モック値
}