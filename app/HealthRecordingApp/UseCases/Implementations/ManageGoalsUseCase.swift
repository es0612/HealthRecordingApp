import Foundation
import SwiftData

/// Use Case for managing user goals
/// Implements comprehensive goal creation, tracking, analysis, and suggestion capabilities
final class ManageGoalsUseCase: ManageGoalsUseCaseProtocol {
    
    // MARK: - Dependencies
    
    private let goalRepository: GoalRepositoryProtocol
    private let healthRecordRepository: HealthRecordRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let logger: AILoggerProtocol
    
    // MARK: - Initialization
    
    init(
        goalRepository: GoalRepositoryProtocol,
        healthRecordRepository: HealthRecordRepositoryProtocol,
        userRepository: UserRepositoryProtocol,
        logger: AILoggerProtocol
    ) {
        self.goalRepository = goalRepository
        self.healthRecordRepository = healthRecordRepository
        self.userRepository = userRepository
        self.logger = logger
    }
    
    // MARK: - ManageGoalsUseCaseProtocol Implementation
    
    func createGoal(
        for user: User,
        goalData: GoalCreationData
    ) async throws -> Goal {
        
        let startTime = Date()
        logger.info("Creating goal", context: [
            "user_id": user.id.uuidString,
            "goal_type": goalData.type.rawValue,
            "target_value": goalData.targetValue,
            "deadline": goalData.deadline.ISO8601Format()
        ])
        
        do {
            // Validate user exists
            let currentUser = try await userRepository.fetchCurrentUser()
            guard currentUser?.id == user.id else {
                throw ValidationError.invalidInput("User", value: user.id.uuidString, reason: "User not found or not current user")
            }
            
            // Create new goal
            let goal = try Goal(
                type: goalData.type,
                targetValue: goalData.targetValue,
                deadline: goalData.deadline
            )
            goal.user = user
            
            // Save the goal
            try await goalRepository.save(goal)
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("create_goal", duration: duration, success: true)
            logger.info("Successfully created goal", context: [
                "goal_id": goal.id.uuidString,
                "execution_time": duration
            ])
            
            return goal
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("create_goal", duration: duration, success: false)
            logger.error(error, context: [
                "user_id": user.id.uuidString,
                "goal_type": goalData.type.rawValue
            ])
            throw error
        }
    }
    
    func updateGoal(
        _ goal: Goal,
        updates: GoalUpdateData
    ) async throws -> Goal {
        
        logger.info("Updating goal", context: [
            "goal_id": goal.id.uuidString,
            "has_target_update": updates.targetValue != nil,
            "has_deadline_update": updates.deadline != nil
        ])
        
        do {
            // Apply updates
            if let targetValue = updates.targetValue {
                goal.targetValue = targetValue
            }
            
            if let deadline = updates.deadline {
                goal.deadline = deadline
            }
            
            if let isActive = updates.isActive {
                goal.isActive = isActive
            }
            
            // Save updated goal
            try await goalRepository.save(goal)
            
            logger.info("Successfully updated goal", context: [
                "goal_id": goal.id.uuidString,
                "new_target": goal.targetValue
            ])
            
            return goal
            
        } catch {
            logger.error(error, context: [
                "goal_id": goal.id.uuidString
            ])
            throw error
        }
    }
    
    func deleteGoal(_ goal: Goal) async throws {
        
        logger.info("Deleting goal", context: [
            "goal_id": goal.id.uuidString,
            "goal_type": goal.type.rawValue
        ])
        
        do {
            try await goalRepository.delete(goal)
            
            logger.info("Successfully deleted goal", context: [
                "goal_id": goal.id.uuidString
            ])
            
        } catch {
            logger.error(error, context: [
                "goal_id": goal.id.uuidString
            ])
            throw error
        }
    }
    
    func fetchActiveGoals(for user: User) async throws -> [Goal] {
        
        logger.info("Fetching active goals", context: [
            "user_id": user.id.uuidString
        ])
        
        do {
            // Validate user
            let currentUser = try await userRepository.fetchCurrentUser()
            guard currentUser?.id == user.id else {
                throw ValidationError.invalidInput("User", value: user.id.uuidString, reason: "User not found or not current user")
            }
            
            let goals = try await goalRepository.fetchGoals(for: user, activeOnly: true)
            
            logger.info("Successfully fetched active goals", context: [
                "goals_count": goals.count
            ])
            
            return goals
            
        } catch {
            logger.error(error, context: [
                "user_id": user.id.uuidString
            ])
            throw error
        }
    }
    
