import SwiftUI
import SwiftData

/// Progressive Goal Setup Wizard - Step-by-step goal creation with AI suggestions
struct GoalSetupWizardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel = GoalSetupWizardViewModel()
    @State private var currentStep: WizardStep = .dataTypeSelection
    @State private var showingDismissAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                ProgressBarView(currentStep: currentStep, totalSteps: WizardStep.allCases.count)
                    .padding(.horizontal)
                    .padding(.top)
                
                // Step content
                ScrollView {
                    VStack(spacing: 24) {
                        stepHeaderView
                        stepContentView
                    }
                    .padding()
                }
                
                // Navigation buttons
                HStack {
                    if currentStep != .dataTypeSelection {
                        Button("戻る") {
                            previousStep()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                    
                    Button(currentStep == .confirmation ? "目標を作成" : "次へ") {
                        if currentStep == .confirmation {
                            createGoal()
                        } else {
                            nextStep()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canProceedFromCurrentStep(currentStep))
                }
                .padding()
            }
            .navigationTitle("目標設定ウィザード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        showingDismissAlert = true
                    }
                }
            }
            .alert("目標設定を中止しますか？", isPresented: $showingDismissAlert) {
                Button("中止", role: .destructive) {
                    dismiss()
                }
                Button("続行", role: .cancel) { }
            }
        }
        .task {
            await viewModel.loadInitialData()
        }
    }
    
    // MARK: - Step Views
    
    @ViewBuilder
    private var stepHeaderView: some View {
        VStack(spacing: 8) {
            Text(currentStep.title)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(currentStep.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    @ViewBuilder
    private var stepContentView: some View {
        switch currentStep {
        case .dataTypeSelection:
            DataTypeSelectionView(
                selectedDataType: $viewModel.selectedDataType,
                availableDataTypes: viewModel.availableDataTypes
            )
            
        case .aiSuggestions:
            AISuggestionsView(
                suggestions: viewModel.aiSuggestions,
                selectedSuggestion: $viewModel.selectedAISuggestion
            )
            
        case .targetCustomization:
            TargetCustomizationView(
                goalType: viewModel.selectedDataType,
                targetValue: $viewModel.targetValue,
                timeframe: $viewModel.timeframe,
                aiSuggestion: viewModel.selectedAISuggestion
            )
            
        case .seasonalAdaptation:
            SeasonalAdaptationView(
                goalType: viewModel.selectedDataType,
                seasonalAdjustments: viewModel.seasonalAdjustments,
                enableSeasonalAdaptation: $viewModel.enableSeasonalAdaptation
            )
            
        case .progressivePlanning:
            ProgressivePlanningView(
                progressivePlan: viewModel.progressivePlan,
                enableProgressivePlanning: $viewModel.enableProgressivePlanning,
                phaseCount: $viewModel.phaseCount
            )
            
        case .confirmation:
            ConfirmationView(
                goalSummary: viewModel.goalSummary
            )
        }
    }
    
    // MARK: - Navigation Methods
    
    private func nextStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let nextStep = WizardStep(rawValue: currentStep.rawValue + 1) {
                currentStep = nextStep
                Task {
                    await viewModel.prepareForStep(nextStep)
                }
            }
        }
    }
    
    private func previousStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let previousStep = WizardStep(rawValue: currentStep.rawValue - 1) {
                currentStep = previousStep
            }
        }
    }
    
    private func createGoal() {
        Task {
            do {
                let createdGoal = try await viewModel.createGoal(using: modelContext)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                // Handle error
                print("Goal creation failed: \(error)")
            }
        }
    }
}

// MARK: - Progress Bar

struct ProgressBarView: View {
    let currentStep: WizardStep
    let totalSteps: Int
    
