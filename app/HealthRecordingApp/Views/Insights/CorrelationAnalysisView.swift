import SwiftUI
import Charts

struct CorrelationAnalysisView: View {
    let correlationResults: [AdvancedCorrelationResult]
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedResult: AdvancedCorrelationResult?
    @State private var selectedMethod: CorrelationMethod = .pearson
    @State private var showingMethodDetails = false
    @State private var sortBy: SortOption = .strength
    
    enum SortOption: String, CaseIterable {
        case strength = "strength"
        case significance = "significance"
        case sampleSize = "sample_size"
        case dataTypes = "data_types"
        
        var displayName: String {
            switch self {
            case .strength: return "相関の強さ"
            case .significance: return "統計的有意性"
            case .sampleSize: return "サンプル数"
            case .dataTypes: return "データタイプ"
            }
        }
    }
    
    var sortedResults: [AdvancedCorrelationResult] {
        switch sortBy {
        case .strength:
            return correlationResults.sorted { 
                abs($0.correlationResults[selectedMethod] ?? 0) > abs($1.correlationResults[selectedMethod] ?? 0)
            }
        case .significance:
            return correlationResults.sorted { 
                ($0.significanceResults[selectedMethod]?.pValue ?? 1.0) < ($1.significanceResults[selectedMethod]?.pValue ?? 1.0)
            }
        case .sampleSize:
            return correlationResults.sorted { $0.sampleSize > $1.sampleSize }
        case .dataTypes:
            return correlationResults.sorted { 
                $0.primaryDataType.displayName < $1.primaryDataType.displayName
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Analysis overview header
                analysisOverviewSection
                
                // Controls section
                controlsSection
                
                // Main content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if correlationResults.isEmpty {
                            noCorrelationsView
                        } else {
                            // Correlation matrix visualization
                            correlationMatrixSection
                            
                            // Detailed results
                            detailedResultsSection
                            
                            // Causal discoveries
                            causalDiscoveriesSection
                            
                            // Time-lagged correlations
                            timeLaggedSection
                            
                            // Non-linear patterns
                            nonLinearPatternsSection
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("相関分析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("分析手法について", systemImage: "info.circle") {
                            showingMethodDetails = true
                        }
                        
                        Divider()
                        
                        Button("CSVでエクスポート", systemImage: "square.and.arrow.up") {
                            exportCorrelationData()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingMethodDetails) {
                CorrelationMethodsInfoView()
            }
            .sheet(item: $selectedResult) { result in
                DetailedCorrelationView(result: result)
            }
        }
    }
    
    // MARK: - Analysis Overview
    
    private var analysisOverviewSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("相関分析結果")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("\(correlationResults.count)組の関係を分析")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("平均サンプル数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    let averageSampleSize = correlationResults.isEmpty ? 0 : 
                        correlationResults.map { $0.sampleSize }.reduce(0, +) / correlationResults.count
                    
                    Text("\(averageSampleSize)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
            
            // Quick stats
            if !correlationResults.isEmpty {
                correlationStatsView
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Controls
    
    private var controlsSection: some View {
        VStack(spacing: 12) {
            // Method picker
            HStack {
                Text("相関手法:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("相関手法", selection: $selectedMethod) {
                    ForEach(CorrelationMethod.allCases, id: \.self) { method in
                        Text(method.displayName).tag(method)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Sort options
            HStack {
                Text("並び順:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("並び順", selection: $sortBy) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Correlation Matrix
    
    private var correlationMatrixSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "相関マトリックス", icon: "grid")
            
            CorrelationMatrixView(
                results: correlationResults,
                selectedMethod: selectedMethod
            )
        }
    }
    
    // MARK: - Detailed Results
    
    private var detailedResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "詳細結果", icon: "list.bullet")
            
            ForEach(sortedResults, id: \.id) { result in
                CorrelationResultCard(
                    result: result,
                    selectedMethod: selectedMethod
                ) {
                    selectedResult = result
                }
            }
        }
    }
    
    // MARK: - Causal Discoveries
    
    private var causalDiscoveriesSection: some View {
        let causalResults = correlationResults.filter { !$0.causalityResult.discoveries.isEmpty }
        
        return Group {
            if !causalResults.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "因果関係の発見", icon: "arrow.triangle.branch")
                    
                    ForEach(causalResults, id: \.id) { result in
                        CausalityDiscoveryCard(result: result)
                    }
                }
            }
        }
    }
    
    // MARK: - Time-Lagged Correlations
    
    private var timeLaggedSection: some View {
        let laggedResults = correlationResults.filter { !$0.timeLaggedCorrelations.isEmpty }
        
        return Group {
            if !laggedResults.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "時間遅れ相関", icon: "clock")
                    
                    ForEach(laggedResults.prefix(3), id: \.id) { result in
                        TimeLaggedCorrelationCard(result: result)
                    }
                }
            }
        }
    }
    
    // MARK: - Non-Linear Patterns
    
    private var nonLinearPatternsSection: some View {
        let nonLinearResults = correlationResults.filter { !$0.nonLinearPatterns.isEmpty }
        
        return Group {
            if !nonLinearResults.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "非線形パターン", icon: "waveform.path")
                    
                    ForEach(nonLinearResults.prefix(3), id: \.id) { result in
                        NonLinearPatternCard(result: result)
                    }
                }
            }
        }
    }
    
    // MARK: - No Correlations View
    
    private var noCorrelationsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "link.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("相関分析結果がありません")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("十分なデータがないか、有意な相関関係が見つかりませんでした")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 8) {
                Text("相関分析を改善するために:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• より多くの健康データを継続的に記録")
                    Text("• 異なるタイプのデータを組み合わせて記録")
                    Text("• 少なくとも2週間以上のデータ蓄積")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Helper Views
    
    private var correlationStatsView: some View {
        HStack(spacing: 20) {
            StatItem(
                title: "強い相関",
                count: strongCorrelationsCount,
                color: .green
            )
            
            StatItem(
                title: "中程度相関",
                count: moderateCorrelationsCount,
                color: .orange
            )
            
            StatItem(
                title: "弱い相関",
                count: weakCorrelationsCount,
                color: .blue
            )
            
            Spacer()
        }
    }
    
    private var strongCorrelationsCount: Int {
        correlationResults.filter { 
            abs($0.correlationResults[selectedMethod] ?? 0) >= 0.7 
        }.count
    }
    
    private var moderateCorrelationsCount: Int {
        correlationResults.filter { 
            let corr = abs($0.correlationResults[selectedMethod] ?? 0)
            return corr >= 0.3 && corr < 0.7
        }.count
    }
    
    private var weakCorrelationsCount: Int {
        correlationResults.filter { 
            abs($0.correlationResults[selectedMethod] ?? 0) < 0.3 
        }.count
    }
    
    // MARK: - Action Methods
    
    private func exportCorrelationData() {
        // Export correlation data as CSV
    }
}

