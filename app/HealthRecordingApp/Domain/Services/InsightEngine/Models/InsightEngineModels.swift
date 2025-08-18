import Foundation
import SwiftUI

// MARK: - Correlation Analysis Models

struct CorrelationAnalysis: Codable, Identifiable {
    let id: UUID
    let primaryDataType: HealthDataType
    let secondaryDataType: HealthDataType
    let correlationCoefficient: Double // -1.0 to 1.0
    let pValue: Double // Statistical significance
    let confidenceInterval: ConfidenceInterval
    let timeWindow: CorrelationTimeWindow
    let sampleSize: Int
    let correlationType: CorrelationType
    let strength: CorrelationStrength
    let direction: CorrelationDirection
    let significance: StatisticalSignificance
    let dataPoints: [CorrelationDataPoint]
    let generatedAt: Date
    
    init(primaryDataType: HealthDataType, secondaryDataType: HealthDataType, correlationCoefficient: Double, pValue: Double, confidenceInterval: ConfidenceInterval, timeWindow: CorrelationTimeWindow, sampleSize: Int, dataPoints: [CorrelationDataPoint]) {
        self.id = UUID()
        self.primaryDataType = primaryDataType
        self.secondaryDataType = secondaryDataType
        self.correlationCoefficient = correlationCoefficient
        self.pValue = pValue
        self.confidenceInterval = confidenceInterval
        self.timeWindow = timeWindow
        self.sampleSize = sampleSize
        self.dataPoints = dataPoints
        self.generatedAt = Date()
        
        // Derived properties
        self.correlationType = abs(correlationCoefficient) > 0.8 ? .strong : abs(correlationCoefficient) > 0.5 ? .moderate : abs(correlationCoefficient) > 0.3 ? .weak : .negligible
        self.strength = CorrelationStrength(from: abs(correlationCoefficient))
        self.direction = correlationCoefficient > 0 ? .positive : correlationCoefficient < 0 ? .negative : .neutral
        self.significance = pValue < 0.01 ? .highlySignificant : pValue < 0.05 ? .significant : pValue < 0.1 ? .marginallySignificant : .notSignificant
    }
}

struct ConfidenceInterval: Codable {
    let lowerBound: Double
    let upperBound: Double
    let confidenceLevel: Double // e.g., 0.95 for 95%
    
    var range: Double {
        return upperBound - lowerBound
    }
    
    var containsZero: Bool {
        return lowerBound <= 0 && upperBound >= 0
    }
}

struct CorrelationDataPoint: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let primaryValue: Double
    let secondaryValue: Double
    let weight: Double // For weighted correlations
    
    init(timestamp: Date, primaryValue: Double, secondaryValue: Double, weight: Double = 1.0) {
        self.id = UUID()
        self.timestamp = timestamp
        self.primaryValue = primaryValue
        self.secondaryValue = secondaryValue
        self.weight = weight
    }
}

enum CorrelationType: String, CaseIterable, Codable {
    case strong = "strong"
    case moderate = "moderate"
    case weak = "weak"
    case negligible = "negligible"
    
    var displayName: String {
        switch self {
        case .strong: return "強い"
        case .moderate: return "中程度"
        case .weak: return "弱い"
        case .negligible: return "無視できる"
        }
    }
}

enum CorrelationStrength: String, CaseIterable, Codable {
    case veryStrong = "very_strong"    // 0.8-1.0
    case strong = "strong"             // 0.6-0.8
    case moderate = "moderate"         // 0.4-0.6
    case weak = "weak"                 // 0.2-0.4
    case veryWeak = "very_weak"        // 0.0-0.2
    
    init(from coefficient: Double) {
        let abs = Swift.abs(coefficient)
        switch abs {
        case 0.8...1.0: self = .veryStrong
        case 0.6..<0.8: self = .strong
        case 0.4..<0.6: self = .moderate
        case 0.2..<0.4: self = .weak
        default: self = .veryWeak
        }
    }
    
    var displayName: String {
        switch self {
        case .veryStrong: return "非常に強い"
        case .strong: return "強い"
        case .moderate: return "中程度"
        case .weak: return "弱い"
        case .veryWeak: return "非常に弱い"
        }
    }
}

enum CorrelationDirection: String, CaseIterable, Codable {
    case positive = "positive"
    case negative = "negative"
    case neutral = "neutral"
    
    var displayName: String {
        switch self {
        case .positive: return "正の相関"
        case .negative: return "負の相関"
        case .neutral: return "相関なし"
        }
    }
}

enum StatisticalSignificance: String, CaseIterable, Codable {
    case highlySignificant = "highly_significant"    // p < 0.01
    case significant = "significant"                  // p < 0.05
    case marginallySignificant = "marginally_significant" // p < 0.1
    case notSignificant = "not_significant"          // p >= 0.1
    
    var displayName: String {
        switch self {
        case .highlySignificant: return "高度に有意"
        case .significant: return "有意"
        case .marginallySignificant: return "やや有意"
        case .notSignificant: return "有意でない"
        }
    }
}

struct LaggedCorrelationResult: Codable, Identifiable {
    let id: UUID
    let leadingDataType: HealthDataType
    let laggingDataType: HealthDataType
    let maxLagDays: Int
    let lagCorrelations: [LagCorrelation]
    let bestLag: LagCorrelation?
    let overallPattern: LagPattern
    let confidence: Double
    let generatedAt: Date
    
    init(leadingDataType: HealthDataType, laggingDataType: HealthDataType, maxLagDays: Int, lagCorrelations: [LagCorrelation]) {
        self.id = UUID()
        self.leadingDataType = leadingDataType
        self.laggingDataType = laggingDataType
        self.maxLagDays = maxLagDays
        self.lagCorrelations = lagCorrelations
        self.bestLag = lagCorrelations.max(by: { abs($0.correlationCoefficient) < abs($1.correlationCoefficient) })
        self.overallPattern = LagPattern.determinePattern(from: lagCorrelations)
        self.confidence = lagCorrelations.map { $0.confidence }.reduce(0, +) / Double(lagCorrelations.count)
        self.generatedAt = Date()
    }
}

struct LagCorrelation: Codable, Identifiable {
    let id: UUID
    let lagDays: Int
    let correlationCoefficient: Double
    let pValue: Double
    let confidence: Double
    let sampleSize: Int
    
    init(lagDays: Int, correlationCoefficient: Double, pValue: Double, confidence: Double, sampleSize: Int) {
        self.id = UUID()
        self.lagDays = lagDays
        self.correlationCoefficient = correlationCoefficient
        self.pValue = pValue
        self.confidence = confidence
        self.sampleSize = sampleSize
    }
}

enum LagPattern: String, CaseIterable, Codable {
    case immediate = "immediate"           // Best correlation at lag 0
    case shortDelay = "short_delay"        // Best correlation at lag 1-3
    case mediumDelay = "medium_delay"      // Best correlation at lag 4-7
    case longDelay = "long_delay"         // Best correlation at lag 8+
    case noPattern = "no_pattern"         // No clear pattern
    
    static func determinePattern(from lagCorrelations: [LagCorrelation]) -> LagPattern {
        guard let bestLag = lagCorrelations.max(by: { abs($0.correlationCoefficient) < abs($1.correlationCoefficient) }) else {
            return .noPattern
        }
        
        switch bestLag.lagDays {
        case 0: return .immediate
        case 1...3: return .shortDelay
        case 4...7: return .mediumDelay
        case 8...: return .longDelay
        default: return .noPattern
        }
    }
    
    var displayName: String {
        switch self {
        case .immediate: return "即座"
        case .shortDelay: return "短期遅延"
        case .mediumDelay: return "中期遅延"
        case .longDelay: return "長期遅延"
        case .noPattern: return "パターンなし"
        }
    }
}

