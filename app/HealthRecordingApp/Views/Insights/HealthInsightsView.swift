import SwiftUI
import Charts

struct HealthInsightsView: View {
    @State private var viewModel = HealthInsightsViewModel()
    @State private var selectedTimeframe: InsightTimeframe = .month
    @State private var selectedFocusAreas: Set<HealthFocusArea> = [.physical, .mental, .behavioral]
    @State private var showingMonthlyReport = false
    @State private var showingAnomalyDetails = false
    @State private var showingCorrelationDetails = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Header with data quality indicator
                    insightHeaderSection
                    
                    // Quick insights overview
                    quickInsightsSection
                    
                    // Priority recommendations
                    priorityRecommendationsSection
                    
                    // Latest anomalies
                    if !viewModel.latestAnomalies.isEmpty {
                        latestAnomaliesSection
                    }
                    
                    // Key correlations
                    if !viewModel.keyCorrelations.isEmpty {
                        keyCorrelationsSection
                    }
                    
                    // Monthly report access
                    monthlyReportSection
                    
                    // Advanced analytics sections
                    advancedAnalyticsSection
                }
                .padding(.horizontal)
            }
            .navigationTitle("健康インサイト")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("期間", selection: $selectedTimeframe) {
                            ForEach(InsightTimeframe.allCases, id: \.self) { timeframe in
                                Text(timeframe.displayName).tag(timeframe)
                            }
                        }
                        
                        Section("フォーカスエリア") {
                            ForEach(HealthFocusArea.allCases, id: \.self) { area in
                                Button(action: {
                                    if selectedFocusAreas.contains(area) {
                                        selectedFocusAreas.remove(area)
                                    } else {
                                        selectedFocusAreas.insert(area)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: selectedFocusAreas.contains(area) ? "checkmark" : "")
                                        Text(area.displayName)
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .refreshable {
                await viewModel.refreshInsights(
                    timeframe: selectedTimeframe,
                    focusAreas: selectedFocusAreas
                )
            }
            .sheet(isPresented: $showingMonthlyReport) {
                MonthlyReportView(
                    reportDate: viewModel.currentMonth,
                    report: viewModel.monthlyReport
                )
            }
            .sheet(isPresented: $showingAnomalyDetails) {
                AnomalyDetectionResultView(
                    anomalyResult: viewModel.enhancedAnomalyResult
                )
            }
            .sheet(isPresented: $showingCorrelationDetails) {
                CorrelationAnalysisView(
                    correlationResults: viewModel.advancedCorrelationResults
                )
            }
        }
        .task {
            await viewModel.loadInsights(
                timeframe: selectedTimeframe,
                focusAreas: selectedFocusAreas
            )
        }
        .onChange(of: selectedTimeframe) { _, newValue in
            Task {
                await viewModel.refreshInsights(
                    timeframe: newValue,
                    focusAreas: selectedFocusAreas
                )
            }
        }
        .onChange(of: selectedFocusAreas) { _, newValue in
            Task {
                await viewModel.refreshInsights(
                    timeframe: selectedTimeframe,
                    focusAreas: newValue
                )
            }
        }
    }
    
    // MARK: - Header Section
    
    private var insightHeaderSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("データ品質スコア")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Text("\(Int(viewModel.dataQualityScore * 100))%")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(qualityScoreColor(viewModel.dataQualityScore))
                        
                        Image(systemName: qualityScoreIcon(viewModel.dataQualityScore))
                            .foregroundColor(qualityScoreColor(viewModel.dataQualityScore))
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("最終更新")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.lastUpdated, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if viewModel.dataQualityScore < 0.7 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    Text("データ品質向上のため、より多くの健康データを記録することをお勧めします")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Quick Insights Section
    
    private var quickInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今月のインサイト")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(viewModel.quickInsights.prefix(4), id: \.id) { insight in
                    InsightQuickCard(insight: insight)
                }
            }
        }
    }
    
    // MARK: - Priority Recommendations Section
    
    private var priorityRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("優先推奨事項")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !viewModel.priorityRecommendations.isEmpty {
                    InfoBadge(text: "\(viewModel.priorityRecommendations.count)", color: .blue)
                }
            }
            
            ForEach(viewModel.priorityRecommendations.prefix(3), id: \.id) { recommendation in
                PriorityRecommendationCard(recommendation: recommendation)
            }
            
            if viewModel.priorityRecommendations.count > 3 {
                Button("すべての推奨事項を見る (\(viewModel.priorityRecommendations.count - 3)件)") {
                    // Navigate to full recommendations view
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
    }
    
    // MARK: - Latest Anomalies Section
    
    private var latestAnomaliesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("異常検出")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("詳細") {
                    showingAnomalyDetails = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            ForEach(viewModel.latestAnomalies.prefix(2), id: \.id) { anomaly in
                AnomalyCard(anomaly: anomaly)
            }
        }
    }
    
    // MARK: - Key Correlations Section
    
    private var keyCorrelationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("重要な相関関係")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("詳細") {
                    showingCorrelationDetails = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            ForEach(viewModel.keyCorrelations.prefix(2), id: \.id) { correlation in
                CorrelationCard(correlation: correlation)
            }
        }
    }
    
    // MARK: - Monthly Report Section
    
    private var monthlyReportSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("月次健康レポート")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("包括的な分析とパーソナライズされた推奨事項")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    showingMonthlyReport = true
                }) {
                    HStack(spacing: 4) {
                        Text("レポートを見る")
                        Image(systemName: "arrow.right")
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            }
            
            if let reportPreview = viewModel.monthlyReportPreview {
                MonthlyReportPreviewCard(preview: reportPreview)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Advanced Analytics Section
    
    private var advancedAnalyticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("高度な分析")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                AdvancedAnalyticsCard(
                    title: "トレンド予測",
                    subtitle: "将来の健康パターン",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green
                ) {
                    // Navigate to trend prediction view
                }
                
                AdvancedAnalyticsCard(
                    title: "リスク評価",
                    subtitle: "健康リスク分析",
                    icon: "shield.lefthalf.filled",
                    color: .orange
                ) {
                    // Navigate to risk assessment view
                }
                
                AdvancedAnalyticsCard(
                    title: "目標最適化",
                    subtitle: "AI駆動目標提案",
                    icon: "target",
                    color: .purple
                ) {
                    // Navigate to AI goal suggestions
                }
                
                AdvancedAnalyticsCard(
                    title: "比較分析",
                    subtitle: "集団比較インサイト",
                    icon: "person.3.fill",
                    color: .blue
                ) {
                    // Navigate to population comparison
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func qualityScoreColor(_ score: Double) -> Color {
        switch score {
        case 0.8...:
            return .green
        case 0.6..<0.8:
            return .orange
        default:
            return .red
        }
    }
    
    private func qualityScoreIcon(_ score: Double) -> String {
        switch score {
        case 0.8...:
            return "checkmark.circle.fill"
        case 0.6..<0.8:
            return "exclamationmark.triangle.fill"
        default:
            return "xmark.circle.fill"
        }
    }
}

// MARK: - Supporting Views

struct InsightQuickCard: View {
    let insight: HealthInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: insight.category.iconName)
                    .foregroundColor(insight.priority.color)
                
                Spacer()
                
                InfoBadge(text: insight.priority.displayName, color: insight.priority.color)
            }
            
            Text(insight.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
            
            Text(insight.summary)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct PriorityRecommendationCard: View {
    let recommendation: PersonalizedRecommendation
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: recommendation.actionItem.iconName)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(recommendation.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Text("難易度: \(recommendation.implementationComplexity.displayName)")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Text("効果: \(recommendation.expectedImpact.displayName)")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            Button(action: {
                // Handle recommendation action
            }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct AnomalyCard: View {
    let anomaly: AnomalousPattern
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: anomaly.severity.iconName)
                .foregroundColor(anomaly.severity.color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(anomaly.dataType.displayName)の異常")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("期待値: \(anomaly.expectedValue, specifier: "%.1f"), 観測値: \(anomaly.observedValue, specifier: "%.1f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("信頼度: \(Int(anomaly.confidence * 100))%")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CorrelationCard: View {
    let correlation: AdvancedCorrelationResult
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "link")
                .foregroundColor(.purple)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(correlation.primaryDataType.displayName) ↔ \(correlation.secondaryDataType.displayName)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let pearsonCorr = correlation.correlationResults[.pearson] {
                    Text("相関係数: \(pearsonCorr, specifier: "%.3f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("サンプル数: \(correlation.sampleSize)")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct MonthlyReportPreviewCard: View {
    let preview: MonthlyReportPreview
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("主要指標")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                ForEach(preview.keyMetrics.prefix(3), id: \.type) { metric in
                    VStack(spacing: 4) {
                        Text(metric.type.displayName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(metric.displayValue)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        HStack(spacing: 2) {
                            Image(systemName: metric.trend.iconName)
                                .font(.caption2)
                            
                            Text(metric.changeText)
                                .font(.caption2)
                        }
                        .foregroundColor(metric.trend.color)
                    }
                    
                    if metric != preview.keyMetrics.last {
                        Divider()
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct AdvancedAnalyticsCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct InfoBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

#Preview {
    HealthInsightsView()
}