    func fetchAllGoals(for user: User) async throws -> [Goal] {
        
        logger.info("Fetching all goals", context: [
            "user_id": user.id.uuidString
        ])
        
        do {
            // Validate user
            let currentUser = try await userRepository.fetchCurrentUser()
            guard currentUser?.id == user.id else {
                throw ValidationError.invalidInput("User", value: user.id.uuidString, reason: "User not found or not current user")
            }
            
            let goals = try await goalRepository.fetchGoals(for: user, activeOnly: false)
            
            logger.info("Successfully fetched all goals", context: [
                "goals_count": goals.count
            ])
            
            return goals
            
        } catch {
            logger.error(error, context: [
                "user_id": user.id.uuidString
            ])
            throw error
        }
    }
    
    func updateGoalProgress(
        _ goal: Goal,
        for user: User
    ) async throws -> Goal {
        
        logger.info("Updating goal progress", context: [
            "goal_id": goal.id.uuidString,
            "goal_type": goal.type.rawValue
        ])
        
        do {
            // Fetch relevant health records
            let healthRecords = try await healthRecordRepository.fetchRecords(
                for: user,
                type: goal.type,
                from: nil,
                to: nil
            )
            
            // Update goal with latest value
            if let latestRecord = healthRecords.max(by: { $0.timestamp < $1.timestamp }) {
                goal.currentValue = latestRecord.value
            }
            
            // Save updated goal
            try await goalRepository.save(goal)
            
            logger.info("Successfully updated goal progress", context: [
                "goal_id": goal.id.uuidString,
                "current_value": goal.currentValue,
                "progress": goal.progress
            ])
            
            return goal
            
        } catch {
            logger.error(error, context: [
                "goal_id": goal.id.uuidString
            ])
            throw error
        }
    }
    
    func updateAllGoalsProgress(for user: User) async throws -> [Goal] {
        
        logger.info("Updating all goals progress", context: [
            "user_id": user.id.uuidString
        ])
        
        do {
            let activeGoals = try await fetchActiveGoals(for: user)
            var updatedGoals: [Goal] = []
            
            for goal in activeGoals {
                let updatedGoal = try await updateGoalProgress(goal, for: user)
                updatedGoals.append(updatedGoal)
            }
            
            logger.info("Successfully updated all goals progress", context: [
                "updated_goals_count": updatedGoals.count
            ])
            
            return updatedGoals
            
        } catch {
            logger.error(error, context: [
                "user_id": user.id.uuidString
            ])
            throw error
        }
    }
    
    func getGoalProgressAnalysis(
        for goal: Goal,
        user: User
    ) async throws -> GoalProgressAnalysis {
        
        logger.info("Analyzing goal progress", context: [
            "goal_id": goal.id.uuidString,
            "goal_type": goal.type.rawValue
        ])
        
        do {
            // Fetch relevant health records for analysis
            let healthRecords = try await healthRecordRepository.fetchRecords(
                for: user,
                type: goal.type,
                from: goal.createdAt,
                to: Date()
            )
            
            // Create analysis
            let analysis = GoalProgressAnalysis(goal: goal, healthRecords: healthRecords)
            
            logger.info("Successfully analyzed goal progress", context: [
                "goal_id": goal.id.uuidString,
                "current_progress": analysis.currentProgress,
                "risk_level": analysis.riskLevel.rawValue,
                "days_remaining": analysis.daysRemaining
            ])
            
            return analysis
            
        } catch {
            logger.error(error, context: [
                "goal_id": goal.id.uuidString
            ])
            throw error
        }
    }
    
    func checkRecentlyCompletedGoals(
        for user: User,
        timeframe: TimeInterval
    ) async throws -> [Goal] {
        
        logger.info("Checking recently completed goals", context: [
            "user_id": user.id.uuidString,
            "timeframe_hours": timeframe / 3600
        ])
        
        do {
            let allGoals = try await fetchAllGoals(for: user)
            let cutoffDate = Date().addingTimeInterval(-timeframe)
            
            let recentlyCompleted = allGoals.filter { goal in
                goal.isCompleted && 
                (goal.deadline > cutoffDate || goal.createdAt > cutoffDate)
            }
            
            logger.info("Found recently completed goals", context: [
                "completed_goals_count": recentlyCompleted.count
            ])
            
            return recentlyCompleted
            
        } catch {
            logger.error(error, context: [
                "user_id": user.id.uuidString
            ])
            throw error
        }
    }
    
    func suggestGoals(for user: User) async throws -> [GoalSuggestion] {
        
        logger.info("Generating goal suggestions", context: [
            "user_id": user.id.uuidString
        ])
        
        do {
            var suggestions: [GoalSuggestion] = []
            
            // Analyze each health data type for suggestions
            let healthDataTypes: [HealthDataType] = [.weight, .steps, .calories, .heartRate]
            
            for dataType in healthDataTypes {
                if let suggestion = try await generateGoalSuggestion(for: dataType, user: user) {
                    suggestions.append(suggestion)
                }
            }
            
            logger.info("Successfully generated goal suggestions", context: [
                "suggestions_count": suggestions.count
            ])
            
            return suggestions
            
        } catch {
            logger.error(error, context: [
                "user_id": user.id.uuidString
            ])
            throw error
        }
    }
    