// MARK: - Pattern Recognition Models

struct HealthPattern: Codable, Identifiable {
    let id: UUID
    let dataType: HealthDataType
    let patternType: PatternType
    let confidence: Double
    let startDate: Date
    let endDate: Date
    let amplitude: Double? // For cyclical patterns
    let frequency: Double? // For cyclical patterns
    let slope: Double? // For trending patterns
    let description: String
    let significance: PatternSignificance
    let predictedContinuation: PatternContinuation
    let relatedFactors: [PatternFactor]
    let detectionMethod: PatternDetectionMethod
    let generatedAt: Date
    
    init(dataType: HealthDataType, patternType: PatternType, confidence: Double, startDate: Date, endDate: Date, description: String, detectionMethod: PatternDetectionMethod, amplitude: Double? = nil, frequency: Double? = nil, slope: Double? = nil, relatedFactors: [PatternFactor] = []) {
        self.id = UUID()
        self.dataType = dataType
        self.patternType = patternType
        self.confidence = confidence
        self.startDate = startDate
        self.endDate = endDate
        self.amplitude = amplitude
        self.frequency = frequency
        self.slope = slope
        self.description = description
        self.detectionMethod = detectionMethod
        self.relatedFactors = relatedFactors
        self.generatedAt = Date()
        
        // Derived properties
        self.significance = confidence > 0.8 ? .high : confidence > 0.6 ? .medium : .low
        self.predictedContinuation = PatternContinuation.predict(from: patternType, confidence: confidence)
    }
}

enum PatternSignificance: String, CaseIterable, Codable {
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

enum PatternContinuation: String, CaseIterable, Codable {
    case likely = "likely"
    case possible = "possible"
    case unlikely = "unlikely"
    case uncertain = "uncertain"
    
    static func predict(from type: PatternType, confidence: Double) -> PatternContinuation {
        switch (type, confidence) {
        case (.trending, 0.8...): return .likely
        case (.cyclical, 0.7...): return .likely
        case (.seasonal, 0.6...): return .likely
        case (_, 0.6...): return .possible
        case (_, 0.4...): return .unlikely
        default: return .uncertain
        }
    }
    
    var displayName: String {
        switch self {
        case .likely: return "継続する可能性が高い"
        case .possible: return "継続する可能性がある"
        case .unlikely: return "継続しにくい"
        case .uncertain: return "不明"
        }
    }
}

struct PatternFactor: Codable, Identifiable {
    let id: UUID
    let factorType: PatternFactorType
    let influence: Double // -1.0 to 1.0
    let description: String
    let confidence: Double
    
    init(factorType: PatternFactorType, influence: Double, description: String, confidence: Double) {
        self.id = UUID()
        self.factorType = factorType
        self.influence = influence
        self.description = description
        self.confidence = confidence
    }
}

enum PatternFactorType: String, CaseIterable, Codable {
    case environmental = "environmental"
    case behavioral = "behavioral"
    case physiological = "physiological"
    case psychological = "psychological"
    case external = "external"
    
    var displayName: String {
        switch self {
        case .environmental: return "環境的"
        case .behavioral: return "行動的"
        case .physiological: return "生理的"
        case .psychological: return "心理的"
        case .external: return "外的"
        }
    }
}

enum PatternDetectionMethod: String, CaseIterable, Codable {
    case statisticalAnalysis = "statistical_analysis"
    case spectralAnalysis = "spectral_analysis"
    case machinelearning = "machine_learning"
    case heuristicRules = "heuristic_rules"
    case hybridApproach = "hybrid_approach"
    
    var displayName: String {
        switch self {
        case .statisticalAnalysis: return "統計分析"
        case .spectralAnalysis: return "スペクトル分析"
        case .machinelearning: return "機械学習"
        case .heuristicRules: return "ヒューリスティック"
        case .hybridApproach: return "ハイブリッド"
        }
    }
}

struct SeasonalPattern: Codable, Identifiable {
    let id: UUID
    let dataType: HealthDataType
    let seasonalCycle: SeasonalCycle
    let amplitude: Double
    let phase: Double // Phase shift in days
    let confidence: Double
    let detectedCycles: Int
    let peakSeason: Season
    let troughSeason: Season
    let yearlyTrend: SeasonalTrend
    let adjustedRSquared: Double
    let description: String
    let generatedAt: Date
    
    init(dataType: HealthDataType, seasonalCycle: SeasonalCycle, amplitude: Double, phase: Double, confidence: Double, detectedCycles: Int, peakSeason: Season, troughSeason: Season, yearlyTrend: SeasonalTrend, adjustedRSquared: Double, description: String) {
        self.id = UUID()
        self.dataType = dataType
        self.seasonalCycle = seasonalCycle
        self.amplitude = amplitude
        self.phase = phase
        self.confidence = confidence
        self.detectedCycles = detectedCycles
        self.peakSeason = peakSeason
        self.troughSeason = troughSeason
        self.yearlyTrend = yearlyTrend
        self.adjustedRSquared = adjustedRSquared
        self.description = description
        self.generatedAt = Date()
    }
}

enum SeasonalCycle: String, CaseIterable, Codable {
    case quarterly = "quarterly"
    case biannual = "biannual"
    case annual = "annual"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .quarterly: return "四半期"
        case .biannual: return "半年"
        case .annual: return "年間"
        case .custom: return "カスタム"
        }
    }
    
    var cycleLengthDays: Int {
        switch self {
        case .quarterly: return 90
        case .biannual: return 180
        case .annual: return 365
        case .custom: return -1
        }
    }
}

// Season enum is defined in AIGoalSuggestionModels.swift

enum SeasonalTrend: String, CaseIterable, Codable {
    case increasing = "increasing"
    case decreasing = "decreasing"
    case stable = "stable"
    case variable = "variable"
    
    var displayName: String {
        switch self {
        case .increasing: return "増加傾向"
        case .decreasing: return "減少傾向"
        case .stable: return "安定"
        case .variable: return "変動"
        }
    }
}

struct CyclicalPatternAnalysis: Codable, Identifiable {
    let id: UUID
    let dataType: HealthDataType
    let expectedCycleLength: CycleLength
    let detectedCycles: [DetectedCycle]
    let averageCycleLength: Double
    let cycleConsistency: Double
    let amplitude: CycleAmplitude
    let phaseAlignment: PhaseAlignment
    let overallConfidence: Double
    let predictiveAccuracy: Double
    let recommendations: [CycleRecommendation]
    let generatedAt: Date
    
    init(dataType: HealthDataType, expectedCycleLength: CycleLength, detectedCycles: [DetectedCycle], recommendations: [CycleRecommendation]) {
        self.id = UUID()
        self.dataType = dataType
        self.expectedCycleLength = expectedCycleLength
        self.detectedCycles = detectedCycles
        self.recommendations = recommendations
        self.generatedAt = Date()
        
        // Calculate derived properties
        self.averageCycleLength = detectedCycles.isEmpty ? 0 : detectedCycles.map { $0.lengthDays }.reduce(0, +) / Double(detectedCycles.count)
        self.cycleConsistency = CyclicalPatternAnalysis.calculateConsistency(cycles: detectedCycles)
        self.amplitude = CycleAmplitude.calculate(from: detectedCycles)
        self.phaseAlignment = PhaseAlignment.calculate(from: detectedCycles)
        self.overallConfidence = detectedCycles.isEmpty ? 0 : detectedCycles.map { $0.confidence }.reduce(0, +) / Double(detectedCycles.count)
        self.predictiveAccuracy = min(1.0, cycleConsistency * overallConfidence)
    }
    
