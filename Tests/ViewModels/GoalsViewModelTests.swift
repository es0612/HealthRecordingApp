import Testing
import Foundation
import SwiftData
@testable import HealthRecordingApp

@Suite("GoalsViewModel Tests")
struct GoalsViewModelTests {
    
    private func createMockDependencies() -> (ManageGoalsUseCaseProtocol, FetchHealthDataUseCaseProtocol, GoalTrackerProtocol, AILoggerProtocol) {
        let mockManageGoalsUseCase = MockManageGoalsUseCase()
        let mockFetchHealthDataUseCase = MockFetchHealthDataUseCase()
        let mockGoalTracker = MockGoalTracker()
        let mockLogger = MockAILogger()
        return (mockManageGoalsUseCase, mockFetchHealthDataUseCase, mockGoalTracker, mockLogger)
    }
    
    private func createViewModel() -> GoalsViewModel {
        let (manageGoalsUseCase, fetchHealthDataUseCase, goalTracker, logger) = createMockDependencies()
        return GoalsViewModel(
            manageGoalsUseCase: manageGoalsUseCase,
            fetchHealthDataUseCase: fetchHealthDataUseCase,
            goalTracker: goalTracker,
            logger: logger
        )
    }
    
    private func createSampleGoal(isCompleted: Bool = false, isExpired: Bool = false) throws -> Goal {
        let deadline = isExpired 
            ? Calendar.current.date(byAdding: .day, value: -1, to: Date())!
            : Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        
        let goal = try Goal(type: .weight, targetValue: 65.0, deadline: deadline)
        
        if isCompleted {
            goal.currentValue = goal.targetValue
        }
        
        return goal
    }
    
    @Test("GoalsViewModel should initialize with default values")
    func testInitialization() async throws {
        // Given & When
        let viewModel = createViewModel()
        
        // Then
        #expect(viewModel.goals.isEmpty)
        #expect(viewModel.activeGoals.isEmpty)
        #expect(viewModel.completedGoals.isEmpty)
        #expect(viewModel.expiredGoals.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.selectedGoal == nil)
        #expect(viewModel.goalProgressDetails.isEmpty)
        #expect(viewModel.isSaving == false)
        #expect(viewModel.hasActiveGoals == false)
        #expect(viewModel.activeGoalCount == 0)
        #expect(viewModel.overallProgress == 0.0)
    }
    
