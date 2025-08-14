import SwiftUI

/// Interactive button for creating new goals with comprehensive goal creation flow
/// Integrates with GoalsViewModel for seamless goal management
struct CreateGoalButton: View {
    let onGoalCreated: () -> Void
    
    @State private var showingGoalCreation = false
    @State private var selectedGoalType: HealthDataType = .weight
    @State private var showingTypeSelection = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Main create button
            Button(action: {
                showingTypeSelection = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("新しい目標を作成")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("健康管理を始めましょう")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(ScaleButtonStyle())
            
            // Quick action buttons
            quickActionButtons
        }
        .sheet(isPresented: $showingTypeSelection) {
            GoalTypeSelectionView(
                onTypeSelected: { goalType in
                    selectedGoalType = goalType
                    showingTypeSelection = false
                    showingGoalCreation = true
                },
                onDismiss: {
                    showingTypeSelection = false
                }
            )
        }
        .sheet(isPresented: $showingGoalCreation) {
            GoalCreationView(
                goalType: selectedGoalType,
                onGoalCreated: { _ in
                    showingGoalCreation = false
                    onGoalCreated()
                },
                onDismiss: {
                    showingGoalCreation = false
                }
            )
        }
    }
    
    private var quickActionButtons: some View {
        HStack(spacing: 12) {
            // Quick weight goal
            QuickGoalButton(
                icon: "scalemass",
                title: "体重",
                color: .blue,
                action: {
                    selectedGoalType = .weight
                    showingGoalCreation = true
                }
            )
            
            // Quick steps goal
            QuickGoalButton(
                icon: "figure.walk",
                title: "歩数",
                color: .green,
                action: {
                    selectedGoalType = .steps
                    showingGoalCreation = true
                }
            )
            
            // Quick calories goal
            QuickGoalButton(
                icon: "flame",
                title: "カロリー",
                color: .orange,
                action: {
                    selectedGoalType = .calories
                    showingGoalCreation = true
                }
            )
            
            // More options
            QuickGoalButton(
                icon: "ellipsis",
                title: "その他",
                color: .gray,
                action: {
                    showingTypeSelection = true
                }
            )
        }
    }
}

/// Quick action button for common goal types
struct QuickGoalButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

/// Goal type selection view presented as sheet
struct GoalTypeSelectionView: View {
    let onTypeSelected: (HealthDataType) -> Void
    let onDismiss: () -> Void
    
    private let goalTypes: [HealthDataType] = [
        .weight, .steps, .calories, .heartRate,
        .bloodPressure, .sleep, .hydration, .exercise
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 16) {
                    ForEach(goalTypes, id: \.self) { goalType in
                        GoalTypeCard(
                            goalType: goalType,
                            onTap: {
                                onTypeSelected(goalType)
                            }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("目標タイプを選択")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("キャンセル") {
                        onDismiss()
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("キャンセル") {
                        onDismiss()
                    }
                }
                #endif
            }
        }
    }
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)
    }
}

/// Individual goal type selection card
struct GoalTypeCard: View {
    let goalType: HealthDataType
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(goalTypeColor.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: goalType.iconName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(goalTypeColor)
                }
                
                // Title and description
                VStack(spacing: 4) {
                    Text(goalType.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(goalType.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                
                // Unit indicator
                Text(goalType.unit)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(goalTypeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(goalTypeColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding()
            .background(Color(.controlColor))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(goalTypeColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var goalTypeColor: Color {
        switch goalType {
        case .weight: return .blue
        case .steps: return .green
        case .calories: return .orange
        case .heartRate: return .red
        case .bloodGlucose: return .pink
        case .bloodPressure: return .purple
        case .sleep: return .indigo
        case .hydration: return .cyan
        case .exercise: return .mint
        case .custom: return .gray
        }
    }
}

/// Comprehensive goal creation form
struct GoalCreationView: View {
    let goalType: HealthDataType
    let onGoalCreated: (GoalCreationRequest) -> Void
    let onDismiss: () -> Void
    
    @State private var targetValue: Double = 0
    @State private var timeframe: GoalTimeframe = .month
    @State private var description: String = ""
    @State private var selectedDeadline = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    
    @State private var showingDatePicker = false
    @State private var isCreating = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Goal overview section
                goalOverviewSection
                
                // Target value section
                targetValueSection
                
                // Timeline section
                timelineSection
                
                // Optional description section
                descriptionSection
                
                // Preview section
                previewSection
            }
            .navigationTitle("目標作成")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("作成") {
                        createGoal()
                    }
                    .fontWeight(.semibold)
                    .disabled(targetValue <= 0 || isCreating)
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("キャンセル") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .automatic) {
                    Button("作成") {
                        createGoal()
                    }
                    .fontWeight(.semibold)
                    .disabled(targetValue <= 0 || isCreating)
                }
                #endif
            }
            .onAppear {
                setupDefaultValues()
            }
        }
    }
    
    private var goalOverviewSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: goalType.iconName)
                    .font(.title2)
                    .foregroundColor(goalTypeColor)
                    .frame(width: 40, height: 40)
                    .background(goalTypeColor.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(goalType.displayName + "目標")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(goalType.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        } header: {
            Text("目標タイプ")
        }
    }
    
