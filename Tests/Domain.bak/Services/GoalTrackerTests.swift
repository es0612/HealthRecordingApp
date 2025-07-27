import Testing
import Foundation
import SwiftData
@testable import HealthRecordingApp

@Suite("GoalTracker Tests")
struct GoalTrackerTests {
    
    private func createTestUser() throws -> User {
        return try User(name: "Test User", age: 30, height: 175.0, targetWeight: 70.0)
    }
    
    private func createTestGoal(type: HealthDataType = .weight) throws -> Goal {
        let deadline = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        return try Goal(
            type: type,
            targetValue: type == .weight ? 70.0 : 10000.0,
            deadline: deadline,
            goalDescription: "Test goal"
        )
    }
    
    private func createTestHealthRecords(for goal: Goal, progressValues: [Double]) -> [HealthRecord] {
        let baseDate = Calendar.current.date(byAdding: .day, value: -progressValues.count, to: Date())!
        return progressValues.enumerated().map { index, value in
            // Ensure valid values based on health data type
            let validValue: Double
            switch goal.type {
            case .weight:
                validValue = value > 0 ? value : 70.0 // Default to 70kg if invalid
            case .steps:
                validValue = value >= 0 ? value : 0.0 // Steps can be 0
            case .calories:
                validValue = value >= 0 ? value : 0.0 // Calories can be 0
            case .heartRate:
                validValue = value > 0 ? value : 80.0 // Default to 80bpm if invalid
            case .bloodGlucose:
                validValue = value > 0 ? value : 100.0 // Default to 100mg/dL if invalid
            }
            
            // Use appropriate unit based on health data type from the enum
            let unit = goal.type.unit
            
            let record = HealthRecord(type: goal.type, value: validValue, unit: unit, source: .healthKit)
            record.timestamp = Calendar.current.date(byAdding: .day, value: index, to: baseDate)!
            return record
        }
    }
    
    private func createTestGoalProgressSnapshots(for goal: Goal, progressValues: [Double]) -> [GoalProgressSnapshot] {
        let baseDate = Calendar.current.date(byAdding: .day, value: -progressValues.count, to: Date())!
        return progressValues.enumerated().map { index, progress in
            GoalProgressSnapshot(
                goalId: goal.id,
                timestamp: Calendar.current.date(byAdding: .day, value: index, to: baseDate)!,
                value: progress * goal.targetValue,
                progress: progress,
                velocityChange: index > 0 ? progress - progressValues[index - 1] : 0.0,
                milestoneReached: progress >= Double(index + 1) * 0.25,
                source: .automatic
            )
        }
    }
    
    private func createTestUserProfile() -> GoalUserProfile {
        let preferences = GoalPreferences(
            preferredMilestoneFrequency: .weekly,
            motivationStyle: .achievement,
            feedbackFrequency: .daily,
            challengeLevel: .moderate,
            socialSharing: true,
            reminderPreferences: ReminderPreferences(
                enabled: true,
                frequency: .daily,
                preferredTimes: [ReminderTime(hour: 9, minute: 0, timeZone: "UTC")],
                style: .motivational
            )
        )
        
        return GoalUserProfile(
            userId: UUID(),
            age: 30,
            fitnessLevel: .intermediate,
            experienceLevel: .experienced,
            preferences: preferences,
            constraints: [],
            motivationFactors: [
                MotivationFactor(type: .health, strength: 0.8, description: "Health improvement", isPersonal: true)
            ]
        )
    }
    
    private func createTestGoalTracker() -> GoalTracker {
        let logger = AILogger()
        return GoalTracker(logger: logger)
    }
    
    // MARK: - Progress Analysis Tests
    
    @Test("GoalTracker should analyze goal progress correctly")
    func testAnalyzeGoalProgress() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let goal = try createTestGoal()
        let healthRecords = createTestHealthRecords(for: goal, progressValues: [65.0, 66.0, 67.0, 68.0, 69.0])
        
        // When
        let progressDetail = try await tracker.analyzeGoalProgress(for: goal, using: healthRecords)
        
