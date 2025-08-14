import SwiftUI
import Charts

/// Enhanced comprehensive trends view with advanced data visualization capabilities
/// Integrates detailed statistics, multi-data comparison, and intelligent insights
struct EnhancedTrendsView: View {
    @Bindable var viewModel: TrendsViewModel
    
    @State private var selectedViewMode: TrendViewMode = .single
    @State private var selectedTimeRange: TrendTimeRange = .month
    @State private var selectedDataType: HealthDataType = .weight
    @State private var showingDetailedStats = false
    @State private var showingMultiComparison = false
    @State private var showingCustomPeriod = false
    @State private var showingInsightDetails = false
    @State private var selectedInsight: HealthInsight?
    
    // Chart interaction states
    @State private var selectedDataPoint: ChartDataPoint?
    @State private var chartInteraction: ChartInteractionState = .none
    @State private var highlightedRange: ClosedRange<Date>?
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 20) {
                    // Control panel
                    controlPanelView
                    
                    // Main chart section
                    mainChartSection
                    
                    // Quick statistics cards
                    quickStatisticsSection
                    
                    // Insights section
                    if !viewModel.healthInsights.isEmpty {
                        insightsSection
                    }
                    
                    // Action buttons
                    actionButtonsSection
                }
                .padding()
            }
            .navigationTitle("データトレンド分析")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar(content: {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("詳細統計を表示") {
                            showingDetailedStats = true
                        }
                        
                        Button("データ比較") {
                            showingMultiComparison = true
                        }
                        
                        Divider()
                        
                        Button("カスタム期間") {
                            showingCustomPeriod = true
                        }
                        
                        Button("データエクスポート") {
                            exportTrendData()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .scrollIndicators(.automatic)
            .refreshable {
                await refreshTrendData()
            }
            .sheet(isPresented: $showingDetailedStats) {
                NavigationStack {
                    DetailedStatisticsView(
                        dataType: selectedDataType,
                        chartDataPoints: viewModel.chartDataPoints,
                        timeRange: selectedTimeRange
                    )
                    .toolbar(content: {
                        #if os(iOS)
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("完了") {
                                showingDetailedStats = false
                            }
                        }
                        #else
                        ToolbarItem(placement: .automatic) {
                            Button("完了") {
                                showingDetailedStats = false
                            }
                        }
                        #endif
                    }
                }
            }
            .sheet(isPresented: $showingMultiComparison) {
                NavigationStack {
                    MultiDataComparisonView(viewModel: viewModel)
                        .toolbar(content: {
                            #if os(iOS)
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("完了") {
                                    showingMultiComparison = false
                                }
                            }
                            #else
                            ToolbarItem(placement: .automatic) {
                                Button("完了") {
                                    showingMultiComparison = false
                                }
                            }
                            #endif
                        }
                }
            }
            .sheet(isPresented: $showingCustomPeriod) {
                CustomPeriodSelector(
                    selectedTimeRange: $selectedTimeRange,
                    onApply: { range in
                        selectedTimeRange = range
                        showingCustomPeriod = false
                        Task {
                            await loadTrendData()
                        }
                    },
                    onDismiss: {
                        showingCustomPeriod = false
                    }
                )
            }
            .sheet(item: $selectedInsight) { insight in
                InsightDetailView(
                    insight: insight,
                    onDismiss: {
                        selectedInsight = nil
                    }
                )
            }
            .task {
                await loadTrendData()
            }
            .onChange(of: selectedDataType) { _, _ in
                Task {
                    await loadTrendData()
                }
            }
            .onChange(of: selectedTimeRange) { _, _ in
                Task {
                    await loadTrendData()
                }
            }
        }
    }
    
    // MARK: - Control Panel
    
    private var controlPanelView: some View {
        VStack(spacing: 16) {
            // View mode selector
            viewModeSelector
            
            // Data type and time range selectors
            HStack(spacing: 12) {
                dataTypeSelector
                timeRangeSelector
            }
            
            // Summary metrics bar
            if !viewModel.chartDataPoints.isEmpty {
                summaryMetricsBar
            }
        }
        .padding()
        .background(Color(.controlColor))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var viewModeSelector: some View {
        HStack(spacing: 0) {
            ForEach(TrendViewMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedViewMode = mode
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: mode.iconName)
                            .font(.caption)
                        Text(mode.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(selectedViewMode == mode ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        selectedViewMode == mode ? 
                        Color.accentColor : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private var dataTypeSelector: some View {
        Menu {
            ForEach([HealthDataType.weight, .steps, .calories, .heartRate], id: \.self) { dataType in
                Button(action: {
                    selectedDataType = dataType
                }) {
                    HStack {
                        Image(systemName: dataType.iconName)
                        Text(dataType.displayName)
                        if selectedDataType == dataType {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: selectedDataType.iconName)
                    .foregroundColor(selectedDataType.color)
                Text(selectedDataType.displayName)
                    .fontWeight(.medium)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private var timeRangeSelector: some View {
        Menu {
            ForEach(TrendTimeRange.allCases, id: \.self) { range in
                Button(action: {
                    selectedTimeRange = range
                }) {
                    HStack {
                        Text(range.displayName)
                        if selectedTimeRange == range {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            
            Divider()
            
            Button("カスタム期間...") {
                showingCustomPeriod = true
            }
        } label: {
            HStack {
                Image(systemName: "calendar")
                Text(selectedTimeRange.displayName)
                    .fontWeight(.medium)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private var summaryMetricsBar: some View {
        HStack(spacing: 16) {
            if let latest = viewModel.latestValue {
                QuickMetric(
                    title: "最新",
                    value: formatValue(latest),
                    color: .primary
                )
            }
            
            if let average = viewModel.averageValue {
                QuickMetric(
                    title: "平均",
                    value: formatValue(average),
                    color: .secondary
                )
            }
            
            if let changeRate = viewModel.changeRate {
                QuickMetric(
                    title: "変化率",
                    value: String(format: "%.1f%%", changeRate),
                    color: changeRate >= 0 ? .green : .red
                )
            }
            
            if let confidence = viewModel.trendAnalysis?.confidence {
                QuickMetric(
                    title: "信頼度",
                    value: String(format: "%.0f%%", confidence * 100),
                    color: confidence >= 0.7 ? .green : .orange
                )
            }
        }
    }
    
    // MARK: - Main Chart Section
    
    private var mainChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Chart header
            HStack {
                Text("\(selectedDataType.displayName)トレンド")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if selectedViewMode == .single {
                singleDataChartView
            } else {
                comparisonChartPlaceholder
            }
            
            // Chart interaction info
            if let selectedPoint = selectedDataPoint {
                chartInteractionView(selectedPoint)
            }
        }
        .padding()
        .background(Color(.controlColor))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var singleDataChartView: some View {
        Group {
            if !viewModel.chartDataPoints.isEmpty {
                Chart(viewModel.chartDataPoints) { dataPoint in
                    // Main data line
                    LineMark(
                        x: .value("日時", dataPoint.timestamp),
                        y: .value("値", dataPoint.value)
                    )
                    .foregroundStyle(selectedDataType.color.gradient)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .symbol(.circle)
                    .symbolSize(selectedDataPoint?.timestamp == dataPoint.timestamp ? 60 : 30)
                    
                    // Moving average line
                    if let movingAverage = dataPoint.movingAverage {
                        LineMark(
                            x: .value("日時", dataPoint.timestamp),
                            y: .value("移動平均", movingAverage)
                        )
                        .foregroundStyle(Color.secondary.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    }
                    
                    // Area fill
                    AreaMark(
                        x: .value("日時", dataPoint.timestamp),
                        y: .value("値", dataPoint.value)
                    )
                    .foregroundStyle(
                        selectedDataType.color.opacity(0.1).gradient
                    )
                    
                    // Goal line if applicable
                    if let goalValue = getGoalValue() {
                        RuleMark(y: .value("目標", goalValue))
                            .foregroundStyle(Color.green.opacity(0.7))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [10, 5]))
                    }
                }
                .frame(height: 250)
                .chartBackground { chartProxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                handleChartTap(location: location, geometry: geometry, chartProxy: chartProxy)
                            }
                    }
                }
                .animation(.easeInOut(duration: 0.5), value: viewModel.chartDataPoints)
            } else {
                emptyChartView
            }
        }
    }
    
    private var comparisonChartPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("データ比較モード")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("複数のデータタイプを比較するには\n「データ比較」ボタンをタップしてください")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("データ比較を開く") {
                showingMultiComparison = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(height: 250)
        .frame(maxWidth: .infinity)
    }
    
    private var emptyChartView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("データがありません")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("選択した期間にはデータが記録されていません")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 250)
        .frame(maxWidth: .infinity)
    }
    
    private func chartInteractionView(_ dataPoint: ChartDataPoint) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("選択中のデータポイント")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dataPoint.timestamp, style: .date)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("\(formatValue(dataPoint.value)) \(selectedDataType.unit)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(selectedDataType.color)
                }
                
                Spacer()
                
                if let movingAverage = dataPoint.movingAverage {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("移動平均")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatValue(movingAverage))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Quick Statistics Section
    
    private var quickStatisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("統計サマリー")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("詳細表示") {
                    showingDetailedStats = true
                }
                .font(.subheadline)
                .foregroundColor(.accentColor)
            }
            
            if !viewModel.chartDataPoints.isEmpty {
                StatisticalSummaryCard(
                    dataType: selectedDataType,
                    statistics: calculateStatistics(),
                    timeRange: selectedTimeRange,
                    onTapDetails: {
                        showingDetailedStats = true
                    }
                )
            }
        }
    }
    
    // MARK: - Insights Section
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("インサイト")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(viewModel.healthInsights.count)件")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(viewModel.healthInsights.prefix(3), id: \.id) { insight in
                    InsightCard(
                        insight: insight,
                        onTap: {
                            selectedInsight = insight
                        }
                    )
                }
                
                if viewModel.healthInsights.count > 3 {
                    Button("他\(viewModel.healthInsights.count - 3)件のインサイトを表示") {
                        showingInsightDetails = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                    .padding(.vertical, 8)
                }
            }
        }
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: {
                    showingDetailedStats = true
                }) {
                    ActionButtonContent(
                        icon: "chart.bar.doc.horizontal",
                        title: "詳細統計",
                        subtitle: "分布・外れ値分析"
                    )
                }
                .buttonStyle(ActionButtonStyle())
                
                Button(action: {
                    showingMultiComparison = true
                }) {
                    ActionButtonContent(
                        icon: "chart.bar.xaxis",
                        title: "データ比較",
                        subtitle: "相関・比較分析"
                    )
                }
                .buttonStyle(ActionButtonStyle())
            }
            
            HStack(spacing: 12) {
                Button(action: {
                    showingCustomPeriod = true
                }) {
                    ActionButtonContent(
                        icon: "calendar.badge.clock",
                        title: "期間設定",
                        subtitle: "カスタム期間選択"
                    )
                }
                .buttonStyle(ActionButtonStyle())
                
                Button(action: {
                    exportTrendData()
                }) {
                    ActionButtonContent(
                        icon: "square.and.arrow.up",
                        title: "エクスポート",
                        subtitle: "データ出力・共有"
                    )
                }
                .buttonStyle(ActionButtonStyle())
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleChartTap(location: CGPoint, geometry: GeometryProxy, chartProxy: ChartProxy) {
        // Find the closest data point to the tap location
        // This is a simplified implementation
        if let dataPoint = findClosestDataPoint(to: location, in: geometry) {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDataPoint = dataPoint
            }
        }
    }
    
    private func findClosestDataPoint(to location: CGPoint, in geometry: GeometryProxy) -> ChartDataPoint? {
        // Simplified implementation - in a real app, you'd use chart proxy to convert coordinates
        return viewModel.chartDataPoints.first
    }
    
    private func getGoalValue() -> Double? {
        switch selectedDataType {
        case .weight: return viewModel.targetWeight
        case .steps: return viewModel.dailyStepsGoal
        case .calories: return viewModel.dailyCaloriesGoal
        case .heartRate: return viewModel.restingHeartRate
        default: return nil
        }
    }
    
    private func calculateStatistics() -> StatisticalSummary {
        let values = viewModel.chartDataPoints.map(\.value)
        guard !values.isEmpty else {
            return StatisticalSummary(
                dataType: selectedDataType,
                sampleCount: 0,
                mean: 0,
                median: 0,
                minimum: 0,
                maximum: 0,
                standardDeviation: 0,
                latestValue: 0,
                trendDirection: .stable,
                changePercentage: 0,
                dataCompleteness: 0
            )
        }
        
        let sorted = values.sorted()
        let mean = values.reduce(0, +) / Double(values.count)
        let median = sorted[sorted.count / 2]
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        let standardDeviation = sqrt(variance)
        
        // Calculate trend direction and change percentage
        let firstValue = values.first ?? 0
        let lastValue = values.last ?? 0
        let changePercentage = firstValue != 0 ? ((lastValue - firstValue) / firstValue) * 100 : 0
        
        let trendDirection: TrendDirection
        if abs(changePercentage) < 2 {
            trendDirection = .stable
        } else if changePercentage > 0 {
            trendDirection = .increasing
        } else {
            trendDirection = .decreasing
        }
        
        // Calculate data completeness (simplified)
        let expectedDataPoints = selectedTimeRange == .week ? 7 : selectedTimeRange == .month ? 30 : 90
        let dataCompleteness = min(1.0, Double(values.count) / Double(expectedDataPoints))
        
        return StatisticalSummary(
            dataType: selectedDataType,
            sampleCount: values.count,
            mean: mean,
            median: median,
            minimum: sorted.first ?? 0,
            maximum: sorted.last ?? 0,
            standardDeviation: standardDeviation,
            latestValue: lastValue,
            trendDirection: trendDirection,
            changePercentage: changePercentage,
            dataCompleteness: dataCompleteness
        )
    }
    
    private func formatValue(_ value: Double) -> String {
        switch selectedDataType {
        case .weight:
            return String(format: "%.1f", value)
        case .steps, .calories:
            return String(format: "%.0f", value)
        case .heartRate:
            return String(format: "%.0f", value)
        default:
            return String(format: "%.1f", value)
        }
    }
    
    private func loadTrendData() async {
        await viewModel.loadTrendData()
    }
    
    private func refreshTrendData() async {
        await viewModel.refreshTrendData()
    }
    
    private func exportTrendData() {
        // TODO: Implement data export functionality
        print("Exporting trend data for \(selectedDataType.displayName)")
    }
}

// MARK: - Supporting Views

struct QuickMetric: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

struct ActionButtonContent: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

struct ActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color(.controlColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct InsightCard: View {
    let insight: HealthInsight
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: insight.priority.iconName)
                    .font(.title3)
                    .foregroundColor(insight.priority.color)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(insight.summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(insight.priority.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct InsightDetailView: View {
    let insight: HealthInsight
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 20) {
                    // Insight header
                    HStack {
                        Image(systemName: insight.priority.iconName)
                            .font(.title2)
                            .foregroundColor(insight.priority.color)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(insight.title)
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text(insight.priority.displayName)
                                .font(.subheadline)
                                .foregroundColor(insight.priority.color)
                        }
                        
                        Spacer()
                    }
                    
                    // Insight message
                    Text(insight.summary)
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    // Recommendations if available
                    if !insight.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("推奨事項")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            ForEach(insight.recommendations.prefix(3), id: \.id) { recommendation in
                                Text("• \(recommendation.title)")
                                    .font(.body)
                            }
                        }
                    }
                }
                .padding()
            }
            .scrollIndicators(.automatic)
            .navigationTitle("インサイト詳細")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar(content: {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") {
                        onDismiss()
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("完了") {
                        onDismiss()
                    }
                }
                #endif
            }
        }
    }
}

