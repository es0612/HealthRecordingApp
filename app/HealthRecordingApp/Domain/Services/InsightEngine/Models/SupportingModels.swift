import Foundation

// MARK: - Behavioral Analysis Supporting Models

struct BehaviorRecord: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let behaviorType: BehaviorType
    let timestamp: Date
    let duration: TimeInterval // in seconds
    let intensity: BehaviorIntensity
    let context: String
    let outcome: BehaviorOutcome
    
    init(userId: UUID, behaviorType: BehaviorType, timestamp: Date, duration: TimeInterval, intensity: BehaviorIntensity, context: String, outcome: BehaviorOutcome) {
        self.id = UUID()
        self.userId = userId
        self.behaviorType = behaviorType
        self.timestamp = timestamp
        self.duration = duration
        self.intensity = intensity
        self.context = context
        self.outcome = outcome
    }
}

enum BehaviorType: String, CaseIterable, Codable {
    case exercise = "exercise"
    case dataEntry = "data_entry"
    case goalSetting = "goal_setting"
    case progressReview = "progress_review"
    case recommendationView = "recommendation_view"
    case milestoneCheck = "milestone_check"
    case socialSharing = "social_sharing"
    case educationalContent = "educational_content"
    
    var displayName: String {
        switch self {
        case .exercise: return "運動"
        case .dataEntry: return "データ入力"
        case .goalSetting: return "目標設定"
        case .progressReview: return "進捗確認"
        case .recommendationView: return "推奨事項確認"
        case .milestoneCheck: return "マイルストーン確認"
        case .socialSharing: return "SNS共有"
        case .educationalContent: return "教育コンテンツ"
        }
    }
}

enum BehaviorIntensity: String, CaseIterable, Codable {
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case veryHigh = "very_high"
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .moderate: return "中"
        case .high: return "高"
        case .veryHigh: return "非常に高"
        }
    }
}

enum BehaviorOutcome: String, CaseIterable, Codable {
    case positive = "positive"
    case neutral = "neutral"
    case negative = "negative"
    
    var displayName: String {
        switch self {
        case .positive: return "ポジティブ"
        case .neutral: return "中性"
        case .negative: return "ネガティブ"
        }
    }
}

struct TargetHabit: Codable, Identifiable {
    let id: UUID
    let name: String
    let behaviorType: BehaviorType
    let targetFrequency: HabitFrequency
    let minimumDuration: TimeInterval
    let successCriteria: String
    
    init(name: String, behaviorType: BehaviorType, targetFrequency: HabitFrequency, minimumDuration: TimeInterval, successCriteria: String) {
        self.id = UUID()
        self.name = name
        self.behaviorType = behaviorType
        self.targetFrequency = targetFrequency
        self.minimumDuration = minimumDuration
        self.successCriteria = successCriteria
    }
}

enum HabitFrequency: String, CaseIterable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case biweekly = "biweekly"
    case monthly = "monthly"
    
    var displayName: String {
        switch self {
        case .daily: return "毎日"
        case .weekly: return "週1回"
        case .biweekly: return "隔週"
        case .monthly: return "月1回"
        }
    }
}

struct EngagementRecord: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let timestamp: Date
    let engagementType: EngagementType
    let duration: TimeInterval
    let interactionQuality: InteractionQuality
    let completionRate: Double // 0.0 to 1.0
    let userSatisfaction: Double // 0.0 to 1.0
    
    init(userId: UUID, timestamp: Date, engagementType: EngagementType, duration: TimeInterval, interactionQuality: InteractionQuality, completionRate: Double, userSatisfaction: Double) {
        self.id = UUID()
        self.userId = userId
        self.timestamp = timestamp
        self.engagementType = engagementType
        self.duration = duration
        self.interactionQuality = interactionQuality
        self.completionRate = completionRate
        self.userSatisfaction = userSatisfaction
    }
}

enum EngagementType: String, CaseIterable, Codable {
    case appUsage = "app_usage"
    case goalSetting = "goal_setting"
    case dataEntry = "data_entry"
    case progressReview = "progress_review"
    case recommendationInteraction = "recommendation_interaction"
    case socialFeature = "social_feature"
    case educationalContent = "educational_content"
    
