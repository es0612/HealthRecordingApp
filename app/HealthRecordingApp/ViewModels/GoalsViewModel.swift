import SwiftUI
import SwiftData
import Foundation

@Observable
final class GoalsViewModel {
    // MARK: - Published Properties
    var goals: [Goal] = []
    var activeGoals: [Goal] = []
    var completedGoals: [Goal] = []
    var expiredGoals: [Goal] = []
    var goalSuggestions: [GoalSuggestion] = []
    var isLoading = false
    var errorMessage: String?
    var selectedGoal: Goal?
    var goalProgressDetails: [UUID: GoalProgressDetail] = [:]
    var isSaving = false
    
    // MARK: - Computed Properties
    var hasActiveGoals: Bool {
        !activeGoals.isEmpty
    }
    
    var activeGoalCount: Int {
        activeGoals.count
    }
    
    var completedGoalCount: Int {
        completedGoals.count
    }
    
    var overallProgress: Double {
        guard !activeGoals.isEmpty else { return 0.0 }
        let totalProgress = activeGoals.reduce(0.0) { $0 + $1.progress }
        return totalProgress / Double(activeGoals.count)
    }
    
    var goalsNeedingAttention: [Goal] {
        activeGoals.filter { goal in
            if let detail = goalProgressDetails[goal.id] {
                return detail.motivationLevel == .critical || detail.motivationLevel == .low
            }
            return goal.isExpired || goal.progress < 0.1
        }
    }
    
    var onTrackGoalsCount: Int {
        activeGoals.filter { goal in
            if let detail = goalProgressDetails[goal.id] {
                return detail.isOnTrack
            }
            return goal.progress >= 0.5
        }.count
    }
    
    // MARK: - Dependencies
    private let manageGoalsUseCase: ManageGoalsUseCaseProtocol
    private let fetchHealthDataUseCase: FetchHealthDataUseCaseProtocol
    private let goalTracker: GoalTrackerProtocol
    private let logger: AILoggerProtocol
    
    // MARK: - Initialization
    init(
        manageGoalsUseCase: ManageGoalsUseCaseProtocol,
        fetchHealthDataUseCase: FetchHealthDataUseCaseProtocol,
        goalTracker: GoalTrackerProtocol = GoalTracker(),
        logger: AILoggerProtocol = AILogger()
    ) {
        self.manageGoalsUseCase = manageGoalsUseCase
        self.fetchHealthDataUseCase = fetchHealthDataUseCase
        self.goalTracker = goalTracker
        self.logger = logger
        
        logger.debug("GoalsViewModel initialized", context: nil)
    }
    
    // MARK: - Data Loading
    @MainActor
    func loadGoals() async {
        logger.debug("Starting goals load", context: nil)
        guard !isLoading else {
            logger.warning("Load already in progress, skipping", context: nil)
            return
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let startTime = Date()
            logger.info("Loading all goals", context: nil)
            
            // Get mock user - this will be replaced with proper user management
            let mockUser = createMockUser()
            
            // Fetch all goals
            let allGoals = try await manageGoalsUseCase.fetchAllGoals(for: mockUser)
            
            // Categorize goals
            goals = allGoals
            categorizeGoals()
            
            // Load progress details for active goals
            await loadProgressDetails()
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("load_goals", duration: duration, success: true)
            logger.info("Successfully loaded goals", context: [
                "totalCount": goals.count,
                "activeCount": activeGoals.count,
                "completedCount": completedGoals.count,
                "expiredCount": expiredGoals.count
            ])
            
        } catch {
            let duration = Date().timeIntervalSince(Date())
            logger.logPerformance("load_goals", duration: duration, success: false)
            logger.error(error, context: ["operation": "load_goals"])
            errorMessage = handleError(error)
        }
    }
    
    @MainActor
    func refreshGoals() async {
        logger.logUserAction("refresh_goals", parameters: [
            "currentGoalCount": goals.count
        ])
        
        await loadGoals()
    }
    
