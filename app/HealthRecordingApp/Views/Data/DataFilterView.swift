import SwiftUI

struct DataFilterView: View {
    @Binding var isPresented: Bool
    @Binding var selectedDataType: HealthDataType?
    let onApplyFilter: (HealthDataType?) -> Void
    
    @State private var tempSelectedType: HealthDataType?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Filter options
                filterOptionsSection
                
                Spacer()
                
                // Action buttons
                actionButtonsSection
            }
            .padding()
            .navigationTitle("データフィルター")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            tempSelectedType = selectedDataType
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("表示するデータ種別を選択")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("特定の種別のデータのみを表示できます")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Filter Options Section
    
    private var filterOptionsSection: some View {
        VStack(spacing: 16) {
            // All data option
            FilterOptionRow(
                title: "すべてのデータ",
                subtitle: "全種別のデータを表示",
                iconName: "heart.text.square",
                isSelected: tempSelectedType == nil
            ) {
                tempSelectedType = nil
            }
            
            Divider()
            
            // Individual data types
            ForEach([HealthDataType.weight, .steps, .calories, .heartRate, .bloodGlucose], id: \.self) { dataType in
                FilterOptionRow(
                    title: dataType.displayName,
                    subtitle: "\(dataType.displayName)データのみを表示",
                    iconName: dataType.iconName,
                    isSelected: tempSelectedType == dataType
                ) {
                    tempSelectedType = dataType
                }
            }
        }
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: applyFilter) {
                Text("フィルターを適用")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            
            Button(action: clearFilter) {
                Text("フィルターをクリア")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Actions
    
    private func applyFilter() {
        selectedDataType = tempSelectedType
        onApplyFilter(tempSelectedType)
        isPresented = false
    }
    
    private func clearFilter() {
        tempSelectedType = nil
        selectedDataType = nil
        onApplyFilter(nil)
        isPresented = false
    }
}

// MARK: - Filter Option Row

struct FilterOptionRow: View {
    let title: String
    let subtitle: String
    let iconName: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                    .frame(width: 30)
                
                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - HealthDataType Icon Extension

extension HealthDataType {
    var iconName: String {
        switch self {
        case .weight:
            return "scalemass"
        case .steps:
            return "figure.walk"
        case .calories:
            return "flame"
        case .heartRate:
            return "heart"
        case .bloodGlucose:
            return "drop"
        }
    }
}

#Preview {
    DataFilterView(
        isPresented: .constant(true),
        selectedDataType: .constant(nil),
        onApplyFilter: { _ in }
    )
}