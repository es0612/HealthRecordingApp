import Foundation
import UserNotifications
import SwiftUI

// MARK: - 通知タイプとモデル定義

/// 通知の種類
public enum AppNotificationType: String, CaseIterable, Codable {
    case dataReminder = "data_reminder"           // データ記録リマインダー
    case goalAchievement = "goal_achievement"     // 目標達成
    case streakMilestone = "streak_milestone"     // ストリークマイルストーン
    case weeklyInsight = "weekly_insight"         // 週次インサイト
    case healthAlert = "health_alert"             // 健康アラート
    
    /// 表示名
    var displayName: String {
        switch self {
        case .dataReminder:
            return "データ記録リマインダー"
        case .goalAchievement:
            return "目標達成通知"
        case .streakMilestone:
            return "継続ストリーク"
        case .weeklyInsight:
            return "週次レポート"
        case .healthAlert:
            return "健康アラート"
        }
    }
    
    /// デフォルトの有効状態
    var defaultEnabled: Bool {
        switch self {
        case .dataReminder:
            return true
        case .goalAchievement:
            return true
        case .streakMilestone:
            return true
        case .weeklyInsight:
            return false
        case .healthAlert:
            return true
        }
    }
    
    /// 詳細説明
    var description: String {
        switch self {
        case .dataReminder:
            return "健康データの記録を思い出させる通知"
        case .goalAchievement:
            return "目標達成時のお祝い通知"
        case .streakMilestone:
            return "継続記録の節目での通知"
        case .healthAlert:
            return "健康状態に関する重要な通知"
        case .weeklyInsight:
            return "週次の健康データ分析結果"
        }
    }
    
    /// アイコン名
    var iconName: String {
        switch self {
        case .dataReminder:
            return "bell.badge"
        case .goalAchievement:
            return "trophy"
        case .streakMilestone:
            return "flame"
        case .healthAlert:
            return "exclamationmark.triangle"
        case .weeklyInsight:
            return "chart.line.uptrend.xyaxis"
        }
    }
    
    /// テーマカラー
    var color: Color {
        switch self {
        case .dataReminder:
            return .blue
        case .goalAchievement:
            return .green
        case .streakMilestone:
            return .orange
        case .healthAlert:
            return .red
        case .weeklyInsight:
            return .purple
        }
    }
}

/// 健康アラートの重要度
public enum HealthAlertSeverity: String, CaseIterable, Codable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .normal: return "通常"
        case .high: return "高"
        case .critical: return "緊急"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .green
        case .normal: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
}

/// 通知の頻度設定
public enum NotificationScheduleFrequency: String, CaseIterable, Codable {
    case disabled = "disabled"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .disabled:
            return "無効"
        case .daily:
            return "毎日"
        case .weekly:
            return "毎週"
        case .monthly:
            return "毎月"
        case .custom:
            return "カスタム"
        }
    }
}

/// 通知設定モデル
public struct NotificationSettings: Codable, Equatable {
    public let id: UUID
    public let type: AppNotificationType
    public var isEnabled: Bool
    public var frequency: NotificationScheduleFrequency
    public var scheduledTimes: [Date]  // 1日内での通知時間
    public var customDays: Set<Int>?   // カスタム頻度での曜日指定 (1=日曜日, 7=土曜日)
    public var lastModified: Date
    
    public init(
        id: UUID = UUID(),
        type: AppNotificationType,
        isEnabled: Bool? = nil,
        frequency: NotificationScheduleFrequency = .daily,
        scheduledTimes: [Date] = [],
        customDays: Set<Int>? = nil
    ) {
        self.id = id
        self.type = type
        self.isEnabled = isEnabled ?? type.defaultEnabled
        self.frequency = frequency
        self.scheduledTimes = scheduledTimes.isEmpty ? [NotificationSettings.defaultTime] : scheduledTimes
        self.customDays = customDays
        self.lastModified = Date()
    }
    
    /// デフォルト通知時間（朝9時）
    public static let defaultTime: Date = {
        let calendar = Calendar.current
        let now = Date()
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
    }()
}

/// 通知コンテンツモデル
public struct NotificationContent: Codable {
    public let id: UUID
    public let type: AppNotificationType
    public let title: String
    public let body: String
    public let badge: Int?
    public let sound: String?
    public let data: [String: String]  // 追加データ
    public let createdAt: Date
    
    public init(
        id: UUID = UUID(),
        type: AppNotificationType,
        title: String,
        body: String,
        badge: Int? = nil,
        sound: String? = nil,
        data: [String: String] = [:],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.badge = badge
        self.sound = sound
        self.data = data
        self.createdAt = createdAt
    }
}

/// スケジュールされた通知モデル
public struct ScheduledNotification: Codable, Identifiable {
    public let id: String  // UNUserNotificationCenter identifier
    public let type: AppNotificationType
    public let content: NotificationContent
    public let scheduledDate: Date
    public let isRepeating: Bool
    public let createdAt: Date
    