    var displayName: String {
        switch self {
        case .appUsage: return "アプリ使用"
        case .goalSetting: return "目標設定"
        case .dataEntry: return "データ入力"
        case .progressReview: return "進捗確認"
        case .recommendationInteraction: return "推奨事項への対応"
        case .socialFeature: return "ソーシャル機能"
        case .educationalContent: return "教育コンテンツ"
        }
    }
}

enum InteractionQuality: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case excellent = "excellent"
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .excellent: return "優秀"
        }
    }
}

struct InsightExternalFactor: Codable, Identifiable {
    let id: UUID
    let type: InsightExternalFactorType
    let description: String
    let impact: Double // -1.0 to 1.0
    let timestamp: Date
    let confidence: Double // 0.0 to 1.0
    
    init(type: InsightExternalFactorType, description: String, impact: Double, timestamp: Date, confidence: Double) {
        self.id = UUID()
        self.type = type
        self.description = description
        self.impact = impact
        self.timestamp = timestamp
        self.confidence = confidence
    }
}

enum InsightExternalFactorType: String, CaseIterable, Codable {
    case weather = "weather"
    case stress = "stress"
    case socialSupport = "social_support"
    case workSchedule = "work_schedule"
    case healthEvent = "health_event"
    case technology = "technology"
    case economic = "economic"
    case seasonal = "seasonal"
    
    var displayName: String {
        switch self {
        case .weather: return "天候"
        case .stress: return "ストレス"
        case .socialSupport: return "社会的サポート"
        case .workSchedule: return "勤務スケジュール"
        case .healthEvent: return "健康イベント"
        case .technology: return "技術"
        case .economic: return "経済的"
        case .seasonal: return "季節的"
        }
    }
}

// MARK: - Health Profile Models

struct HealthProfile: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let age: Int
    let gender: Gender
    let height: Double // in cm
    let currentWeight: Double // in kg
    let targetWeight: Double? // in kg
    let activityLevel: ActivityLevel
    let healthConditions: [HealthCondition]
    let medications: [Medication]
    let allergies: [Allergy]
    let preferences: HealthPreferences
    
    init(userId: UUID, age: Int, gender: Gender, height: Double, currentWeight: Double, targetWeight: Double?, activityLevel: ActivityLevel, healthConditions: [HealthCondition], medications: [Medication], allergies: [Allergy], preferences: HealthPreferences) {
        self.id = UUID()
        self.userId = userId
        self.age = age
        self.gender = gender
        self.height = height
        self.currentWeight = currentWeight
        self.targetWeight = targetWeight
        self.activityLevel = activityLevel
        self.healthConditions = healthConditions
        self.medications = medications
        self.allergies = allergies
        self.preferences = preferences
    }
}

enum Gender: String, CaseIterable, Codable {
    case male = "male"
    case female = "female"
    case other = "other"
    case preferNotToSay = "prefer_not_to_say"
    
    var displayName: String {
        switch self {
        case .male: return "男性"
        case .female: return "女性"
        case .other: return "その他"
        case .preferNotToSay: return "回答しない"
        }
    }
}

enum ActivityLevel: String, CaseIterable, Codable {
    case sedentary = "sedentary"
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case veryHigh = "very_high"
    
    var displayName: String {
        switch self {
        case .sedentary: return "座位中心"
        case .low: return "低活動"
        case .moderate: return "中活動"
        case .high: return "高活動"
        case .veryHigh: return "非常に高活動"
        }
    }
    
    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .low: return 1.375
        case .moderate: return 1.55
        case .high: return 1.725
        case .veryHigh: return 1.9
        }
    }
}

struct HealthCondition: Codable, Identifiable {
    let id: UUID
    let name: String
    let severity: ConditionSeverity
    let diagnosedDate: Date?
    let isActive: Bool
    let notes: String?
    
    init(name: String, severity: ConditionSeverity, diagnosedDate: Date? = nil, isActive: Bool = true, notes: String? = nil) {
        self.id = UUID()
        self.name = name
        self.severity = severity
        self.diagnosedDate = diagnosedDate
        self.isActive = isActive
        self.notes = notes
    }
}

enum ConditionSeverity: String, CaseIterable, Codable {
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

struct Medication: Codable, Identifiable {
    let id: UUID
    let name: String
    let dosage: String
    let frequency: MedicationFrequency
    let startDate: Date
    let endDate: Date?
    let purpose: String
    
