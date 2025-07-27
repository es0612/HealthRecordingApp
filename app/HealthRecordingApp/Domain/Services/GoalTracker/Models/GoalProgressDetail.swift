import Foundation

struct GoalProgressDetail: Codable {
    let goalId: UUID
    let goalType: HealthDataType
    let targetValue: Double
    let currentValue: Double
    let progress: Double // 0.0 to 1.0
    let progressPercentage: Double // 0.0 to 100.0
    let remainingValue: Double
    let remainingDays: Int
    let dailyRequiredProgress: Double
    let isOnTrack: Bool
    let achievabilityScore: Double // 0.0 to 1.0
    let motivationLevel: MotivationLevel
    let milestones: [Milestone]
    let recommendations: [GoalRecommendation]
    let trendAnalysis: GoalTrendAnalysis?
    
    init(
        goalId: UUID,
        goalType: HealthDataType,
        targetValue: Double,
        currentValue: Double,
        progress: Double,
        progressPercentage: Double,
        remainingValue: Double,
        remainingDays: Int,
        dailyRequiredProgress: Double,
        isOnTrack: Bool,
        achievabilityScore: Double,
        motivationLevel: MotivationLevel,
        milestones: [Milestone],
        recommendations: [GoalRecommendation],
        trendAnalysis: GoalTrendAnalysis? = nil
    ) {
        self.goalId = goalId
        self.goalType = goalType
        self.targetValue = targetValue
        self.currentValue = currentValue
        self.progress = progress
        self.progressPercentage = progressPercentage
        self.remainingValue = remainingValue
        self.remainingDays = remainingDays
        self.dailyRequiredProgress = dailyRequiredProgress
        self.isOnTrack = isOnTrack
        self.achievabilityScore = achievabilityScore
        self.motivationLevel = motivationLevel
        self.milestones = milestones
        self.recommendations = recommendations
        self.trendAnalysis = trendAnalysis
    }
}

struct Milestone: Codable, Identifiable {
    let id: UUID
    let goalId: UUID
    let title: String
    let description: String
    let targetValue: Double
    let currentValue: Double
    let progress: Double
    let isCompleted: Bool
    let completedDate: Date?
    let targetDate: Date
    let priority: MilestonePriority
    let category: MilestoneCategory
    
    init(
        goalId: UUID,
        title: String,
        description: String,
        targetValue: Double,
        currentValue: Double,
        progress: Double,
        isCompleted: Bool,
        completedDate: Date? = nil,
        targetDate: Date,
        priority: MilestonePriority,
        category: MilestoneCategory
    ) {
        self.id = UUID()
        self.goalId = goalId
        self.title = title
        self.description = description
        self.targetValue = targetValue
        self.currentValue = currentValue
        self.progress = progress
        self.isCompleted = isCompleted
        self.completedDate = completedDate
        self.targetDate = targetDate
        self.priority = priority
        self.category = category
    }
}

enum MotivationLevel: String, CaseIterable, Codable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .high: return "高い"
        case .medium: return "中程度"
        case .low: return "低い"
        case .critical: return "要注意"
        }
    }
    
    var emoji: String {
        switch self {
        case .high: return "🔥"
        case .medium: return "👍"
        case .low: return "😐"
        case .critical: return "⚠️"
        }
    }
}

enum MilestonePriority: String, CaseIterable, Codable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    var displayName: String {
        switch self {
        case .high: return "高"
        case .medium: return "中"
        case .low: return "低"
        }
    }
}

enum MilestoneCategory: String, CaseIterable, Codable {
    case weekly = "weekly"
    case monthly = "monthly"
    case custom = "custom"
    case achievement = "achievement"
    
    var displayName: String {
        switch self {
        case .weekly: return "週間目標"
        case .monthly: return "月間目標"
        case .custom: return "カスタム"
        case .achievement: return "達成目標"
        }
    }
}

struct GoalRecommendation: Codable, Identifiable {
    let id: UUID
    let goalId: UUID
    let type: RecommendationType
    let title: String
    let description: String
    let actionItems: [String]
    let priority: RecommendationPriority
    let estimatedImpact: Double // 0.0 to 1.0
    let difficulty: RecommendationDifficulty
    let category: RecommendationCategory
    let isPersonalized: Bool
    
