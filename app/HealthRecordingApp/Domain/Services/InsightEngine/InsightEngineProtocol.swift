import Foundation

protocol InsightEngineProtocol {
    
    // MARK: - Correlation Analysis
    
    /// 異なる健康データタイプ間の相関関係を分析
    func analyzeCorrelations(
        between primaryData: [HealthRecordProtocol],
        and secondaryData: [HealthRecordProtocol],
        timeWindow: CorrelationTimeWindow
    ) async throws -> CorrelationAnalysis
    
    /// 複数の健康データタイプ間のマルチ相関分析
    func analyzeMultipleCorrelations(
        healthRecords: [HealthRecordProtocol],
        dataTypes: Set<HealthDataType>,
        analysisDepth: AnalysisDepth
    ) async throws -> [CorrelationAnalysis]
    
    /// 遅延相関分析（時間差を考慮した相関）
    func analyzeLaggedCorrelations(
        leadingData: [HealthRecordProtocol],
        laggingData: [HealthRecordProtocol],
        maxLagDays: Int
    ) async throws -> LaggedCorrelationResult
    
    // MARK: - Pattern Recognition
    
    /// 健康データのパターン認識と分類
    func recognizePatterns(
        in healthRecords: [HealthRecordProtocol],
        patternTypes: Set<PatternType>,
        sensitivity: PatternSensitivity
    ) async throws -> [HealthPattern]
    
    /// 季節性パターンの検出
    func detectSeasonalPatterns(
        in healthRecords: [HealthRecordProtocol],
        dataType: HealthDataType,
        minimumCycles: Int
    ) async throws -> [SeasonalPattern]
    
    /// 周期的パターンの分析
    func analyzeCyclicalPatterns(
        in healthRecords: [HealthRecordProtocol],
        expectedCycleLength: CycleLength,
        tolerance: Double
    ) async throws -> CyclicalPatternAnalysis
    
    /// 異常パターンの検出
    func detectAnomalousPatterns(
        in healthRecords: [HealthRecordProtocol],
        baselineData: [HealthRecordProtocol],
        anomalyThreshold: Double
    ) async throws -> [AnomalousPattern]
    
    // MARK: - Health Insights Generation
    
    /// 包括的な健康インサイトの生成
    func generateHealthInsights(
        for user: User,
        timeframe: InsightTimeframe,
        focusAreas: Set<HealthFocusArea>
    ) async throws -> [HealthInsight]
    
    /// パーソナライズされた健康推奨事項の生成
    func generatePersonalizedRecommendations(
        based on: [HealthInsight],
        userProfile: HealthProfile,
        priorityLevel: RecommendationPriority
    ) async throws -> [PersonalizedRecommendation]
    
    /// 健康リスク評価とアラート生成
    func assessHealthRisks(
        for user: User,
        riskFactors: [RiskFactor],
        assessmentPeriod: TimeInterval
    ) async throws -> HealthRiskAssessment
    
    /// 進歩とトレンドに基づく成功予測
    func predictHealthOutcomes(
        based on: [HealthRecordProtocol],
        targetMetrics: [HealthMetric],
        predictionHorizon: PredictionHorizon
    ) async throws -> [HealthOutcomePrediction]
    
    // MARK: - Behavioral Analysis
    
    /// ユーザーの行動パターン分析
    func analyzeBehavioralPatterns(
        for user: User,
        behaviorData: [BehaviorRecord],
        analysisWindow: BehaviorAnalysisWindow
    ) async throws -> BehavioralAnalysis
    
    /// 習慣形成の分析と予測
    func analyzeHabitFormation(
        behaviorHistory: [BehaviorRecord],
        targetHabits: [TargetHabit],
        formationThreshold: HabitFormationThreshold
    ) async throws -> [HabitFormationAnalysis]
    
    /// モチベーションパターンの分析
    func analyzeMotivationPatterns(
        engagementData: [EngagementRecord],
        externalFactors: [InsightExternalFactor],
        timeframe: MotivationTimeframe
    ) async throws -> MotivationPatternAnalysis
    
    // MARK: - Predictive Analytics
    
    /// 機械学習ベースの健康予測
    func generateMLPredictions(
        features: [HealthFeature],
        predictionTarget: PredictionTarget,
        modelConfiguration: MLModelConfiguration
    ) async throws -> MLPredictionResult
    
    /// トレンド外挿による将来予測
    func extrapolateTrends(
        historicalData: [HealthRecordProtocol],
        extrapolationMethod: ExtrapolationMethod,
        projectionPeriod: TimeInterval
    ) async throws -> [TrendProjection]
    
    /// リスク発生確率の計算
    func calculateRiskProbabilities(
        currentState: HealthState,
        riskModels: [RiskModel],
        timeHorizon: RiskTimeHorizon
    ) async throws -> [RiskProbability]
    
