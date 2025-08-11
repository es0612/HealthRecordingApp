import Foundation

/// 高度なトレンド指標
/// 変動係数・歪度・尖度などの高度な統計指標を含む拡張分析結果
struct AdvancedTrendIndicators: Codable {
    let dataType: HealthDataType
    let timeRange: TrendTimeRange
    let sampleSize: Int
    let basicStatistics: BasicStatistics
    let variabilityMetrics: VariabilityIndicators
    let distributionShape: DistributionShapeIndicators
    let percentileAnalysis: PercentileIndicators
    let outlierAnalysis: OutlierIndicators
    let dataQuality: DataQualityIndicators
    let trendStrength: TrendStrengthIndicators
    let seasonalityIndicators: SeasonalityIndicators?
    let calculatedAt: Date
    
    init(
        dataType: HealthDataType,
        timeRange: TrendTimeRange,
        values: [Double],
        timestamps: [Date] = []
    ) {
        self.dataType = dataType
        self.timeRange = timeRange
        self.sampleSize = values.count
        self.calculatedAt = Date()
        
        // 基本統計の計算
        self.basicStatistics = BasicStatistics(from: values)
        
        // 変動性指標の計算
        self.variabilityMetrics = VariabilityIndicators(from: values, mean: basicStatistics.mean)
        
        // 分布形状指標の計算
        self.distributionShape = DistributionShapeIndicators(from: values)
        
        // パーセンタイル分析
        self.percentileAnalysis = PercentileIndicators(from: values)
        
        // 外れ値分析
        self.outlierAnalysis = OutlierIndicators(from: values)
        
        // データ品質指標
        self.dataQuality = DataQualityIndicators(
            from: values,
            timestamps: timestamps,
            expectedDataPoints: timeRange.days
        )
        
        // トレンド強度指標
        self.trendStrength = TrendStrengthIndicators(from: values, timestamps: timestamps)
        
        // 季節性指標（年間データがある場合のみ）
        if timeRange == .year && !timestamps.isEmpty {
            self.seasonalityIndicators = SeasonalityIndicators(values: values, timestamps: timestamps)
        } else {
            self.seasonalityIndicators = nil
        }
    }
}

// MARK: - Basic Statistics

struct BasicStatistics: Codable {
    let mean: Double
    let median: Double
    let mode: Double?
    let minimum: Double
    let maximum: Double
    let range: Double
    let sum: Double
    let count: Int
    
    init(from values: [Double]) {
        self.count = values.count
        self.sum = values.reduce(0, +)
        self.mean = count > 0 ? sum / Double(count) : 0
        self.minimum = values.min() ?? 0
        self.maximum = values.max() ?? 0
        self.range = maximum - minimum
        
        // 中央値の計算
        self.median = PercentileCalculator.calculatePercentile(from: values, percentile: 0.5) ?? mean
        
        // 最頻値の計算（精度を考慮した近似計算）
        if !values.isEmpty {
            let roundedValues = values.map { round($0 * 100) / 100 }
            let frequencies = Dictionary(roundedValues.map { ($0, 1) }, uniquingKeysWith: +)
            let maxFrequency = frequencies.values.max() ?? 0
            
            if maxFrequency > 1 {
                self.mode = frequencies.first { $0.value == maxFrequency }?.key
            } else {
                self.mode = nil
            }
        } else {
            self.mode = nil
        }
    }
}

// MARK: - Variability Indicators

struct VariabilityIndicators: Codable {
    let variance: Double
    let standardDeviation: Double
    let coefficientOfVariation: Double
    let interquartileRange: Double
    let meanAbsoluteDeviation: Double
    let relativeStandardError: Double
    let variabilityLevel: VariabilityLevel
    
