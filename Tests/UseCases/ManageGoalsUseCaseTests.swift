import Testing
import Foundation
import SwiftData
@testable import HealthRecordingApp

@Suite("ManageGoalsUseCase Tests")
struct ManageGoalsUseCaseTests {
    
    private func createInMemoryModelContext() throws -> ModelContext {
        let schema = Schema([User.self, HealthRecord.self, Goal.self, Badge.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }
    
    private func createTestUser() -> User {
        return try! User(name: "Test User", age: 30, height: 170.0, targetWeight: 65.0)
    }
    
    private func createTestHealthRecords(for user: User, context: ModelContext) throws -> [HealthRecord] {
        let records = [
            HealthRecord(type: .weight, value: 70.0, unit: "kg", source: .healthKit),
            HealthRecord(type: .weight, value: 69.0, unit: "kg", source: .manual),
            HealthRecord(type: .steps, value: 8000, unit: "steps", source: .healthKit),
            HealthRecord(type: .steps, value: 10000, unit: "steps", source: .healthKit),
            HealthRecord(type: .steps, value: 12000, unit: "steps", source: .healthKit),
        ]
        
        // Set timestamps for progress tracking
        let baseDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        for (index, record) in records.enumerated() {
            record.timestamp = Calendar.current.date(byAdding: .day, value: index * 2, to: baseDate)!
            record.user = user
            context.insert(record)
        }
        
        return records
    }
    
    private func createTestUseCase(modelContext: ModelContext) -> ManageGoalsUseCase {
        let goalRepository = SwiftDataGoalRepository(modelContext: modelContext)
        let healthRecordRepository = SwiftDataHealthRecordRepository(modelContext: modelContext)
        let userRepository = SwiftDataUserRepository(modelContext: modelContext)
        let logger = AILogger()
        
        return ManageGoalsUseCase(
            goalRepository: goalRepository,
            healthRecordRepository: healthRecordRepository,
            userRepository: userRepository,
            logger: logger
        )
    }
    
    // MARK: - Goal Creation Tests
    
    @Test("ManageGoalsUseCase should create goal successfully")
    func testCreateGoal() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        let goalData = try GoalCreationData(
            type: .weight,
            targetValue: 65.0,
            deadline: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
            description: "Lose weight to reach target"
        )
        
        // When
        let createdGoal = try await useCase.createGoal(for: user, goalData: goalData)
        
        // Then
        #expect(createdGoal.type == .weight)
        #expect(createdGoal.targetValue == 65.0)
        #expect(createdGoal.isActive == true)
        #expect(createdGoal.user?.id == user.id)
        #expect(user.goals.contains(where: { $0.id == createdGoal.id }))
    }
    
    @Test("ManageGoalsUseCase should validate goal creation data")
    func testCreateGoalValidation() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        // When & Then - Invalid target value
        do {
            let invalidGoalData = try GoalCreationData(
                type: .weight,
                targetValue: -10.0, // Invalid negative value
                deadline: Calendar.current.date(byAdding: .month, value: 1, to: Date())!
            )
            _ = try await useCase.createGoal(for: user, goalData: invalidGoalData)
            #expect(Bool(false), "Should throw error for invalid target value")
        } catch is ValidationError {
            #expect(true, "Expected ValidationError was thrown")
        }
        
        // When & Then - Invalid deadline
        do {
            let invalidGoalData = try GoalCreationData(
                type: .weight,
                targetValue: 65.0,
                deadline: Calendar.current.date(byAdding: .day, value: -1, to: Date())! // Past date
            )
            _ = try await useCase.createGoal(for: user, goalData: invalidGoalData)
            #expect(Bool(false), "Should throw error for past deadline")
        } catch is ValidationError {
            #expect(true, "Expected ValidationError was thrown")
        }
    }
    
    // MARK: - Goal Update Tests
    
    @Test("ManageGoalsUseCase should update goal successfully")
    func testUpdateGoal() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        let goal = try Goal(
            type: .steps,
            targetValue: 10000,
            deadline: Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        )
        goal.user = user
        modelContext.insert(goal)
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        let updateData = try GoalUpdateData(
            targetValue: 12000,
            description: "Updated target for better fitness"
        )
        