// MARK: - Supporting Views

struct StatItem: View {
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

struct CorrelationMatrixView: View {
    let results: [AdvancedCorrelationResult]
    let selectedMethod: CorrelationMethod
    
    var dataTypes: [HealthDataType] {
        var types = Set<HealthDataType>()
        for result in results {
            types.insert(result.primaryDataType)
            types.insert(result.secondaryDataType)
        }
        return Array(types).sorted { $0.displayName < $1.displayName }
    }
    
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(80)), count: dataTypes.count + 1)) {
                // Header row
                Text("")
                    .frame(width: 80, height: 40)
                
                ForEach(dataTypes, id: \.self) { type in
                    Text(type.shortName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .frame(width: 80, height: 40)
                        .multilineTextAlignment(.center)
                }
                
                // Data rows
                ForEach(dataTypes, id: \.self) { primaryType in
                    Text(primaryType.shortName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .frame(width: 80, height: 80)
                        .multilineTextAlignment(.center)
                    
                    ForEach(dataTypes, id: \.self) { secondaryType in
                        CorrelationCell(
                            primaryType: primaryType,
                            secondaryType: secondaryType,
                            results: results,
                            selectedMethod: selectedMethod
                        )
                    }
                }
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CorrelationCell: View {
    let primaryType: HealthDataType
    let secondaryType: HealthDataType
    let results: [AdvancedCorrelationResult]
    let selectedMethod: CorrelationMethod
    
    private var correlation: Double? {
        if primaryType == secondaryType {
            return 1.0
        }
        
        return results.first { result in
            (result.primaryDataType == primaryType && result.secondaryDataType == secondaryType) ||
            (result.primaryDataType == secondaryType && result.secondaryDataType == primaryType)
        }?.correlationResults[selectedMethod]
    }
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(correlationColor)
                .frame(width: 80, height: 80)
            
            if let corr = correlation {
                Text("\(corr, specifier: "%.2f")")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(textColor)
            }
        }
    }
    
    private var correlationColor: Color {
        guard let corr = correlation else { return Color(.systemGray5) }
        
        let intensity = abs(corr)
        if corr > 0 {
            return Color.blue.opacity(intensity)
        } else {
            return Color.red.opacity(intensity)
        }
    }
    
    private var textColor: Color {
        guard let corr = correlation else { return .secondary }
        return abs(corr) > 0.5 ? .white : .primary
    }
}

struct CorrelationResultCard: View {
    let result: AdvancedCorrelationResult
    let selectedMethod: CorrelationMethod
    let onTap: () -> Void
    
    var correlation: Double {
        result.correlationResults[selectedMethod] ?? 0.0
    }
    
    var significance: StatisticalSignificanceResult? {
        result.significanceResults[selectedMethod]
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(result.primaryDataType.displayName) ↔ \(result.secondaryDataType.displayName)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.leading)
                        
                        Text("\(selectedMethod.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(correlation, specifier: "%.3f")")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(correlationStrengthColor(correlation))
                        
                        CorrelationStrengthBadge(correlation: correlation)
                    }
                }
                
                // Statistics
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("サンプル数")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("\(result.sampleSize)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    if let sig = significance {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("p値")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text("\(sig.pValue, specifier: "%.4f")")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("有意性")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text(sig.isSignificant ? "有意" : "非有意")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(sig.isSignificant ? .green : .orange)
                        }
                    }
                    
                    Spacer()
                }
                
                // Data quality indicator
                DataQualityIndicator(metrics: result.dataQualityMetrics)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func correlationStrengthColor(_ correlation: Double) -> Color {
        let absCorr = abs(correlation)
        if absCorr >= 0.7 {
            return .green
        } else if absCorr >= 0.3 {
            return .orange
        } else {
            return .blue
        }
    }
}