// MARK: - Extensions




extension InsightPriority {
    var iconName: String {
        switch self {
        case .low: return "info.circle"
        case .medium: return "exclamationmark.triangle"
        case .high: return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        case .informational: return "lightbulb"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        case .critical: return .red
        case .informational: return .green
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .low: return .blue.opacity(0.1)
        case .medium: return .orange.opacity(0.1)
        case .high: return .red.opacity(0.1)
        case .critical: return .red.opacity(0.15)
        case .informational: return .green.opacity(0.1)
        }
    }
    
}

// MARK: - Chart Interaction State

enum ChartInteractionState {
    case none
    case selecting
    case highlighting
}



// MARK: - Previews

// Mock implementation for preview
final class MockFetchHealthDataUseCase: FetchHealthDataUseCaseProtocol {
    func fetchHealthRecords(for user: User, type: HealthDataType?, dateRange: DateRange?, limit: Int?) async throws -> [HealthRecord] {
        return []
    }
    
    func fetchLatestRecord(for user: User, type: HealthDataType) async throws -> HealthRecord? {
        return nil
    }
    
    func fetchRecordsGroupedByDay(for user: User, type: HealthDataType, dateRange: DateRange) async throws -> [Date : [HealthRecord]] {
        return [:]
    }
    
    func getHealthDataStatistics(for user: User, type: HealthDataType, dateRange: DateRange) async throws -> HealthDataStatistics {
        return HealthDataStatistics(dataType: type, dateRange: dateRange, records: [])
    }
    
    func searchHealthRecords(for user: User, criteria: HealthDataSearchCriteria) async throws -> [HealthRecord] {
        return []
    }
    
    func exportHealthData(for user: User, format: ExportFormat, dateRange: DateRange?) async throws -> ExportResult {
        return ExportResult(
            format: format,
            data: Data(),
            filename: "export.json",
            recordCount: 0,
            userID: user.id
        )
    }
}

#Preview("Enhanced Trends View") {
    NavigationStack {
        EnhancedTrendsView(viewModel: TrendsViewModel(
            fetchHealthDataUseCase: MockFetchHealthDataUseCase(),
            trendAnalyzer: TrendAnalyzer(logger: AILogger()),
            logger: AILogger()
        ))
    }
}