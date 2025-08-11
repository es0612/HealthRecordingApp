import Foundation
import SwiftUI

/// 四分位数・パーセンタイル計算エンジン
/// 健康データの統計分析に特化した高精度計算システム
final class PercentileCalculator {
    
    // MARK: - Core Percentile Calculations
    
    /// 指定されたパーセンタイルを計算
    /// - Parameters:
    ///   - values: 計算対象の数値配列
    ///   - percentile: パーセンタイル (0.0-1.0)
    /// - Returns: 計算されたパーセンタイル値
    static func calculatePercentile(from values: [Double], percentile: Double) -> Double? {
        guard !values.isEmpty, percentile >= 0.0, percentile <= 1.0 else { return nil }
        
        let sortedValues = values.sorted()
        let count = sortedValues.count
        
        // 単一要素の場合
        if count == 1 {
            return sortedValues[0]
        }
        
        // パーセンタイル位置を計算 (R-7 method: Excel互換)
        let position = percentile * Double(count - 1)
        let lowerIndex = Int(floor(position))
        let upperIndex = Int(ceil(position))
        
        // 境界チェック
        guard lowerIndex >= 0, upperIndex < count else { return nil }
        
        // 線形補間
        if lowerIndex == upperIndex {
            return sortedValues[lowerIndex]
        } else {
            let lowerValue = sortedValues[lowerIndex]
            let upperValue = sortedValues[upperIndex]
            let fraction = position - Double(lowerIndex)
            return lowerValue + fraction * (upperValue - lowerValue)
        }
    }
    
    /// 主要な四分位数を一括計算
    /// - Parameter values: 計算対象の数値配列
    /// - Returns: 四分位数の詳細情報
    static func calculateQuartiles(from values: [Double]) -> QuartileAnalysis? {
        guard !values.isEmpty else { return nil }
        
        let sortedValues = values.sorted()
        
        guard let q1 = calculatePercentile(from: sortedValues, percentile: 0.25),
              let q2 = calculatePercentile(from: sortedValues, percentile: 0.50),
              let q3 = calculatePercentile(from: sortedValues, percentile: 0.75) else {
            return nil
        }
        
        let iqr = q3 - q1
        let outlierLowerBound = q1 - 1.5 * iqr
        let outlierUpperBound = q3 + 1.5 * iqr
        
        let outliers = sortedValues.filter { value in
            value < outlierLowerBound || value > outlierUpperBound
        }
        
        return QuartileAnalysis(
            minimum: sortedValues.first ?? 0,
            q1: q1,
            median: q2,
            q3: q3,
            maximum: sortedValues.last ?? 0,
            interquartileRange: iqr,
            outliers: outliers,
            outlierLowerBound: outlierLowerBound,
            outlierUpperBound: outlierUpperBound
        )
    }
    
    /// 包括的パーセンタイル分析
    /// - Parameter values: 計算対象の数値配列
    /// - Returns: 包括的なパーセンタイル情報
    static func calculatePercentileAnalysis(from values: [Double]) -> PercentileAnalysis? {
        guard !values.isEmpty else { return nil }
        
        let percentiles: [Double] = [0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95]
        var results: [Double: Double] = [:]
        
        for percentile in percentiles {
            if let value = calculatePercentile(from: values, percentile: percentile) {
                results[percentile] = value
            }
        }
        
        guard let quartiles = calculateQuartiles(from: values) else { return nil }
        
        return PercentileAnalysis(
            p5: results[0.05],
            p10: results[0.10],
            p25: results[0.25],
            p50: results[0.50],  // median
            p75: results[0.75],
            p90: results[0.90],
            p95: results[0.95],
            quartiles: quartiles
        )
    }
    
    // MARK: - Advanced Statistical Methods
    
    /// Z-スコア（標準得点）を計算
    /// - Parameters:
    ///   - values: 計算対象の数値配列
    ///   - mean: 平均値（指定がない場合は自動計算）
    ///   - standardDeviation: 標準偏差（指定がない場合は自動計算）
    /// - Returns: 各値のZ-スコア配列
    static func calculateZScores(
        from values: [Double],
        mean: Double? = nil,
        standardDeviation: Double? = nil
    ) -> [Double]? {
        guard !values.isEmpty else { return nil }
        
        let calculatedMean = mean ?? values.reduce(0, +) / Double(values.count)
        let calculatedStd = standardDeviation ?? calculateStandardDeviation(from: values, mean: calculatedMean)
        
        guard calculatedStd > 0 else { return nil }
        
        return values.map { ($0 - calculatedMean) / calculatedStd }
    }
    
    /// 標準偏差を計算
    /// - Parameters:
    ///   - values: 計算対象の数値配列
    ///   - mean: 平均値（指定がない場合は自動計算）
    /// - Returns: 標準偏差
    static func calculateStandardDeviation(from values: [Double], mean: Double? = nil) -> Double {
        guard values.count > 1 else { return 0 }
        
        let calculatedMean = mean ?? values.reduce(0, +) / Double(values.count)
        let squaredDeviations = values.map { pow($0 - calculatedMean, 2) }
        let variance = squaredDeviations.reduce(0, +) / Double(values.count - 1)
        
        return sqrt(variance)
    }
    
    /// 変動係数を計算
    /// - Parameter values: 計算対象の数値配列
    /// - Returns: 変動係数（CV）
    static func calculateCoefficientOfVariation(from values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        
        let mean = values.reduce(0, +) / Double(values.count)
        guard mean != 0 else { return nil }
        
        let standardDeviation = calculateStandardDeviation(from: values, mean: mean)
        return (standardDeviation / abs(mean)) * 100
    }
    