    private static func calculateConsistency(cycles: [DetectedCycle]) -> Double {
        guard cycles.count > 1 else { return 0.0 }
        
        let lengths = cycles.map { $0.lengthDays }
        let mean = lengths.reduce(0, +) / Double(lengths.count)
        let variance = lengths.map { pow($0 - mean, 2) }.reduce(0, +) / Double(lengths.count)
        let standardDeviation = sqrt(variance)
        let coefficientOfVariation = mean > 0 ? standardDeviation / mean : 1.0
        
        return max(0.0, 1.0 - coefficientOfVariation)
    }
}

struct DetectedCycle: Codable, Identifiable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let lengthDays: Double
    let amplitude: Double
    let peakValue: Double
    let troughValue: Double
    let confidence: Double
    let quality: CycleQuality
    
    init(startDate: Date, endDate: Date, amplitude: Double, peakValue: Double, troughValue: Double, confidence: Double) {
        self.id = UUID()
        self.startDate = startDate
        self.endDate = endDate
        self.lengthDays = endDate.timeIntervalSince(startDate) / (24 * 60 * 60)
        self.amplitude = amplitude
        self.peakValue = peakValue
        self.troughValue = troughValue
        self.confidence = confidence
        self.quality = confidence > 0.8 ? .excellent : confidence > 0.6 ? .good : confidence > 0.4 ? .fair : .poor
    }
}

enum CycleQuality: String, CaseIterable, Codable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    
    var displayName: String {
        switch self {
        case .excellent: return "優秀"
        case .good: return "良好"
        case .fair: return "普通"
        case .poor: return "劣悪"
        }
    }
}

enum CycleAmplitude: String, CaseIterable, Codable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    static func calculate(from cycles: [DetectedCycle]) -> CycleAmplitude {
        guard !cycles.isEmpty else { return .low }
        
        let averageAmplitude = cycles.map { $0.amplitude }.reduce(0, +) / Double(cycles.count)
        
        switch averageAmplitude {
        case 0.5...: return .high
        case 0.2..<0.5: return .medium
        default: return .low
        }
    }
    
    var displayName: String {
        switch self {
        case .high: return "高振幅"
        case .medium: return "中振幅"
        case .low: return "低振幅"
        }
    }
}

enum PhaseAlignment: String, CaseIterable, Codable {
    case aligned = "aligned"
    case partiallyAligned = "partially_aligned"
    case misaligned = "misaligned"
    
    static func calculate(from cycles: [DetectedCycle]) -> PhaseAlignment {
        guard cycles.count > 1 else { return .aligned }
        
        // Simplified phase alignment calculation
        let cycleLengths = cycles.map { $0.lengthDays }
        let meanLength = cycleLengths.reduce(0, +) / Double(cycleLengths.count)
        let variance = cycleLengths.map { pow($0 - meanLength, 2) }.reduce(0, +) / Double(cycleLengths.count)
        let coefficientOfVariation = sqrt(variance) / meanLength
        
        switch coefficientOfVariation {
        case 0..<0.1: return .aligned
        case 0.1..<0.3: return .partiallyAligned
        default: return .misaligned
        }
    }
    
    var displayName: String {
        switch self {
        case .aligned: return "位相一致"
        case .partiallyAligned: return "部分一致"
        case .misaligned: return "位相不一致"
        }
    }
}

struct CycleRecommendation: Codable, Identifiable {
    let id: UUID
    let type: CycleRecommendationType
    let title: String
    let description: String
    let actionItems: [String]
    let expectedImpact: Double
    let implementationDifficulty: RecommendationDifficulty
    let timeToImplement: TimeInterval
    
    init(type: CycleRecommendationType, title: String, description: String, actionItems: [String], expectedImpact: Double, implementationDifficulty: RecommendationDifficulty, timeToImplement: TimeInterval) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.description = description
        self.actionItems = actionItems
        self.expectedImpact = expectedImpact
        self.implementationDifficulty = implementationDifficulty
        self.timeToImplement = timeToImplement
    }
}

enum CycleRecommendationType: String, CaseIterable, Codable {
    case optimization = "optimization"
    case stabilization = "stabilization"
    case amplification = "amplification"
    case dampening = "dampening"
    case timing = "timing"
    
    var displayName: String {
        switch self {
        case .optimization: return "最適化"
        case .stabilization: return "安定化"
        case .amplification: return "増幅"
        case .dampening: return "減衰"
        case .timing: return "タイミング"
        }
    }
}


struct AnomalousPattern: Codable, Identifiable {
    let id: UUID
    let dataType: HealthDataType
    let anomalyType: AnomalyType
    let severity: InsightAnomalySeverity
    let startDate: Date
    let endDate: Date?
    let expectedValue: Double
    let observedValue: Double
    let deviationMagnitude: Double
    let statisticalSignificance: Double
    let confidence: Double
    let potentialCauses: [PotentialCause]
    let immediateActions: [ImmediateAction]
    let monitoringRecommendations: [MonitoringRecommendation]
    let isOngoing: Bool
    let detectionMethod: AnomalyDetectionMethod
    let contextualFactors: [ContextualFactor]
    let generatedAt: Date
    
    init(dataType: HealthDataType, anomalyType: AnomalyType, severity: InsightAnomalySeverity, startDate: Date, expectedValue: Double, observedValue: Double, confidence: Double, detectionMethod: AnomalyDetectionMethod, endDate: Date? = nil, potentialCauses: [PotentialCause] = [], immediateActions: [ImmediateAction] = [], monitoringRecommendations: [MonitoringRecommendation] = [], contextualFactors: [ContextualFactor] = []) {
        self.id = UUID()
        self.dataType = dataType
        self.anomalyType = anomalyType
        self.severity = severity
        self.startDate = startDate
        self.endDate = endDate
        self.expectedValue = expectedValue
        self.observedValue = observedValue
        self.confidence = confidence
        self.detectionMethod = detectionMethod
        self.potentialCauses = potentialCauses
        self.immediateActions = immediateActions
        self.monitoringRecommendations = monitoringRecommendations
        self.contextualFactors = contextualFactors
        self.generatedAt = Date()
        
        // Calculated properties
        self.deviationMagnitude = abs(observedValue - expectedValue) / max(abs(expectedValue), 1.0)
        self.statisticalSignificance = min(1.0, deviationMagnitude * confidence)
        self.isOngoing = endDate == nil
    }
}

enum AnomalyType: String, CaseIterable, Codable {
    case spike = "spike"                 // Sudden increase
    case drop = "drop"                   // Sudden decrease
    case plateau = "plateau"             // Unexpected flatness
    case oscillation = "oscillation"     // Unexpected variability
    case drift = "drift"                // Gradual shift from baseline
    case missing = "missing"             // Missing data pattern
    case outlier = "outlier"            // Single point anomaly
    
    var displayName: String {
        switch self {
        case .spike: return "急激な上昇"
        case .drop: return "急激な下降"
        case .plateau: return "異常な平坦化"
        case .oscillation: return "異常な変動"
        case .drift: return "ベースライン偏移"
        case .missing: return "データ欠損"
        case .outlier: return "外れ値"
        }
    }
}

enum InsightAnomalySeverity: String, CaseIterable, Codable {
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
    
    var colorCode: String {
        switch self {
        case .critical: return "#FF0000"
        case .high: return "#FF6600"
        case .medium: return "#FFAA00"
        case .low: return "#FFDD00"
        case .informational: return "#0088FF"
        }
    }
    
    var color: Color {
        switch self {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .green
        case .informational: return .blue
        }
    }
    
