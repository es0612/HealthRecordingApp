import SwiftUI
import Charts

struct AnomalyDetectionResultView: View {
    let anomalyResult: EnhancedAnomalyResult?
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMethod: AnomalyDetectionMethod = .statisticalThreshold
    @State private var selectedSeverity: InsightAnomalySeverity?
    @State private var showingMethodDetails = false
    @State private var expandedAnomalyId: UUID?
    
    private var filteredAnomalies: [AnomalousPattern] {
        guard let result = anomalyResult else { return [] }
        
        var anomalies = result.detectedAnomalies
        
        if let severity = selectedSeverity {
            anomalies = anomalies.filter { $0.severity == severity }
        }
        
        return anomalies.sorted { $0.severity.rawValue < $1.severity.rawValue }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Analysis summary header
                analysisHeaderSection
                
                // Filter controls
                filterControlsSection
                
                // Main content
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 16) {
                        if let result = anomalyResult {
                            // Method comparison section
                            methodComparisonSection(result: result)
                            
                            // Risk assessment section
                            riskAssessmentSection(assessment: result.riskAssessment)
                            
                            // Detailed anomalies list
                            anomaliesListSection
                            
                            // Insights and recommendations
                            insightsSection(insights: result.anomalyInsights)
                        } else {
                            noAnomaliesView
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("異常検出分析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                #else
                ToolbarItem(placement: .automatic) {
                #endif
                    Button("詳細", systemImage: "info.circle") {
                        showingMethodDetails = true
                    }
                }
            }
            .sheet(isPresented: $showingMethodDetails) {
                AnomalyDetectionMethodsInfoView()
            }
        }
    }
    
    // MARK: - Analysis Header
    
    private var analysisHeaderSection: some View {
        VStack(spacing: 12) {
            if let result = anomalyResult {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("検出された異常")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("\(result.detectedAnomalies.count)件の異常パターン")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("信頼度")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(result.analysisMetadata.confidenceLevel * 100))%")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(confidenceColor(result.analysisMetadata.confidenceLevel))
                    }
                }
                