    init(name: String, dosage: String, frequency: MedicationFrequency, startDate: Date, endDate: Date? = nil, purpose: String) {
        self.id = UUID()
        self.name = name
        self.dosage = dosage
        self.frequency = frequency
        self.startDate = startDate
        self.endDate = endDate
        self.purpose = purpose
    }
}

enum MedicationFrequency: String, CaseIterable, Codable {
    case onceDailymorning = "once_daily_morning"
    case onceDailyevening = "once_daily_evening"
    case twiceDaily = "twice_daily"
    case thriceDaily = "thrice_daily"
    case asNeeded = "as_needed"
    case weekly = "weekly"
    case monthly = "monthly"
    
    var displayName: String {
        switch self {
        case .onceDailymorning: return "1日1回（朝）"
        case .onceDailyevening: return "1日1回（夜）"
        case .twiceDaily: return "1日2回"
        case .thriceDaily: return "1日3回"
        case .asNeeded: return "必要時"
        case .weekly: return "週1回"
        case .monthly: return "月1回"
        }
    }
}

struct Allergy: Codable, Identifiable {
    let id: UUID
    let allergen: String
    let severity: AllergySeverity
    let reactions: [String]
    let notes: String?
    
    init(allergen: String, severity: AllergySeverity, reactions: [String], notes: String? = nil) {
        self.id = UUID()
        self.allergen = allergen
        self.severity = severity
        self.reactions = reactions
        self.notes = notes
    }
}

enum AllergySeverity: String, CaseIterable, Codable {
    case mild = "mild"
    case moderate = "moderate"
    case severe = "severe"
    case lifeThreatening = "life_threatening"
    
    var displayName: String {
        switch self {
        case .mild: return "軽度"
        case .moderate: return "中程度"
        case .severe: return "重度"
        case .lifeThreatening: return "生命に関わる"
        }
    }
}

struct HealthPreferences: Codable {
    let preferredExerciseTypes: [ExerciseType]
    let dietaryRestrictions: [DietaryRestriction]
    let notificationPreferences: NotificationPreferences
}

enum ExerciseType: String, CaseIterable, Codable {
    case walking = "walking"
    case running = "running"
    case cycling = "cycling"
    case swimming = "swimming"
    case weightTraining = "weight_training"
    case yoga = "yoga"
    case pilates = "pilates"
    case dancing = "dancing"
    case sports = "sports"
    case hiking = "hiking"
    
    var displayName: String {
        switch self {
        case .walking: return "ウォーキング"
        case .running: return "ランニング"
        case .cycling: return "サイクリング"
        case .swimming: return "水泳"
        case .weightTraining: return "筋力トレーニング"
        case .yoga: return "ヨガ"
        case .pilates: return "ピラティス"
        case .dancing: return "ダンス"
        case .sports: return "スポーツ"
        case .hiking: return "ハイキング"
        }
    }
}

enum DietaryRestriction: String, CaseIterable, Codable {
    case vegetarian = "vegetarian"
    case vegan = "vegan"
    case glutenFree = "gluten_free"
    case dairyFree = "dairy_free"
    case lowSodium = "low_sodium"
    case lowSugar = "low_sugar"
    case keto = "keto"
    case paleo = "paleo"
    case mediterranean = "mediterranean"
    case none = "none"
    
    var displayName: String {
        switch self {
        case .vegetarian: return "ベジタリアン"
        case .vegan: return "ビーガン"
        case .glutenFree: return "グルテンフリー"
        case .dairyFree: return "乳製品フリー"
        case .lowSodium: return "低塩分"
        case .lowSugar: return "低糖質"
        case .keto: return "ケトジェニック"
        case .paleo: return "パレオ"
        case .mediterranean: return "地中海式"
        case .none: return "制限なし"
        }
    }
}

struct NotificationPreferences: Codable {
    let enabled: Bool
    let frequency: NotificationFrequency
    let quietHours: ClosedRange<Int> // Hour range (e.g., 22...7)
}

enum NotificationFrequency: String, CaseIterable, Codable {
    case realTime = "real_time"
    case hourly = "hourly"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    
    var displayName: String {
        switch self {
        case .realTime: return "リアルタイム"
        case .hourly: return "1時間毎"
        case .daily: return "日次"
        case .weekly: return "週次"
        case .monthly: return "月次"
        }
    }
}

// MARK: - Machine Learning Models

struct HealthFeature: Codable, Identifiable {
    let id: UUID
    let name: String
    let value: Double
    let type: FeatureType
    