    init(from values: [Double], mean: Double) {
        // 標準偏差と分散
        self.standardDeviation = PercentileCalculator.calculateStandardDeviation(from: values, mean: mean)
        self.variance = standardDeviation * standardDeviation
        
        // 変動係数
        self.coefficientOfVariation = mean != 0 ? (standardDeviation / abs(mean)) * 100 : 0
        
        // 四分位範囲
        if let quartiles = PercentileCalculator.calculateQuartiles(from: values) {
            self.interquartileRange = quartiles.interquartileRange
        } else {
            self.interquartileRange = 0
        }
        
        // 平均絶対偏差
        let absoluteDeviations = values.map { abs($0 - mean) }
        self.meanAbsoluteDeviation = absoluteDeviations.reduce(0, +) / Double(max(values.count, 1))
        
        // 相対標準誤差
        let standardError = standardDeviation / sqrt(Double(max(values.count, 1)))
        self.relativeStandardError = mean != 0 ? (standardError / abs(mean)) * 100 : 0
        
        // 変動レベルの判定
        self.variabilityLevel = VariabilityLevel.assess(from: coefficientOfVariation)
    }
}

enum VariabilityLevel: String, CaseIterable, Codable {
    case veryLow = "very_low"
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case veryHigh = "very_high"
    
    var displayName: String {
        switch self {
        case .veryLow: return "非常に安定"
        case .low: return "安定"
        case .moderate: return "適度な変動"
        case .high: return "変動が大"
        case .veryHigh: return "非常に不安定"
        }
    }
    
    var color: String {
        switch self {
        case .veryLow, .low: return "green"
        case .moderate: return "blue"
        case .high: return "orange"
        case .veryHigh: return "red"
        }
    }
    
    static func assess(from coefficientOfVariation: Double) -> VariabilityLevel {
        switch coefficientOfVariation {
        case 0..<5: return .veryLow
        case 5..<15: return .low
        case 15..<25: return .moderate
        case 25..<35: return .high
        default: return .veryHigh
        }
    }
}

// MARK: - Distribution Shape Indicators

struct DistributionShapeIndicators: Codable {
    let skewness: Double
    let kurtosis: Double
    let shapeLikes: DistributionShape
    let normalityScore: Double
    let symmetryLevel: SymmetryLevel
    let tailedness: TailProperties
    
    init(from values: [Double]) {
        // 歪度と尖度の計算
        self.skewness = PercentileCalculator.calculateSkewness(from: values) ?? 0
        self.kurtosis = PercentileCalculator.calculateKurtosis(from: values) ?? 0
        
        // 分布形状の判定
        self.shapeLikes = DistributionShape.determine(skewness: skewness, kurtosis: kurtosis)
        
        // 正規性スコア（0-10のスケール）
        self.normalityScore = Self.calculateNormalityScore(skewness: skewness, kurtosis: kurtosis, sampleSize: values.count)
        
        // 対称性レベル
        self.symmetryLevel = SymmetryLevel.assess(from: skewness)
        
        // 尾部の特性
        self.tailedness = TailProperties.assess(from: kurtosis)
    }
    
    private static func calculateNormalityScore(skewness: Double, kurtosis: Double, sampleSize: Int) -> Double {
        var score: Double = 10.0
        
        // 歪度による減点
        score -= min(abs(skewness) * 2, 4)
        
        // 尖度による減点
        score -= min(abs(kurtosis) * 1.5, 3)
        
        // サンプルサイズによる調整
        if sampleSize < 30 {
            score -= 1
        }
        
        return max(0, score)
    }
}

enum DistributionShape: String, CaseIterable, Codable {
    case normal = "normal"
    case leftSkewed = "left_skewed"
    case rightSkewed = "right_skewed"
    case bimodal = "bimodal"
    case uniform = "uniform"
    case leptokurtic = "leptokurtic"  // 急峻
    case platykurtic = "platykurtic"  // 平坦
    
    var displayName: String {
        switch self {
        case .normal: return "正規分布型"
        case .leftSkewed: return "左偏り"
        case .rightSkewed: return "右偏り"
        case .bimodal: return "二峰性"
        case .uniform: return "一様分布型"
        case .leptokurtic: return "急峻な分布"
        case .platykurtic: return "平坦な分布"
        }
    }
    
    static func determine(skewness: Double, kurtosis: Double) -> DistributionShape {
        let absSkewness = abs(skewness)
        let absKurtosis = abs(kurtosis)
        
        if absSkewness < 0.5 && absKurtosis < 0.5 {
            return .normal
        } else if skewness < -0.5 {
            return .leftSkewed
        } else if skewness > 0.5 {
            return .rightSkewed
        } else if kurtosis > 2.0 {
            return .leptokurtic
        } else if kurtosis < -2.0 {
            return .platykurtic
        } else {
            return .normal
        }
    }
}