    var iconName: String {
        switch self {
        case .critical: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.triangle"
        case .medium: return "exclamationmark.circle"
        case .low: return "info.circle"
        case .informational: return "info.circle.fill"
        }
    }
}

struct PotentialCause: Codable, Identifiable {
    let id: UUID
    let category: CauseCategory
    let description: String
    let likelihood: Double // 0.0 to 1.0
    let evidenceStrength: EvidenceStrength
    let investigationSteps: [String]
    
    init(category: CauseCategory, description: String, likelihood: Double, evidenceStrength: EvidenceStrength, investigationSteps: [String]) {
        self.id = UUID()
        self.category = category
        self.description = description
        self.likelihood = likelihood
        self.evidenceStrength = evidenceStrength
        self.investigationSteps = investigationSteps
    }
}

enum CauseCategory: String, CaseIterable, Codable {
    case physiological = "physiological"
    case behavioral = "behavioral"
    case environmental = "environmental"
    case medicinal = "medicinal"
    case technical = "technical"
    case psychological = "psychological"
    
    var displayName: String {
        switch self {
        case .physiological: return "生理的"
        case .behavioral: return "行動的"
        case .environmental: return "環境的"
        case .medicinal: return "薬理的"
        case .technical: return "技術的"
        case .psychological: return "心理的"
        }
    }
}

enum EvidenceStrength: String, CaseIterable, Codable {
    case strong = "strong"
    case moderate = "moderate"
    case weak = "weak"
    case speculative = "speculative"
    
    var displayName: String {
        switch self {
        case .strong: return "強い"
        case .moderate: return "中程度"
        case .weak: return "弱い"
        case .speculative: return "推測的"
        }
    }
}

struct ImmediateAction: Codable, Identifiable {
    let id: UUID
    let priority: ActionPriority
    let description: String
    let timeframe: ActionTimeframe
    let difficulty: ActionDifficulty
    let expectedOutcome: String
    let riskLevel: ActionRiskLevel
    
    init(priority: ActionPriority, description: String, timeframe: ActionTimeframe, difficulty: ActionDifficulty, expectedOutcome: String, riskLevel: ActionRiskLevel) {
        self.id = UUID()
        self.priority = priority
        self.description = description
        self.timeframe = timeframe
        self.difficulty = difficulty
        self.expectedOutcome = expectedOutcome
        self.riskLevel = riskLevel
    }
}

enum ActionPriority: String, CaseIterable, Codable {
    case immediate = "immediate"
    case urgent = "urgent"
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    var displayName: String {
        switch self {
        case .immediate: return "即座"
        case .urgent: return "緊急"
        case .high: return "高"
        case .medium: return "中"
        case .low: return "低"
        }
    }
}

enum ActionTimeframe: String, CaseIterable, Codable {
    case immediate = "immediate"      // Within hours
    case today = "today"             // Within 24 hours
    case thisWeek = "this_week"      // Within 7 days
    case soon = "soon"               // Within 1 month
    
    var displayName: String {
        switch self {
        case .immediate: return "即座に"
        case .today: return "今日中に"
        case .thisWeek: return "今週中に"
        case .soon: return "近日中に"
        }
    }
}

enum ActionDifficulty: String, CaseIterable, Codable {
    case trivial = "trivial"
    case easy = "easy"
    case moderate = "moderate"
    case challenging = "challenging"
    case expert = "expert"
    
    var displayName: String {
        switch self {
        case .trivial: return "簡単"
        case .easy: return "容易"
        case .moderate: return "中程度"
        case .challenging: return "困難"
        case .expert: return "専門的"
        }
    }
}

enum ActionRiskLevel: String, CaseIterable, Codable {
    case noRisk = "no_risk"
    case lowRisk = "low_risk"
    case mediumRisk = "medium_risk"
    case highRisk = "high_risk"
    
    var displayName: String {
        switch self {
        case .noRisk: return "リスクなし"
        case .lowRisk: return "低リスク"
        case .mediumRisk: return "中リスク"
        case .highRisk: return "高リスク"
        }
    }
}

struct MonitoringRecommendation: Codable, Identifiable {
    let id: UUID
    let monitoringType: MonitoringType
    let frequency: MonitoringFrequency
    let duration: MonitoringDuration
    let keyMetrics: [String]
    let alertThresholds: [AlertThreshold]
    let reviewSchedule: ReviewSchedule
    let escalationCriteria: [EscalationCriterion]
    let description: String
    
    init(monitoringType: MonitoringType, frequency: MonitoringFrequency, duration: MonitoringDuration, keyMetrics: [String], alertThresholds: [AlertThreshold], reviewSchedule: ReviewSchedule, escalationCriteria: [EscalationCriterion], description: String) {
        self.id = UUID()
        self.monitoringType = monitoringType
        self.frequency = frequency
        self.duration = duration
        self.keyMetrics = keyMetrics
        self.alertThresholds = alertThresholds
        self.reviewSchedule = reviewSchedule
        self.escalationCriteria = escalationCriteria
        self.description = description
    }
}

enum MonitoringType: String, CaseIterable, Codable {
    case continuous = "continuous"
    case frequent = "frequent"
    case regular = "regular"
    case periodic = "periodic"
    case asNeeded = "as_needed"
    
    var displayName: String {
        switch self {
        case .continuous: return "継続的"
        case .frequent: return "頻繁"
        case .regular: return "定期的"
        case .periodic: return "周期的"
        case .asNeeded: return "必要時"
        }
    }
}

enum MonitoringFrequency: String, CaseIterable, Codable {
    case continuous = "continuous"
    case realTime = "real_time"
    case hourly = "hourly"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    
    var displayName: String {
        switch self {
        case .continuous: return "継続的"
        case .realTime: return "リアルタイム"
        case .hourly: return "時間毎"
        case .daily: return "日次"
        case .weekly: return "週次"
        case .monthly: return "月次"
        case .quarterly: return "四半期"
        }
    }
}

enum MonitoringDuration: String, CaseIterable, Codable {
    case shortTerm = "short_term"    // 1-7 days
    case mediumTerm = "medium_term"  // 1-4 weeks
    case longTerm = "long_term"      // 1-6 months
    case ongoing = "ongoing"         // Indefinite
    
    var displayName: String {
        switch self {
        case .shortTerm: return "短期"
        case .mediumTerm: return "中期"
        case .longTerm: return "長期"
        case .ongoing: return "継続的"
        }
    }
}

struct AlertThreshold: Codable, Identifiable {
    let id: UUID
    let metricName: String
    let comparisonOperator: ComparisonOperator
    let value: Double
    let severity: InsightAnomalySeverity
    let description: String
    
    init(metricName: String, comparisonOperator: ComparisonOperator, value: Double, severity: InsightAnomalySeverity, description: String) {
        self.id = UUID()
        self.metricName = metricName
        self.comparisonOperator = comparisonOperator
        self.value = value
        self.severity = severity
        self.description = description
    }
}


struct ReviewSchedule: Codable, Identifiable {
    let id: UUID
    let frequency: ReviewFrequency
    let participants: [ReviewParticipant]
    let agenda: [String]
    let deliverables: [String]
    
    init(frequency: ReviewFrequency, participants: [ReviewParticipant], agenda: [String], deliverables: [String]) {
        self.id = UUID()
        self.frequency = frequency
        self.participants = participants
        self.agenda = agenda
        self.deliverables = deliverables
    }
}

enum ReviewFrequency: String, CaseIterable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case biweekly = "biweekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    
    var displayName: String {
        switch self {
        case .daily: return "日次"
        case .weekly: return "週次"
        case .biweekly: return "隔週"
        case .monthly: return "月次"
        case .quarterly: return "四半期"
        }
    }
}