    init(name: String, value: Double, type: FeatureType) {
        self.id = UUID()
        self.name = name
        self.value = value
        self.type = type
    }
}

enum FeatureType: String, CaseIterable, Codable {
    case numerical = "numerical"
    case categorical = "categorical"
    case binary = "binary"
    case ordinal = "ordinal"
    
    var displayName: String {
        switch self {
        case .numerical: return "数値"
        case .categorical: return "カテゴリ"
        case .binary: return "二値"
        case .ordinal: return "順序"
        }
    }
}

struct MLModelConfiguration: Codable {
    let modelType: MLModelType
    let algorithm: MLAlgorithm
    let hyperparameters: [String: Double]
    let validationMethod: ValidationMethod
    let trainingDataSize: Int
}

enum MLModelType: String, CaseIterable, Codable {
    case regression = "regression"
    case classification = "classification"
    case clustering = "clustering"
    case timeSeries = "time_series"
    case deepLearning = "deep_learning"
    
    var displayName: String {
        switch self {
        case .regression: return "回帰"
        case .classification: return "分類"
        case .clustering: return "クラスタリング"
        case .timeSeries: return "時系列"
        case .deepLearning: return "深層学習"
        }
    }
}

enum MLAlgorithm: String, CaseIterable, Codable {
    case linearRegression = "linear_regression"
    case randomForest = "random_forest"
    case svm = "svm"
    case neuralNetwork = "neural_network"
    case xgboost = "xgboost"
    case lstm = "lstm"
    
    var displayName: String {
        switch self {
        case .linearRegression: return "線形回帰"
        case .randomForest: return "ランダムフォレスト"
        case .svm: return "SVM"
        case .neuralNetwork: return "ニューラルネットワーク"
        case .xgboost: return "XGBoost"
        case .lstm: return "LSTM"
        }
    }
}

enum ValidationMethod: String, CaseIterable, Codable {
    case holdout = "holdout"
    case crossValidation = "cross_validation"
    case timeSeriesSplit = "time_series_split"
    case bootstrapping = "bootstrapping"
    
    var displayName: String {
        switch self {
        case .holdout: return "ホールドアウト"
        case .crossValidation: return "交差検証"
        case .timeSeriesSplit: return "時系列分割"
        case .bootstrapping: return "ブートストラップ"
        }
    }
}

struct MLPredictionResult: Codable, Identifiable {
    let id: UUID
    let predictionTarget: PredictionTarget
    let modelType: MLModelType
    let predictedValue: Double
    let confidence: Double
    let predictionInterval: PredictionInterval
    let featureImportance: [String: Double]
    let modelMetrics: [String: Double]
    let validationResults: ValidationResults
    
    init(predictionTarget: PredictionTarget, modelType: MLModelType, predictedValue: Double, confidence: Double, predictionInterval: PredictionInterval, featureImportance: [String: Double], modelMetrics: [String: Double], validationResults: ValidationResults) {
        self.id = UUID()
        self.predictionTarget = predictionTarget
        self.modelType = modelType
        self.predictedValue = predictedValue
        self.confidence = confidence
        self.predictionInterval = predictionInterval
        self.featureImportance = featureImportance
        self.modelMetrics = modelMetrics
        self.validationResults = validationResults
    }
}

struct PredictionInterval: Codable {
    let lowerBound: Double
    let upperBound: Double
    let confidenceLevel: Double
}

struct ValidationResults: Codable {
    let accuracy: Double
    let precision: Double?
    let recall: Double?
    let f1Score: Double?
    let mse: Double?
    let rmse: Double?
    let mae: Double?
    let rSquared: Double?
}

// MARK: - Health State and Risk Models

struct HealthState: Codable {
    let vitals: [String: Double]
    let symptoms: [String]
    let medications: [String]
    let lifestyle: [String: Double]
    let timestamp: Date
}

struct RiskModel: Codable, Identifiable {
    let id: UUID
    let riskType: RiskType
    let modelName: String
    let parameters: [String: Double]
    let weights: [String: Double]
    let threshold: Double
    
    init(riskType: RiskType, modelName: String, parameters: [String: Double], weights: [String: Double], threshold: Double) {
        self.id = UUID()
        self.riskType = riskType
        self.modelName = modelName
        self.parameters = parameters
        self.weights = weights
        self.threshold = threshold
    }
}

struct RiskProbability: Codable, Identifiable {
    let id: UUID
    let riskType: RiskType
    let probability: Double // 0.0 to 1.0
    let confidence: Double // 0.0 to 1.0
    let timeHorizon: RiskTimeHorizon
    let riskLevel: RiskLevel
    let contributingFactors: [String]
    let mitigationStrategies: [String]
    
