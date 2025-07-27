import Foundation

protocol GoalTrackerProtocol {
    
    // MARK: - Progress Analysis
    
    func analyzeGoalProgress(
        for goal: Goal,
        using healthRecords: [HealthRecordProtocol]
    ) async throws -> GoalProgressDetail
    
    func analyzeMultipleGoals(
        goals: [Goal],
        using healthRecords: [HealthRecordProtocol]
    ) async throws -> [GoalProgressDetail]
    
    func calculateAchievabilityScore(
        for goal: Goal,
        progressHistory: [GoalProgressSnapshot]
    ) async throws -> Double
    
    // MARK: - Milestone Management
    
    func generateMilestones(
        for goal: Goal,
        strategy: MilestoneStrategy
    ) async throws -> [Milestone]
    
    func updateMilestoneProgress(
        milestones: [Milestone],
        currentValue: Double
    ) -> [Milestone]
    
    func checkMilestoneCompletion(
        milestones: [Milestone],
        currentValue: Double
    ) -> [Milestone]
    
    // MARK: - Recommendation Generation
    
    func generateRecommendations(
        for goalProgress: GoalProgressDetail,
        userProfile: GoalUserProfile
    ) async throws -> [GoalRecommendation]
    
    func prioritizeRecommendations(
        recommendations: [GoalRecommendation],
        context: GoalContext
    ) -> [GoalRecommendation]
    
    func personalizeRecommendations(
        recommendations: [GoalRecommendation],
        for user: User
    ) async throws -> [GoalRecommendation]
    
    // MARK: - Trend Analysis
    
    func analyzeTrends(
        for goal: Goal,
        progressHistory: [GoalProgressSnapshot],
        timeframe: GoalTimeframe
    ) async throws -> GoalTrendAnalysis
    
    func predictGoalCompletion(
        based on: GoalProgressDetail,
        progressHistory: [GoalProgressSnapshot]
    ) async throws -> GoalCompletionPrediction
    
    func calculateProgressVelocity(
        from progressHistory: [GoalProgressSnapshot],
        timeframe: GoalTimeframe
    ) -> Double
    
    // MARK: - Risk Assessment
    
    func assessGoalRisks(
        for goalProgress: GoalProgressDetail,
        progressHistory: [GoalProgressSnapshot]
    ) async throws -> [GoalRiskFactor]
    
    func calculateSuccessProbability(
        for goal: Goal,
        based on: [GoalProgressSnapshot]
    ) async throws -> Double
    
    func identifyBarriers(
        for goal: Goal,
        progressHistory: [GoalProgressSnapshot]
    ) async throws -> [GoalBarrier]
    
    // MARK: - Motivation Analysis
    
    func calculateMotivationLevel(
        for goal: Goal,
        progressHistory: [GoalProgressSnapshot],
        recentActivity: [GoalActivity]
    ) async throws -> MotivationLevel
    
    func generateMotivationalContent(
        for goal: Goal,
        motivationLevel: MotivationLevel,
        userPreferences: MotivationPreferences
    ) async throws -> [MotivationalContent]
    
    func trackEngagement(
        for goal: Goal,
        activities: [GoalActivity]
    ) async throws -> GoalEngagementMetrics
    
    // MARK: - Goal Optimization
    
    func optimizeGoalTarget(
        for goal: Goal,
        based on: [GoalProgressSnapshot],
        constraints: GoalConstraints
    ) async throws -> GoalOptimizationSuggestion
    
    func suggestTimelineAdjustment(
        for goal: Goal,
        currentProgress: GoalProgressDetail
    ) async throws -> TimelineAdjustmentSuggestion
    
    func calculateOptimalDailyTarget(
        for goal: Goal,
        currentProgress: Double,
        remainingDays: Int
    ) -> Double
    
    // MARK: - Comparative Analysis
    
    func compareGoalPerformance(
        goals: [Goal],
        metric: GoalComparisonMetric
    ) async throws -> GoalComparisonResult
    
    func benchmarkAgainstSimilarGoals(
        goal: Goal,
        similarGoals: [Goal]
    ) async throws -> GoalBenchmarkResult
    
    func generateInsights(
        from comparisons: [GoalComparisonResult]
    ) async throws -> [GoalInsight]
}

// MARK: - Supporting Types