enum ReviewParticipant: String, CaseIterable, Codable {
    case user = "user"
    case system = "system"
    case healthcareProvider = "healthcare_provider"
    case familyMember = "family_member"
    case coach = "coach"
    
    var displayName: String {
        switch self {
        case .user: return "ユーザー"
        case .system: return "システム"
        case .healthcareProvider: return "医療提供者"
        case .familyMember: return "家族"
        case .coach: return "コーチ"
        }
    }
}

struct EscalationCriterion: Codable, Identifiable {
    let id: UUID
    let triggerCondition: String
    let escalationLevel: EscalationLevel
    let timeframe: TimeInterval
    let actions: [String]
    let contacts: [EmergencyContact]
    
    init(triggerCondition: String, escalationLevel: EscalationLevel, timeframe: TimeInterval, actions: [String], contacts: [EmergencyContact]) {
        self.id = UUID()
        self.triggerCondition = triggerCondition
        self.escalationLevel = escalationLevel
        self.timeframe = timeframe
        self.actions = actions
        self.contacts = contacts
    }
}

enum EscalationLevel: String, CaseIterable, Codable {
    case notification = "notification"
    case warning = "warning"
    case alert = "alert"
    case emergency = "emergency"
    
    var displayName: String {
        switch self {
        case .notification: return "通知"
        case .warning: return "警告"
        case .alert: return "アラート"
        case .emergency: return "緊急"
        }
    }
}

struct EmergencyContact: Codable, Identifiable {
    let id: UUID
    let name: String
    let relationship: ContactRelationship
    let phoneNumber: String
    let email: String?
    let isAvailable247: Bool
    let preferredContactMethod: ContactMethod
    
    init(name: String, relationship: ContactRelationship, phoneNumber: String, email: String? = nil, isAvailable247: Bool = false, preferredContactMethod: ContactMethod) {
        self.id = UUID()
        self.name = name
        self.relationship = relationship
        self.phoneNumber = phoneNumber
        self.email = email
        self.isAvailable247 = isAvailable247
        self.preferredContactMethod = preferredContactMethod
    }
}

enum ContactRelationship: String, CaseIterable, Codable {
    case doctor = "doctor"
    case nurse = "nurse"
    case familyMember = "family_member"
    case friend = "friend"
    case coach = "coach"
    case emergencyServices = "emergency_services"
    
    var displayName: String {
        switch self {
        case .doctor: return "医師"
        case .nurse: return "看護師"
        case .familyMember: return "家族"
        case .friend: return "友人"
        case .coach: return "コーチ"
        case .emergencyServices: return "緊急サービス"
        }
    }
}

enum ContactMethod: String, CaseIterable, Codable {
    case phone = "phone"
    case sms = "sms"
    case email = "email"
    case app = "app"
    
    var displayName: String {
        switch self {
        case .phone: return "電話"
        case .sms: return "SMS"
        case .email: return "メール"
        case .app: return "アプリ"
        }
    }
}

enum AnomalyDetectionMethod: String, CaseIterable, Codable {
    case statisticalThreshold = "statistical_threshold"
    case movingAverage = "moving_average"
    case seasonalDecomposition = "seasonal_decomposition"
    case timeSeriesDecomposition = "time_series_decomposition"
    case isolationForest = "isolation_forest"
    case oneClassSVM = "one_class_svm"
    case autoencoder = "autoencoder"
    case neuralNetwork = "neural_network"
    case clustering = "clustering"
    case ensemble = "ensemble"
    case ensembleMethod = "ensemble_method"
    
    var displayName: String {
        switch self {
        case .statisticalThreshold: return "統計的閾値"
        case .movingAverage: return "移動平均"
        case .seasonalDecomposition: return "季節分解"
        case .timeSeriesDecomposition: return "時系列分解"
        case .isolationForest: return "Isolation Forest"
        case .oneClassSVM: return "One-Class SVM"
        case .autoencoder: return "オートエンコーダー"
        case .neuralNetwork: return "ニューラルネットワーク"
        case .clustering: return "クラスタリング"
        case .ensemble: return "アンサンブル"
        case .ensembleMethod: return "アンサンブル手法"
        }
    }
}

struct ContextualFactor: Codable, Identifiable {
    let id: UUID
    let factorType: ContextualFactorType
    let description: String
    let influence: Double // -1.0 to 1.0
    let confidence: Double
    let timestamp: Date
    
    init(factorType: ContextualFactorType, description: String, influence: Double, confidence: Double, timestamp: Date = Date()) {
        self.id = UUID()
        self.factorType = factorType
        self.description = description
        self.influence = influence
        self.confidence = confidence
        self.timestamp = timestamp
    }
}

enum ContextualFactorType: String, CaseIterable, Codable {
    case weather = "weather"
    case stress = "stress"
    case sleep = "sleep"
    case diet = "diet"
    case exercise = "exercise"
    case medication = "medication"
    case illness = "illness"
    case travel = "travel"
    case workSchedule = "work_schedule"
    case socialEvents = "social_events"
    
    var displayName: String {
        switch self {
        case .weather: return "天候"
        case .stress: return "ストレス"
        case .sleep: return "睡眠"
        case .diet: return "食事"
        case .exercise: return "運動"
        case .medication: return "薬物"
        case .illness: return "疾病"
        case .travel: return "旅行"
        case .workSchedule: return "勤務スケジュール"
        case .socialEvents: return "社交イベント"
        }
    }
}

// MARK: - Additional Missing Types

struct MetricComparison: Codable, Identifiable {
    let id: UUID
    let metricType: HealthDataType
    let userValue: Double
    let peerMedian: Double
    let peerMean: Double
    let percentile: Double
    let comparison: ComparisonResult
    let confidenceLevel: Double
    let sampleSize: Int
    
    init(metricType: HealthDataType, userValue: Double, peerMedian: Double, peerMean: Double, percentile: Double, confidenceLevel: Double, sampleSize: Int) {
        self.id = UUID()
        self.metricType = metricType
        self.userValue = userValue
        self.peerMedian = peerMedian
        self.peerMean = peerMean
        self.percentile = percentile
        self.confidenceLevel = confidenceLevel
        self.sampleSize = sampleSize
        self.comparison = Self.determineComparison(userValue: userValue, peerMedian: peerMedian, percentile: percentile)
    }
    
    private static func determineComparison(userValue: Double, peerMedian: Double, percentile: Double) -> ComparisonResult {
        if percentile >= 75 { return .aboveAverage }
        else if percentile >= 25 { return .average }
        else { return .belowAverage }
    }
}

enum ComparisonResult: String, CaseIterable, Codable {
    case aboveAverage = "above_average"
    case average = "average"
    case belowAverage = "below_average"
    
    var displayName: String {
        switch self {
        case .aboveAverage: return "平均以上"
        case .average: return "平均的"
        case .belowAverage: return "平均以下"
        }
    }
}

struct PopulationComparison: Codable, Identifiable {
    let id: UUID
    let populationType: PopulationType
    let metricType: HealthDataType
    let userValue: Double
    let populationMean: Double
    let populationStandardDeviation: Double
    let zScore: Double
    let percentile: Double
    let confidenceInterval: ConfidenceInterval
    let interpretation: PopulationComparisonResult
    
    init(populationType: PopulationType, metricType: HealthDataType, userValue: Double, populationMean: Double, populationStandardDeviation: Double) {
        self.id = UUID()
        self.populationType = populationType
        self.metricType = metricType
        self.userValue = userValue
        self.populationMean = populationMean
        self.populationStandardDeviation = populationStandardDeviation
        self.zScore = populationStandardDeviation > 0 ? (userValue - populationMean) / populationStandardDeviation : 0
        self.percentile = Self.calculatePercentile(zScore: zScore)
        self.confidenceInterval = ConfidenceInterval(lowerBound: userValue - 1.96 * populationStandardDeviation, upperBound: userValue + 1.96 * populationStandardDeviation, confidenceLevel: 0.95)
        self.interpretation = Self.interpretResult(percentile: percentile)
    }
    