    init(riskType: RiskType, probability: Double, confidence: Double, timeHorizon: RiskTimeHorizon, riskLevel: RiskLevel, contributingFactors: [String], mitigationStrategies: [String]) {
        self.id = UUID()
        self.riskType = riskType
        self.probability = probability
        self.confidence = confidence
        self.timeHorizon = timeHorizon
        self.riskLevel = riskLevel
        self.contributingFactors = contributingFactors
        self.mitigationStrategies = mitigationStrategies
    }
}

// MARK: - Data Quality Models

struct QualityBenchmark: Codable {
    let completenessThreshold: Double
    let accuracyThreshold: Double
    let consistencyThreshold: Double
    let validityThreshold: Double
    let timelinessThreshold: Double
}

struct InsightDataQualityAssessment: Codable {
    let overallScore: Double
    let metricScores: [DataQualityMetric: Double]
    let dataIssues: [InsightDataQualityIssue]
    let recommendations: [QualityRecommendation]
    let benchmarkComparison: [DataQualityMetric: BenchmarkComparison]
}

struct InsightDataQualityIssue: Codable, Identifiable {
    let id: UUID
    let issueType: QualityIssueType
    let severity: QualityIssueSeverity
    let description: String
    let affectedRecords: Int
    let suggestedActions: [String]
    
    init(issueType: QualityIssueType, severity: QualityIssueSeverity, description: String, affectedRecords: Int, suggestedActions: [String]) {
        self.id = UUID()
        self.issueType = issueType
        self.severity = severity
        self.description = description
        self.affectedRecords = affectedRecords
        self.suggestedActions = suggestedActions
    }
}

enum QualityIssueType: String, CaseIterable, Codable {
    case missingData = "missing_data"
    case invalidValue = "invalid_value"
    case outlier = "outlier"
    case inconsistency = "inconsistency"
    case duplication = "duplication"
    case timeliness = "timeliness"
    
    var displayName: String {
        switch self {
        case .missingData: return "データ欠損"
        case .invalidValue: return "無効値"
        case .outlier: return "外れ値"
        case .inconsistency: return "不整合"
        case .duplication: return "重複"
        case .timeliness: return "適時性"
        }
    }
}

enum QualityIssueSeverity: String, CaseIterable, Codable {
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

struct QualityRecommendation: Codable, Identifiable {
    let id: UUID
    let title: String
    let description: String
    let priority: RecommendationPriority
    let estimatedImpact: Double
    let implementation: String
    
    init(title: String, description: String, priority: RecommendationPriority, estimatedImpact: Double, implementation: String) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.priority = priority
        self.estimatedImpact = estimatedImpact
        self.implementation = implementation
    }
}

struct BenchmarkComparison: Codable {
    let score: Double
    let benchmark: Double
    let meetsBenchmark: Bool
    let deviation: Double
}

struct AccuracyRecord: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let expectedValue: Double
    let actualValue: Double
    let accuracy: Double
    
    init(timestamp: Date, expectedValue: Double, actualValue: Double, accuracy: Double) {
        self.id = UUID()
        self.timestamp = timestamp
        self.expectedValue = expectedValue
        self.actualValue = actualValue
        self.accuracy = accuracy
    }
}

struct ConsistencyMetrics: Codable {
    let temporalConsistency: Double
    let crossSourceConsistency: Double
    let internalConsistency: Double
    let methodologicalConsistency: Double
}

struct ReliabilityScore: Codable {
    let overallScore: Double
    let dataSource: DataSource
    let components: [String: Double]
    let confidenceLevel: Double
    let sampleSize: Int
    let assessmentDate: Date
    let validityPeriod: TimeInterval
}

struct MissingDataPattern: Codable {
    let patternType: MissingDataPatternType
    let missingPercentage: Double
    let affectedTimeRange: InsightDateRange
    let missingMechanism: MissingDataMechanism
}

enum MissingDataPatternType: String, CaseIterable, Codable {
    case random = "random"
    case systematic = "systematic"
    case periodic = "periodic"
    case cluster = "cluster"
    
