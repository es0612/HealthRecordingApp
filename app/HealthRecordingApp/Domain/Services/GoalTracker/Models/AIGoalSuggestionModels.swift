import Foundation

// MARK: - AI Goal Suggestion Core Models (Phase 2.2)

struct AIGoalSuggestion: Codable, Identifiable {
    let id: UUID
    let goalType: HealthDataType
    let suggestedTarget: Double
    let targetUnit: String
    let timeframe: GoalTimeframe
    let priority: AIGoalPriority
    let confidence: Double // 0.0 to 1.0
    let rationale: String
    let evidenceSource: [EvidenceSource]
    let personalizedFactors: [PersonalizationFactor]
    let estimatedDifficulty: DifficultyLevel
    let expectedBenefits: [ExpectedBenefit]
    let prerequisites: [GoalPrerequisite]
    let suggestedMilestones: [SuggestedMilestone]
    let adaptationStrategy: AdaptationStrategy
    let motivationTactics: [MotivationTactic]
    let generatedAt: Date
    
    init(goalType: HealthDataType, suggestedTarget: Double, targetUnit: String, timeframe: GoalTimeframe, priority: AIGoalPriority, confidence: Double, rationale: String, evidenceSource: [EvidenceSource], personalizedFactors: [PersonalizationFactor], estimatedDifficulty: DifficultyLevel, expectedBenefits: [ExpectedBenefit], prerequisites: [GoalPrerequisite] = [], suggestedMilestones: [SuggestedMilestone] = [], adaptationStrategy: AdaptationStrategy, motivationTactics: [MotivationTactic] = []) {
        self.id = UUID()
        self.goalType = goalType
        self.suggestedTarget = suggestedTarget
        self.targetUnit = targetUnit
        self.timeframe = timeframe
        self.priority = priority
        self.confidence = confidence
        self.rationale = rationale
        self.evidenceSource = evidenceSource
        self.personalizedFactors = personalizedFactors
        self.estimatedDifficulty = estimatedDifficulty
        self.expectedBenefits = expectedBenefits
        self.prerequisites = prerequisites
        self.suggestedMilestones = suggestedMilestones
        self.adaptationStrategy = adaptationStrategy
        self.motivationTactics = motivationTactics
        self.generatedAt = Date()
    }
}

enum AIGoalPriority: String, CaseIterable, Codable {
    case critical = "critical"      // 健康上重要
    case high = "high"             // 高優先度
    case medium = "medium"         // 中優先度
    case low = "low"               // 低優先度
    case optional = "optional"     // オプション
    
    var displayName: String {
        switch self {
        case .critical: return "重要"
        case .high: return "高"
        case .medium: return "中"
        case .low: return "低"
        case .optional: return "オプション"
        }
    }
    
    var color: String {
        switch self {
        case .critical: return "red"
        case .high: return "orange"
        case .medium: return "blue"
        case .low: return "green"
        case .optional: return "gray"
        }
    }
}

enum AIAnalysisDepth: String, CaseIterable, Codable {
    case basic = "basic"           // 基本分析
    case standard = "standard"     // 標準分析
    case comprehensive = "comprehensive" // 包括的分析
    case expert = "expert"         // 専門家レベル
    
    var displayName: String {
        switch self {
        case .basic: return "基本"
        case .standard: return "標準"
        case .comprehensive: return "包括的"
        case .expert: return "専門家"
        }
    }
}

enum AnalysisTimeframe: String, CaseIterable, Codable {
    case week = "week"
    case month = "month"
    case quarter = "quarter"
    case halfYear = "half_year"
    case year = "year"
    case all = "all"
    
    var displayName: String {
        switch self {
        case .week: return "1週間"
        case .month: return "1ヶ月"
        case .quarter: return "3ヶ月"
        case .halfYear: return "6ヶ月"
        case .year: return "1年"
        case .all: return "全期間"
        }
    }
    
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .halfYear: return 180
        case .year: return 365
        case .all: return Int.max
        }
    }
}

// MARK: - Health Data Pattern Analysis

struct HealthDataPatternAnalysis: Codable, Identifiable {
    let id: UUID
    let analysisTimeframe: AnalysisTimeframe
    let dataTypes: [HealthDataType]
    let patterns: [DataPattern]
    let trends: [DataTrend]
    let anomalies: [PatternAnomaly]
    let correlations: [PatternCorrelation]
    let seasonalEffects: [SeasonalEffect]
    let weeklyPatterns: [WeeklyPattern]
    let dailyPatterns: [DailyPattern]
    let insights: [PatternInsight]
    let recommendedFocusAreas: [HealthFocusArea]
    let dataQuality: DataQualityScore
    let analysisConfidence: Double
    let generatedAt: Date
    
    init(analysisTimeframe: AnalysisTimeframe, dataTypes: [HealthDataType], patterns: [DataPattern], trends: [DataTrend], anomalies: [PatternAnomaly], correlations: [PatternCorrelation], seasonalEffects: [SeasonalEffect], weeklyPatterns: [WeeklyPattern], dailyPatterns: [DailyPattern], insights: [PatternInsight], recommendedFocusAreas: [HealthFocusArea], dataQuality: DataQualityScore, analysisConfidence: Double) {
        self.id = UUID()
        self.analysisTimeframe = analysisTimeframe
        self.dataTypes = dataTypes
        self.patterns = patterns
        self.trends = trends
        self.anomalies = anomalies
        self.correlations = correlations
        self.seasonalEffects = seasonalEffects
        self.weeklyPatterns = weeklyPatterns
        self.dailyPatterns = dailyPatterns
        self.insights = insights
        self.recommendedFocusAreas = recommendedFocusAreas
        self.dataQuality = dataQuality
        self.analysisConfidence = analysisConfidence
        self.generatedAt = Date()
    }
}

struct DataPattern: Codable, Identifiable {
    let id: UUID
    let dataType: HealthDataType
    let patternType: PatternType
    let description: String
    let frequency: PatternFrequency
    let strength: Double // 0.0 to 1.0
    let confidence: Double
    let startDate: Date
    let endDate: Date?
    let associatedValues: [Double]
    let context: [PatternContext]
    
    init(dataType: HealthDataType, patternType: PatternType, description: String, frequency: PatternFrequency, strength: Double, confidence: Double, startDate: Date, endDate: Date? = nil, associatedValues: [Double] = [], context: [PatternContext] = []) {
        self.id = UUID()
        self.dataType = dataType
        self.patternType = patternType
        self.description = description
        self.frequency = frequency
        self.strength = strength
        self.confidence = confidence
        self.startDate = startDate
        self.endDate = endDate
        self.associatedValues = associatedValues
        self.context = context
    }
}

enum PatternType: String, CaseIterable, Codable {
    case increasing = "increasing"     // 増加傾向
    case decreasing = "decreasing"     // 減少傾向
    case cyclical = "cyclical"         // 周期的
    case seasonal = "seasonal"         // 季節的
    case plateau = "plateau"           // 停滞
    case spike = "spike"               // スパイク
    case drop = "drop"                 // 急降下
    case stable = "stable"             // 安定
    case volatile = "volatile"         // 変動的
    case progressive = "progressive"   // 段階的
    
