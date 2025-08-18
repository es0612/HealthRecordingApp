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
        // Get user's health records for analysis
        let userRecords = try await healthRecordRepository.fetchRecords(
            for: user,
            type: nil,
            from: nil,
            to: nil
        )
        
        let calendar = Calendar.current
        let now = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        let recentRecords = userRecords.filter { $0.timestamp >= thirtyDaysAgo }
        
        // Special condition 1: Perfect Week (7 consecutive days with all data types)
        if checkPerfectWeek(records: recentRecords) {
            return true
        }
        
        // Special condition 2: Health Diversity (recorded 5+ different data types in a week)
        if checkHealthDiversity(records: recentRecords) {
            return true
        }
        
        // Special condition 3: Early Bird (recorded data before 8 AM for 5 consecutive days)
        if checkEarlyBird(records: recentRecords) {
            return true
        }
        
        // Special condition 4: Weekend Warrior (consistent weekend recording for 4 weeks)
        if checkWeekendWarrior(records: userRecords) {
            return true
        }
        
        // Special condition 5: Improvement Streak (showing improvement for 14 consecutive days)
        if try await checkImprovementStreak(records: recentRecords, for: user) {
            return true
        }
        
        return false
    }
    
    private func checkPerfectWeek(records: [HealthRecord]) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        // Check last 7 days
        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let dayStart = calendar.startOfDay(for: day)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            
            let dayRecords = records.filter { record in
                record.timestamp >= dayStart && record.timestamp < dayEnd
            }
            
            let recordedTypes = Set(dayRecords.map { $0.type })
            // Perfect day requires at least 3 different data types
            if recordedTypes.count < 3 {
                return false
            }
        }
        
        return true
    }
    
    private func checkHealthDiversity(records: [HealthRecord]) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        
        let weekRecords = records.filter { $0.timestamp >= oneWeekAgo }
        let uniqueTypes = Set(weekRecords.map { $0.type })
        
        return uniqueTypes.count >= 5
    }
    
    private func checkEarlyBird(records: [HealthRecord]) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        var consecutiveDays = 0
        
        for dayOffset in 0..<14 { // Check last 14 days for 5 consecutive
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let dayStart = calendar.startOfDay(for: day)
            let morningEnd = calendar.date(byAdding: .hour, value: 8, to: dayStart) ?? dayStart
            
            let morningRecords = records.filter { record in
                record.timestamp >= dayStart && record.timestamp <= morningEnd
            }
            
            if !morningRecords.isEmpty {
                consecutiveDays += 1
                if consecutiveDays >= 5 {
                    return true
                }
            } else {
                consecutiveDays = 0
            }
        }
        
        return false
    }
    
    private func checkWeekendWarrior(records: [HealthRecord]) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        var weekendStreaks = 0
        
        // Check last 8 weeks for 4 consecutive weekend recordings
        for weekOffset in 0..<8 {
            guard let week = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: now) else { continue }
            
            // Get Saturday and Sunday of this week
            let weekdays = (1...7).compactMap { dayOffset in
                calendar.date(byAdding: .day, value: dayOffset - calendar.component(.weekday, from: week), to: week)
            }
            
            guard weekdays.count >= 7 else { continue }
            let saturday = weekdays[5] // Saturday (index 5 for Saturday)
            let sunday = weekdays[6]   // Sunday (index 6 for Sunday)
            
            let weekendRecords = records.filter { record in
                let day = calendar.startOfDay(for: record.timestamp)
                return day == calendar.startOfDay(for: saturday) || day == calendar.startOfDay(for: sunday)
            }
            
            if !weekendRecords.isEmpty {
                weekendStreaks += 1
                if weekendStreaks >= 4 {
                    return true
                }
            } else {
                weekendStreaks = 0
            }
        }
        
        return false
    }
    
    private func checkImprovementStreak(records: [HealthRecord], for user: User) async throws -> Bool {
        // Focus on weight improvement for this special condition
        let weightRecords = records.filter { $0.type == .weight }
            .sorted { $0.timestamp < $1.timestamp }
        
        guard weightRecords.count >= 14 else { return false }
        
        let calendar = Calendar.current
        let now = Date()
        
        var improvementDays = 0
        var lastWeight: Double?
        
        // Check last 14 days for consistent improvement
        for dayOffset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let dayStart = calendar.startOfDay(for: day)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            
            let dayWeightRecords = weightRecords.filter { record in
                record.timestamp >= dayStart && record.timestamp < dayEnd
            }
            
            if let currentWeight = dayWeightRecords.last?.value {
                if let previous = lastWeight {
                    // Improvement means weight is decreasing (assuming weight loss goal)
                    if currentWeight <= previous {
                        improvementDays += 1
                    } else {
                        improvementDays = 0
                    }
                }
                lastWeight = currentWeight
            }
        }
        
        return improvementDays >= 14
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
            ),
            
            // Enhanced Special Badges
            BadgeDefinition(
                name: "パーフェクトウィーク",
                description: "7日間連続で多様な健康データを記録",
                type: .special,
                requirement: .special,
                iconName: "star.circle.fill",
                colorScheme: .gold
            ),
            BadgeDefinition(
                name: "データマニア",
                description: "1週間で5種類以上のデータを記録",
                type: .special,
                requirement: .special,
                iconName: "chart.bar.fill",
                colorScheme: .silver
            ),
            BadgeDefinition(
                name: "早起きの鳥",
                description: "5日連続で朝8時前にデータを記録",
                type: .special,
                requirement: .special,
                iconName: "sunrise.fill",
                colorScheme: .gold
            ),
            BadgeDefinition(
                name: "ウィークエンドウォリアー",
                description: "4週連続で週末にデータを記録",
                type: .special,
                requirement: .special,
                iconName: "calendar.badge.plus",
                colorScheme: .silver
            ),
            BadgeDefinition(
                name: "改善ストリーク",
                description: "14日連続で健康指標が改善",
                type: .special,
                requirement: .special,
                iconName: "chart.line.uptrend.xyaxis",
                colorScheme: .platinum
            ),
            
            // Extended Milestone Badges
            BadgeDefinition(
                name: "センチュリオン",
                description: "100回の健康記録を達成",
                type: .milestone,
                requirement: .recordCount(count: 100),
                iconName: "100.square.fill",
                colorScheme: .platinum
            ),
            BadgeDefinition(
                name: "レジェンド",
                description: "365回の健康記録を達成",
                type: .milestone,
                requirement: .recordCount(count: 365),
                iconName: "crown.fill",
                colorScheme: .platinum
            ),
            
            // Extended Streak Badges
            BadgeDefinition(
                name: "アイアンウィル",
                description: "60日連続記録を達成",
                type: .streak,
                requirement: .streak(days: 60),
                iconName: "shield.fill",
                colorScheme: .gold
            ),
            BadgeDefinition(
                name: "不屈の精神",
                description: "90日連続記録を達成",
                type: .streak,
                requirement: .streak(days: 90),
                iconName: "medal.fill",
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