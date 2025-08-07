import SwiftUI
import Charts
import Foundation

struct MultiDataComparisonView: View {
    @Bindable var viewModel: TrendsViewModel
    @State private var selectedDataTypes: Set<HealthDataType> = [.weight, .steps]
    @State private var comparisonMode: ComparisonMode = .overlay
    @State private var showingDataTypeSelector = false
    @State private var correlationAnalysis: ComparisonCorrelationAnalysis?
    @State private var isAnalyzingCorrelation = false
    
    // Chart interaction state
    @State private var selectedDataPoint: Date?
    @State private var crossHairPosition: CGPoint?
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with controls
            headerView
            
            // Comparison mode toggle
            comparisonModeSelector
            
            // Multi-data chart
            multiDataChartView
            
            // Correlation insights
            if let correlation = correlationAnalysis {
                CorrelationInsightsCard(analysis: correlation)
            }
            
            // Data types comparison statistics
            comparisonStatisticsView
        }
        .padding()
        .navigationTitle("データ比較")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("データタイプを選択") {
                        showingDataTypeSelector = true
                    }
                    
                    Button("相関分析を実行") {
                        analyzeCorrelation()
                    }
                    
                    Divider()
                    
                    Button("比較データをエクスポート") {
                        exportComparisonData()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingDataTypeSelector) {
            MultiDataTypeSelectorSheet(
                selectedDataTypes: $selectedDataTypes,
                onDone: {
                    showingDataTypeSelector = false
                }
            )
        }
        .task {
            await loadMultiDataComparison()
        }
        .onChange(of: selectedDataTypes) { _, _ in
            Task {
                await loadMultiDataComparison()
            }
        }
        .onChange(of: comparisonMode) { _, _ in
            // Trigger chart redraw with animation
            withAnimation(.easeInOut(duration: 0.3)) {
                // Chart will automatically update based on comparisonMode
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("複数データ比較")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("\(selectedDataTypes.count)つの指標を比較中")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("データ選択") {
                showingDataTypeSelector = true
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.1))
            .foregroundColor(.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    // MARK: - Comparison Mode Selector
    
    private var comparisonModeSelector: some View {
        HStack(spacing: 0) {
            ForEach(ComparisonMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        comparisonMode = mode
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: mode.iconName)
                        Text(mode.displayName)
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        comparisonMode == mode ? 
                        Color.accentColor : Color.clear
                    )
                    .foregroundColor(
                        comparisonMode == mode ? 
                        .white : .primary
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Multi-Data Chart View
    
    private var multiDataChartView: some View {
        VStack(spacing: 12) {
            // Legend
            chartLegend
            
            // Chart
            Chart {
                ForEach(Array(selectedDataTypes), id: \.self) { dataType in
                    ForEach(getChartData(for: dataType), id: \.id) { dataPoint in
                        switch comparisonMode {
                        case .overlay:
                            overlayChartMarks(for: dataPoint, dataType: dataType)
                        case .sideBySide:
                            sideBySideChartMarks(for: dataPoint, dataType: dataType)
                        case .normalized:
                            normalizedChartMarks(for: dataPoint, dataType: dataType)
                        }
                    }
                }
                
                // Cross-hair indicator
                if let selectedDate = selectedDataPoint {
                    RuleMark(x: .value("Date", selectedDate))
                        .foregroundStyle(.gray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
            }
            .frame(height: chartHeight)
            .chartBackground { chartProxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            handleChartInteraction(at: location, in: geometry, chartProxy: chartProxy)
                        }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .chartYAxis(comparisonMode == .sideBySide ? .trailing : .leading) {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
    }
    
    // MARK: - Chart Components
    
    private var chartLegend: some View {
        HStack {
            ForEach(Array(selectedDataTypes), id: \.self) { dataType in
                HStack(spacing: 6) {
                    Circle()
                        .fill(dataType.color)
                        .frame(width: 8, height: 8)
                    
                    Text(dataType.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(dataType.color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
    
    private var chartHeight: CGFloat {
        switch comparisonMode {
        case .overlay, .normalized: return 300
        case .sideBySide: return CGFloat(200 + (selectedDataTypes.count * 80))
        }
    }
    
    @ChartContentBuilder
    private func overlayChartMarks(for dataPoint: ComparisonDataPoint, dataType: HealthDataType) -> some ChartContent {
        LineMark(
            x: .value("Date", dataPoint.date),
            y: .value(dataType.displayName, dataPoint.value)
        )
        .foregroundStyle(dataType.color)
        .lineStyle(StrokeStyle(lineWidth: 2))
        .interpolationMethod(.catmullRom)
        
        PointMark(
            x: .value("Date", dataPoint.date),
            y: .value(dataType.displayName, dataPoint.value)
        )
        .foregroundStyle(dataType.color)
        .symbolSize(30)
    }
    
    @ChartContentBuilder
    private func sideBySideChartMarks(for dataPoint: ComparisonDataPoint, dataType: HealthDataType) -> some ChartContent {
        BarMark(
            x: .value("Date", dataPoint.date),
            y: .value(dataType.displayName, dataPoint.value),
            width: .fixed(20)
        )
        .foregroundStyle(dataType.color.gradient)
        .position(by: .value("Type", dataType.displayName))
    }
    
    @ChartContentBuilder
    private func normalizedChartMarks(for dataPoint: ComparisonDataPoint, dataType: HealthDataType) -> some ChartContent {
        let normalizedValue = normalizeValue(dataPoint.value, for: dataType)
        
        LineMark(
            x: .value("Date", dataPoint.date),
            y: .value("Normalized", normalizedValue)
        )
        .foregroundStyle(dataType.color)
        .lineStyle(StrokeStyle(lineWidth: 3))
        .interpolationMethod(.cardinal)
        
        AreaMark(
            x: .value("Date", dataPoint.date),
            y: .value("Normalized", normalizedValue)
        )
        .foregroundStyle(
            LinearGradient(
                colors: [dataType.color.opacity(0.3), dataType.color.opacity(0.1), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .interpolationMethod(.cardinal)
    }
    
    // MARK: - Comparison Statistics View
    
    private var comparisonStatisticsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("比較統計")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: min(selectedDataTypes.count, 3)), spacing: 12) {
                ForEach(Array(selectedDataTypes), id: \.self) { dataType in
                    ComparisonStatCard(
                        dataType: dataType,
                        statistics: getStatistics(for: dataType)
                    )
                }
            }
        }
        .padding()
        .background(
            #if os(iOS)
            Color(.systemGray6).opacity(0.5)
            #else
            Color.gray.opacity(0.1)
            #endif
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Data Methods
    
    private func getChartData(for dataType: HealthDataType) -> [ComparisonDataPoint] {
        // Convert viewModel's chart data points to comparison data points
        return viewModel.chartDataPoints.map { point in
            ComparisonDataPoint(
                date: point.date,
                value: point.value,
                dataType: dataType
            )
        }
    }
    
    private func normalizeValue(_ value: Double, for dataType: HealthDataType) -> Double {
        // Normalize to 0-100 scale for better comparison
        let statistics = getStatistics(for: dataType)
        let range = statistics.maximum - statistics.minimum
        guard range > 0 else { return 50 }
        return ((value - statistics.minimum) / range) * 100
    }
    
    private func getStatistics(for dataType: HealthDataType) -> ComparisonStatistics {
        let dataPoints = getChartData(for: dataType)
        let values = dataPoints.map(\.value)
        
        return ComparisonStatistics(
            dataType: dataType,
            count: values.count,
            average: values.reduce(0, +) / Double(values.count),
            minimum: values.min() ?? 0,
            maximum: values.max() ?? 0,
            standardDeviation: calculateStandardDeviation(values)
        )
    }
    
    private func calculateStandardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { sum, value in
            sum + pow(value - mean, 2)
        } / Double(values.count - 1)
        return sqrt(variance)
    }
    
    // MARK: - Actions
    
    private func loadMultiDataComparison() async {
        // Load data for all selected data types
        for dataType in selectedDataTypes {
            await viewModel.updateDataType(dataType)
        }
    }
    
    private func handleChartInteraction(at location: CGPoint, in geometry: GeometryProxy, chartProxy: ChartProxy) {
        guard let plotFrame = chartProxy.plotFrame else { return }
        let frame = geometry[plotFrame]
        let origin = geometry[plotFrame].origin
        
        // Calculate the relative position in the plot area
        let relativeX = location.x - origin.x
        
        // Convert to date (simplified - in a real implementation, you'd use chartProxy to convert coordinates)
        if let closestDate = findClosestDate(at: relativeX, in: frame) {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDataPoint = closestDate
                crossHairPosition = location
            }
        }
    }
    
    private func findClosestDate(at x: CGFloat, in frame: CGRect) -> Date? {
        // Simplified implementation
        let dataPoints = viewModel.chartDataPoints
        guard !dataPoints.isEmpty else { return nil }
        
        let index = Int((x / frame.width) * CGFloat(dataPoints.count - 1))
        let clampedIndex = max(0, min(index, dataPoints.count - 1))
        
        return dataPoints[clampedIndex].date
    }
    
    private func analyzeCorrelation() {
        guard selectedDataTypes.count >= 2 else { return }
        
        isAnalyzingCorrelation = true
        
        // Simulate correlation analysis
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let dataTypesArray = Array(selectedDataTypes)
            correlationAnalysis = ComparisonCorrelationAnalysis(
                dataTypeA: dataTypesArray[0],
                dataTypeB: dataTypesArray[1],
                correlationCoefficient: Double.random(in: -1...1),
                strength: .medium,
                significance: 0.05
            )
            isAnalyzingCorrelation = false
        }
    }
    
    private func exportComparisonData() {
        // TODO: Implement comparison data export
        print("Exporting comparison data for: \(selectedDataTypes.map(\.displayName).joined(separator: ", "))")
    }
}

// MARK: - Supporting Types

enum ComparisonMode: CaseIterable {
    case overlay, sideBySide, normalized
    
    var displayName: String {
        switch self {
        case .overlay: return "オーバーレイ"
        case .sideBySide: return "並列表示"
        case .normalized: return "正規化"
        }
    }
    
    var iconName: String {
        switch self {
        case .overlay: return "square.stack"
        case .sideBySide: return "rectangle.split.2x1"
        case .normalized: return "chart.bar.xaxis"
        }
    }
}

struct ComparisonDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let dataType: HealthDataType
}

struct ComparisonStatistics {
    let dataType: HealthDataType
    let count: Int
    let average: Double
    let minimum: Double
    let maximum: Double
    let standardDeviation: Double
}

struct ComparisonCorrelationAnalysis {
    let dataTypeA: HealthDataType
    let dataTypeB: HealthDataType
    let correlationCoefficient: Double
    let strength: ComparisonCorrelationStrength
    let significance: Double
}

enum ComparisonCorrelationStrength: CaseIterable {
    case weak, medium, strong, veryStrong
    
    var displayName: String {
        switch self {
        case .weak: return "弱い"
        case .medium: return "中程度"
        case .strong: return "強い"
        case .veryStrong: return "非常に強い"
        }
    }
    
    var color: Color {
        switch self {
        case .weak: return .gray
        case .medium: return .yellow
        case .strong: return .orange
        case .veryStrong: return .red
        }
    }
}

// MARK: - Component Views

struct ComparisonStatCard: View {
    let dataType: HealthDataType
    let statistics: ComparisonStatistics
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: dataType.iconName)
                    .foregroundColor(dataType.color)
                Text(dataType.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            VStack(spacing: 4) {
                Text("\(String(format: "%.1f", statistics.average))")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(dataType.color)
                
                Text("平均値")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                VStack {
                    Text("\(String(format: "%.0f", statistics.minimum))")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("最小")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack {
                    Text("\(String(format: "%.0f", statistics.maximum))")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("最大")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct CorrelationInsightsCard: View {
    let analysis: ComparisonCorrelationAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundColor(.accentColor)
                Text("相関分析結果")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(analysis.dataTypeA.displayName)
                            .foregroundColor(analysis.dataTypeA.color)
                        Text("×")
                            .foregroundColor(.secondary)
                        Text(analysis.dataTypeB.displayName)
                            .foregroundColor(analysis.dataTypeB.color)
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    
                    Text("相関係数: \(String(format: "%.3f", analysis.correlationCoefficient))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(analysis.strength.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(analysis.strength.color)
                    
                    Text("p < \(String(format: "%.2f", analysis.significance))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Correlation interpretation
            Text(correlationInterpretation)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color.accentColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var correlationInterpretation: String {
        let coefficient = analysis.correlationCoefficient
        let typeA = analysis.dataTypeA.displayName
        let typeB = analysis.dataTypeB.displayName
        
        if coefficient > 0.7 {
            return "\(typeA)と\(typeB)の間に強い正の相関があります。一方が増加すると、もう一方も増加する傾向があります。"
        } else if coefficient > 0.3 {
            return "\(typeA)と\(typeB)の間に中程度の正の相関があります。"
        } else if coefficient > -0.3 {
            return "\(typeA)と\(typeB)の間に明確な相関は見られません。"
        } else if coefficient > -0.7 {
            return "\(typeA)と\(typeB)の間に中程度の負の相関があります。"
        } else {
            return "\(typeA)と\(typeB)の間に強い負の相関があります。一方が増加すると、もう一方は減少する傾向があります。"
        }
    }
}

struct MultiDataTypeSelectorSheet: View {
    @Binding var selectedDataTypes: Set<HealthDataType>
    let onDone: () -> Void
    
    var body: some View {
        NavigationStack {
            List(HealthDataType.allCases, id: \.self) { dataType in
                Button(action: {
                    if selectedDataTypes.contains(dataType) {
                        selectedDataTypes.remove(dataType)
                    } else {
                        selectedDataTypes.insert(dataType)
                    }
                }) {
                    HStack {
                        Image(systemName: dataType.iconName)
                            .font(.title3)
                            .foregroundColor(dataType.color)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dataType.displayName)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("\(dataType.unit)単位")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if selectedDataTypes.contains(dataType) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .navigationTitle("比較データ選択")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了", action: onDone)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Preview

#Preview {
    struct PreviewContainer: View {
        @State private var mockViewModel = TrendsViewModel(
            fetchHealthDataUseCase: MockFetchHealthDataUseCase(),
            trendAnalyzer: MockTrendAnalyzer()
        )
        
        var body: some View {
            NavigationStack {
                MultiDataComparisonView(viewModel: mockViewModel)
            }
        }
    }
    
    return PreviewContainer()
}

// Mock implementations for preview
private struct MockFetchHealthDataUseCase: FetchHealthDataUseCaseProtocol {
    func fetchHealthRecords(for user: User, type: HealthDataType?, dateRange: DateRange?, limit: Int?) async throws -> [HealthRecord] { [] }
    func fetchLatestRecord(for user: User, type: HealthDataType) async throws -> HealthRecord? { nil }
    func fetchRecordsGroupedByDay(for user: User, type: HealthDataType, dateRange: DateRange) async throws -> [Date: [HealthRecord]] { [:] }
    func getHealthDataStatistics(for user: User, type: HealthDataType, dateRange: DateRange) async throws -> HealthDataStatistics {
        HealthDataStatistics(dataType: type, dateRange: dateRange, records: [])
    }
    func searchHealthRecords(for user: User, criteria: HealthDataSearchCriteria) async throws -> [HealthRecord] { [] }
    func exportHealthData(for user: User, format: ExportFormat, dateRange: DateRange?) async throws -> ExportResult {
        ExportResult(format: .json, data: Data(), filename: "test.json", recordCount: 0, userID: user.id)
    }
}

private struct MockTrendAnalyzer: TrendAnalyzerProtocol {
    func analyzeTrends(from records: [any HealthRecordProtocol], timeRange: TimeRange) async throws -> TrendAnalysis {
        TrendAnalysis(dataType: .weight, timeRange: .week, trendPoints: [], direction: .stable, slope: 0.0, correlation: 0.0, anomalies: [], summary: TrendSummary(totalDataPoints: 0, averageValue: 0.0, minimumValue: 0.0, maximumValue: 0.0, standardDeviation: 0.0, changePercentage: 0.0, lastValue: 0.0, firstValue: 0.0), confidence: 0.0)
    }
    func analyzeTrends(from records: [any HealthRecordProtocol], dateRange: DateRange) async throws -> TrendAnalysis {
        TrendAnalysis(dataType: .weight, timeRange: .week, trendPoints: [], direction: .stable, slope: 0.0, correlation: 0.0, anomalies: [], summary: TrendSummary(totalDataPoints: 0, averageValue: 0.0, minimumValue: 0.0, maximumValue: 0.0, standardDeviation: 0.0, changePercentage: 0.0, lastValue: 0.0, firstValue: 0.0), confidence: 0.0)
    }
    // ... other required methods with empty implementations
    func calculateMovingAverage(values: [Double], windowSize: Int) -> [Double] { [] }
    func calculateWeightedMovingAverage(values: [Double], weights: [Double]) -> [Double] { [] }
    func calculateExponentialMovingAverage(values: [Double], alpha: Double) -> [Double] { [] }
    func detectAnomalies(in records: [any HealthRecordProtocol], sensitivity: Double) async throws -> [AnomalyPoint] { [] }
    func detectOutliers(values: [Double], method: OutlierDetectionMethod) -> [Int] { [] }
    func predictTrend(from analysis: TrendAnalysis, daysAhead: Int) async throws -> TrendPrediction {
        TrendPrediction(dataType: .weight, predictedPoints: [], confidence: 0.0, methodology: "mock", validUntil: Date())
    }
    func predictValue(from records: [any HealthRecordProtocol], daysAhead: Int, method: PredictionMethod) async throws -> Double { 0.0 }
    func calculateCorrelation(between firstSeries: [Double], and secondSeries: [Double]) -> Double { 0.0 }
    func calculateLinearRegression(from points: [(x: Double, y: Double)]) -> LinearRegressionResult {
        LinearRegressionResult(slope: 0.0, intercept: 0.0, correlation: 0.0, rSquared: 0.0, standardError: 0.0)
    }
    func calculateVariability(from values: [Double]) -> VariabilityMetrics {
        VariabilityMetrics(variance: 0.0, standardDeviation: 0.0, coefficientOfVariation: 0.0, range: 0.0, interquartileRange: 0.0)
    }
}