    var displayName: String {
        switch self {
        case .increasing: return "増加傾向"
        case .decreasing: return "減少傾向"
        case .cyclical: return "周期的パターン"
        case .seasonal: return "季節的変動"
        case .plateau: return "停滞期"
        case .spike: return "急上昇"
        case .drop: return "急降下"
        case .stable: return "安定"
        case .volatile: return "変動的"
        case .progressive: return "段階的改善"
        }
    }
}

enum PatternFrequency: String, CaseIterable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    case yearly = "yearly"
    case irregular = "irregular"
    
    var displayName: String {
        switch self {
        case .daily: return "毎日"
        case .weekly: return "週次"
        case .monthly: return "月次"
        case .quarterly: return "四半期"
        case .yearly: return "年次"
        case .irregular: return "不定期"
        }
    }
}

// MARK: - Seasonal Goal Adjustments

struct SeasonalGoalAdjustment: Codable, Identifiable {
    let id: UUID
    let originalGoal: Goal
    let adjustedGoal: Goal
    let season: Season
    let adjustmentType: AdjustmentType
    let adjustmentRatio: Double
    let rationale: String
    let historicalEvidence: [SeasonalEvidence]
    let adaptationStrategy: SeasonalAdaptationStrategy
    let validityPeriod: DateInterval
    let confidence: Double
    let implementationGuide: ImplementationGuide
    
    init(originalGoal: Goal, adjustedGoal: Goal, season: Season, adjustmentType: AdjustmentType, adjustmentRatio: Double, rationale: String, historicalEvidence: [SeasonalEvidence], adaptationStrategy: SeasonalAdaptationStrategy, validityPeriod: DateInterval, confidence: Double, implementationGuide: ImplementationGuide) {
        self.id = UUID()
        self.originalGoal = originalGoal
        self.adjustedGoal = adjustedGoal
        self.season = season
        self.adjustmentType = adjustmentType
        self.adjustmentRatio = adjustmentRatio
        self.rationale = rationale
        self.historicalEvidence = historicalEvidence
        self.adaptationStrategy = adaptationStrategy
        self.validityPeriod = validityPeriod
        self.confidence = confidence
        self.implementationGuide = implementationGuide
    }
}

enum Season: String, CaseIterable, Codable {
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
    
    var emoji: String {
        switch self {
        case .spring: return "🌸"
        case .summer: return "☀️"
        case .autumn: return "🍂"
        case .winter: return "❄️"
        }
    }
    
    var months: [Int] {
        switch self {
        case .spring: return [3, 4, 5]
        case .summer: return [6, 7, 8]
        case .autumn: return [9, 10, 11]
        case .winter: return [12, 1, 2]
        }
    }
    
    var monthRange: ClosedRange<Int> {
        switch self {
        case .spring: return 3...5
        case .summer: return 6...8
        case .autumn: return 9...11
        case .winter: return 12...2 // Note: Winter spans year boundary
        }
    }
}

enum AdjustmentType: String, CaseIterable, Codable {
    case targetIncrease = "target_increase"
    case targetDecrease = "target_decrease"
    case timelineExtension = "timeline_extension"
    case timelineShortening = "timeline_shortening"
    case strategyChange = "strategy_change"
    case frequencyAdjustment = "frequency_adjustment"
    case motivationBoost = "motivation_boost"
    case difficultyReduction = "difficulty_reduction"
    
    var displayName: String {
        switch self {
        case .targetIncrease: return "目標値上方修正"
        case .targetDecrease: return "目標値下方修正"
        case .timelineExtension: return "期限延長"
        case .timelineShortening: return "期限短縮"
        case .strategyChange: return "戦略変更"
        case .frequencyAdjustment: return "頻度調整"
        case .motivationBoost: return "モチベーション強化"
        case .difficultyReduction: return "難易度調整"
        }
    }
}

// MARK: - Progressive Goal Planning

struct ProgressiveGoalPlan: Codable, Identifiable {
    let id: UUID
    let finalGoal: Goal
    let phases: [GoalPhase]
    let timeline: ProgressiveTimeline
    let userCapabilityProfile: UserCapabilityProfile
    let adaptationPoints: [AdaptationPoint]
    let milestones: [ProgressiveMilestone]
    let riskMitigation: [RiskMitigationStrategy]
    let supportResources: [SupportResource]
    let successMetrics: [SuccessMetric]
    let fallbackStrategies: [FallbackStrategy]
    let motivationPlan: ProgressiveMotivationPlan
    let reviewSchedule: [ReviewPoint]
    let generatedAt: Date
    
    init(finalGoal: Goal, phases: [GoalPhase], timeline: ProgressiveTimeline, userCapabilityProfile: UserCapabilityProfile, adaptationPoints: [AdaptationPoint], milestones: [ProgressiveMilestone], riskMitigation: [RiskMitigationStrategy], supportResources: [SupportResource], successMetrics: [SuccessMetric], fallbackStrategies: [FallbackStrategy], motivationPlan: ProgressiveMotivationPlan, reviewSchedule: [ReviewPoint]) {
        self.id = UUID()
        self.finalGoal = finalGoal
        self.phases = phases
        self.timeline = timeline
        self.userCapabilityProfile = userCapabilityProfile
        self.adaptationPoints = adaptationPoints
        self.milestones = milestones
        self.riskMitigation = riskMitigation
        self.supportResources = supportResources
        self.successMetrics = successMetrics
        self.fallbackStrategies = fallbackStrategies
        self.motivationPlan = motivationPlan
        self.reviewSchedule = reviewSchedule
        self.generatedAt = Date()
    }
}

struct GoalPhase: Codable, Identifiable {
    let id: UUID
    let phaseNumber: Int
    let name: String
    let description: String
    let duration: TimeInterval
    let startDate: Date
    let endDate: Date
    let targetValue: Double
    let requiredCapabilities: [RequiredCapability]
    let challenges: [PhaseChallenge]
    let supportMeasures: [SupportMeasure]
    let successCriteria: [SuccessCriterion]
    let transitionConditions: [TransitionCondition]
    
    init(phaseNumber: Int, name: String, description: String, duration: TimeInterval, startDate: Date, endDate: Date, targetValue: Double, requiredCapabilities: [RequiredCapability], challenges: [PhaseChallenge], supportMeasures: [SupportMeasure], successCriteria: [SuccessCriterion], transitionConditions: [TransitionCondition]) {
        self.id = UUID()
        self.phaseNumber = phaseNumber
        self.name = name
        self.description = description
        self.duration = duration
        self.startDate = startDate
        self.endDate = endDate
        self.targetValue = targetValue
        self.requiredCapabilities = requiredCapabilities
        self.challenges = challenges
        self.supportMeasures = supportMeasures
        self.successCriteria = successCriteria
        self.transitionConditions = transitionConditions
    }
}

struct ProgressiveTimeline: Codable {
    let totalDuration: TimeInterval
    let phaseCount: Int
    let flexibility: TimelineFlexibility
    let bufferTime: TimeInterval
    let criticalMilestones: [Date]
    let adaptationWindows: [DateInterval]
    let reviewFrequency: ReviewFrequency
    