    @Test("GoalsViewModel should load goals successfully")
    func testLoadGoalsSuccess() async throws {
        // Given
        let (manageGoalsUseCase, fetchHealthDataUseCase, goalTracker, logger) = createMockDependencies()
        let mockManageGoalsUseCase = manageGoalsUseCase as! MockManageGoalsUseCase
        
        let activeGoal = try createSampleGoal()
        let completedGoal = try createSampleGoal(isCompleted: true)
        let expiredGoal = try createSampleGoal(isExpired: true)
        
        mockManageGoalsUseCase.mockGoals = [activeGoal, completedGoal, expiredGoal]
        
        let viewModel = GoalsViewModel(
            manageGoalsUseCase: manageGoalsUseCase,
            fetchHealthDataUseCase: fetchHealthDataUseCase,
            goalTracker: goalTracker,
            logger: logger
        )
        
        // When
        await viewModel.loadGoals()
        
        // Then
        #expect(viewModel.goals.count == 3)
        #expect(viewModel.activeGoals.count == 1)
        #expect(viewModel.completedGoals.count == 1)
        #expect(viewModel.expiredGoals.count == 1)
        #expect(viewModel.hasActiveGoals == true)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }
    
    @Test("GoalsViewModel should handle load error gracefully")
    func testLoadGoalsError() async throws {
        // Given
        let (manageGoalsUseCase, fetchHealthDataUseCase, goalTracker, logger) = createMockDependencies()
        let mockManageGoalsUseCase = manageGoalsUseCase as! MockManageGoalsUseCase
        mockManageGoalsUseCase.shouldThrowError = true
        
        let viewModel = GoalsViewModel(
            manageGoalsUseCase: manageGoalsUseCase,
            fetchHealthDataUseCase: fetchHealthDataUseCase,
            goalTracker: goalTracker,
            logger: logger
        )
        
        // When
        await viewModel.loadGoals()
        
        // Then
        #expect(viewModel.goals.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage != nil)
    }
    
    @Test("GoalsViewModel should create goal successfully")
    func testCreateGoalSuccess() async throws {
        // Given
        let (manageGoalsUseCase, fetchHealthDataUseCase, goalTracker, logger) = createMockDependencies()
        let mockManageGoalsUseCase = manageGoalsUseCase as! MockManageGoalsUseCase
        
        let viewModel = GoalsViewModel(
            manageGoalsUseCase: manageGoalsUseCase,
            fetchHealthDataUseCase: fetchHealthDataUseCase,
            goalTracker: goalTracker,
            logger: logger
        )
        
        let goalRequest = GoalCreationRequest(
            type: .weight,
            targetValue: 65.0,
            deadline: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
            description: "Test goal"
        )
        
        // When
        await viewModel.createGoal(goalRequest)
        
        // Then
        #expect(viewModel.goals.count == 1)
        #expect(viewModel.activeGoals.count == 1)
        #expect(viewModel.isSaving == false)
        #expect(viewModel.errorMessage == nil)
        #expect(mockManageGoalsUseCase.createGoalCallCount == 1)
    }
    
    @Test("GoalsViewModel should handle create goal error")
    func testCreateGoalError() async throws {
        // Given
        let (manageGoalsUseCase, fetchHealthDataUseCase, goalTracker, logger) = createMockDependencies()
        let mockManageGoalsUseCase = manageGoalsUseCase as! MockManageGoalsUseCase
        mockManageGoalsUseCase.shouldThrowError = true
        
        let viewModel = GoalsViewModel(
            manageGoalsUseCase: manageGoalsUseCase,
            fetchHealthDataUseCase: fetchHealthDataUseCase,
            goalTracker: goalTracker,
            logger: logger
        )
        
        let goalRequest = GoalCreationRequest(
            type: .weight,
            targetValue: 65.0,
            deadline: Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        )
        
        // When
        await viewModel.createGoal(goalRequest)
        
        // Then
        #expect(viewModel.goals.isEmpty)
        #expect(viewModel.isSaving == false)
        #expect(viewModel.errorMessage != nil)
    }
    
    @Test("GoalsViewModel should update goal successfully")
    func testUpdateGoalSuccess() async throws {
        // Given
        let (manageGoalsUseCase, fetchHealthDataUseCase, goalTracker, logger) = createMockDependencies()
        let mockManageGoalsUseCase = manageGoalsUseCase as! MockManageGoalsUseCase
        
        let originalGoal = try createSampleGoal()
        mockManageGoalsUseCase.mockGoals = [originalGoal]
        
        let viewModel = GoalsViewModel(
            manageGoalsUseCase: manageGoalsUseCase,
            fetchHealthDataUseCase: fetchHealthDataUseCase,
            goalTracker: goalTracker,
            logger: logger
        )
        
        await viewModel.loadGoals()
        
        let updateRequest = GoalUpdateRequest(
            targetValue: 60.0,
            deadline: Calendar.current.date(byAdding: .month, value: 2, to: Date())!
        )
        
        // When
        await viewModel.updateGoal(originalGoal, request: updateRequest)
        
        // Then
        #expect(viewModel.isSaving == false)
        #expect(viewModel.errorMessage == nil)
        #expect(mockManageGoalsUseCase.updateGoalCallCount == 1)
    }
    
    @Test("GoalsViewModel should delete goal successfully")
    func testDeleteGoalSuccess() async throws {
        // Given
        let (manageGoalsUseCase, fetchHealthDataUseCase, goalTracker, logger) = createMockDependencies()
        let mockManageGoalsUseCase = manageGoalsUseCase as! MockManageGoalsUseCase
        
        let goalToDelete = try createSampleGoal()
        mockManageGoalsUseCase.mockGoals = [goalToDelete]
        
        let viewModel = GoalsViewModel(
            manageGoalsUseCase: manageGoalsUseCase,
            fetchHealthDataUseCase: fetchHealthDataUseCase,
            goalTracker: goalTracker,
            logger: logger
        )
        
        await viewModel.loadGoals()
        #expect(viewModel.goals.count == 1)
        
        // When
        await viewModel.deleteGoal(goalToDelete)
        
        // Then
        #expect(viewModel.goals.isEmpty)
        #expect(viewModel.activeGoals.isEmpty)
        #expect(viewModel.goalProgressDetails[goalToDelete.id] == nil)
        #expect(viewModel.isSaving == false)
        #expect(viewModel.errorMessage == nil)
        #expect(mockManageGoalsUseCase.deleteGoalCallCount == 1)
    }
    
    @Test("GoalsViewModel should select and clear goal selection")
    func testGoalSelection() async throws {
        // Given
        let viewModel = createViewModel()
        let goal = try createSampleGoal()
        
        // When - Select goal
        await viewModel.selectGoal(goal)
        
        // Then
        #expect(viewModel.selectedGoal?.id == goal.id)
        
        // When - Clear selection
        await viewModel.clearSelection()
        
        // Then
        #expect(viewModel.selectedGoal == nil)
    }
    
    @Test("GoalsViewModel should update goal progress")
    func testUpdateGoalProgress() async throws {
        // Given
        let (manageGoalsUseCase, fetchHealthDataUseCase, goalTracker, logger) = createMockDependencies()
        let mockManageGoalsUseCase = manageGoalsUseCase as! MockManageGoalsUseCase
        
        let activeGoal = try createSampleGoal()
        mockManageGoalsUseCase.mockGoals = [activeGoal]
        
        let viewModel = GoalsViewModel(
            manageGoalsUseCase: manageGoalsUseCase,
            fetchHealthDataUseCase: fetchHealthDataUseCase,
            goalTracker: goalTracker,
            logger: logger
        )
        
        await viewModel.loadGoals()
        
        // When
        await viewModel.updateGoalProgress()
        
        // Then
        #expect(mockManageGoalsUseCase.updateAllGoalsProgressCallCount == 1)
    }
    
    @Test("GoalsViewModel should calculate overall progress correctly")
    func testOverallProgress() async throws {
        // Given
        let (manageGoalsUseCase, fetchHealthDataUseCase, goalTracker, logger) = createMockDependencies()
        let mockManageGoalsUseCase = manageGoalsUseCase as! MockManageGoalsUseCase
        
        let goal1 = try createSampleGoal()
        goal1.currentValue = 32.5 // 50% progress (65.0 / 2)
        
        let goal2 = try createSampleGoal()
        goal2.currentValue = 48.75 // 75% progress (65.0 * 0.75)
        
        mockManageGoalsUseCase.mockGoals = [goal1, goal2]
        
        let viewModel = GoalsViewModel(
            manageGoalsUseCase: manageGoalsUseCase,
            fetchHealthDataUseCase: fetchHealthDataUseCase,
            goalTracker: goalTracker,
            logger: logger
        )
        
        await viewModel.loadGoals()
        
        // When
        let overallProgress = viewModel.overallProgress
        
        // Then
        // Average of 50% and 75% = 62.5%
        #expect(abs(overallProgress - 0.625) < 0.01)
    }
    
    @Test("GoalsViewModel should get suggested goals")
    func testGetSuggestedGoals() async throws {
        // Given
        let (manageGoalsUseCase, fetchHealthDataUseCase, goalTracker, logger) = createMockDependencies()
        let mockManageGoalsUseCase = manageGoalsUseCase as! MockManageGoalsUseCase
        
        let suggestions = [
            GoalSuggestion(
                type: .weight,
                suggestedTargetValue: 65.0,
                suggestedDeadline: Calendar.current.date(byAdding: .month, value: 3, to: Date())!,
                reasoning: "Based on your current progress",
                confidence: 0.8
            )
        ]
        mockManageGoalsUseCase.mockSuggestions = suggestions
        
        let viewModel = GoalsViewModel(
            manageGoalsUseCase: manageGoalsUseCase,
            fetchHealthDataUseCase: fetchHealthDataUseCase,
            goalTracker: goalTracker,
            logger: logger
        )
        
        // When
        let suggestedGoals = await viewModel.getSuggestedGoals()
        
        // Then
        #expect(suggestedGoals.count == 1)
        #expect(suggestedGoals.first?.type == .weight)
        #expect(suggestedGoals.first?.confidence == 0.8)
        #expect(suggestedGoals.first?.isRecommended == true)
    }
    
    @Test("GoalsViewModel should identify goals needing attention")
    func testGoalsNeedingAttention() async throws {
        // Given
        let (manageGoalsUseCase, fetchHealthDataUseCase, goalTracker, logger) = createMockDependencies()
        let mockManageGoalsUseCase = manageGoalsUseCase as! MockManageGoalsUseCase
        let mockGoalTracker = goalTracker as! MockGoalTracker
        
        let lowProgressGoal = try createSampleGoal()
        lowProgressGoal.currentValue = 3.25 // 5% progress (very low)
        
        let normalGoal = try createSampleGoal()
        normalGoal.currentValue = 32.5 // 50% progress (normal)
        
        mockManageGoalsUseCase.mockGoals = [lowProgressGoal, normalGoal]
        
        // Setup mock progress detail for low progress goal
        let lowProgressDetail = GoalProgressDetail(
            goalId: lowProgressGoal.id,
            goalType: lowProgressGoal.type,
            targetValue: lowProgressGoal.targetValue,
            currentValue: lowProgressGoal.currentValue,
            progress: 0.05,
            progressPercentage: 5.0,
            remainingValue: 61.75,
            remainingDays: 30,
            dailyRequiredProgress: 2.058,
            isOnTrack: false,
            achievabilityScore: 0.2,
            motivationLevel: .critical,
            milestones: [],
            recommendations: []
        )
        
        mockGoalTracker.mockProgressDetails[lowProgressGoal.id] = lowProgressDetail
        
        let viewModel = GoalsViewModel(
            manageGoalsUseCase: manageGoalsUseCase,
            fetchHealthDataUseCase: fetchHealthDataUseCase,
            goalTracker: goalTracker,
            logger: logger
        )
        
        await viewModel.loadGoals()
        
        // When
        let goalsNeedingAttention = viewModel.goalsNeedingAttention
        
        // Then
        #expect(goalsNeedingAttention.count == 1)
        #expect(goalsNeedingAttention.first?.id == lowProgressGoal.id)
    }
    
    @Test("GoalsViewModel should clear error message")
    func testClearError() async throws {
        // Given
        let (manageGoalsUseCase, fetchHealthDataUseCase, goalTracker, logger) = createMockDependencies()
        let mockManageGoalsUseCase = manageGoalsUseCase as! MockManageGoalsUseCase
        mockManageGoalsUseCase.shouldThrowError = true
        
        let viewModel = GoalsViewModel(
            manageGoalsUseCase: manageGoalsUseCase,
            fetchHealthDataUseCase: fetchHealthDataUseCase,
            goalTracker: goalTracker,
            logger: logger
        )
        
        await viewModel.loadGoals()
        #expect(viewModel.errorMessage != nil)
        
        // When
        await viewModel.clearError()
        
        // Then
        #expect(viewModel.errorMessage == nil)
    }
    
    @Test("GoalsViewModel should prevent concurrent saving")
    func testConcurrentSavingPrevention() async throws {
        // Given
        let (manageGoalsUseCase, fetchHealthDataUseCase, goalTracker, logger) = createMockDependencies()
        let mockManageGoalsUseCase = manageGoalsUseCase as! MockManageGoalsUseCase
        mockManageGoalsUseCase.shouldDelay = true
        
        let viewModel = GoalsViewModel(
            manageGoalsUseCase: manageGoalsUseCase,
            fetchHealthDataUseCase: fetchHealthDataUseCase,
            goalTracker: goalTracker,
            logger: logger
        )
        
        let goalRequest = GoalCreationRequest(
            type: .weight,
            targetValue: 65.0,
            deadline: Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        )
        
        // When - Start two concurrent saves
        async let create1 = viewModel.createGoal(goalRequest)
        async let create2 = viewModel.createGoal(goalRequest)
        
        await create1
        await create2
        
        // Then - Only one save should have executed
        #expect(mockManageGoalsUseCase.createGoalCallCount == 1)
    }
}

// MARK: - Mock Classes
final class MockManageGoalsUseCase: ManageGoalsUseCaseProtocol {
    var mockGoals: [Goal] = []
    var mockSuggestions: [GoalSuggestion] = []
    var shouldThrowError = false
    var shouldDelay = false
    var createGoalCallCount = 0
    var updateGoalCallCount = 0
    var deleteGoalCallCount = 0
    var updateAllGoalsProgressCallCount = 0
    