    var displayName: String {
        switch self {
        case .random: return "ランダム"
        case .systematic: return "系統的"
        case .periodic: return "周期的"
        case .cluster: return "クラスター"
        }
    }
}

enum MissingDataMechanism: String, CaseIterable, Codable {
    case missingCompletelyAtRandom = "mcar"
    case missingAtRandom = "mar"
    case missingNotAtRandom = "mnar"
    
    var displayName: String {
        switch self {
        case .missingCompletelyAtRandom: return "完全にランダム"
        case .missingAtRandom: return "ランダム"
        case .missingNotAtRandom: return "非ランダム"
        }
    }
}

struct InsightDateRange: Codable {
    let start: Date
    let end: Date
    
    var duration: TimeInterval {
        return end.timeIntervalSince(start)
    }
}

struct AnalysisRequirements: Codable {
    let minimumDataPoints: Int
    let requiredCoverage: Double
    let acceptableGaps: Int
    let criticalMetrics: [String]
}

struct MissingDataImpactAssessment: Codable {
    let missingPercentage: Double
    let impactSeverity: MissingDataImpactSeverity
    let affectedAnalyses: [String]
    let confidenceReduction: Double
    let mitigationStrategies: [String]
    let alternativeApproaches: [String]
    let dataCollectionRecommendations: [String]
}

enum MissingDataImpactSeverity: String, CaseIterable, Codable {
    case minimal = "minimal"
    case moderate = "moderate"
    case significant = "significant"
    case severe = "severe"
    
    var displayName: String {
        switch self {
        case .minimal: return "最小"
        case .moderate: return "中程度"
        case .significant: return "重要"
        case .severe: return "深刻"
        }
    }
}

// MARK: - Advanced Analytics Supporting Types

struct HealthVariable: Codable, Identifiable {
    let id: UUID
    let name: String
    let values: [Double]
    let type: VariableType
    
    init(name: String, values: [Double], type: VariableType) {
        self.id = UUID()
        self.name = name
        self.values = values
        self.type = type
    }
}

enum VariableType: String, CaseIterable, Codable {
    case continuous = "continuous"
    case discrete = "discrete"
    case binary = "binary"
    case ordinal = "ordinal"
    
    var displayName: String {
        switch self {
        case .continuous: return "連続"
        case .discrete: return "離散"
        case .binary: return "二値"
        case .ordinal: return "順序"
        }
    }
}

struct StatisticalConfiguration: Codable {
    let significanceLevel: Double
    let confidenceLevel: Double
    let robustMethods: Bool
    let bootstrapIterations: Int
}

struct MultivariateAnalysisResult: Codable {
    let analysisType: MultivariateAnalysisType
    let variables: [String]
    let results: [String: Double]
    let explainedVariance: [Double]
    let loadings: [String: [Double]]
    let significance: StatisticalSignificance?
    let assumptions: [String]
    let diagnostics: [String: Double]
}

struct HealthTimeSeriesPoint: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let value: Double
    let dataType: HealthDataType
    
    init(timestamp: Date, value: Double, dataType: HealthDataType) {
        self.id = UUID()
        self.timestamp = timestamp
        self.value = value
        self.dataType = dataType
    }
}

struct TimeSeriesDecomposition: Codable {
    let method: TimeSeriesDecompositionMethod
    let originalSeries: [Double]
    let trend: [Double]
    let seasonal: [Double]
    let residual: [Double]
    let forecast: [Double]
    let forecastConfidenceInterval: [ConfidenceInterval]
    let seasonalityStrength: Double
    let trendStrength: Double
    let goodnessOfFit: Double
}

struct HealthClusteringResult: Codable {
    let algorithm: ClusteringAlgorithm
    let optimalClusters: Int
    let clusters: [HealthCluster]
    let clusterAssignments: [UUID: Int] // UserID to cluster assignment
    let silhouetteScore: Double
    let inertia: Double
    let clusterCharacteristics: [ClusterCharacteristics]
}

struct HealthCluster: Codable, Identifiable {
    let id: UUID
    let clusterNumber: Int
    let centroid: [String: Double]
    let memberCount: Int
    let cohesion: Double
    
    init(clusterNumber: Int, centroid: [String: Double], memberCount: Int, cohesion: Double) {
        self.id = UUID()
        self.clusterNumber = clusterNumber
        self.centroid = centroid
        self.memberCount = memberCount
        self.cohesion = cohesion
    }
}