    init(totalDuration: TimeInterval, phaseCount: Int, flexibility: TimelineFlexibility, bufferTime: TimeInterval, criticalMilestones: [Date], adaptationWindows: [DateInterval], reviewFrequency: ReviewFrequency) {
        self.totalDuration = totalDuration
        self.phaseCount = phaseCount
        self.flexibility = flexibility
        self.bufferTime = bufferTime
        self.criticalMilestones = criticalMilestones
        self.adaptationWindows = adaptationWindows
        self.reviewFrequency = reviewFrequency
    }
}

enum TimelineFlexibility: String, CaseIterable, Codable {
    case rigid = "rigid"           // 厳格
    case moderate = "moderate"     // 中程度
    case flexible = "flexible"     // 柔軟
    case adaptive = "adaptive"     // 適応的
    
    var displayName: String {
        switch self {
        case .rigid: return "厳格"
        case .moderate: return "中程度"
        case .flexible: return "柔軟"
        case .adaptive: return "適応的"
        }
    }
}

// MARK: - Goal Feasibility Assessment

struct GoalFeasibilityAssessment: Codable, Identifiable {
    let id: UUID
    let proposedGoal: Goal
    let feasibilityScore: Double // 0.0 to 1.0
    let assessment: FeasibilityLevel
    let strengthFactors: [StrengthFactor]
    let riskFactors: [RiskFactor]
    let recommendations: [FeasibilityRecommendation]
    let alternativeGoals: [AlternativeGoal]
    let requiredPreparation: [PreparationStep]
    let timelineAdjustments: [TimelineAdjustment]
    let resourceRequirements: [ResourceRequirement]
    let successProbability: Double
    let confidence: Double
    let generatedAt: Date
    
    init(proposedGoal: Goal, feasibilityScore: Double, assessment: FeasibilityLevel, strengthFactors: [StrengthFactor], riskFactors: [RiskFactor], recommendations: [FeasibilityRecommendation], alternativeGoals: [AlternativeGoal], requiredPreparation: [PreparationStep], timelineAdjustments: [TimelineAdjustment], resourceRequirements: [ResourceRequirement], successProbability: Double, confidence: Double) {
        self.id = UUID()
        self.proposedGoal = proposedGoal
        self.feasibilityScore = feasibilityScore
        self.assessment = assessment
        self.strengthFactors = strengthFactors
        self.riskFactors = riskFactors
        self.recommendations = recommendations
        self.alternativeGoals = alternativeGoals
        self.requiredPreparation = requiredPreparation
        self.timelineAdjustments = timelineAdjustments
        self.resourceRequirements = resourceRequirements
        self.successProbability = successProbability
        self.confidence = confidence
        self.generatedAt = Date()
    }
}

enum FeasibilityLevel: String, CaseIterable, Codable {
    case excellent = "excellent"   // 優秀
    case good = "good"             // 良好
    case moderate = "moderate"     // 中程度
    case challenging = "challenging" // 困難
    case unrealistic = "unrealistic" // 非現実的
    
    var displayName: String {
        switch self {
        case .excellent: return "優秀"
        case .good: return "良好"
        case .moderate: return "中程度"
        case .challenging: return "困難"
        case .unrealistic: return "非現実的"
        }
    }
    
    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .moderate: return "yellow"
        case .challenging: return "orange"
        case .unrealistic: return "red"
        }
    }
}

// MARK: - Supporting Types

struct UserCapabilityProfile: Codable {
    let physicalCapability: PhysicalCapabilityLevel
    let mentalCapability: MentalCapabilityLevel
    let motivationLevel: MotivationLevel
    let consistencyScore: Double
    let adaptabilityScore: Double
    let learningRate: Double
    let stressResilience: Double
    let timeAvailability: TimeAvailability
    let supportSystem: SupportSystemStrength
    let experienceLevel: ExperienceLevel
    let preferredChallengeLevel: ChallengeLevel
    
    init(physicalCapability: PhysicalCapabilityLevel, mentalCapability: MentalCapabilityLevel, motivationLevel: MotivationLevel, consistencyScore: Double, adaptabilityScore: Double, learningRate: Double, stressResilience: Double, timeAvailability: TimeAvailability, supportSystem: SupportSystemStrength, experienceLevel: ExperienceLevel, preferredChallengeLevel: ChallengeLevel) {
        self.physicalCapability = physicalCapability
        self.mentalCapability = mentalCapability
        self.motivationLevel = motivationLevel
        self.consistencyScore = consistencyScore
        self.adaptabilityScore = adaptabilityScore
        self.learningRate = learningRate
        self.stressResilience = stressResilience
        self.timeAvailability = timeAvailability
        self.supportSystem = supportSystem
        self.experienceLevel = experienceLevel
        self.preferredChallengeLevel = preferredChallengeLevel
    }
}

enum PhysicalCapabilityLevel: String, CaseIterable, Codable {
    case excellent = "excellent"
    case good = "good"
    case average = "average"
    case limited = "limited"
    case restricted = "restricted"
    
    var displayName: String {
        switch self {
        case .excellent: return "優秀"
        case .good: return "良好"
        case .average: return "平均"
        case .limited: return "制限あり"
        case .restricted: return "大幅制限"
        }
    }
}

enum MentalCapabilityLevel: String, CaseIterable, Codable {
    case excellent = "excellent"
    case good = "good"
    case average = "average"
    case stressed = "stressed"
    case overwhelmed = "overwhelmed"
    
    var displayName: String {
        switch self {
        case .excellent: return "優秀"
        case .good: return "良好"
        case .average: return "平均"
        case .stressed: return "ストレス状態"
        case .overwhelmed: return "過負荷状態"
        }
    }
}

enum DifficultyLevel: String, CaseIterable, Codable {
    case veryEasy = "very_easy"
    case easy = "easy"
    case moderate = "moderate"
    case challenging = "challenging"
    case veryDifficult = "very_difficult"
    
    var displayName: String {
        switch self {
        case .veryEasy: return "とても簡単"
        case .easy: return "簡単"
        case .moderate: return "中程度"
        case .challenging: return "困難"
        case .veryDifficult: return "とても困難"
        }
    }
    
    var score: Double {
        switch self {
        case .veryEasy: return 0.2
        case .easy: return 0.4
        case .moderate: return 0.6
        case .challenging: return 0.8
        case .veryDifficult: return 1.0
        }
    }
}

struct EvidenceSource: Codable, Identifiable {
    let id: UUID
    let type: EvidenceType
    let description: String
    let reliability: Double
    let dataPoints: Int
    let timeRange: DateInterval
    let source: String
    
    init(type: EvidenceType, description: String, reliability: Double, dataPoints: Int, timeRange: DateInterval, source: String) {
        self.id = UUID()
        self.type = type
        self.description = description
        self.reliability = reliability
        self.dataPoints = dataPoints
        self.timeRange = timeRange
        self.source = source
    }
}

enum EvidenceType: String, CaseIterable, Codable {
    case healthData = "health_data"
    case behaviorPattern = "behavior_pattern"
    case previousGoals = "previous_goals"
    case medicalHistory = "medical_history"
    case lifestyle = "lifestyle"
    case environmental = "environmental"
    case psychological = "psychological"
    
    var displayName: String {
        switch self {
        case .healthData: return "健康データ"
        case .behaviorPattern: return "行動パターン"
        case .previousGoals: return "過去の目標"
        case .medicalHistory: return "医療履歴"
        case .lifestyle: return "ライフスタイル"
        case .environmental: return "環境要因"
        case .psychological: return "心理的要因"
        }
    }
}

