import Foundation
import SwiftData

/// Protocol defining the ManageGoalsUseCase interface
/// Handles goal creation, tracking, updating, and progress analysis
protocol ManageGoalsUseCaseProtocol {
    
    /// Create a new goal for the user
    /// - Parameters:
    ///   - user: The user to create the goal for
    ///   - goalData: Goal creation data
    /// - Returns: The created Goal object
    /// - Throws: Use case errors if creation fails
    func createGoal(
        for user: User,
        goalData: GoalCreationData
    ) async throws -> Goal
    
    /// Update an existing goal
    /// - Parameters:
    ///   - goal: The goal to update
    ///   - updates: Updates to apply to the goal
    /// - Returns: The updated Goal object
    /// - Throws: Use case errors if update fails
    func updateGoal(
        _ goal: Goal,
        updates: GoalUpdateData
    ) async throws -> Goal
    
    /// Delete a goal
    /// - Parameter goal: The goal to delete
    /// - Throws: Use case errors if deletion fails
    func deleteGoal(_ goal: Goal) async throws
    
    /// Fetch all active goals for a user
    /// - Parameter user: The user to fetch goals for
    /// - Returns: Array of active Goal objects
    /// - Throws: Use case errors if fetching fails
    func fetchActiveGoals(for user: User) async throws -> [Goal]
    
    /// Fetch all goals (active and inactive) for a user
    /// - Parameter user: The user to fetch goals for
    /// - Returns: Array of all Goal objects
    /// - Throws: Use case errors if fetching fails
    func fetchAllGoals(for user: User) async throws -> [Goal]
    
    /// Update goal progress based on latest health records
    /// - Parameters:
    ///   - goal: The goal to update progress for
    ///   - user: The user who owns the goal
    /// - Returns: The updated Goal with new progress
    /// - Throws: Use case errors if update fails
    func updateGoalProgress(
        _ goal: Goal,
        for user: User
    ) async throws -> Goal
    
    /// Update progress for all active goals of a user
    /// - Parameter user: The user to update goals for
    /// - Returns: Array of updated Goal objects
    /// - Throws: Use case errors if update fails
    func updateAllGoalsProgress(for user: User) async throws -> [Goal]
    
    /// Get goal progress analysis
    /// - Parameters:
    ///   - goal: The goal to analyze
    ///   - user: The user who owns the goal
    /// - Returns: GoalProgressAnalysis containing detailed metrics
    /// - Throws: Use case errors if analysis fails
    func getGoalProgressAnalysis(
        for goal: Goal,
        user: User
    ) async throws -> GoalProgressAnalysis
    
    /// Check if any goals have been completed recently
    /// - Parameters:
    ///   - user: The user to check goals for
    ///   - timeframe: Time period to check (e.g., last 24 hours)
    /// - Returns: Array of recently completed Goal objects
    /// - Throws: Use case errors if check fails
    func checkRecentlyCompletedGoals(
        for user: User,
        timeframe: TimeInterval
    ) async throws -> [Goal]
    
    /// Suggest new goals based on user's health data patterns
    /// - Parameter user: The user to suggest goals for
    /// - Returns: Array of suggested GoalSuggestion objects
    /// - Throws: Use case errors if suggestion generation fails
    func suggestGoals(for user: User) async throws -> [GoalSuggestion]
    
    /// Archive completed or expired goals
    /// - Parameters:
    ///   - user: The user to archive goals for
    ///   - olderThan: Archive goals older than this date
    /// - Returns: Number of goals archived
    /// - Throws: Use case errors if archiving fails
    func archiveOldGoals(
        for user: User,
        olderThan date: Date
    ) async throws -> Int
}

// MARK: - Supporting Data Structures

/// Data structure for creating new goals
struct GoalCreationData {
    let type: HealthDataType
    let targetValue: Double
    let deadline: Date
    let description: String?
    let isRecurring: Bool
    let reminderEnabled: Bool
    
    init(
        type: HealthDataType,
        targetValue: Double,
        deadline: Date,
        description: String? = nil,
        isRecurring: Bool = false,
        reminderEnabled: Bool = true
    ) throws {
        guard targetValue > 0 else {
            throw ValidationError.invalidInput(
                "GoalCreationData",
                value: "\(targetValue)",
                reason: "Target value must be positive"
            )
        }
        
        guard deadline > Date() else {
            throw ValidationError.invalidInput(
                "GoalCreationData",
                value: deadline.description,
                reason: "Deadline must be in the future"
            )
        }
        
        self.type = type
        self.targetValue = targetValue
        self.deadline = deadline
        self.description = description
        self.isRecurring = isRecurring
        self.reminderEnabled = reminderEnabled
    }
}

