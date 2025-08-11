import Testing
import Foundation
@testable import HealthRecordingApp

/// PercentileCalculator統計計算精度検証テスト
/// パーセンタイル、四分位数、異常値検出、分布分析の包括的テストスイート
@Suite("PercentileCalculator Tests")
struct PercentileCalculatorTests {
    
    // MARK: - Test Data
    
    /// 基本的な数値配列（小さいデータセット）
    private let basicValues = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
    
    /// より現実的な体重データ（30日分）
    private let weightData = [
        72.5, 72.3, 72.1, 71.9, 72.0, 72.2, 72.4, 71.8, 71.6, 71.9,
        72.1, 72.0, 71.8, 71.7, 71.9, 72.2, 72.5, 72.3, 72.1, 71.8,
        71.6, 71.4, 71.7, 71.9, 72.1, 72.3, 72.0, 71.8, 71.9, 72.2
    ]
    
    /// より現実的な歩数データ（30日分）
    private let stepsData = [
        8420.0, 7850.0, 9200.0, 6800.0, 8900.0, 9500.0, 7200.0, 8800.0, 9100.0, 7600.0,
        8300.0, 9000.0, 8700.0, 7900.0, 8400.0, 9300.0, 8100.0, 7700.0, 8600.0, 9400.0,
        8200.0, 7500.0, 8900.0, 9600.0, 8000.0, 8800.0, 9200.0, 8500.0, 7800.0, 8700.0
    ]
    
    /// 外れ値を含むデータセット
    private let outlierData = [
        10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0,
        20.0, 21.0, 22.0, 100.0, 23.0, 24.0, 25.0, 26.0, 27.0, 2.0  // 100.0と2.0が外れ値
    ]
    
    // MARK: - Percentile Calculation Tests
    
    @Test("パーセンタイル計算の基本機能テスト")
    func testBasicPercentileCalculation() async throws {
        // 50%点（中央値）のテスト
        let median = PercentileCalculator.calculatePercentile(from: basicValues, percentile: 0.5)
        #expect(median != nil)
        #expect(abs(median! - 5.5) < 0.1)  // [1,2,3,4,5,6,7,8,9,10]の中央値は5.5
        
        // 25%点（第1四分位数）のテスト
        let q1 = PercentileCalculator.calculatePercentile(from: basicValues, percentile: 0.25)
        #expect(q1 != nil)
        #expect(abs(q1! - 3.25) < 0.1)
        
        // 75%点（第3四分位数）のテスト
        let q3 = PercentileCalculator.calculatePercentile(from: basicValues, percentile: 0.75)
        #expect(q3 != nil)
        #expect(abs(q3! - 7.75) < 0.1)
        
        // 90%点のテスト
        let p90 = PercentileCalculator.calculatePercentile(from: basicValues, percentile: 0.9)
        #expect(p90 != nil)
        #expect(abs(p90! - 9.1) < 0.1)
    }
    
    @Test("四分位数計算の精度検証")
    func testQuartileCalculation() async throws {
        let quartiles = PercentileCalculator.calculateQuartiles(from: weightData)
        
        #expect(quartiles.count == 3)
        
        let q1 = quartiles[0]
        let q2 = quartiles[1]  // 中央値
        let q3 = quartiles[2]
        
        // 四分位数の順序確認
        #expect(q1 < q2)
        #expect(q2 < q3)
        
        // 体重データの現実的な範囲確認
        #expect(q1 >= 71.0 && q1 <= 73.0)
        #expect(q2 >= 71.5 && q2 <= 72.5)
        #expect(q3 >= 72.0 && q3 <= 73.0)
    }
    