// MARK: - Additional Supporting Types

struct SeasonalPerformanceData: Codable, Identifiable {
    let id: UUID
    let season: Season
    let year: Int
    let performanceMetrics: [String: Double]
    let goalCompletionRate: Double
    let averageProgress: Double
    let commonChallenges: [String]
    let successFactors: [String]
    
    init(season: Season, year: Int, performanceMetrics: [String: Double], goalCompletionRate: Double, averageProgress: Double, commonChallenges: [String], successFactors: [String]) {
        self.id = UUID()
        self.season = season
        self.year = year
        self.performanceMetrics = performanceMetrics
        self.goalCompletionRate = goalCompletionRate
        self.averageProgress = averageProgress
        self.commonChallenges = commonChallenges
        self.successFactors = successFactors
    }
}

struct PersonalizedGoalType: Codable, Identifiable {
    let id: UUID
    let goalType: HealthDataType
    let recommendationStrength: Double
    let rationale: String
    let expectedImpact: String
    let personalizedParameters: [String: Any]
    
    init(goalType: HealthDataType, recommendationStrength: Double, rationale: String, expectedImpact: String, personalizedParameters: [String: Any]) {
        self.id = UUID()
        self.goalType = goalType
        self.recommendationStrength = recommendationStrength
        self.rationale = rationale
        self.expectedImpact = expectedImpact
        self.personalizedParameters = personalizedParameters
    }
    
    // Custom Codable implementation
    enum CodingKeys: String, CodingKey {
        case id, goalType, recommendationStrength, rationale, expectedImpact
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        goalType = try container.decode(HealthDataType.self, forKey: .goalType)
        recommendationStrength = try container.decode(Double.self, forKey: .recommendationStrength)
        rationale = try container.decode(String.self, forKey: .rationale)
        expectedImpact = try container.decode(String.self, forKey: .expectedImpact)
        personalizedParameters = [:]
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(goalType, forKey: .goalType)
        try container.encode(recommendationStrength, forKey: .recommendationStrength)
        try container.encode(rationale, forKey: .rationale)
        try container.encode(expectedImpact, forKey: .expectedImpact)
    }
}

struct UserGoalPreferences: Codable {
    let preferredDataTypes: [HealthDataType]
    let difficultyPreference: DifficultyLevel
    let timeframeFocus: GoalTimeframe
    let motivationalFactors: [String]
    let avoidanceFactors: [String]
    let personalityTraits: [String]
    
    init(preferredDataTypes: [HealthDataType], difficultyPreference: DifficultyLevel, timeframeFocus: GoalTimeframe, motivationalFactors: [String], avoidanceFactors: [String], personalityTraits: [String]) {
        self.preferredDataTypes = preferredDataTypes
        self.difficultyPreference = difficultyPreference
        self.timeframeFocus = timeframeFocus
        self.motivationalFactors = motivationalFactors
        self.avoidanceFactors = avoidanceFactors
        self.personalityTraits = personalityTraits
    }
}

struct GoalDifficultyOptimization: Codable, Identifiable {
    let id: UUID
    let currentDifficulty: DifficultyLevel
    let optimalDifficulty: DifficultyLevel
    let adjustmentRecommendations: [String]
    let predictedSuccessRate: Double
    let confidenceLevel: Double
    
    init(currentDifficulty: DifficultyLevel, optimalDifficulty: DifficultyLevel, adjustmentRecommendations: [String], predictedSuccessRate: Double, confidenceLevel: Double) {
        self.id = UUID()
        self.currentDifficulty = currentDifficulty
        self.optimalDifficulty = optimalDifficulty
        self.adjustmentRecommendations = adjustmentRecommendations
        self.predictedSuccessRate = predictedSuccessRate
        self.confidenceLevel = confidenceLevel
    }
}

struct AdaptiveGoalRecommendation: Codable, Identifiable {
    let id: UUID
    let goalType: HealthDataType
    let currentTarget: Double
    let recommendedTarget: Double
    let adjustmentReason: String
    let adaptationStrategy: String
    let confidenceScore: Double
    let implementationTimeline: String
    
    init(goalType: HealthDataType, currentTarget: Double, recommendedTarget: Double, adjustmentReason: String, adaptationStrategy: String, confidenceScore: Double, implementationTimeline: String) {
        self.id = UUID()
        self.goalType = goalType
        self.currentTarget = currentTarget
        self.recommendedTarget = recommendedTarget
        self.adjustmentReason = adjustmentReason
        self.adaptationStrategy = adaptationStrategy
        self.confidenceScore = confidenceScore
        self.implementationTimeline = implementationTimeline
    }
}

struct MotivationAnalysis: Codable, Identifiable {
    let id: UUID
    let motivationLevel: MotivationLevel
    let motivationalFactors: [String]
    let barriers: [String]
    let recommendedInterventions: [String]
    let personalityAlignment: Double
    let socialSupport: Double
    
    init(motivationLevel: MotivationLevel, motivationalFactors: [String], barriers: [String], recommendedInterventions: [String], personalityAlignment: Double, socialSupport: Double) {
        self.id = UUID()
        self.motivationLevel = motivationLevel
        self.motivationalFactors = motivationalFactors
        self.barriers = barriers
        self.recommendedInterventions = recommendedInterventions
        self.personalityAlignment = personalityAlignment
        self.socialSupport = socialSupport
    }
}

enum MotivationLevel: String, CaseIterable, Codable {
    case critical = "critical"
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case excellent = "excellent"
    
    var displayName: String {
        switch self {
        case .critical: return "要改善"
        case .low: return "低い"
        case .moderate: return "普通"
        case .high: return "高い"
        case .excellent: return "非常に高い"
        }
    }
    
    var emoji: String {
        switch self {
        case .critical: return "⚠️"
        case .low: return "😐"
        case .moderate: return "👍"
        case .high: return "🔥"
        case .excellent: return "⭐"
        }
    }
}

struct AdherenceInsight: Codable, Identifiable {
    let id: UUID
    let adherenceRate: Double
    let consistencyScore: Double
    let adherencePatterns: [String]
    let dropoffRisks: [String]
    let retentionStrategies: [String]
    let behavioralTriggers: [String]
    
    init(adherenceRate: Double, consistencyScore: Double, adherencePatterns: [String], dropoffRisks: [String], retentionStrategies: [String], behavioralTriggers: [String]) {
        self.id = UUID()
        self.adherenceRate = adherenceRate
        self.consistencyScore = consistencyScore
        self.adherencePatterns = adherencePatterns
        self.dropoffRisks = dropoffRisks
        self.retentionStrategies = retentionStrategies
        self.behavioralTriggers = behavioralTriggers
    }
}

// MARK: - Advanced Goal Management Types (Phase 2.3)

struct GoalCombination: Codable, Identifiable {
    let id: UUID
    let primaryGoal: Goal
    let secondaryGoals: [Goal]
    let synergyScore: Double
    let combinedDifficulty: DifficultyLevel
    let expectedOutcomes: [CombinationOutcome]
    let conflictRisks: [ConflictRisk]
    let managementStrategy: CombinationStrategy
    let timeline: CombinationTimeline
    let successProbability: Double
    