    private var targetValueSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("目標値")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(targetValue, specifier: goalType.numberFormat) \(goalType.unit)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(goalTypeColor)
                }
                
                Slider(
                    value: $targetValue,
                    in: targetValueRange,
                    step: targetValueStep
                ) {
                    Text("目標値")
                } minimumValueLabel: {
                    Text("\(targetValueRange.lowerBound, specifier: goalType.numberFormat)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } maximumValueLabel: {
                    Text("\(targetValueRange.upperBound, specifier: goalType.numberFormat)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .tint(goalTypeColor)
            }
            .padding(.vertical, 8)
        } header: {
            Text("目標値設定")
        } footer: {
            Text(targetValueHint)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var timelineSection: some View {
        Section {
            // Timeframe picker
            Picker("期間", selection: $timeframe) {
                ForEach(GoalTimeframe.allCases, id: \.self) { timeframe in
                    Text(timeframe.displayName).tag(timeframe)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: timeframe) { _, newValue in
                updateDeadlineFromTimeframe(newValue)
            }
            
            // Custom deadline picker
            HStack {
                Text("期限日")
                Spacer()
                Button(action: {
                    showingDatePicker = true
                }) {
                    Text(selectedDeadline, formatter: dateFormatter)
                        .foregroundColor(goalTypeColor)
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                NavigationStack {
                    DatePicker(
                        "期限日",
                        selection: $selectedDeadline,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                    .navigationTitle("期限日を選択")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        #if os(iOS)
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("完了") {
                                showingDatePicker = false
                            }
                        }
                        #else
                        ToolbarItem(placement: .automatic) {
                            Button("完了") {
                                showingDatePicker = false
                            }
                        }
                        #endif
                    }
                }
                .presentationDetents([.medium])
            }
            
        } header: {
            Text("達成期限")
        } footer: {
            Text("現実的な期限を設定することで、継続的な進捗管理ができます。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var descriptionSection: some View {
        Section {
            TextField("目標の詳細や動機を入力（任意）", text: $description, axis: .vertical)
                .lineLimit(3...6)
        } header: {
            Text("目標の説明（任意）")
        }
    }
    
    private var previewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("目標プレビュー")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                GoalPreviewCard(
                    goalType: goalType,
                    targetValue: targetValue,
                    deadline: selectedDeadline,
                    description: description
                )
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Helper Properties
    
    private var goalTypeColor: Color {
        switch goalType {
        case .weight: return .blue
        case .steps: return .green
        case .calories: return .orange
        case .heartRate: return .red
        case .bloodGlucose: return .pink
        case .bloodPressure: return .purple
        case .sleep: return .indigo
        case .hydration: return .cyan
        case .exercise: return .mint
        case .custom: return .gray
        }
    }
    
    private var targetValueRange: ClosedRange<Double> {
        switch goalType {
        case .weight: return 50.0...120.0
        case .steps: return 1000.0...30000.0
        case .calories: return 1000.0...5000.0
        case .heartRate: return 60.0...180.0
        case .bloodGlucose: return 80.0...200.0
        case .bloodPressure: return 90.0...140.0
        case .sleep: return 4.0...12.0
        case .hydration: return 1.0...5.0
        case .exercise: return 10.0...180.0
        case .custom: return 0.0...1000.0
        }
    }
    
    private var targetValueStep: Double {
        switch goalType {
        case .weight: return 0.5
        case .steps: return 500.0
        case .calories: return 100.0
        case .heartRate: return 5.0
        case .bloodGlucose: return 10.0
        case .bloodPressure: return 5.0
        case .sleep: return 0.5
        case .hydration: return 0.1
        case .exercise: return 5.0
        case .custom: return 1.0
        }
    }
    
    private var targetValueHint: String {
        switch goalType {
        case .weight: return "健康的な体重範囲を考慮して設定してください"
        case .steps: return "WHO推奨の1日8,000歩以上を目安にしてください"
        case .calories: return "年齢・性別・活動量に応じた適切な消費カロリーを設定してください"
        case .heartRate: return "安静時心拍数の改善を目標にしてください"
        case .bloodGlucose: return "医師と相談の上、適切な血糖値目標を設定してください"
        case .bloodPressure: return "健康的な血圧値（収縮期120mmHg未満）を目標にしてください"
        case .sleep: return "成人に推奨される7-9時間の睡眠時間を目安にしてください"
        case .hydration: return "体重1kgあたり35mlの水分補給が推奨されています"
        case .exercise: return "週150分以上の中強度運動が推奨されています"
        case .custom: return "あなたの健康状態に適した目標値を設定してください"
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    // MARK: - Helper Methods
    
    private func setupDefaultValues() {
        targetValue = getDefaultTargetValue()
        updateDeadlineFromTimeframe(timeframe)
    }
    
    private func getDefaultTargetValue() -> Double {
        switch goalType {
        case .weight: return 70.0
        case .steps: return 8000.0
        case .calories: return 2000.0
        case .heartRate: return 70.0
        case .bloodGlucose: return 100.0
        case .bloodPressure: return 120.0
        case .sleep: return 8.0
        case .hydration: return 2.0
        case .exercise: return 30.0
        case .custom: return 10.0
        }
    }
    
    private func updateDeadlineFromTimeframe(_ timeframe: GoalTimeframe) {
        let calendar = Calendar.current
        let now = Date()
        
        switch timeframe {
        case .week:
            selectedDeadline = calendar.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
        case .month:
            selectedDeadline = calendar.date(byAdding: .month, value: 1, to: now) ?? now
        case .quarter:
            selectedDeadline = calendar.date(byAdding: .month, value: 3, to: now) ?? now
        case .overall:
            selectedDeadline = calendar.date(byAdding: .year, value: 1, to: now) ?? now
        }
    }
    
    private func createGoal() {
        isCreating = true
        
        let goalRequest = GoalCreationRequest(
            type: goalType,
            targetValue: targetValue,
            deadline: selectedDeadline,
            description: description.isEmpty ? nil : description
        )
        
        onGoalCreated(goalRequest)
        isCreating = false
    }
}

/// Preview card for goal creation
struct GoalPreviewCard: View {
    let goalType: HealthDataType
    let targetValue: Double
    let deadline: Date
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: goalType.iconName)
                    .foregroundColor(goalTypeColor)
                
                Text(goalType.displayName + "目標")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(targetValue, specifier: goalType.numberFormat) \(goalType.unit)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(goalTypeColor)
            }
            
            HStack {
                Text("期限:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(deadline, formatter: dateFormatter)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            if !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(goalTypeColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var goalTypeColor: Color {
        switch goalType {
        case .weight: return .blue
        case .steps: return .green
        case .calories: return .orange
        case .heartRate: return .red
        case .bloodGlucose: return .pink
        case .bloodPressure: return .purple
        case .sleep: return .indigo
        case .hydration: return .cyan
        case .exercise: return .mint
        case .custom: return .gray
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
}

/// Custom button style with scale animation
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Extensions

extension HealthDataType {
    var description: String {
        switch self {
        case .weight: return "体重の増減を管理"
        case .steps: return "日々の歩数を記録"
        case .calories: return "消費カロリーを追跡"
        case .heartRate: return "心拍数を監視"
        case .bloodGlucose: return "血糖値を管理"
        case .bloodPressure: return "血圧値を管理"
        case .sleep: return "睡眠時間を記録"
        case .hydration: return "水分補給を追跡"
        case .exercise: return "運動時間を記録"
        case .custom: return "カスタム健康指標"
        }
    }
    
    var numberFormat: String {
        switch self {
        case .weight, .hydration: return "%.1f"
        case .steps, .calories: return "%.0f"
        case .heartRate, .bloodGlucose, .bloodPressure: return "%.0f"
        case .sleep, .exercise: return "%.1f"
        case .custom: return "%.1f"
        }
    }
}

// MARK: - Previews

#Preview("Create Goal Button") {
    CreateGoalButton(onGoalCreated: {})
        .padding()
}