    // MARK: - Data Quality & Validation
    
    /// データ品質の包括的評価
    func assessDataQuality(
        healthRecords: [HealthRecordProtocol],
        qualityMetrics: Set<DataQualityMetric>,
        benchmarkStandards: QualityBenchmark
    ) async throws -> InsightDataQualityAssessment
    
    /// データの信頼性スコア計算
    func calculateReliabilityScore(
        for dataSource: DataSource,
        historicalAccuracy: [AccuracyRecord],
        consistencyMetrics: ConsistencyMetrics
    ) async throws -> ReliabilityScore
    
    /// 欠損データの影響評価
    func evaluateMissingDataImpact(
        completeData: [HealthRecordProtocol],
        missingDataPattern: MissingDataPattern,
        analysisRequirements: AnalysisRequirements
    ) async throws -> MissingDataImpactAssessment
    
    // MARK: - Comparative Analysis
    
    /// ピアグループとの比較分析
    func compareToPeerGroup(
        userMetrics: [HealthMetric],
        peerGroupData: PeerGroupData,
        demographicFilters: [DemographicFilter]
    ) async throws -> PeerComparisonAnalysis
    
    /// 人口統計との比較
    func compareToPopulationNorms(
        userData: [HealthRecordProtocol],
        populationDatabase: PopulationDatabase,
        normalizationFactors: [NormalizationFactor]
    ) async throws -> PopulationComparisonResult
    
    /// 個人的ベースラインとの経時変化分析
    func analyzePersonalBaseline(
        currentData: [HealthRecordProtocol],
        historicalBaseline: [HealthRecordProtocol],
        changeDetectionSensitivity: Double
    ) async throws -> BaselineComparisonAnalysis
    
    // MARK: - Advanced Analytics
    
    /// 複雑なマルチ変量分析
    func performMultivariateAnalysis(
        variables: [HealthVariable],
        analysisType: MultivariateAnalysisType,
        statisticalConfiguration: StatisticalConfiguration
    ) async throws -> MultivariateAnalysisResult
    
    /// 時系列分解とフォーキャスティング
    func decomposeTimeSeries(
        timeSeries: [HealthTimeSeriesPoint],
        decompositionMethod: TimeSeriesDecompositionMethod,
        forecastHorizon: Int
    ) async throws -> TimeSeriesDecomposition
    
    /// クラスタリング分析による健康状態分類
    func performHealthClustering(
        healthProfiles: [HealthProfile],
        clusteringAlgorithm: ClusteringAlgorithm,
        optimalClusterCount: OptimalClusterCount
    ) async throws -> HealthClusteringResult
    
    // MARK: - Insight Synthesis & Reporting
    
    /// 複数のインサイトの統合と優先順位付け
    func synthesizeInsights(
        insights: [HealthInsight],
        synthesisStrategy: InsightSynthesisStrategy,
        userPreferences: InsightPreferences
    ) async throws -> SynthesizedInsightReport
    
    /// カスタマイズされたレポート生成
    func generateCustomReport(
        reportTemplate: ReportTemplate,
        dataSource: [HealthRecordProtocol],
        reportConfiguration: ReportConfiguration
    ) async throws -> CustomHealthReport
    
    /// インサイトの信頼性と精度の評価
    func evaluateInsightAccuracy(
        generatedInsights: [HealthInsight],
        validationData: ValidationDataSet,
        accuracyMetrics: Set<AccuracyMetric>
    ) async throws -> InsightAccuracyEvaluation
}

// MARK: - Supporting Enums and Structs

enum CorrelationTimeWindow: String, CaseIterable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    case yearly = "yearly"
    
    var displayName: String {
        switch self {
        case .daily: return "日次"
        case .weekly: return "週次"
        case .monthly: return "月次"
        case .quarterly: return "四半期"
        case .yearly: return "年次"
        }
    }
    
    var timeInterval: TimeInterval {
        switch self {
        case .daily: return 24 * 60 * 60
        case .weekly: return 7 * 24 * 60 * 60
        case .monthly: return 30 * 24 * 60 * 60
        case .quarterly: return 90 * 24 * 60 * 60
        case .yearly: return 365 * 24 * 60 * 60
        }
    }
}

enum AnalysisDepth: String, CaseIterable, Codable {
    case shallow = "shallow"
    case moderate = "moderate"
    case deep = "deep"
    case comprehensive = "comprehensive"
    
    var displayName: String {
        switch self {
        case .shallow: return "表面的"
        case .moderate: return "適度"
        case .deep: return "深い"
        case .comprehensive: return "包括的"
        }
    }
    
    var computationalComplexity: Int {
        switch self {
        case .shallow: return 1
        case .moderate: return 3
        case .deep: return 7
        case .comprehensive: return 15
        }
    }
}

