import SwiftUI
import SwiftData

/// Card displaying badge collection and progress
/// Shows earned badges, progress towards unearned badges, and streak information
struct BadgeProgressCard: View {
    @State private var badges: [Badge] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentStreak = 0
    @State private var showingBadgeCelebration = false
    @State private var celebrationBadge: Badge?
    
    // Mock service for now - should be injected
    private let badgeService = BadgeService(
        badgeRepository: SwiftDataBadgeRepository(
            modelContext: ModelContainer.shared.mainContext
        ),
        healthRecordRepository: SwiftDataHealthRecordRepository(
            modelContext: ModelContainer.shared.mainContext
        )
    )
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with streak indicator
            headerView
            
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else {
                contentView
            }
        }
        .padding()
        .background(Color(.controlColor))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        .sheet(isPresented: $showingBadgeCelebration) {
            if let badge = celebrationBadge {
                BadgeEarnedCelebrationView(badge: badge) {
                    showingBadgeCelebration = false
                    celebrationBadge = nil
                }
            }
        }
        .onAppear {
            Task {
                await loadBadges()
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("バッジコレクション")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("獲得済み: \(earnedBadges.count)/\(badges.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            StreakIndicatorView(
                streakCount: currentStreak,
                isActive: currentStreak > 0
            )
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("バッジを読み込み中...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 120)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("エラーが発生しました")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("再試行") {
                Task {
                    await loadBadges()
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(height: 120)
    }
    
    private var contentView: some View {
        VStack(spacing: 16) {
            // Earned badges showcase
            if !earnedBadges.isEmpty {
                earnedBadgesSection
            }
            
            // Progress towards next badges
            if !unearnedBadges.isEmpty {
                progressSection
            }
            
            // All badges grid
            allBadgesGrid
        }
    }
    
    private var earnedBadgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近獲得したバッジ")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("すべて表示") {
                    // TODO: Navigate to full badge collection
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recentEarnedBadges, id: \.id) { badge in
                        BadgeViewCompact(badge: badge)
                            .onTapGesture {
                                showBadgeDetails(badge)
                            }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("次のバッジまで")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            ForEach(Array(nextBadgesWithProgress.prefix(2)), id: \.badge.id) { item in
                BadgeProgressRow(
                    badge: item.badge,
                    progress: item.progress
                )
            }
        }
    }
    
    private var allBadgesGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("すべてのバッジ")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(badges.prefix(8), id: \.id) { badge in
                    BadgeViewCompact(badge: badge)
                        .onTapGesture {
                            showBadgeDetails(badge)
                        }
                }
                
                if badges.count > 8 {
                    Button(action: {
                        // TODO: Navigate to full badge collection
                    }) {
                        VStack {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                            
                            Text("他\(badges.count - 8)個")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 40, height: 40)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                    }
                }
            }
        }
    }
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
    }
    
    // MARK: - Computed Properties
    
    private var earnedBadges: [Badge] {
        badges.filter { $0.isEarned }
    }
    
    private var unearnedBadges: [Badge] {
        badges.filter { !$0.isEarned }
    }
    
    private var recentEarnedBadges: [Badge] {
        earnedBadges
            .sorted { ($0.earnedDate ?? Date.distantPast) > ($1.earnedDate ?? Date.distantPast) }
            .prefix(5)
            .compactMap { $0 }
    }
    
    private var nextBadgesWithProgress: [(badge: Badge, progress: Double)] {
        // Mock progress calculation - should use BadgeService
        unearnedBadges.map { badge in
            let mockProgress = Double.random(in: 0.1...0.9)
            return (badge: badge, progress: mockProgress)
        }
        .sorted { $0.progress > $1.progress }
    }
    
    // MARK: - Actions
    
    private func loadBadges() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Create default badges if needed
            try await badgeService.createDefaultBadges()
            
            // Load user badges (using mock user for now)
            let mockUser = try User(name: "Mock User", age: 30, height: 170.0, targetWeight: 65.0)
            badges = try await badgeService.getAllBadges(for: mockUser)
            
            // Check for new badge achievements
            let newBadges = try await badgeService.checkAndAwardBadges(for: mockUser)
            if let newBadge = newBadges.first {
                celebrationBadge = newBadge
                showingBadgeCelebration = true
            }
            
            // Load current streak (mock for now)
            currentStreak = Int.random(in: 0...15)
            
        } catch {
            errorMessage = "バッジの読み込みに失敗しました: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func showBadgeDetails(_ badge: Badge) {
        // TODO: Navigate to badge detail view or show detail sheet
        if badge.isEarned {
            celebrationBadge = badge
            showingBadgeCelebration = true
        }
    }
}

/// Row showing progress towards a specific badge
struct BadgeProgressRow: View {
    let badge: Badge
    let progress: Double
    
    var body: some View {
        HStack(spacing: 12) {
            BadgeViewCompact(badge: badge)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(badge.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(badge.displayDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: badge.colorScheme.accent)))
                    .scaleEffect(x: 1, y: 0.8)
            }
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: badge.colorScheme.accent))
                
                Text("完了")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Mock Model Container Extension

extension ModelContainer {
    static var shared: ModelContainer = {
        do {
            let schema = Schema([
                HealthRecord.self,
                User.self,
                Goal.self,
                Badge.self
            ])
            
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
            
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
}

// MARK: - Previews

#Preview("Badge Progress Card") {
    BadgeProgressCard()
        .padding()
}