    @Test("パーセンタイル範囲のバリデーション")
    func testPercentileRangeValidation() async throws {
        // 無効な範囲のテスト
        let invalidLow = PercentileCalculator.calculatePercentile(from: basicValues, percentile: -0.1)
        #expect(invalidLow == nil)
        
        let invalidHigh = PercentileCalculator.calculatePercentile(from: basicValues, percentile: 1.1)
        #expect(invalidHigh == nil)
        
        // 境界値のテスト
        let min = PercentileCalculator.calculatePercentile(from: basicValues, percentile: 0.0)
        #expect(min == 1.0)
        
        let max = PercentileCalculator.calculatePercentile(from: basicValues, percentile: 1.0)
        #expect(max == 10.0)
    }
    
    @Test("空配列・単一要素のエッジケース")
    func testEdgeCases() async throws {
        // 空配列のテスト
        let emptyResult = PercentileCalculator.calculatePercentile(from: [], percentile: 0.5)
        #expect(emptyResult == nil)
        
        // 単一要素のテスト
        let singleElement = PercentileCalculator.calculatePercentile(from: [42.0], percentile: 0.5)
        #expect(singleElement == 42.0)
        
        let singleQ1 = PercentileCalculator.calculatePercentile(from: [42.0], percentile: 0.25)
        #expect(singleQ1 == 42.0)
    }
    
    // MARK: - Outlier Detection Tests
    
    @Test("IQR法による外れ値検出")
    func testIQROutlierDetection() async throws {
        let outliers = PercentileCalculator.detectOutliersIQR(from: outlierData)
        
        // 外れ値が検出されることを確認
        #expect(outliers.count >= 2)
        
        // 明らかな外れ値（100.0と2.0）のインデックスが含まれることを確認
        let outlierValues = outliers.map { outlierData[$0] }
        #expect(outlierValues.contains(100.0))
        #expect(outlierValues.contains(2.0))
    }
    
    @Test("Zスコア法による外れ値検出")
    func testZScoreOutlierDetection() async throws {
        let outliers = PercentileCalculator.detectOutliersZScore(from: outlierData, threshold: 2.0)
        
        // 外れ値が検出されることを確認
        #expect(outliers.count >= 1)
        
        // 極端な外れ値（100.0）が検出されることを確認
        let outlierValues = outliers.map { outlierData[$0] }
        #expect(outlierValues.contains(100.0))
    }
    
    @Test("修正Zスコア法による外れ値検出")
    func testModifiedZScoreOutlierDetection() async throws {
        let outliers = PercentileCalculator.detectOutliersModifiedZScore(from: outlierData, threshold: 3.5)
        
        // 修正Zスコア法でも外れ値が検出されることを確認
        #expect(outliers.count >= 1)
        
        let outlierValues = outliers.map { outlierData[$0] }
        #expect(outlierValues.contains(100.0))
    }
    
    @Test("外れ値検出メソッドの比較")
    func testOutlierDetectionMethodComparison() async throws {
        let iqrOutliers = PercentileCalculator.detectOutliersIQR(from: outlierData)
        let zScoreOutliers = PercentileCalculator.detectOutliersZScore(from: outlierData, threshold: 2.0)
        let modifiedZScoreOutliers = PercentileCalculator.detectOutliersModifiedZScore(from: outlierData, threshold: 3.5)
        
        // 全メソッドで少なくとも1つの外れ値が検出されることを確認
        #expect(iqrOutliers.count >= 1)
        #expect(zScoreOutliers.count >= 1)
        #expect(modifiedZScoreOutliers.count >= 1)
        
        // IQR法が最も多くの外れ値を検出する傾向があることを確認
        #expect(iqrOutliers.count >= modifiedZScoreOutliers.count)
    }
    
    // MARK: - Statistical Distribution Tests
    
    @Test("統計分布の基本指標計算")
    func testBasicStatisticalIndicators() async throws {
        let mean = PercentileCalculator.calculateMean(from: basicValues)
        #expect(abs(mean - 5.5) < 0.01)
        
        let stdDev = PercentileCalculator.calculateStandardDeviation(from: basicValues, mean: mean)
        #expect(stdDev > 0)
        #expect(abs(stdDev - 3.02765) < 0.01)  // 標準偏差の理論値
        
        let variance = PercentileCalculator.calculateVariance(from: basicValues, mean: mean)
        #expect(abs(variance - stdDev * stdDev) < 0.01)
    }
    