    public init(
        id: String = UUID().uuidString,
        type: AppNotificationType,
        content: NotificationContent,
        scheduledDate: Date,
        isRepeating: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.scheduledDate = scheduledDate
        self.isRepeating = isRepeating
        self.createdAt = createdAt
    }
}

// MARK: - 通知権限管理

/// 通知権限の状態
public enum NotificationAuthorizationStatus: String, Codable {
    case notDetermined = "not_determined"
    case denied = "denied"
    case authorized = "authorized"
    case provisional = "provisional"
    case ephemeral = "ephemeral"
    
    public init(from unStatus: UNAuthorizationStatus) {
        switch unStatus {
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .authorized:
            self = .authorized
        case .provisional:
            self = .provisional
        case .ephemeral:
            self = .ephemeral
        @unknown default:
            self = .notDetermined
        }
    }
    
    var displayName: String {
        switch self {
        case .notDetermined:
            return "未設定"
        case .denied:
            return "拒否"
        case .authorized:
            return "許可"
        case .provisional:
            return "仮許可"
        case .ephemeral:
            return "一時許可"
        }
    }
    
    var isAuthorized: Bool {
        return [.authorized, .provisional, .ephemeral].contains(self)
    }
}

// MARK: - 通知テンプレート

/// 通知テンプレート生成器
public struct NotificationTemplate {
    
    /// データ記録リマインダー通知
    public static func dataReminder(dataType: HealthDataType, streak: Int = 0) -> NotificationContent {
        let title = "健康データを記録しましょう"
        let body: String
        
        if streak > 0 {
            body = "\(dataType.displayName)の記録をお忘れなく！現在\(streak)日連続記録中です。"
        } else {
            body = "\(dataType.displayName)の記録をして、健康管理を続けましょう。"
        }
        
        return NotificationContent(
            type: .dataReminder,
            title: title,
            body: body,
            badge: 1,
            data: [
                "dataType": dataType.rawValue,
                "streak": String(streak)
            ]
        )
    }
    
    /// 目標達成通知
    public static func goalAchievement(goalType: HealthDataType, value: Double) -> NotificationContent {
        let title = "目標達成おめでとうございます！🎉"
        let body = "\(goalType.displayName)の目標(\(String(format: "%.1f", value))\(goalType.unit))を達成しました！"
        
        return NotificationContent(
            type: .goalAchievement,
            title: title,
            body: body,
            badge: 1,
            sound: "achievement.wav",
            data: [
                "goalType": goalType.rawValue,
                "value": String(value)
            ]
        )
    }
    
    /// ストリークマイルストーン通知
    public static func streakMilestone(streak: Int, dataType: HealthDataType? = nil) -> NotificationContent {
        let title = "継続記録達成！🔥"
        let body: String
        
        if let dataType = dataType {
            body = "\(dataType.displayName)を\(streak)日連続で記録しています！素晴らしい継続力です。"
        } else {
            body = "健康データを\(streak)日連続で記録しています！この調子で続けましょう。"
        }
        
        return NotificationContent(
            type: .streakMilestone,
            title: title,
            body: body,
            badge: 1,
            sound: "streak.wav",
            data: [
                "streak": String(streak),
                "dataType": dataType?.rawValue ?? ""
            ]
        )
    }
    
    /// 週次インサイト通知
    public static func weeklyInsight(summary: String) -> NotificationContent {
        return NotificationContent(
            type: .weeklyInsight,
            title: "今週の健康レポート",
            body: summary,
            badge: 1,
            data: ["summary": summary]
        )
    }
    
    /// 健康アラート通知
    public static func healthAlert(message: String, severity: String = "normal") -> NotificationContent {
        return NotificationContent(
            type: .healthAlert,
            title: "健康に関するお知らせ",
            body: message,
            badge: 1,
            sound: severity == "urgent" ? "urgent.wav" : nil,
            data: [
                "message": message,
                "severity": severity
            ]
        )
    }
}

// MARK: - 通知統計

/// 通知統計モデル
public struct NotificationStats: Codable {
    public let totalSent: Int
    public let totalDelivered: Int
    public let totalOpened: Int
    public let typeBreakdown: [AppNotificationType: Int]
    public let recentActivity: [Date]
    public let calculatedAt: Date
    
    public init(
        totalSent: Int = 0,
        totalDelivered: Int = 0,
        totalOpened: Int = 0,
        typeBreakdown: [AppNotificationType: Int] = [:],
        recentActivity: [Date] = [],
        calculatedAt: Date = Date()
    ) {
        self.totalSent = totalSent
        self.totalDelivered = totalDelivered
        self.totalOpened = totalOpened
        self.typeBreakdown = typeBreakdown
        self.recentActivity = recentActivity
        self.calculatedAt = calculatedAt
    }
    
    public var engagementRate: Double {
        guard totalDelivered > 0 else { return 0 }
        return Double(totalOpened) / Double(totalDelivered)
    }
    
    public var deliveryRate: Double {
        guard totalSent > 0 else { return 0 }
        return Double(totalDelivered) / Double(totalSent)
    }
}