/// Data structure for updating existing goals
struct GoalUpdateData {
    let targetValue: Double?
    let deadline: Date?
    let description: String?
    let isActive: Bool?
    let reminderEnabled: Bool?
    
    init(
        targetValue: Double? = nil,
        deadline: Date? = nil,
        description: String? = nil,
        isActive: Bool? = nil,
        reminderEnabled: Bool? = nil
    ) throws {
        if let target = targetValue {
            guard target > 0 else {
                throw ValidationError.invalidInput(
                    "GoalUpdateData",
                    value: "\(target)",
                    reason: "Target value must be positive"
                )
            }
        }
        
        if let newDeadline = deadline {
            guard newDeadline > Date() else {
                throw ValidationError.invalidInput(
                    "GoalUpdateData",
                    value: newDeadline.description,
                    reason: "New deadline must be in the future"
                )
            }
        }
        
        self.targetValue = targetValue
        self.deadline = deadline
        self.description = description
        self.isActive = isActive
        self.reminderEnabled = reminderEnabled
    }
}

/// Detailed analysis of goal progress
struct GoalProgressAnalysis {
    let goal: Goal
    let currentProgress: Double // 0.0 to 1.0
    let progressVelocity: Double // Progress per day
    let estimatedCompletionDate: Date?
    let daysRemaining: Int
    let isOnTrack: Bool
    let riskLevel: GoalRiskLevel
    let recommendations: [String]
    let historicalProgress: [GoalProgressPoint]
    let analysisDate: Date
    
    init(goal: Goal, healthRecords: [HealthRecord]) {
        self.goal = goal
        self.analysisDate = Date()
        
        // Calculate current progress
        let relevantRecords = healthRecords
            .filter { $0.type == goal.type }
            .sorted { $0.timestamp > $1.timestamp }
        
        if let latestRecord = relevantRecords.first {
            goal.currentValue = latestRecord.value
        }
        
        self.currentProgress = min(goal.progress, 1.0)
        
        // Calculate days remaining
        let calendar = Calendar.current
        self.daysRemaining = max(0, calendar.dateComponents([.day], from: Date(), to: goal.deadline).day ?? 0)
        
        // Calculate progress velocity (progress per day)
        let goalAge = calendar.dateComponents([.day], from: goal.createdAt, to: Date()).day ?? 1
        self.progressVelocity = goalAge > 0 ? currentProgress / Double(goalAge) : 0.0
        
        // Estimate completion date based on current velocity
        if progressVelocity > 0 {
            let remainingProgress = 1.0 - currentProgress
            let daysToComplete = remainingProgress / progressVelocity
            self.estimatedCompletionDate = calendar.date(byAdding: .day, value: Int(daysToComplete), to: Date())
        } else {
            self.estimatedCompletionDate = nil
        }
        
        // Determine if on track
        self.isOnTrack = (estimatedCompletionDate?.timeIntervalSince1970 ?? Double.infinity) <= goal.deadline.timeIntervalSince1970
        
        // Assess risk level
        if currentProgress >= 0.9 {
            self.riskLevel = .low
        } else if isOnTrack && daysRemaining > 7 {
            self.riskLevel = .low
        } else if isOnTrack && daysRemaining > 3 {
            self.riskLevel = .medium
        } else {
            self.riskLevel = .high
        }
        
        // Generate recommendations
        var recommendations: [String] = []
        
        switch riskLevel {
        case .low:
            recommendations.append("目標達成まで順調に進んでいます")
            if currentProgress < 1.0 {
                recommendations.append("この調子で継続しましょう")
            }
        case .medium:
            recommendations.append("目標達成のために少しペースアップが必要です")
            recommendations.append("毎日の記録を確認して継続的な改善を心がけましょう")
        case .high:
            if daysRemaining > 0 {
                recommendations.append("目標達成が厳しい状況です。期限の延長を検討してください")
                recommendations.append("より実現可能な中間目標を設定することをお勧めします")
            } else {
                recommendations.append("期限が過ぎています。目標を見直すか新しい目標を設定しましょう")
            }
        }
        
        self.recommendations = recommendations
        
        // Generate historical progress points (simplified)
        var progressPoints: [GoalProgressPoint] = []
        let pointsCount = min(30, goalAge) // Last 30 days or goal age
        
        for i in 0..<pointsCount {
            let date = calendar.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            let recordsUpToDate = healthRecords
                .filter { $0.type == goal.type && $0.timestamp <= date }
                .sorted { $0.timestamp > $1.timestamp }
            
            let progressValue = recordsUpToDate.isEmpty ? 0.0 : min(recordsUpToDate.first!.value / goal.targetValue, 1.0)
            
            progressPoints.append(GoalProgressPoint(
                date: date,
                progress: progressValue,
                value: recordsUpToDate.first?.value ?? 0.0
            ))
        }
        
        self.historicalProgress = progressPoints.reversed()
    }
}

