import SwiftUI

/// Card displaying AI-generated goal suggestions with personalized recommendations
/// Integrates with GoalsViewModel for intelligent goal creation
struct GoalSuggestionsCard: View {
    let suggestions: [GoalSuggestion]
    
    @State private var selectedSuggestion: GoalSuggestion?
    @State private var showingSuggestionDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            headerView
            
            // Suggestions list
            if suggestions.isEmpty {
                emptyStateView
            } else {
                suggestionsListView
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.05),
                    Color.purple.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        .sheet(isPresented: $showingSuggestionDetail) {
            if let suggestion = selectedSuggestion {
                SuggestionDetailView(
                    suggestion: suggestion,
                    onDismiss: {
                        showingSuggestionDetail = false
                        selectedSuggestion = nil
                    },
                    onAccept: { acceptedSuggestion in
                        // TODO: Create goal from suggestion
                        showingSuggestionDetail = false
                        selectedSuggestion = nil
                    }
                )
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI目標提案")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("あなたに最適な目標を提案")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Suggestion count badge
            if !suggestions.isEmpty {
                suggestionCountBadge
            }
        }
    }
    
    private var suggestionCountBadge: some View {
        Text("\(suggestions.count)")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(width: 24, height: 24)
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Circle())
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "lightbulb")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("現在利用可能な提案はありません")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("もう少しデータが蓄積されると、パーソナライズされた目標を提案できます")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    private var suggestionsListView: some View {
        LazyVStack(spacing: 12) {
            ForEach(suggestions.prefix(3), id: \.id) { suggestion in
                SuggestionRow(
                    suggestion: suggestion,
                    onTap: {
                        selectedSuggestion = suggestion
                        showingSuggestionDetail = true
                    },
                    onQuickAccept: {
                        // TODO: Quick accept suggestion
                    }
                )
            }
            
            if suggestions.count > 3 {
                Button("他\(suggestions.count - 3)個の提案を表示") {
                    // TODO: Navigate to full suggestions list
                }
                .font(.subheadline)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .padding(.top, 8)
            }
        }
    }
}