                // Severity distribution
                severityDistributionView(anomalies: result.detectedAnomalies)
            }
        }
        .padding()
        #if os(iOS)
        .background(Color(.systemGray6))
        #else
        .background(Color(Color.gray.opacity(0.1)))
        #endif
    }
    
    // MARK: - Filter Controls
    
    private var filterControlsSection: some View {
        VStack(spacing: 12) {
            // Detection method picker
            if let result = anomalyResult {
                HStack {
                    Text("検出手法:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("検出手法", selection: $selectedMethod) {
                        ForEach(Array(result.methodResults.keys), id: \.self) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            
            // Severity filter
            HStack {
                Text("重要度フィルター:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button("すべて") {
                        selectedSeverity = nil
                    }
                    .buttonStyle(FilterButtonStyle(isSelected: selectedSeverity == nil))
                    
                    ForEach(InsightAnomalySeverity.allCases, id: \.self) { severity in
                        Button(severity.displayName) {
                            selectedSeverity = selectedSeverity == severity ? nil : severity
                        }
                        .buttonStyle(FilterButtonStyle(isSelected: selectedSeverity == severity))
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        #if os(iOS)
        .background(Color(.systemBackground))
        #else
        .background(Color.white)
        #endif
    }
    
    // MARK: - Method Comparison
    
    private func methodComparisonSection(result: EnhancedAnomalyResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "検出手法の比較", icon: "chart.bar.xaxis")
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(Array(result.methodResults.keys), id: \.self) { method in
                    MethodComparisonCard(
                        method: method,
                        anomaliesCount: result.methodResults[method]?.count ?? 0,
                        isSelected: selectedMethod == method
                    ) {
                        selectedMethod = method
                    }
                }
            }
            
            // Method-specific anomalies
            if let methodAnomalies = result.methodResults[selectedMethod] {
                Text("\(selectedMethod.displayName)による検出結果")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.top)
                
                ForEach(methodAnomalies.prefix(3), id: \.id) { anomaly in
                    AnomalyMethodCard(anomaly: anomaly, method: selectedMethod)
                }
                
                if methodAnomalies.count > 3 {
                    Button("さらに\(methodAnomalies.count - 3)件表示") {
                        // Show more anomalies for this method
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    // MARK: - Risk Assessment
    
    private func riskAssessmentSection(assessment: AnomalyRiskAssessment) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "リスク評価", icon: "shield.lefthalf.filled")
            
            OverallRiskCard(
                riskLevel: assessment.overallRiskLevel,
                riskScore: assessment.riskScore,
                criticalCount: assessment.criticalAnomalies.count
            )
            
            if !assessment.immediateActions.isEmpty {
                Text("即座に必要な行動")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
                
                ForEach(assessment.immediateActions, id: \.id) { action in
                    ImmediateActionCard(action: action)
                }
            }
            
            if !assessment.monitoringRecommendations.isEmpty {
                Text("モニタリング推奨事項")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ForEach(assessment.monitoringRecommendations, id: \.id) { recommendation in
                    MonitoringRecommendationCard(recommendation: recommendation)
                }
            }
        }
    }
    
    // MARK: - Anomalies List
    
    private var anomaliesListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "検出された異常", icon: "exclamationmark.triangle")
                
                Spacer()
                
                Text("\(self.filteredAnomalies.count)件")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if self.filteredAnomalies.isEmpty {
                EmptyStateView(
                    title: "異常なし",
                    message: "選択された条件に該当する異常は見つかりませんでした"
                )
            } else {
                ForEach(self.filteredAnomalies, id: \.id) { anomaly in
                    DetailedAnomalyCard(
                        anomaly: anomaly,
                        isExpanded: self.expandedAnomalyId == anomaly.id
                    ) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.expandedAnomalyId = self.expandedAnomalyId == anomaly.id ? nil : anomaly.id
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Insights Section
    
    private func insightsSection(insights: [HealthInsight]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "分析インサイト", icon: "lightbulb")
            
            ForEach(insights, id: \.id) { insight in
                InsightCard(insight: insight)
            }
        }
    }
    
    // MARK: - No Anomalies View
    
    private var noAnomaliesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("異常は検出されませんでした")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("あなたの健康データには心配するような異常なパターンは見つかりませんでした")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 8) {
                Text("継続的な健康管理のために:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• 定期的なデータ記録を続ける")
                    Text("• バランスの取れた生活習慣を維持")
                    Text("• 気になる変化があれば医師に相談")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            #if os(iOS)
            .background(Color(.systemGray6))
            #else
            .background(Color.gray.opacity(0.1))
            #endif
            .cornerRadius(12)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Helper Views
    
    private func severityDistributionView(anomalies: [AnomalousPattern]) -> some View {
        let severityCounts = Dictionary(grouping: anomalies, by: { $0.severity })
            .mapValues { $0.count }
        
        return HStack(spacing: 12) {
            ForEach(InsightAnomalySeverity.allCases, id: \.self) { severity in
                let count = severityCounts[severity] ?? 0
                
                VStack(spacing: 2) {
                    Text("\(count)")
                        .font(Font.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(severity.color)
                    
                    Text(severity.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(minWidth: 40)
            }
            
            Spacer()
        }
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        switch confidence {
        case 0.8...:
            return .green
        case 0.6..<0.8:
            return .orange
        default:
            return .red
        }
    }

// MARK: - Supporting Views

struct MethodComparisonCard: View {
    let method: AnomalyDetectionMethod
    let anomaliesCount: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: method.iconName)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(method.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text("\(anomaliesCount)件")
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    #if os(iOS)
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
                    #else
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.1))
                    #endif
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AnomalyMethodCard: View {
    let anomaly: AnomalousPattern
    let method: AnomalyDetectionMethod
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: anomaly.severity.iconName)
                .foregroundColor(anomaly.severity.color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(anomaly.dataType.displayName)の\(anomaly.anomalyType.displayName)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("信頼度: \(Int(anomaly.confidence * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(anomaly.startDate, style: .relative)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        #if os(iOS)
        .background(Color(.systemGray6))
        #else
        .background(Color(Color.gray.opacity(0.1)))
        #endif
        .cornerRadius(8)
    }
}

struct OverallRiskCard: View {
    let riskLevel: RiskLevel
    let riskScore: Double
    let criticalCount: Int
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("総合リスクレベル")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(riskLevel.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(riskLevel.color)
                
                Text("スコア: \(Int(riskScore * 100))/100")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                if criticalCount > 0 {
                    VStack(spacing: 2) {
                        Text("\(criticalCount)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        
                        Text("緊急")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(riskLevel.color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(riskLevel.color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct DetailedAnomalyCard: View {
    let anomaly: AnomalousPattern
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            
            if isExpanded {
                expandedDetailsSection
            }
        }
        .padding()
        #if os(iOS)
        .background(Color(.systemBackground))
        #else
        .background(Color.white)
        #endif
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: anomaly.severity.iconName)
                    .foregroundColor(anomaly.severity.color)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(anomaly.dataType.displayName)の\(anomaly.anomalyType.displayName)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(anomaly.startDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    InfoBadge(text: anomaly.severity.displayName, color: anomaly.severity.color)
                    
                    Text("\(Int(anomaly.confidence * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Expanded Details Section
    
    private var expandedDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            
            valuesComparisonSection
            detectionMethodSection
            
            if !anomaly.potentialCauses.isEmpty {
                potentialCausesSection
            }
            
            if !anomaly.immediateActions.isEmpty {
                immediateActionsSection
            }
        }
    }
    
    // MARK: - Values Comparison
    
    private var valuesComparisonSection: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("期待値")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(String(format: "%.2f", anomaly.expectedValue))
                    .font(Font.subheadline)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("観測値")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(String(format: "%.2f", anomaly.observedValue))
                    .font(Font.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(anomaly.severity.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("偏差")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(deviationText)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Detection Method
    
    private var detectionMethodSection: some View {
        HStack {
            Text("検出方法:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(anomaly.detectionMethod.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
    
    // MARK: - Potential Causes
    
    private var potentialCausesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("考えられる原因:")
                .font(.caption)
                .fontWeight(.medium)
            
            ForEach(anomaly.potentialCauses.prefix(2), id: \.id) { cause in
                HStack {
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    
                    Text(cause.description)
                        .font(.caption)
                }
            }
        }
    }
    
    // MARK: - Immediate Actions
    
    private var immediateActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("推奨される行動:")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.orange)
            
            ForEach(anomaly.immediateActions.prefix(2), id: \.id) { action in
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    
                    Text(action.description)
                        .font(.caption)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var deviationText: String {
        let deviation = abs(anomaly.observedValue - anomaly.expectedValue) / anomaly.expectedValue * 100
        return String(format: "%.1f%%", deviation)
    }
}

struct FilterButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    #if os(iOS)
                    .fill(isSelected ? Color.blue : Color(.systemGray5))
                    #else
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.2))
                    #endif
            )
            .foregroundColor(isSelected ? .white : .primary)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct ImmediateActionCard: View {
    let action: ImmediateAction
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(action.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("優先度: \(action.priority.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

struct MonitoringRecommendationCard: View {
    let recommendation: MonitoringRecommendation
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("頻度: \(recommendation.frequency.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title)
                .foregroundColor(.gray)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Method Info Sheet

struct AnomalyDetectionMethodsInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(AnomalyDetectionMethod.allCases, id: \.self) { method in
                        MethodInfoCard(method: method)
                    }
                }
                .padding()
            }
            .navigationTitle("検出手法について")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                #else
                ToolbarItem(placement: .automatic) {
                #endif
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }

struct MethodInfoCard: View {
    let method: AnomalyDetectionMethod
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: method.iconName)
                    .foregroundColor(.blue)
                
                Text(method.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Text(method.description)
                .font(.body)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("特徴:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ForEach(method.characteristics, id: \.self) { characteristic in
                    HStack {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Text(characteristic)
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        #if os(iOS)
        .background(Color(.systemGray6))
        #else
        .background(Color(Color.gray.opacity(0.1)))
        #endif
        .cornerRadius(12)
    }
}

// MARK: - Extensions

extension AnomalyDetectionMethod {
    var iconName: String {
        switch self {
        case .statisticalThreshold: return "chart.bar"
        case .movingAverage: return "chart.line.uptrend.xyaxis"
        case .seasonalDecomposition: return "calendar.circle"
        case .timeSeriesDecomposition: return "waveform.path"
        case .isolationForest: return "tree"
        case .oneClassSVM: return "circle.dashed"
        case .autoencoder: return "arrow.triangle.2.circlepath"
        case .neuralNetwork: return "brain"
        case .clustering: return "circle.grid.cross"
        case .ensemble: return "rectangle.stack"
        case .ensembleMethod: return "rectangle.3.group"
        }
    }
    
    var displayName: String {
        switch self {
        case .statisticalThreshold: return "統計的閾値"
        case .movingAverage: return "移動平均"
        case .seasonalDecomposition: return "季節分解"
        case .timeSeriesDecomposition: return "時系列分解"
        case .isolationForest: return "分離フォレスト"
        case .oneClassSVM: return "One-Class SVM"
        case .autoencoder: return "オートエンコーダー"
        case .neuralNetwork: return "ニューラルネット"
        case .clustering: return "クラスタリング"
        case .ensemble: return "アンサンブル"
        case .ensembleMethod: return "アンサンブル手法"
        }
    }
    
    var description: String {
        switch self {
        case .statisticalThreshold:
            return "統計的な閾値を使用して、正常な範囲から外れた値を異常として検出します。"
        case .movingAverage:
            return "移動平均を基準として、平均から大きく外れた値を異常として検出します。"
        case .seasonalDecomposition:
            return "季節性パターンを考慮し、季節調整後の値から異常を検出します。"
        case .timeSeriesDecomposition:
            return "時系列データをトレンド、季節性、残差に分解して異常を特定します。"
        case .isolationForest:
            return "データポイントを分離するのに必要な分割数に基づいて異常を検出します。"
        case .oneClassSVM:
            return "正常データのみで学習したSVMモデルを使用して、境界外のデータを異常とします。"
        case .autoencoder:
            return "オートエンコーダーで正常パターンを学習し、再構成誤差が大きいデータを異常とします。"
        case .neuralNetwork:
            return "ニューラルネットワークを使用して複雑なパターンの異常を学習・検出します。"
        case .clustering:
            return "データポイントをクラスターに分類し、どのクラスターにも属さないものを異常とします。"
        case .ensemble:
            return "複数の異常検出アルゴリズムの結果を統合して最終判定を行います。"
        case .ensembleMethod:
            return "複数の検出手法を組み合わせて、より正確な異常検出を行います。"
        }
    }
    
    var characteristics: [String] {
        switch self {
        case .statisticalThreshold:
            return ["シンプルで解釈しやすい", "正規分布データに適している", "閾値の設定が重要"]
        case .movingAverage:
            return ["トレンドの変化に対応", "ノイズを平滑化", "リアルタイム処理可能"]
        case .seasonalDecomposition:
            return ["季節パターンを考慮", "周期的な変動を除去", "長期トレンドを把握"]
        case .timeSeriesDecomposition:
            return ["季節性を考慮", "トレンドの変化を検出", "時系列データに特化"]
        case .isolationForest:
            return ["外れ値に強い", "高次元データに適している", "計算効率が良い"]
        case .oneClassSVM:
            return ["正常データのみで学習", "非線形境界に対応", "ロバストな検出"]
        case .autoencoder:
            return ["深層学習ベース", "高次元データに強い", "潜在表現を学習"]
        case .neuralNetwork:
            return ["複雑なパターンを学習", "高い検出精度", "大量データが必要"]
        case .clustering:
            return ["ラベルなし学習", "データ構造を発見", "多様な異常タイプを検出"]
        case .ensemble:
            return ["複数モデルの統合", "頑健な検出性能", "バイアス軽減"]
        case .ensembleMethod:
            return ["複数手法の組み合わせ", "バランスの取れた検出", "偽陽性を減らす"]
        }
    }
}

extension RiskLevel {
    var color: Color {
        switch self {
        case .veryLow: return .green
        case .low: return .yellow
        case .moderate: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
    
    var displayName: String {
        switch self {
        case .veryLow: return "とても低い"
        case .low: return "低い"
        case .moderate: return "中程度"
        case .high: return "高い"
        case .critical: return "緊急"
        }
    }
}

extension ActionPriority {
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

extension MonitoringFrequency {
    var displayName: String {
        switch self {
        case .continuous: return "継続的"
        case .realTime: return "リアルタイム"
        case .hourly: return "時間毎"
        case .daily: return "毎日"
        case .weekly: return "週次"
        case .monthly: return "月次"
        case .quarterly: return "四半期"
        }
    }
}

#Preview {
    AnomalyDetectionResultView(anomalyResult: nil)
}