    init(primaryGoal: Goal, secondaryGoals: [Goal], synergyScore: Double, combinedDifficulty: DifficultyLevel, expectedOutcomes: [CombinationOutcome], conflictRisks: [ConflictRisk], managementStrategy: CombinationStrategy, timeline: CombinationTimeline, successProbability: Double) {
        self.id = UUID()
        self.primaryGoal = primaryGoal
        self.secondaryGoals = secondaryGoals
        self.synergyScore = synergyScore
        self.combinedDifficulty = combinedDifficulty
        self.expectedOutcomes = expectedOutcomes
        self.conflictRisks = conflictRisks
        self.managementStrategy = managementStrategy
        self.timeline = timeline
        self.successProbability = successProbability
    }
}

struct AdaptiveMilestone: Codable, Identifiable {
    let id: UUID
    let goalId: UUID
    let name: String
    let description: String
    let targetValue: Double
    let targetDate: Date
    let adaptationRules: [AdaptationRule]
    let triggerConditions: [TriggerCondition]
    let fallbackOptions: [FallbackOption]
    let motivationBoosts: [MotivationBoost]
    let trackingMetrics: [TrackingMetric]
    
    init(goalId: UUID, name: String, description: String, targetValue: Double, targetDate: Date, adaptationRules: [AdaptationRule], triggerConditions: [TriggerCondition], fallbackOptions: [FallbackOption], motivationBoosts: [MotivationBoost], trackingMetrics: [TrackingMetric]) {
        self.id = UUID()
        self.goalId = goalId
        self.name = name
        self.description = description
        self.targetValue = targetValue
        self.targetDate = targetDate
        self.adaptationRules = adaptationRules
        self.triggerConditions = triggerConditions
        self.fallbackOptions = fallbackOptions
        self.motivationBoosts = motivationBoosts
        self.trackingMetrics = trackingMetrics
    }
}

struct AdaptationTrigger: Codable, Identifiable {
    let id: UUID
    let triggerType: TriggerType
    let condition: String
    let threshold: Double
    let action: AdaptationAction
    let priority: TriggerPriority
    let cooldownPeriod: TimeInterval
    let isActive: Bool
    
    init(triggerType: TriggerType, condition: String, threshold: Double, action: AdaptationAction, priority: TriggerPriority, cooldownPeriod: TimeInterval, isActive: Bool = true) {
        self.id = UUID()
        self.triggerType = triggerType
        self.condition = condition
        self.threshold = threshold
        self.action = action
        self.priority = priority
        self.cooldownPeriod = cooldownPeriod
        self.isActive = isActive
    }
}

struct GoalSynergy: Codable, Identifiable {
    let id: UUID
    let primaryGoal: Goal
    let secondaryGoal: Goal
    let synergyType: SynergyType
    let synergyStrength: Double
    let mutualBenefits: [MutualBenefit]
    let sharedResources: [SharedResource]
    let compoundEffects: [CompoundEffect]
    let optimizationOpportunities: [OptimizationOpportunity]
    
    init(primaryGoal: Goal, secondaryGoal: Goal, synergyType: SynergyType, synergyStrength: Double, mutualBenefits: [MutualBenefit], sharedResources: [SharedResource], compoundEffects: [CompoundEffect], optimizationOpportunities: [OptimizationOpportunity]) {
        self.id = UUID()
        self.primaryGoal = primaryGoal
        self.secondaryGoal = secondaryGoal
        self.synergyType = synergyType
        self.synergyStrength = synergyStrength
        self.mutualBenefits = mutualBenefits
        self.sharedResources = sharedResources
        self.compoundEffects = compoundEffects
        self.optimizationOpportunities = optimizationOpportunities
    }
}

struct GoalOutcomePrediction: Codable, Identifiable {
    let id: UUID
    let goal: Goal
    let predictionHorizon: TimeInterval
    let successProbability: Double
    let expectedTimeToCompletion: TimeInterval
    let riskFactors: [PredictionRiskFactor]
    let successFactors: [PredictionSuccessFactor]
    let alternateScenarios: [PredictionScenario]
    let confidenceLevel: Double
    let predictionMethod: PredictionMethod
    
    init(goal: Goal, predictionHorizon: TimeInterval, successProbability: Double, expectedTimeToCompletion: TimeInterval, riskFactors: [PredictionRiskFactor], successFactors: [PredictionSuccessFactor], alternateScenarios: [PredictionScenario], confidenceLevel: Double, predictionMethod: PredictionMethod) {
        self.id = UUID()
        self.goal = goal
        self.predictionHorizon = predictionHorizon
        self.successProbability = successProbability
        self.expectedTimeToCompletion = expectedTimeToCompletion
        self.riskFactors = riskFactors
        self.successFactors = successFactors
        self.alternateScenarios = alternateScenarios
        self.confidenceLevel = confidenceLevel
        self.predictionMethod = predictionMethod
    }
}

struct UserGoalHistory: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let completedGoals: [Goal]
    let abandonedGoals: [Goal]
    let currentGoals: [Goal]
    let successRate: Double
    let averageCompletionTime: TimeInterval
    let preferredDifficulty: DifficultyLevel
    let consistencyScore: Double
    let motivationPatterns: [MotivationPattern]
    let challengeAreas: [ChallengeArea]
    let strengthAreas: [StrengthArea]
    
    init(userId: UUID, completedGoals: [Goal], abandonedGoals: [Goal], currentGoals: [Goal], successRate: Double, averageCompletionTime: TimeInterval, preferredDifficulty: DifficultyLevel, consistencyScore: Double, motivationPatterns: [MotivationPattern], challengeAreas: [ChallengeArea], strengthAreas: [StrengthArea]) {
        self.id = UUID()
        self.userId = userId
        self.completedGoals = completedGoals
        self.abandonedGoals = abandonedGoals
        self.currentGoals = currentGoals
        self.successRate = successRate
        self.averageCompletionTime = averageCompletionTime
        self.preferredDifficulty = preferredDifficulty
        self.consistencyScore = consistencyScore
        self.motivationPatterns = motivationPatterns
        self.challengeAreas = challengeAreas
        self.strengthAreas = strengthAreas
    }
}

struct HealthBaseline: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let baselineMetrics: [HealthDataType: BaselineMetric]
    let physicalCapability: PhysicalCapabilityLevel
    let fitnessLevel: FitnessLevel
    let healthRisks: [HealthRisk]
    let medicalConditions: [MedicalCondition]
    let medicationEffects: [MedicationEffect]
    let lifestyleFactors: [LifestyleFactor]
    let lastUpdated: Date
    
    init(userId: UUID, baselineMetrics: [HealthDataType: BaselineMetric], physicalCapability: PhysicalCapabilityLevel, fitnessLevel: FitnessLevel, healthRisks: [HealthRisk], medicalConditions: [MedicalCondition], medicationEffects: [MedicationEffect], lifestyleFactors: [LifestyleFactor]) {
        self.id = UUID()
        self.userId = userId
        self.baselineMetrics = baselineMetrics
        self.physicalCapability = physicalCapability
        self.fitnessLevel = fitnessLevel
        self.healthRisks = healthRisks
        self.medicalConditions = medicalConditions
        self.medicationEffects = medicationEffects
        self.lifestyleFactors = lifestyleFactors
        self.lastUpdated = Date()
    }
}