    func createGoal(for user: User, type: HealthDataType, targetValue: Double, deadline: Date, description: String?) async throws -> Goal {
        createGoalCallCount += 1
        
        if shouldDelay {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        if shouldThrowError {
            throw HealthAppError.validationError(.invalidInput("Goal", value: String(targetValue), reason: "Invalid target value"))
        }
        
        let newGoal = try Goal(type: type, targetValue: targetValue, deadline: deadline, goalDescription: description)
        mockGoals.append(newGoal)
        return newGoal
    }
    
    func fetchAllGoals(for user: User) async throws -> [Goal] {
        if shouldThrowError {
            throw HealthAppError.dataFetchFailed(underlying: NSError(domain: "Test", code: 1))
        }
        
        return mockGoals
    }
    
    func fetchActiveGoals(for user: User) async throws -> [Goal] {
        return mockGoals.filter { $0.isActive && !$0.isExpired && !$0.isCompleted }
    }
    
    func updateGoal(_ goal: Goal, for user: User, targetValue: Double?, deadline: Date?, description: String?) async throws -> Goal {
        updateGoalCallCount += 1
        
        if shouldThrowError {
            throw HealthAppError.validationError(.invalidInput("Goal", value: "update", reason: "Update failed"))
        }
        
        if let targetValue = targetValue {
            goal.targetValue = targetValue
        }
        if let deadline = deadline {
            goal.deadline = deadline
        }
        if let description = description {
            goal.goalDescription = description
        }
        
        return goal
    }
    
    func deleteGoal(_ goal: Goal, for user: User) async throws {
        deleteGoalCallCount += 1
        
        if shouldThrowError {
            throw HealthAppError.validationError(.invalidInput("Goal", value: goal.id.uuidString, reason: "Delete failed"))
        }
        
        mockGoals.removeAll { $0.id == goal.id }
    }
    
    func updateGoalProgress(_ goal: Goal, for user: User) async throws -> Goal {
        // Implementation would update progress based on health records
        return goal
    }
    
    func updateAllGoalsProgress(for user: User) async throws {
        updateAllGoalsProgressCallCount += 1
        
        if shouldThrowError {
            throw HealthAppError.dataFetchFailed(underlying: NSError(domain: "Test", code: 1))
        }
    }
    
    func suggestGoals(for user: User) async throws -> [GoalSuggestion] {
        if shouldThrowError {
            throw HealthAppError.dataFetchFailed(underlying: NSError(domain: "Test", code: 1))
        }
        
        return mockSuggestions
    }
    
    func getGoalProgressAnalysis(for user: User) async throws -> GoalProgressAnalysis {
        return GoalProgressAnalysis(
            totalGoals: mockGoals.count,
            activeGoals: mockGoals.filter { $0.isActive }.count,
            completedGoals: mockGoals.filter { $0.isCompleted }.count,
            averageProgress: 0.5,
            onTrackGoals: 0,
            behindScheduleGoals: 0
        )
    }
    
    func checkRecentlyCompletedGoals(for user: User, within timeInterval: TimeInterval) async throws -> [Goal] {
        return mockGoals.filter { goal in
            guard let completedDate = goal.completedDate else { return false }
            return Date().timeIntervalSince(completedDate) <= timeInterval
        }
    }
    
    func archiveOldGoals(for user: User, olderThan timeInterval: TimeInterval) async throws -> Int {
        return 0
    }
}

final class MockGoalTracker: GoalTrackerProtocol {
    var mockProgressDetails: [UUID: GoalProgressDetail] = [:]
    var shouldThrowError = false
    
