import Foundation

// MARK: - Health Insight Core Models

struct HealthInsight: Codable, Identifiable {
    let id: UUID
    let category: InsightCategory
    let title: String
    let summary: String
    let confidence: Double // 0.0 to 1.0
    let priority: InsightPriority
    let timeframe: InsightTimeframe
    let actionability: InsightActionability
    let relatedData: [UUID] // References to health records
    let evidence: [InsightEvidence]
    let recommendations: [InsightRecommendation]
    let tags: [String]
    let generatedAt: Date
    
    init(id: UUID = UUID(), category: InsightCategory, title: String, summary: String, confidence: Double, priority: InsightPriority, timeframe: InsightTimeframe, actionability: InsightActionability, relatedData: [UUID] = [], evidence: [InsightEvidence] = [], recommendations: [InsightRecommendation] = [], tags: [String] = []) {
        self.id = id
        self.category = category
        self.title = title
        self.summary = summary
        self.confidence = confidence
        self.priority = priority
        self.timeframe = timeframe
        self.actionability = actionability
        self.relatedData = relatedData
        self.evidence = evidence
        self.recommendations = recommendations
        self.tags = tags
        self.generatedAt = Date()
    }
}

enum InsightCategory: String, CaseIterable, Codable {
    case fitness = "fitness"
    case nutrition = "nutrition"
    case sleep = "sleep"
    case cardiovascular = "cardiovascular"
    case metabolic = "metabolic"
    case mentalHealth = "mental_health"
    case chronicDisease = "chronic_disease"
    case prevention = "prevention"
    case recovery = "recovery"
    case performance = "performance"
    
    var displayName: String {
        switch self {
        case .fitness: return "フィットネス"
        case .nutrition: return "栄養"
        case .sleep: return "睡眠"
        case .cardiovascular: return "心血管"
        case .metabolic: return "代謝"
        case .mentalHealth: return "メンタルヘルス"
        case .chronicDisease: return "慢性疾患"
        case .prevention: return "予防"
        case .recovery: return "回復"
        case .performance: return "パフォーマンス"
        }
    }
}

enum InsightPriority: String, CaseIterable, Codable {
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
    
    var urgencyScore: Int {
        switch self {
        case .critical: return 5
        case .high: return 4
        case .medium: return 3
        case .low: return 2
        case .informational: return 1
        }
    }
}

enum InsightActionability: String, CaseIterable, Codable {
    case high = "high"         // Can take immediate action
    case medium = "medium"     // Can take action with some planning
    case low = "low"          // Requires significant preparation
    case informational = "informational" // No direct action required
    
    var displayName: String {
        switch self {
        case .high: return "高実行可能性"
        case .medium: return "中実行可能性"
        case .low: return "低実行可能性"
        case .informational: return "情報のみ"
        }
    }
}

struct InsightEvidence: Codable, Identifiable {
    let id: UUID
    let evidenceType: EvidenceType
    let description: String
    let strength: EvidenceStrength
    let source: EvidenceSource
    let dataPoints: [UUID] // References to supporting data
    let statisticalSignificance: Double?
    let confidenceInterval: ConfidenceInterval?
    
    init(evidenceType: EvidenceType, description: String, strength: EvidenceStrength, source: EvidenceSource, dataPoints: [UUID] = [], statisticalSignificance: Double? = nil, confidenceInterval: ConfidenceInterval? = nil) {
        self.id = UUID()
        self.evidenceType = evidenceType
        self.description = description
        self.strength = strength
        self.source = source
        self.dataPoints = dataPoints
        self.statisticalSignificance = statisticalSignificance
        self.confidenceInterval = confidenceInterval
    }
}

enum EvidenceType: String, CaseIterable, Codable {
    case statistical = "statistical"
    case observational = "observational"
    case comparative = "comparative"
    case predictive = "predictive"
    case correlational = "correlational"
    case experimental = "experimental"
    
    var displayName: String {
        switch self {
        case .statistical: return "統計的"
        case .observational: return "観察的"
        case .comparative: return "比較的"
        case .predictive: return "予測的"
        case .correlational: return "相関的"
        case .experimental: return "実験的"
        }
    }
}