enum PatternType: String, CaseIterable, Codable {
    case trending = "trending"
    case cyclical = "cyclical"
    case seasonal = "seasonal"
    case spike = "spike"
    case plateau = "plateau"
    case decline = "decline"
    case irregular = "irregular"
    
    var displayName: String {
        switch self {
        case .trending: return "トレンド"
        case .cyclical: return "周期的"
        case .seasonal: return "季節的"
        case .spike: return "スパイク"
        case .plateau: return "プラトー"
        case .decline: return "低下"
        case .irregular: return "不規則"
        }
    }
}

enum PatternSensitivity: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case adaptive = "adaptive"
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .adaptive: return "適応的"
        }
    }
    
    var detectionThreshold: Double {
        switch self {
        case .low: return 0.3
        case .medium: return 0.2
        case .high: return 0.1
        case .adaptive: return 0.15 // Will be dynamically adjusted
        }
    }
}

enum CycleLength: String, CaseIterable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .daily: return "日次"
        case .weekly: return "週次"
        case .monthly: return "月次"
        case .quarterly: return "四半期"
        case .custom: return "カスタム"
        }
    }
    
    var standardDays: Int {
        switch self {
        case .daily: return 1
        case .weekly: return 7
        case .monthly: return 30
        case .quarterly: return 90
        case .custom: return -1 // To be specified
        }
    }
}

enum InsightTimeframe: String, CaseIterable, Codable {
    case week = "week"
    case month = "month"
    case quarter = "quarter"
    case year = "year"
    case lifetime = "lifetime"
    
    var displayName: String {
        switch self {
        case .week: return "週間"
        case .month: return "月間"
        case .quarter: return "四半期"
        case .year: return "年間"
        case .lifetime: return "生涯"
        }
    }
}

enum HealthFocusArea: String, CaseIterable, Codable {
    case cardiovascular = "cardiovascular"
    case metabolic = "metabolic"
    case fitness = "fitness"
    case sleep = "sleep"
    case nutrition = "nutrition"
    case mentalHealth = "mental_health"
    case chronicDisease = "chronic_disease"
    
    var displayName: String {
        switch self {
        case .cardiovascular: return "心血管"
        case .metabolic: return "代謝"
        case .fitness: return "フィットネス"
        case .sleep: return "睡眠"
        case .nutrition: return "栄養"
        case .mentalHealth: return "メンタルヘルス"
        case .chronicDisease: return "慢性疾患"
        }
    }
}


enum PredictionHorizon: String, CaseIterable, Codable {
    case shortTerm = "short_term"    // 1-7 days
    case mediumTerm = "medium_term"  // 1-4 weeks
    case longTerm = "long_term"      // 1-6 months
    case extended = "extended"       // 6 months - 2 years
    
    var displayName: String {
        switch self {
        case .shortTerm: return "短期"
        case .mediumTerm: return "中期"
        case .longTerm: return "長期"
        case .extended: return "拡張期"
        }
    }
    
    var dayRange: ClosedRange<Int> {
        switch self {
        case .shortTerm: return 1...7
        case .mediumTerm: return 7...28
        case .longTerm: return 30...180
        case .extended: return 180...730
        }
    }
}

enum BehaviorAnalysisWindow: String, CaseIterable, Codable {
    case recent = "recent"        // Last 2 weeks
    case standard = "standard"    // Last 3 months
    case comprehensive = "comprehensive" // Last year
    case historical = "historical"       // All available data
    
    var displayName: String {
        switch self {
        case .recent: return "最近"
        case .standard: return "標準"
        case .comprehensive: return "包括的"
        case .historical: return "履歴"
        }
    }
}

enum HabitFormationThreshold: String, CaseIterable, Codable {
    case lenient = "lenient"      // 66% consistency over 21 days
    case standard = "standard"    // 80% consistency over 28 days
    case strict = "strict"        // 90% consistency over 42 days
    case expert = "expert"        // 95% consistency over 66 days
    
    var displayName: String {
        switch self {
        case .lenient: return "寛大"
        case .standard: return "標準"
        case .strict: return "厳格"
        case .expert: return "専門家"
        }
    }
    
    var consistencyRequirement: Double {
        switch self {
        case .lenient: return 0.66
        case .standard: return 0.80
        case .strict: return 0.90
        case .expert: return 0.95
        }
    }
    
    var minimumDays: Int {
        switch self {
        case .lenient: return 21
        case .standard: return 28
        case .strict: return 42
        case .expert: return 66
        }
    }
}

enum MotivationTimeframe: String, CaseIterable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case seasonal = "seasonal"
    
    var displayName: String {
        switch self {
        case .daily: return "日次"
        case .weekly: return "週次"
        case .monthly: return "月次"
        case .seasonal: return "季節"
        }
    }
}