    private var progress: Double {
        Double(currentStep.rawValue + 1) / Double(totalSteps)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ステップ \(currentStep.rawValue + 1) / \(totalSteps)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .frame(height: 6)
                        .foregroundColor(Color(.systemGray5))
                        .cornerRadius(3)
                    
                    Rectangle()
                        .frame(width: geometry.size.width * progress, height: 6)
                        .foregroundColor(.blue)
                        .cornerRadius(3)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Wizard Steps

enum WizardStep: Int, CaseIterable {
    case dataTypeSelection = 0
    case aiSuggestions = 1
    case targetCustomization = 2
    case seasonalAdaptation = 3
    case progressivePlanning = 4
    case confirmation = 5
    
    var title: String {
        switch self {
        case .dataTypeSelection:
            return "データタイプを選択"
        case .aiSuggestions:
            return "AI提案を確認"
        case .targetCustomization:
            return "目標値をカスタマイズ"
        case .seasonalAdaptation:
            return "季節適応を設定"
        case .progressivePlanning:
            return "段階的プランを設定"
        case .confirmation:
            return "設定内容を確認"
        }
    }
    
    var description: String {
        switch self {
        case .dataTypeSelection:
            return "目標を設定したい健康データのタイプを選択してください"
        case .aiSuggestions:
            return "あなたのデータに基づいたAI提案を確認してください"
        case .targetCustomization:
            return "目標値と期間をあなたの希望に合わせて調整してください"
        case .seasonalAdaptation:
            return "季節に応じた目標調整を設定してください"
        case .progressivePlanning:
            return "段階的な達成プランを設定してください"
        case .confirmation:
            return "設定内容を確認して目標を作成してください"
        }
    }
}

// MARK: - Step Component Views

struct DataTypeSelectionView: View {
    @Binding var selectedDataType: HealthDataType?
    let availableDataTypes: [HealthDataType]
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            ForEach(availableDataTypes, id: \.self) { dataType in
                DataTypeCard(
                    dataType: dataType,
                    isSelected: selectedDataType == dataType
                ) {
                    selectedDataType = dataType
                }
            }
        }
    }
}

struct DataTypeCard: View {
    let dataType: HealthDataType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: dataType.iconName)
                    .font(.largeTitle)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(dataType.displayName)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(dataType.description)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AISuggestionsView: View {
    let suggestions: [AIGoalSuggestion]
    @Binding var selectedSuggestion: AIGoalSuggestion?
    
    var body: some View {
        VStack(spacing: 16) {
            if suggestions.isEmpty {
                Text("AI提案を生成中...")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(suggestions, id: \.id) { suggestion in
                    AISuggestionCard(
                        suggestion: suggestion,
                        isSelected: selectedSuggestion?.id == suggestion.id
                    ) {
                        selectedSuggestion = suggestion
                    }
                }
            }
        }
    }
}