enum MilestoneStrategy: String, CaseIterable {
    case linear = "linear"
    case exponential = "exponential"
    case custom = "custom"
    case adaptive = "adaptive"
    
    var displayName: String {
        switch self {
        case .linear: return "線形分割"
        case .exponential: return "指数的増加"
        case .custom: return "カスタム"
        case .adaptive: return "適応的"
        }
    }
}

struct GoalProgressSnapshot: Codable {
    let goalId: UUID
    let timestamp: Date
    let value: Double
    let progress: Double
    let velocityChange: Double
    let milestoneReached: Bool
    let source: SnapshotSource
    
    init(goalId: UUID, timestamp: Date, value: Double, progress: Double, velocityChange: Double, milestoneReached: Bool, source: SnapshotSource) {
        self.goalId = goalId
        self.timestamp = timestamp
        self.value = value
        self.progress = progress
        self.velocityChange = velocityChange
        self.milestoneReached = milestoneReached
        self.source = source
    }
}

enum SnapshotSource: String, CaseIterable, Codable {
    case automatic = "automatic"
    case manual = "manual"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .automatic: return "自動"
        case .manual: return "手動"
        case .system: return "システム"
        }
    }
}

struct GoalUserProfile: Codable {
    let userId: UUID
    let age: Int
    let fitnessLevel: FitnessLevel
    let experienceLevel: ExperienceLevel
    let preferences: GoalPreferences
    let constraints: [GoalConstraint]
    let motivationFactors: [MotivationFactor]
    
    init(userId: UUID, age: Int, fitnessLevel: FitnessLevel, experienceLevel: ExperienceLevel, preferences: GoalPreferences, constraints: [GoalConstraint], motivationFactors: [MotivationFactor]) {
        self.userId = userId
        self.age = age
        self.fitnessLevel = fitnessLevel
        self.experienceLevel = experienceLevel
        self.preferences = preferences
        self.constraints = constraints
        self.motivationFactors = motivationFactors
    }
}

enum FitnessLevel: String, CaseIterable, Codable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case expert = "expert"
    
    var displayName: String {
        switch self {
        case .beginner: return "初心者"
        case .intermediate: return "中級者"
        case .advanced: return "上級者"
        case .expert: return "エキスパート"
        }
    }
}

enum ExperienceLevel: String, CaseIterable, Codable {
    case novice = "novice"
    case experienced = "experienced"
    case veteran = "veteran"
    
    var displayName: String {
        switch self {
        case .novice: return "初心者"
        case .experienced: return "経験者"
        case .veteran: return "ベテラン"
        }
    }
}

struct GoalPreferences: Codable {
    let preferredMilestoneFrequency: MilestoneFrequency
    let motivationStyle: MotivationStyle
    let feedbackFrequency: FeedbackFrequency
    let challengeLevel: ChallengeLevel
    let socialSharing: Bool
    let reminderPreferences: ReminderPreferences
    
    init(preferredMilestoneFrequency: MilestoneFrequency, motivationStyle: MotivationStyle, feedbackFrequency: FeedbackFrequency, challengeLevel: ChallengeLevel, socialSharing: Bool, reminderPreferences: ReminderPreferences) {
        self.preferredMilestoneFrequency = preferredMilestoneFrequency
        self.motivationStyle = motivationStyle
        self.feedbackFrequency = feedbackFrequency
        self.challengeLevel = challengeLevel
        self.socialSharing = socialSharing
        self.reminderPreferences = reminderPreferences
    }
}

enum MilestoneFrequency: String, CaseIterable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case biWeekly = "bi_weekly"
    case monthly = "monthly"
    
    var displayName: String {
        switch self {
        case .daily: return "毎日"
        case .weekly: return "週間"
        case .biWeekly: return "隔週"
        case .monthly: return "月間"
        }
    }
}

enum MotivationStyle: String, CaseIterable, Codable {
    case competitive = "competitive"
    case collaborative = "collaborative"
    case personal = "personal"
    case achievement = "achievement"
    
    var displayName: String {
        switch self {
        case .competitive: return "競争型"
        case .collaborative: return "協力型"
        case .personal: return "個人型"
        case .achievement: return "達成型"
        }
    }
}

enum FeedbackFrequency: String, CaseIterable, Codable {
    case realTime = "real_time"
    case daily = "daily"
    case weekly = "weekly"
    case onDemand = "on_demand"
    
