import Foundation

/// Protocol defining badge service operations
protocol BadgeServiceProtocol {
    /// Check for newly earned badges and award them to the user
    /// - Parameter user: The user to check badges for
    /// - Returns: Array of newly earned badges
    /// - Throws: BadgeServiceError if operation fails
    func checkAndAwardBadges(for user: User) async throws -> [Badge]
    
    /// Create and save default badges to the system
    /// - Throws: BadgeServiceError if creation or saving fails
    func createDefaultBadges() async throws
    
    /// Get all available badges for a user (earned and unearned)
    /// - Parameter user: The user to get badges for
    /// - Returns: Array of all badges with earned status
    /// - Throws: BadgeServiceError if fetch operation fails
    func getAllBadges(for user: User) async throws -> [Badge]
    
    /// Get badge progress for a specific requirement
    /// - Parameters:
    ///   - requirement: The badge requirement to check
    ///   - user: The user to check progress for
    /// - Returns: Progress value between 0.0 and 1.0
    /// - Throws: BadgeServiceError if operation fails
    func getBadgeProgress(for requirement: BadgeRequirement, user: User) async throws -> Double
}

/// Badge service implementation
final class BadgeService: BadgeServiceProtocol {
    
    private let badgeRepository: BadgeRepositoryProtocol
    private let healthRecordRepository: HealthRecordRepositoryProtocol
    private let logger: AILoggerProtocol
    
    init(
        badgeRepository: BadgeRepositoryProtocol,
        healthRecordRepository: HealthRecordRepositoryProtocol,
        logger: AILoggerProtocol = AILogger()
    ) {
        self.badgeRepository = badgeRepository
        self.healthRecordRepository = healthRecordRepository
        self.logger = logger
    }
    
    // MARK: - Public Methods
    
    func checkAndAwardBadges(for user: User) async throws -> [Badge] {
        let startTime = Date()
        
        do {
            logger.info("Starting badge check for user", context: [
                "user_id": user.id.uuidString
            ])
            
            // Get all badges and user's earned badges
            let allBadges = try await badgeRepository.fetchAllBadges()
            let earnedBadges = try await badgeRepository.fetchEarnedBadges(for: user)
            let earnedBadgeIds = Set(earnedBadges.map { $0.id })
            
            // Filter unearned badges
            let unearnedBadges = allBadges.filter { !earnedBadgeIds.contains($0.id) }
            
            var newlyEarnedBadges: [Badge] = []
            
            // Check each unearned badge
            for badge in unearnedBadges {
                let requirementMet = try await isRequirementMet(
                    requirement: badge.requirement,
                    for: user
                )
                
                if requirementMet {
                    try await badgeRepository.markAsEarned(badge, for: user)
                    newlyEarnedBadges.append(badge)
                    
                    logger.info("Badge earned", context: [
                        "user_id": user.id.uuidString,
                        "badge_id": badge.id.uuidString,
                        "badge_name": badge.name,
                        "badge_type": badge.type.rawValue
                    ])
                }
            }
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("check_and_award_badges", duration: duration, success: true)
            
            logger.info("Badge check completed", context: [
                "user_id": user.id.uuidString,
                "newly_earned_count": newlyEarnedBadges.count,
                "total_checked": unearnedBadges.count
            ])
            
            return newlyEarnedBadges
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("check_and_award_badges", duration: duration, success: false)
            
            logger.error(error, context: [
                "user_id": user.id.uuidString,
                "operation": "check_and_award_badges"
            ])
            
            throw BadgeServiceError.badgeCheckFailed(underlying: error)
        }
    }
    
    func createDefaultBadges() async throws {
        let startTime = Date()
        
        do {
            logger.info("Creating default badges", context: nil)
            
            let defaultBadges = getDefaultBadgeDefinitions()
            
            // Check which badges already exist
            let existingBadges = try await badgeRepository.fetchAllBadges()
            let existingNames = Set(existingBadges.map { $0.name })
            
            var createdCount = 0
            
            for badgeDefinition in defaultBadges {
                if !existingNames.contains(badgeDefinition.name) {
                    let badge = try Badge(
                        name: badgeDefinition.name,
                        description: badgeDefinition.description,
                        type: badgeDefinition.type,
                        requirement: badgeDefinition.requirement,
                        iconName: badgeDefinition.iconName,
                        colorScheme: badgeDefinition.colorScheme
                    )
                    
                    try await badgeRepository.save(badge)
                    createdCount += 1
                    
                    logger.info("Default badge created", context: [
                        "badge_name": badge.name,
                        "badge_type": badge.type.rawValue
                    ])
                }
            }
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("create_default_badges", duration: duration, success: true)
            
            logger.info("Default badges creation completed", context: [
                "created_count": createdCount,
                "total_definitions": defaultBadges.count
            ])
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("create_default_badges", duration: duration, success: false)
            
            logger.error(error, context: [
                "operation": "create_default_badges"
            ])
            
            throw BadgeServiceError.defaultBadgeCreationFailed(underlying: error)
        }
    }
    