struct AISuggestionCard: View {
    let suggestion: AIGoalSuggestion
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(suggestion.suggestedTarget, specifier: "%.1f") \(suggestion.targetUnit)")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(suggestion.timeframe.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("\(Int(suggestion.confidence * 100))%")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        Text(suggestion.priority.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(suggestion.priority.color.opacity(0.2))
                            .foregroundColor(suggestion.priority.color)
                            .cornerRadius(4)
                    }
                }
                
                Text(suggestion.rationale)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                if !suggestion.expectedBenefits.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("期待される効果:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        ForEach(suggestion.expectedBenefits.prefix(2), id: \.id) { benefit in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                
                                Text(benefit.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TargetCustomizationView: View {
    let goalType: HealthDataType?
    @Binding var targetValue: Double
    @Binding var timeframe: GoalTimeframe
    let aiSuggestion: AIGoalSuggestion?
    
    var body: some View {
        VStack(spacing: 24) {
            // Target value adjustment
            VStack(alignment: .leading, spacing: 8) {
                Text("目標値")
                    .font(.headline)
                
                HStack {
                    Text("\(targetValue, specifier: "%.1f")")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(goalType?.defaultUnit ?? "")
                        .font(.title)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                Slider(value: $targetValue, in: targetValueRange) {
                    Text("目標値")
                } minimumValueLabel: {
                    Text("\(targetValueRange.lowerBound, specifier: "%.0f")")
                        .font(.caption)
                } maximumValueLabel: {
                    Text("\(targetValueRange.upperBound, specifier: "%.0f")")
                        .font(.caption)
                }
            }
            
            // Timeframe selection
            VStack(alignment: .leading, spacing: 8) {
                Text("達成期間")
                    .font(.headline)
                
                Picker("達成期間", selection: $timeframe) {
                    ForEach(GoalTimeframe.allCases, id: \.self) { timeframe in
                        Text(timeframe.displayName).tag(timeframe)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // AI suggestion comparison
            if let suggestion = aiSuggestion {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI提案との比較")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("AI提案")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(suggestion.suggestedTarget, specifier: "%.1f") \(suggestion.targetUnit)")
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("あなたの設定")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(targetValue, specifier: "%.1f") \(goalType?.defaultUnit ?? "")")
                                .font(.body)
                                .fontWeight(.medium)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private var targetValueRange: ClosedRange<Double> {
        guard let goalType = goalType else { return 0...100 }
        
        switch goalType {
        case .weight:
            return 40...150
        case .steps:
            return 1000...20000
        case .calories:
            return 100...1000
        case .sleep:
            return 6...10
        default:
            return 0...100
        }
    }
}

struct SeasonalAdaptationView: View {
    let goalType: HealthDataType?
    let seasonalAdjustments: [SeasonalGoalAdjustment]
    @Binding var enableSeasonalAdaptation: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Toggle("季節適応を有効にする", isOn: $enableSeasonalAdaptation)
                .font(.headline)
            
            if enableSeasonalAdaptation {
                VStack(alignment: .leading, spacing: 16) {
                    Text("季節適応プレビュー")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(Season.allCases, id: \.self) { season in
                        SeasonalAdjustmentRow(
                            season: season,
                            adjustment: seasonalAdjustments.first { $0.season == season }
                        )
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                Text("季節による目標調整は行われません")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
}

struct SeasonalAdjustmentRow: View {
    let season: Season
    let adjustment: SeasonalGoalAdjustment?
    
    var body: some View {
        HStack {
            Text(season.emoji)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(season.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let adjustment = adjustment {
                    Text(adjustment.rationale)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("調整なし")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let adjustment = adjustment {
                Text("\(adjustment.adjustmentRatio, specifier: "%.0f")%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(adjustment.adjustmentRatio > 1 ? .green : .orange)
            }
        }
    }
}

struct ProgressivePlanningView: View {
    let progressivePlan: ProgressiveGoalPlan?
    @Binding var enableProgressivePlanning: Bool
    @Binding var phaseCount: Int
    
    var body: some View {
        VStack(spacing: 20) {
            Toggle("段階的プランを有効にする", isOn: $enableProgressivePlanning)
                .font(.headline)
            
            if enableProgressivePlanning {
                VStack(alignment: .leading, spacing: 16) {
                    Text("フェーズ数")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("フェーズ数", selection: $phaseCount) {
                        ForEach(2...6, id: \.self) { count in
                            Text("\(count)フェーズ").tag(count)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if let plan = progressivePlan {
                        ProgressivePlanPreview(plan: plan)
                    }
                }
            } else {
                Text("単一の目標として設定されます")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
}

struct ProgressivePlanPreview: View {
    let plan: ProgressiveGoalPlan
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("段階プレビュー")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            ForEach(Array(plan.phases.enumerated()), id: \.offset) { index, phase in
                PhaseRow(phaseNumber: index + 1, phase: phase)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct PhaseRow: View {
    let phaseNumber: Int
    let phase: GoalPhase
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.blue)
                .frame(width: 24, height: 24)
                .overlay(
                    Text("\(phaseNumber)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("フェーズ \(phaseNumber)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(phase.targetValue, specifier: "%.1f") まで")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(phase.endDate, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct ConfirmationView: View {
    let goalSummary: GoalSummary?
    
    var body: some View {
        VStack(spacing: 24) {
            if let summary = goalSummary {
                // Goal overview
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: summary.goalType.iconName)
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text(summary.goalType.displayName)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("\(summary.targetValue, specifier: "%.1f") \(summary.targetUnit)")
                                .font(.title)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                    }
                    
                    Text(summary.timeframe.displayName)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Features summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("有効な機能")
                        .font(.headline)
                    
                    if summary.hasSeasonalAdaptation {
                        FeatureRow(
                            icon: "leaf.fill",
                            title: "季節適応",
                            description: "季節に応じて目標を自動調整"
                        )
                    }
                    
                    if summary.hasProgressivePlanning {
                        FeatureRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "段階的プラン",
                            description: "\(summary.phaseCount)つのフェーズで段階的に達成"
                        )
                    }
                    
                    FeatureRow(
                        icon: "brain.head.profile",
                        title: "AI分析",
                        description: "データ分析に基づく継続的な最適化"
                    )
                }
            } else {
                Text("設定内容を読み込み中...")
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    GoalSetupWizardView()
        .modelContainer(for: [Goal.self, User.self])
}