    var displayName: String {
        switch self {
        case .realTime: return "リアルタイム"
        case .daily: return "日次"
        case .weekly: return "週次"
        case .onDemand: return "要求時"
        }
    }
}

enum ChallengeLevel: String, CaseIterable, Codable {
    case conservative = "conservative"
    case moderate = "moderate"
    case aggressive = "aggressive"
    case extreme = "extreme"
    
    var displayName: String {
        switch self {
        case .conservative: return "控えめ"
        case .moderate: return "適度"
        case .aggressive: return "積極的"
        case .extreme: return "極端"
        }
    }
}

struct ReminderPreferences: Codable {
    let enabled: Bool
    let frequency: ReminderFrequency
    let preferredTimes: [ReminderTime]
    let style: ReminderStyle
    
    init(enabled: Bool, frequency: ReminderFrequency, preferredTimes: [ReminderTime], style: ReminderStyle) {
        self.enabled = enabled
        self.frequency = frequency
        self.preferredTimes = preferredTimes
        self.style = style
    }
}

enum ReminderFrequency: String, CaseIterable, Codable {
    case never = "never"
    case daily = "daily"
    case weekly = "weekly"
    case milestoneOnly = "milestone_only"
    
    var displayName: String {
        switch self {
        case .never: return "なし"
        case .daily: return "毎日"
        case .weekly: return "週間"
        case .milestoneOnly: return "マイルストーンのみ"
        }
    }
}

struct ReminderTime: Codable {
    let hour: Int
    let minute: Int
    let timeZone: String
    
    init(hour: Int, minute: Int, timeZone: String) {
        self.hour = hour
        self.minute = minute
        self.timeZone = timeZone
    }
}

enum ReminderStyle: String, CaseIterable, Codable {
    case gentle = "gentle"
    case motivational = "motivational"
    case urgent = "urgent"
    case celebratory = "celebratory"
    
    var displayName: String {
        switch self {
        case .gentle: return "穏やか"
        case .motivational: return "励まし"
        case .urgent: return "緊急"
        case .celebratory: return "お祝い"
        }
    }
}

struct GoalConstraint: Codable, Identifiable {
    let id: UUID
    let type: ConstraintType
    let description: String
    let impact: Double // 0.0 to 1.0
    let isTemporary: Bool
    let startDate: Date?
    let endDate: Date?
    
    init(type: ConstraintType, description: String, impact: Double, isTemporary: Bool, startDate: Date? = nil, endDate: Date? = nil) {
        self.id = UUID()
        self.type = type
        self.description = description
        self.impact = impact
        self.isTemporary = isTemporary
        self.startDate = startDate
        self.endDate = endDate
    }
}

enum ConstraintType: String, CaseIterable, Codable {
    case time = "time"
    case physical = "physical"
    case financial = "financial"
    case social = "social"
    case environmental = "environmental"
    
    var displayName: String {
        switch self {
        case .time: return "時間"
        case .physical: return "身体的"
        case .financial: return "経済的"
        case .social: return "社会的"
        case .environmental: return "環境的"
        }
    }
}

struct MotivationFactor: Codable, Identifiable {
    let id: UUID
    let type: MotivationFactorType
    let strength: Double // 0.0 to 1.0
    let description: String
    let isPersonal: Bool
    
    init(type: MotivationFactorType, strength: Double, description: String, isPersonal: Bool) {
        self.id = UUID()
        self.type = type
        self.strength = strength
        self.description = description
        self.isPersonal = isPersonal
    }
}

enum MotivationFactorType: String, CaseIterable, Codable {
    case health = "health"
    case appearance = "appearance"
    case performance = "performance"
    case social = "social"
    case competition = "competition"
    case personal = "personal"
    
    var displayName: String {
        switch self {
        case .health: return "健康"
        case .appearance: return "外見"
        case .performance: return "パフォーマンス"
        case .social: return "社会的"
        case .competition: return "競争"
        case .personal: return "個人的"
        }
    }
}

struct GoalContext: Codable {
    let currentDate: Date
    let seasonality: Seasonality
    let userLifePhase: LifePhase
    let externalFactors: [ExternalFactor]
    let availableResources: [Resource]
    