    private static func calculatePercentile(zScore: Double) -> Double {
        // Simplified normal distribution percentile calculation
        return max(0, min(100, 50 + (zScore * 34.13)))
    }
    
    private static func interpretResult(percentile: Double) -> PopulationComparisonResult {
        switch percentile {
        case 90...: return .exceptional
        case 75..<90: return .aboveAverage
        case 25..<75: return .typical
        case 10..<25: return .belowAverage
        default: return .concerningLow
        }
    }
}

enum PopulationType: String, CaseIterable, Codable {
    case general = "general"
    case ageMatched = "age_matched"
    case genderMatched = "gender_matched"
    case demographicMatched = "demographic_matched"
    case healthConditionMatched = "health_condition_matched"
    
    var displayName: String {
        switch self {
        case .general: return "一般人口"
        case .ageMatched: return "同年代"
        case .genderMatched: return "同性"
        case .demographicMatched: return "同一属性"
        case .healthConditionMatched: return "同一健康状態"
        }
    }
}

enum PopulationComparisonResult: String, CaseIterable, Codable {
    case exceptional = "exceptional"
    case aboveAverage = "above_average"
    case typical = "typical"
    case belowAverage = "below_average"
    case concerningLow = "concerning_low"
    
    var displayName: String {
        switch self {
        case .exceptional: return "優秀"
        case .aboveAverage: return "平均以上"
        case .typical: return "標準的"
        case .belowAverage: return "平均以下"
        case .concerningLow: return "要注意"
        }
    }
}

struct BaselineChange: Codable, Identifiable {
    let id: UUID
    let metricType: HealthDataType
    let changeType: BaselineChangeType
    let significance: ChangeSignificance
    let oldBaseline: Double
    let newBaseline: Double
    let changeAmount: Double
    let changePercentage: Double
    let detectionDate: Date
    let confidence: Double
    let timeWindow: TimeInterval
    
    init(metricType: HealthDataType, changeType: BaselineChangeType, significance: ChangeSignificance, oldBaseline: Double, newBaseline: Double, detectionDate: Date, confidence: Double, timeWindow: TimeInterval) {
        self.id = UUID()
        self.metricType = metricType
        self.changeType = changeType
        self.significance = significance
        self.oldBaseline = oldBaseline
        self.newBaseline = newBaseline
        self.detectionDate = detectionDate
        self.confidence = confidence
        self.timeWindow = timeWindow
        self.changeAmount = newBaseline - oldBaseline
        self.changePercentage = oldBaseline != 0 ? ((newBaseline - oldBaseline) / abs(oldBaseline)) * 100 : 0
    }
}

enum BaselineChangeType: String, CaseIterable, Codable {
    case gradualIncrease = "gradual_increase"
    case gradualDecrease = "gradual_decrease"
    case suddenIncrease = "sudden_increase"
    case suddenDecrease = "sudden_decrease"
    case cyclicalShift = "cyclical_shift"
    case seasonalAdjustment = "seasonal_adjustment"
    
    var displayName: String {
        switch self {
        case .gradualIncrease: return "緩やかな増加"
        case .gradualDecrease: return "緩やかな減少"
        case .suddenIncrease: return "急激な増加"
        case .suddenDecrease: return "急激な減少"
        case .cyclicalShift: return "周期的変化"
        case .seasonalAdjustment: return "季節調整"
        }
    }
}

enum ChangeSignificance: String, CaseIterable, Codable {
    case veryHigh = "very_high"
    case high = "high"
    case moderate = "moderate"
    case low = "low"
    case negligible = "negligible"
    
    var displayName: String {
        switch self {
        case .veryHigh: return "非常に高い"
        case .high: return "高い"
        case .moderate: return "中程度"
        case .low: return "低い"
        case .negligible: return "無視できる"
        }
    }
}

// MARK: - Enhanced Analysis Models (Phase 2.1)

// Enhanced Anomaly Detection Results
struct EnhancedAnomalyResult: Codable, Identifiable {
    let id: UUID
    let detectedAnomalies: [AnomalousPattern]
    let methodResults: [AnomalyDetectionMethod: [AnomalousPattern]]
    let anomalyInsights: [HealthInsight]
    let riskAssessment: AnomalyRiskAssessment
    let analysisMetadata: AnomalyAnalysisMetadata
    
    init(detectedAnomalies: [AnomalousPattern], methodResults: [AnomalyDetectionMethod: [AnomalousPattern]], anomalyInsights: [HealthInsight], riskAssessment: AnomalyRiskAssessment, analysisMetadata: AnomalyAnalysisMetadata) {
        self.id = UUID()
        self.detectedAnomalies = detectedAnomalies
        self.methodResults = methodResults
        self.anomalyInsights = anomalyInsights
        self.riskAssessment = riskAssessment
        self.analysisMetadata = analysisMetadata
    }
}

struct AnomalyAnalysisMetadata: Codable {
    let detectionMethods: Set<AnomalyDetectionMethod>
    let analysisTimestamp: Date
    let dataQualityScore: Double
    let confidenceLevel: Double
    let processingTimeMs: Double?
    let algorithmVersions: [AnomalyDetectionMethod: String]
    
    init(detectionMethods: Set<AnomalyDetectionMethod>, analysisTimestamp: Date, dataQualityScore: Double, confidenceLevel: Double, processingTimeMs: Double? = nil, algorithmVersions: [AnomalyDetectionMethod: String] = [:]) {
        self.detectionMethods = detectionMethods
        self.analysisTimestamp = analysisTimestamp
        self.dataQualityScore = dataQualityScore
        self.confidenceLevel = confidenceLevel
        self.processingTimeMs = processingTimeMs
        self.algorithmVersions = algorithmVersions
    }
}

struct AnomalyRiskAssessment: Codable, Identifiable {
    let id: UUID
    let overallRiskLevel: RiskLevel
    let criticalAnomalies: [AnomalousPattern]
    let riskFactors: [RiskFactor]
    let immediateActions: [ImmediateAction]
    let monitoringRecommendations: [MonitoringRecommendation]
    let riskScore: Double // 0.0 to 1.0
    
    init(overallRiskLevel: RiskLevel, criticalAnomalies: [AnomalousPattern], riskFactors: [RiskFactor], immediateActions: [ImmediateAction], monitoringRecommendations: [MonitoringRecommendation], riskScore: Double) {
        self.id = UUID()
        self.overallRiskLevel = overallRiskLevel
        self.criticalAnomalies = criticalAnomalies
        self.riskFactors = riskFactors
        self.immediateActions = immediateActions
        self.monitoringRecommendations = monitoringRecommendations
        self.riskScore = riskScore
    }
}

// Advanced Correlation Analysis
struct AdvancedCorrelationOptions: Codable {
    let minimumSampleSize: Int
    let timeWindow: CorrelationTimeWindow
    let maxLagDays: Int
    let controlVariables: [HealthDataType]
    let confidenceLevel: Double
    let includeCausalityAnalysis: Bool
    let includeNonLinearPatterns: Bool
    