enum SymmetryLevel: String, CaseIterable, Codable {
    case symmetric = "symmetric"
    case moderatelySkewed = "moderately_skewed"
    case highlySkewed = "highly_skewed"
    
    var displayName: String {
        switch self {
        case .symmetric: return "対称的"
        case .moderatelySkewed: return "やや偏り"
        case .highlySkewed: return "強く偏り"
        }
    }
    
    static func assess(from skewness: Double) -> SymmetryLevel {
        let absSkewness = abs(skewness)
        
        switch absSkewness {
        case 0..<0.5: return .symmetric
        case 0.5..<1.0: return .moderatelySkewed
        default: return .highlySkewed
        }
    }
}

enum TailProperties: String, CaseIterable, Codable {
    case normalTails = "normal_tails"
    case heavyTails = "heavy_tails"
    case lightTails = "light_tails"
    
    var displayName: String {
        switch self {
        case .normalTails: return "標準的な尾部"
        case .heavyTails: return "厚い尾部"
        case .lightTails: return "薄い尾部"
        }
    }
    
    static func assess(from kurtosis: Double) -> TailProperties {
        switch kurtosis {
        case -0.5..<0.5: return .normalTails
        case 0.5...: return .heavyTails
        default: return .lightTails
        }
    }
}

// MARK: - Percentile Indicators

struct PercentileIndicators: Codable {
    let p5: Double?
    let p10: Double?
    let p25: Double?
    let p50: Double?  // median
    let p75: Double?
    let p90: Double?
    let p95: Double?
    let quartiles: QuartileData
    
    init(from values: [Double]) {
        let percentiles: [Double] = [0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95]
        var results: [Double: Double] = [:]
        
        for percentile in percentiles {
            results[percentile] = PercentileCalculator.calculatePercentile(from: values, percentile: percentile)
        }
        
        self.p5 = results[0.05]
        self.p10 = results[0.10]
        self.p25 = results[0.25]
        self.p50 = results[0.50]
        self.p75 = results[0.75]
        self.p90 = results[0.90]
        self.p95 = results[0.95]
        
        // 四分位数データ
        if let quartileAnalysis = PercentileCalculator.calculateQuartiles(from: values) {
            self.quartiles = QuartileData(
                q1: quartileAnalysis.q1,
                q2: quartileAnalysis.median,
                q3: quartileAnalysis.q3,
                iqr: quartileAnalysis.interquartileRange,
                outlierCount: quartileAnalysis.outliers.count
            )
        } else {
            self.quartiles = QuartileData(q1: 0, q2: 0, q3: 0, iqr: 0, outlierCount: 0)
        }
    }
}

struct QuartileData: Codable {
    let q1: Double
    let q2: Double
    let q3: Double
    let iqr: Double
    let outlierCount: Int
}

// MARK: - Outlier Indicators

struct OutlierIndicators: Codable {
    let totalOutliers: Int
    let outlierPercentage: Double
    let mildOutliers: Int
    let extremeOutliers: Int
    let outlierSeverity: OutlierSeverityLevel
    let detectionMethod: OutlierDetectionMethod
    let lowerBound: Double?
    let upperBound: Double?
    
    init(from values: [Double]) {
        // IQR法による外れ値検出
        if let analysis = PercentileCalculator.detectOutliers(from: values) {
            self.totalOutliers = analysis.outlierCount
            self.outlierPercentage = analysis.outlierPercentage
            self.lowerBound = analysis.lowerBound
            self.upperBound = analysis.upperBound
            
            self.mildOutliers = analysis.outliers.filter { $0.severity == .mild }.count
            self.extremeOutliers = analysis.outliers.filter { $0.severity == .extreme }.count
            
            self.detectionMethod = .iqr
            self.outlierSeverity = OutlierSeverityLevel.assess(from: outlierPercentage)
        } else {
            self.totalOutliers = 0
            self.outlierPercentage = 0
            self.mildOutliers = 0
            self.extremeOutliers = 0
            self.detectionMethod = .iqr
            self.outlierSeverity = .none
            self.lowerBound = nil
            self.upperBound = nil
        }
    }
}