    @Test("歪度と尖度の計算")
    func testSkewnessAndKurtosis() async throws {
        // 対称データでの歪度テスト（0に近い値を期待）
        let symmetricSkewness = PercentileCalculator.calculateSkewness(from: basicValues)
        #expect(abs(symmetricSkewness) < 0.1)
        
        // 非対称データ（右に偏った分布）での歪度テスト
        let rightSkewedData = [1.0, 2.0, 3.0, 4.0, 5.0, 10.0, 15.0, 20.0]
        let rightSkewness = PercentileCalculator.calculateSkewness(from: rightSkewedData)
        #expect(rightSkewness > 0)  // 正の歪度を期待
        
        // 尖度の計算
        let kurtosis = PercentileCalculator.calculateKurtosis(from: basicValues)
        #expect(kurtosis != nil)  // 計算可能であることを確認
    }
    
    @Test("変動係数の計算")
    func testCoefficientOfVariation() async throws {
        let cv = PercentileCalculator.calculateCoefficientOfVariation(from: basicValues)
        #expect(cv > 0)
        #expect(cv < 1.0)  // 100%未満であることを期待
        
        // より安定したデータでの変動係数テスト
        let stableData = [10.0, 10.1, 9.9, 10.2, 9.8, 10.0, 10.1, 9.9]
        let stableCv = PercentileCalculator.calculateCoefficientOfVariation(from: stableData)
        #expect(stableCv < 0.05)  // 非常に小さい変動係数を期待
    }
    
    // MARK: - Real-world Health Data Tests
    
    @Test("体重データの現実的な統計分析")
    func testWeightDataAnalysis() async throws {
        let weightStats = PercentileCalculator.calculateBasicStatistics(from: weightData)
        
        // 基本統計値の妥当性確認
        #expect(weightStats.mean >= 71.0 && weightStats.mean <= 73.0)
        #expect(weightStats.minimum >= 71.0)
        #expect(weightStats.maximum <= 73.0)
        #expect(weightStats.standardDeviation > 0 && weightStats.standardDeviation < 1.0)
        
        // パーセンタイル分析
        let p10 = PercentileCalculator.calculatePercentile(from: weightData, percentile: 0.1)!
        let p90 = PercentileCalculator.calculatePercentile(from: weightData, percentile: 0.9)!
        
        // 10%点と90%点の範囲が妥当であることを確認
        #expect(p90 - p10 < 2.0)  // 体重の変動範囲は通常2kg未満
    }
    
    @Test("歩数データの現実的な統計分析")
    func testStepsDataAnalysis() async throws {
        let stepsStats = PercentileCalculator.calculateBasicStatistics(from: stepsData)
        
        // 歩数データの妥当性確認
        #expect(stepsStats.mean >= 7000 && stepsStats.mean <= 10000)
        #expect(stepsStats.minimum >= 6000)
        #expect(stepsStats.maximum <= 10000)
        
        // 変動係数が妥当な範囲であることを確認
        let cv = PercentileCalculator.calculateCoefficientOfVariation(from: stepsData)
        #expect(cv >= 0.05 && cv <= 0.3)  // 歩数の日々の変動は5-30%程度
        
        // 外れ値検出（異常に少ない・多い日がないことを確認）
        let outliers = PercentileCalculator.detectOutliersIQR(from: stepsData)
        #expect(outliers.count <= 3)  // 外れ値は少数であることを期待
    }
    