/// Individual suggestion row with AI reasoning and quick actions
struct SuggestionRow: View {
    let suggestion: GoalSuggestion
    let onTap: () -> Void
    let onQuickAccept: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with confidence indicator
                HStack {
                    suggestionTypeIcon
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        if let reasoning = suggestion.reasoning {
                            Text(reasoning)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    
                    Spacer()
                    
                    confidenceIndicator
                }
                
                // Goal details
                goalDetailsView
                
                // Action buttons
                actionButtonsView
            }
            .padding()
            .background(Color.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var suggestionTypeIcon: some View {
        ZStack {
            Circle()
                .fill(suggestionTypeColor.opacity(0.2))
                .frame(width: 40, height: 40)
            
            Image(systemName: suggestion.type.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(suggestionTypeColor)
        }
    }
    
    private var suggestionTypeColor: Color {
        switch suggestion.type {
        case .weight: return .blue
        case .steps: return .green
        case .calories: return .orange
        case .heartRate: return .red
        case .bloodPressure: return .purple
        case .sleep: return .indigo
        case .hydration: return .cyan
        case .exercise: return .mint
        case .custom: return .gray
        }
    }
    
    private var confidenceIndicator: some View {
        VStack(spacing: 4) {
            HStack(spacing: 1) {
                ForEach(0..<5, id: \.self) { index in
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(
                            index < Int(suggestion.confidence * 5) ? .yellow : .gray.opacity(0.3)
                        )
                }
            }
            
            Text("信頼度")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var goalDetailsView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("目標値: \(suggestion.targetValue, specifier: "%.1f") \(suggestion.type.unit)")
                    .font(.caption)
                    .foregroundColor(.primary)
                
                if let timeframe = suggestion.timeframe {
                    Text("期間: \(timeframe.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if suggestion.isRecommended {
                recommendedBadge
            }
        }
    }
    
    private var recommendedBadge: some View {
        Text("推奨")
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                LinearGradient(
                    colors: [.green, .mint],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private var actionButtonsView: some View {
        HStack(spacing: 8) {
            Button("詳細") {
                onTap()
            }
            .font(.caption)
            .foregroundColor(.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            Spacer()
            
            Button(action: onQuickAccept) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.caption)
                    Text("目標にする")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

/// Detailed suggestion view presented as sheet
struct SuggestionDetailView: View {
    let suggestion: GoalSuggestion
    let onDismiss: () -> Void
    let onAccept: (GoalSuggestion) -> Void
    
    @State private var customTargetValue: Double
    @State private var customTimeframe: GoalTimeframe
    
    init(suggestion: GoalSuggestion, onDismiss: @escaping () -> Void, onAccept: @escaping (GoalSuggestion) -> Void) {
        self.suggestion = suggestion
        self.onDismiss = onDismiss
        self.onAccept = onAccept
        self._customTargetValue = State(initialValue: suggestion.targetValue)
        self._customTimeframe = State(initialValue: suggestion.timeframe ?? .month)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Suggestion overview
                    suggestionOverviewSection
                    
                    // AI reasoning
                    aiReasoningSection
                    
                    // Customization options
                    customizationSection
                    
                    // Expected benefits
                    if !suggestion.expectedBenefits.isEmpty {
                        expectedBenefitsSection
                    }
                }
                .padding()
            }
            .navigationTitle("目標提案詳細")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("採用") {
                        var customizedSuggestion = suggestion
                        customizedSuggestion.targetValue = customTargetValue
                        customizedSuggestion.timeframe = customTimeframe
                        onAccept(customizedSuggestion)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var suggestionOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("提案概要")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("目標タイプ:")
                    Spacer()
                    Text(suggestion.type.displayName)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("推奨目標値:")
                    Spacer()
                    Text("\(suggestion.targetValue, specifier: "%.1f") \(suggestion.type.unit)")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("推奨期間:")
                    Spacer()
                    Text(suggestion.timeframe?.displayName ?? "未設定")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("信頼度:")
                    Spacer()
                    HStack(spacing: 1) {
                        ForEach(0..<5, id: \.self) { index in
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(
                                    index < Int(suggestion.confidence * 5) ? .yellow : .gray.opacity(0.3)
                                )
                        }
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private var aiReasoningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI分析結果")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let reasoning = suggestion.reasoning {
                Text(reasoning)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    private var customizationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("カスタマイズ")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                // Target value adjustment
                VStack(alignment: .leading, spacing: 8) {
                    Text("目標値: \(customTargetValue, specifier: "%.1f") \(suggestion.type.unit)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Slider(
                        value: $customTargetValue,
                        in: targetValueRange,
                        step: targetValueStep
                    )
                    .tint(.blue)
                }
                
                // Timeframe selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("達成期間")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("期間", selection: $customTimeframe) {
                        ForEach(GoalTimeframe.allCases, id: \.self) { timeframe in
                            Text(timeframe.displayName).tag(timeframe)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private var expectedBenefitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("期待される効果")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(suggestion.expectedBenefits, id: \.self) { benefit in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.top, 2)
                        
                        Text(benefit)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.green.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private var targetValueRange: ClosedRange<Double> {
        switch suggestion.type {
        case .weight:
            return 50.0...100.0
        case .steps:
            return 1000.0...20000.0
        case .calories:
            return 1000.0...4000.0
        case .heartRate:
            return 60.0...180.0
        default:
            return 0.0...1000.0
        }
    }
    
    private var targetValueStep: Double {
        switch suggestion.type {
        case .weight:
            return 0.5
        case .steps:
            return 500.0
        case .calories:
            return 100.0
        case .heartRate:
            return 5.0
        default:
            return 1.0
        }
    }
}

// MARK: - Extensions


// MARK: - Previews

#Preview("Goal Suggestions Card") {
    let sampleSuggestions = [
        GoalSuggestion(
            type: .weight,
            suggestedTargetValue: 68.0,
            suggestedDeadline: Calendar.current.date(byAdding: .month, value: 2, to: Date()) ?? Date(),
            title: "体重目標",
            description: "健康的な減量目標",
            reasoning: "現在の減量ペースを考慮すると、2ヶ月で2.5kg減量が現実的です。",
            confidenceScore: 0.9,
            isRecommended: true
        ),
        GoalSuggestion(
            type: .steps,
            suggestedTargetValue: 8500.0,
            suggestedDeadline: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date(),
            title: "歩数目標",
            description: "日々の歩数向上",
            reasoning: "現在の平均歩数を15%向上させる現実的な目標です。",
            confidenceScore: 0.8,
            isRecommended: true
        )
    ]
    
    GoalSuggestionsCard(suggestions: sampleSuggestions)
        .padding()
}