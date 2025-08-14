import SwiftUI

/// Card displaying active goals with progress visualization and quick actions
/// Integrates with GoalsViewModel for real-time goal tracking
struct ActiveGoalsCard: View {
    let goals: [Goal]
    let progressDetails: [UUID: GoalProgressDetail]
    
    @State private var selectedGoal: Goal?
    @State private var showingGoalDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            headerView
            
            // Goals list
            if goals.isEmpty {
                emptyStateView
            } else {
                goalsListView
            }
        }
        .padding()
        .background(Color(.controlColor))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        .sheet(isPresented: $showingGoalDetail) {
            if let goal = selectedGoal {
                GoalDetailView(
                    goal: goal,
                    progressDetail: progressDetails[goal.id],
                    onDismiss: {
                        showingGoalDetail = false
                        selectedGoal = nil
                    }
                )
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("アクティブな目標")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if !goals.isEmpty {
                    Text("\(goals.count)個の目標が進行中")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Overall progress indicator
            if !goals.isEmpty {
                overallProgressView
            }
        }
    }
    
    private var overallProgressView: some View {
        let overallProgress = goals.reduce(0.0) { $0 + $1.progress } / Double(goals.count)
        
        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                    .frame(width: 40, height: 40)
                
                Circle()
                    .trim(from: 0, to: overallProgress)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.0), value: overallProgress)
                
                Text("\(Int(overallProgress * 100))%")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            Text("全体進捗")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "target")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("アクティブな目標がありません")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("新しい目標を設定して、健康管理を始めましょう")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    private var goalsListView: some View {
        LazyVStack(spacing: 12) {
            ForEach(goals.prefix(5), id: \.id) { goal in
                GoalProgressRow(
                    goal: goal,
                    progressDetail: progressDetails[goal.id],
                    onTap: {
                        selectedGoal = goal
                        showingGoalDetail = true
                    }
                )
            }
            
            if goals.count > 5 {
                Button("他\(goals.count - 5)個の目標を表示") {
                    // TODO: Navigate to full goals list
                }
                .font(.subheadline)
                .foregroundColor(.accentColor)
                .padding(.top, 8)
            }
        }
    }
}

/// Individual goal progress row with visual indicators
struct GoalProgressRow: View {
    let goal: Goal
    let progressDetail: GoalProgressDetail?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Goal type icon
                goalTypeIcon
                
                // Goal info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(goal.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if let detail = progressDetail {
                            motivationIndicator(detail.motivationLevel)
                        }
                    }
                    
                    Text(goal.progressDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    // Progress bar
                    progressBar
                    
                    // Deadline info
                    deadlineInfo
                }
                
                // Progress percentage
                progressPercentage
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.gray.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var goalTypeIcon: some View {
        ZStack {
            Circle()
                .fill(goalTypeColor.opacity(0.2))
                .frame(width: 40, height: 40)
            
            Image(systemName: goal.type.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(goalTypeColor)
        }
    }
    
    private var goalTypeColor: Color {
        switch goal.type {
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
    
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: progressGradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * goal.progress, height: 4)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .animation(.easeOut(duration: 0.8), value: goal.progress)
            }
        }
        .frame(height: 4)
    }
    
    private var progressGradientColors: [Color] {
        if goal.progress >= 0.8 {
            return [.green, .mint]
        } else if goal.progress >= 0.5 {
            return [.blue, .green]
        } else if goal.progress >= 0.3 {
            return [.orange, .yellow]
        } else {
            return [.red, .orange]
        }
    }
    
    private var deadlineInfo: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(deadlineText)
                .font(.caption2)
                .foregroundColor(deadlineColor)
        }
    }
    
    private var deadlineText: String {
        let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: goal.deadline).day ?? 0
        
        if daysRemaining < 0 {
            return "期限超過"
        } else if daysRemaining == 0 {
            return "今日が期限"
        } else if daysRemaining == 1 {
            return "明日が期限"
        } else {
            return "あと\(daysRemaining)日"
        }
    }
    
    private var deadlineColor: Color {
        let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: goal.deadline).day ?? 0
        
        if daysRemaining < 0 {
            return .red
        } else if daysRemaining <= 3 {
            return .orange
        } else {
            return .secondary
        }
    }
    
    private var progressPercentage: some View {
        VStack(spacing: 2) {
            Text("\(Int(goal.progress * 100))%")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            if let detail = progressDetail, detail.isOnTrack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.green)
            } else {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
    }
    
    private func motivationIndicator(_ level: MotivationLevel) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index < levelNumericValue(level) ? levelColor(level) : Color.gray.opacity(0.3))
                    .frame(width: 4, height: 4)
            }
        }
    }
    
    private func levelNumericValue(_ level: MotivationLevel) -> Int {
        switch level {
        case .critical: return 1
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }
    
    private func levelColor(_ level: MotivationLevel) -> Color {
        switch level {
        case .critical: return .red
        case .low: return .orange
        case .medium: return .yellow
        case .high: return .green
        }
    }
}

/// Detailed goal view presented as sheet
struct GoalDetailView: View {
    let goal: Goal
    let progressDetail: GoalProgressDetail?
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Goal overview
                    goalOverviewSection
                    
                    // Progress analysis
                    if let detail = progressDetail {
                        progressAnalysisSection(detail)
                    }
                    