enum PredictionTarget: String, CaseIterable, Codable {
    case weightLoss = "weight_loss"
    case fitnessImprovement = "fitness_improvement"
    case healthRisk = "health_risk"
    case goalAchievement = "goal_achievement"
    case behaviorChange = "behavior_change"
    
    var displayName: String {
        switch self {
        case .weightLoss: return "体重減少"
        case .fitnessImprovement: return "フィットネス向上"
        case .healthRisk: return "健康リスク"
        case .goalAchievement: return "目標達成"
        case .behaviorChange: return "行動変容"
        }
    }
}

enum ExtrapolationMethod: String, CaseIterable, Codable {
    case linear = "linear"
    case polynomial = "polynomial"
    case exponential = "exponential"
    case logarithmic = "logarithmic"
    case movingAverage = "moving_average"
    case seasonalDecomposition = "seasonal_decomposition"
    
    var displayName: String {
        switch self {
        case .linear: return "線形"
        case .polynomial: return "多項式"
        case .exponential: return "指数"
        case .logarithmic: return "対数"
        case .movingAverage: return "移動平均"
        case .seasonalDecomposition: return "季節分解"
        }
    }
}

enum RiskTimeHorizon: String, CaseIterable, Codable {
    case immediate = "immediate"  // Next 24-48 hours
    case nearTerm = "near_term"   // Next 1-2 weeks
    case shortTerm = "short_term" // Next 1-3 months
    case longTerm = "long_term"   // Next 6-12 months
    
    var displayName: String {
        switch self {
        case .immediate: return "即座"
        case .nearTerm: return "近期"
        case .shortTerm: return "短期"
        case .longTerm: return "長期"
        }
    }
}

enum DataQualityMetric: String, CaseIterable, Codable {
    case completeness = "completeness"
    case accuracy = "accuracy"
    case consistency = "consistency"
    case timeliness = "timeliness"
    case validity = "validity"
    case uniqueness = "uniqueness"
    
    var displayName: String {
        switch self {
        case .completeness: return "完全性"
        case .accuracy: return "正確性"
        case .consistency: return "一貫性"
        case .timeliness: return "適時性"
        case .validity: return "妥当性"
        case .uniqueness: return "一意性"
        }
    }
}

enum MultivariateAnalysisType: String, CaseIterable, Codable {
    case principalComponentAnalysis = "pca"
    case factorAnalysis = "factor_analysis"
    case clusterAnalysis = "cluster_analysis"
    case discriminantAnalysis = "discriminant_analysis"
    case canonicalCorrelation = "canonical_correlation"
    
    var displayName: String {
        switch self {
        case .principalComponentAnalysis: return "主成分分析"
        case .factorAnalysis: return "因子分析"
        case .clusterAnalysis: return "クラスター分析"
        case .discriminantAnalysis: return "判別分析"
        case .canonicalCorrelation: return "正準相関"
        }
    }
}

enum TimeSeriesDecompositionMethod: String, CaseIterable, Codable {
    case additive = "additive"
    case multiplicative = "multiplicative"
    case stl = "stl"
    case x13 = "x13"
    
    var displayName: String {
        switch self {
        case .additive: return "加法分解"
        case .multiplicative: return "乗法分解"
        case .stl: return "STL分解"
        case .x13: return "X-13分解"
        }
    }
}

enum ClusteringAlgorithm: String, CaseIterable, Codable {
    case kmeans = "kmeans"
    case hierarchical = "hierarchical"
    case dbscan = "dbscan"
    case gaussianMixture = "gaussian_mixture"
    
    var displayName: String {
        switch self {
        case .kmeans: return "K-means"
        case .hierarchical: return "階層クラスタリング"
        case .dbscan: return "DBSCAN"
        case .gaussianMixture: return "ガウス混合"
        }
    }
}

enum OptimalClusterCount: String, CaseIterable, Codable {
    case elbow = "elbow"
    case silhouette = "silhouette"
    case gapStatistic = "gap_statistic"
    case fixed = "fixed"
    
    var displayName: String {
        switch self {
        case .elbow: return "エルボー法"
        case .silhouette: return "シルエット法"
        case .gapStatistic: return "ギャップ統計"
        case .fixed: return "固定"
        }
    }
}

enum InsightSynthesisStrategy: String, CaseIterable, Codable {
    case priorityBased = "priority_based"
    case thematic = "thematic"
    case chronological = "chronological"
    case impactBased = "impact_based"
    case personalized = "personalized"
    
    var displayName: String {
        switch self {
        case .priorityBased: return "優先度ベース"
        case .thematic: return "テーマ別"
        case .chronological: return "時系列"
        case .impactBased: return "影響度ベース"
        case .personalized: return "パーソナライズ"
        }
    }
}