enum OutlierSeverityLevel: String, CaseIterable, Codable {
    case none = "none"
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .none: return "外れ値なし"
        case .low: return "少数の外れ値"
        case .moderate: return "中程度の外れ値"
        case .high: return "多数の外れ値"
        case .critical: return "極めて多数の外れ値"
        }
    }
    
    static func assess(from percentage: Double) -> OutlierSeverityLevel {
        switch percentage {
        case 0: return .none
        case 0..<5: return .low
        case 5..<10: return .moderate
        case 10..<20: return .high
        default: return .critical
        }
    }
}

// OutlierDetectionMethod is defined in TrendAnalyzerProtocol.swift

// MARK: - Data Quality Indicators

struct DataQualityIndicators: Codable {
    let completeness: Double        // データの完全性 (0-1)
    let consistency: Double         // データの一貫性 (0-1)
    let accuracy: Double           // データの正確性推定 (0-1)
    let timeliness: Double         // データの時間的妥当性 (0-1)
    let overallQualityScore: Double // 総合品質スコア (0-100)
    let qualityLevel: DataQualityLevel
    let missingDataPercentage: Double
    
    init(from values: [Double], timestamps: [Date], expectedDataPoints: Int) {
        // 完全性の計算
        self.completeness = min(Double(values.count) / Double(max(expectedDataPoints, 1)), 1.0)
        
        // 欠損データの割合
        self.missingDataPercentage = max(0, (1.0 - completeness) * 100)
        
        // 一貫性の評価（変動係数ベース）
        let mean = values.reduce(0, +) / Double(max(values.count, 1))
        let stdDev = PercentileCalculator.calculateStandardDeviation(from: values, mean: mean)
        let cv = mean != 0 ? (stdDev / abs(mean)) * 100 : 0
        self.consistency = max(0, min(1.0, 1.0 - cv / 100))
        
        // 正確性の推定（外れ値の少なさベース）
        let outlierAnalysis = PercentileCalculator.detectOutliers(from: values)
        let outlierPercentage = outlierAnalysis?.outlierPercentage ?? 0
        self.accuracy = max(0, min(1.0, 1.0 - outlierPercentage / 100))
        
        // 時間的妥当性の評価
        if timestamps.isEmpty {
            self.timeliness = 0.8  // タイムスタンプ不明の場合は中程度
        } else {
            // データの時間分布の均等性を評価
            let timeIntervals = zip(timestamps.dropFirst(), timestamps).map { $0.timeIntervalSince($1) }
            if !timeIntervals.isEmpty {
                let avgInterval = timeIntervals.reduce(0, +) / Double(timeIntervals.count)
                let timelineConsistency = timeIntervals.map { abs($0 - avgInterval) / avgInterval }
                let avgTimeConsistency = timelineConsistency.reduce(0, +) / Double(timelineConsistency.count)
                self.timeliness = max(0, min(1.0, 1.0 - avgTimeConsistency))
            } else {
                self.timeliness = 1.0
            }
        }
        
        // 総合品質スコアの計算
        let weightedScore = (completeness * 0.3 + consistency * 0.25 + accuracy * 0.25 + timeliness * 0.2) * 100
        self.overallQualityScore = weightedScore
        
        // 品質レベルの判定
        self.qualityLevel = DataQualityLevel.assess(from: overallQualityScore)
    }
}

enum DataQualityLevel: String, CaseIterable, Codable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    case unacceptable = "unacceptable"
    
    var displayName: String {
        switch self {
        case .excellent: return "優秀"
        case .good: return "良好"
        case .fair: return "普通"
        case .poor: return "不良"
        case .unacceptable: return "使用不可"
        }
    }
    
    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "orange"
        case .poor: return "red"
        case .unacceptable: return "red"
        }
    }
    
    static func assess(from score: Double) -> DataQualityLevel {
        switch score {
        case 90...100: return .excellent
        case 75..<90: return .good
        case 60..<75: return .fair
        case 40..<60: return .poor
        default: return .unacceptable
        }
    }
}

// MARK: - Trend Strength Indicators

