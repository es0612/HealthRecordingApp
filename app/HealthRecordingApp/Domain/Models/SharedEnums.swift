import Foundation

// MARK: - Shared Enums for Domain Services

/// Represents the difficulty level of implementing a recommendation
enum RecommendationDifficulty: String, CaseIterable, Codable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"
    case expert = "expert"
    
    var displayName: String {
        switch self {
        case .easy: return "簡単"
        case .medium: return "中程度"
        case .hard: return "難しい"
        case .expert: return "専門的"
        }
    }
    
    var goalTrackerDisplayName: String {
        switch self {
        case .easy: return "簡単"
        case .medium: return "普通"
        case .hard: return "難しい"
        case .expert: return "専門的"
        }
    }
}

/// Represents the level of personalization applied to recommendations and analysis
enum PersonalizationLevel: String, CaseIterable, Codable {
    case basic = "basic"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case maximum = "maximum"
    case expert = "expert"
    
    var displayName: String {
        switch self {
        case .basic: return "基本"
        case .intermediate: return "中級"
        case .advanced: return "上級"
        case .maximum: return "最大"
        case .expert: return "専門家"
        }
    }
    
    /// Returns true if this personalization level is available for GoalTracker
    var isGoalTrackerLevel: Bool {
        return [.basic, .intermediate, .advanced, .maximum].contains(self)
    }
    
    /// Returns true if this personalization level is available for InsightEngine
    var isInsightEngineLevel: Bool {
        return [.basic, .intermediate, .advanced, .expert].contains(self)
    }
}

/// Comparison operators used in data analysis and filtering
enum ComparisonOperator: String, CaseIterable, Codable {
    case lessThan = "less_than"
    case lessThanOrEqual = "less_than_or_equal"
    case equal = "equal"
    case greaterThanOrEqual = "greater_than_or_equal"
    case greaterThan = "greater_than"
    case notEqual = "not_equal"
    
    var symbol: String {
        switch self {
        case .lessThan: return "<"
        case .lessThanOrEqual: return "<="
        case .equal: return "=="
        case .greaterThanOrEqual: return ">="
        case .greaterThan: return ">"
        case .notEqual: return "!="
        }
    }
    
    var displayName: String {
        switch self {
        case .lessThan: return "未満"
        case .lessThanOrEqual: return "以下"
        case .equal: return "等しい"
        case .greaterThanOrEqual: return "以上"
        case .greaterThan: return "より大きい"
        case .notEqual: return "等しくない"
        }
    }
    
    /// Evaluates the comparison between two values
    func evaluate(_ lhs: Double, _ rhs: Double) -> Bool {
        switch self {
        case .lessThan: return lhs < rhs
        case .lessThanOrEqual: return lhs <= rhs
        case .equal: return abs(lhs - rhs) < 0.0001 // Handle floating point precision
        case .greaterThanOrEqual: return lhs >= rhs
        case .greaterThan: return lhs > rhs
        case .notEqual: return abs(lhs - rhs) >= 0.0001
        }
    }
}

/// Severity levels for various domain objects
enum Severity: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .critical: return "重大"
        }
    }
    
    var priority: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
}


/// Priority levels for recommendations
enum RecommendationPriority: String, CaseIterable, Codable {
    case critical = "critical"
    case high = "high"
    case medium = "medium"
    case low = "low"
    case informational = "informational"
    
    var displayName: String {
        switch self {
        case .critical: return "緊急"
        case .high: return "高"
        case .medium: return "中"
        case .low: return "低"
        case .informational: return "情報"
        }
    }
    
    var priority: Int {
        switch self {
        case .critical: return 5
        case .high: return 4
        case .medium: return 3
        case .low: return 2
        case .informational: return 1
        }
    }
    
    /// Returns true if this priority level is available for GoalTracker (excludes informational)
    var isGoalTrackerPriority: Bool {
        return [.critical, .high, .medium, .low].contains(self)
    }
}

/// Categories for health recommendations
enum RecommendationCategory: String, CaseIterable, Codable {
    // Common categories
    case nutrition = "nutrition"
    case exercise = "exercise"
    case lifestyle = "lifestyle"
    case sleep = "sleep"
    case stress = "stress"
    
    // GoalTracker specific
    case mindset = "mindset"
    case tracking = "tracking"
    case social = "social"
    
    // InsightEngine specific
    case diet = "diet"
    case medical = "medical"
    case monitoring = "monitoring"
    case education = "education"
    
    var displayName: String {
        switch self {
        case .nutrition: return "栄養"
        case .exercise: return "運動"
        case .lifestyle: return "ライフスタイル"
        case .mindset: return "マインドセット"
        case .tracking: return "トラッキング"
        case .social: return "ソーシャル"
        case .diet: return "食事"
        case .sleep: return "睡眠"
        case .stress: return "ストレス"
        case .medical: return "医療"
        case .monitoring: return "モニタリング"
        case .education: return "教育"
        }
    }
    
    /// Returns true if this category is available for GoalTracker
    var isGoalTrackerCategory: Bool {
        return [.nutrition, .exercise, .lifestyle, .mindset, .tracking, .social].contains(self)
    }
    
    /// Returns true if this category is available for InsightEngine
    var isInsightEngineCategory: Bool {
        return [.lifestyle, .diet, .exercise, .sleep, .stress, .medical, .monitoring, .education].contains(self)
    }
}