    func analyzeGoalProgress(for goal: Goal, using healthRecords: [HealthRecordProtocol]) async throws -> GoalProgressDetail {
        if shouldThrowError {
            throw HealthAppError.dataFetchFailed(underlying: NSError(domain: "Test", code: 1))
        }
        
        return mockProgressDetails[goal.id] ?? GoalProgressDetail(
            goalId: goal.id,
            goalType: goal.type,
            targetValue: goal.targetValue,
            currentValue: goal.currentValue,
            progress: goal.progress,
            progressPercentage: goal.progress * 100,
            remainingValue: goal.targetValue - goal.currentValue,
            remainingDays: goal.remainingDays,
            dailyRequiredProgress: 0.0,
            isOnTrack: goal.progress >= 0.5,
            achievabilityScore: 0.7,
            motivationLevel: .moderate,
            milestones: [],
            recommendations: []
        )
    }
    
    func analyzeMultipleGoals(goals: [Goal], using healthRecords: [HealthRecordProtocol]) async throws -> [GoalProgressDetail] {
        return []
    }
    
    func generateMilestones(for goal: Goal, strategy: MilestoneStrategy) async throws -> [GoalMilestone] {
        return []
    }
    
    func updateMilestoneProgress(milestones: [GoalMilestone], currentValue: Double) -> [GoalMilestone] {
        return milestones
    }
    