    init(currentDate: Date, seasonality: Seasonality, userLifePhase: LifePhase, externalFactors: [ExternalFactor], availableResources: [Resource]) {
        self.currentDate = currentDate
        self.seasonality = seasonality
        self.userLifePhase = userLifePhase
        self.externalFactors = externalFactors
        self.availableResources = availableResources
    }
}

enum Seasonality: String, CaseIterable, Codable {
    case spring = "spring"
    case summer = "summer"
    case autumn = "autumn"
    case winter = "winter"
    
    var displayName: String {
        switch self {
        case .spring: return "春"
        case .summer: return "夏"
        case .autumn: return "秋"
        case .winter: return "冬"
        }
    }
}

enum LifePhase: String, CaseIterable, Codable {
    case student = "student"
    case professional = "professional"
    case parent = "parent"
    case retired = "retired"
    
    var displayName: String {
        switch self {
        case .student: return "学生"
        case .professional: return "社会人"
        case .parent: return "子育て中"
        case .retired: return "退職後"
        }
    }
}

struct ExternalFactor: Codable, Identifiable {
    let id: UUID
    let type: ExternalFactorType
    let impact: Double // -1.0 to 1.0
    let description: String
    let duration: ExternalFactorDuration
    
    init(type: ExternalFactorType, impact: Double, description: String, duration: ExternalFactorDuration) {
        self.id = UUID()
        self.type = type
        self.impact = impact
        self.description = description
        self.duration = duration
    }
}

enum ExternalFactorType: String, CaseIterable, Codable {
    case weather = "weather"
    case workload = "workload"
    case social = "social"
    case health = "health"
    case travel = "travel"
    
    var displayName: String {
        switch self {
        case .weather: return "天候"
        case .workload: return "仕事量"
        case .social: return "社会的要因"
        case .health: return "健康状態"
        case .travel: return "旅行"
        }
    }
}

enum ExternalFactorDuration: String, CaseIterable, Codable {
    case temporary = "temporary"
    case shortTerm = "short_term"
    case longTerm = "long_term"
    case permanent = "permanent"
    
    var displayName: String {
        switch self {
        case .temporary: return "一時的"
        case .shortTerm: return "短期"
        case .longTerm: return "長期"
        case .permanent: return "永続的"
        }
    }
}

struct Resource: Codable, Identifiable {
    let id: UUID
    let type: ResourceType
    let name: String
    let availability: Double // 0.0 to 1.0
    let quality: Double // 0.0 to 1.0
    let cost: ResourceCost
    
    init(type: ResourceType, name: String, availability: Double, quality: Double, cost: ResourceCost) {
        self.id = UUID()
        self.type = type
        self.name = name
        self.availability = availability
        self.quality = quality
        self.cost = cost
    }
}

enum ResourceType: String, CaseIterable, Codable {
    case time = "time"
    case equipment = "equipment"
    case knowledge = "knowledge"
    case support = "support"
    case facility = "facility"
    
    var displayName: String {
        switch self {
        case .time: return "時間"
        case .equipment: return "設備"
        case .knowledge: return "知識"
        case .support: return "サポート"
        case .facility: return "施設"
        }
    }
}

enum ResourceCost: String, CaseIterable, Codable {
    case free = "free"
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .free: return "無料"
        case .low: return "低コスト"
        case .medium: return "中コスト"
        case .high: return "高コスト"
        }
    }
}

// Additional supporting types continued in next part due to length...

struct GoalCompletionPrediction: Codable {
    let goalId: UUID
    let predictedCompletionDate: Date?
    let confidenceLevel: Double // 0.0 to 1.0
    let successProbability: Double // 0.0 to 1.0
    let requiredDailyProgress: Double
    let alternativeScenarios: [CompletionScenario]
    
    init(goalId: UUID, predictedCompletionDate: Date?, confidenceLevel: Double, successProbability: Double, requiredDailyProgress: Double, alternativeScenarios: [CompletionScenario]) {
        self.goalId = goalId
        self.predictedCompletionDate = predictedCompletionDate
        self.confidenceLevel = confidenceLevel
        self.successProbability = successProbability
        self.requiredDailyProgress = requiredDailyProgress
        self.alternativeScenarios = alternativeScenarios
    }
}

struct CompletionScenario: Codable, Identifiable {
    let id: UUID
    let name: String
    let probability: Double
    let description: String
    let completionDate: Date
    let requiredChanges: [String]
    
