import SwiftUI
import Charts

/// 包括的統計情報表示コンポーネント
/// パーセンタイル、分布形状、外れ値検出など高度な統計分析結果を表示
struct DetailedStatisticsView: View {
    let dataType: HealthDataType
    let chartDataPoints: [ChartDataPoint]
    let timeRange: TrendTimeRange
    
    @State private var selectedStatCategory: StatisticCategory = .basic
    @State private var showingOutlierDetails = false
    @State private var percentileAnalysis: PercentileAnalysis?
    @State private var outlierAnalysis: OutlierAnalysis?
    @State private var distributionMetrics: DistributionMetrics?
    
    private var values: [Double] {
        chartDataPoints.map(\.value)
    }
    
    private var backgroundColorMain: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #else
        return Color.clear
        #endif
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with category selector
            statisticsHeaderView
            
            // Main content based on selected category
            ScrollView {
                LazyVStack(spacing: 16) {
                    switch selectedStatCategory {
                    case .basic:
                        basicStatisticsSection
                    case .percentiles:
                        percentilesSection
                    case .distribution:
                        distributionSection
                    case .outliers:
                        outliersSection
                    }
                }
                .padding()
            }
        }
        .navigationTitle("詳細統計情報")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .background(backgroundColorMain)
        .onAppear {
            calculateStatistics()
        }
    }
    
    // MARK: - Header Section
    
    private var statisticsHeaderView: some View {
        VStack(spacing: 16) {
            // Data summary
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(dataType.displayName)データ")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("\(timeRange.displayName)間 • \(values.count)件のデータ")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: dataType.iconName)
                    .font(.title2)
                    .foregroundColor(dataType.color)
            }
            
            // Category selector
            categorySelector
        }
        .padding()
        .background(Color(.controlColor).opacity(0.1))
    }
    
    private var categorySelector: some View {
        HStack(spacing: 0) {
            ForEach(StatisticCategory.allCases, id: \.self) { category in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedStatCategory = category
                    }
                }) {
                    Text(category.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            selectedStatCategory == category ?
                            Color.accentColor : Color.clear
                        )
                        .foregroundColor(
                            selectedStatCategory == category ?
                            .white : .primary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(Color.gray.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Statistics Sections
    
    private var basicStatisticsSection: some View {
        VStack(spacing: 16) {
            // Central tendency measures
            StatisticsSectionCard(title: "中心傾向", iconName: "chart.bar") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    StatisticItemCard(
                        title: "平均値",
                        value: formatValue(calculateMean()),
                        subtitle: "算術平均",
                        color: .blue
                    )
                    
                    if let median = percentileAnalysis?.p50 {
                        StatisticItemCard(
                            title: "中央値",
                            value: formatValue(median),
                            subtitle: "50パーセンタイル",
                            color: .green
                        )
                    }
                    
                    if let mode = calculateMode() {
                        StatisticItemCard(
                            title: "最頻値",
                            value: formatValue(mode.value),
                            subtitle: "\(mode.frequency)回出現",
                            color: .orange
                        )
                    }
                    
                    StatisticItemCard(
                        title: "レンジ",
                        value: formatValue(calculateRange()),
                        subtitle: "最大値 - 最小値",
                        color: .purple
                    )
                }
            }
            
            // Variability measures
            StatisticsSectionCard(title: "ばらつきの指標", iconName: "waveform.circle") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    StatisticItemCard(
                        title: "標準偏差",
                        value: formatValue(calculateStandardDeviation()),
                        subtitle: "データの散らばり",
                        color: .red
                    )
                    
                    StatisticItemCard(
                        title: "分散",
                        value: formatValue(calculateVariance()),
                        subtitle: "標準偏差の2乗",
                        color: .pink
                    )
                    
                    if let cv = PercentileCalculator.calculateCoefficientOfVariation(from: values) {
                        StatisticItemCard(
                            title: "変動係数",
                            value: "\(String(format: "%.1f", cv))%",
                            subtitle: "相対的ばらつき",
                            color: .indigo
                        )
                    }
                    
                    if let iqr = percentileAnalysis?.quartiles.interquartileRange {
                        StatisticItemCard(
                            title: "四分位範囲",
                            value: formatValue(iqr),
                            subtitle: "Q3 - Q1",
                            color: .teal
                        )
                    }
                }
            }
        }
    }
    
    private var percentilesSection: some View {
        VStack(spacing: 16) {
            // Quartile box plot visualization
            if let quartiles = percentileAnalysis?.quartiles {
                StatisticsSectionCard(title: "四分位数", iconName: "chart.bar.doc.horizontal") {
                    VStack(spacing: 16) {
                        // Box plot visualization
                        QuartileBoxPlotView(quartiles: quartiles, dataType: dataType)
                        
                        // Quartile values
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                            StatisticItemCard(
                                title: "Q1",
                                value: formatValue(quartiles.q1),
                                subtitle: "25%のデータがこの値以下",
                                color: .cyan
                            )
                            
                            StatisticItemCard(
                                title: "Q2 (中央値)",
                                value: formatValue(quartiles.median),
                                subtitle: "50%のデータがこの値以下",
                                color: .green
                            )
                            
                            StatisticItemCard(
                                title: "Q3",
                                value: formatValue(quartiles.q3),
                                subtitle: "75%のデータがこの値以下",
                                color: .orange
                            )
                        }
                    }
                }
            }
            
            // Percentile breakdown
            if let analysis = percentileAnalysis {
                StatisticsSectionCard(title: "パーセンタイル分布", iconName: "percent") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        if let p5 = analysis.p5 {
                            PercentileItemCard(percentile: 5, value: p5, dataType: dataType)
                        }
                        if let p10 = analysis.p10 {
                            PercentileItemCard(percentile: 10, value: p10, dataType: dataType)
                        }
                        if let p25 = analysis.p25 {
                            PercentileItemCard(percentile: 25, value: p25, dataType: dataType)
                        }
                        if let p50 = analysis.p50 {
                            PercentileItemCard(percentile: 50, value: p50, dataType: dataType)
                        }
                        if let p75 = analysis.p75 {
                            PercentileItemCard(percentile: 75, value: p75, dataType: dataType)
                        }
                        if let p90 = analysis.p90 {
                            PercentileItemCard(percentile: 90, value: p90, dataType: dataType)
                        }
                        if let p95 = analysis.p95 {
                            PercentileItemCard(percentile: 95, value: p95, dataType: dataType)
                        }
                    }
                }
            }
        }
    }
    
    private var distributionSection: some View {
        VStack(spacing: 16) {
            // Distribution shape
            if let metrics = distributionMetrics {
                StatisticsSectionCard(title: "分布の形状", iconName: "waveform") {
                    VStack(spacing: 16) {
                        // Distribution visualization
                        DistributionVisualizationView(values: values, dataType: dataType)
                        
                        // Shape metrics
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            StatisticItemCard(
                                title: "歪度",
                                value: String(format: "%.3f", metrics.skewness),
                                subtitle: skewnessInterpretation(metrics.skewness),
                                color: skewnessColor(metrics.skewness)
                            )
                            
                            StatisticItemCard(
                                title: "尖度",
                                value: String(format: "%.3f", metrics.kurtosis),
                                subtitle: kurtosisInterpretation(metrics.kurtosis),
                                color: kurtosisColor(metrics.kurtosis)
                            )
                        }
                    }
                }
            }
            
            // Normality assessment
            StatisticsSectionCard(title: "正規性の評価", iconName: "bell") {
                VStack(spacing: 12) {
                    let normalityScore = assessNormality()
                    
                    HStack {
                        Image(systemName: normalityScore.iconName)
                            .foregroundColor(normalityScore.color)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("正規性スコア: \(String(format: "%.1f", normalityScore.score))/10")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text(normalityScore.interpretation)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    // Normal distribution comparison
                    NormalityComparisonView(
                        actualValues: values,
                        dataType: dataType
                    )
                }
            }
        }
    }
    
    private var outliersSection: some View {
        VStack(spacing: 16) {
            if let analysis = outlierAnalysis {
                // Outlier summary
                StatisticsSectionCard(title: "外れ値の概要", iconName: "exclamationmark.triangle") {
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("検出された外れ値")
                                    .font(.headline)
                                
                                Text("\(analysis.outlierCount)個 (\(String(format: "%.1f", analysis.outlierPercentage))%)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(outlierSeverityColor(analysis.outlierCount))
                            }
                            
                            Spacer()
                            
                            Button("詳細表示") {
                                showingOutlierDetails = true
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        // Outlier severity breakdown
                        if !analysis.outliers.isEmpty {
                            OutlierSeverityBreakdownView(outliers: analysis.outliers)
                        }
                    }
                }
                
                // Outlier visualization
                StatisticsSectionCard(title: "外れ値の可視化", iconName: "chart.dots.scatter") {
                    OutlierVisualizationView(
                        values: values,
                        outliers: analysis.outliers,
                        dataType: dataType
                    )
                }
            }
        }
    }
    
    // MARK: - Calculation Methods
    
    private func calculateStatistics() {
        guard !values.isEmpty else { return }
        
        // Calculate percentiles
        percentileAnalysis = PercentileCalculator.calculatePercentileAnalysis(from: values)
        
        // Calculate outliers
        outlierAnalysis = PercentileCalculator.detectOutliers(from: values)
        
        // Calculate distribution metrics
        let skewness = PercentileCalculator.calculateSkewness(from: values) ?? 0
        let kurtosis = PercentileCalculator.calculateKurtosis(from: values) ?? 0
        let coefficientOfVariation = PercentileCalculator.calculateCoefficientOfVariation(from: values) ?? 0
        
        distributionMetrics = DistributionMetrics(
            skewness: skewness,
            kurtosis: kurtosis,
            coefficientOfVariation: coefficientOfVariation
        )
    }
    
    private func calculateMean() -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
    
    private func calculateStandardDeviation() -> Double {
        return PercentileCalculator.calculateStandardDeviation(from: values)
    }
    
    private func calculateVariance() -> Double {
        let std = calculateStandardDeviation()
        return std * std
    }
    
    private func calculateRange() -> Double {
        guard let min = values.min(), let max = values.max() else { return 0 }
        return max - min
    }
    
    private func calculateMode() -> (value: Double, frequency: Int)? {
        guard !values.isEmpty else { return nil }
        
        // 値の頻度を計算（小数点の精度を考慮）
        let roundedValues = values.map { round($0 * 100) / 100 }
        let frequencies = Dictionary(roundedValues.map { ($0, 1) }, uniquingKeysWith: +)
        
        // 最も頻度の高い値を見つける
        let maxFrequency = frequencies.values.max() ?? 0
        guard maxFrequency > 1 else { return nil } // 全ての値が1回ずつの場合は最頻値なし
        
        if let mostFrequentValue = frequencies.first(where: { $0.value == maxFrequency })?.key {
            return (mostFrequentValue, maxFrequency)
        }
        
        return nil
    }
    
    // MARK: - Interpretation Helpers
    
    private func skewnessInterpretation(_ skewness: Double) -> String {
        if abs(skewness) < 0.5 {
            return "ほぼ対称"
        } else if skewness > 0.5 {
            return "右に偏り"
        } else {
            return "左に偏り"
        }
    }
    
    private func skewnessColor(_ skewness: Double) -> Color {
        if abs(skewness) < 0.5 {
            return .green
        } else if abs(skewness) < 1.0 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func kurtosisInterpretation(_ kurtosis: Double) -> String {
        if abs(kurtosis) < 0.5 {
            return "正規分布に近い"
        } else if kurtosis > 0.5 {
            return "急峻な分布"
        } else {
            return "平坦な分布"
        }
    }
    
    private func kurtosisColor(_ kurtosis: Double) -> Color {
        if abs(kurtosis) < 0.5 {
            return .green
        } else if abs(kurtosis) < 2.0 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func assessNormality() -> NormalityAssessment {
        guard let metrics = distributionMetrics else {
            return NormalityAssessment(score: 0, interpretation: "データ不足", iconName: "questionmark.circle", color: .gray)
        }
        
        var score: Double = 10.0
        
        // 歪度による評価
        let skewnessDeduction = min(abs(metrics.skewness) * 2, 4)
        score -= skewnessDeduction
        
        // 尖度による評価
        let kurtosisDeduction = min(abs(metrics.kurtosis) * 1.5, 3)
        score -= kurtosisDeduction
        
        // サンプルサイズによる調整
        if values.count < 30 {
            score -= 1
        }
        
        score = max(0, score)
        
        let interpretation: String
        let iconName: String
        let color: Color
        
        switch score {
        case 8...10:
            interpretation = "正規分布に非常に近い"
            iconName = "checkmark.circle.fill"
            color = .green
        case 6..<8:
            interpretation = "正規分布に近い"
            iconName = "checkmark.circle"
            color = .green
        case 4..<6:
            interpretation = "やや正規分布から逸脱"
            iconName = "exclamationmark.circle"
            color = .orange
        case 2..<4:
            interpretation = "正規分布から大きく逸脱"
            iconName = "xmark.circle"
            color = .red
        default:
            interpretation = "正規分布ではない"
            iconName = "xmark.circle.fill"
            color = .red
        }
        
        return NormalityAssessment(score: score, interpretation: interpretation, iconName: iconName, color: color)
    }
    
    private func outlierSeverityColor(_ count: Int) -> Color {
        let percentage = Double(count) / Double(values.count) * 100
        if percentage < 5 {
            return .green
        } else if percentage < 10 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func formatValue(_ value: Double) -> String {
        switch dataType {
        case .weight, .bloodGlucose:
            return String(format: "%.1f", value)
        case .steps, .calories, .heartRate:
            return String(format: "%.0f", value)
        }
    }
}

// MARK: - Supporting Views

struct StatisticsSectionCard<Content: View>: View {
    let title: String
    let iconName: String
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            content()
        }
        .padding()
        .background(Color(.controlColor).opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct StatisticItemCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
                .multilineTextAlignment(.center)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct PercentileItemCard: View {
    let percentile: Int
    let value: Double
    let dataType: HealthDataType
    
    private var formattedValue: String {
        switch dataType {
        case .weight, .bloodGlucose:
            return String(format: "%.1f", value)
        case .steps, .calories, .heartRate:
            return String(format: "%.0f", value)
        }
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Text("P\(percentile)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.accentColor)
            
            Text(formattedValue)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("\(percentile)%のデータがこの値以下")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 70)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color(.controlColor).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Data Models

enum StatisticCategory: CaseIterable {
    case basic, percentiles, distribution, outliers
    
    var displayName: String {
        switch self {
        case .basic: return "基本統計"
        case .percentiles: return "パーセンタイル"
        case .distribution: return "分布"
        case .outliers: return "外れ値"
        }
    }
}

struct DistributionMetrics {
    let skewness: Double
    let kurtosis: Double
    let coefficientOfVariation: Double
}

struct NormalityAssessment {
    let score: Double
    let interpretation: String
    let iconName: String
    let color: Color
}

// MARK: - Placeholder Views

struct QuartileBoxPlotView: View {
    let quartiles: QuartileAnalysis
    let dataType: HealthDataType
    
    var body: some View {
        Text("Box Plot Visualization")
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct DistributionVisualizationView: View {
    let values: [Double]
    let dataType: HealthDataType
    
    var body: some View {
        Text("Distribution Chart")
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct NormalityComparisonView: View {
    let actualValues: [Double]
    let dataType: HealthDataType
    
    var body: some View {
        Text("Q-Q Plot")
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct OutlierSeverityBreakdownView: View {
    let outliers: [OutlierPoint]
    
    var body: some View {
        HStack {
            let mildCount = outliers.filter { $0.severity == .mild }.count
            let extremeCount = outliers.filter { $0.severity == .extreme }.count
            
            VStack {
                Text("\(mildCount)")
                    .font(.headline)
                    .fontWeight(.bold)
                Text("軽度")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            VStack {
                Text("\(extremeCount)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                Text("極端")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct OutlierVisualizationView: View {
    let values: [Double]
    let outliers: [OutlierPoint]
    let dataType: HealthDataType
    
    var body: some View {
        Text("Outlier Scatter Plot")
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}