enum EvidenceSource: String, CaseIterable, Codable {
    case userData = "user_data"
    case scientificLiterature = "scientific_literature"
    case populationData = "population_data"
    case expertOpinion = "expert_opinion"
    case machineLearning = "machine_learning"
    case clinicalGuidelines = "clinical_guidelines"
    
    var displayName: String {
        switch self {
        case .userData: return "ユーザーデータ"
        case .scientificLiterature: return "科学文献"
        case .populationData: return "人口統計データ"
        case .expertOpinion: return "専門家意見"
        case .machineLearning: return "機械学習"
        case .clinicalGuidelines: return "臨床ガイドライン"
        }
    }
}

struct InsightRecommendation: Codable, Identifiable {
    let id: UUID
    let title: String
    let description: String
    let category: RecommendationCategory
    let priority: RecommendationPriority
    let actionItems: [ActionItem]
    let estimatedImpact: Double // 0.0 to 1.0
    let difficulty: RecommendationDifficulty
    let timeToImplement: TimeInterval
    let successMetrics: [SuccessMetric]
    let prerequisites: [String]
    let resources: [InsightResource]
    
    init(title: String, description: String, category: RecommendationCategory, priority: RecommendationPriority, actionItems: [ActionItem], estimatedImpact: Double, difficulty: RecommendationDifficulty, timeToImplement: TimeInterval, successMetrics: [SuccessMetric] = [], prerequisites: [String] = [], resources: [InsightResource] = []) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.category = category
        self.priority = priority
        self.actionItems = actionItems
        self.estimatedImpact = estimatedImpact
        self.difficulty = difficulty
        self.timeToImplement = timeToImplement
        self.successMetrics = successMetrics
        self.prerequisites = prerequisites
        self.resources = resources
    }
}


struct ActionItem: Codable, Identifiable {
    let id: UUID
    let description: String
    let timeframe: ActionTimeframe
    let difficulty: ActionDifficulty
    let isOptional: Bool
    let dependencies: [UUID] // References to other action items
    let completionCriteria: String
    
    init(description: String, timeframe: ActionTimeframe, difficulty: ActionDifficulty, isOptional: Bool = false, dependencies: [UUID] = [], completionCriteria: String) {
        self.id = UUID()
        self.description = description
        self.timeframe = timeframe
        self.difficulty = difficulty
        self.isOptional = isOptional
        self.dependencies = dependencies
        self.completionCriteria = completionCriteria
    }
}

struct SuccessMetric: Codable, Identifiable {
    let id: UUID
    let name: String
    let targetValue: Double
    let currentValue: Double?
    let unit: String
    let measurementFrequency: MeasurementFrequency
    let targetDate: Date?
    
    init(name: String, targetValue: Double, unit: String, measurementFrequency: MeasurementFrequency, currentValue: Double? = nil, targetDate: Date? = nil) {
        self.id = UUID()
        self.name = name
        self.targetValue = targetValue
        self.currentValue = currentValue
        self.unit = unit
        self.measurementFrequency = measurementFrequency
        self.targetDate = targetDate
    }
}

enum MeasurementFrequency: String, CaseIterable, Codable {
    case continuous = "continuous"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case asNeeded = "as_needed"
    
    var displayName: String {
        switch self {
        case .continuous: return "継続的"
        case .daily: return "日次"
        case .weekly: return "週次"
        case .monthly: return "月次"
        case .asNeeded: return "必要時"
        }
    }
}

struct InsightResource: Codable, Identifiable {
    let id: UUID
    let type: InsightResourceType
    let name: String
    let description: String
    let url: String?
    let cost: InsightResourceCost
    let availability: ResourceAvailability
    
    init(type: InsightResourceType, name: String, description: String, url: String? = nil, cost: InsightResourceCost, availability: ResourceAvailability) {
        self.id = UUID()
        self.type = type
        self.name = name
        self.description = description
        self.url = url
        self.cost = cost
        self.availability = availability
    }
}

enum InsightResourceType: String, CaseIterable, Codable {
    case article = "article"
    case video = "video"
    case app = "app"
    case book = "book"
    case course = "course"
    case tool = "tool"
    case service = "service"
    
