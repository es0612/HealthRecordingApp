import SwiftUI
import Foundation

/// 通知設定画面
/// ユーザーが通知の種類、時間、頻度を設定できるUI
struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = NotificationSettingsViewModel()
    
    // UI状態管理
    @State private var showingAuthorizationAlert = false
    @State private var showingTimePickerSheet = false
    @State private var selectedNotificationType: AppNotificationType?
    @State private var selectedTimeIndex: Int = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 権限状態セクション
                    authorizationStatusSection
                    
                    // 通知種別設定セクション
                    if viewModel.authorizationStatus.isAuthorized {
                        notificationTypesSection
                        
                        // データリマインダー詳細設定
                        if viewModel.isDataRemindersEnabled {
                            dataReminderDetailsSection
                        }
                        
                        // 目標達成通知設定
                        goalAchievementSection
                        
                        // ストリーク通知設定
                        streakNotificationSection
                        
                        // 健康アラート設定
                        healthAlertSection
                        
                        // 一括設定
                        bulkSettingsSection
                    }
                }
                .padding()
            }
            .navigationTitle("通知設定")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.initialize()
            }
            .alert("通知権限が必要です", isPresented: $showingAuthorizationAlert) {
                Button("設定を開く") {
                    Task {
                        await viewModel.openSystemSettings()
                    }
                }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("通知機能を使用するには、設定アプリで通知を許可してください。")
            }
            .sheet(isPresented: $showingTimePickerSheet) {
                TimePickerSheet(
                    notificationType: selectedNotificationType ?? .dataReminder,
                    selectedTimeIndex: $selectedTimeIndex
                ) { newTime in
                    if let type = selectedNotificationType {
                        Task {
                            await viewModel.updateNotificationTime(
                                for: type,
                                at: selectedTimeIndex,
                                to: newTime
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Authorization Status Section
    
    private var authorizationStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bell.badge")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text("通知権限")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            HStack {
                Circle()
                    .fill(viewModel.authorizationStatus.isAuthorized ? .green : .red)
                    .frame(width: 12, height: 12)
                
                Text(viewModel.authorizationStatus.displayName)
                    .font(.subheadline)
                    .foregroundColor(viewModel.authorizationStatus.isAuthorized ? .green : .red)
                
                Spacer()
                
                if !viewModel.authorizationStatus.isAuthorized {
                    Button("許可する") {
                        Task {
                            await viewModel.requestNotificationPermission()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.subheadline)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlColor).opacity(0.5))
        )
    }
    
    // MARK: - Notification Types Section
    
    private var notificationTypesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text("通知の種類")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                // データリマインダー
                NotificationTypeToggleRow(
                    type: .dataReminder,
                    isEnabled: viewModel.isDataRemindersEnabled
                ) { enabled in
                    Task {
                        await viewModel.toggleNotificationType(.dataReminder, enabled: enabled)
                    }
                }
                
                Divider()
                
                // 目標達成通知
                NotificationTypeToggleRow(
                    type: .goalAchievement,
                    isEnabled: viewModel.isGoalAchievementEnabled
                ) { enabled in
                    Task {
                        await viewModel.toggleNotificationType(.goalAchievement, enabled: enabled)
                    }
                }
                
                Divider()
                
                // ストリーク通知
                NotificationTypeToggleRow(
                    type: .streakMilestone,
                    isEnabled: viewModel.isStreakMilestoneEnabled
                ) { enabled in
                    Task {
                        await viewModel.toggleNotificationType(.streakMilestone, enabled: enabled)
                    }
                }
                
                Divider()
                
                // 健康アラート
                NotificationTypeToggleRow(
                    type: .healthAlert,
                    isEnabled: viewModel.isHealthAlertEnabled
                ) { enabled in
                    Task {
                        await viewModel.toggleNotificationType(.healthAlert, enabled: enabled)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlColor).opacity(0.5))
        )
    }
    
    // MARK: - Data Reminder Details Section
    
    private var dataReminderDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.badge")
                    .foregroundColor(.orange)
                    .font(.title2)
                
                Text("データリマインダー詳細設定")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            // 頻度設定
            VStack(alignment: .leading, spacing: 8) {
                Text("頻度")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("頻度", selection: $viewModel.dataReminderFrequency) {
                    ForEach(NotificationScheduleFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.displayName).tag(frequency)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.dataReminderFrequency) { _, newValue in
                    Task {
                        await viewModel.updateDataReminderFrequency(newValue)
                    }
                }
            }
            
            // 時間設定
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("通知時間")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button(action: {
                        Task {
                            await viewModel.addDataReminderTime()
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                    .disabled(viewModel.dataReminderTimes.count >= 5)
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(Array(viewModel.dataReminderTimes.enumerated()), id: \.offset) { index, time in
                        TimeSelectionButton(
                            time: time,
                            onTap: {
                                selectedNotificationType = .dataReminder
                                selectedTimeIndex = index
                                showingTimePickerSheet = true
                            },
                            onDelete: {
                                Task {
                                    await viewModel.removeDataReminderTime(at: index)
                                }
                            }
                        )
                    }
                }
            }
            
            // インテリジェント・リマインダー
            Toggle(isOn: $viewModel.isIntelligentRemindersEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("インテリジェント・リマインダー")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("過去のデータ入力パターンに基づいて最適な時間に通知")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: viewModel.isIntelligentRemindersEnabled) { _, enabled in
                Task {
                    await viewModel.toggleIntelligentReminders(enabled)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Goal Achievement Section
    
    private var goalAchievementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(.green)
                    .font(.title2)
                
                Text("目標達成通知")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                Toggle("目標完了時に通知", isOn: $viewModel.notifyGoalCompletion)
                    .onChange(of: viewModel.notifyGoalCompletion) { _, enabled in
                        Task {
                            await viewModel.updateGoalCompletionNotification(enabled)
                        }
                    }
                
                Toggle("マイルストーン達成時に通知", isOn: $viewModel.notifyMilestoneAchievement)
                    .onChange(of: viewModel.notifyMilestoneAchievement) { _, enabled in
                        Task {
                            await viewModel.updateMilestoneNotification(enabled)
                        }
                    }
                
                Toggle("目標期限切迫アラート", isOn: $viewModel.notifyGoalDeadline)
                    .onChange(of: viewModel.notifyGoalDeadline) { _, enabled in
                        Task {
                            await viewModel.updateGoalDeadlineNotification(enabled)
                        }
                    }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Streak Notification Section
    
    private var streakNotificationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.red)
                    .font(.title2)
                
                Text("ストリーク通知")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("通知するストリーク日数")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach([7, 14, 30, 50, 100, 365], id: \.self) { days in
                        StreakMilestoneToggle(
                            days: days,
                            isEnabled: viewModel.enabledStreakMilestones.contains(days)
                        ) { enabled in
                            Task {
                                await viewModel.toggleStreakMilestone(days, enabled: enabled)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Health Alert Section
    
    private var healthAlertSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.text.square")
                    .foregroundColor(.pink)
                    .font(.title2)
                
                Text("健康アラート")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("アラート重要度")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                VStack(spacing: 8) {
                    HealthAlertSeverityToggle(
                        severity: .low,
                        isEnabled: viewModel.enabledAlertSeverities.contains(.low)
                    ) { enabled in
                        Task {
                            await viewModel.toggleAlertSeverity(.low, enabled: enabled)
                        }
                    }
                    
                    HealthAlertSeverityToggle(
                        severity: .normal,
                        isEnabled: viewModel.enabledAlertSeverities.contains(.normal)
                    ) { enabled in
                        Task {
                            await viewModel.toggleAlertSeverity(.normal, enabled: enabled)
                        }
                    }
                    
                    HealthAlertSeverityToggle(
                        severity: .high,
                        isEnabled: viewModel.enabledAlertSeverities.contains(.high)
                    ) { enabled in
                        Task {
                            await viewModel.toggleAlertSeverity(.high, enabled: enabled)
                        }
                    }
                    
                    HealthAlertSeverityToggle(
                        severity: .critical,
                        isEnabled: viewModel.enabledAlertSeverities.contains(.critical)
                    ) { enabled in
                        Task {
                            await viewModel.toggleAlertSeverity(.critical, enabled: enabled)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.pink.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.pink.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Bulk Settings Section
    
    private var bulkSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gearshape.2")
                    .foregroundColor(.purple)
                    .font(.title2)
                
                Text("一括設定")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                HStack {
                    Button("すべて有効") {
                        Task {
                            await viewModel.enableAllNotifications()
                        }
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.green)
                    
                    Spacer()
                    
                    Button("すべて無効") {
                        Task {
                            await viewModel.disableAllNotifications()
                        }
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
                
                Button("設定をリセット") {
                    Task {
                        await viewModel.resetAllSettings()
                    }
                }
                .buttonStyle(.bordered)
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Supporting Views

struct NotificationTypeToggleRow: View {
    let type: AppNotificationType
    let isEnabled: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack {
            Image(systemName: type.iconName)
                .foregroundColor(type.color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(type.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(type.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { onToggle($0) }
            ))
        }
    }
}

struct TimeSelectionButton: View {
    let time: Date
    let onTap: () -> Void
    let onDelete: () -> Void
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(timeFormatter.string(from: time))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.controlColor).opacity(0.6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StreakMilestoneToggle: View {
    let days: Int
    let isEnabled: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        Button(action: {
            onToggle(!isEnabled)
        }) {
            VStack(spacing: 4) {
                Text("\(days)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("日")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isEnabled ? Color.red.opacity(0.2) : Color(.controlColor).opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isEnabled ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1.5)
                    )
            )
            .foregroundColor(isEnabled ? .red : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct HealthAlertSeverityToggle: View {
    let severity: HealthAlertSeverity
    let isEnabled: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack {
            Circle()
                .fill(severity.color)
                .frame(width: 12, height: 12)
            
            Text(severity.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { onToggle($0) }
            ))
        }
    }
}

struct TimePickerSheet: View {
    let notificationType: AppNotificationType
    @Binding var selectedTimeIndex: Int
    let onTimeSelected: (Date) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTime = Date()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("\(notificationType.displayName)の通知時間を選択")
                    .font(.headline)
                    .padding(.top)
                
                DatePicker(
                    "通知時間",
                    selection: $selectedTime,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                
                Spacer()
            }
            .padding()
            .navigationTitle("時間を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        onTimeSelected(selectedTime)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Extensions

extension NotificationAuthorizationStatus {
    var displayName: String {
        switch self {
        case .notDetermined:
            return "未設定"
        case .denied:
            return "拒否"
        case .authorized:
            return "許可済み"
        case .provisional:
            return "仮許可"
        case .ephemeral:
            return "一時許可"
        @unknown default:
            return "不明"
        }
    }
    
    var isAuthorized: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }
}

extension AppNotificationType {
    var displayName: String {
        switch self.rawValue {
        case "dataReminder":
            return "データリマインダー"
        case "goalAchievement":
            return "目標達成通知"
        case "streakMilestone":
            return "ストリーク通知"
        case "healthAlert":
            return "健康アラート"
        case "weeklyInsight":
            return "週次レポート"
        case "milestoneAchievement":
            return "マイルストーン達成"
        default:
            return "通知"
        }
    }
    
    var description: String {
        switch self.rawValue {
        case "dataReminder":
            return "健康データの記録を促す通知"
        case "goalAchievement":
            return "設定した目標を達成した時の通知"
        case "streakMilestone":
            return "連続記録日数のマイルストーン通知"
        case "healthAlert":
            return "健康状態に関する重要なアラート"
        case "weeklyInsight":
            return "毎週の健康データ分析レポート"
        case "milestoneAchievement":
            return "目標達成過程でのマイルストーン通知"
        default:
            return "通知の説明"
        }
    }
    
    var iconName: String {
        switch self.rawValue {
        case "dataReminder":
            return "clock.badge"
        case "goalAchievement":
            return "target"
        case "streakMilestone":
            return "flame.fill"
        case "healthAlert":
            return "exclamationmark.triangle.fill"
        case "weeklyInsight":
            return "chart.bar.doc.horizontal"
        case "milestoneAchievement":
            return "flag.checkered"
        default:
            return "bell"
        }
    }
    
    var color: Color {
        switch self.rawValue {
        case "dataReminder":
            return .orange
        case "goalAchievement":
            return .green
        case "streakMilestone":
            return .red
        case "healthAlert":
            return .pink
        case "weeklyInsight":
            return .blue
        case "milestoneAchievement":
            return .purple
        default:
            return .gray
        }
    }
}

extension NotificationScheduleFrequency {
    var displayName: String {
        switch self {
        case .disabled:
            return "無効"
        case .daily:
            return "毎日"
        case .weekly:
            return "週1回"
        case .monthly:
            return "月1回"
        case .custom:
            return "カスタム"
        }
    }
}

extension HealthAlertSeverity {
    var displayName: String {
        switch self {
        case .low:
            return "軽度"
        case .normal:
            return "通常"
        case .high:
            return "重要"
        case .critical:
            return "緊急"
        }
    }
    
    var color: Color {
        switch self {
        case .low:
            return .green
        case .normal:
            return .blue
        case .high:
            return .orange
        case .critical:
            return .red
        }
    }
}

#Preview {
    NotificationSettingsView()
}