    init(name: String, probability: Double, description: String, completionDate: Date, requiredChanges: [String]) {
        self.id = UUID()
        self.name = name
        self.probability = probability
        self.description = description
        self.completionDate = completionDate
        self.requiredChanges = requiredChanges
    }
}

struct GoalBarrier: Codable, Identifiable {
    let id: UUID
    let goalId: UUID
    let type: BarrierType
    let severity: BarrierSeverity
    let description: String
    let suggestedSolutions: [String]
    let isAddressable: Bool
    
    init(goalId: UUID, type: BarrierType, severity: BarrierSeverity, description: String, suggestedSolutions: [String], isAddressable: Bool) {
        self.id = UUID()
        self.goalId = goalId
        self.type = type
        self.severity = severity
        self.description = description
        self.suggestedSolutions = suggestedSolutions
        self.isAddressable = isAddressable
    }
}

enum BarrierType: String, CaseIterable, Codable {
    case motivation = "motivation"
    case knowledge = "knowledge"
    case resource = "resource"
    case time = "time"
    case physical = "physical"
    case environmental = "environmental"
    
    var displayName: String {
        switch self {
        case .motivation: return "モチベーション"
        case .knowledge: return "知識不足"
        case .resource: return "リソース不足"
        case .time: return "時間不足"
        case .physical: return "身体的制約"
        case .environmental: return "環境的制約"
        }
    }
}

enum BarrierSeverity: String, CaseIterable, Codable {
    case minor = "minor"
    case moderate = "moderate"
    case major = "major"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .minor: return "軽微"
        case .moderate: return "中程度"
        case .major: return "重大"
        case .critical: return "致命的"
        }
    }
}

struct GoalActivity: Codable {
    let goalId: UUID
    let activityType: ActivityType
    let timestamp: Date
    let duration: TimeInterval
    let engagement: Double // 0.0 to 1.0
    let result: ActivityResult
    
    init(goalId: UUID, activityType: ActivityType, timestamp: Date, duration: TimeInterval, engagement: Double, result: ActivityResult) {
        self.goalId = goalId
        self.activityType = activityType
        self.timestamp = timestamp
        self.duration = duration
        self.engagement = engagement
        self.result = result
    }
}

enum ActivityType: String, CaseIterable, Codable {
    case dataEntry = "data_entry"
    case progressReview = "progress_review"
    case recommendationView = "recommendation_view"
    case milestoneCheck = "milestone_check"
    case goalAdjustment = "goal_adjustment"
    
    var displayName: String {
        switch self {
        case .dataEntry: return "データ入力"
        case .progressReview: return "進捗確認"
        case .recommendationView: return "推奨事項確認"
        case .milestoneCheck: return "マイルストーン確認"
        case .goalAdjustment: return "目標調整"
        }
    }
}

enum ActivityResult: String, CaseIterable, Codable {
    case positive = "positive"
    case neutral = "neutral"
    case negative = "negative"
    case abandoned = "abandoned"
    
    var displayName: String {
        switch self {
        case .positive: return "ポジティブ"
        case .neutral: return "中立"
        case .negative: return "ネガティブ"
        case .abandoned: return "中断"
        }
    }
}

struct MotivationalContent: Codable, Identifiable {
    let id: UUID
    let goalId: UUID
    let contentType: MotivationalContentType
    let title: String
    let message: String
    let actionable: Bool
    let personalizedElements: [String]
    let deliveryTime: Date?
    
    init(goalId: UUID, contentType: MotivationalContentType, title: String, message: String, actionable: Bool, personalizedElements: [String], deliveryTime: Date? = nil) {
        self.id = UUID()
        self.goalId = goalId
        self.contentType = contentType
        self.title = title
        self.message = message
        self.actionable = actionable
        self.personalizedElements = personalizedElements
        self.deliveryTime = deliveryTime
    }
}

enum MotivationalContentType: String, CaseIterable, Codable {
    case encouragement = "encouragement"
    case celebration = "celebration"
    case reminder = "reminder"
    case challenge = "challenge"
    case insight = "insight"
    case tip = "tip"
    
    var displayName: String {
        switch self {
        case .encouragement: return "励まし"
        case .celebration: return "お祝い"
        case .reminder: return "リマインダー"
        case .challenge: return "チャレンジ"
        case .insight: return "洞察"
        case .tip: return "ヒント"
        }
    }
}