    var displayName: String {
        switch self {
        case .article: return "記事"
        case .video: return "動画"
        case .app: return "アプリ"
        case .book: return "書籍"
        case .course: return "コース"
        case .tool: return "ツール"
        case .service: return "サービス"
        }
    }
}

enum InsightResourceCost: String, CaseIterable, Codable {
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

enum ResourceAvailability: String, CaseIterable, Codable {
    case immediate = "immediate"
    case withinDays = "within_days"
    case withinWeeks = "within_weeks"
    case scheduled = "scheduled"
    
    var displayName: String {
        switch self {
        case .immediate: return "即座に利用可能"
        case .withinDays: return "数日以内"
        case .withinWeeks: return "数週間以内"
        case .scheduled: return "予約制"
        }
    }
}

// MARK: - Personalized Recommendation Models

struct PersonalizedRecommendation: Codable, Identifiable {
    let id: UUID
    let title: String
    let description: String
    let category: RecommendationCategory
    let priority: RecommendationPriority
    let personalizationLevel: PersonalizationLevel
    let actionItems: [ActionItem]
    let estimatedImpact: Double
    let difficulty: RecommendationDifficulty
    let timeToImplement: TimeInterval
    let personalizationFactors: [PersonalizationFactor]
    let adaptations: [RecommendationAdaptation]
    let monitoringPlan: MonitoringPlan
    
    init(title: String, description: String, category: RecommendationCategory, priority: RecommendationPriority, personalizationLevel: PersonalizationLevel, actionItems: [ActionItem], estimatedImpact: Double, difficulty: RecommendationDifficulty, timeToImplement: TimeInterval, personalizationFactors: [PersonalizationFactor] = [], adaptations: [RecommendationAdaptation] = [], monitoringPlan: MonitoringPlan) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.category = category
        self.priority = priority
        self.personalizationLevel = personalizationLevel
        self.actionItems = actionItems
        self.estimatedImpact = estimatedImpact
        self.difficulty = difficulty
        self.timeToImplement = timeToImplement
        self.personalizationFactors = personalizationFactors
        self.adaptations = adaptations
        self.monitoringPlan = monitoringPlan
    }
}


struct PersonalizationFactor: Codable, Identifiable {
    let id: UUID
    let factorType: PersonalizationFactorType
    let description: String
    let influence: Double // -1.0 to 1.0
    let confidence: Double
    
    init(factorType: PersonalizationFactorType, description: String, influence: Double, confidence: Double) {
        self.id = UUID()
        self.factorType = factorType
        self.description = description
        self.influence = influence
        self.confidence = confidence
    }
}

enum PersonalizationFactorType: String, CaseIterable, Codable {
    case demographic = "demographic"
    case behavioral = "behavioral"
    case preference = "preference"
    case historical = "historical"
    case physiological = "physiological"
    case psychological = "psychological"
    case environmental = "environmental"
    case social = "social"
    
    var displayName: String {
        switch self {
        case .demographic: return "人口統計"
        case .behavioral: return "行動的"
        case .preference: return "嗜好"
        case .historical: return "履歴"
        case .physiological: return "生理的"
        case .psychological: return "心理的"
        case .environmental: return "環境的"
        case .social: return "社会的"
        }
    }
}

struct RecommendationAdaptation: Codable, Identifiable {
    let id: UUID
    let adaptationType: AdaptationType
    let description: String
    let triggerConditions: [String]
    let modifications: [String]
    
    init(adaptationType: AdaptationType, description: String, triggerConditions: [String], modifications: [String]) {
        self.id = UUID()
        self.adaptationType = adaptationType
        self.description = description
        self.triggerConditions = triggerConditions
        self.modifications = modifications
    }
}

enum AdaptationType: String, CaseIterable, Codable {
    case intensity = "intensity"
    case frequency = "frequency"
    case duration = "duration"
    case approach = "approach"
    case timing = "timing"
    case content = "content"
    
    var displayName: String {
        switch self {
        case .intensity: return "強度"
        case .frequency: return "頻度"
        case .duration: return "期間"
        case .approach: return "アプローチ"
        case .timing: return "タイミング"
        case .content: return "内容"
        }
    }
}