    // MARK: - Goal Management
    @MainActor
    func createGoal(_ goalRequest: GoalCreationRequest) async {
        logger.debug("Starting goal creation", context: [
            "type": goalRequest.type.rawValue,
            "targetValue": goalRequest.targetValue
        ])
        
        guard !isSaving else {
            logger.warning("Save already in progress, skipping", context: nil)
            return
        }
        
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        
        do {
            let startTime = Date()
            let mockUser = createMockUser()
            
            logger.info("Creating new goal", context: [
                "type": goalRequest.type.rawValue,
                "targetValue": goalRequest.targetValue,
                "deadline": goalRequest.deadline.description
            ])
            
            let newGoal = try await manageGoalsUseCase.createGoal(
                for: mockUser,
                goalData: GoalCreationData(
                    type: goalRequest.type,
                    targetValue: goalRequest.targetValue,
                    deadline: goalRequest.deadline,
                    description: goalRequest.description
                )
            )
            
            // Add to local state
            goals.append(newGoal)
            categorizeGoals()
            
            // Load progress detail for the new goal
            await loadProgressDetail(for: newGoal)
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("create_goal", duration: duration, success: true)
            logger.logUserAction("goal_created", parameters: [
                "goalId": newGoal.id.uuidString,
                "type": goalRequest.type.rawValue,
                "targetValue": goalRequest.targetValue
            ])
            
        } catch {
            let duration = Date().timeIntervalSince(Date())
            logger.logPerformance("create_goal", duration: duration, success: false)
            logger.error(error, context: [
                "operation": "create_goal",
                "goalType": goalRequest.type.rawValue
            ])
            errorMessage = handleError(error)
        }
    }
    
    @MainActor
    func updateGoal(_ goal: Goal, request: GoalUpdateRequest) async {
        logger.debug("Starting goal update", context: [
            "goalId": goal.id.uuidString,
            "type": goal.type.rawValue
        ])
        
        guard !isSaving else {
            logger.warning("Save already in progress, skipping", context: nil)
            return
        }
        
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        
        do {
            let startTime = Date()
            let mockUser = createMockUser()
            
            logger.info("Updating goal", context: [
                "goalId": goal.id.uuidString,
                "newTargetValue": request.targetValue,
                "newDeadline": request.deadline?.description ?? "nil"
            ])
            
            let updatedGoal = try await manageGoalsUseCase.updateGoal(
                goal,
                updates: GoalUpdateData(
                    targetValue: request.targetValue,
                    deadline: request.deadline,
                    description: request.description,
                    isActive: nil
                )
            )
            
            // Update local state
            if let index = goals.firstIndex(where: { $0.id == goal.id }) {
                goals[index] = updatedGoal
                categorizeGoals()
            }
            
            // Reload progress detail
            await loadProgressDetail(for: updatedGoal)
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("update_goal", duration: duration, success: true)
            logger.logUserAction("goal_updated", parameters: [
                "goalId": goal.id.uuidString
            ])
            
        } catch {
            let duration = Date().timeIntervalSince(Date())
            logger.logPerformance("update_goal", duration: duration, success: false)
            logger.error(error, context: [
                "operation": "update_goal",
                "goalId": goal.id.uuidString
            ])
            errorMessage = handleError(error)
        }
    }
    
    @MainActor
    func deleteGoal(_ goal: Goal) async {
        logger.debug("Starting goal deletion", context: [
            "goalId": goal.id.uuidString
        ])
        
        guard !isSaving else {
            logger.warning("Save already in progress, skipping", context: nil)
            return
        }
        
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        
        do {
            let startTime = Date()
            let mockUser = createMockUser()
            
            logger.info("Deleting goal", context: [
                "goalId": goal.id.uuidString,
                "type": goal.type.rawValue
            ])
            
            try await manageGoalsUseCase.deleteGoal(goal)
            
            // Remove from local state
            goals.removeAll { $0.id == goal.id }
            goalProgressDetails.removeValue(forKey: goal.id)
            categorizeGoals()
            
            // Clear selection if deleted goal was selected
            if selectedGoal?.id == goal.id {
                selectedGoal = nil
            }
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("delete_goal", duration: duration, success: true)
            logger.logUserAction("goal_deleted", parameters: [
                "goalId": goal.id.uuidString
            ])
            
        } catch {
            let duration = Date().timeIntervalSince(Date())
            logger.logPerformance("delete_goal", duration: duration, success: false)
            logger.error(error, context: [
                "operation": "delete_goal",
                "goalId": goal.id.uuidString
            ])
            errorMessage = handleError(error)
        }
    }
    