struct MotivationPreferences: Codable {
    let preferredContentTypes: [MotivationalContentType]
    let frequency: MotivationFrequency
    let tone: MotivationTone
    let personalizationLevel: PersonalizationLevel
    
    init(preferredContentTypes: [MotivationalContentType], frequency: MotivationFrequency, tone: MotivationTone, personalizationLevel: PersonalizationLevel) {
        self.preferredContentTypes = preferredContentTypes
        self.frequency = frequency
        self.tone = tone
        self.personalizationLevel = personalizationLevel
    }
}

enum MotivationFrequency: String, CaseIterable, Codable {
    case minimal = "minimal"
    case moderate = "moderate"
    case high = "high"
    case maximum = "maximum"
    
    var displayName: String {
        switch self {
        case .minimal: return "最小限"
        case .moderate: return "適度"
        case .high: return "高頻度"
        case .maximum: return "最大限"
        }
    }
}

enum MotivationTone: String, CaseIterable, Codable {
    case gentle = "gentle"
    case enthusiastic = "enthusiastic"
    case professional = "professional"
    case friendly = "friendly"
    case humorous = "humorous"
    
    var displayName: String {
        switch self {
        case .gentle: return "穏やか"
        case .enthusiastic: return "熱心"
        case .professional: return "プロフェッショナル"
        case .friendly: return "フレンドリー"
        case .humorous: return "ユーモラス"
        }
    }
}


struct GoalEngagementMetrics: Codable {
    let goalId: UUID
    let overallEngagement: Double // 0.0 to 1.0
    let dailyEngagement: Double
    let weeklyEngagement: Double
    let monthlyEngagement: Double
    let engagementTrend: TrendDirection
    let activityFrequency: Double
    let sessionDuration: TimeInterval
    let completionRate: Double
    
    init(goalId: UUID, overallEngagement: Double, dailyEngagement: Double, weeklyEngagement: Double, monthlyEngagement: Double, engagementTrend: TrendDirection, activityFrequency: Double, sessionDuration: TimeInterval, completionRate: Double) {
        self.goalId = goalId
        self.overallEngagement = overallEngagement
        self.dailyEngagement = dailyEngagement
        self.weeklyEngagement = weeklyEngagement
        self.monthlyEngagement = monthlyEngagement
        self.engagementTrend = engagementTrend
        self.activityFrequency = activityFrequency
        self.sessionDuration = sessionDuration
        self.completionRate = completionRate
    }
}

struct GoalConstraints: Codable {
    let timeConstraints: [TimeConstraint]
    let resourceConstraints: [ResourceConstraint]
    let physicalConstraints: [PhysicalConstraint]
    let environmentalConstraints: [EnvironmentalConstraint]
    
    init(timeConstraints: [TimeConstraint], resourceConstraints: [ResourceConstraint], physicalConstraints: [PhysicalConstraint], environmentalConstraints: [EnvironmentalConstraint]) {
        self.timeConstraints = timeConstraints
        self.resourceConstraints = resourceConstraints
        self.physicalConstraints = physicalConstraints
        self.environmentalConstraints = environmentalConstraints
    }
}

struct TimeConstraint: Codable, Identifiable {
    let id: UUID
    let type: TimeConstraintType
    let maxDailyTime: TimeInterval
    let availableTimeSlots: [TimeSlot]
    let flexibility: Double // 0.0 to 1.0
    
    init(type: TimeConstraintType, maxDailyTime: TimeInterval, availableTimeSlots: [TimeSlot], flexibility: Double) {
        self.id = UUID()
        self.type = type
        self.maxDailyTime = maxDailyTime
        self.availableTimeSlots = availableTimeSlots
        self.flexibility = flexibility
    }
}

enum TimeConstraintType: String, CaseIterable, Codable {
    case work = "work"
    case family = "family"
    case sleep = "sleep"
    case commute = "commute"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .work: return "仕事"
        case .family: return "家族"
        case .sleep: return "睡眠"
        case .commute: return "通勤"
        case .other: return "その他"
        }
    }
}

struct TimeSlot: Codable {
    let startTime: Date
    let endTime: Date
    let recurring: Bool
    let priority: TimeSlotPriority
    
