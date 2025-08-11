import Foundation
import UserNotifications
import SwiftUI

/// 通知サービスの実装クラス
@MainActor
public final class NotificationService: NSObject, NotificationServiceProtocol {
    
    // MARK: - Properties
    
    private let notificationCenter: UNUserNotificationCenter
    internal let logger: AILoggerProtocol
    internal let userDefaults: UserDefaults
    
    /// 通知設定のキャッシュ
    private var settingsCache: [AppNotificationType: NotificationSettings] = [:]
    
    /// 通知統計のキャッシュ
    private var statsCache: NotificationStats?
    private var statsCacheExpiry: Date = Date()
    
    /// 設定保存用のキー
    private let settingsKey = "notification_settings"
    private let statsKey = "notification_stats"
    
    // MARK: - Initialization
    
    public init(
        notificationCenter: UNUserNotificationCenter = UNUserNotificationCenter.current(),
        logger: AILoggerProtocol,
        userDefaults: UserDefaults = .standard
    ) {
        self.notificationCenter = notificationCenter
        self.logger = logger
        self.userDefaults = userDefaults
        
        super.init()
        
        // デリゲートを設定
        self.notificationCenter.delegate = self
        
        // 初期設定をロード
        Task {
            await loadStoredSettings()
        }
    }
    
    // MARK: - 権限管理
    
    public func getAuthorizationStatus() async -> NotificationAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        let status = NotificationAuthorizationStatus(from: settings.authorizationStatus)
        
        logger.debug("通知権限状態取得", context: [
            "status": status.rawValue,
            "displayName": status.displayName
        ])
        