struct ClusterCharacteristics: Codable, Identifiable {
    let id: UUID
    let clusterNumber: Int
    let dominantFeatures: [String]
    let averageProfile: HealthProfile
    let typicalBehaviors: [String]
    let riskFactors: [String]
    let recommendations: [String]
    
    init(clusterNumber: Int, dominantFeatures: [String], averageProfile: HealthProfile, typicalBehaviors: [String], riskFactors: [String], recommendations: [String]) {
        self.id = UUID()
        self.clusterNumber = clusterNumber
        self.dominantFeatures = dominantFeatures
        self.averageProfile = averageProfile
        self.typicalBehaviors = typicalBehaviors
        self.riskFactors = riskFactors
        self.recommendations = recommendations
    }
}

// MARK: - Insight Synthesis and Reporting Models

struct InsightPreferences: Codable {
    let preferredCategories: [InsightCategory]
    let maxInsightsPerReport: Int
    let minimumConfidence: Double
    let priorityThreshold: InsightPriority
    let includeActionItems: Bool
}

struct SynthesizedInsightReport: Codable {
    let strategy: InsightSynthesisStrategy
    let totalInsights: Int
    let synthesizedInsights: [HealthInsight]
    let keyFindings: [String]
    let priorityInsights: [HealthInsight]
    let actionableRecommendations: [InsightRecommendation]
    let overallScore: Double
    let generatedAt: Date
}

struct ReportTemplate: Codable {
    let name: String
    let sections: [ReportSectionType]
    let format: ReportFormat
    let includeCharts: Bool
    let includeComparisons: Bool
}

enum ReportSectionType: String, CaseIterable, Codable {
    case overview = "overview"
    case trends = "trends"
    case achievements = "achievements"
    case recommendations = "recommendations"
    case comparisons = "comparisons"
    case projections = "projections"
    
    var displayName: String {
        switch self {
        case .overview: return "概要"
        case .trends: return "トレンド"
        case .achievements: return "達成事項"
        case .recommendations: return "推奨事項"
        case .comparisons: return "比較"
        case .projections: return "予測"
        }
    }
}

enum ReportFormat: String, CaseIterable, Codable {
    case pdf = "pdf"
    case html = "html"
    case json = "json"
    case markdown = "markdown"
    
    var displayName: String {
        switch self {
        case .pdf: return "PDF"
        case .html: return "HTML"
        case .json: return "JSON"
        case .markdown: return "Markdown"
        }
    }
}

struct ReportConfiguration: Codable {
    let timeRange: InsightDateRange
    let includePersonalData: Bool
    let aggregationLevel: AggregationLevel
    let comparisonBaseline: ComparisonBaseline
    let privacyLevel: PrivacyLevel
}

enum AggregationLevel: String, CaseIterable, Codable {
    case raw = "raw"
    case hourly = "hourly"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    
    var displayName: String {
        switch self {
        case .raw: return "生データ"
        case .hourly: return "時間毎"
        case .daily: return "日次"
        case .weekly: return "週次"
        case .monthly: return "月次"
        }
    }
}

enum ComparisonBaseline: String, CaseIterable, Codable {
    case previousPeriod = "previous_period"
    case yearOverYear = "year_over_year"
    case personalBest = "personal_best"
    case populationAverage = "population_average"
    
    var displayName: String {
        switch self {
        case .previousPeriod: return "前期間"
        case .yearOverYear: return "前年同期"
        case .personalBest: return "個人記録"
        case .populationAverage: return "人口平均"
        }
    }
}

enum PrivacyLevel: String, CaseIterable, Codable {
    case minimal = "minimal"
    case standard = "standard"
    case enhanced = "enhanced"
    case maximum = "maximum"
    
    var displayName: String {
        switch self {
        case .minimal: return "最小"
        case .standard: return "標準"
        case .enhanced: return "強化"
        case .maximum: return "最大"
        }
    }
}

struct CustomHealthReport: Codable {
    let templateName: String
    let generatedSections: [ReportSection]
    let dataRange: InsightDateRange
    let reportMetadata: [String: String]
    let generatedAt: Date
    let reportSize: Int // in bytes
    let format: ReportFormat
}

struct ReportSection: Codable, Identifiable {
    let id: UUID
    let type: ReportSectionType
    let title: String
    let content: String
    let dataPoints: [DataPoint]
    
