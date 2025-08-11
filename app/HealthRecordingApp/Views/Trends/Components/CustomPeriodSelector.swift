import SwiftUI
import Foundation

struct CustomPeriodSelector: View {
    @Binding var selectedTimeRange: TrendTimeRange
    @Binding var customDateRange: DateRange?
    @State private var showingCustomPicker = false
    @State private var tempStartDate = Date()
    @State private var tempEndDate = Date()
    @State private var isCustomMode = false
    
    // Animation state
    @State private var selectedIndex = 0
    @State private var animationOffset: CGFloat = 0
    
    private let presetRanges: [TimeRangePreset] = [
        .init(range: .week, title: "7日間", subtitle: "1週間", icon: "calendar.badge.clock"),
        .init(range: .month, title: "30日間", subtitle: "1ヶ月", icon: "calendar"),
        .init(range: .quarter, title: "90日間", subtitle: "3ヶ月", icon: "calendar.badge.plus"),
        .init(range: .year, title: "365日間", subtitle: "1年間", icon: "calendar.badge.checkmark")
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with title and custom button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("期間選択")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(currentRangeDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingCustomPicker = true
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.plus")
                        Text("カスタム")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundColor(.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal)
            
            // Preset range selector with smooth animation
            presetsScrollView
            
            // Quick access buttons
            quickAccessButtons
        }
        .sheet(isPresented: $showingCustomPicker) {
            CustomDateRangePicker(
                startDate: $tempStartDate,
                endDate: $tempEndDate,
                onSave: { start, end in
                    customDateRange = try? DateRange(startDate: start, endDate: end)
                    isCustomMode = true
                    showingCustomPicker = false
                },
                onCancel: {
                    showingCustomPicker = false
                }
            )
        }
        .onAppear {
            setupInitialState()
        }
    }
    
    // MARK: - Presets Scroll View
    
