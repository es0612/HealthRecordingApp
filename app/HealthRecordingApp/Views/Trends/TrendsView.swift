import SwiftUI
import Charts
import Foundation

struct TrendsView: View {
    @Bindable var viewModel: TrendsViewModel
    @State private var selectedTimeRange: TrendTimeRange = .month
    @State private var selectedDataType: HealthDataType = .weight
    @State private var showingDataTypeSelector = false
    @State private var selectedDataPoint: ChartDataPoint?
    @State private var chartInteractionEnabled = true
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with controls
                trendsHeaderView
                
                // Main chart area
                if viewModel.hasData {
                    chartContainerView
                } else {
                    emptyStateView
                }
                
                // Statistics summary
                if !viewModel.chartDataPoints.isEmpty {
                    statisticsView
                }
                
                Spacer()
            }
            .navigationTitle("データトレンド")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("更新") {
                        Task {
                            await viewModel.refreshTrendData()
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.refreshTrendData()
            }
            .sheet(isPresented: $showingDataTypeSelector) {
                dataTypeSelectorSheet
            }
        }
        .task {
            await viewModel.loadTrendData()
        }
        .onChange(of: selectedTimeRange) { _, newRange in
            viewModel.updateTimeRange(newRange)
        }
        .onChange(of: selectedDataType) { _, newType in
            viewModel.updateDataType(newType)
        }
    }
    
    // MARK: - Header View
    
    private var trendsHeaderView: some View {
        VStack(spacing: 12) {
            // Time range selector
            timeRangeSelector
            
            // Data type selector button
            dataTypeButton
            
            // Current data info
            currentDataInfo
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
        .background(Color(.controlColor).opacity(0.1))
    }
    
    private var timeRangeSelector: some View {
        HStack(spacing: 0) {
            ForEach(TrendTimeRange.allCases, id: \.self) { range in
                Button(action: {
                    selectedTimeRange = range
                }) {
                    Text(range.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            selectedTimeRange == range ? 
                            Color.accentColor : Color.clear
                        )
                        .foregroundColor(
                            selectedTimeRange == range ? 
                            .white : .primary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var dataTypeButton: some View {
        Button(action: {
            showingDataTypeSelector = true
        }) {
            HStack {
                Image(systemName: selectedDataType.iconName)
                    .font(.title3)
                    .foregroundColor(selectedDataType.color)
                
                Text(selectedDataType.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(selectedDataType.unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var currentDataInfo: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("最新値")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let latestValue = viewModel.latestValue {
                    Text("\(formatValue(latestValue, for: selectedDataType)) \(selectedDataType.unit)")
                        .font(.title3)
                        .fontWeight(.semibold)
                } else {
                    Text("データなし")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("トレンド")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let trend = viewModel.latestTrend {
                    HStack(spacing: 4) {
                        Image(systemName: trend.iconName)
                            .foregroundColor(trend.color)
                        Text(trend.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(trend.color)
                    }
                } else {
                    Text("不明")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Chart Views
    
    private var chartContainerView: some View {
        VStack(spacing: 16) {
            // Main chart
            chartView
            
            // Chart interaction info
            if let selectedPoint = selectedDataPoint {
                selectedDataPointView(selectedPoint)
            }
        }
        .padding(.horizontal)
    }
    
    private var chartView: some View {
        Chart(viewModel.chartDataPoints) { dataPoint in
            // Specialized chart rendering based on data type
            switch selectedDataType {
            case .weight:
                weightChartMarks(for: dataPoint)
            case .steps:
                stepsChartMarks(for: dataPoint)
            case .calories:
                caloriesChartMarks(for: dataPoint)
            case .heartRate:
                heartRateChartMarks(for: dataPoint)
            case .bloodGlucose:
                bloodGlucoseChartMarks(for: dataPoint)
            }
            
            // Common moving average line (if available)
            if let movingAverage = dataPoint.movingAverage {
                LineMark(
                    x: .value("日時", dataPoint.timestamp),
                    y: .value("平均", movingAverage)
                )
                .foregroundStyle(.orange)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
            }
        }
        .frame(height: chartHeight)
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine()
                AxisValueLabel(format: dateAxisFormat)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                AxisValueLabel(format: valueAxisFormat)
            }
        }
        .apply { view in
            if let domain = yAxisDomain {
                view.chartYScale(domain: domain)
            } else {
                view
            }
        }
        .chartXSelection(value: .constant(nil as Date?))
        .chartAngleSelection(value: .constant(nil as Double?))
        .chartBackground { chartProxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if chartInteractionEnabled {
                                    handleChartInteraction(at: value.location, in: geometry, chartProxy: chartProxy)
                                }
                            }
                    )
            }
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private func selectedDataPointView(_ dataPoint: ChartDataPoint) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("選択されたデータ")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("閉じる") {
                    selectedDataPoint = nil
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("値")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(formatValue(dataPoint.value, for: selectedDataType)) \(selectedDataType.unit)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("日時")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatDate(dataPoint.timestamp))
                        .font(.subheadline)
                }
                
                if let movingAverage = dataPoint.movingAverage {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("移動平均")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(formatValue(movingAverage, for: selectedDataType)) \(selectedDataType.unit)")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.controlColor).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Statistics View
    
    private var statisticsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("統計情報")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                statisticCard(title: "平均値", value: viewModel.averageValue, unit: selectedDataType.unit)
                statisticCard(title: "最高値", value: viewModel.maximumValue, unit: selectedDataType.unit)
                statisticCard(title: "最低値", value: viewModel.minimumValue, unit: selectedDataType.unit)
                statisticCard(title: "データ数", value: Double(viewModel.chartDataPoints.count), unit: "個")
            }
            
            if let changeRate = viewModel.changeRate {
                changeRateView(changeRate)
            }
            
            // Data type-specific performance insights
            performanceInsightsView
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
        .background(Color(.controlColor).opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
    
    // MARK: - Performance Insights View
    
    private var performanceInsightsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("パフォーマンス分析")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                // Progress towards goal
                insightCard(
                    title: "目標達成率",
                    value: "\(String(format: "%.0f", viewModel.progressPercentage))%",
                    color: progressColor
                )
                
                // Current streak
                insightCard(
                    title: "現在のストリーク",
                    value: "\(viewModel.streakCount)日",
                    color: streakColor
                )
                
                // Weekly trend
                insightCard(
                    title: "週間トレンド",
                    value: viewModel.weeklyPerformanceTrend.displayName,
                    color: viewModel.weeklyPerformanceTrend.color
                )
                
                // Best streak
                insightCard(
                    title: "最長ストリーク",
                    value: "\(viewModel.bestStreak)日",
                    color: .blue
                )
            }
            
            // Data type-specific insights
            dataTypeSpecificInsights
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
        .background(Color(.controlColor).opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
    
    private var dataTypeSpecificInsights: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch selectedDataType {
            case .weight:
                weightSpecificInsights
            case .steps:
                stepsSpecificInsights
            case .calories:
                caloriesSpecificInsights
            case .heartRate:
                heartRateSpecificInsights
            case .bloodGlucose:
                bloodGlucoseSpecificInsights
            }
        }
    }
    
    @ViewBuilder
    private var weightSpecificInsights: some View {
        HStack {
            Image(systemName: "scalemass")
                .foregroundColor(.purple)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("目標体重まで")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let target = viewModel.targetWeight, let current = viewModel.latestValue {
                    let difference = abs(current - target)
                    Text("\(String(format: "%.1f", difference))kg")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(current > target ? .red : .green)
                } else {
                    Text("目標未設定")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(viewModel.isAboveTarget ? "目標超過" : viewModel.isBelowTarget ? "目標未達" : "目標範囲内")
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (viewModel.isAboveTarget ? Color.red : viewModel.isBelowTarget ? Color.orange : Color.green).opacity(0.2)
                )
                .foregroundColor(
                    viewModel.isAboveTarget ? .red : viewModel.isBelowTarget ? .orange : .green
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    @ViewBuilder
    private var stepsSpecificInsights: some View {
        HStack {
            Image(systemName: "figure.walk")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("今日の歩数")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let current = viewModel.latestValue {
                    Text("\(Int(current))歩")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                } else {
                    Text("データなし")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let goal = viewModel.dailyStepsGoal, let current = viewModel.latestValue {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("目標達成")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(current >= goal ? "✓" : "\(Int(goal - current))歩不足")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(current >= goal ? .green : .orange)
                }
            }
        }
    }
    
    @ViewBuilder
    private var caloriesSpecificInsights: some View {
        HStack {
            Image(systemName: "flame")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("消費カロリー")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let current = viewModel.latestValue {
                    Text("\(Int(current))kcal")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                } else {
                    Text("データなし")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(viewModel.isAboveTarget ? "目標超過" : viewModel.isBelowTarget ? "目標未達" : "目標範囲内")
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (viewModel.isAboveTarget ? Color.green : viewModel.isBelowTarget ? Color.red : Color.blue).opacity(0.2)
                )
                .foregroundColor(
                    viewModel.isAboveTarget ? .green : viewModel.isBelowTarget ? .red : .blue
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    @ViewBuilder
    private var heartRateSpecificInsights: some View {
        HStack {
            Image(systemName: "heart")
                .foregroundColor(.red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("平均心拍数")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let average = viewModel.averageValue {
                    Text("\(Int(average)) bpm")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(heartRateZoneColor(for: average))
                } else {
                    Text("データなし")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let average = viewModel.averageValue {
                Text(heartRateZoneName(for: average))
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(heartRateZoneColor(for: average).opacity(0.2))
                    .foregroundColor(heartRateZoneColor(for: average))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    @ViewBuilder
    private var bloodGlucoseSpecificInsights: some View {
        HStack {
            Image(systemName: "drop")
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("血糖値状態")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let current = viewModel.latestValue {
                    Text(bloodGlucoseStatus(for: current))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(bloodGlucoseColor(for: current))
                } else {
                    Text("データなし")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let current = viewModel.latestValue {
                Text("\(Int(current)) mg/dL")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(bloodGlucoseColor(for: current).opacity(0.2))
                    .foregroundColor(bloodGlucoseColor(for: current))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    private func insightCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(color)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Helper Properties and Methods
    
    private var progressColor: Color {
        let progress = viewModel.progressPercentage
        if progress >= 90 { return .green }
        if progress >= 70 { return .orange }
        return .red
    }
    
    private var streakColor: Color {
        let streak = viewModel.streakCount
        if streak >= 7 { return .green }
        if streak >= 3 { return .orange }
        return .gray
    }
    
    private func heartRateZoneColor(for bpm: Double) -> Color {
        switch bpm {
        case 0..<70: return .blue
        case 70..<130: return .green
        case 130..<160: return .orange
        case 160...: return .red
        default: return .gray
        }
    }
    
    private func heartRateZoneName(for bpm: Double) -> String {
        switch bpm {
        case 0..<70: return "安静"
        case 70..<130: return "脂肪燃焼"
        case 130..<160: return "有酸素"
        case 160...: return "ピーク"
        default: return "不明"
        }
    }
    
    private func bloodGlucoseStatus(for value: Double) -> String {
        switch value {
        case 0..<70: return "低血糖"
        case 70..<100: return "正常"
        case 100..<126: return "境界型"
        case 126...: return "高血糖"
        default: return "不明"
        }
    }
    
    private func bloodGlucoseColor(for value: Double) -> Color {
        switch value {
        case 0..<70: return .red
        case 70..<100: return .green
        case 100..<126: return .orange
        case 126...: return .red
        default: return .gray
        }
    }
    }
    
    private func statisticCard(title: String, value: Double?, unit: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let value = value {
                Text("\(formatValue(value, for: selectedDataType))\(unit)")
                    .font(.headline)
                    .fontWeight(.semibold)
            } else {
                Text("--")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func changeRateView(_ changeRate: Double) -> some View {
        HStack {
            Image(systemName: changeRate >= 0 ? "arrow.up.right" : "arrow.down.right")
                .foregroundColor(changeRate >= 0 ? .green : .red)
            
            Text("変化率: \(changeRate >= 0 ? "+" : "")\(String(format: "%.1f", changeRate))%")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(changeRate >= 0 ? .green : .red)
            
            Spacer()
            
            Text("対\(selectedTimeRange.displayName)開始時")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("データが不足しています")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("トレンドを表示するには、少なくとも2つ以上のデータポイントが必要です")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("データを追加") {
                // Navigate to manual data input
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Data Type Selector Sheet
    
    private var dataTypeSelectorSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List(HealthDataType.allCases, id: \.self) { dataType in
                    Button(action: {
                        selectedDataType = dataType
                        showingDataTypeSelector = false
                    }) {
                        HStack(spacing: 16) {
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
                            
                            if dataType == selectedDataType {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("データタイプ選択")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        showingDataTypeSelector = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    // MARK: - Chart Configuration Properties
    
    private var chartHeight: CGFloat {
        switch selectedDataType {
        case .weight, .bloodGlucose: return 300
        case .steps: return 350
        case .calories: return 320
        case .heartRate: return 280
        }
    }
    
    private var dateAxisFormat: Date.FormatStyle {
        switch selectedTimeRange {
        case .week: return .dateTime.weekday(.abbreviated)
        case .month: return .dateTime.day().month(.abbreviated)
        case .quarter, .year: return .dateTime.month(.abbreviated)
        }
    }
    
    private var valueAxisFormat: FloatingPointFormatStyle<Double> {
        switch selectedDataType {
        case .weight, .bloodGlucose: return .number.precision(.fractionLength(1))
        case .steps, .calories: return .number.precision(.fractionLength(0))
        case .heartRate: return .number.precision(.fractionLength(0))
        }
    }
    
    private var yAxisDomain: ClosedRange<Double>? {
        guard !viewModel.chartDataPoints.isEmpty else { return nil }
        
        let values = viewModel.chartDataPoints.map(\.value)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 100
        let padding = (maxValue - minValue) * 0.1
        
        switch selectedDataType {
        case .weight:
            return max(minValue - padding, 40)...(maxValue + padding)
        case .steps:
            return 0...max(maxValue + padding, 15000)
        case .calories:
            return 0...max(maxValue + padding, 3000)
        case .heartRate:
            return max(minValue - padding, 40)...min(maxValue + padding, 220)
        case .bloodGlucose:
            return max(minValue - padding, 70)...min(maxValue + padding, 200)
        }
    }
    
    // MARK: - Specialized Chart Marks
    
    @ChartContentBuilder
    private func weightChartMarks(for dataPoint: ChartDataPoint) -> some ChartContent {
        // Main weight trend line
        LineMark(
            x: .value("日時", dataPoint.timestamp),
            y: .value("体重", dataPoint.value)
        )
        .foregroundStyle(.purple.gradient)
        .lineStyle(StrokeStyle(lineWidth: 3))
        .interpolationMethod(.catmullRom)
        
        // Weight area with gradient
        AreaMark(
            x: .value("日時", dataPoint.timestamp),
            y: .value("体重", dataPoint.value)
        )
        .foregroundStyle(
            LinearGradient(
                colors: [.purple.opacity(0.3), .purple.opacity(0.1), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .interpolationMethod(.catmullRom)
        
        // Data points with weight-specific styling
        PointMark(
            x: .value("日時", dataPoint.timestamp),
            y: .value("体重", dataPoint.value)
        )
        .foregroundStyle(.purple)
        .symbolSize(dataPoint.isSelected ? 100 : 50)
        .symbol(.circle)
        
        // Target weight reference line (if available)
        if let targetWeight = getTargetWeight() {
            RuleMark(y: .value("目標体重", targetWeight))
                .foregroundStyle(.green.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [10, 5]))
                .annotation(position: .topTrailing) {
                    Text("目標: \(String(format: "%.1f", targetWeight))kg")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
        }
    }
    
    @ChartContentBuilder
    private func stepsChartMarks(for dataPoint: ChartDataPoint) -> some ChartContent {
        // Steps bar chart
        BarMark(
            x: .value("日時", dataPoint.timestamp),
            y: .value("歩数", dataPoint.value)
        )
        .foregroundStyle(
            LinearGradient(
                colors: [.blue, .blue.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(4)
        
        // Steps trend line overlay
        LineMark(
            x: .value("日時", dataPoint.timestamp),
            y: .value("歩数", dataPoint.value)
        )
        .foregroundStyle(.blue)
        .lineStyle(StrokeStyle(lineWidth: 2))
        .interpolationMethod(.cardinal)
        
        // Daily goal reference line
        if let dailyStepsGoal = getDailyStepsGoal() {
            RuleMark(y: .value("目標歩数", dailyStepsGoal))
                .foregroundStyle(.green.opacity(0.8))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [8, 4]))
                .annotation(position: .topLeading) {
                    Text("目標: \(Int(dailyStepsGoal))歩")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
        }
    }
    
    @ChartContentBuilder
    private func caloriesChartMarks(for dataPoint: ChartDataPoint) -> some ChartContent {
        // Calories area chart
        AreaMark(
            x: .value("日時", dataPoint.timestamp),
            y: .value("カロリー", dataPoint.value)
        )
        .foregroundStyle(
            LinearGradient(
                colors: [.orange.opacity(0.8), .orange.opacity(0.3), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .interpolationMethod(.cardinal)
        
        // Calories trend line
        LineMark(
            x: .value("日時", dataPoint.timestamp),
            y: .value("カロリー", dataPoint.value)
        )
        .foregroundStyle(.orange)
        .lineStyle(StrokeStyle(lineWidth: 3))
        .interpolationMethod(.cardinal)
        
        // Data points with calorie-specific styling
        PointMark(
            x: .value("日時", dataPoint.timestamp),
            y: .value("カロリー", dataPoint.value)
        )
        .foregroundStyle(.orange)
        .symbolSize(dataPoint.isSelected ? 80 : 35)
        .symbol(.circle)
        
        // Calorie goal reference
        if let calorieGoal = getCalorieGoal() {
            RuleMark(y: .value("目標カロリー", calorieGoal))
                .foregroundStyle(.red.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 3]))
                .annotation(position: .topTrailing) {
                    Text("目標: \(Int(calorieGoal))kcal")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
        }
    }
    
    @ChartContentBuilder
    private func heartRateChartMarks(for dataPoint: ChartDataPoint) -> some ChartContent {
        // Heart rate line with zones
        LineMark(
            x: .value("日時", dataPoint.timestamp),
            y: .value("心拍数", dataPoint.value)
        )
        .foregroundStyle(heartRateColor(for: dataPoint.value))
        .lineStyle(StrokeStyle(lineWidth: 3))
        .interpolationMethod(.cardinal)
        
        // Heart rate area with zone colors
        AreaMark(
            x: .value("日時", dataPoint.timestamp),
            y: .value("心拍数", dataPoint.value)
        )
        .foregroundStyle(
            LinearGradient(
                colors: [
                    heartRateColor(for: dataPoint.value).opacity(0.4),
                    heartRateColor(for: dataPoint.value).opacity(0.1),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .interpolationMethod(.cardinal)
        
        // Heart rate data points
        PointMark(
            x: .value("日時", dataPoint.timestamp),
            y: .value("心拍数", dataPoint.value)
        )
        .foregroundStyle(heartRateColor(for: dataPoint.value))
        .symbolSize(dataPoint.isSelected ? 90 : 45)
        .symbol(.circle)
        
        // Heart rate zones
        heartRateZones
    }
    
    @ChartContentBuilder
    private func bloodGlucoseChartMarks(for dataPoint: ChartDataPoint) -> some ChartContent {
        // Blood glucose line
        LineMark(
            x: .value("日時", dataPoint.timestamp),
            y: .value("血糖値", dataPoint.value)
        )
        .foregroundStyle(.green.gradient)
        .lineStyle(StrokeStyle(lineWidth: 3))
        .interpolationMethod(.catmullRom)
        
        // Blood glucose area
        AreaMark(
            x: .value("日時", dataPoint.timestamp),
            y: .value("血糖値", dataPoint.value)
        )
        .foregroundStyle(
            LinearGradient(
                colors: [.green.opacity(0.3), .green.opacity(0.1), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .interpolationMethod(.catmullRom)
        
        // Data points
        PointMark(
            x: .value("日時", dataPoint.timestamp),
            y: .value("血糖値", dataPoint.value)
        )
        .foregroundStyle(.green)
        .symbolSize(dataPoint.isSelected ? 80 : 40)
        
        // Normal range indicators
        bloodGlucoseNormalRange
    }
    
    // MARK: - Chart Helper Views
    
    @ChartContentBuilder
    private var heartRateZones: some ChartContent {
        // Resting zone (50-70 bpm)
        RectangleMark(
            yStart: .value("安静", 50),
            yEnd: .value("安静", 70)
        )
        .foregroundStyle(.blue.opacity(0.1))
        .annotation(position: .topLeading) {
            Text("安静")
                .font(.caption2)
                .foregroundColor(.blue)
        }
        
        // Fat burn zone (70-130 bpm)
        RectangleMark(
            yStart: .value("脂肪燃焼", 70),
            yEnd: .value("脂肪燃焼", 130)
        )
        .foregroundStyle(.green.opacity(0.08))
        .annotation(position: .topLeading) {
            Text("脂肪燃焼")
                .font(.caption2)
                .foregroundColor(.green)
        }
        
        // Cardio zone (130-160 bpm)
        RectangleMark(
            yStart: .value("有酸素", 130),
            yEnd: .value("有酸素", 160)
        )
        .foregroundStyle(.orange.opacity(0.08))
        .annotation(position: .topLeading) {
            Text("有酸素")
                .font(.caption2)
                .foregroundColor(.orange)
        }
        
        // Peak zone (160+ bpm)
        RectangleMark(
            yStart: .value("ピーク", 160),
            yEnd: .value("ピーク", 200)
        )
        .foregroundStyle(.red.opacity(0.08))
        .annotation(position: .topLeading) {
            Text("ピーク")
                .font(.caption2)
                .foregroundColor(.red)
        }
    }
    
    @ChartContentBuilder
    private var bloodGlucoseNormalRange: some ChartContent {
        // Normal range (80-100 mg/dL)
        RectangleMark(
            yStart: .value("正常範囲下限", 80),
            yEnd: .value("正常範囲上限", 100)
        )
        .foregroundStyle(.green.opacity(0.1))
        .annotation(position: .topTrailing) {
            Text("正常範囲")
                .font(.caption2)
                .foregroundColor(.green)
        }
        
        // Warning lines
        RuleMark(y: .value("低血糖", 70))
            .foregroundStyle(.red.opacity(0.6))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 2]))
        
        RuleMark(y: .value("高血糖", 140))
            .foregroundStyle(.red.opacity(0.6))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 2]))
    }
    
    // MARK: - Helper Methods for Chart Configuration
    
    private func heartRateColor(for bpm: Double) -> Color {
        switch bpm {
        case 0..<70: return .blue
        case 70..<130: return .green
        case 130..<160: return .orange
        case 160...: return .red
        default: return .gray
        }
    }
    
    private func getTargetWeight() -> Double? {
        // TODO: Get from user's goal settings
        return 70.0 // Mock target weight
    }
    
    private func getDailyStepsGoal() -> Double? {
        // TODO: Get from user's goal settings
        return 10000 // Mock daily steps goal
    }
    
    private func getCalorieGoal() -> Double? {
        // TODO: Get from user's goal settings
        return 2200 // Mock calorie goal
    }
    
    private func handleChartInteraction(at location: CGPoint, in geometry: GeometryProxy, chartProxy: ChartProxy) {
        // Implementation for chart interaction
        guard let plotFrame = chartProxy.plotFrame else { return }
        let frame = geometry[plotFrame]
        let origin = geometry[plotFrame].origin
        
        // Calculate the relative position in the plot area
        let relativeX = location.x - origin.x
        let _ = location.y - origin.y
        
        // Find the closest data point
        if let closestPoint = findClosestDataPoint(at: relativeX, in: frame) {
            self.selectedDataPoint = closestPoint
        }
    }
    
    private func findClosestDataPoint(at x: CGFloat, in frame: CGRect) -> ChartDataPoint? {
        let dataPoints = self.viewModel.chartDataPoints
        guard !dataPoints.isEmpty else { return nil }
        
        // Simplified implementation - in reality you'd need to map chart coordinates
        let index = Int((x / frame.width) * CGFloat(dataPoints.count - 1))
        let clampedIndex = max(0, min(index, dataPoints.count - 1))
        
        return dataPoints[clampedIndex]
    }
    
    private func formatValue(_ value: Double, for dataType: HealthDataType) -> String {
        switch dataType {
        case .weight, .bloodGlucose:
            return String(format: "%.1f", value)
        case .steps, .calories, .heartRate:
            return String(format: "%.0f", value)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

// MARK: - Extensions

extension HealthDataType {
    var color: Color {
        switch self {
        case .weight: return .purple
        case .steps: return .blue
        case .calories: return .orange
        case .heartRate: return .red
        case .bloodGlucose: return .green
        }
    }
}

extension TrendDirection {
    var iconName: String {
        switch self {
        case .increasing: return "arrow.up.right"
        case .decreasing: return "arrow.down.right"
        case .stable: return "arrow.right"
        case .volatile: return "arrow.up.and.down"
        }
    }
    
    var displayName: String {
        switch self {
        case .increasing: return "上昇"
        case .decreasing: return "下降"
        case .stable: return "安定"
        case .volatile: return "変動"
        }
    }
    
    var color: Color {
        switch self {
        case .increasing: return .green
        case .decreasing: return .red
        case .stable: return .blue
        case .volatile: return .orange
        }
    }
}

// TrendTimeRange.displayName is already defined in TrendAnalysis.swift

// MARK: - View Extensions

extension View {
    func apply<V: View>(@ViewBuilder transform: (Self) -> V) -> V {
        transform(self)
    }
}

// MARK: - Preview

/*
#Preview {
    let mockViewModel = TrendsViewModel(
        fetchHealthDataUseCase: MockFetchHealthDataUseCase(),
        trendAnalyzer: MockTrendAnalyzer()
    )
    
    TrendsView(viewModel: mockViewModel)
}
*/