        // Then
        #expect(progressDetail.goalId == goal.id)
        #expect(progressDetail.goalType == goal.type)
        #expect(progressDetail.targetValue == goal.targetValue)
        #expect(progressDetail.progress >= 0.0)
        #expect(progressDetail.progress <= 1.0)
        #expect(progressDetail.progressPercentage >= 0.0)
        #expect(progressDetail.progressPercentage <= 100.0)
        #expect(progressDetail.remainingDays >= 0)
        #expect(progressDetail.achievabilityScore >= 0.0)
        #expect(progressDetail.achievabilityScore <= 1.0)
        #expect(progressDetail.milestones.count > 0)
    }
    
    @Test("GoalTracker should handle empty health records")
    func testAnalyzeGoalProgressEmptyRecords() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let goal = try createTestGoal(type: .steps) // Use steps goal where 0.0 is valid
        let emptyRecords: [HealthRecord] = []
        
        // When
        let progressDetail = try await tracker.analyzeGoalProgress(for: goal, using: emptyRecords)
        
        // Then
        #expect(progressDetail.currentValue == 0.0)
        #expect(progressDetail.progress == 0.0)
        #expect(progressDetail.achievabilityScore <= 0.5) // Low achievability with no progress
        #expect(progressDetail.motivationLevel == .low || progressDetail.motivationLevel == .critical)
    }
    
    @Test("GoalTracker should analyze multiple goals correctly")
    func testAnalyzeMultipleGoals() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let weightGoal = try createTestGoal(type: .weight)
        let stepsGoal = try createTestGoal(type: .steps)
        let goals = [weightGoal, stepsGoal]
        
        let weightRecords = createTestHealthRecords(for: weightGoal, progressValues: [68.0, 69.0])
        let stepsRecords = createTestHealthRecords(for: stepsGoal, progressValues: [8000.0, 9000.0])
        let allRecords = weightRecords + stepsRecords
        
        // When
        let progressDetails = try await tracker.analyzeMultipleGoals(goals: goals, using: allRecords)
        
        // Then
        #expect(progressDetails.count == 2)
        #expect(progressDetails.contains { $0.goalType == .weight })
        #expect(progressDetails.contains { $0.goalType == .steps })
        
        for detail in progressDetails {
            #expect(detail.progress >= 0.0)
            #expect(detail.progress <= 1.0)
            #expect(detail.achievabilityScore >= 0.0)
            #expect(detail.achievabilityScore <= 1.0)
        }
    }
    
    @Test("GoalTracker should calculate achievability score correctly")
    func testCalculateAchievabilityScore() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let goal = try createTestGoal()
        
        // Good progress scenario
        let goodProgressSnapshots = createTestGoalProgressSnapshots(for: goal, progressValues: [0.1, 0.3, 0.5, 0.7, 0.8])
        
        // When
        let achievabilityScore = try await tracker.calculateAchievabilityScore(for: goal, progressHistory: goodProgressSnapshots)
        
        // Then
        #expect(achievabilityScore >= 0.0)
        #expect(achievabilityScore <= 1.0)
        #expect(achievabilityScore > 0.5) // Should be high for good progress
    }
    
    @Test("GoalTracker should handle poor progress in achievability score")
    func testCalculateAchievabilityScorePoorProgress() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let goal = try createTestGoal()
        
        // Poor progress scenario
        let poorProgressSnapshots = createTestGoalProgressSnapshots(for: goal, progressValues: [0.05, 0.08, 0.1, 0.12, 0.15])
        
        // When
        let achievabilityScore = try await tracker.calculateAchievabilityScore(for: goal, progressHistory: poorProgressSnapshots)
        
        // Then
        #expect(achievabilityScore >= 0.0)
        #expect(achievabilityScore <= 1.0)
        #expect(achievabilityScore < 0.5) // Should be low for poor progress
    }
    
    // MARK: - Milestone Management Tests
    
    @Test("GoalTracker should generate linear milestones correctly")
    func testGenerateMilestonesLinear() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let goal = try createTestGoal()
        
        // When
        let milestones = try await tracker.generateMilestones(for: goal, strategy: .linear)
        
        // Then
        #expect(milestones.count > 0)
        #expect(milestones.allSatisfy { $0.goalId == goal.id })
        #expect(milestones.allSatisfy { $0.targetValue <= goal.targetValue })
        #expect(milestones.allSatisfy { $0.targetDate <= goal.deadline })
        
        // Verify linear progression
        let sortedMilestones = milestones.sorted { $0.targetValue < $1.targetValue }
        for i in 1..<sortedMilestones.count {
            let previousValue = sortedMilestones[i-1].targetValue
            let currentValue = sortedMilestones[i].targetValue
            #expect(currentValue > previousValue)
        }
    }
    
    @Test("GoalTracker should generate exponential milestones correctly")
    func testGenerateMilestonesExponential() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let goal = try createTestGoal()
        
        // When
        let milestones = try await tracker.generateMilestones(for: goal, strategy: .exponential)
        
        // Then
        #expect(milestones.count > 0)
        #expect(milestones.allSatisfy { $0.goalId == goal.id })
        #expect(milestones.allSatisfy { $0.targetValue <= goal.targetValue })
        
        // Verify exponential progression (early milestones should be smaller)
        let sortedMilestones = milestones.sorted { $0.targetValue < $1.targetValue }
        if sortedMilestones.count >= 3 {
            let firstGap = sortedMilestones[1].targetValue - sortedMilestones[0].targetValue
            let lastGap = sortedMilestones.last!.targetValue - sortedMilestones[sortedMilestones.count - 2].targetValue
            #expect(lastGap > firstGap) // Later gaps should be larger
        }
    }
    
    @Test("GoalTracker should update milestone progress correctly")
    func testUpdateMilestoneProgress() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let goal = try createTestGoal()
        let milestones = try await tracker.generateMilestones(for: goal, strategy: .linear)
        let currentValue = goal.targetValue * 0.6 // 60% progress
        
        // When
        let updatedMilestones = tracker.updateMilestoneProgress(milestones: milestones, currentValue: currentValue)
        
        // Then
        #expect(updatedMilestones.count == milestones.count)
        
        for milestone in updatedMilestones {
            if milestone.targetValue <= currentValue {
                #expect(milestone.progress >= 0.99) // Should be nearly complete
            } else {
                #expect(milestone.progress < 1.0) // Should be incomplete
            }
        }
    }
    
    @Test("GoalTracker should check milestone completion correctly")
    func testCheckMilestoneCompletion() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let goal = try createTestGoal()
        let milestones = try await tracker.generateMilestones(for: goal, strategy: .linear)
        let currentValue = goal.targetValue * 0.5 // 50% progress
        
        // When
        let completedMilestones = tracker.checkMilestoneCompletion(milestones: milestones, currentValue: currentValue)
        
        // Then
        let actuallyCompleted = completedMilestones.filter { $0.isCompleted }
        let shouldBeCompleted = milestones.filter { $0.targetValue <= currentValue }
        
        #expect(actuallyCompleted.count == shouldBeCompleted.count)
        
        for milestone in actuallyCompleted {
            #expect(milestone.completedDate != nil)
            #expect(milestone.targetValue <= currentValue)
        }
    }
    
    // MARK: - Recommendation Generation Tests
    
    @Test("GoalTracker should generate recommendations correctly")
    func testGenerateRecommendations() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let goal = try createTestGoal()
        let healthRecords = createTestHealthRecords(for: goal, progressValues: [68.0, 68.5, 69.0])
        let progressDetail = try await tracker.analyzeGoalProgress(for: goal, using: healthRecords)
        let userProfile = createTestUserProfile()
        
        // When
        let recommendations = try await tracker.generateRecommendations(for: progressDetail, userProfile: userProfile)
        
        // Then
        #expect(recommendations.count > 0)
        #expect(recommendations.allSatisfy { $0.goalId == goal.id })
        #expect(recommendations.allSatisfy { $0.estimatedImpact >= 0.0 && $0.estimatedImpact <= 1.0 })
        
        // Should have varied types and priorities
        let types = Set(recommendations.map { $0.type })
        let priorities = Set(recommendations.map { $0.priority })
        #expect(types.count > 1)
        #expect(priorities.count > 1)
    }
    
    @Test("GoalTracker should prioritize recommendations correctly")
    func testPrioritizeRecommendations() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let goal = try createTestGoal()
        
        let recommendations = [
            GoalRecommendation(goalId: goal.id, type: .behaviorChange, title: "Low Impact", description: "Test", actionItems: [], priority: .low, estimatedImpact: 0.2, difficulty: .easy, category: .lifestyle),
            GoalRecommendation(goalId: goal.id, type: .targetAdjustment, title: "High Impact", description: "Test", actionItems: [], priority: .high, estimatedImpact: 0.8, difficulty: .medium, category: .tracking),
            GoalRecommendation(goalId: goal.id, type: .motivationalBoost, title: "Critical", description: "Test", actionItems: [], priority: .critical, estimatedImpact: 0.9, difficulty: .hard, category: .mindset)
        ]
        
        let context = GoalContext(
            currentDate: Date(),
            seasonality: .winter,
            userLifePhase: .professional,
            externalFactors: [],
            availableResources: []
        )
        
        // When
        let prioritizedRecommendations = tracker.prioritizeRecommendations(recommendations: recommendations, context: context)
        
        // Then
        #expect(prioritizedRecommendations.count == recommendations.count)
        
        // Critical should come first
        #expect(prioritizedRecommendations.first?.priority == .critical)
        
        // Should be sorted by priority and impact
        for i in 0..<(prioritizedRecommendations.count - 1) {
            let current = prioritizedRecommendations[i]
            let next = prioritizedRecommendations[i + 1]
            
            // Either higher priority or same priority with higher impact
            #expect(current.priority.rawValue <= next.priority.rawValue ||
                   (current.priority == next.priority && current.estimatedImpact >= next.estimatedImpact))
        }
    }
    
    @Test("GoalTracker should personalize recommendations correctly")
    func testPersonalizeRecommendations() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let user = try createTestUser()
        let goal = try createTestGoal()
        
        let genericRecommendations = [
            GoalRecommendation(goalId: goal.id, type: .behaviorChange, title: "Generic Advice", description: "Generic description", actionItems: ["Generic action"], priority: .medium, estimatedImpact: 0.5, difficulty: .medium, category: .lifestyle, isPersonalized: false)
        ]
        
        // When
        let personalizedRecommendations = try await tracker.personalizeRecommendations(recommendations: genericRecommendations, for: user)
        
        // Then
        #expect(personalizedRecommendations.count == genericRecommendations.count)
        
        for recommendation in personalizedRecommendations {
            #expect(recommendation.isPersonalized == true)
            #expect(recommendation.title != "Generic Advice") // Should be modified
            #expect(recommendation.description.contains(user.name) || recommendation.actionItems.contains { $0.contains(user.name) })
        }
    }
    
    // MARK: - Trend Analysis Tests
    
    @Test("GoalTracker should analyze trends correctly")
    func testAnalyzeTrends() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let goal = try createTestGoal()
        let progressSnapshots = createTestGoalProgressSnapshots(for: goal, progressValues: [0.1, 0.2, 0.35, 0.5, 0.7])
        
        // When
        let trendAnalysis = try await tracker.analyzeTrends(for: goal, progressHistory: progressSnapshots, timeframe: .month)
        
        // Then
        #expect(trendAnalysis.goalId == goal.id)
        #expect(trendAnalysis.timeframe == .month)
        #expect(trendAnalysis.progressTrend == .increasing) // Should detect increasing trend
        #expect(trendAnalysis.averageProgress > 0)
        #expect(trendAnalysis.progressVelocity > 0) // Positive velocity for increasing trend
        #expect(trendAnalysis.confidenceLevel >= 0.0 && trendAnalysis.confidenceLevel <= 1.0)
        #expect(trendAnalysis.successProbability >= 0.0 && trendAnalysis.successProbability <= 1.0)
    }
    
    @Test("GoalTracker should predict goal completion correctly")
    func testPredictGoalCompletion() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let goal = try createTestGoal()
        let healthRecords = createTestHealthRecords(for: goal, progressValues: [65.0, 66.5, 68.0, 69.0])
        let progressDetail = try await tracker.analyzeGoalProgress(for: goal, using: healthRecords)
        let progressSnapshots = createTestGoalProgressSnapshots(for: goal, progressValues: [0.1, 0.3, 0.5, 0.7])
        
        // When
        let prediction = try await tracker.predictGoalCompletion(based: progressDetail, progressHistory: progressSnapshots)
        
        // Then
        #expect(prediction.goalId == goal.id)
        #expect(prediction.confidenceLevel >= 0.0 && prediction.confidenceLevel <= 1.0)
        #expect(prediction.successProbability >= 0.0 && prediction.successProbability <= 1.0)
        #expect(prediction.requiredDailyProgress > 0) // Should require positive daily progress
        #expect(prediction.alternativeScenarios.count > 0)
        
        if let completionDate = prediction.predictedCompletionDate {
            #expect(completionDate > Date()) // Should be in the future
        }
    }
    
    @Test("GoalTracker should calculate progress velocity correctly")
    func testCalculateProgressVelocity() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let progressSnapshots = createTestGoalProgressSnapshots(for: try createTestGoal(), progressValues: [0.1, 0.2, 0.3, 0.4, 0.5])
        
        // When
        let velocity = tracker.calculateProgressVelocity(from: progressSnapshots, timeframe: .week)
        
        // Then
        #expect(velocity > 0) // Should be positive for increasing progress
        
        // Test with decreasing progress
        let decreasingSnapshots = createTestGoalProgressSnapshots(for: try createTestGoal(), progressValues: [0.5, 0.4, 0.3, 0.2, 0.1])
        let negativeVelocity = tracker.calculateProgressVelocity(from: decreasingSnapshots, timeframe: .week)
        #expect(negativeVelocity < 0) // Should be negative for decreasing progress
    }
    
    // MARK: - Risk Assessment Tests
    
    @Test("GoalTracker should assess goal risks correctly")
    func testAssessGoalRisks() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let goal = try createTestGoal()
        let healthRecords = createTestHealthRecords(for: goal, progressValues: [68.0, 68.1, 68.2]) // Very slow progress
        let progressDetail = try await tracker.analyzeGoalProgress(for: goal, using: healthRecords)
        let progressSnapshots = createTestGoalProgressSnapshots(for: goal, progressValues: [0.1, 0.12, 0.14])
        
        // When
        let riskFactors = try await tracker.assessGoalRisks(for: progressDetail, progressHistory: progressSnapshots)
        
        // Then
        #expect(riskFactors.count > 0)
        #expect(riskFactors.allSatisfy { $0.goalId == goal.id })
        #expect(riskFactors.allSatisfy { $0.impact >= 0.0 && $0.impact <= 1.0 })
        
        // Should identify lack of progress as a risk
        let lackOfProgressRisk = riskFactors.first { $0.type == .lackOfProgress }
        #expect(lackOfProgressRisk != nil)
        #expect(lackOfProgressRisk?.severity != .low)
    }
    
    @Test("GoalTracker should calculate success probability correctly")
    func testCalculateSuccessProbability() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let goal = try createTestGoal()
        
        // Good progress scenario
        let goodProgressSnapshots = createTestGoalProgressSnapshots(for: goal, progressValues: [0.2, 0.4, 0.6, 0.8])
        
        // When
        let successProbability = try await tracker.calculateSuccessProbability(for: goal, based: goodProgressSnapshots)
        
        // Then
        #expect(successProbability >= 0.0 && successProbability <= 1.0)
        #expect(successProbability > 0.5) // Should be high for good progress
        
        // Poor progress scenario
        let poorProgressSnapshots = createTestGoalProgressSnapshots(for: goal, progressValues: [0.05, 0.08, 0.1, 0.11])
        let lowSuccessProbability = try await tracker.calculateSuccessProbability(for: goal, based: poorProgressSnapshots)
        
        #expect(lowSuccessProbability < successProbability) // Should be lower than good progress
    }
    
    @Test("GoalTracker should identify barriers correctly")
    func testIdentifyBarriers() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let goal = try createTestGoal()
        let stagnantProgressSnapshots = createTestGoalProgressSnapshots(for: goal, progressValues: [0.3, 0.3, 0.31, 0.3, 0.29])
        
        // When
        let barriers = try await tracker.identifyBarriers(for: goal, progressHistory: stagnantProgressSnapshots)
        
        // Then
        #expect(barriers.count > 0)
        #expect(barriers.allSatisfy { $0.goalId == goal.id })
        #expect(barriers.allSatisfy { $0.severity != .minor }) // Should identify significant barriers
        
        // Should suggest solutions
        for barrier in barriers {
            #expect(barrier.suggestedSolutions.count > 0)
            #expect(!barrier.suggestedSolutions.allSatisfy { $0.isEmpty })
        }
    }
    
    // MARK: - Motivation Analysis Tests
    
    @Test("GoalTracker should calculate motivation level correctly")
    func testCalculateMotivationLevel() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let goal = try createTestGoal()
        let progressSnapshots = createTestGoalProgressSnapshots(for: goal, progressValues: [0.2, 0.4, 0.6])
        
        let recentActivities = [
            GoalActivity(goalId: goal.id, activityType: .dataEntry, timestamp: Date(), duration: 300, engagement: 0.8, result: .positive),
            GoalActivity(goalId: goal.id, activityType: .progressReview, timestamp: Date(), duration: 180, engagement: 0.7, result: .positive)
        ]
        
        // When
        let motivationLevel = try await tracker.calculateMotivationLevel(for: goal, progressHistory: progressSnapshots, recentActivity: recentActivities)
        
        // Then
        #expect([MotivationLevel.high, .medium, .low, .critical].contains(motivationLevel))
        
        // With good progress and positive activities, should not be critical
        #expect(motivationLevel != .critical)
    }
    
    @Test("GoalTracker should generate motivational content correctly")
    func testGenerateMotivationalContent() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let goal = try createTestGoal()
        let motivationLevel = MotivationLevel.medium
        
        let preferences = MotivationPreferences(
            preferredContentTypes: [.encouragement, .celebration],
            frequency: .moderate,
            tone: .enthusiastic,
            personalizationLevel: .advanced
        )
        
        // When
        let content = try await tracker.generateMotivationalContent(for: goal, motivationLevel: motivationLevel, userPreferences: preferences)
        
        // Then
        #expect(content.count > 0)
        #expect(content.allSatisfy { $0.goalId == goal.id })
        #expect(content.allSatisfy { preferences.preferredContentTypes.contains($0.contentType) })
        
        // Should be personalized
        for item in content {
            #expect(!item.title.isEmpty)
            #expect(!item.message.isEmpty)
            #expect(item.personalizedElements.count > 0)
        }
    }
    
    @Test("GoalTracker should track engagement correctly")
    func testTrackEngagement() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let goal = try createTestGoal()
        
        let activities = [
            GoalActivity(goalId: goal.id, activityType: .dataEntry, timestamp: Date(), duration: 300, engagement: 0.8, result: .positive),
            GoalActivity(goalId: goal.id, activityType: .progressReview, timestamp: Date(), duration: 600, engagement: 0.9, result: .positive),
            GoalActivity(goalId: goal.id, activityType: .recommendationView, timestamp: Date(), duration: 180, engagement: 0.6, result: .neutral),
            GoalActivity(goalId: goal.id, activityType: .milestoneCheck, timestamp: Date(), duration: 120, engagement: 0.7, result: .positive)
        ]
        
        // When
        let engagementMetrics = try await tracker.trackEngagement(for: goal, activities: activities)
        
        // Then
        #expect(engagementMetrics.goalId == goal.id)
        #expect(engagementMetrics.overallEngagement >= 0.0 && engagementMetrics.overallEngagement <= 1.0)
        #expect(engagementMetrics.dailyEngagement >= 0.0 && engagementMetrics.dailyEngagement <= 1.0)
        #expect(engagementMetrics.activityFrequency > 0)
        #expect(engagementMetrics.sessionDuration > 0)
        #expect(engagementMetrics.completionRate >= 0.0 && engagementMetrics.completionRate <= 1.0)
        
        // Calculate expected completion rate
        let positiveResults = activities.filter { $0.result == .positive }.count
        let expectedCompletionRate = Double(positiveResults) / Double(activities.count)
        #expect(abs(engagementMetrics.completionRate - expectedCompletionRate) < 0.01)
    }
    
    // MARK: - Goal Optimization Tests
    
    @Test("GoalTracker should optimize goal target correctly")
    func testOptimizeGoalTarget() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let goal = try createTestGoal()
        let progressSnapshots = createTestGoalProgressSnapshots(for: goal, progressValues: [0.1, 0.15, 0.18, 0.2]) // Slow progress
        
        let constraints = GoalConstraints(
            timeConstraints: [],
            resourceConstraints: [],
            physicalConstraints: [],
            environmentalConstraints: []
        )
        
        // When
        let optimization = try await tracker.optimizeGoalTarget(for: goal, based: progressSnapshots, constraints: constraints)
        
        // Then
        #expect(optimization.goalId == goal.id)
        #expect(optimization.suggestedTarget != goal.targetValue) // Should suggest a change
        #expect(optimization.confidenceLevel >= 0.0 && optimization.confidenceLevel <= 1.0)
        #expect(optimization.implementationSteps.count > 0)
        
        // With slow progress, should suggest lower target
        #expect(optimization.suggestedTarget < goal.targetValue)
        #expect(optimization.reasoningForDecrease != nil)
    }
    
    @Test("GoalTracker should suggest timeline adjustment correctly")
    func testSuggestTimelineAdjustment() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let goal = try createTestGoal()
        let healthRecords = createTestHealthRecords(for: goal, progressValues: [68.0, 68.2, 68.4]) // Slow progress
        let progressDetail = try await tracker.analyzeGoalProgress(for: goal, using: healthRecords)
        
        // When
        let adjustment = try await tracker.suggestTimelineAdjustment(for: goal, currentProgress: progressDetail)
        
        // Then
        #expect(adjustment.goalId == goal.id)
        #expect(adjustment.suggestedDeadline != goal.deadline) // Should suggest a change
        #expect(adjustment.reasoning.count > 0)
        #expect(adjustment.confidenceLevel >= 0.0 && adjustment.confidenceLevel <= 1.0)
        
        // With slow progress, should suggest extended deadline
        #expect(adjustment.suggestedDeadline > goal.deadline)
        #expect(adjustment.adjustmentType == .extend)
    }
    
    @Test("GoalTracker should calculate optimal daily target correctly")
    func testCalculateOptimalDailyTarget() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let goal = try createTestGoal()
        let currentProgress = 30.0 // 30kg progress out of 70kg target
        let remainingDays = 15
        
        // When
        let dailyTarget = tracker.calculateOptimalDailyTarget(for: goal, currentProgress: currentProgress, remainingDays: remainingDays)
        
        // Then
        #expect(dailyTarget > 0)
        
        // Calculate expected daily target
        let remainingProgress = goal.targetValue - currentProgress
        let expectedDailyTarget = remainingProgress / Double(remainingDays)
        #expect(abs(dailyTarget - expectedDailyTarget) < 0.01)
    }
    
    // MARK: - Comparative Analysis Tests
    
    @Test("GoalTracker should compare goal performance correctly")
    func testCompareGoalPerformance() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let goal1 = try createTestGoal(type: .weight)
        let goal2 = try createTestGoal(type: .steps)
        let goals = [goal1, goal2]
        
        // Set different progress levels
        goal1.currentValue = goal1.targetValue * 0.8 // 80% progress
        goal2.currentValue = goal2.targetValue * 0.4 // 40% progress
        
        // When
        let comparison = try await tracker.compareGoalPerformance(goals: goals, metric: .progress)
        
        // Then
        #expect(comparison.comparedGoals.count == 2)
        #expect(comparison.metric == .progress)
        #expect(comparison.rankings.count == 2)
        
        // Goal1 should rank higher (better progress)
        let goal1Ranking = comparison.rankings.first { $0.goalId == goal1.id }
        let goal2Ranking = comparison.rankings.first { $0.goalId == goal2.id }
        
        #expect(goal1Ranking != nil)
        #expect(goal2Ranking != nil)
        #expect(goal1Ranking!.rank < goal2Ranking!.rank) // Lower rank number = better performance
        #expect(goal1Ranking!.score > goal2Ranking!.score)
    }
    
    @Test("GoalTracker should benchmark against similar goals correctly")
    func testBenchmarkAgainstSimilarGoals() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let targetGoal = try createTestGoal(type: .weight)
        targetGoal.currentValue = targetGoal.targetValue * 0.6 // 60% progress
        
        let similarGoals = [
            try createTestGoal(type: .weight), // 0% progress (default)
            try createTestGoal(type: .weight), // Will set to 80% progress
            try createTestGoal(type: .weight)  // Will set to 40% progress
        ]
        
        similarGoals[1].currentValue = similarGoals[1].targetValue * 0.8
        similarGoals[2].currentValue = similarGoals[2].targetValue * 0.4
        
        // When
        let benchmark = try await tracker.benchmarkAgainstSimilarGoals(goal: targetGoal, similarGoals: similarGoals)
        
        // Then
        #expect(benchmark.targetGoalId == targetGoal.id)
        #expect(benchmark.comparisonGoals.count == similarGoals.count)
        #expect(benchmark.percentileRank >= 0.0 && benchmark.percentileRank <= 100.0)
        #expect(benchmark.averagePerformance >= 0.0 && benchmark.averagePerformance <= 1.0)
        
        // Target goal (60%) should rank in middle of similar goals (0%, 40%, 80%)
        #expect(benchmark.percentileRank > 30.0 && benchmark.percentileRank < 70.0)
    }
    
    @Test("GoalTracker should generate insights from comparisons correctly")
    func testGenerateInsights() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let goal1 = try createTestGoal(type: .weight)
        let goal2 = try createTestGoal(type: .steps)
        goal1.currentValue = goal1.targetValue * 0.9 // High performer
        goal2.currentValue = goal2.targetValue * 0.2 // Low performer
        
        let comparison = try await tracker.compareGoalPerformance(goals: [goal1, goal2], metric: .progress)
        
        // When
        let insights = try await tracker.generateInsights(from: [comparison])
        
        // Then
        #expect(insights.count > 0)
        
        for insight in insights {
            #expect(!insight.title.isEmpty)
            #expect(!insight.description.isEmpty)
            #expect(insight.confidence >= 0.0 && insight.confidence <= 1.0)
            #expect(insight.actionable != nil)
            #expect(insight.category != nil)
        }
        
        // Should generate insights about performance differences
        let performanceInsight = insights.first { $0.category == .performance }
        #expect(performanceInsight != nil)
    }
    
    // MARK: - Edge Cases and Error Handling Tests
    
    @Test("GoalTracker should handle expired goals correctly")
    func testHandleExpiredGoal() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let pastDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let expiredGoal = try Goal(type: .weight, targetValue: 70.0, deadline: pastDate)
        let healthRecords = createTestHealthRecords(for: expiredGoal, progressValues: [68.0])
        
        // When
        let progressDetail = try await tracker.analyzeGoalProgress(for: expiredGoal, using: healthRecords)
        
        // Then
        #expect(progressDetail.remainingDays == 0)
        #expect(progressDetail.motivationLevel == .critical || progressDetail.motivationLevel == .low)
        
        // Should identify time constraint as a risk
        let riskFactors = try await tracker.assessGoalRisks(for: progressDetail, progressHistory: [])
        let timeRisk = riskFactors.first { $0.type == .timeConstraint }
        #expect(timeRisk != nil)
        #expect(timeRisk?.severity == .critical)
    }
    
    @Test("GoalTracker should handle completed goals correctly")
    func testHandleCompletedGoal() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let goal = try createTestGoal()
        goal.currentValue = goal.targetValue // Completed
        goal.complete()
        
        let healthRecords = createTestHealthRecords(for: goal, progressValues: [70.0])
        
        // When
        let progressDetail = try await tracker.analyzeGoalProgress(for: goal, using: healthRecords)
        
        // Then
        #expect(progressDetail.progress >= 1.0)
        #expect(progressDetail.progressPercentage >= 100.0)
        #expect(progressDetail.motivationLevel == .high)
        #expect(progressDetail.achievabilityScore >= 0.9)
        
        // Should generate celebratory recommendations
        let recommendations = try await tracker.generateRecommendations(for: progressDetail, userProfile: createTestUserProfile())
        let celebratoryRec = recommendations.first { $0.type == .motivationalBoost }
        #expect(celebratoryRec != nil)
    }
    
    @Test("GoalTracker should handle insufficient data gracefully")
    func testHandleInsufficientData() async throws {
        // Given
        let tracker = createTestGoalTracker()
        let goal = try createTestGoal()
        let singleRecord = createTestHealthRecords(for: goal, progressValues: [68.0])
        
        // When
        let progressDetail = try await tracker.analyzeGoalProgress(for: goal, using: singleRecord)
        
        // Then
        #expect(progressDetail.achievabilityScore <= 0.5) // Low due to insufficient data
        #expect(progressDetail.trendAnalysis == nil) // No trend with single point
        
        // Should generate recommendation for more data collection
        let recommendations = try await tracker.generateRecommendations(for: progressDetail, userProfile: createTestUserProfile())
        let trackingRec = recommendations.first { $0.category == .tracking }
        #expect(trackingRec != nil)
    }
}

// MARK: - Additional Supporting Types for Missing Enums

extension TimelineAdjustmentType: CaseIterable {
    public static var allCases: [TimelineAdjustmentType] = [.extend, .compress, .redistribute]
}

extension GoalComparisonMetric: CaseIterable {
    public static var allCases: [GoalComparisonMetric] = [.progress, .velocity, .consistency, .achievability]
}