                    // Action buttons
                    actionButtonsSection
                }
                .padding()
            }
            .navigationTitle(goal.displayName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
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
    
    private var goalOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("目標概要")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("現在の値:")
                    Spacer()
                    Text("\(goal.currentValue, specifier: "%.1f") \(goal.type.unit)")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("目標値:")
                    Spacer()
                    Text("\(goal.targetValue, specifier: "%.1f") \(goal.type.unit)")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("進捗:")
                    Spacer()
                    Text("\(Int(goal.progress * 100))%")
                        .fontWeight(.medium)
                        .foregroundColor(goal.progress >= 0.8 ? .green : .primary)
                }
                
                HStack {
                    Text("期限:")
                    Spacer()
                    Text(goal.deadline, formatter: dateFormatter)
                        .fontWeight(.medium)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private func progressAnalysisSection(_ detail: GoalProgressDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("進捗分析")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("軌道状況:")
                    Spacer()
                    Text(detail.isOnTrack ? "順調" : "要注意")
                        .fontWeight(.medium)
                        .foregroundColor(detail.isOnTrack ? .green : .orange)
                }
                
                HStack {
                    Text("モチベーション:")
                    Spacer()
                    Text(detail.motivationLevel.displayName)
                        .fontWeight(.medium)
                        .foregroundColor(motivationColor(detail.motivationLevel))
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button("進捗を更新") {
                // TODO: Implement progress update
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            
            HStack(spacing: 12) {
                Button("編集") {
                    // TODO: Implement edit goal
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                
                Button("削除") {
                    // TODO: Implement delete goal
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    private func motivationColor(_ level: MotivationLevel) -> Color {
        switch level {
        case .critical: return .red
        case .low: return .orange
        case .medium: return .yellow
        case .high: return .green
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
}

// MARK: - Extensions

extension Goal {
    var displayName: String {
        switch type {
        case .weight:
            return "体重目標"
        case .steps:
            return "歩数目標"
        case .calories:
            return "カロリー目標"
        case .heartRate:
            return "心拍数目標"
        case .bloodGlucose:
            return "血糖値目標"
        case .bloodPressure:
            return "血圧目標"
        case .sleep:
            return "睡眠目標"
        case .hydration:
            return "水分補給目標"
        case .exercise:
            return "運動目標"
        case .custom:
            return "カスタム目標"
        }
    }
    
    var progressDescription: String {
        let remaining = targetValue - currentValue
        let unit = type.unit
        
        if remaining <= 0 {
            return "目標達成！"
        } else {
            return String(format: "あと%.1f%@", remaining, unit)
        }
    }
}




// MARK: - Previews

#Preview("Active Goals Card") {
    struct PreviewWrapper: View {
        var body: some View {
            let testUser = try! User(name: "Test", age: 30, height: 170.0, targetWeight: 70.0)
            
            let weightGoal = try! Goal(
                type: .weight,
                targetValue: 70.0,
                deadline: Calendar.current.date(byAdding: .month, value: 2, to: Date())!,
                isActive: true
            )
            weightGoal.currentValue = 72.5
            weightGoal.user = testUser
            
            let stepsGoal = try! Goal(
                type: .steps,
                targetValue: 10000.0,
                deadline: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
                isActive: true
            )
            stepsGoal.currentValue = 7500.0
            stepsGoal.user = testUser
            
            let sampleGoals = [weightGoal, stepsGoal]
    
    let sampleProgressDetails: [UUID: GoalProgressDetail] = [
        sampleGoals[0].id: GoalProgressDetail(
            goalId: sampleGoals[0].id,
            goalType: sampleGoals[0].type,
            targetValue: sampleGoals[0].targetValue,
            currentValue: sampleGoals[0].currentValue,
            progress: sampleGoals[0].progress,
            progressPercentage: sampleGoals[0].progress * 100,
            remainingValue: max(0, sampleGoals[0].targetValue - sampleGoals[0].currentValue),
            remainingDays: max(0, Calendar.current.dateComponents([.day], from: Date(), to: sampleGoals[0].deadline).day ?? 0),
            dailyRequiredProgress: 10.0,
            isOnTrack: true,
            achievabilityScore: 0.8,
            motivationLevel: .high,
            milestones: [],
            recommendations: []
        ),
        sampleGoals[1].id: GoalProgressDetail(
            goalId: sampleGoals[1].id,
            goalType: sampleGoals[1].type,
            targetValue: sampleGoals[1].targetValue,
            currentValue: sampleGoals[1].currentValue,
            progress: sampleGoals[1].progress,
            progressPercentage: sampleGoals[1].progress * 100,
            remainingValue: max(0, sampleGoals[1].targetValue - sampleGoals[1].currentValue),
            remainingDays: max(0, Calendar.current.dateComponents([.day], from: Date(), to: sampleGoals[1].deadline).day ?? 0),
            dailyRequiredProgress: 15.0,
            isOnTrack: false,
            achievabilityScore: 0.6,
            motivationLevel: .medium,
            milestones: [],
            recommendations: []
        )
            ]
            
            return ActiveGoalsCard(
                goals: sampleGoals,
                progressDetails: sampleProgressDetails
            )
            .padding()
        }
    }
    
    return PreviewWrapper()
}