    func calculateAchievabilityScore(for goal: Goal, progressHistory: [GoalProgressSnapshot]) async throws -> Double {
        return 0.7
    }
    
    func generateRecommendations(for goal: Goal, progressDetail: GoalProgressDetail) async throws -> [GoalRecommendation] {
        return []
    }
    
    func predictGoalCompletion(for goal: Goal, progressHistory: [GoalProgressSnapshot]) async throws -> GoalCompletionPrediction {
        return GoalCompletionPrediction(
            predictedCompletionDate: goal.deadline,
            confidence: 0.7,
            likelihood: .likely,
            requiredDailyProgress: 0.0
        )
    }
    
    func assessGoalRisks(for goal: Goal, progressHistory: [GoalProgressSnapshot]) async throws -> [GoalRisk] {
        return []
    }
    
    func optimizeGoalTarget(for goal: Goal, userProfile: GoalUserProfile, progressHistory: [GoalProgressSnapshot]) async throws -> GoalTargetOptimization {
        return GoalTargetOptimization(
            originalTarget: goal.targetValue,
            optimizedTarget: goal.targetValue,
            reasoning: "No optimization needed",
            confidence: 0.7
        )
    }
    
    func personalizeRecommendations(for goal: Goal, userProfile: GoalUserProfile, progressDetail: GoalProgressDetail) async throws -> [GoalRecommendation] {
        return []
    }
    