    func getAllBadges(for user: User) async throws -> [Badge] {
        let startTime = Date()
        
        do {
            let allBadges = try await badgeRepository.fetchAllBadges()
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("get_all_badges", duration: duration, success: true)
            
            logger.info("All badges fetched for user", context: [
                "user_id": user.id.uuidString,
                "badge_count": allBadges.count
            ])
            
            return allBadges
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("get_all_badges", duration: duration, success: false)
            
            logger.error(error, context: [
                "user_id": user.id.uuidString,
                "operation": "get_all_badges"
            ])
            
            throw BadgeServiceError.badgeFetchFailed(underlying: error)
        }
    }
    
    func getBadgeProgress(for requirement: BadgeRequirement, user: User) async throws -> Double {
        let startTime = Date()
        
        do {
            let progress = try await calculateProgress(for: requirement, user: user)
            let clampedProgress = min(max(progress, 0.0), 1.0)
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("get_badge_progress", duration: duration, success: true)
            
            return clampedProgress
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("get_badge_progress", duration: duration, success: false)
            
            logger.error(error, context: [
                "user_id": user.id.uuidString,
                "operation": "get_badge_progress"
            ])
            
            throw BadgeServiceError.progressCalculationFailed(underlying: error)
        }
    }
}

// MARK: - Private Methods

private extension BadgeService {
    
    /// Check if a specific badge requirement is met for a user
    func isRequirementMet(requirement: BadgeRequirement, for user: User) async throws -> Bool {
        switch requirement {
        case .recordCount(let count):
            return try await checkRecordCount(targetCount: count, for: user)
            
        case .streak(let days):
            return try await checkConsecutiveStreak(targetDays: days, for: user)
            
        case .milestone(let value):
            return try await checkMilestoneAchievement(targetValue: value, for: user)
            
        case .special:
            return try await checkSpecialCondition(for: user)
        }
    }
    
    /// Calculate progress towards a badge requirement
    func calculateProgress(for requirement: BadgeRequirement, user: User) async throws -> Double {
        switch requirement {
        case .recordCount(let count):
            let currentCount = user.healthRecords.count
            return Double(currentCount) / Double(count)
            
        case .streak(let days):
            let currentStreak = try await getCurrentStreak(for: user)
            return Double(currentStreak) / Double(days)
            
        case .milestone(let value):
            guard let currentWeight = user.currentWeight else { return 0.0 }
            let initialWeight = user.targetWeight + 10.0 // Assume starting 10kg above target
            let progress = (initialWeight - currentWeight) / (initialWeight - value)
            return max(0.0, progress)
            
        case .special:
            return 0.0 // Special badges don't have linear progress
        }
    }
    
    /// Check if user has reached the target record count
    func checkRecordCount(targetCount: Int, for user: User) async throws -> Bool {
        let userRecords = try await healthRecordRepository.fetchRecords(
            for: user,
            type: nil,
            from: nil,
            to: nil
        )
        
        return userRecords.count >= targetCount
    }
    
    /// Check if user has maintained a consecutive recording streak
    func checkConsecutiveStreak(targetDays: Int, for user: User) async throws -> Bool {
        let currentStreak = try await getCurrentStreak(for: user)
        return currentStreak >= targetDays
    }
    