struct MonitoringPlan: Codable, Identifiable {
    let id: UUID
    let monitoringFrequency: MonitoringFrequency
    let keyMetrics: [String]
    let checkpoints: [MonitoringCheckpoint]
    let adjustmentCriteria: [AdjustmentCriterion]
    let escalationPlan: EscalationPlan
    
    init(monitoringFrequency: MonitoringFrequency, keyMetrics: [String], checkpoints: [MonitoringCheckpoint], adjustmentCriteria: [AdjustmentCriterion], escalationPlan: EscalationPlan) {
        self.id = UUID()
        self.monitoringFrequency = monitoringFrequency
        self.keyMetrics = keyMetrics
        self.checkpoints = checkpoints
        self.adjustmentCriteria = adjustmentCriteria
        self.escalationPlan = escalationPlan
    }
}

struct MonitoringCheckpoint: Codable, Identifiable {
    let id: UUID
    let name: String
    let scheduledDate: Date
    let requiredActions: [String]
    let successCriteria: [String]
    let contingencyPlans: [String]
    
    init(name: String, scheduledDate: Date, requiredActions: [String], successCriteria: [String], contingencyPlans: [String]) {
        self.id = UUID()
        self.name = name
        self.scheduledDate = scheduledDate
        self.requiredActions = requiredActions
        self.successCriteria = successCriteria
        self.contingencyPlans = contingencyPlans
    }
}

struct AdjustmentCriterion: Codable, Identifiable {
    let id: UUID
    let metric: String
    let threshold: Double
    let comparisonOperator: ComparisonOperator
    let adjustmentAction: String
    let severity: AdjustmentSeverity
    
    init(metric: String, threshold: Double, comparisonOperator: ComparisonOperator, adjustmentAction: String, severity: AdjustmentSeverity) {
        self.id = UUID()
        self.metric = metric
        self.threshold = threshold
        self.comparisonOperator = comparisonOperator
        self.adjustmentAction = adjustmentAction
        self.severity = severity
    }
}

enum AdjustmentSeverity: String, CaseIterable, Codable {
    case minor = "minor"
    case moderate = "moderate"
    case major = "major"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .minor: return "軽微"
        case .moderate: return "中程度"
        case .major: return "重大"
        case .critical: return "緊急"
        }
    }
}

struct EscalationPlan: Codable, Identifiable {
    let id: UUID
    let escalationLevels: [EscalationLevel]
    let contacts: [EmergencyContact]
    let automaticTriggers: [AutomaticTrigger]
    
    init(escalationLevels: [EscalationLevel], contacts: [EmergencyContact], automaticTriggers: [AutomaticTrigger]) {
        self.id = UUID()
        self.escalationLevels = escalationLevels
        self.contacts = contacts
        self.automaticTriggers = automaticTriggers
    }
}

struct AutomaticTrigger: Codable, Identifiable {
    let id: UUID
    let condition: String
    let action: String
    let delay: TimeInterval
    let priority: EscalationLevel
    
    init(condition: String, action: String, delay: TimeInterval, priority: EscalationLevel) {
        self.id = UUID()
        self.condition = condition
        self.action = action
        self.delay = delay
        self.priority = priority
    }
}

// MARK: - Health Risk Assessment Models

struct HealthRiskAssessment: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let overallRiskScore: Double // 0.0 to 1.0
    let riskLevel: RiskLevel
    let assessmentDate: Date
    let assessmentPeriod: TimeInterval
    let identifiedRisks: [IdentifiedRisk]
    let protectiveFactors: [ProtectiveFactor]
    let mitigationStrategies: [MitigationStrategy]
    let recommendedActions: [RecommendedAction]
    let nextReviewDate: Date
    let confidenceLevel: Double
    
    init(userId: UUID, overallRiskScore: Double, riskLevel: RiskLevel, assessmentPeriod: TimeInterval, identifiedRisks: [IdentifiedRisk], protectiveFactors: [ProtectiveFactor], mitigationStrategies: [MitigationStrategy], recommendedActions: [RecommendedAction], nextReviewDate: Date, confidenceLevel: Double) {
        self.id = UUID()
        self.userId = userId
        self.overallRiskScore = overallRiskScore
        self.riskLevel = riskLevel
        self.assessmentDate = Date()
        self.assessmentPeriod = assessmentPeriod
        self.identifiedRisks = identifiedRisks
        self.protectiveFactors = protectiveFactors
        self.mitigationStrategies = mitigationStrategies
        self.recommendedActions = recommendedActions
        self.nextReviewDate = nextReviewDate
        self.confidenceLevel = confidenceLevel
    }
}

