import SwiftData
import Foundation

@Model
final class Badge {
    var id: UUID
    var name: String
    var badgeDescription: String
    var type: BadgeType
    var iconName: String
    var colorScheme: BadgeColorScheme
    var isEarned: Bool
    var earnedDate: Date?
    var createdAt: Date
    var requirement: BadgeRequirement
    
    // Relationship
    var user: User?
    
    init(name: String, description: String, type: BadgeType, requirement: BadgeRequirement, iconName: String, colorScheme: BadgeColorScheme) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidInput("Badge", value: name, reason: "Badge name cannot be empty")
        }
        guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidInput("Badge", value: description, reason: "Badge description cannot be empty")
        }
        guard !iconName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidInput("Badge", value: iconName, reason: "Badge iconName cannot be empty")
        }
        
        self.id = UUID()
        self.name = name
        self.badgeDescription = description
        self.type = type
        self.requirement = requirement
        self.iconName = iconName
        self.colorScheme = colorScheme
        self.isEarned = false
        self.earnedDate = nil
        self.createdAt = Date()
        self.user = nil
    }
    
    /// バッジを獲得する
    func earn(for user: User) {
        guard !isEarned else { return } // 既に獲得済みの場合は何もしない
        
        self.user = user
        isEarned = true
        earnedDate = Date()
    }
    
    /// バッジをリセット（未獲得状態に戻す）
    func reset() {
        isEarned = false
        earnedDate = nil
        user = nil
    }
    
    /// 表示用の名前
    var displayName: String {
        return name
    }
    
    /// 表示用の説明
    var displayDescription: String {
        return badgeDescription
    }
    
    /// SF Symbolsアイコン名
    var sfSymbolName: String {
        return iconName
    }
    
    /// 特別なバッジかどうか
    var isSpecialBadge: Bool {
        return type == .special
    }
}

/// バッジの種類
enum BadgeType: String, CaseIterable, Codable {
    case streak = "継続"        // 継続系バッジ
    case milestone = "マイルストーン" // 達成系バッジ
    case achievement = "実績"    // 成果系バッジ
    case special = "特別"       // 特別なバッジ
}

/// バッジのカラーパレット
enum BadgeColorScheme: String, CaseIterable, Codable {
    case bronze = "bronze"     // ブロンズ
    case silver = "silver"     // シルバー
    case gold = "gold"         // ゴールド
    case platinum = "platinum" // プラチナ
    
    /// アクセントカラーのHEX値
    var accent: String {
        switch self {
        case .bronze: return "#CD7F32"
        case .silver: return "#C0C0C0"
        case .gold: return "#FFD700"
        case .platinum: return "#E5E4E2"
        }
    }
    
    /// ベースカラーのHEX値
    var base: String {
        switch self {
        case .bronze: return "#8B4513"
        case .silver: return "#808080"
        case .gold: return "#B8860B"
        case .platinum: return "#B8B8B8"
        }
    }
}

/// バッジ獲得の条件
enum BadgeRequirement: Codable, Equatable {
    case recordCount(count: Int)    // 記録数達成
    case streak(days: Int)          // 連続日数達成
    case milestone(value: Double)   // 目標値達成
    case special                    // 特別な条件
    
    /// 条件の説明文
    var description: String {
        switch self {
        case .recordCount(let count):
            return "\(count)回の記録"
        case .streak(let days):
            return "\(days)日連続記録"
        case .milestone(let value):
            return "目標値\(value)達成"
        case .special:
            return "特別な条件"
        }
    }
    
    /// 条件が達成されているかチェック
    func isMet(for user: User) -> Bool {
        switch self {
        case .recordCount(let count):
            return user.healthRecords.count >= count
        case .streak(let days):
            // 簡易実装：連続記録のロジックは実際にはより複雑
            return user.healthRecords.count >= days
        case .milestone(let value):
            // 簡易実装：最新の体重記録が目標値以下かチェック
            if let currentWeight = user.currentWeight {
                return currentWeight <= value
            }
            return false
        case .special:
            // 特別な条件は個別に実装
            return false
        }
    }
}