        return status
    }
    
    public func requestAuthorization() async throws -> Bool {
        logger.info("通知権限要求開始")
        
        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .badge, .sound, .provisional]
            )
            
            logger.info("通知権限要求完了", context: [
                "granted": granted
            ])
            
            if granted {
                // デフォルト設定を初期化
                await initializeDefaultSettings()
            }
            
            return granted
        } catch {
            logger.error(error, context: [
                "operation": "request_authorization"
            ])
            throw NotificationServiceError.systemError(error.localizedDescription)
        }
    }
    
    public func promptForSettings() async {
        logger.info("設定画面遷移プロンプト表示")
        
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            logger.warning("設定画面URLの取得に失敗")
            return
        }
        
        #if os(iOS)
        if await UIApplication.shared.canOpenURL(settingsURL) {
            await UIApplication.shared.open(settingsURL)
        }
        #endif
    }
    
    // MARK: - 通知設定管理
    
    public func getNotificationSettings() async -> [NotificationSettings] {
        if settingsCache.isEmpty {
            await loadStoredSettings()
        }
        
        return Array(settingsCache.values).sorted { $0.type.rawValue < $1.type.rawValue }
    }
    
    public func getNotificationSettings(for type: AppNotificationType) async -> NotificationSettings? {
        if settingsCache.isEmpty {
            await loadStoredSettings()
        }
        
        return settingsCache[type]
    }
    
    public func updateNotificationSettings(_ settings: NotificationSettings) async throws {
        logger.info("通知設定更新", context: [
            "type": settings.type.rawValue,
            "enabled": settings.isEnabled,
            "frequency": settings.frequency.rawValue
        ])
        
        // キャッシュを更新
        settingsCache[settings.type] = settings
        
        // 永続化
        await saveSettings()
        
        // 既存の通知をキャンセルして再スケジュール
        await cancelNotifications(ofType: settings.type)
        
        if settings.isEnabled {
            try await scheduleRecurringNotification(for: settings)
        }
    }
    
    public func resetNotificationSettings() async throws {
        logger.info("通知設定リセット")
        
        // 全通知をキャンセル
        await cancelAllNotifications()
        
        // デフォルト設定を初期化
        await initializeDefaultSettings()
        
        // 永続化
        await saveSettings()
    }
    
    // MARK: - 通知スケジューリング
    
    public func sendImmediateNotification(_ content: NotificationContent) async throws {
        let status = await getAuthorizationStatus()
        guard status.isAuthorized else {
            throw NotificationServiceError.authorizationDenied
        }
        
        logger.info("即座通知送信", context: [
            "type": content.type.rawValue,
            "title": content.title
        ])
        
        let unContent = createUNNotificationContent(from: content)
        let request = UNNotificationRequest(
            identifier: content.id.uuidString,
            content: unContent,
            trigger: nil  // 即座に送信
        )
        
        do {
            try await notificationCenter.add(request)
            await recordNotificationSent(content)
        } catch {
            logger.error(error, context: [
                "operation": "send_immediate_notification",
                "contentId": content.id.uuidString
            ])
            throw NotificationServiceError.systemError(error.localizedDescription)
        }
    }
    
    public func scheduleNotification(
        _ content: NotificationContent,
        at date: Date,
        repeating: Bool = false
    ) async throws -> String {
        let status = await getAuthorizationStatus()
        guard status.isAuthorized else {
            throw NotificationServiceError.authorizationDenied
        }
        
        guard date > Date() else {
            throw NotificationServiceError.invalidScheduleDate(date)
        }
        
        logger.info("通知スケジュール", context: [
            "type": content.type.rawValue,
            "scheduledDate": date.ISO8601String,
            "repeating": repeating
        ])
        
        let identifier = content.id.uuidString
        let unContent = createUNNotificationContent(from: content)
        
        let trigger: UNNotificationTrigger
        if repeating {
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        } else {
            let timeInterval = date.timeIntervalSinceNow
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        }
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: unContent,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
            await recordNotificationScheduled(content, date: date, repeating: repeating)
            return identifier
        } catch {
            logger.error(error, context: [
                "operation": "schedule_notification",
                "contentId": content.id.uuidString
            ])
            throw NotificationServiceError.systemError(error.localizedDescription)
        }
    }
    
    public func scheduleRecurringNotification(for settings: NotificationSettings) async throws -> [String] {
        guard settings.isEnabled else {
            logger.debug("無効な設定のためスキップ", context: [
                "type": settings.type.rawValue
            ])
            return []
        }
        
        logger.info("定期通知スケジュール", context: [
            "type": settings.type.rawValue,
            "frequency": settings.frequency.rawValue,
            "timesCount": settings.scheduledTimes.count
        ])
        
        var scheduledIds: [String] = []
        
        for scheduledTime in settings.scheduledTimes {
            let content = createDefaultContent(for: settings.type)
            
            switch settings.frequency {
            case .disabled:
                continue
                
            case .daily:
                let id = try await scheduleNotification(content, at: scheduledTime, repeating: true)
                scheduledIds.append(id)
                
            case .weekly:
                // 毎週同じ曜日・時間
                let id = try await scheduleWeeklyNotification(content, at: scheduledTime)
                scheduledIds.append(id)
                
            case .monthly:
                // 毎月同じ日・時間
                let id = try await scheduleMonthlyNotification(content, at: scheduledTime)
                scheduledIds.append(id)
                
            case .custom:
                if let customDays = settings.customDays {
                    for dayOfWeek in customDays {
                        let id = try await scheduleCustomNotification(
                            content,
                            at: scheduledTime,
                            dayOfWeek: dayOfWeek
                        )
                        scheduledIds.append(id)
                    }
                }
            }
        }
        
        return scheduledIds
    }
    
    public func cancelNotification(withId id: String) async {
        logger.debug("通知キャンセル", context: ["id": id])
        
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [id])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [id])
    }
    
    public func cancelNotifications(ofType type: AppNotificationType) async {
        logger.info("タイプ別通知キャンセル", context: ["type": type.rawValue])
        
        let pending = await getPendingNotifications()
        let idsToCancel = pending.filter { $0.type == type }.map(\.id)
        
        if !idsToCancel.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: idsToCancel)
            notificationCenter.removeDeliveredNotifications(withIdentifiers: idsToCancel)
        }
    }
    
    public func cancelAllNotifications() async {
        logger.info("全通知キャンセル", context: nil)
        
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }
    
    // MARK: - 通知管理
    
    public func getPendingNotifications() async -> [ScheduledNotification] {
        let requests = await notificationCenter.pendingNotificationRequests()
        
        return requests.compactMap { request -> ScheduledNotification? in
            guard let typeString = request.content.userInfo["type"] as? String,
                  let type = AppNotificationType(rawValue: typeString),
                  let scheduleDateString = request.content.userInfo["scheduledDate"] as? String,
                  let scheduledDate = ISO8601DateFormatter().date(from: scheduleDateString) else {
                return nil
            }
            
            let content = NotificationContent(
                type: type,
                title: request.content.title,
                body: request.content.body,
                badge: request.content.badge?.intValue,
                sound: request.content.sound?.name,
                data: request.content.userInfo.compactMapValues { $0 as? String }
            )
            
            return ScheduledNotification(
                id: request.identifier,
                type: type,
                content: content,
                scheduledDate: scheduledDate,
                isRepeating: request.trigger?.repeats ?? false
            )
        }
    }
    
    public func getDeliveredNotifications() async -> [UNNotification] {
        let notifications = await notificationCenter.deliveredNotifications()
        
        logger.debug("配信済み通知取得", context: [
            "count": notifications.count
        ])
        
        return notifications
    }
    
    public func clearDeliveredNotifications() async {
        logger.info("配信済み通知クリア", context: nil)
        notificationCenter.removeAllDeliveredNotifications()
    }
    
    public func clearDeliveredNotifications(ofType type: AppNotificationType) async {
        logger.info("タイプ別配信済み通知クリア", context: ["type": type.rawValue])
        
        let delivered = await getDeliveredNotifications()
        let idsToRemove = delivered.compactMap { notification in
            if let typeString = notification.request.content.userInfo["type"] as? String,
               AppNotificationType(rawValue: typeString) == type {
                return notification.request.identifier
            }
            return nil
        }
        
        if !idsToRemove.isEmpty {
            notificationCenter.removeDeliveredNotifications(withIdentifiers: idsToRemove)
        }
    }
    
    // MARK: - 通知統計
    
    public func getNotificationStats() async -> NotificationStats {
        // キャッシュチェック
        if let cachedStats = statsCache, statsCacheExpiry > Date() {
            return cachedStats
        }
        
        let stats = await calculateNotificationStats()
        
        // キャッシュを更新（1時間有効）
        statsCache = stats
        statsCacheExpiry = Date().addingTimeInterval(3600)
        
        await saveStats(stats)
        
        return stats
    }
    
    public func recordNotificationEngagement(_ notificationId: String) async {
        logger.info("通知エンゲージメント記録", context: [
            "notificationId": notificationId
        ])
        
        // エンゲージメントデータをUserDefaultsに保存
        var engagements = userDefaults.stringArray(forKey: "notification_engagements") ?? []
        let engagementRecord = "\(notificationId)|\(Date().timeIntervalSince1970)"
        engagements.append(engagementRecord)
        
        // 最新100件のみ保持
        if engagements.count > 100 {
            engagements = Array(engagements.suffix(100))
        }
        
        userDefaults.set(engagements, forKey: "notification_engagements")
        
        // 統計キャッシュを無効化
        statsCache = nil
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        logger.debug("フォアグラウンド通知受信", context: [
            "identifier": notification.request.identifier
        ])
        
        // フォアグラウンドでも通知を表示
        completionHandler([.banner, .sound, .badge])
    }
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        
        logger.info("通知応答受信", context: [
            "identifier": identifier,
            "actionIdentifier": response.actionIdentifier
        ])
        
        // エンゲージメントを記録
        Task {
            await recordNotificationEngagement(identifier)
        }
        
        completionHandler()
    }
}