enum RiskLevel: String, CaseIterable, Codable {
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "低リスク"
        case .moderate: return "中リスク"
        case .high: return "高リスク"
        case .critical: return "緊急リスク"
        }
    }
    
    var colorCode: String {
        switch self {
        case .low: return "#00AA00"
        case .moderate: return "#FFAA00"
        case .high: return "#FF6600"
        case .critical: return "#FF0000"
        }
    }
}

struct IdentifiedRisk: Codable, Identifiable {
    let id: UUID
    let type: RiskType
    let name: String
    let description: String
    let severity: RiskSeverity
    let likelihood: Double // 0.0 to 1.0
    let impact: Double // 0.0 to 1.0
    let timeHorizon: RiskTimeHorizon
    let modifiable: Bool
    let evidence: [String]
    let relatedFactors: [String]
    
    init(type: RiskType, name: String, description: String, severity: RiskSeverity, likelihood: Double, impact: Double, timeHorizon: RiskTimeHorizon, modifiable: Bool, evidence: [String], relatedFactors: [String]) {
        self.id = UUID()
        self.type = type
        self.name = name
        self.description = description
        self.severity = severity
        self.likelihood = likelihood
        self.impact = impact
        self.timeHorizon = timeHorizon
        self.modifiable = modifiable
        self.evidence = evidence
        self.relatedFactors = relatedFactors
    }
}

enum RiskType: String, CaseIterable, Codable {
    case cardiovascular = "cardiovascular"
    case metabolic = "metabolic"
    case musculoskeletal = "musculoskeletal"
    case mental = "mental"
    case lifestyle = "lifestyle"
    case environmental = "environmental"
    case genetic = "genetic"
    case iatrogenic = "iatrogenic" // Medical treatment-related
    
    var displayName: String {
        switch self {
        case .cardiovascular: return "心血管"
        case .metabolic: return "代謝"
        case .musculoskeletal: return "筋骨格"
        case .mental: return "精神"
        case .lifestyle: return "ライフスタイル"
        case .environmental: return "環境"
        case .genetic: return "遺伝"
        case .iatrogenic: return "医原性"
        }
    }
}

enum RiskSeverity: String, CaseIterable, Codable {
    case minimal = "minimal"
    case mild = "mild"
    case moderate = "moderate"
    case severe = "severe"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .minimal: return "最小"
        case .mild: return "軽度"
        case .moderate: return "中程度"
        case .severe: return "重度"
        case .critical: return "緊急"
        }
    }
}

struct RiskFactor: Codable, Identifiable {
    let id: UUID
    let type: RiskType
    let name: String
    let severity: RiskSeverity
    let description: String
    let modifiable: Bool
    
    init(type: RiskType, name: String, severity: RiskSeverity, description: String, modifiable: Bool) {
        self.id = UUID()
        self.type = type
        self.name = name
        self.severity = severity
        self.description = description
        self.modifiable = modifiable
    }
}

struct ProtectiveFactor: Codable, Identifiable {
    let id: UUID
    let type: ProtectiveFactorType
    let name: String
    let description: String
    let strength: ProtectiveStrength
    let evidence: String
    let enhanceable: Bool
    
    init(type: ProtectiveFactorType, name: String, description: String, strength: ProtectiveStrength, evidence: String, enhanceable: Bool) {
        self.id = UUID()
        self.type = type
        self.name = name
        self.description = description
        self.strength = strength
        self.evidence = evidence
        self.enhanceable = enhanceable
    }
}

enum ProtectiveFactorType: String, CaseIterable, Codable {
    case lifestyle = "lifestyle"
    case genetic = "genetic"
    case social = "social"
    case environmental = "environmental"
    case medical = "medical"
    case psychological = "psychological"
    
    var displayName: String {
        switch self {
        case .lifestyle: return "ライフスタイル"
        case .genetic: return "遺伝的"
        case .social: return "社会的"
        case .environmental: return "環境的"
        case .medical: return "医療的"
        case .psychological: return "心理的"
        }
    }
}