    @Test("データ品質指標の計算")
    func testDataQualityMetrics() async throws {
        // 完全なデータセット
        let completeDataCompleteness = PercentileCalculator.calculateDataCompleteness(
            actualCount: 30,
            expectedCount: 30
        )
        #expect(completeDataCompleteness == 1.0)
        
        // 不完全なデータセット
        let incompleteDataCompleteness = PercentileCalculator.calculateDataCompleteness(
            actualCount: 25,
            expectedCount: 30
        )
        #expect(abs(incompleteDataCompleteness - 0.833) < 0.01)
        
        // データ一貫性の計算
        let consistency = PercentileCalculator.calculateDataConsistency(from: weightData)
        #expect(consistency >= 0.8)  // 体重データは比較的一貫していることを期待
    }
    
    // MARK: - Performance Tests
    
    @Test("大量データでのパフォーマンステスト")
    func testPerformanceWithLargeDataset() async throws {
        // 10,000個のデータポイントを生成
        let largeDataset = (1...10000).map { _ in Double.random(in: 50.0...100.0) }
        
        let startTime = Date()
        
        // パーセンタイル計算のパフォーマンステスト
        let median = PercentileCalculator.calculatePercentile(from: largeDataset, percentile: 0.5)
        let quartiles = PercentileCalculator.calculateQuartiles(from: largeDataset)
        let outliers = PercentileCalculator.detectOutliersIQR(from: largeDataset)
        
        let executionTime = Date().timeIntervalSince(startTime)
        
        // 結果の妥当性確認
        #expect(median != nil)
        #expect(quartiles.count == 3)
        #expect(outliers.count >= 0)
        
        // パフォーマンス確認（1秒以内に完了することを期待）
        #expect(executionTime < 1.0)
        
        print("Large dataset performance: \(executionTime) seconds for \(largeDataset.count) data points")
    }
    
    // MARK: - Error Handling Tests
    
    @Test("異常値やNaN値の処理")
    func testInvalidValueHandling() async throws {
        // NaN値を含むデータ
        let dataWithNaN = [1.0, 2.0, Double.nan, 4.0, 5.0]
        let cleanedData = dataWithNaN.filter { !$0.isNaN && $0.isFinite }
        
        let result = PercentileCalculator.calculatePercentile(from: cleanedData, percentile: 0.5)
        #expect(result != nil)
        #expect(!result!.isNaN)
        
        // 無限大値を含むデータ
        let dataWithInfinity = [1.0, 2.0, Double.infinity, 4.0, 5.0]
        let cleanedInfinityData = dataWithInfinity.filter { !$0.isNaN && $0.isFinite }
        
        let infinityResult = PercentileCalculator.calculatePercentile(from: cleanedInfinityData, percentile: 0.5)
        #expect(infinityResult != nil)
        #expect(infinityResult!.isFinite)
    }
}

// MARK: - Supporting Extensions

extension PercentileCalculator {
    
    /// 基本統計情報を計算する便利メソッド（テスト用）
    static func calculateBasicStatistics(from values: [Double]) -> (
        mean: Double,
        minimum: Double,
        maximum: Double,
        standardDeviation: Double
    ) {
        guard !values.isEmpty else {
            return (mean: 0, minimum: 0, maximum: 0, standardDeviation: 0)
        }
        
        let mean = calculateMean(from: values)
        let minimum = values.min() ?? 0
        let maximum = values.max() ?? 0
        let standardDeviation = calculateStandardDeviation(from: values, mean: mean)
        
        return (mean: mean, minimum: minimum, maximum: maximum, standardDeviation: standardDeviation)
    }
    
    /// データ完全性を計算（テスト用）
    static func calculateDataCompleteness(actualCount: Int, expectedCount: Int) -> Double {
        guard expectedCount > 0 else { return 0.0 }
        return min(Double(actualCount) / Double(expectedCount), 1.0)
    }
    
    /// データ一貫性を計算（テスト用）
    static func calculateDataConsistency(from values: [Double]) -> Double {
        guard values.count > 1 else { return 1.0 }
        
        let mean = calculateMean(from: values)
        let stdDev = calculateStandardDeviation(from: values, mean: mean)
        
        // 変動係数の逆数をベースとした一貫性指標
        let cv = stdDev / mean
        return max(0.0, min(1.0, 1.0 - cv))
    }
}