// MARK: - Private Methods

internal extension NotificationService {
    
    func initializeDefaultSettings() async {
        logger.info("デフォルト通知設定初期化", context: nil)
        
        for type in AppNotificationType.allCases {
            if settingsCache[type] == nil {
                let defaultSettings = NotificationSettings(type: type)
                settingsCache[type] = defaultSettings
            }
        }
        
        await saveSettings()
    }
    
    func loadStoredSettings() async {
        if let data = userDefaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode([NotificationSettings].self, from: data) {
            
            settingsCache = Dictionary(uniqueKeysWithValues: decoded.map { ($0.type, $0) })
            
            logger.debug("保存済み通知設定読み込み", context: [
                "count": decoded.count
            ])
        } else {
            await initializeDefaultSettings()
        }
    }
    
    func saveSettings() async {
        let settings = Array(settingsCache.values)
        
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: settingsKey)
            
            logger.debug("通知設定保存", context: [
                "count": settings.count
            ])
        }
    }
    
    func saveStats(_ stats: NotificationStats) async {
        if let encoded = try? JSONEncoder().encode(stats) {
            userDefaults.set(encoded, forKey: statsKey)
        }
    }
    
    func createUNNotificationContent(from content: NotificationContent) -> UNMutableNotificationContent {
        let unContent = UNMutableNotificationContent()
        unContent.title = content.title
        unContent.body = content.body
        unContent.badge = content.badge.map(NSNumber.init)
        unContent.sound = content.sound.map { UNNotificationSound(named: UNNotificationSoundName($0)) } ?? .default
        
        // カスタムデータを追加
        var userInfo = content.data
        userInfo["type"] = content.type.rawValue
        userInfo["contentId"] = content.id.uuidString
        userInfo["createdAt"] = content.createdAt.ISO8601String
        
        unContent.userInfo = userInfo
        
        return unContent
    }
    
    func createDefaultContent(for type: AppNotificationType) -> NotificationContent {
        switch type {
        case .dataReminder:
            return NotificationTemplate.dataReminder(dataType: .weight)
        case .goalAchievement:
            return NotificationTemplate.goalAchievement(goalType: .weight, value: 70.0)
        case .streakMilestone:
            return NotificationTemplate.streakMilestone(streak: 7)
        case .weeklyInsight:
            return NotificationTemplate.weeklyInsight(summary: "今週も健康管理お疲れさまでした。")
        case .healthAlert:
            return NotificationTemplate.healthAlert(message: "健康データをチェックしましょう。")
        }
    }
    
    func scheduleWeeklyNotification(_ content: NotificationContent, at time: Date) async throws -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.weekday, .hour, .minute], from: time)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: createUNNotificationContent(from: content),
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
        return request.identifier
    }
    
    func scheduleMonthlyNotification(_ content: NotificationContent, at time: Date) async throws -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .hour, .minute], from: time)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: createUNNotificationContent(from: content),
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
        return request.identifier
    }
    
    func scheduleCustomNotification(_ content: NotificationContent, at time: Date, dayOfWeek: Int) async throws -> String {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.hour, .minute], from: time)
        components.weekday = dayOfWeek
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: createUNNotificationContent(from: content),
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
        return request.identifier
    }
    
    func recordNotificationSent(_ content: NotificationContent) async {
        logger.info("通知送信記録", context: [
            "type": content.type.rawValue,
            "contentId": content.id.uuidString
        ])
        
        // 送信統計を更新
        var sentStats = userDefaults.dictionary(forKey: "notification_sent_stats") ?? [:]
        let key = content.type.rawValue
        let currentCount = sentStats[key] as? Int ?? 0
        sentStats[key] = currentCount + 1
        userDefaults.set(sentStats, forKey: "notification_sent_stats")
    }
    
    func recordNotificationScheduled(_ content: NotificationContent, date: Date, repeating: Bool) async {
        logger.info("通知スケジュール記録", context: [
            "type": content.type.rawValue,
            "scheduledDate": date.ISO8601String,
            "repeating": repeating
        ])
        
        await recordNotificationSent(content)
    }
    
    func calculateNotificationStats() async -> NotificationStats {
        let sentStats = userDefaults.dictionary(forKey: "notification_sent_stats") ?? [:]
        let engagements = userDefaults.stringArray(forKey: "notification_engagements") ?? []
        
        let totalSent = sentStats.values.compactMap { $0 as? Int }.reduce(0, +)
        let totalOpened = engagements.count
        
        let typeBreakdown = sentStats.compactMapValues { $0 as? Int }
            .compactMapKeys { AppNotificationType(rawValue: $0) }
        
        // 最近のエンゲージメント日時を抽出
        let recentActivity = engagements.compactMap { engagement in
            let components = engagement.components(separatedBy: "|")
            guard components.count >= 2,
                  let timestamp = Double(components[1]) else { return nil }
            return Date(timeIntervalSince1970: timestamp)
        }.sorted(by: >)
        
        return NotificationStats(
            totalSent: totalSent,
            totalDelivered: totalSent, // 簡略化：送信数と配信数を同じとする
            totalOpened: totalOpened,
            typeBreakdown: typeBreakdown,
            recentActivity: Array(recentActivity.prefix(20))
        )
    }
}

// MARK: - Extensions

internal extension Date {
    var ISO8601String: String {
        return ISO8601DateFormatter().string(from: self)
    }
}

private extension Dictionary {
    func compactMapKeys<T>(_ transform: (Key) -> T?) -> [T: Value] {
        return compactMap { key, value in
            transform(key).map { ($0, value) }
        }.reduce(into: [:]) { result, pair in
            result[pair.0] = pair.1
        }
    }
}