import SwiftUI
import Charts

struct MonthlyReportView: View {
    let reportDate: Date
    let report: ComprehensiveMonthlyReport?
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection: ReportSection = .summary
    @State private var showingShareSheet = false
    @State private var reportPDFData: Data?
    
    enum ReportSection: String, CaseIterable {
        case summary = "summary"
        case keyMetrics = "key_metrics"
        case correlations = "correlations"
        case anomalies = "anomalies"
        case trends = "trends"
        case goals = "goals"
        case risks = "risks"
        case recommendations = "recommendations"
        
        var displayName: String {
            switch self {
            case .summary: return "概要"
            case .keyMetrics: return "主要指標"
            case .correlations: return "相関分析"
            case .anomalies: return "異常検出"
            case .trends: return "トレンド分析"
            case .goals: return "目標分析"
            case .risks: return "リスク評価"
            case .recommendations: return "推奨事項"
            }
        }
        
        var iconName: String {
            switch self {
            case .summary: return "doc.text"
            case .keyMetrics: return "chart.bar"
            case .correlations: return "link"
            case .anomalies: return "exclamationmark.triangle"
            case .trends: return "chart.line.uptrend.xyaxis"
            case .goals: return "target"
            case .risks: return "shield.lefthalf.filled"
            case .recommendations: return "lightbulb"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with report info
                reportHeaderSection
                
                // Section picker
                sectionPickerView
                
                // Content based on selected section
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if let report = report {
                            selectedSectionContent(for: report)
                        } else {
                            EmptyReportView()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100) // Extra padding for floating buttons
                }
            }
            .navigationTitle("月次レポート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("PDFで共有", systemImage: "square.and.arrow.up") {
                            generateAndSharePDF()
                        }
                        
                        Button("データをエクスポート", systemImage: "square.and.arrow.down") {
                            exportReportData()
                        }
                        
                        Divider()
                        
                        Button("印刷", systemImage: "printer") {
                            printReport()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let pdfData = reportPDFData {
                    ShareSheet(items: [pdfData])
                }
            }
        }
    }
    
    // MARK: - Report Header
    
    private var reportHeaderSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reportDate, style: .date)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if let report = report {
                        Text("分析レベル: \(report.analyticsLevel.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if let report = report {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("生成完了")
                                .font(.caption)
                        }
                        
                        Text("データ品質: \(Int(report.dataQualityAssessment.overallScore * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if let report = report {
                ReportMetricsBar(report: report)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Section Picker
    
    private var sectionPickerView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ReportSection.allCases, id: \.self) { section in
                    SectionTab(
                        section: section,
                        isSelected: selectedSection == section
                    ) {
                        selectedSection = section
                    }
                }
            }
            .padding(.horizontal)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Section Content
    
    @ViewBuilder
    private func selectedSectionContent(for report: ComprehensiveMonthlyReport) -> some View {
        switch selectedSection {
        case .summary:
            ReportSummarySection(report: report)
            
        case .keyMetrics:
            KeyMetricsSection(insights: report.keyMetrics)
            
        case .correlations:
            if let correlationAnalysis = report.correlationAnalysis {
                CorrelationSection(analysis: correlationAnalysis)
            } else {
                EmptySectionView(title: "相関分析", message: "十分なデータがありません")
            }
            
        case .anomalies:
            AnomalySection(analysis: report.anomalyAnalysis)
            
        case .trends:
            TrendSection(analysis: report.trendAnalysis)
            
        case .goals:
            GoalSection(analysis: report.goalAnalysis)
            
        case .risks:
            RiskSection(assessment: report.riskAssessment)
            
        case .recommendations:
            RecommendationSection(recommendations: report.personalizedRecommendations)
        }
    }
    
    // MARK: - Action Methods
    
    private func generateAndSharePDF() {
        guard let report = report else { return }
        
        Task {
            do {
                let pdfData = try await ReportPDFGenerator.generatePDF(for: report)
                await MainActor.run {
                    reportPDFData = pdfData
                    showingShareSheet = true
                }
            } catch {
                // Handle error
                print("PDF generation failed: \(error)")
            }
        }
    }
    
    private func exportReportData() {
        // Export raw data as JSON or CSV
    }
    
    private func printReport() {
        // Trigger print dialog
    }
}

// MARK: - Supporting Views

struct ReportMetricsBar: View {
    let report: ComprehensiveMonthlyReport
    
    var body: some View {
        HStack(spacing: 16) {
            MetricBadge(
                title: "インサイト",
                count: report.keyMetrics.count,
                color: .blue
            )
            
            MetricBadge(
                title: "異常",
                count: report.anomalyAnalysis.detectedAnomalies.count,
                color: .orange
            )
            
            MetricBadge(
                title: "推奨事項",
                count: report.personalizedRecommendations.count,
                color: .green
            )
            
            Spacer()
        }
    }
}