    private var presetsScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(presetRanges.enumerated()), id: \.offset) { index, preset in
                    PresetRangeCard(
                        preset: preset,
                        isSelected: selectedTimeRange == preset.range && !isCustomMode,
                        onTap: {
                            selectPreset(preset, at: index)
                        }
                    )
                }
                
                // Custom range card (if active)
                if isCustomMode, let customRange = customDateRange {
                    CustomRangeCard(
                        dateRange: customRange,
                        isSelected: true,
                        onTap: {
                            showingCustomPicker = true
                        },
                        onClear: {
                            clearCustomRange()
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Quick Access Buttons
    
    private var quickAccessButtons: some View {
        HStack(spacing: 12) {
            QuickAccessButton(
                title: "今日",
                subtitle: "24時間",
                icon: "sun.max",
                action: {
                    selectQuickRange(.today)
                }
            )
            
            QuickAccessButton(
                title: "昨日",
                subtitle: "前日",
                icon: "moon",
                action: {
                    selectQuickRange(.yesterday)
                }
            )
            
            QuickAccessButton(
                title: "今週",
                subtitle: "週始まり",
                icon: "calendar.badge.clock",
                action: {
                    selectQuickRange(.thisWeek)
                }
            )
            
            QuickAccessButton(
                title: "先週",
                subtitle: "前週",
                icon: "arrow.left.circle",
                action: {
                    selectQuickRange(.lastWeek)
                }
            )
        }
        .padding(.horizontal)
    }
    
    // MARK: - Helper Properties
    
    private var currentRangeDescription: String {
        if isCustomMode, let customRange = customDateRange {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "\(formatter.string(from: customRange.startDate)) - \(formatter.string(from: customRange.endDate))"
        }
        
        let now = Date()
        let calendar = Calendar.current
        
        switch selectedTimeRange {
        case .week:
            return "過去7日間"
        case .month:
            return "過去30日間"
        case .quarter:
            return "過去90日間"
        case .year:
            return "過去365日間"
        }
    }
    
    // MARK: - Actions
    
    private func setupInitialState() {
        selectedIndex = presetRanges.firstIndex { $0.range == selectedTimeRange } ?? 0
    }
    
    private func selectPreset(_ preset: TimeRangePreset, at index: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedTimeRange = preset.range
            selectedIndex = index
            isCustomMode = false
            customDateRange = nil
        }
        
        // Haptic feedback
        #if os(iOS)
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        #endif
    }
    
    private func selectQuickRange(_ quickRange: QuickRangeType) {
        let calendar = Calendar.current
        let now = Date()
        
        do {
            let range: DateRange
            
            switch quickRange {
            case .today:
                let startOfDay = calendar.startOfDay(for: now)
                range = try DateRange(startDate: startOfDay, endDate: now)
            case .yesterday:
                let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
                let startOfYesterday = calendar.startOfDay(for: yesterday)
                let endOfYesterday = calendar.date(byAdding: .day, value: 1, to: startOfYesterday)?.addingTimeInterval(-1) ?? yesterday
                range = try DateRange(startDate: startOfYesterday, endDate: endOfYesterday)
            case .thisWeek:
                let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                range = try DateRange(startDate: startOfWeek, endDate: now)
            case .lastWeek:
                let lastWeekDate = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
                let lastWeekInterval = calendar.dateInterval(of: .weekOfYear, for: lastWeekDate)
                let startOfLastWeek = lastWeekInterval?.start ?? now
                let endOfLastWeek = lastWeekInterval?.end.addingTimeInterval(-1) ?? now
                range = try DateRange(startDate: startOfLastWeek, endDate: endOfLastWeek)
            }
            
            withAnimation(.easeInOut(duration: 0.3)) {
                customDateRange = range
                isCustomMode = true
            }
            
        } catch {
            print("Error creating quick range: \(error)")
        }
    }
    
    private func clearCustomRange() {
        withAnimation(.easeInOut(duration: 0.3)) {
            customDateRange = nil
            isCustomMode = false
            selectedTimeRange = .month // Default fallback
        }
    }
}

// MARK: - Supporting Types

struct TimeRangePreset {
    let range: TrendTimeRange
    let title: String
    let subtitle: String
    let icon: String
}

enum QuickRangeType {
    case today, yesterday, thisWeek, lastWeek
}

// MARK: - Preset Range Card

struct PresetRangeCard: View {
    let preset: TimeRangePreset
    let isSelected: Bool
    let onTap: () -> Void
    
    private var backgroundColorUnselected: Color {
        #if os(iOS)
        return Color(.systemGray6)
        #else
        return Color.gray.opacity(0.1)
        #endif
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: preset.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .accentColor)
                
                VStack(spacing: 2) {
                    Text(preset.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(preset.subtitle)
                        .font(.caption2)
                        .opacity(0.8)
                }
                .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: 80, height: 90)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor : backgroundColorUnselected)
                    .shadow(
                        color: isSelected ? Color.accentColor.opacity(0.3) : Color.black.opacity(0.1),
                        radius: isSelected ? 6 : 2,
                        x: 0,
                        y: isSelected ? 3 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Custom Range Card

struct CustomRangeCard: View {
    let dateRange: DateRange
    let isSelected: Bool
    let onTap: () -> Void
    let onClear: () -> Void
    
    private var dayCount: Int {
        dateRange.dayCount
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title3)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                VStack(spacing: 2) {
                    Text("カスタム")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("\(dayCount)日間")
                        .font(.caption2)
                        .opacity(0.8)
                }
                .foregroundColor(.white)
            }
            .frame(width: 80, height: 90)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .shadow(color: .purple.opacity(0.3), radius: 6, x: 0, y: 3)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Quick Access Button

struct QuickAccessButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    
    private var backgroundColorSecondary: Color {
        #if os(iOS)
        return Color(.systemGray6)
        #else
        return Color.gray.opacity(0.1)
        #endif
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(backgroundColorSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Custom Date Range Picker

struct CustomDateRangePicker: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let onSave: (Date, Date) -> Void
    let onCancel: () -> Void
    
    @State private var tempStartDate: Date
    @State private var tempEndDate: Date
    @State private var showingValidationError = false
    @State private var validationMessage = ""
    
    private var backgroundColorTertiary: Color {
        #if os(iOS)
        return Color(.systemGray6)
        #else
        return Color.gray.opacity(0.1)
        #endif
    }
    
    init(startDate: Binding<Date>, endDate: Binding<Date>, onSave: @escaping (Date, Date) -> Void, onCancel: @escaping () -> Void) {
        self._startDate = startDate
        self._endDate = endDate
        self.onSave = onSave
        self.onCancel = onCancel
        
        // Initialize temp dates
        self._tempStartDate = State(initialValue: startDate.wrappedValue)
        self._tempEndDate = State(initialValue: endDate.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Date pickers
                VStack(spacing: 16) {
                    DatePicker(
                        "開始日",
                        selection: $tempStartDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    
                    Divider()
                    
                    DatePicker(
                        "終了日",
                        selection: $tempEndDate,
                        in: tempStartDate...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                }
                
                // Validation error
                if showingValidationError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal)
                }
                
                // Range info
                rangeInfoView
                
                Spacer()
            }
            .padding()
            .navigationTitle("期間をカスタム")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: onCancel)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: saveSelection)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }
    
    private var rangeInfoView: some View {
        let dayCount = Calendar.current.dateComponents([.day], from: tempStartDate, to: tempEndDate).day ?? 0
        
        return VStack(spacing: 8) {
            Text("選択した期間")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("\(dayCount + 1)日間")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.accentColor)
            
            HStack {
                Text(formatDate(tempStartDate))
                Text("〜")
                    .foregroundColor(.secondary)
                Text(formatDate(tempEndDate))
            }
            .font(.subheadline)
        }
        .padding()
        .background(backgroundColorTertiary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func saveSelection() {
        if tempStartDate > tempEndDate {
            showValidationError("開始日は終了日より前に設定してください")
            return
        }
        
        let dayCount = Calendar.current.dateComponents([.day], from: tempStartDate, to: tempEndDate).day ?? 0
        if dayCount > 365 {
            showValidationError("期間は365日以内に設定してください")
            return
        }
        
        onSave(tempStartDate, tempEndDate)
    }
    
    private func showValidationError(_ message: String) {
        validationMessage = message
        withAnimation {
            showingValidationError = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showingValidationError = false
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    struct PreviewContainer: View {
        @State private var selectedTimeRange: TrendTimeRange = .month
        @State private var customDateRange: DateRange?
        
        var body: some View {
            CustomPeriodSelector(
                selectedTimeRange: $selectedTimeRange,
                customDateRange: $customDateRange
            )
            .padding()
        }
    }
    
    return PreviewContainer()
}