    /// Get current consecutive recording streak for user
    func getCurrentStreak(for user: User) async throws -> Int {
        let userRecords = try await healthRecordRepository.fetchRecords(
            for: user,
            type: nil,
            from: nil,
            to: nil
        )
        
        // Group records by date
        let calendar = Calendar.current
        let recordsByDate = Dictionary(grouping: userRecords) { record in
            calendar.startOfDay(for: record.timestamp)
        }
        
        let sortedDates = recordsByDate.keys.sorted(by: >)
        
        guard !sortedDates.isEmpty else { return 0 }
        
        var streak = 0
        let today = calendar.startOfDay(for: Date())
        
        // Check if there's a record today or yesterday (to allow for timezone differences)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        
        var currentDate = sortedDates.contains(today) ? today : 
                         (sortedDates.contains(yesterday) ? yesterday : sortedDates[0])
        
        // Count backwards from the most recent recording date
        while sortedDates.contains(currentDate) {
            streak += 1
            guard let previousDate = calendar.date(byAdding: .day, value: -1, to: currentDate) else {
                break
            }
            currentDate = previousDate
        }
        
        return streak
    }
    
    /// Check if user has achieved milestone (typically weight-related)
    func checkMilestoneAchievement(targetValue: Double, for user: User) async throws -> Bool {
        guard let currentWeight = user.currentWeight else { return false }
        return currentWeight <= targetValue
    }
    
    /// Check special badge conditions
    func checkSpecialCondition(for user: User) async throws -> Bool {
        // Special badges require custom logic
        // For now, return false - this should be implemented based on specific requirements
        return false
    }
    
    /// Get default badge definitions
    func getDefaultBadgeDefinitions() -> [BadgeDefinition] {
        return [
            // Milestone badges
            BadgeDefinition(
                name: "はじめの一歩",
                description: "初回の健康記録を達成",
                type: .milestone,
                requirement: .recordCount(count: 1),
                iconName: "star.fill",
                colorScheme: .bronze
            ),
            BadgeDefinition(
                name: "記録マスター",
                description: "10回の健康記録を達成",
                type: .milestone,
                requirement: .recordCount(count: 10),
                iconName: "chart.line.uptrend.xyaxis",
                colorScheme: .silver
            ),
            BadgeDefinition(
                name: "データコレクター",
                description: "50回の健康記録を達成",
                type: .milestone,
                requirement: .recordCount(count: 50),
                iconName: "folder.fill",
                colorScheme: .gold
            ),
            
            // Streak badges
            BadgeDefinition(
                name: "継続は力なり",
                description: "7日連続記録を達成",
                type: .streak,
                requirement: .streak(days: 7),
                iconName: "flame.fill",
                colorScheme: .silver
            ),
            BadgeDefinition(
                name: "習慣マスター",
                description: "14日連続記録を達成",
                type: .streak,
                requirement: .streak(days: 14),
                iconName: "calendar",
                colorScheme: .gold
            ),
            BadgeDefinition(
                name: "健康ライフスタイル",
                description: "30日連続記録を達成",
                type: .streak,
                requirement: .streak(days: 30),
                iconName: "crown.fill",
                colorScheme: .platinum
            ),
            
            // Achievement badges
            BadgeDefinition(
                name: "目標達成者",
                description: "体重目標を達成",
                type: .achievement,
                requirement: .milestone(value: 70.0), // Default target weight
                iconName: "target",
                colorScheme: .gold
            ),
            BadgeDefinition(
                name: "健康マスター",
                description: "総合的な健康目標を達成",
                type: .achievement,
                requirement: .special,
                iconName: "heart.fill",
                colorScheme: .platinum
            )
        ]
    }
}

// MARK: - Supporting Types

private struct BadgeDefinition {
    let name: String
    let description: String
    let type: BadgeType
    let requirement: BadgeRequirement
    let iconName: String
    let colorScheme: BadgeColorScheme
}

// MARK: - Error Types

enum BadgeServiceError: LocalizedError {
    case badgeCheckFailed(underlying: Error)
    case defaultBadgeCreationFailed(underlying: Error)
    case badgeFetchFailed(underlying: Error)
    case progressCalculationFailed(underlying: Error)
    case invalidBadgeData(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .badgeCheckFailed(let error):
            return "バッジチェックに失敗しました: \(error.localizedDescription)"
        case .defaultBadgeCreationFailed(let error):
            return "デフォルトバッジの作成に失敗しました: \(error.localizedDescription)"
        case .badgeFetchFailed(let error):
            return "バッジの取得に失敗しました: \(error.localizedDescription)"
        case .progressCalculationFailed(let error):
            return "進捗計算に失敗しました: \(error.localizedDescription)"
        case .invalidBadgeData(let reason):
            return "無効なバッジデータ: \(reason)"
        }
    }
}