    func archiveOldGoals(
        for user: User,
        olderThan date: Date
    ) async throws -> Int {
        
        logger.info("Archiving old goals", context: [
            "user_id": user.id.uuidString,
            "cutoff_date": date.ISO8601Format()
        ])
        
        do {
            let allGoals = try await fetchAllGoals(for: user)
            
            let goalsToArchive = allGoals.filter { goal in
                (goal.isCompleted || goal.isExpired) && goal.deadline < date
            }
            
            var archivedCount = 0
            for goal in goalsToArchive {
                goal.isActive = false
                try await goalRepository.save(goal)
                archivedCount += 1
            }
            
            logger.info("Successfully archived old goals", context: [
                "archived_count": archivedCount
            ])
            
            return archivedCount
            
        } catch {
            logger.error(error, context: [
                "user_id": user.id.uuidString
            ])
            throw error
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func generateGoalSuggestion(
        for dataType: HealthDataType,
        user: User
    ) async throws -> GoalSuggestion? {
        
        // Fetch recent health records for this data type
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .month, value: -3, to: endDate) ?? endDate
        
        let healthRecords = try await healthRecordRepository.fetchRecords(
            for: user,
            type: dataType,
            from: startDate,
            to: endDate
        )
        
        guard healthRecords.count >= 5 else {
            // Not enough data for meaningful suggestion
            return nil
        }
        
        // Calculate statistics
        let values = healthRecords.map { $0.value }
        let averageValue = values.reduce(0, +) / Double(values.count)
        
        // Determine trend
        let recentValues = values.suffix(10)
        let olderValues = values.prefix(10)
        
        let recentAverage = recentValues.isEmpty ? 0 : recentValues.reduce(0, +) / Double(recentValues.count)
        let olderAverage = olderValues.isEmpty ? 0 : olderValues.reduce(0, +) / Double(olderValues.count)
        
        let trend: TrendDirection
        if recentAverage > olderAverage * 1.05 {
            trend = .increasing
        } else if recentAverage < olderAverage * 0.95 {
            trend = .decreasing
        } else {
            trend = .stable
        }
        
        // Generate suggestion based on data type and trends
        let (targetValue, reasoning, confidence) = generateSuggestionParameters(
            for: dataType,
            currentAverage: averageValue,
            trend: trend,
            user: user
        )
        
        let suggestedDeadline = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        
        let suggestionData = GoalSuggestionData(
            averageValue: averageValue,
            recentTrend: trend,
            dataPoints: healthRecords.count,
            timespan: endDate.timeIntervalSince(startDate)
        )
        
        return GoalSuggestion(
            type: dataType,
            suggestedTargetValue: targetValue,
            suggestedDeadline: suggestedDeadline,
            reasoning: reasoning,
            confidenceLevel: confidence,
            basedOnData: suggestionData
        )
    }
    
    private func generateSuggestionParameters(
        for dataType: HealthDataType,
        currentAverage: Double,
        trend: TrendDirection,
        user: User
    ) -> (targetValue: Double, reasoning: String, confidence: Double) {
        
        switch dataType {
        case .weight:
            let targetWeight = user.targetWeight
            let improvement = abs(currentAverage - targetWeight) * 0.3 // 30% improvement
            let target = currentAverage > targetWeight ? currentAverage - improvement : currentAverage + improvement
            
            let reasoning = trend == .increasing ? 
                "体重が増加傾向にあります。適度な減量目標を設定することをお勧めします。" :
                "現在の体重から理想体重に向けて段階的な目標を設定しましょう。"
            
            return (target, reasoning, 0.8)
            
        case .steps:
            let improvement = currentAverage * 0.2 // 20% increase
            let target = currentAverage + improvement
            
            let reasoning = trend == .increasing ?
                "歩数が順調に増えています。さらなる向上を目指しましょう。" :
                "日常の活動量を増やすため、現在より少し高めの目標を設定しました。"
            
            return (target, reasoning, 0.7)
            
        case .calories:
            let adjustment = trend == .increasing ? -currentAverage * 0.1 : currentAverage * 0.1
            let target = currentAverage + adjustment
            
            let reasoning = "カロリー消費量の最適化を目指した目標です。"
            
            return (target, reasoning, 0.6)
            
        case .heartRate:
            // For heart rate, suggest maintaining current level
            let target = currentAverage
            let reasoning = "現在の心拍数レベルを維持することを目標にしましょう。"
            
            return (target, reasoning, 0.5)
            
        case .bloodGlucose:
            let target = currentAverage
            let reasoning = "血糖値の安定した管理を目標にしましょう。"
            
            return (target, reasoning, 0.6)
        }
    }
}