struct TrendStrengthIndicators: Codable {
    let linearTrend: Double         // -1 to 1の線形トレンド強度
    let trendConsistency: Double    // 0-1のトレンド一貫性
    let volatility: Double          // 価格変動性指標
    let momentum: Double            // 直近のモメンタム
    let trendStrength: TrendStrength
    let changeVelocity: Double      // 変化の速度
    
    init(from values: [Double], timestamps: [Date] = []) {
        guard values.count >= 2 else {
            self.linearTrend = 0
            self.trendConsistency = 0
            self.volatility = 0
            self.momentum = 0
            self.trendStrength = .noTrend
            self.changeVelocity = 0
            return
        }
        
        // 線形トレンドの計算（最小二乗法）
        let n = Double(values.count)
        let xValues = Array(0..<values.count).map(Double.init)
        let xMean = xValues.reduce(0, +) / n
        let yMean = values.reduce(0, +) / n
        
        let numerator = zip(xValues, values).map { ($0 - xMean) * ($1 - yMean) }.reduce(0, +)
        let denominator = xValues.map { pow($0 - xMean, 2) }.reduce(0, +)
        
        self.linearTrend = denominator != 0 ? numerator / denominator : 0
        
        // トレンド一貫性（R²のようなもの）
        let currentLinearTrend = self.linearTrend
        let yPredicted = xValues.map { yMean + currentLinearTrend * ($0 - xMean) }
        let ssRes = zip(values, yPredicted).map { pow($0 - $1, 2) }.reduce(0, +)
        let ssTot = values.map { pow($0 - yMean, 2) }.reduce(0, +)
        self.trendConsistency = ssTot != 0 ? max(0, 1 - ssRes / ssTot) : 0
        
        // ボラティリティ（標準偏差を平均で正規化）
        let stdDev = PercentileCalculator.calculateStandardDeviation(from: values)
        self.volatility = yMean != 0 ? stdDev / abs(yMean) : 0
        
        // モメンタム（直近の変化率）
        let recentCount = min(values.count, max(3, values.count / 4))
        let recentValues = Array(values.suffix(recentCount))
        let recentMean = recentValues.reduce(0, +) / Double(recentValues.count)
        self.momentum = yMean != 0 ? (recentMean - yMean) / abs(yMean) : 0
        
        // 変化速度（単位時間あたりの変化）
        if !timestamps.isEmpty && timestamps.count == values.count {
            let timeSpan = timestamps.last!.timeIntervalSince(timestamps.first!)
            let valueChange = values.last! - values.first!
            self.changeVelocity = timeSpan > 0 ? valueChange / timeSpan : 0
        } else {
            self.changeVelocity = values.count > 1 ? (values.last! - values.first!) / Double(values.count - 1) : 0
        }
        
        // トレンド強度の判定
        self.trendStrength = TrendStrength.assess(
            linearTrend: linearTrend,
            consistency: trendConsistency,
            volatility: volatility
        )
    }
}

enum TrendStrength: String, CaseIterable, Codable {
    case strongUpward = "strong_upward"
    case moderateUpward = "moderate_upward"
    case weakUpward = "weak_upward"
    case noTrend = "no_trend"
    case weakDownward = "weak_downward"
    case moderateDownward = "moderate_downward"
    case strongDownward = "strong_downward"
    
    var displayName: String {
        switch self {
        case .strongUpward: return "強い上昇トレンド"
        case .moderateUpward: return "中程度の上昇トレンド"
        case .weakUpward: return "弱い上昇トレンド"
        case .noTrend: return "トレンドなし"
        case .weakDownward: return "弱い下降トレンド"
        case .moderateDownward: return "中程度の下降トレンド"
        case .strongDownward: return "強い下降トレンド"
        }
    }
    
    static func assess(linearTrend: Double, consistency: Double, volatility: Double) -> TrendStrength {
        let absLinearTrend = abs(linearTrend)
        let strength = absLinearTrend * consistency * (1 - min(volatility, 1.0))
        
        if strength < 0.1 {
            return .noTrend
        } else if linearTrend > 0 {
            switch strength {
            case 0.1..<0.3: return .weakUpward
            case 0.3..<0.6: return .moderateUpward
            default: return .strongUpward
            }
        } else {
            switch strength {
            case 0.1..<0.3: return .weakDownward
            case 0.3..<0.6: return .moderateDownward
            default: return .strongDownward
            }
        }
    }
}