    // MARK: - Progress Tracking
    @MainActor
    func updateGoalProgress() async {
        logger.debug("Starting goal progress update", context: nil)
        
        guard !activeGoals.isEmpty else {
            logger.info("No active goals to update", context: nil)
            return
        }
        
        do {
            let startTime = Date()
            let mockUser = createMockUser()
            
            logger.info("Updating progress for all active goals", context: [
                "activeGoalCount": activeGoals.count
            ])
            
            try await manageGoalsUseCase.updateAllGoalsProgress(for: mockUser)
            
            // Reload goals to get updated progress
            await loadGoals()
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("update_goal_progress", duration: duration, success: true)
            
        } catch {
            let duration = Date().timeIntervalSince(Date())
            logger.logPerformance("update_goal_progress", duration: duration, success: false)
            logger.error(error, context: ["operation": "update_goal_progress"])
            errorMessage = handleError(error)
        }
    }
    
    @MainActor
    func selectGoal(_ goal: Goal) {
        logger.logUserAction("select_goal", parameters: [
            "goalId": goal.id.uuidString,
            "type": goal.type.rawValue,
            "progress": goal.progress
        ])
        
        selectedGoal = goal
    }
    
    @MainActor
    func clearSelection() {
        selectedGoal = nil
        logger.debug("Goal selection cleared", context: nil)
    }
    
    // MARK: - Goal Suggestions
    @MainActor
    func getSuggestedGoals() async -> [GoalSuggestion] {
        logger.debug("Generating goal suggestions", context: nil)
        
        do {
            let startTime = Date()
            let mockUser = createMockUser()
            
            let suggestions = try await manageGoalsUseCase.suggestGoals(for: mockUser)
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("generate_goal_suggestions", duration: duration, success: true)
            logger.info("Generated goal suggestions", context: [
                "suggestionCount": suggestions.count
            ])
            
            return suggestions
            
        } catch {
            let duration = Date().timeIntervalSince(Date())
            logger.logPerformance("generate_goal_suggestions", duration: duration, success: false)
            logger.error(error, context: ["operation": "generate_goal_suggestions"])
            return []
        }
    }
    
    // MARK: - Progress Details
    private func loadProgressDetails() async {
        for goal in activeGoals {
            await loadProgressDetail(for: goal)
        }
    }
    
    private func loadProgressDetail(for goal: Goal) async {
        do {
            let mockUser = createMockUser()
            let healthRecords = try await fetchHealthDataUseCase.fetchHealthRecords(for: mockUser, type: nil, dateRange: nil, limit: nil)
            let progressDetail = try await goalTracker.analyzeGoalProgress(
                for: goal,
                using: healthRecords
            )
            
            await MainActor.run {
                goalProgressDetails[goal.id] = progressDetail
            }
            
        } catch {
            logger.error(error, context: [
                "operation": "load_progress_detail",
                "goalId": goal.id.uuidString
            ])
        }
    }
    
    // MARK: - Helper Methods
    private func categorizeGoals() {
        activeGoals = goals.filter { $0.isActive && !$0.isExpired && !$0.isCompleted }
        completedGoals = goals.filter { $0.isCompleted }
        expiredGoals = goals.filter { $0.isExpired && !$0.isCompleted }
        
        logger.debug("Goals categorized", context: [
            "active": activeGoals.count,
            "completed": completedGoals.count,
            "expired": expiredGoals.count
        ])
    }
    
    private func createMockUser() -> User {
        do {
            return try User(name: "テストユーザー", age: 30, height: 175.0, targetWeight: 70.0)
        } catch {
            logger.error(error, context: ["operation": "create_mock_user"])
            fatalError("Failed to create mock user: \(error)")
        }
    }
    
    // MARK: - Error Handling
    @MainActor
    func clearError() {
        errorMessage = nil
        logger.debug("Goals error message cleared by user", context: nil)
    }
    
    private func handleError(_ error: Error) -> String {
        if let healthAppError = error as? any HealthAppError {
            return healthAppError.localizedDescription
        }
        return "目標管理中にエラーが発生しました: \(error.localizedDescription)"
    }
}

// MARK: - Supporting Types
struct GoalCreationRequest {
    let type: HealthDataType
    let targetValue: Double
    let deadline: Date
    let description: String?
    
    init(type: HealthDataType, targetValue: Double, deadline: Date, description: String? = nil) {
        self.type = type
        self.targetValue = targetValue
        self.deadline = deadline
        self.description = description
    }
}

struct GoalUpdateRequest {
    let targetValue: Double?
    let deadline: Date?
    let description: String?
    
    init(targetValue: Double? = nil, deadline: Date? = nil, description: String? = nil) {
        self.targetValue = targetValue
        self.deadline = deadline
        self.description = description
    }
}

// Note: GoalSuggestion is defined in ManageGoalsUseCaseProtocol.swift to avoid duplication