struct MetricBadge: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct SectionTab: View {
    let section: MonthlyReportView.ReportSection
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: section.iconName)
                    .font(.caption)
                
                Text(section.displayName)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : Color(.systemGray5))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ReportSummarySection: View {
    let report: ComprehensiveMonthlyReport
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "エグゼクティブサマリー", icon: "doc.text")
            
            InsightCard(insight: report.executiveSummary)
            
            if report.personalizedRecommendations.count > 0 {
                SectionHeader(title: "今月のハイライト", icon: "star.fill")
                
                let topRecommendations = Array(report.personalizedRecommendations.prefix(3))
                ForEach(topRecommendations, id: \.id) { recommendation in
                    RecommendationHighlightCard(recommendation: recommendation)
                }
            }
            
            DataQualityCard(assessment: report.dataQualityAssessment)
        }
    }
}

struct KeyMetricsSection: View {
    let insights: [HealthInsight]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "主要健康指標", icon: "chart.bar")
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(insights, id: \.id) { insight in
                    KeyMetricCard(insight: insight)
                }
            }
        }
    }
}

struct CorrelationSection: View {
    let analysis: AdvancedCorrelationAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "相関分析", icon: "link")
            
            ForEach(analysis.correlationResults, id: \.id) { result in
                CorrelationResultCard(result: result)
            }
            
            if !analysis.causalityDiscoveries.isEmpty {
                SectionHeader(title: "因果関係の発見", icon: "arrow.triangle.branch")
                
                ForEach(analysis.causalityDiscoveries, id: \.id) { discovery in
                    CausalityDiscoveryCard(discovery: discovery)
                }
            }
        }
    }
}

struct AnomalySection: View {
    let analysis: EnhancedAnomalyAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "異常検出", icon: "exclamationmark.triangle")
            
            if analysis.detectedAnomalies.isEmpty {
                EmptySectionView(title: "異常検出", message: "今月は異常なパターンは検出されませんでした")
            } else {
                ForEach(analysis.detectedAnomalies, id: \.id) { anomaly in
                    AnomalyDetailCard(anomaly: anomaly)
                }
                
                RiskAssessmentCard(assessment: analysis.riskAssessment)
            }
        }
    }
}

struct TrendSection: View {
    let analysis: AdvancedTrendAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "トレンド分析", icon: "chart.line.uptrend.xyaxis")
            
            TrendOverviewCard(trendDirections: analysis.trendDirections)
            
            if !analysis.predictions.isEmpty {
                SectionHeader(title: "予測", icon: "crystal.ball")
                
                ForEach(analysis.predictions, id: \.id) { prediction in
                    PredictionCard(prediction: prediction)
                }
            }
            
            if !analysis.seasonalPatterns.isEmpty {
                SectionHeader(title: "季節パターン", icon: "calendar")
                
                ForEach(analysis.seasonalPatterns, id: \.id) { pattern in
                    SeasonalPatternCard(pattern: pattern)
                }
            }
        }
    }
}

struct GoalSection: View {
    let analysis: IntelligentGoalAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "目標分析", icon: "target")
            
            ForEach(analysis.goalProgress, id: \.id) { progress in
                GoalProgressCard(progress: progress)
            }
            
            if !analysis.adaptiveRecommendations.isEmpty {
                SectionHeader(title: "適応的推奨", icon: "lightbulb")
                
                ForEach(analysis.adaptiveRecommendations, id: \.id) { recommendation in
                    AdaptiveGoalCard(recommendation: recommendation)
                }
            }
            
            MotivationAnalysisCard(analysis: analysis.motivationAnalysis)
        }
    }
}

struct RiskSection: View {
    let assessment: ComprehensiveHealthRiskAssessment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "健康リスク評価", icon: "shield.lefthalf.filled")
            
            OverallRiskCard(assessment: assessment)
            
            if !assessment.identifiedRisks.isEmpty {
                SectionHeader(title: "特定されたリスク", icon: "exclamationmark.shield")
                
                ForEach(assessment.identifiedRisks, id: \.id) { risk in
                    IdentifiedRiskCard(risk: risk)
                }
            }
            
            if !assessment.protectiveFactors.isEmpty {
                SectionHeader(title: "保護要因", icon: "shield.checkered")
                
                ForEach(assessment.protectiveFactors, id: \.id) { factor in
                    ProtectiveFactorCard(factor: factor)
                }
            }
        }
    }
}

struct RecommendationSection: View {
    let recommendations: [PersonalizedRecommendation]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "パーソナライズされた推奨事項", icon: "lightbulb")
            
            ForEach(recommendations, id: \.id) { recommendation in
                DetailedRecommendationCard(recommendation: recommendation)
            }
        }
    }
}

// MARK: - Helper Views

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
        }
    }
}

struct EmptyReportView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.below.ecg")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("レポートを生成できませんでした")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("十分な健康データがないか、分析中にエラーが発生しました")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 60)
    }
}

struct EmptySectionView: View {
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .font(.title2)
                .foregroundColor(.gray)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Placeholder Card Views

struct InsightCard: View {
    let insight: HealthInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(insight.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Badge(text: insight.priority.displayName, color: insight.priority.color)
            }
            
            Text(insight.summary)
                .font(.body)
                .foregroundColor(.secondary)
            
            if !insight.recommendations.isEmpty {
                Text("推奨事項:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ForEach(insight.recommendations, id: \.id) { recommendation in
                    HStack {
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text(recommendation.description)
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// Additional placeholder card views would be implemented here...
// For brevity, showing the pattern with InsightCard

#Preview {
    MonthlyReportView(reportDate: Date(), report: nil)
}