    init(
        goalId: UUID,
        type: RecommendationType,
        title: String,
        description: String,
        actionItems: [String],
        priority: RecommendationPriority,
        estimatedImpact: Double,
        difficulty: RecommendationDifficulty,
        category: RecommendationCategory,
        isPersonalized: Bool = true
    ) {
        self.id = UUID()
        self.goalId = goalId
        self.type = type
        self.title = title
        self.description = description
        self.actionItems = actionItems
        self.priority = priority
        self.estimatedImpact = estimatedImpact
        self.difficulty = difficulty
        self.category = category
        self.isPersonalized = isPersonalized
    }
}

enum RecommendationType: String, CaseIterable, Codable {
    case behaviorChange = "behavior_change"
    case targetAdjustment = "target_adjustment"
    case timelineModification = "timeline_modification"
    case motivationalBoost = "motivational_boost"
    case resourceAllocation = "resource_allocation"
    
    var displayName: String {
        switch self {
        case .behaviorChange: return "行動変容"
        case .targetAdjustment: return "目標調整"
        case .timelineModification: return "期限変更"
        case .motivationalBoost: return "モチベーション向上"
        case .resourceAllocation: return "リソース配分"
        }
    }
}


struct GoalTrendAnalysis: Codable {
    let goalId: UUID
    let timeframe: GoalTimeframe
    let progressTrend: TrendDirection
    let velocityTrend: TrendDirection
    let averageProgress: Double
    let progressVelocity: Double // Progress per day
    let projectedCompletion: Date?
    let confidenceLevel: Double // 0.0 to 1.0
    let riskFactors: [GoalRiskFactor]
    let successProbability: Double // 0.0 to 1.0
    
    init(
        goalId: UUID,
        timeframe: GoalTimeframe,
        progressTrend: TrendDirection,
        velocityTrend: TrendDirection,
        averageProgress: Double,
        progressVelocity: Double,
        projectedCompletion: Date?,
        confidenceLevel: Double,
        riskFactors: [GoalRiskFactor],
        successProbability: Double
    ) {
        self.goalId = goalId
        self.timeframe = timeframe
        self.progressTrend = progressTrend
        self.velocityTrend = velocityTrend
        self.averageProgress = averageProgress
        self.progressVelocity = progressVelocity
        self.projectedCompletion = projectedCompletion
        self.confidenceLevel = confidenceLevel
        self.riskFactors = riskFactors
        self.successProbability = successProbability
    }
}

enum GoalTimeframe: String, CaseIterable, Codable {
    case week = "week"
    case month = "month"
    case quarter = "quarter"
    case overall = "overall"
    
    var displayName: String {
        switch self {
        case .week: return "週間"
        case .month: return "月間"
        case .quarter: return "四半期"
        case .overall: return "全期間"
        }
    }
}

struct GoalRiskFactor: Codable, Identifiable {
    let id: UUID
    let goalId: UUID
    let type: GoalRiskType
    let severity: GoalRiskSeverity
    let description: String
    let impact: Double // 0.0 to 1.0
    let mitigation: String
    let isAddressable: Bool
    
    init(
        goalId: UUID,
        type: GoalRiskType,
        severity: GoalRiskSeverity,
        description: String,
        impact: Double,
        mitigation: String,
        isAddressable: Bool
    ) {
        self.id = UUID()
        self.goalId = goalId
        self.type = type
        self.severity = severity
        self.description = description
        self.impact = impact
        self.mitigation = mitigation
        self.isAddressable = isAddressable
    }
}

enum GoalRiskType: String, CaseIterable, Codable {
    case timeConstraint = "time_constraint"
    case unrealisticTarget = "unrealistic_target"
    case lackOfProgress = "lack_of_progress"
    case motivationDecline = "motivation_decline"
    case externalFactors = "external_factors"
    case resourceLimitation = "resource_limitation"
    
    var displayName: String {
        switch self {
        case .timeConstraint: return "時間制約"
        case .unrealisticTarget: return "非現実的目標"
        case .lackOfProgress: return "進捗不足"
        case .motivationDecline: return "モチベーション低下"
        case .externalFactors: return "外部要因"
        case .resourceLimitation: return "リソース制限"
        }
    }
}

enum GoalRiskSeverity: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "軽微"
        case .medium: return "中程度"
        case .high: return "高"
        case .critical: return "重要"
        }
    }
}