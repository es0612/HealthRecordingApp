import SwiftUI
import Charts
import Foundation

enum TrendViewMode: CaseIterable {
    case single, comparison
    
    var displayName: String {
        switch self {
        case .single: return "単一チャート"
        case .comparison: return "比較表示"
        }
    }
    
    var iconName: String {
        switch self {
        case .single: return "chart.line.uptrend.xyaxis"
        case .comparison: return "chart.bar.xaxis"
        }
    }
}

struct TrendsView: View {
    @Bindable var viewModel: TrendsViewModel
    @State private var selectedTimeRange: TrendTimeRange = .month
    @State private var selectedDataType: HealthDataType = .weight
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("トレンドビュー")
                    .font(.title)
                Text("データ可視化テスト対応の簡易版")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !viewModel.chartDataPoints.isEmpty {
                    Chart(viewModel.chartDataPoints) { dataPoint in
                        LineMark(
                            x: .value("日時", dataPoint.timestamp),
                            y: .value("値", dataPoint.value)
                        )
                    }
                    .frame(height: 200)
                } else {
                    Text("データなし")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("データトレンド")
        }
        .task {
            await viewModel.loadTrendData()
        }
    }
}

// Preview is disabled due to compilation complexity