enum ProtectiveStrength: String, CaseIterable, Codable {
    case weak = "weak"
    case moderate = "moderate"
    case strong = "strong"
    case veryStrong = "very_strong"
    
    var displayName: String {
        switch self {
        case .weak: return "弱い"
        case .moderate: return "中程度"
        case .strong: return "強い"
        case .veryStrong: return "非常に強い"
        }
    }
}

struct MitigationStrategy: Codable, Identifiable {
    let id: UUID
    let targetRisk: UUID // Reference to IdentifiedRisk
    let strategy: String
    let effectiveness: Double // 0.0 to 1.0
    let implementationComplexity: ImplementationComplexity
    let timeframe: ImplementationTimeframe
    let cost: ImplementationCost
    let barriers: [String]
    let enablers: [String]
    
    init(targetRisk: UUID, strategy: String, effectiveness: Double, implementationComplexity: ImplementationComplexity, timeframe: ImplementationTimeframe, cost: ImplementationCost, barriers: [String], enablers: [String]) {
        self.id = UUID()
        self.targetRisk = targetRisk
        self.strategy = strategy
        self.effectiveness = effectiveness
        self.implementationComplexity = implementationComplexity
        self.timeframe = timeframe
        self.cost = cost
        self.barriers = barriers
        self.enablers = enablers
    }
}

enum ImplementationComplexity: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case veryHigh = "very_high"
    
    var displayName: String {
        switch self {
        case .low: return "低複雑性"
        case .medium: return "中複雑性"
        case .high: return "高複雑性"
        case .veryHigh: return "非常に高複雑性"
        }
    }
}

enum ImplementationTimeframe: String, CaseIterable, Codable {
    case immediate = "immediate"      // Days
    case shortTerm = "short_term"     // Weeks
    case mediumTerm = "medium_term"   // Months
    case longTerm = "long_term"       // Years
    
    var displayName: String {
        switch self {
        case .immediate: return "即時"
        case .shortTerm: return "短期"
        case .mediumTerm: return "中期"
        case .longTerm: return "長期"
        }
    }
}

enum ImplementationCost: String, CaseIterable, Codable {
    case minimal = "minimal"
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case veryHigh = "very_high"
    
    var displayName: String {
        switch self {
        case .minimal: return "最小コスト"
        case .low: return "低コスト"
        case .moderate: return "中程度コスト"
        case .high: return "高コスト"
        case .veryHigh: return "非常に高コスト"
        }
    }
}

struct RecommendedAction: Codable, Identifiable {
    let id: UUID
    let priority: ActionPriority
    let description: String
    let rationale: String
    let expectedOutcome: String
    let timeframe: ActionTimeframe
    let difficulty: ActionDifficulty
    let riskLevel: ActionRiskLevel
    let dependencies: [UUID] // References to other actions
    let successCriteria: [String]
    
    init(priority: ActionPriority, description: String, rationale: String, expectedOutcome: String, timeframe: ActionTimeframe, difficulty: ActionDifficulty, riskLevel: ActionRiskLevel, dependencies: [UUID] = [], successCriteria: [String]) {
        self.id = UUID()
        self.priority = priority
        self.description = description
        self.rationale = rationale
        self.expectedOutcome = expectedOutcome
        self.timeframe = timeframe
        self.difficulty = difficulty
        self.riskLevel = riskLevel
        self.dependencies = dependencies
        self.successCriteria = successCriteria
    }
}

// MARK: - Health Outcome Prediction Models

struct HealthOutcomePrediction: Codable, Identifiable {
    let id: UUID
    let metricType: HealthDataType
    let predictionHorizon: PredictionHorizon
    let predictedValue: Double
    let predictionRange: PredictionRange
    let confidence: Double
    let achievabilityScore: Double
    let methodology: PredictionMethodology
    let factors: [PredictionFactor]
    let uncertainties: [PredictionUncertainty]
    let scenarios: [PredictionScenario]
    let generatedAt: Date
    