    init(minimumSampleSize: Int = 10, timeWindow: CorrelationTimeWindow = .weekly, maxLagDays: Int = 7, controlVariables: [HealthDataType] = [], confidenceLevel: Double = 0.95, includeCausalityAnalysis: Bool = true, includeNonLinearPatterns: Bool = true) {
        self.minimumSampleSize = minimumSampleSize
        self.timeWindow = timeWindow
        self.maxLagDays = maxLagDays
        self.controlVariables = controlVariables
        self.confidenceLevel = confidenceLevel
        self.includeCausalityAnalysis = includeCausalityAnalysis
        self.includeNonLinearPatterns = includeNonLinearPatterns
    }
    
    var description: String {
        return "AdvancedCorrelationOptions(sampleSize: \(minimumSampleSize), window: \(timeWindow.rawValue), maxLag: \(maxLagDays))"
    }
}

struct AdvancedCorrelationResult: Codable, Identifiable {
    let id: UUID
    let primaryDataType: HealthDataType
    let secondaryDataType: HealthDataType
    let correlationResults: [CorrelationMethod: Double]
    let partialCorrelations: [PartialCorrelationResult]
    let timeLaggedCorrelations: [TimeLaggedCorrelation]
    let nonLinearPatterns: [NonLinearPattern]
    let causalityResult: CausalityAnalysisResult
    let significanceResults: [CorrelationMethod: StatisticalSignificanceResult]
    let analysisOptions: AdvancedCorrelationOptions
    let sampleSize: Int
    let dataQualityMetrics: DataQualityMetrics
    let interpretationGuide: CorrelationInterpretationGuide
    let analysisTimestamp: Date
    
    init(primaryDataType: HealthDataType, secondaryDataType: HealthDataType, correlationResults: [CorrelationMethod: Double], partialCorrelations: [PartialCorrelationResult], timeLaggedCorrelations: [TimeLaggedCorrelation], nonLinearPatterns: [NonLinearPattern], causalityResult: CausalityAnalysisResult, significanceResults: [CorrelationMethod: StatisticalSignificanceResult], analysisOptions: AdvancedCorrelationOptions, sampleSize: Int, dataQualityMetrics: DataQualityMetrics, interpretationGuide: CorrelationInterpretationGuide) {
        self.id = UUID()
        self.primaryDataType = primaryDataType
        self.secondaryDataType = secondaryDataType
        self.correlationResults = correlationResults
        self.partialCorrelations = partialCorrelations
        self.timeLaggedCorrelations = timeLaggedCorrelations
        self.nonLinearPatterns = nonLinearPatterns
        self.causalityResult = causalityResult
        self.significanceResults = significanceResults
        self.analysisOptions = analysisOptions
        self.sampleSize = sampleSize
        self.dataQualityMetrics = dataQualityMetrics
        self.interpretationGuide = interpretationGuide
        self.analysisTimestamp = Date()
    }
}

enum CorrelationMethod: String, CaseIterable, Codable {
    case pearson = "pearson"
    case spearman = "spearman"
    case kendall = "kendall"
    case partial = "partial"
    case canonical = "canonical"
    
    var displayName: String {
        switch self {
        case .pearson: return "ピアソン相関"
        case .spearman: return "スピアマン順位相関"
        case .kendall: return "ケンドールのタウ"
        case .partial: return "偏相関"
        case .canonical: return "正準相関"
        }
    }
}

struct TimeLaggedCorrelation: Codable, Identifiable {
    let id: UUID
    let baseCorrelation: CorrelationAnalysis
    let lagDays: Int
    let strength: Double
    let direction: LagDirection
    let significance: StatisticalSignificance
    
    init(baseCorrelation: CorrelationAnalysis, lagDays: Int, strength: Double) {
        self.id = UUID()
        self.baseCorrelation = baseCorrelation
        self.lagDays = lagDays
        self.strength = strength
        self.direction = lagDays > 0 ? .leading : lagDays < 0 ? .lagging : .synchronous
        self.significance = strength > 0.5 ? .significant : strength > 0.3 ? .marginallySignificant : .notSignificant
    }
}

enum LagDirection: String, CaseIterable, Codable {
    case leading = "leading"
    case lagging = "lagging"
    case synchronous = "synchronous"
    
    var displayName: String {
        switch self {
        case .leading: return "先行"
        case .lagging: return "遅行"
        case .synchronous: return "同期"
        }
    }
}

struct NonLinearPattern: Codable, Identifiable {
    let id: UUID
    let type: NonLinearPatternType
    let strength: Double
    let equation: String?
    let parameters: [String: Double]
    let rSquared: Double
    
    init(type: NonLinearPatternType, strength: Double, equation: String? = nil, parameters: [String: Double] = [:], rSquared: Double = 0.0) {
        self.id = UUID()
        self.type = type
        self.strength = strength
        self.equation = equation
        self.parameters = parameters
        self.rSquared = rSquared
    }
}

enum NonLinearPatternType: String, CaseIterable, Codable {
    case quadratic = "quadratic"
    case exponential = "exponential"
    case logarithmic = "logarithmic"
    case polynomial = "polynomial"
    case sinusoidal = "sinusoidal"
    case power = "power"
    
    var displayName: String {
        switch self {
        case .quadratic: return "二次関数"
        case .exponential: return "指数関数"
        case .logarithmic: return "対数関数"
        case .polynomial: return "多項式"
        case .sinusoidal: return "正弦波"
        case .power: return "べき関数"
        }
    }
}

// Comprehensive Monthly Report
struct ComprehensiveMonthlyReport: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let reportMonth: Date
    let executiveSummary: HealthInsight
    let keyMetrics: [HealthInsight]
    let correlationAnalysis: AdvancedCorrelationAnalysis?
    let anomalyAnalysis: EnhancedAnomalyAnalysis
    let trendAnalysis: AdvancedTrendAnalysis
    let goalAnalysis: IntelligentGoalAnalysis
    let riskAssessment: ComprehensiveHealthRiskAssessment
    let personalizedRecommendations: [PersonalizedRecommendation]
    let dataQualityAssessment: ComprehensiveDataQualityAssessment
    let generatedAt: Date
    let reportVersion: String
    let analyticsLevel: AnalyticsLevel
    
    init(userId: UUID, reportMonth: Date, executiveSummary: HealthInsight, keyMetrics: [HealthInsight], correlationAnalysis: AdvancedCorrelationAnalysis?, anomalyAnalysis: EnhancedAnomalyAnalysis, trendAnalysis: AdvancedTrendAnalysis, goalAnalysis: IntelligentGoalAnalysis, riskAssessment: ComprehensiveHealthRiskAssessment, personalizedRecommendations: [PersonalizedRecommendation], dataQualityAssessment: ComprehensiveDataQualityAssessment, generatedAt: Date, reportVersion: String, analyticsLevel: AnalyticsLevel) {
        self.id = UUID()
        self.userId = userId
        self.reportMonth = reportMonth
        self.executiveSummary = executiveSummary
        self.keyMetrics = keyMetrics
        self.correlationAnalysis = correlationAnalysis
        self.anomalyAnalysis = anomalyAnalysis
        self.trendAnalysis = trendAnalysis
        self.goalAnalysis = goalAnalysis
        self.riskAssessment = riskAssessment
        self.personalizedRecommendations = personalizedRecommendations
        self.dataQualityAssessment = dataQualityAssessment
        self.generatedAt = generatedAt
        self.reportVersion = reportVersion
        self.analyticsLevel = analyticsLevel
    }
}

enum AnalyticsLevel: String, CaseIterable, Codable {
    case basic = "basic"
    case standard = "standard"
    case comprehensive = "comprehensive"
    case expert = "expert"
    
    var displayName: String {
        switch self {
        case .basic: return "基本"
        case .standard: return "標準"
        case .comprehensive: return "包括的"
        case .expert: return "専門"
        }
    }
}