struct OptimizedGoal: Codable, Identifiable {
    let id: UUID
    let originalGoal: Goal
    let optimizedTarget: Double
    let optimizedTimeline: Date
    let optimizedStrategy: OptimizationStrategy
    let personalizedApproach: PersonalizedApproach
    let motivationAlignment: Double
    let feasibilityScore: Double
    let expectedSuccessRate: Double
    let optimizationRationale: String
    
    init(originalGoal: Goal, optimizedTarget: Double, optimizedTimeline: Date, optimizedStrategy: OptimizationStrategy, personalizedApproach: PersonalizedApproach, motivationAlignment: Double, feasibilityScore: Double, expectedSuccessRate: Double, optimizationRationale: String) {
        self.id = UUID()
        self.originalGoal = originalGoal
        self.optimizedTarget = optimizedTarget
        self.optimizedTimeline = optimizedTimeline
        self.optimizedStrategy = optimizedStrategy
        self.personalizedApproach = personalizedApproach
        self.motivationAlignment = motivationAlignment
        self.feasibilityScore = feasibilityScore
        self.expectedSuccessRate = expectedSuccessRate
        self.optimizationRationale = optimizationRationale
    }
}

struct UserConstraints: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let timeConstraints: TimeConstraints
    let physicalConstraints: PhysicalConstraints
    let financialConstraints: FinancialConstraints
    let socialConstraints: SocialConstraints
    let environmentalConstraints: EnvironmentalConstraints
    let psychologicalConstraints: PsychologicalConstraints
    let medicalConstraints: MedicalConstraints
    
    init(userId: UUID, timeConstraints: TimeConstraints, physicalConstraints: PhysicalConstraints, financialConstraints: FinancialConstraints, socialConstraints: SocialConstraints, environmentalConstraints: EnvironmentalConstraints, psychologicalConstraints: PsychologicalConstraints, medicalConstraints: MedicalConstraints) {
        self.id = UUID()
        self.userId = userId
        self.timeConstraints = timeConstraints
        self.physicalConstraints = physicalConstraints
        self.financialConstraints = financialConstraints
        self.socialConstraints = socialConstraints
        self.environmentalConstraints = environmentalConstraints
        self.psychologicalConstraints = psychologicalConstraints
        self.medicalConstraints = medicalConstraints
    }
}

struct SmartMilestone: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String
    let targetValue: Double
    let targetDate: Date
    let adaptiveRules: [AdaptiveRule]
    let motivationStrategy: MilestoneMotivationStrategy
    let trackingFrequency: TrackingFrequency
    let rewardMechanism: RewardMechanism
    let difficultyProgression: DifficultyProgression
    
    init(name: String, description: String, targetValue: Double, targetDate: Date, adaptiveRules: [AdaptiveRule], motivationStrategy: MilestoneMotivationStrategy, trackingFrequency: TrackingFrequency, rewardMechanism: RewardMechanism, difficultyProgression: DifficultyProgression) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.targetValue = targetValue
        self.targetDate = targetDate
        self.adaptiveRules = adaptiveRules
        self.motivationStrategy = motivationStrategy
        self.trackingFrequency = trackingFrequency
        self.rewardMechanism = rewardMechanism
        self.difficultyProgression = difficultyProgression
    }
}

// MARK: - Supporting Enums and Structs

enum TriggerType: String, CaseIterable, Codable {
    case performance = "performance"
    case time = "time"
    case progress = "progress"
    case motivation = "motivation"
    case external = "external"
    case health = "health"
}

enum AdaptationAction: String, CaseIterable, Codable {
    case adjustTarget = "adjust_target"
    case adjustTimeline = "adjust_timeline"
    case changeStrategy = "change_strategy"
    case addSupport = "add_support"
    case modifyDifficulty = "modify_difficulty"
}

enum TriggerPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
}

enum SynergyType: String, CaseIterable, Codable {
    case reinforcing = "reinforcing"
    case complementary = "complementary"
    case synergistic = "synergistic"
    case neutral = "neutral"
    case conflicting = "conflicting"
}

enum PredictionMethod: String, CaseIterable, Codable {
    case statistical = "statistical"
    case machineLearning = "machine_learning"
    case behavioral = "behavioral"
    case historical = "historical"
    case hybrid = "hybrid"
}

enum FitnessLevel: String, CaseIterable, Codable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case expert = "expert"
}

enum TrackingFrequency: String, CaseIterable, Codable {
    case realTime = "real_time"
    case hourly = "hourly"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
}

enum ExperienceLevel: String, CaseIterable, Codable {
    case novice = "novice"
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case expert = "expert"
}

enum ChallengeLevel: String, CaseIterable, Codable {
    case minimal = "minimal"
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case extreme = "extreme"
}

enum TimeAvailability: String, CaseIterable, Codable {
    case veryLimited = "very_limited"
    case limited = "limited"
    case moderate = "moderate"
    case ample = "ample"
    case unlimited = "unlimited"
}

enum SupportSystemStrength: String, CaseIterable, Codable {
    case none = "none"
    case weak = "weak"
    case moderate = "moderate"
    case strong = "strong"
    case excellent = "excellent"
}

enum ReviewFrequency: String, CaseIterable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case biweekly = "biweekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
}

// MARK: - Complex Supporting Structs

struct CombinationOutcome: Codable, Identifiable {
    let id: UUID
    let description: String
    let probability: Double
    let impactLevel: String
    
    init(description: String, probability: Double, impactLevel: String) {
        self.id = UUID()
        self.description = description
        self.probability = probability
        self.impactLevel = impactLevel
    }
}

struct ConflictRisk: Codable, Identifiable {
    let id: UUID
    let riskType: String
    let description: String
    let severity: String
    let mitigation: String
    
    init(riskType: String, description: String, severity: String, mitigation: String) {
        self.id = UUID()
        self.riskType = riskType
        self.description = description
        self.severity = severity
        self.mitigation = mitigation
    }
}

struct CombinationStrategy: Codable {
    let strategyType: String
    let description: String
    let priorityOrder: [String]
    let resourceAllocation: [String: Double]
}

struct CombinationTimeline: Codable {
    let totalDuration: TimeInterval
    let phases: [String]
    let milestones: [String]
    let flexibility: String
}

struct AdaptationRule: Codable, Identifiable {
    let id: UUID
    let condition: String
    let action: String
    let threshold: Double
    let priority: String
    
    init(condition: String, action: String, threshold: Double, priority: String) {
        self.id = UUID()
        self.condition = condition
        self.action = action
        self.threshold = threshold
        self.priority = priority
    }
}

struct TriggerCondition: Codable, Identifiable {
    let id: UUID
    let conditionType: String
    let description: String
    let threshold: Double
    
    init(conditionType: String, description: String, threshold: Double) {
        self.id = UUID()
        self.conditionType = conditionType
        self.description = description
        self.threshold = threshold
    }
}

struct FallbackOption: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String
    let triggerConditions: [String]
    
    init(name: String, description: String, triggerConditions: [String]) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.triggerConditions = triggerConditions
    }
}

struct MotivationBoost: Codable, Identifiable {
    let id: UUID
    let boostType: String
    let description: String
    let effectiveness: Double
    