struct CorrelationStrengthBadge: View {
    let correlation: Double
    
    private var strengthText: String {
        let absCorr = abs(correlation)
        if absCorr >= 0.7 {
            return "強い"
        } else if absCorr >= 0.3 {
            return "中程度"
        } else {
            return "弱い"
        }
    }
    
    private var strengthColor: Color {
        let absCorr = abs(correlation)
        if absCorr >= 0.7 {
            return .green
        } else if absCorr >= 0.3 {
            return .orange
        } else {
            return .blue
        }
    }
    
    var body: some View {
        Text(strengthText)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(strengthColor.opacity(0.2))
            .foregroundColor(strengthColor)
            .cornerRadius(4)
    }
}

struct DataQualityIndicator: View {
    let metrics: DataQualityMetrics
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.shield")
                .foregroundColor(qualityColor)
                .font(.caption)
            
            Text("データ品質: \(Int(metrics.overallScore * 100))%")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    private var qualityColor: Color {
        if metrics.overallScore >= 0.8 {
            return .green
        } else if metrics.overallScore >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
}

struct CausalityDiscoveryCard: View {
    let result: AdvancedCorrelationResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundColor(.purple)
                
                Text("因果関係の可能性")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            ForEach(result.causalityResult.discoveries.prefix(2), id: \.id) { discovery in
                HStack {
                    Text(discovery.cause.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    
                    Text(discovery.effect.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("信頼度: \(Int(discovery.confidence * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(8)
    }
}

struct TimeLaggedCorrelationCard: View {
    let result: AdvancedCorrelationResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.blue)
                
                Text("時間遅れ相関")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            ForEach(result.timeLaggedCorrelations.prefix(3), id: \.id) { lagged in
                HStack {
                    Text("\(lagged.lagDays)日遅れ")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(lagged.baseCorrelation.correlationCoefficient, specifier: "%.3f")")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(lagged.direction.color)
                    
                    Text(lagged.direction.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

struct NonLinearPatternCard: View {
    let result: AdvancedCorrelationResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "waveform.path")
                    .foregroundColor(.green)
                
                Text("非線形パターン")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            ForEach(result.nonLinearPatterns.prefix(2), id: \.id) { pattern in
                HStack {
                    Text(pattern.type.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("強度: \(pattern.strength, specifier: "%.3f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("R²: \(pattern.rSquared, specifier: "%.3f")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Detailed Correlation View

struct DetailedCorrelationView: View {
    let result: AdvancedCorrelationResult
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    // Header
                    correlationHeaderSection
                    
                    // All correlation methods
                    allMethodsSection
                    
                    // Statistical significance
                    significanceSection
                    
                    // Partial correlations
                    if !result.partialCorrelations.isEmpty {
                        partialCorrelationsSection
                    }
                    
                    // Time-lagged analysis
                    if !result.timeLaggedCorrelations.isEmpty {
                        timeLaggedAnalysisSection
                    }
                    
                    // Causality analysis
                    causalityAnalysisSection
                    
                    // Data quality assessment
                    dataQualitySection
                    
                    // Interpretation guide
                    interpretationSection
                }
                .padding()
            }
            .navigationTitle("詳細相関分析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var correlationHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(result.primaryDataType.displayName)")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Image(systemName: "link")
                    .foregroundColor(.blue)
                
                Text("\(result.secondaryDataType.displayName)")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            HStack {
                Text("サンプル数: \(result.sampleSize)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("分析日時: \(result.analysisTimestamp, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var allMethodsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("相関係数")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(CorrelationMethod.allCases, id: \.self) { method in
                if let correlation = result.correlationResults[method] {
                    MethodCorrelationRow(method: method, correlation: correlation)
                }
            }
        }
    }
    
    private var significanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("統計的有意性")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(CorrelationMethod.allCases, id: \.self) { method in
                if let significance = result.significanceResults[method] {
                    SignificanceRow(method: method, significance: significance)
                }
            }
        }
    }
    
    private var partialCorrelationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("偏相関分析")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(result.partialCorrelations, id: \.id) { partial in
                PartialCorrelationRow(partial: partial)
            }
        }
    }
    
    private var timeLaggedAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("時間遅れ相関分析")
                .font(.headline)
                .fontWeight(.semibold)
            
            Chart(result.timeLaggedCorrelations) { lagged in
                LineMark(
                    x: .value("Lag (days)", lagged.lagDays),
                    y: .value("Correlation", lagged.baseCorrelation.correlationCoefficient)
                )
                .foregroundStyle(.blue)
                
                PointMark(
                    x: .value("Lag (days)", lagged.lagDays),
                    y: .value("Correlation", lagged.baseCorrelation.correlationCoefficient)
                )
                .foregroundStyle(.blue)
            }
            .frame(height: 200)
            .chartYScale(domain: -1...1)
            .chartXAxis {
                AxisMarks(preset: .aligned, position: .bottom)
            }
            .chartYAxis {
                AxisMarks(preset: .aligned, position: .leading)
            }
        }
    }
    
    private var causalityAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("因果性分析")
                .font(.headline)
                .fontWeight(.semibold)
            
            if result.causalityResult.discoveries.isEmpty {
                Text("明確な因果関係は検出されませんでした")
                    .font(.body)
                    .foregroundColor(.secondary)
            } else {
                ForEach(result.causalityResult.discoveries, id: \.id) { discovery in
                    CausalityDiscoveryDetailRow(discovery: discovery)
                }
            }
        }
    }
    
    private var dataQualitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("データ品質評価")
                .font(.headline)
                .fontWeight(.semibold)
            
            DataQualityDetailView(metrics: result.dataQualityMetrics)
        }
    }
    
    private var interpretationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("解釈ガイド")
                .font(.headline)
                .fontWeight(.semibold)
            
            InterpretationGuideView(guide: result.interpretationGuide)
        }
    }
}