    init(type: ReportSectionType, title: String, content: String, dataPoints: [DataPoint]) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.content = content
        self.dataPoints = dataPoints
    }
}

struct DataPoint: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let value: Double
    let label: String
    
    init(timestamp: Date, value: Double, label: String) {
        self.id = UUID()
        self.timestamp = timestamp
        self.value = value
        self.label = label
    }
}

struct ValidationDataSet: Codable {
    let actualOutcomes: [String: Double]
    let timeRange: InsightDateRange
    let dataQuality: Double
    let completeness: Double
}

enum AccuracyMetric: String, CaseIterable, Codable {
    case meanAbsoluteError = "mae"
    case rootMeanSquareError = "rmse"
    case meanAbsolutePercentageError = "mape"
    case correlation = "correlation"
    case r2Score = "r2_score"
    
    var displayName: String {
        switch self {
        case .meanAbsoluteError: return "平均絶対誤差"
        case .rootMeanSquareError: return "二乗平均平方根誤差"
        case .meanAbsolutePercentageError: return "平均絶対パーセント誤差"
        case .correlation: return "相関係数"
        case .r2Score: return "決定係数"
        }
    }
}

struct InsightAccuracyEvaluation: Codable {
    let overallAccuracy: Double
    let metricResults: [AccuracyMetric: Double]
    let insightAccuracies: [InsightAccuracy]
    let confidenceCalibration: Double
    let predictionErrors: [PredictionError]
    let improvementSuggestions: [String]
}

struct InsightAccuracy: Codable, Identifiable {
    let id: UUID
    let insightTitle: String
    let accuracy: Double
    let confidence: Double
    let actualOutcome: Double?
    let predictedOutcome: Double?
    
    init(insightTitle: String, accuracy: Double, confidence: Double, actualOutcome: Double? = nil, predictedOutcome: Double? = nil) {
        self.id = UUID()
        self.insightTitle = insightTitle
        self.accuracy = accuracy
        self.confidence = confidence
        self.actualOutcome = actualOutcome
        self.predictedOutcome = predictedOutcome
    }
}

struct PredictionError: Codable, Identifiable {
    let id: UUID
    let errorType: PredictionErrorType
    let magnitude: Double
    let description: String
    let suggestedCorrection: String
    
    init(errorType: PredictionErrorType, magnitude: Double, description: String, suggestedCorrection: String) {
        self.id = UUID()
        self.errorType = errorType
        self.magnitude = magnitude
        self.description = description
        self.suggestedCorrection = suggestedCorrection
    }
}

enum PredictionErrorType: String, CaseIterable, Codable {
    case overestimation = "overestimation"
    case underestimation = "underestimation"
    case directionError = "direction_error"
    case timingError = "timing_error"
    case magnitudeError = "magnitude_error"
    
    var displayName: String {
        switch self {
        case .overestimation: return "過大評価"
        case .underestimation: return "過小評価"
        case .directionError: return "方向性誤差"
        case .timingError: return "タイミング誤差"
        case .magnitudeError: return "規模誤差"
        }
    }
}

// MARK: - Trend Projection Models

struct TrendProjection: Codable, Identifiable {
    let id: UUID
    let dataType: HealthDataType
    let method: ExtrapolationMethod
    let projectionPeriod: TimeInterval
    let confidence: Double
    let projectedValues: [ProjectionPoint]
    let confidenceInterval: ConfidenceInterval?
    let assumptions: [String]
    let limitingFactors: [String]
    
    init(dataType: HealthDataType, method: ExtrapolationMethod, projectionPeriod: TimeInterval, confidence: Double, projectedValues: [ProjectionPoint], confidenceInterval: ConfidenceInterval?, assumptions: [String], limitingFactors: [String]) {
        self.id = UUID()
        self.dataType = dataType
        self.method = method
        self.projectionPeriod = projectionPeriod
        self.confidence = confidence
        self.projectedValues = projectedValues
        self.confidenceInterval = confidenceInterval
        self.assumptions = assumptions
        self.limitingFactors = limitingFactors
    }
}

struct ProjectionPoint: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let value: Double
    let confidence: Double
    
    init(timestamp: Date, value: Double, confidence: Double) {
        self.id = UUID()
        self.timestamp = timestamp
        self.value = value
        self.confidence = confidence
    }
}

// MARK: - Completion Scenario Models

struct InsightCompletionScenario: Codable, Identifiable {
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