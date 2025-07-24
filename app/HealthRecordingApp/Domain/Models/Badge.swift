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
    var requirement: BadgeRequirement?
    
    init(name: String, description: String, type: BadgeType, iconName: String, colorScheme: BadgeColorScheme) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            fatalError("Badge name cannot be empty")
        }
        guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            fatalError("Badge description cannot be empty")
        }
        guard !iconName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            fatalError("Badge iconName cannot be empty")
        }
        
        self.id = UUID()
        self.name = name
        self.badgeDescription = description
        self.type = type
        self.iconName = iconName
        self.colorScheme = colorScheme
        self.isEarned = false
        self.earnedDate = nil
        self.createdAt = Date()
        self.requirement = nil
    }
    
    /// バッジを獲得する
    func earn() {
        guard !isEarned else { return } // 既に獲得済みの場合は何もしない
        
        isEarned = true
        earnedDate = Date()
    }
    
    /// バッジをリセット（未獲得状態に戻す）
    func reset() {
        isEarned = false
        earnedDate = nil
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
@Model
final class BadgeRequirement {
    var id: UUID
    var type: BadgeRequirementType
    var targetValue: Double
    var dataType: HealthDataType
    var requirementDescription: String
    var createdAt: Date
    
    init(type: BadgeRequirementType, targetValue: Double, dataType: HealthDataType, description: String) {
        guard targetValue > 0 else {
            fatalError("Badge requirement target value must be positive")
        }
        guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            fatalError("Badge requirement description cannot be empty")
        }
        
        self.id = UUID()
        self.type = type
        self.targetValue = targetValue
        self.dataType = dataType
        self.requirementDescription = description
        self.createdAt = Date()
    }
}

/// バッジ条件の種類
enum BadgeRequirementType: String, CaseIterable, Codable {
    case streak = "連続記録"     // 連続日数
    case total = "累計"         // 累計値
    case milestone = "到達"     // 目標到達
    case frequency = "頻度"     // 記録頻度
}