// MARK: - Additional Supporting Views

struct MethodCorrelationRow: View {
    let method: CorrelationMethod
    let correlation: Double
    
    var body: some View {
        HStack {
            Text(method.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Text("\(correlation, specifier: "%.4f")")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(correlationColor)
            
            CorrelationStrengthBadge(correlation: correlation)
        }
        .padding(.vertical, 4)
    }
    
    private var correlationColor: Color {
        let absCorr = abs(correlation)
        if correlation > 0 {
            return absCorr >= 0.7 ? .green : absCorr >= 0.3 ? .blue : .gray
        } else {
            return absCorr >= 0.7 ? .red : absCorr >= 0.3 ? .orange : .gray
        }
    }
}

struct SignificanceRow: View {
    let method: CorrelationMethod
    let significance: StatisticalSignificanceResult
    
    var body: some View {
        HStack {
            Text(method.displayName)
                .font(.subheadline)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("p = \(significance.pValue, specifier: "%.4f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(significance.isSignificant ? "有意" : "非有意")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(significance.isSignificant ? .green : .orange)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Extensions

extension HealthDataType {
    var shortName: String {
        switch self {
        case .weight: return "体重"
        case .steps: return "歩数"
        case .calories: return "カロリー"
        case .heartRate: return "心拍"
        case .bloodPressure: return "血圧"
        case .sleep: return "睡眠"
        case .hydration: return "水分"
        case .exercise: return "運動"
        case .custom: return "その他"
        }
    }
}

extension LagDirection {
    var color: Color {
        switch self {
        case .leading: return .green
        case .lagging: return .orange
        case .synchronous: return .blue
        }
    }
}

// MARK: - Method Info Sheet

struct CorrelationMethodsInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(CorrelationMethod.allCases, id: \.self) { method in
                        CorrelationMethodInfoCard(method: method)
                    }
                }
                .padding()
            }
            .navigationTitle("相関分析手法について")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CorrelationMethodInfoCard: View {
    let method: CorrelationMethod
    
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
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Extensions for Method Details

extension CorrelationMethod {
    var iconName: String {
        switch self {
        case .pearson: return "chart.line.uptrend.xyaxis"
        case .spearman: return "arrow.up.arrow.down"
        case .kendall: return "arrow.clockwise"
        case .partial: return "link.circle"
        case .canonical: return "square.grid.3x3"
        }
    }
    
    var description: String {
        switch self {
        case .pearson:
            return "線形関係の強さを測定する最も一般的な相関係数です。-1から1の値を取り、正規分布データに適しています。"
        case .spearman:
            return "順位に基づく相関係数で、非線形関係や外れ値に対してより頑健です。単調関係を検出できます。"
        case .kendall:
            return "順位の一致度に基づく相関係数で、小さなサンプルサイズや外れ値に対して安定しています。"
        case .partial:
            return "他の変数の影響を除去した上での2変数間の相関を測定します。交絡因子を制御できます。"
        case .canonical:
            return "2つの変数セット間の関係を分析する多変量手法です。複数の変数間の複雑な関係を捉えます。"
        }
    }
    
    var characteristics: [String] {
        switch self {
        case .pearson:
            return ["線形関係を測定", "正規分布データに適している", "外れ値に敏感", "解釈しやすい"]
        case .spearman:
            return ["単調関係を測定", "外れ値に頑健", "順序データに適用可能", "非線形関係も検出"]
        case .kendall:
            return ["順位の一致度を測定", "小サンプルに適している", "外れ値に非常に頑健", "計算コストが高い"]
        case .partial:
            return ["交絡因子を制御", "因果推論に有用", "複雑な関係を分析", "解釈に注意が必要"]
        case .canonical:
            return ["多変量分析", "変数セット間の関係", "次元削減効果", "高度な統計知識が必要"]
        }
    }
}

#Preview {
    CorrelationAnalysisView(correlationResults: [])
}