/// Risk level for goal completion
enum GoalRiskLevel: String, CaseIterable {
    case low = "低"
    case medium = "中"
    case high = "高"
    
    var description: String {
        switch self {
        case .low:
            return "目標達成の可能性が高い"
        case .medium:
            return "目標達成にはペースアップが必要"
        case .high:
            return "目標達成が困難な状況"
        }
    }
}

/// Point in time progress data for historical analysis
struct GoalProgressPoint {
    let date: Date
    let progress: Double // 0.0 to 1.0
    let value: Double // Actual health data value
    
    init(date: Date, progress: Double, value: Double) {
        self.date = date
        self.progress = max(0.0, min(1.0, progress)) // Clamp between 0 and 1
        self.value = value
    }
}

/// Goal suggestion generated by AI analysis
struct GoalSuggestion {
    let type: HealthDataType
    let suggestedTargetValue: Double
    let suggestedDeadline: Date
    let reasoning: String
    let confidenceLevel: Double // 0.0 to 1.0
    let basedOnData: GoalSuggestionData
    
    init(
        type: HealthDataType,
        suggestedTargetValue: Double,
        suggestedDeadline: Date,
        reasoning: String,
        confidenceLevel: Double,
        basedOnData: GoalSuggestionData
    ) {
        self.type = type
        self.suggestedTargetValue = suggestedTargetValue
        self.suggestedDeadline = suggestedDeadline
        self.reasoning = reasoning
        self.confidenceLevel = max(0.0, min(1.0, confidenceLevel))
        self.basedOnData = basedOnData
    }
}

/// Data used for generating goal suggestions
struct GoalSuggestionData {
    let averageValue: Double
    let recentTrend: TrendDirection
    let dataPoints: Int
    let timespan: TimeInterval
    let lastGoalPerformance: Double? // Previous goal completion rate
    
    init(
        averageValue: Double,
        recentTrend: TrendDirection,
        dataPoints: Int,
        timespan: TimeInterval,
        lastGoalPerformance: Double? = nil
    ) {
        self.averageValue = averageValue
        self.recentTrend = recentTrend
        self.dataPoints = dataPoints
        self.timespan = timespan
        self.lastGoalPerformance = lastGoalPerformance
    }
}

/// Type of goal for categorization
enum GoalCategory: String, CaseIterable {
    case fitness = "フィットネス"
    case weight = "体重管理"
    case health = "健康維持"
    case performance = "パフォーマンス"
    
    /// Get appropriate goal category for a health data type
    static func category(for dataType: HealthDataType) -> GoalCategory {
        switch dataType {
        case .weight:
            return .weight
        case .steps, .calories:
            return .fitness
        case .heartRate:
            return .performance
        case .bloodGlucose:
            return .health
        }
    }
}

/// Goal achievement status for reporting
enum GoalAchievementStatus: String, CaseIterable {
    case notStarted = "未開始"
    case inProgress = "進行中"
    case completed = "達成"
    case failed = "未達成"
    case expired = "期限切れ"
    
    /// Determine status based on goal state
    static func status(for goal: Goal) -> GoalAchievementStatus {
        if goal.isCompleted {
            return .completed
        } else if goal.isExpired {
            return goal.progress > 0 ? .failed : .expired
        } else if goal.progress > 0 {
            return .inProgress
        } else {
            return .notStarted
        }
    }
}