    /// 歪度（Skewness）を計算
    /// - Parameter values: 計算対象の数値配列
    /// - Returns: 歪度
    static func calculateSkewness(from values: [Double]) -> Double? {
        guard values.count >= 3 else { return nil }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let standardDeviation = calculateStandardDeviation(from: values, mean: mean)
        
        guard standardDeviation > 0 else { return nil }
        
        let cubedDeviations = values.map { pow(($0 - mean) / standardDeviation, 3) }
        let skewness = cubedDeviations.reduce(0, +) / Double(values.count)
        
        return skewness
    }
    
    /// 尖度（Kurtosis）を計算
    /// - Parameter values: 計算対象の数値配列
    /// - Returns: 尖度（超過尖度）
    static func calculateKurtosis(from values: [Double]) -> Double? {
        guard values.count >= 4 else { return nil }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let standardDeviation = calculateStandardDeviation(from: values, mean: mean)
        
        guard standardDeviation > 0 else { return nil }
        
        let fourthPowerDeviations = values.map { pow(($0 - mean) / standardDeviation, 4) }
        let kurtosis = fourthPowerDeviations.reduce(0, +) / Double(values.count)
        
        // 超過尖度を返す（正規分布の尖度3を基準として）
        return kurtosis - 3.0
    }
    
    // MARK: - Outlier Detection
    
    /// IQR法による外れ値検出
    /// - Parameters:
    ///   - values: 計算対象の数値配列
    ///   - multiplier: IQRの倍数（通常1.5）
    /// - Returns: 外れ値検出結果
    static func detectOutliers(from values: [Double], multiplier: Double = 1.5) -> OutlierAnalysis? {
        guard let quartiles = calculateQuartiles(from: values) else { return nil }
        
        let lowerBound = quartiles.q1 - multiplier * quartiles.interquartileRange
        let upperBound = quartiles.q3 + multiplier * quartiles.interquartileRange
        
        let mildOutliers = values.compactMap { value -> OutlierPoint? in
            if value < lowerBound || value > upperBound {
                let severity: OutlierSeverity = {
                    let extremeBound = multiplier * 2.0
                    if value < quartiles.q1 - extremeBound * quartiles.interquartileRange ||
                       value > quartiles.q3 + extremeBound * quartiles.interquartileRange {
                        return .extreme
                    } else {
                        return .mild
                    }
                }()
                return OutlierPoint(value: value, severity: severity)
            }
            return nil
        }
        
        return OutlierAnalysis(
            outliers: mildOutliers,
            lowerBound: lowerBound,
            upperBound: upperBound,
            outlierCount: mildOutliers.count,
            outlierPercentage: Double(mildOutliers.count) / Double(values.count) * 100
        )
    }
    
    /// Z-スコアによる外れ値検出
    /// - Parameters:
    ///   - values: 計算対象の数値配列
    ///   - threshold: Z-スコア閾値（通常2.0または3.0）
    /// - Returns: 外れ値検出結果
    static func detectOutliersWithZScore(from values: [Double], threshold: Double = 2.0) -> OutlierAnalysis? {
        guard let zScores = calculateZScores(from: values) else { return nil }
        
        var outliers: [OutlierPoint] = []
        
        for (index, zScore) in zScores.enumerated() {
            let absZScore = abs(zScore)
            if absZScore > threshold {
                let severity: OutlierSeverity = absZScore > 3.0 ? .extreme : .mild
                outliers.append(OutlierPoint(value: values[index], severity: severity))
            }
        }
        
        return OutlierAnalysis(
            outliers: outliers,
            lowerBound: nil,
            upperBound: nil,
            outlierCount: outliers.count,
            outlierPercentage: Double(outliers.count) / Double(values.count) * 100
        )
    }
}

// MARK: - Data Models

/// 四分位数分析結果
struct QuartileAnalysis {
    let minimum: Double
    let q1: Double          // 第1四分位数（25パーセンタイル）
    let median: Double      // 中央値（50パーセンタイル）
    let q3: Double          // 第3四分位数（75パーセンタイル）
    let maximum: Double
    let interquartileRange: Double  // 四分位範囲（IQR）
    let outliers: [Double]
    let outlierLowerBound: Double
    let outlierUpperBound: Double
    
    /// 五数要約統計として表示用の配列を取得
    var fiveNumberSummary: [Double] {
        return [minimum, q1, median, q3, maximum]
    }
}

/// 包括的パーセンタイル分析結果
struct PercentileAnalysis {
    let p5: Double?         // 5パーセンタイル
    let p10: Double?        // 10パーセンタイル
    let p25: Double?        // 25パーセンタイル
    let p50: Double?        // 50パーセンタイル（中央値）
    let p75: Double?        // 75パーセンタイル
    let p90: Double?        // 90パーセンタイル
    let p95: Double?        // 95パーセンタイル
    let quartiles: QuartileAnalysis
}

/// 外れ値分析結果
struct OutlierAnalysis {
    let outliers: [OutlierPoint]
    let lowerBound: Double?
    let upperBound: Double?
    let outlierCount: Int
    let outlierPercentage: Double
}

/// 外れ値ポイント
struct OutlierPoint {
    let value: Double
    let severity: OutlierSeverity
}

/// 外れ値の重要度
enum OutlierSeverity: CaseIterable {
    case mild    // 軽度の外れ値
    case extreme // 極端な外れ値
    
    var displayName: String {
        switch self {
        case .mild: return "軽度"
        case .extreme: return "極端"
        }
    }
    
    var color: Color {
        switch self {
        case .mild: return .orange
        case .extreme: return .red
        }
    }
}