    init(startTime: Date, endTime: Date, recurring: Bool, priority: TimeSlotPriority) {
        self.startTime = startTime
        self.endTime = endTime
        self.recurring = recurring
        self.priority = priority
    }
}

enum TimeSlotPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .critical: return "重要"
        }
    }
}

struct ResourceConstraint: Codable, Identifiable {
    let id: UUID
    let resourceType: ResourceType
    let limitation: ResourceLimitation
    let impact: Double // 0.0 to 1.0
    
    init(resourceType: ResourceType, limitation: ResourceLimitation, impact: Double) {
        self.id = UUID()
        self.resourceType = resourceType
        self.limitation = limitation
        self.impact = impact
    }
}

enum ResourceLimitation: String, CaseIterable, Codable {
    case unavailable = "unavailable"
    case limited = "limited"
    case expensive = "expensive"
    case lowQuality = "low_quality"
    
    var displayName: String {
        switch self {
        case .unavailable: return "利用不可"
        case .limited: return "制限あり"
        case .expensive: return "高コスト"
        case .lowQuality: return "低品質"
        }
    }
}

struct PhysicalConstraint: Codable, Identifiable {
    let id: UUID
    let type: PhysicalConstraintType
    let severity: ConstraintSeverity
    let description: String
    let adaptations: [String]
    
    init(type: PhysicalConstraintType, severity: ConstraintSeverity, description: String, adaptations: [String]) {
        self.id = UUID()
        self.type = type
        self.severity = severity
        self.description = description
        self.adaptations = adaptations
    }
}

enum PhysicalConstraintType: String, CaseIterable, Codable {
    case injury = "injury"
    case disability = "disability"
    case illness = "illness"
    case age = "age"
    case fitness = "fitness"
    
    var displayName: String {
        switch self {
        case .injury: return "怪我"
        case .disability: return "障害"
        case .illness: return "病気"
        case .age: return "年齢"
        case .fitness: return "体力"
        }
    }
}

enum ConstraintSeverity: String, CaseIterable, Codable {
    case mild = "mild"
    case moderate = "moderate"
    case severe = "severe"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .mild: return "軽度"
        case .moderate: return "中程度"
        case .severe: return "重度"
        case .critical: return "重篤"
        }
    }
}

struct EnvironmentalConstraint: Codable, Identifiable {
    let id: UUID
    let type: EnvironmentalConstraintType
    let impact: Double // 0.0 to 1.0
    let seasonal: Bool
    let mitigation: [String]
    
    init(type: EnvironmentalConstraintType, impact: Double, seasonal: Bool, mitigation: [String]) {
        self.id = UUID()
        self.type = type
        self.impact = impact
        self.seasonal = seasonal
        self.mitigation = mitigation
    }
}

enum EnvironmentalConstraintType: String, CaseIterable, Codable {
    case weather = "weather"
    case location = "location"
    case facilities = "facilities"
    case safety = "safety"
    case noise = "noise"
    
    var displayName: String {
        switch self {
        case .weather: return "天候"
        case .location: return "場所"
        case .facilities: return "施設"
        case .safety: return "安全性"
        case .noise: return "騒音"
        }
    }
}

struct GoalOptimizationSuggestion: Codable {
    let goalId: UUID
    let suggestedTarget: Double
    let reasoningForDecrease: String?
    let reasoningForIncrease: String?
    let confidenceLevel: Double // 0.0 to 1.0
    let expectedOutcome: OptimizationOutcome
    let implementationSteps: [String]
    
    init(goalId: UUID, suggestedTarget: Double, reasoningForDecrease: String?, reasoningForIncrease: String?, confidenceLevel: Double, expectedOutcome: OptimizationOutcome, implementationSteps: [String]) {
        self.goalId = goalId
        self.suggestedTarget = suggestedTarget
        self.reasoningForDecrease = reasoningForDecrease
        self.reasoningForIncrease = reasoningForIncrease
        self.confidenceLevel = confidenceLevel
        self.expectedOutcome = expectedOutcome
        self.implementationSteps = implementationSteps
    }
}

enum OptimizationOutcome: String, CaseIterable, Codable {
    case targetReduction = "target_reduction"
    case targetIncrease = "target_increase"
    case timelineExtension = "timeline_extension"
    case strategyChange = "strategy_change"
    