    func calculateProgressVelocity(progressHistory: [GoalProgressSnapshot]) -> Double {
        return 0.0
    }
    
    func analyzeTrends(for goal: Goal, progressHistory: [GoalProgressSnapshot]) async throws -> GoalTrendAnalysis {
        return GoalTrendAnalysis(
            trend: .stable,
            velocity: 0.0,
            acceleration: 0.0,
            confidence: 0.5
        )
    }
    
    func compareGoalPerformance(goals: [Goal], progressDetails: [GoalProgressDetail]) -> GoalPerformanceComparison {
        return GoalPerformanceComparison(
            bestPerformingGoal: goals.first,
            worstPerformingGoal: goals.first,
            averageProgress: 0.5,
            insights: []
        )
    }
    
    func generateInsights(from progressDetails: [GoalProgressDetail]) async throws -> [GoalInsight] {
        return []
    }
    
    func suggestTimelineAdjustment(for goal: Goal, progressDetail: GoalProgressDetail) async throws -> TimelineAdjustment? {
        return nil
    }
    
    func handleExpiredGoal(_ goal: Goal, progressDetail: GoalProgressDetail) async throws -> ExpiredGoalAction {
        return ExpiredGoalAction(
            action: .extend,
            suggestedNewDeadline: Calendar.current.date(byAdding: .month, value: 1, to: Date()),
            reasoning: "Goal can be salvaged with extension"
        )
    }
    
    func handleCompletedGoal(_ goal: Goal, progressDetail: GoalProgressDetail) async throws -> CompletedGoalAction {
        return CompletedGoalAction(
            action: .celebrate,
            nextGoalSuggestion: nil,
            celebrationMessage: "Congratulations!"
        )
    }
    
    func calculateMotivationLevel(progressDetail: GoalProgressDetail, userProfile: GoalUserProfile) -> MotivationLevel {
        return .moderate
    }
    
    func trackEngagement(for goal: Goal, userProfile: GoalUserProfile) async throws -> EngagementMetrics {
        return EngagementMetrics(
            checkInFrequency: 1.0,
            interactionCount: 10,
            lastInteraction: Date(),
            engagementScore: 0.7
        )
    }
    
    func identifyBarriers(for goal: Goal, progressHistory: [GoalProgressSnapshot], userProfile: GoalUserProfile) async throws -> [GoalBarrier] {
        return []
    }
    
    func prioritizeRecommendations(_ recommendations: [GoalRecommendation], for goal: Goal, userProfile: GoalUserProfile) -> [GoalRecommendation] {
        return recommendations
    }
    
    func benchmarkAgainstSimilarGoals(goal: Goal, userProfile: GoalUserProfile) async throws -> GoalBenchmark {
        return GoalBenchmark(
            userPerformance: 0.5,
            averagePerformance: 0.6,
            percentile: 40,
            insights: []
        )
    }
    
    func calculateSuccessProbability(for goal: Goal, progressHistory: [GoalProgressSnapshot], userProfile: GoalUserProfile) async throws -> Double {
        return 0.7
    }
    
    func generateMotivationalContent(for goal: Goal, progressDetail: GoalProgressDetail, userProfile: GoalUserProfile) async throws -> MotivationalContent {
        return MotivationalContent(
            message: "Keep going!",
            type: .encouragement,
            personalized: true
        )
    }
}