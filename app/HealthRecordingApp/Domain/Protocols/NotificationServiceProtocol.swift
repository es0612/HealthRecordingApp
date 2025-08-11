import Foundation
import UserNotifications

/// 通知サービスのプロトコル定義
@MainActor
public protocol NotificationServiceProtocol {
    
    // MARK: - 権限管理
    
    /// 通知権限の現在の状態を取得
    func getAuthorizationStatus() async -> NotificationAuthorizationStatus
    
    /// 通知権限の要求
    func requestAuthorization() async throws -> Bool
    
    /// 設定画面への遷移を促すアラート表示
    func promptForSettings() async
    
    // MARK: - 通知設定管理
    
    /// 全ての通知設定を取得
    func getNotificationSettings() async -> [NotificationSettings]
    
    /// 特定タイプの通知設定を取得
    func getNotificationSettings(for type: AppNotificationType) async -> NotificationSettings?
    
    /// 通知設定を更新
    func updateNotificationSettings(_ settings: NotificationSettings) async throws
    
    /// 通知設定をリセット（デフォルトに戻す）
    func resetNotificationSettings() async throws
    
    // MARK: - 通知スケジューリング
    
    /// 即座に通知を送信
    func sendImmediateNotification(_ content: NotificationContent) async throws
    
    /// 指定された日時に通知をスケジュール
    func scheduleNotification(
        _ content: NotificationContent,
        at date: Date,
        repeating: Bool
    ) async throws -> String
    
    /// 定期的な通知をスケジュール（設定に基づく）
    func scheduleRecurringNotification(for settings: NotificationSettings) async throws -> [String]
    
    /// 特定の通知をキャンセル
    func cancelNotification(withId id: String) async
    
    /// 特定タイプの全通知をキャンセル
    func cancelNotifications(ofType type: AppNotificationType) async
    
    /// 全ての保留中の通知をキャンセル
    func cancelAllNotifications() async
    
    // MARK: - 通知管理
    
    /// 保留中の通知一覧を取得
    func getPendingNotifications() async -> [ScheduledNotification]
    
    /// 配信済み通知一覧を取得
    func getDeliveredNotifications() async -> [UNNotification]
    
    /// 配信済み通知をクリア
    func clearDeliveredNotifications() async
    
    /// 特定タイプの配信済み通知をクリア
    func clearDeliveredNotifications(ofType type: AppNotificationType) async
    
    // MARK: - 通知統計
    
    /// 通知統計を取得
    func getNotificationStats() async -> NotificationStats
    
    /// 通知のクリック・開封を記録
    func recordNotificationEngagement(_ notificationId: String) async
    
    // MARK: - ヘルスケア特化機能
    
    /// データ記録リマインダーをスケジュール
    func scheduleDataReminder(
        for dataType: HealthDataType,
        at times: [Date],
        frequency: NotificationScheduleFrequency
    ) async throws
    
    /// 目標達成通知を送信
    func sendGoalAchievementNotification(
        goalType: HealthDataType,
        value: Double,
        streakDays: Int?
    ) async throws
    
    /// ストリークマイルストーン通知を送信
    func sendStreakMilestoneNotification(
        streak: Int,
        dataType: HealthDataType?
    ) async throws
    
    /// 週次インサイト通知をスケジュール
    func scheduleWeeklyInsight(
        summary: String,
        dayOfWeek: Int,
        time: Date
    ) async throws
    
    /// 健康アラートを送信
    func sendHealthAlert(
        message: String,
        severity: String,
        immediate: Bool
    ) async throws
}

// MARK: - 通知サービスエラー

public enum NotificationServiceError: Error, LocalizedError, Equatable {
    case authorizationDenied
    case authorizationNotDetermined
    case settingsNotFound(AppNotificationType)
    case invalidScheduleDate(Date)
    case notificationLimitExceeded
    case systemError(String)
    
    public var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "通知の許可が拒否されています。設定で許可してください。"
        case .authorizationNotDetermined:
            return "通知の許可がまだ設定されていません。"
        case .settingsNotFound(let type):
            return "通知設定が見つかりません: \(type.displayName)"
        case .invalidScheduleDate(let date):
            return "無効な通知日時です: \(date)"
        case .notificationLimitExceeded:
            return "通知の上限数を超過しています。"
        case .systemError(let message):
            return "システムエラー: \(message)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .authorizationDenied:
            return "設定アプリから通知を許可してください。"
        case .authorizationNotDetermined:
            return "アプリから通知の許可を要求してください。"
        case .settingsNotFound:
            return "通知設定を再設定してください。"
        case .invalidScheduleDate:
            return "将来の日時を指定してください。"
        case .notificationLimitExceeded:
            return "不要な通知を削除してから再試行してください。"
        case .systemError:
            return "しばらく待ってから再試行してください。"
        }
    }
}