    var displayName: String {
        switch self {
        case .targetReduction: return "目標値減少"
        case .targetIncrease: return "目標値増加"
        case .timelineExtension: return "期限延長"
        case .strategyChange: return "戦略変更"
        }
    }
}

struct TimelineAdjustmentSuggestion: Codable {
    let goalId: UUID
    let suggestedDeadline: Date
    let adjustmentType: TimelineAdjustmentType
    let reasoning: String
    let confidenceLevel: Double // 0.0 to 1.0
    let estimatedImpact: Double // 0.0 to 1.0
    
    init(goalId: UUID, suggestedDeadline: Date, adjustmentType: TimelineAdjustmentType, reasoning: String, confidenceLevel: Double, estimatedImpact: Double) {
        self.goalId = goalId
        self.suggestedDeadline = suggestedDeadline
        self.adjustmentType = adjustmentType
        self.reasoning = reasoning
        self.confidenceLevel = confidenceLevel
        self.estimatedImpact = estimatedImpact
    }
}

enum TimelineAdjustmentType: String, CaseIterable, Codable {
    case extend = "extend"
    case compress = "compress"
    case redistribute = "redistribute"
    
    var displayName: String {
        switch self {
        case .extend: return "延長"
        case .compress: return "短縮"
        case .redistribute: return "再配分"
        }
    }
}

struct GoalComparisonResult: Codable {
    let comparedGoals: [UUID]
    let metric: GoalComparisonMetric
    let rankings: [GoalRanking]
    let insights: [String]
    let generatedAt: Date
    
    init(comparedGoals: [UUID], metric: GoalComparisonMetric, rankings: [GoalRanking], insights: [String]) {
        self.comparedGoals = comparedGoals
        self.metric = metric
        self.rankings = rankings
        self.insights = insights
        self.generatedAt = Date()
    }
}

enum GoalComparisonMetric: String, CaseIterable, Codable {
    case progress = "progress"
    case velocity = "velocity"
    case consistency = "consistency"
    case achievability = "achievability"
    
    var displayName: String {
        switch self {
        case .progress: return "進捗"
        case .velocity: return "速度"
        case .consistency: return "一貫性"
        case .achievability: return "達成可能性"
        }
    }
}

struct GoalRanking: Codable, Identifiable {
    let id: UUID
    let goalId: UUID
    let rank: Int
    let score: Double
    let percentile: Double
    
    init(goalId: UUID, rank: Int, score: Double, percentile: Double) {
        self.id = UUID()
        self.goalId = goalId
        self.rank = rank
        self.score = score
        self.percentile = percentile
    }
}

struct GoalBenchmarkResult: Codable {
    let targetGoalId: UUID
    let comparisonGoals: [UUID]
    let percentileRank: Double // 0.0 to 100.0
    let averagePerformance: Double // 0.0 to 1.0
    let topPerformerInsights: [String]
    let improvementSuggestions: [String]
    
    init(targetGoalId: UUID, comparisonGoals: [UUID], percentileRank: Double, averagePerformance: Double, topPerformerInsights: [String], improvementSuggestions: [String]) {
        self.targetGoalId = targetGoalId
        self.comparisonGoals = comparisonGoals
        self.percentileRank = percentileRank
        self.averagePerformance = averagePerformance
        self.topPerformerInsights = topPerformerInsights
        self.improvementSuggestions = improvementSuggestions
    }
}

struct GoalInsight: Codable, Identifiable {
    let id: UUID
    let title: String
    let description: String
    let confidence: Double // 0.0 to 1.0
    let actionable: Bool
    let category: GoalInsightCategory?
    let relatedGoals: [UUID]
    
    init(title: String, description: String, confidence: Double, actionable: Bool, category: GoalInsightCategory? = nil, relatedGoals: [UUID] = []) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.confidence = confidence
        self.actionable = actionable
        self.category = category
        self.relatedGoals = relatedGoals
    }
}

enum GoalInsightCategory: String, CaseIterable, Codable {
    case performance = "performance"
    case patterns = "patterns"
    case risks = "risks"
    case opportunities = "opportunities"
    case behavioral = "behavioral"
    
    var displayName: String {
        switch self {
        case .performance: return "パフォーマンス"
        case .patterns: return "パターン"
        case .risks: return "リスク"
        case .opportunities: return "機会"
        case .behavioral: return "行動"
        }
    }
}