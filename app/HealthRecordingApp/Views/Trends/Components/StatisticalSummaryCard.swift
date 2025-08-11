import SwiftUI

/// データタイプ別統計サマリー表示カード
/// 各健康指標に特化した統計情報の要約表示コンポーネント
struct StatisticalSummaryCard: View {
    let dataType: HealthDataType
    let statistics: StatisticalSummary
    let timeRange: TrendTimeRange
    let onTapDetails: () -> Void
    
    @State private var animateValues = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Main metrics
            mainMetricsView
            
            // Trend indicators
            trendIndicatorsView
            
            // Action button
            detailsButtonView
        }
        .background(backgroundGradient)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: dataType.color.opacity(0.2), radius: 8, x: 0, y: 4)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).delay(0.2)) {
                animateValues = true
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(dataType.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("\(timeRange.displayName)間の統計")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            Image(systemName: dataType.iconName)
                .font(.title2)
                .foregroundColor(.white)
                .background(
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 40, height: 40)
                )
        }
        .padding()
    }
    
    // MARK: - Main Metrics
    
    private var mainMetricsView: some View {
        VStack(spacing: 16) {
            // Primary metrics
            HStack(spacing: 16) {
                MetricView(
                    title: "平均",
                    value: formatValue(statistics.mean),
                    subtitle: "全期間平均",
                    animate: animateValues
                )
                
                MetricView(
                    title: "中央値",
                    value: formatValue(statistics.median),
                    subtitle: "50%点",
                    animate: animateValues
                )
                
                MetricView(
                    title: "最新値",
                    value: formatValue(statistics.latestValue),
                    subtitle: getLatestValueStatus(),
                    animate: animateValues
                )
            }
            
            // Range and variability
            HStack(spacing: 16) {
                MetricView(
                    title: "範囲",
                    value: "\(formatValue(statistics.minimum)) - \(formatValue(statistics.maximum))",
                    subtitle: "最小 - 最大",
                    animate: animateValues
                )
                
                MetricView(
                    title: "標準偏差",
                    value: formatValue(statistics.standardDeviation),
                    subtitle: variabilityAssessment(),
                    animate: animateValues
                )
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
    
    // MARK: - Trend Indicators
    
    private var trendIndicatorsView: some View {
        VStack(spacing: 12) {
            Divider()
                .background(.white.opacity(0.3))
            
            HStack {
                // Trend direction
                HStack(spacing: 8) {
                    Image(systemName: trendIconName())
                        .foregroundColor(trendColor())
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("トレンド")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text(trendDescription())
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                
                // Data quality indicator
                HStack(spacing: 8) {
                    Image(systemName: dataQualityIconName())
                        .foregroundColor(dataQualityColor())
                        .font(.title3)
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("データ品質")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text(dataQualityDescription())
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Details Button
    
    private var detailsButtonView: some View {
        Button(action: onTapDetails) {
            HStack {
                Text("詳細統計を表示")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Image(systemName: "arrow.right.circle")
                    .font(.title3)
            }
            .foregroundColor(.white)
            .padding()
            .background(.white.opacity(0.15))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some ShapeStyle {
        LinearGradient(
            colors: [
                dataType.color,
                dataType.color.opacity(0.8)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Helper Methods
    
    private func formatValue(_ value: Double) -> String {
        switch dataType {
        case .weight, .bloodGlucose:
            return String(format: "%.1f", value)
        case .steps, .calories, .heartRate:
            return String(format: "%.0f", value)
        }
    }
    
    private func getLatestValueStatus() -> String {
        let diff = statistics.latestValue - statistics.mean
        let percentDiff = abs(diff) / statistics.mean * 100
        
        if percentDiff < 5 {
            return "平均的"
        } else if diff > 0 {
            return "平均より\(String(format: "%.0f", percentDiff))%高"
        } else {
            return "平均より\(String(format: "%.0f", percentDiff))%低"
        }
    }
    
    private func variabilityAssessment() -> String {
        let cv = statistics.standardDeviation / statistics.mean * 100
        
        switch cv {
        case 0..<10:
            return "安定"
        case 10..<20:
            return "やや変動"
        case 20..<30:
            return "変動大"
        default:
            return "非常に不安定"
        }
    }
    
    private func trendIconName() -> String {
        switch statistics.trendDirection {
        case .increasing:
            return "arrow.up.right"
        case .decreasing:
            return "arrow.down.right"
        case .stable:
            return "arrow.right"
        case .volatile:
            return "arrow.up.and.down"
        }
    }
    
    private func trendColor() -> Color {
        switch dataType {
        case .weight:
            // 体重は減少がポジティブ
            switch statistics.trendDirection {
            case .decreasing: return .green
            case .increasing: return .red
            case .stable: return .blue
            case .volatile: return .orange
            }
        case .steps, .calories:
            // 歩数・カロリーは増加がポジティブ
            switch statistics.trendDirection {
            case .increasing: return .green
            case .decreasing: return .red
            case .stable: return .blue
            case .volatile: return .orange
            }
        case .heartRate, .bloodGlucose:
            // 心拍数・血糖値は安定がポジティブ
            switch statistics.trendDirection {
            case .stable: return .green
            case .volatile: return .red
            case .increasing, .decreasing: return .orange
            }
        }
    }
    
    private func trendDescription() -> String {
        let changePercent = statistics.changePercentage
        let absChange = abs(changePercent)
        
        switch statistics.trendDirection {
        case .increasing:
            return "上昇 +\(String(format: "%.1f", changePercent))%"
        case .decreasing:
            return "下降 \(String(format: "%.1f", changePercent))%"
        case .stable:
            return "安定 ±\(String(format: "%.1f", absChange))%"
        case .volatile:
            return "変動 ±\(String(format: "%.1f", absChange))%"
        }
    }
    
    private func dataQualityIconName() -> String {
        let completeness = statistics.dataCompleteness
        
        switch completeness {
        case 0.9...1.0: return "checkmark.seal"
        case 0.7..<0.9: return "checkmark.circle"
        case 0.5..<0.7: return "exclamationmark.circle"
        default: return "xmark.circle"
        }
    }
    
    private func dataQualityColor() -> Color {
        let completeness = statistics.dataCompleteness
        
        switch completeness {
        case 0.9...1.0: return .green
        case 0.7..<0.9: return .green
        case 0.5..<0.7: return .orange
        default: return .red
        }
    }
    
    private func dataQualityDescription() -> String {
        let completeness = statistics.dataCompleteness * 100
        
        switch completeness {
        case 90...100: return "優秀 \(String(format: "%.0f", completeness))%"
        case 70..<90: return "良好 \(String(format: "%.0f", completeness))%"
        case 50..<70: return "不足 \(String(format: "%.0f", completeness))%"
        default: return "要改善 \(String(format: "%.0f", completeness))%"
        }
    }
}

// MARK: - Supporting Views

struct MetricView: View {
    let title: String
    let value: String
    let subtitle: String
    let animate: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .scaleEffect(animate ? 1.0 : 0.8)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animate)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Data Models

/// 統計サマリー情報
struct StatisticalSummary {
    let dataType: HealthDataType
    let sampleCount: Int
    let mean: Double
    let median: Double
    let minimum: Double
    let maximum: Double
    let standardDeviation: Double
    let latestValue: Double
    let trendDirection: TrendDirection
    let changePercentage: Double
    let dataCompleteness: Double  // 0.0-1.0の範囲でデータの完全性を示す
    
    /// 統計サマリーを生成
    /// - Parameters:
    ///   - dataType: 健康データタイプ
    ///   - values: 測定値配列
    ///   - expectedDataPoints: 期待されるデータポイント数（完全性計算用）
    /// - Returns: 統計サマリー
    static func create(
        for dataType: HealthDataType,
        from values: [Double],
        expectedDataPoints: Int
    ) -> StatisticalSummary? {
        guard !values.isEmpty else { return nil }
        
        let count = values.count
        let mean = values.reduce(0, +) / Double(count)
        let standardDeviation = PercentileCalculator.calculateStandardDeviation(from: values, mean: mean)
        
        guard let median = PercentileCalculator.calculatePercentile(from: values, percentile: 0.5),
              let minimum = values.min(),
              let maximum = values.max() else {
            return nil
        }
        
        let latestValue = values.last ?? mean
        
        // トレンド方向の計算
        let trendDirection: TrendDirection
        if count >= 5 {
            let firstHalf = Array(values.prefix(count / 2))
            let secondHalf = Array(values.suffix(count / 2))
            let firstMean = firstHalf.reduce(0, +) / Double(firstHalf.count)
            let secondMean = secondHalf.reduce(0, +) / Double(secondHalf.count)
            
            let changePercent = ((secondMean - firstMean) / firstMean) * 100
            
            if abs(changePercent) < 5 {
                trendDirection = .stable
            } else if changePercent > 5 {
                trendDirection = .increasing
            } else {
                trendDirection = .decreasing
            }
        } else {
            trendDirection = .stable
        }
        
        // 変化率の計算
        let changePercentage: Double
        if count >= 2 {
            let firstValue = values.first ?? mean
            changePercentage = ((latestValue - firstValue) / firstValue) * 100
        } else {
            changePercentage = 0
        }
        
        // データ完全性の計算
        let dataCompleteness = min(Double(count) / Double(max(expectedDataPoints, 1)), 1.0)
        
        return StatisticalSummary(
            dataType: dataType,
            sampleCount: count,
            mean: mean,
            median: median,
            minimum: minimum,
            maximum: maximum,
            standardDeviation: standardDeviation,
            latestValue: latestValue,
            trendDirection: trendDirection,
            changePercentage: changePercentage,
            dataCompleteness: dataCompleteness
        )
    }
}

// MARK: - Preview

#if DEBUG
struct StatisticalSummaryCard_Previews: PreviewProvider {
    static var previews: some View {
        let mockStatistics = StatisticalSummary(
            dataType: .weight,
            sampleCount: 30,
            mean: 72.5,
            median: 72.1,
            minimum: 70.2,
            maximum: 75.8,
            standardDeviation: 1.2,
            latestValue: 71.8,
            trendDirection: .decreasing,
            changePercentage: -2.3,
            dataCompleteness: 0.85
        )
        
        VStack(spacing: 20) {
            StatisticalSummaryCard(
                dataType: .weight,
                statistics: mockStatistics,
                timeRange: .month,
                onTapDetails: {}
            )
            
            StatisticalSummaryCard(
                dataType: .steps,
                statistics: StatisticalSummary(
                    dataType: .steps,
                    sampleCount: 28,
                    mean: 8420,
                    median: 8650,
                    minimum: 3200,
                    maximum: 15600,
                    standardDeviation: 2850,
                    latestValue: 9200,
                    trendDirection: .increasing,
                    changePercentage: 12.5,
                    dataCompleteness: 0.93
                ),
                timeRange: .month,
                onTapDetails: {}
            )
        }
        .padding()
        .background({
            #if os(iOS)
            return Color(.systemGroupedBackground)
            #else
            return Color(.controlColor).opacity(0.05)
            #endif
        }())
        .previewLayout(.sizeThatFits)
    }
}
#endif