    init(boostType: String, description: String, effectiveness: Double) {
        self.id = UUID()
        self.boostType = boostType
        self.description = description
        self.effectiveness = effectiveness
    }
}

struct TrackingMetric: Codable, Identifiable {
    let id: UUID
    let metricName: String
    let description: String
    let unit: String
    let frequency: String
    
    init(metricName: String, description: String, unit: String, frequency: String) {
        self.id = UUID()
        self.metricName = metricName
        self.description = description
        self.unit = unit
        self.frequency = frequency
    }
}

struct MutualBenefit: Codable, Identifiable {
    let id: UUID
    let benefitType: String
    let description: String
    let impactLevel: String
    
    init(benefitType: String, description: String, impactLevel: String) {
        self.id = UUID()
        self.benefitType = benefitType
        self.description = description
        self.impactLevel = impactLevel
    }
}

struct SharedResource: Codable, Identifiable {
    let id: UUID
    let resourceType: String
    let description: String
    let utilizationEfficiency: Double
    
    init(resourceType: String, description: String, utilizationEfficiency: Double) {
        self.id = UUID()
        self.resourceType = resourceType
        self.description = description
        self.utilizationEfficiency = utilizationEfficiency
    }
}

struct CompoundEffect: Codable, Identifiable {
    let id: UUID
    let effectType: String
    let description: String
    let magnitude: Double
    
    init(effectType: String, description: String, magnitude: Double) {
        self.id = UUID()
        self.effectType = effectType
        self.description = description
        self.magnitude = magnitude
    }
}

struct OptimizationOpportunity: Codable, Identifiable {
    let id: UUID
    let opportunityType: String
    let description: String
    let potentialBenefit: String
    
    init(opportunityType: String, description: String, potentialBenefit: String) {
        self.id = UUID()
        self.opportunityType = opportunityType
        self.description = description
        self.potentialBenefit = potentialBenefit
    }
}

struct PredictionRiskFactor: Codable, Identifiable {
    let id: UUID
    let factorType: String
    let description: String
    let impact: Double
    let likelihood: Double
    
    init(factorType: String, description: String, impact: Double, likelihood: Double) {
        self.id = UUID()
        self.factorType = factorType
        self.description = description
        self.impact = impact
        self.likelihood = likelihood
    }
}

struct PredictionSuccessFactor: Codable, Identifiable {
    let id: UUID
    let factorType: String
    let description: String
    let contribution: Double
    
    init(factorType: String, description: String, contribution: Double) {
        self.id = UUID()
        self.factorType = factorType
        self.description = description
        self.contribution = contribution
    }
}

struct PredictionScenario: Codable, Identifiable {
    let id: UUID
    let scenarioName: String
    let description: String
    let probability: Double
    let expectedOutcome: String
    
    init(scenarioName: String, description: String, probability: Double, expectedOutcome: String) {
        self.id = UUID()
        self.scenarioName = scenarioName
        self.description = description
        self.probability = probability
        self.expectedOutcome = expectedOutcome
    }
}

struct MotivationPattern: Codable, Identifiable {
    let id: UUID
    let patternType: String
    let description: String
    let frequency: String
    let effectiveness: Double
    
    init(patternType: String, description: String, frequency: String, effectiveness: Double) {
        self.id = UUID()
        self.patternType = patternType
        self.description = description
        self.frequency = frequency
        self.effectiveness = effectiveness
    }
}

struct ChallengeArea: Codable, Identifiable {
    let id: UUID
    let areaType: String
    let description: String
    let severity: String
    let recommendations: [String]
    
    init(areaType: String, description: String, severity: String, recommendations: [String]) {
        self.id = UUID()
        self.areaType = areaType
        self.description = description
        self.severity = severity
        self.recommendations = recommendations
    }
}

struct StrengthArea: Codable, Identifiable {
    let id: UUID
    let areaType: String
    let description: String
    let level: String
    let leverageOpportunities: [String]
    
    init(areaType: String, description: String, level: String, leverageOpportunities: [String]) {
        self.id = UUID()
        self.areaType = areaType
        self.description = description
        self.level = level
        self.leverageOpportunities = leverageOpportunities
    }
}

struct BaselineMetric: Codable {
    let averageValue: Double
    let standardDeviation: Double
    let trendDirection: String
    let confidenceLevel: Double
    let lastUpdated: Date
}

struct HealthRisk: Codable, Identifiable {
    let id: UUID
    let riskType: String
    let description: String
    let severityLevel: String
    let mitigation: [String]
    
    init(riskType: String, description: String, severityLevel: String, mitigation: [String]) {
        self.id = UUID()
        self.riskType = riskType
        self.description = description
        self.severityLevel = severityLevel
        self.mitigation = mitigation
    }
}

struct MedicalCondition: Codable, Identifiable {
    let id: UUID
    let conditionName: String
    let description: String
    let severity: String
    let managementStrategy: [String]
    
    init(conditionName: String, description: String, severity: String, managementStrategy: [String]) {
        self.id = UUID()
        self.conditionName = conditionName
        self.description = description
        self.severity = severity
        self.managementStrategy = managementStrategy
    }
}

struct MedicationEffect: Codable, Identifiable {
    let id: UUID
    let medicationName: String
    let effectType: String
    let description: String
    let impactLevel: String
    
    init(medicationName: String, effectType: String, description: String, impactLevel: String) {
        self.id = UUID()
        self.medicationName = medicationName
        self.effectType = effectType
        self.description = description
        self.impactLevel = impactLevel
    }
}

struct LifestyleFactor: Codable, Identifiable {
    let id: UUID
    let factorType: String
    let description: String
    let impact: String
    let recommendations: [String]
    
    init(factorType: String, description: String, impact: String, recommendations: [String]) {
        self.id = UUID()
        self.factorType = factorType
        self.description = description
        self.impact = impact
        self.recommendations = recommendations
    }
}

struct OptimizationStrategy: Codable {
    let strategyType: String
    let description: String
    let steps: [String]
    let expectedBenefits: [String]
}

struct PersonalizedApproach: Codable {
    let approachType: String
    let description: String
    let personalityAlignment: Double
    let customizations: [String]
}

struct TimeConstraints: Codable {
    let availableTimePerDay: TimeInterval
    let preferredTimeSlots: [String]
    let flexibilityLevel: String
    let constraints: [String]
}

struct PhysicalConstraints: Codable {
    let limitations: [String]
    let capabilities: [String]
    let adaptations: [String]
    let equipment: [String]
}

struct FinancialConstraints: Codable {
    let budget: Double
    let priorities: [String]
    let alternatives: [String]
    let costOptimizations: [String]
}

struct SocialConstraints: Codable {
    let supportLevel: String
    let socialFactors: [String]
    let networkEffects: [String]
    let influences: [String]
}

struct EnvironmentalConstraints: Codable {
    let location: String
    let facilities: [String]
    let climate: String
    let accessibility: [String]
}

struct PsychologicalConstraints: Codable {
    let motivationLevel: String
    let stressLevel: String
    let mentalCapacity: String
    let psychologicalFactors: [String]
}

struct MedicalConstraints: Codable {
    let conditions: [String]
    let medications: [String]
    let restrictions: [String]
    let recommendations: [String]
}

