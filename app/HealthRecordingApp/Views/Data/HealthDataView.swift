import SwiftUI
import SwiftData

struct HealthDataView: View {
    var viewModel: HealthDataViewModel
    @State private var showingManualInput = false
    @State private var selectedDataType: HealthDataType? = nil
    @State private var showingFilterOptions = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with manual input button
                headerSection
                
                // Data content
                dataContentSection
            }
            .navigationTitle("健康データ")

            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: {
                            showingManualInput = true
                        }) {
                            Label("手動入力", systemImage: "plus.circle")
                        }
                        
                        Button(action: {
                            showingFilterOptions = true
                        }) {
                            Label("フィルター", systemImage: "line.3.horizontal.decrease.circle")
                        }
                        
                        Button(action: {
                            Task {
                                await viewModel.refreshAllData()
                            }
                        }) {
                            Label("更新", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingManualInput) {
                ManualDataInputView(isPresented: $showingManualInput)
            }
            .sheet(isPresented: $showingFilterOptions) {
                DataFilterView(
                    isPresented: $showingFilterOptions,
                    selectedDataType: $selectedDataType,
                    onApplyFilter: { dataType in
                        selectedDataType = dataType
                        Task {
                            if let dataType = dataType {
                                await viewModel.loadHealthRecords(for: dataType)
                            } else {
                                await viewModel.refreshAllData()
                            }
                        }
                    }
                )
            }
        }
        .task {
            await viewModel.refreshAllData()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Quick stats
            quickStatsRow
            
            // Manual input quick access
            manualInputQuickAccess
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
    
    private var quickStatsRow: some View {
        HStack(spacing: 16) {
            ForEach([HealthDataType.weight, .steps, .calories, .heartRate], id: \.self) { dataType in
                QuickStatCard(
                    dataType: dataType,
                    latestRecord: viewModel.getLatestRecord(for: dataType),
                    isLoading: viewModel.isLoading
                )
            }
        }
    }
    
    private var manualInputQuickAccess: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("クイック入力")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                ForEach([HealthDataType.weight, .steps, .calories], id: \.self) { dataType in
                    Button(action: {
                        // Open manual input with pre-selected type
                        showingManualInput = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: dataType.iconName)
                                .font(.subheadline)
                            Text(dataType.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    showingManualInput = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("すべて")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Data Content Section
    
    private var dataContentSection: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewModel.isLoading && viewModel.allHealthRecords.isEmpty {
                    // Loading state
                    ForEach(0..<3, id: \.self) { _ in
                        DataRecordCardSkeleton()
                    }
                } else if viewModel.allHealthRecords.isEmpty {
                    // Empty state
                    emptyStateView
                } else {
                    // Data records
                    dataRecordsSection
                }
            }
            .padding()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("データがありません")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("HealthKitからデータを取得するか、手動でデータを入力してください")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                showingManualInput = true
            }) {
                Text("手動入力を開始")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding(40)
    }
    
    private var dataRecordsSection: some View {
        ForEach(groupedRecords, id: \.key) { dateGroup in
            VStack(alignment: .leading, spacing: 12) {
                // Date header
                Text(dateGroup.key)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .padding(.horizontal)
                
                // Records for this date
                LazyVStack(spacing: 8) {
                    ForEach(dateGroup.value, id: \.id) { record in
                        DataRecordCard(record: record)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var groupedRecords: [(key: String, value: [HealthRecord])] {
        let filteredRecords = selectedDataType == nil 
            ? viewModel.allHealthRecords 
            : viewModel.allHealthRecords.filter { $0.type == selectedDataType }
        
        let grouped = Dictionary(grouping: filteredRecords) { record in
            DateFormatter.dayFormatter.string(from: record.timestamp)
        }
        
        return grouped.sorted { $0.key > $1.key } // Most recent first
    }
}

// MARK: - Quick Stat Card

struct QuickStatCard: View {
    let dataType: HealthDataType
    let latestRecord: HealthRecord?
    let isLoading: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: dataType.iconName)
                .font(.title3)
                .foregroundColor(.blue)
            
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else if let record = latestRecord {
                VStack(spacing: 2) {
                    Text(String(format: dataType == .weight ? "%.1f" : "%.0f", record.value))
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(dataType.unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("--")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            Text(dataType.displayName)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.controlColor))
        .cornerRadius(8)
    }
}

// MARK: - Data Record Card

struct DataRecordCard: View {
    let record: HealthRecord
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: record.type.iconName)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            // Data info
            VStack(alignment: .leading, spacing: 2) {
                Text(record.type.displayName)
                    .font(.headline)
                    .fontWeight(.medium)
                
                HStack {
                    Text(String(format: record.type == .weight ? "%.1f %@" : "%.0f %@", record.value, record.unit))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(DateFormatter.timeFormatter.string(from: record.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Source indicator
            VStack {
                Image(systemName: record.source == .healthKit ? "applewatch" : "hand.point.up")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(record.source == .healthKit ? "自動" : "手動")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.controlColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Data Record Card Skeleton

struct DataRecordCardSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 30, height: 30)
            
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 100, height: 16)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 150, height: 14)
            }
            
            Spacer()
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 20)
        }
        .padding()
        .background(Color(.controlColor))
        .cornerRadius(12)
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Date Formatters

extension DateFormatter {
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()
    
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}



/*
#Preview {
    // Mock view model for preview
    // TODO: Create proper mock classes for preview
    let mockViewModel = HealthDataViewModel(
        fetchHealthDataUseCase: MockFetchHealthDataUseCase(),
        recordHealthDataUseCase: MockRecordHealthDataUseCase(),
        logger: AILogger()
    )
    
    HealthDataView(viewModel: mockViewModel)
}
*/