// Supporting Types for Monthly Report
struct AdvancedCorrelationAnalysis: Codable, Identifiable {
    let id: UUID
    let correlationResults: [AdvancedCorrelationResult]
    let insights: [HealthInsight]
    let keyFindings: [CorrelationKeyFinding]
    let causalityDiscoveries: [CausalityDiscovery]
    
    init(correlationResults: [AdvancedCorrelationResult], insights: [HealthInsight], keyFindings: [CorrelationKeyFinding], causalityDiscoveries: [CausalityDiscovery]) {
        self.id = UUID()
        self.correlationResults = correlationResults
        self.insights = insights
        self.keyFindings = keyFindings
        self.causalityDiscoveries = causalityDiscoveries
    }
}

struct EnhancedAnomalyAnalysis: Codable, Identifiable {
    let id: UUID
    let detectedAnomalies: [AnomalousPattern]
    let insights: [HealthInsight]
    let riskAssessment: AnomalyRiskAssessment
    let patterns: [AnomalyPattern]
    let interventionRecommendations: [InterventionRecommendation]
    
    init(detectedAnomalies: [AnomalousPattern], insights: [HealthInsight], riskAssessment: AnomalyRiskAssessment, patterns: [AnomalyPattern], interventionRecommendations: [InterventionRecommendation]) {
        self.id = UUID()
        self.detectedAnomalies = detectedAnomalies
        self.insights = insights
        self.riskAssessment = riskAssessment
        self.patterns = patterns
        self.interventionRecommendations = interventionRecommendations
    }
}

struct AdvancedTrendAnalysis: Codable, Identifiable {
    let id: UUID
    let insights: [HealthInsight]
    let trendDirections: [HealthDataType: TrendDirection]
    let predictions: [HealthPrediction]
    let seasonalPatterns: [SeasonalPattern]
    let changePoints: [ChangePoint]
    
    init(insights: [HealthInsight], trendDirections: [HealthDataType: TrendDirection], predictions: [HealthPrediction], seasonalPatterns: [SeasonalPattern], changePoints: [ChangePoint]) {
        self.id = UUID()
        self.insights = insights
        self.trendDirections = trendDirections
        self.predictions = predictions
        self.seasonalPatterns = seasonalPatterns
        self.changePoints = changePoints
    }
}

struct IntelligentGoalAnalysis: Codable, Identifiable {
    let id: UUID
    let insights: [HealthInsight]
    let goalProgress: [GoalProgressAnalysis]
    let adaptiveRecommendations: [AdaptiveGoalRecommendation]
    let motivationAnalysis: MotivationAnalysis
    let adherenceInsights: [AdherenceInsight]
    
    init(insights: [HealthInsight], goalProgress: [GoalProgressAnalysis], adaptiveRecommendations: [AdaptiveGoalRecommendation], motivationAnalysis: MotivationAnalysis, adherenceInsights: [AdherenceInsight]) {
        self.id = UUID()
        self.insights = insights
        self.goalProgress = goalProgress
        self.adaptiveRecommendations = adaptiveRecommendations
        self.motivationAnalysis = motivationAnalysis
        self.adherenceInsights = adherenceInsights
    }
}

struct RiskMitigationStrategy: Codable, Identifiable {
    let id: UUID
    let strategyType: String
    let description: String
    let priority: ActionPriority
    let timeframe: String
    let expectedEffectiveness: Double
    
    init(strategyType: String, description: String, priority: ActionPriority, timeframe: String, expectedEffectiveness: Double) {
        self.id = UUID()
        self.strategyType = strategyType
        self.description = description
        self.priority = priority
        self.timeframe = timeframe
        self.expectedEffectiveness = expectedEffectiveness
    }
}

struct PopulationRiskComparison: Codable, Identifiable {
    let id: UUID
    let comparisonGroup: String
    let userPercentile: Double
    let averageRiskScore: Double
    let confidenceLevel: Double
    
    init(comparisonGroup: String, userPercentile: Double, averageRiskScore: Double, confidenceLevel: Double) {
        self.id = UUID()
        self.comparisonGroup = comparisonGroup
        self.userPercentile = userPercentile
        self.averageRiskScore = averageRiskScore
        self.confidenceLevel = confidenceLevel
    }
}

struct ComprehensiveHealthRiskAssessment: Codable, Identifiable {
    let id: UUID
    let overallRiskScore: Double
    let identifiedRisks: [IdentifiedRisk]
    let protectiveFactors: [ProtectiveFactor]
    let riskMitigationStrategies: [RiskMitigationStrategy]
    let monitoringPlan: MonitoringPlan
    let populationComparison: PopulationRiskComparison?
    
    init(overallRiskScore: Double, identifiedRisks: [IdentifiedRisk], protectiveFactors: [ProtectiveFactor], riskMitigationStrategies: [RiskMitigationStrategy], monitoringPlan: MonitoringPlan, populationComparison: PopulationRiskComparison? = nil) {
        self.id = UUID()
        self.overallRiskScore = overallRiskScore
        self.identifiedRisks = identifiedRisks
        self.protectiveFactors = protectiveFactors
        self.riskMitigationStrategies = riskMitigationStrategies
        self.monitoringPlan = monitoringPlan
        self.populationComparison = populationComparison
    }
}

struct DataQualityImprovement: Codable, Identifiable {
    let id: UUID
    let category: DataQualityCategory
    let description: String
    let impact: QualityImpact
    let effort: ImplementationEffort
    let priority: ImprovementPriority
    let expectedImprovement: Double
    let timeToImplement: TimeInterval
    let actionableSteps: [String]
    
    init(category: DataQualityCategory, description: String, impact: QualityImpact, effort: ImplementationEffort, priority: ImprovementPriority, expectedImprovement: Double, timeToImplement: TimeInterval, actionableSteps: [String]) {
        self.id = UUID()
        self.category = category
        self.description = description
        self.impact = impact
        self.effort = effort
        self.priority = priority
        self.expectedImprovement = expectedImprovement
        self.timeToImplement = timeToImplement
        self.actionableSteps = actionableSteps
    }
}

enum DataQualityCategory: String, Codable, CaseIterable {
    case completeness = "完全性"
    case consistency = "一貫性"
    case accuracy = "正確性"
    case timeliness = "適時性"
    case validity = "妥当性"
}

enum QualityImpact: String, Codable, CaseIterable {
    case critical = "重大"
    case high = "高"
    case medium = "中"
    case low = "低"
}

enum ImplementationEffort: String, Codable, CaseIterable {
    case minimal = "最小"
    case low = "低"
    case medium = "中"
    case high = "高"
    case extensive = "extensive"
}

enum ImprovementPriority: String, Codable, CaseIterable {
    case urgent = "緊急"
    case high = "高"
    case medium = "中"
    case low = "低"
    case deferred = "延期"
}

struct ComprehensiveDataQualityAssessment: Codable, Identifiable {
    let id: UUID
    let overallScore: Double
    let completenessScore: Double
    let consistencyScore: Double
    let accuracyScore: Double
    let timelinessScore: Double
    let qualityIssues: [DataQualityIssue]
    let improvementRecommendations: [DataQualityImprovement]
    
    init(overallScore: Double, completenessScore: Double, consistencyScore: Double, accuracyScore: Double, timelinessScore: Double, qualityIssues: [DataQualityIssue], improvementRecommendations: [DataQualityImprovement]) {
        self.id = UUID()
        self.overallScore = overallScore
        self.completenessScore = completenessScore
        self.consistencyScore = consistencyScore
        self.accuracyScore = accuracyScore
        self.timelinessScore = timelinessScore
        self.qualityIssues = qualityIssues
        self.improvementRecommendations = improvementRecommendations
    }
}

// InsightDataQualityIssue moved to SupportingModels.swift to avoid duplication