// MARK: - Seasonality Indicators

struct SeasonalityIndicators: Codable {
    let hasSeasonalPattern: Bool
    let seasonalStrength: Double    // 0-1の季節性強度
    let dominantPeriod: Int?        // 主要な周期（日数）
    let seasonalComponents: [SeasonalComponent]
    let detrended: [Double]         // 季節調整済みデータ
    
    init(values: [Double], timestamps: [Date]) {
        guard values.count >= 30 && timestamps.count == values.count else {
            self.hasSeasonalPattern = false
            self.seasonalStrength = 0
            self.dominantPeriod = nil
            self.seasonalComponents = []
            self.detrended = values
            return
        }
        
        // 簡易的な季節性検出（将来的にはFFTなど使用可能）
        let calendar = Calendar.current
        var weeklyAverages: [Int: [Double]] = [:]  // 曜日別
        var monthlyAverages: [Int: [Double]] = [:]  // 月別
        
        for (value, timestamp) in zip(values, timestamps) {
            let weekday = calendar.component(.weekday, from: timestamp)
            let month = calendar.component(.month, from: timestamp)
            
            weeklyAverages[weekday, default: []].append(value)
            monthlyAverages[month, default: []].append(value)
        }
        
        // 週次パターンの分析
        let weeklyMeans = weeklyAverages.mapValues { $0.reduce(0, +) / Double($0.count) }
        let overallMean = values.reduce(0, +) / Double(values.count)
        
        let weeklyMeansList = Array(weeklyMeans.values)
        let weeklyVarianceSum = weeklyMeansList.reduce(0) { total, mean in
            total + pow(mean - overallMean, 2)
        }
        let weeklyVariance = weeklyVarianceSum / Double(max(weeklyMeans.count - 1, 1))
        
        // 月次パターンの分析
        let monthlyMeans = monthlyAverages.mapValues { $0.reduce(0, +) / Double($0.count) }
        
        let monthlyMeansList = Array(monthlyMeans.values)
        let monthlyVarianceSum = monthlyMeansList.reduce(0) { total, mean in
            total + pow(mean - overallMean, 2)
        }
        let monthlyVariance = monthlyVarianceSum / Double(max(monthlyMeans.count - 1, 1))
        
        // 季節性の強度を評価
        let totalVariance = PercentileCalculator.calculateStandardDeviation(from: values)
        let weeklySeasonality = totalVariance > 0 ? sqrt(weeklyVariance) / totalVariance : 0
        let monthlySeasonality = totalVariance > 0 ? sqrt(monthlyVariance) / totalVariance : 0
        
        self.seasonalStrength = max(weeklySeasonality, monthlySeasonality)
        self.hasSeasonalPattern = seasonalStrength > 0.1
        
        // 主要な周期の決定
        if monthlySeasonality > weeklySeasonality {
            self.dominantPeriod = 30  // 月次周期
        } else if weeklySeasonality > 0.1 {
            self.dominantPeriod = 7   // 週次周期
        } else {
            self.dominantPeriod = nil
        }
        
        // 季節成分の生成
        var components: [SeasonalComponent] = []
        
        if weeklySeasonality > 0.1 {
            components.append(SeasonalComponent(
                type: .weekly,
                strength: weeklySeasonality,
                period: 7,
                averages: weeklyMeans
            ))
        }
        
        if monthlySeasonality > 0.1 {
            components.append(SeasonalComponent(
                type: .monthly,
                strength: monthlySeasonality,
                period: 30,
                averages: monthlyMeans
            ))
        }
        
        self.seasonalComponents = components
        
        // 簡易的な季節調整（将来的により高度な手法を実装可能）
        self.detrended = values  // 現在は元データのまま
    }
}

struct SeasonalComponent: Codable {
    let type: SeasonalType
    let strength: Double
    let period: Int
    let averages: [Int: Double]
}

enum SeasonalType: String, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
    
    var displayName: String {
        switch self {
        case .daily: return "日次"
        case .weekly: return "週次"
        case .monthly: return "月次"
        case .yearly: return "年次"
        }
    }
}