struct AdaptiveRule: Codable, Identifiable {
    let id: UUID
    let ruleName: String
    let condition: String
    let action: String
    let priority: String
    
    init(ruleName: String, condition: String, action: String, priority: String) {
        self.id = UUID()
        self.ruleName = ruleName
        self.condition = condition
        self.action = action
        self.priority = priority
    }
}

struct MilestoneMotivationStrategy: Codable {
    let strategyType: String
    let description: String
    let motivationalElements: [String]
    let rewardSystem: String
}

struct RewardMechanism: Codable {
    let rewardType: String
    let description: String
    let triggerConditions: [String]
    let value: String
}

struct DifficultyProgression: Codable {
    let progressionType: String
    let steps: [String]
    let adaptationRate: Double
    let targetDifficulty: String
}

// MARK: - Additional Missing Types

struct GoalPreferences: Codable {
    let preferredDifficulty: DifficultyLevel
    let preferredTimeframe: GoalTimeframe
    let motivationalFactors: [String]
    let avoidanceFactors: [String]
    let personalityTraits: [String]
    let communicationStyle: String
}

enum AdaptationStyle: String, CaseIterable, Codable {
    case aggressive = "aggressive"
    case moderate = "moderate"
    case conservative = "conservative"
    case reactive = "reactive"
    case proactive = "proactive"
    
    var displayName: String {
        switch self {
        case .aggressive: return "積極的"
        case .moderate: return "中程度"
        case .conservative: return "保守的"
        case .reactive: return "反応的"
        case .proactive: return "先制的"
        }
    }
}

struct MotivationProfile: Codable {
    let primaryMotivators: [String]
    let motivationStyle: String
    let responseToFeedback: String
    let rewardPreferences: [String]
    let challengePreference: ChallengeLevel
    let socialMotivation: Double
    let intrinsicMotivation: Double
    let extrinsicMotivation: Double
}

struct GoalProgressSnapshot: Codable, Identifiable {
    let id: UUID
    let goalId: UUID
    let timestamp: Date
    let currentValue: Double
    let targetValue: Double
    let progressPercentage: Double
    let velocity: Double
    let trend: String
    let contextualFactors: [String]
    let challenges: [String]
    let achievements: [String]
    
    init(goalId: UUID, timestamp: Date, currentValue: Double, targetValue: Double, progressPercentage: Double, velocity: Double, trend: String, contextualFactors: [String], challenges: [String], achievements: [String]) {
        self.id = UUID()
        self.goalId = goalId
        self.timestamp = timestamp
        self.currentValue = currentValue
        self.targetValue = targetValue
        self.progressPercentage = progressPercentage
        self.velocity = velocity
        self.trend = trend
        self.contextualFactors = contextualFactors
        self.challenges = challenges
        self.achievements = achievements
    }
}

// MARK: - Additional Pattern Analysis Types

struct PatternContext: Codable, Identifiable {
    let id: UUID
    let contextType: String
    let description: String
    let relevance: Double
    let timeframe: String
    
    init(contextType: String, description: String, relevance: Double, timeframe: String) {
        self.id = UUID()
        self.contextType = contextType
        self.description = description
        self.relevance = relevance
        self.timeframe = timeframe
    }
}

struct DataTrend: Codable, Identifiable {
    let id: UUID
    let trendType: String
    let description: String
    let strength: Double
    let direction: String
    let duration: TimeInterval
    let reliability: Double
    
    init(trendType: String, description: String, strength: Double, direction: String, duration: TimeInterval, reliability: Double) {
        self.id = UUID()
        self.trendType = trendType
        self.description = description
        self.strength = strength
        self.direction = direction
        self.duration = duration
        self.reliability = reliability
    }
}

struct PatternAnomaly: Codable, Identifiable {
    let id: UUID
    let anomalyType: String
    let description: String
    let severity: String
    let confidence: Double
    let detectionDate: Date
    let recommendations: [String]
    
    init(anomalyType: String, description: String, severity: String, confidence: Double, detectionDate: Date, recommendations: [String]) {
        self.id = UUID()
        self.anomalyType = anomalyType
        self.description = description
        self.severity = severity
        self.confidence = confidence
        self.detectionDate = detectionDate
        self.recommendations = recommendations
    }
}

struct PatternCorrelation: Codable, Identifiable {
    let id: UUID
    let primaryDataType: HealthDataType
    let secondaryDataType: HealthDataType
    let correlationStrength: Double
    let correlationType: String
    let significance: String
    let timeframe: String
    
    init(primaryDataType: HealthDataType, secondaryDataType: HealthDataType, correlationStrength: Double, correlationType: String, significance: String, timeframe: String) {
        self.id = UUID()
        self.primaryDataType = primaryDataType
        self.secondaryDataType = secondaryDataType
        self.correlationStrength = correlationStrength
        self.correlationType = correlationType
        self.significance = significance
        self.timeframe = timeframe
    }
}

struct SeasonalEffect: Codable, Identifiable {
    let id: UUID
    let season: Season
    let effectType: String
    let description: String
    let magnitude: Double
    let reliability: Double
    
    init(season: Season, effectType: String, description: String, magnitude: Double, reliability: Double) {
        self.id = UUID()
        self.season = season
        self.effectType = effectType
        self.description = description
        self.magnitude = magnitude
        self.reliability = reliability
    }
}

struct WeeklyPattern: Codable, Identifiable {
    let id: UUID
    let patternType: String
    let description: String
    let dayOfWeekEffects: [String: Double]
    let reliability: Double
    
    init(patternType: String, description: String, dayOfWeekEffects: [String: Double], reliability: Double) {
        self.id = UUID()
        self.patternType = patternType
        self.description = description
        self.dayOfWeekEffects = dayOfWeekEffects
        self.reliability = reliability
    }
}

struct DailyPattern: Codable, Identifiable {
    let id: UUID
    let patternType: String
    let description: String
    let timeOfDayEffects: [String: Double]
    let reliability: Double
    
    init(patternType: String, description: String, timeOfDayEffects: [String: Double], reliability: Double) {
        self.id = UUID()
        self.patternType = patternType
        self.description = description
        self.timeOfDayEffects = timeOfDayEffects
        self.reliability = reliability
    }
}

struct PatternInsight: Codable, Identifiable {
    let id: UUID
    let insightType: String
    let description: String
    let actionable: Bool
    let priority: String
    let recommendations: [String]
    
    init(insightType: String, description: String, actionable: Bool, priority: String, recommendations: [String]) {
        self.id = UUID()
        self.insightType = insightType
        self.description = description
        self.actionable = actionable
        self.priority = priority
        self.recommendations = recommendations
    }
}

struct HealthFocusArea: Codable, Identifiable {
    let id: UUID
    let areaName: String
    let description: String
    let priority: String
    let currentStatus: String
    let improvementPotential: Double
    
    init(areaName: String, description: String, priority: String, currentStatus: String, improvementPotential: Double) {
        self.id = UUID()
        self.areaName = areaName
        self.description = description
        self.priority = priority
        self.currentStatus = currentStatus
        self.improvementPotential = improvementPotential
    }
}

struct DataQualityScore: Codable {
    let overallScore: Double
    let completeness: Double
    let consistency: Double
    let accuracy: Double
    let timeliness: Double
    let relevance: Double
    let recommendations: [String]
}