    init(metricType: HealthDataType, predictionHorizon: PredictionHorizon, predictedValue: Double, predictionRange: PredictionRange, confidence: Double, achievabilityScore: Double, methodology: PredictionMethodology, factors: [PredictionFactor], uncertainties: [PredictionUncertainty], scenarios: [PredictionScenario]) {
        self.id = UUID()
        self.metricType = metricType
        self.predictionHorizon = predictionHorizon
        self.predictedValue = predictedValue
        self.predictionRange = predictionRange
        self.confidence = confidence
        self.achievabilityScore = achievabilityScore
        self.methodology = methodology
        self.factors = factors
        self.uncertainties = uncertainties
        self.scenarios = scenarios
        self.generatedAt = Date()
    }
}

struct PredictionRange: Codable {
    let lowerBound: Double
    let upperBound: Double
    let confidenceLevel: Double
    
    var range: Double {
        return upperBound - lowerBound
    }
}

enum PredictionMethodology: String, CaseIterable, Codable {
    case linearRegression = "linear_regression"
    case timeSeries = "time_series"
    case machineLearning = "machine_learning"
    case statisticalModel = "statistical_model"
    case expertSystem = "expert_system"
    case ensemble = "ensemble"
    
    var displayName: String {
        switch self {
        case .linearRegression: return "線形回帰"
        case .timeSeries: return "時系列"
        case .machineLearning: return "機械学習"
        case .statisticalModel: return "統計モデル"
        case .expertSystem: return "エキスパートシステム"
        case .ensemble: return "アンサンブル"
        }
    }
}

struct PredictionFactor: Codable, Identifiable {
    let id: UUID
    let name: String
    let importance: Double // 0.0 to 1.0
    let direction: FactorDirection
    let confidence: Double
    let description: String
    
    init(name: String, importance: Double, direction: FactorDirection, confidence: Double, description: String) {
        self.id = UUID()
        self.name = name
        self.importance = importance
        self.direction = direction
        self.confidence = confidence
        self.description = description
    }
}

enum FactorDirection: String, CaseIterable, Codable {
    case positive = "positive"
    case negative = "negative"
    case neutral = "neutral"
    case variable = "variable"
    
    var displayName: String {
        switch self {
        case .positive: return "正の影響"
        case .negative: return "負の影響"
        case .neutral: return "中性"
        case .variable: return "可変"
        }
    }
}

struct PredictionUncertainty: Codable, Identifiable {
    let id: UUID
    let source: UncertaintySource
    let description: String
    let impact: Double // 0.0 to 1.0
    let mitigatable: Bool
    
    init(source: UncertaintySource, description: String, impact: Double, mitigatable: Bool) {
        self.id = UUID()
        self.source = source
        self.description = description
        self.impact = impact
        self.mitigatable = mitigatable
    }
}

enum UncertaintySource: String, CaseIterable, Codable {
    case dataQuality = "data_quality"
    case modelLimitations = "model_limitations"
    case externalFactors = "external_factors"
    case behaviorChange = "behavior_change"
    case randomVariation = "random_variation"
    case measurementError = "measurement_error"
    
    var displayName: String {
        switch self {
        case .dataQuality: return "データ品質"
        case .modelLimitations: return "モデル限界"
        case .externalFactors: return "外部要因"
        case .behaviorChange: return "行動変化"
        case .randomVariation: return "ランダム変動"
        case .measurementError: return "測定誤差"
        }
    }
}

struct PredictionScenario: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String
    let probability: Double
    let predictedOutcome: Double
    let assumptions: [String]
    let requiredActions: [String]
    
    init(name: String, description: String, probability: Double, predictedOutcome: Double, assumptions: [String], requiredActions: [String]) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.probability = probability
        self.predictedOutcome = predictedOutcome
        self.assumptions = assumptions
        self.requiredActions = requiredActions
    }
}

struct HealthMetric: Codable, Identifiable {
    let id: UUID
    let type: HealthDataType
    let targetValue: Double
    let currentValue: Double
    let unit: String
    let timeframe: InsightTimeframe
    
    init(type: HealthDataType, targetValue: Double, currentValue: Double, unit: String, timeframe: InsightTimeframe) {
        self.id = UUID()
        self.type = type
        self.targetValue = targetValue
        self.currentValue = currentValue
        self.unit = unit
        self.timeframe = timeframe
    }
}