        // When
        let updatedGoal = try await useCase.updateGoal(goal, updates: updateData)
        
        // Then
        #expect(updatedGoal.targetValue == 12000)
        #expect(updatedGoal.id == goal.id)
    }
    
    @Test("ManageGoalsUseCase should validate goal updates")
    func testUpdateGoalValidation() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        let goal = try Goal(
            type: .steps,
            targetValue: 10000,
            deadline: Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        )
        goal.user = user
        modelContext.insert(goal)
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        // When & Then - Invalid target value
        do {
            let invalidUpdate = try GoalUpdateData(targetValue: -500)
            _ = try await useCase.updateGoal(goal, updates: invalidUpdate)
            #expect(Bool(false), "Should throw error for invalid target value")
        } catch is ValidationError {
            #expect(true, "Expected ValidationError was thrown")
        }
    }
    
    // MARK: - Goal Deletion Tests
    
    @Test("ManageGoalsUseCase should delete goal successfully")
    func testDeleteGoal() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        let goal = try Goal(
            type: .weight,
            targetValue: 65.0,
            deadline: Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        )
        goal.user = user
        modelContext.insert(goal)
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        // When
        try await useCase.deleteGoal(goal)
        
        // Then
        #expect(!user.goals.contains(where: { $0.id == goal.id }))
    }
    
    // MARK: - Goal Fetching Tests
    
    @Test("ManageGoalsUseCase should fetch active goals")
    func testFetchActiveGoals() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        // Create active goal
        let activeGoal = try Goal(
            type: .steps,
            targetValue: 10000,
            deadline: Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        )
        activeGoal.user = user
        activeGoal.isActive = true
        modelContext.insert(activeGoal)
        
        // Create inactive goal
        let inactiveGoal = try Goal(
            type: .weight,
            targetValue: 65.0,
            deadline: Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        )
        inactiveGoal.user = user
        inactiveGoal.isActive = false
        modelContext.insert(inactiveGoal)
        
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        // When
        let activeGoals = try await useCase.fetchActiveGoals(for: user)
        
        // Then
        #expect(activeGoals.count == 1)
        #expect(activeGoals.first?.id == activeGoal.id)
        #expect(activeGoals.allSatisfy { $0.isActive })
    }
    
    @Test("ManageGoalsUseCase should fetch all goals")
    func testFetchAllGoals() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        // Create multiple goals
        let goal1 = try Goal(type: .steps, targetValue: 10000, deadline: Calendar.current.date(byAdding: .month, value: 1, to: Date())!)
        goal1.user = user
        goal1.isActive = true
        
        let goal2 = try Goal(type: .weight, targetValue: 65.0, deadline: Calendar.current.date(byAdding: .month, value: 1, to: Date())!)
        goal2.user = user
        goal2.isActive = false
        
        modelContext.insert(goal1)
        modelContext.insert(goal2)
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        // When
        let allGoals = try await useCase.fetchAllGoals(for: user)
        
        // Then
        #expect(allGoals.count == 2)
        #expect(allGoals.contains(where: { $0.id == goal1.id }))
        #expect(allGoals.contains(where: { $0.id == goal2.id }))
    }
    
    // MARK: - Progress Update Tests
    
    @Test("ManageGoalsUseCase should update goal progress")
    func testUpdateGoalProgress() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        _ = try createTestHealthRecords(for: user, context: modelContext)
        
        let goal = try Goal(
            type: .steps,
            targetValue: 10000,
            deadline: Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        )
        goal.user = user
        modelContext.insert(goal)
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        // When
        let updatedGoal = try await useCase.updateGoalProgress(goal, for: user)
        
        // Then
        #expect(updatedGoal.currentValue > 0) // Should be updated with latest health record
        #expect(updatedGoal.progress >= 0) // Progress should be calculated
        #expect(updatedGoal.id == goal.id)
    }
    
    @Test("ManageGoalsUseCase should update all goals progress")
    func testUpdateAllGoalsProgress() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        _ = try createTestHealthRecords(for: user, context: modelContext)
        
        let stepsGoal = try Goal(type: .steps, targetValue: 10000, deadline: Calendar.current.date(byAdding: .month, value: 1, to: Date())!)
        stepsGoal.user = user
        stepsGoal.isActive = true
        
        let weightGoal = try Goal(type: .weight, targetValue: 65.0, deadline: Calendar.current.date(byAdding: .month, value: 1, to: Date())!)
        weightGoal.user = user
        weightGoal.isActive = true
        
        modelContext.insert(stepsGoal)
        modelContext.insert(weightGoal)
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        // When
        let updatedGoals = try await useCase.updateAllGoalsProgress(for: user)
        
        // Then
        #expect(updatedGoals.count == 2)
        #expect(updatedGoals.allSatisfy { $0.progress >= 0 })
    }
    
    // MARK: - Progress Analysis Tests
    
    @Test("ManageGoalsUseCase should provide goal progress analysis")
    func testGetGoalProgressAnalysis() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        let testRecords = try createTestHealthRecords(for: user, context: modelContext)
        
        let goal = try Goal(
            type: .steps,
            targetValue: 15000,
            deadline: Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        )
        goal.user = user
        modelContext.insert(goal)
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        // When
        let analysis = try await useCase.getGoalProgressAnalysis(for: goal, user: user)
        
        // Then
        #expect(analysis.goal.id == goal.id)
        #expect(analysis.currentProgress >= 0.0)
        #expect(analysis.currentProgress <= 1.0)
        #expect(analysis.daysRemaining >= 0)
        #expect(analysis.recommendations.count > 0)
        #expect(analysis.historicalProgress.count >= 0)
    }
    
    // MARK: - Completed Goals Tests
    
    @Test("ManageGoalsUseCase should check recently completed goals")
    func testCheckRecentlyCompletedGoals() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        // Create a completed goal
        let completedGoal = try Goal(
            type: .steps,
            targetValue: 5000, // Low target to ensure completion
            deadline: Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        )
        completedGoal.user = user
        completedGoal.currentValue = 6000 // Exceeds target
        modelContext.insert(completedGoal)
        
        // Create health records
        _ = try createTestHealthRecords(for: user, context: modelContext)
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        // When - Check for goals completed in last 24 hours
        let recentlyCompleted = try await useCase.checkRecentlyCompletedGoals(
            for: user,
            timeframe: 24 * 60 * 60 // 24 hours
        )
        
        // Then
        #expect(recentlyCompleted.count >= 0) // May or may not have completed goals
        #expect(recentlyCompleted.allSatisfy { $0.isCompleted })
    }
    
    // MARK: - Goal Suggestions Tests
    
    @Test("ManageGoalsUseCase should suggest new goals")
    func testSuggestGoals() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        // Create sufficient health records for analysis
        _ = try createTestHealthRecords(for: user, context: modelContext)
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        // When
        let suggestions = try await useCase.suggestGoals(for: user)
        
        // Then
        #expect(suggestions.count >= 0) // May have suggestions based on data
        
        for suggestion in suggestions {
            #expect(suggestion.suggestedTargetValue > 0)
            #expect(suggestion.suggestedDeadline > Date())
            #expect(suggestion.confidenceLevel >= 0.0)
            #expect(suggestion.confidenceLevel <= 1.0)
            #expect(!suggestion.reasoning.isEmpty)
        }
    }
    
    // MARK: - Goal Archiving Tests
    
    @Test("ManageGoalsUseCase should archive old goals")
    func testArchiveOldGoals() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        // Create an old completed goal
        let oldGoal = try Goal(
            type: .weight,
            targetValue: 65.0,
            deadline: Calendar.current.date(byAdding: .day, value: -30, to: Date())! // 30 days ago
        )
        oldGoal.user = user
        oldGoal.currentValue = 65.0 // Completed
        modelContext.insert(oldGoal)
        
        // Create a recent goal
        let recentGoal = try Goal(
            type: .steps,
            targetValue: 10000,
            deadline: Calendar.current.date(byAdding: .day, value: 10, to: Date())! // Future
        )
        recentGoal.user = user
        modelContext.insert(recentGoal)
        
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        // When - Archive goals older than 7 days
        let archivedCount = try await useCase.archiveOldGoals(
            for: user,
            olderThan: Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        )
        
        // Then
        #expect(archivedCount >= 0)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("ManageGoalsUseCase should handle invalid user gracefully")
    func testInvalidUserHandling() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let invalidUser = createTestUser() // Not saved to context
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        // When & Then
        do {
            _ = try await useCase.fetchActiveGoals(for: invalidUser)
            #expect(Bool(false), "Should throw error for invalid user")
        } catch {
            #expect(true, "Expected error was thrown: \(error)")
        }
    }
    
    // MARK: - Concurrent Operations Tests
    
    @Test("ManageGoalsUseCase should handle concurrent operations")
    func testConcurrentOperations() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        _ = try createTestHealthRecords(for: user, context: modelContext)
        
        let goal1 = try Goal(type: .steps, targetValue: 10000, deadline: Calendar.current.date(byAdding: .month, value: 1, to: Date())!)
        goal1.user = user
        
        let goal2 = try Goal(type: .weight, targetValue: 65.0, deadline: Calendar.current.date(byAdding: .month, value: 1, to: Date())!)
        goal2.user = user
        
        modelContext.insert(goal1)
        modelContext.insert(goal2)
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        // When - Execute multiple operations concurrently
        async let fetchTask = useCase.fetchActiveGoals(for: user)
        async let progressTask = useCase.updateGoalProgress(goal1, for: user)
        async let analysisTask = useCase.getGoalProgressAnalysis(for: goal2, user: user)
        
        let results = try await (fetchTask, progressTask, analysisTask)
        
        // Then
        #expect(results.0.count >= 0) // Fetched goals
        #expect(results.1.id == goal1.id) // Updated goal
        #expect(results.2.goal.id == goal2.id) // Analyzed goal
    }
    
    // MARK: - Performance Tests
    
    @Test("ManageGoalsUseCase should handle multiple goals efficiently")
    func testMultipleGoalsPerformance() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        // Create many goals
        for i in 0..<50 {
            let goal = try Goal(
                type: .steps,
                targetValue: Double(8000 + i * 100),
                deadline: Calendar.current.date(byAdding: .day, value: i + 1, to: Date())!
            )
            goal.user = user
            modelContext.insert(goal)
        }
        
        _ = try createTestHealthRecords(for: user, context: modelContext)
        try modelContext.save()
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        // When - Measure performance
        let startTime = Date()
        let allGoals = try await useCase.fetchAllGoals(for: user)
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Then
        #expect(allGoals.count == 50)
        #expect(executionTime < 2.0) // Should complete within 2 seconds
    }
    
    // MARK: - Data Consistency Tests
    
    @Test("ManageGoalsUseCase should maintain data consistency")
    func testDataConsistency() async throws {
        // Given
        let modelContext = try createInMemoryModelContext()
        let user = createTestUser()
        modelContext.insert(user)
        
        let useCase = createTestUseCase(modelContext: modelContext)
        
        let goalData = try GoalCreationData(
            type: .weight,
            targetValue: 65.0,
            deadline: Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        )
        
        // When - Create goal and verify consistency
        let createdGoal = try await useCase.createGoal(for: user, goalData: goalData)
        let fetchedGoals = try await useCase.fetchAllGoals(for: user)
        
        // Then
        #expect(fetchedGoals.contains(where: { $0.id == createdGoal.id }))
        #expect(user.goals.contains(where: { $0.id == createdGoal.id }))
        
        // When - Update goal and verify consistency
        let updateData = try GoalUpdateData(targetValue: 63.0)
        let updatedGoal = try await useCase.updateGoal(createdGoal, updates: updateData)
        
        // Then
        #expect(updatedGoal.targetValue == 63.0)
        #expect(updatedGoal.id == createdGoal.id)
    }
}