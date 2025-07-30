import Testing
import Foundation
import SwiftData
@testable import HealthRecordingApp

@Suite("DashboardViewModel Tests")
struct DashboardViewModelTests {
    
    private func createMockViewModels() -> (HealthDataViewModel, TrendsViewModel, GoalsViewModel, AILoggerProtocol) {
        let (recordUseCase, fetchUseCase, aiLogger) = createMockHealthDataDependencies()
        let healthDataViewModel = HealthDataViewModel(
            recordHealthDataUseCase: recordUseCase,
            fetchHealthDataUseCase: fetchUseCase,
            logger: aiLogger
        )
        
        let trendsViewModel = TrendsViewModel(
            fetchHealthDataUseCase: fetchUseCase,
            trendAnalyzer: MockTrendAnalyzer(),
            logger: aiLogger
        )
        
        let goalsViewModel = GoalsViewModel(
            manageGoalsUseCase: MockManageGoalsUseCase(),
            fetchHealthDataUseCase: fetchUseCase,
            goalTracker: MockGoalTracker(),
            logger: aiLogger
        )
        
        return (healthDataViewModel, trendsViewModel, goalsViewModel, aiLogger)
    }
    
    private func createMockHealthDataDependencies() -> (RecordHealthDataUseCaseProtocol, FetchHealthDataUseCaseProtocol, AILoggerProtocol) {
        return (MockRecordHealthDataUseCase(), MockFetchHealthDataUseCase(), MockAILogger())
    }
    
    private func createViewModel() -> DashboardViewModel {
        let (healthDataVM, trendsVM, goalsVM, logger) = createMockViewModels()
        return DashboardViewModel(
            healthDataViewModel: healthDataVM,
            trendsViewModel: trendsVM,
            goalsViewModel: goalsVM,
            logger: logger
        )
    }
    
    @Test("DashboardViewModel should initialize with default values")
    func testInitialization() async throws {
        // Given & When
        let viewModel = createViewModel()
        
        // Then
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.lastUpdated == nil)
        #expect(viewModel.healthSummary == nil)
        #expect(viewModel.todayStats == nil)
        #expect(viewModel.recentAchievements.isEmpty)
        #expect(viewModel.urgentNotifications.isEmpty)
        #expect(viewModel.quickActions.count == 4)
        #expect(viewModel.hasData == false)
        #expect(viewModel.needsAttention == false)
        #expect(viewModel.overallHealthScore == 0.0)
        #expect(viewModel.todayProgress == 0.0)
        #expect(viewModel.streakCount == 0)
    }
    
    @Test("DashboardViewModel should load dashboard data successfully")
    func testLoadDashboardDataSuccess() async throws {
        // Given
        let (healthDataVM, trendsVM, goalsVM, logger) = createMockViewModels()
        
        // Setup mock health data
        let mockFetchUseCase = healthDataVM.fetchHealthDataUseCase as! MockFetchHealthDataUseCase
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        
        let sampleRecords = [
            HealthRecord(type: .weight, value: 70.0, unit: "kg"),
            HealthRecord(type: .weight, value: 69.5, unit: "kg")
        ]
        sampleRecords[0].timestamp = yesterday
        sampleRecords[1].timestamp = today
        mockFetchUseCase.mockRecords = sampleRecords
        
        // Setup mock goals
        let mockManageGoalsUseCase = goalsVM.manageGoalsUseCase as! MockManageGoalsUseCase
        let activeGoal = try Goal(
            type: .weight,
            targetValue: 65.0,
            deadline: Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        )
        activeGoal.currentValue = 32.5 // 50% progress
        mockManageGoalsUseCase.mockGoals = [activeGoal]
        
        let viewModel = DashboardViewModel(
            healthDataViewModel: healthDataVM,
            trendsViewModel: trendsVM,
            goalsViewModel: goalsVM,
            logger: logger
        )
        
        // When
        await viewModel.loadDashboardData()
        
        // Then
        #expect(viewModel.isLoading == false)
        #expect(viewModel.lastUpdated != nil)
        #expect(viewModel.hasData == true)
        #expect(viewModel.healthSummary != nil)
        #expect(viewModel.todayStats != nil)
        #expect(viewModel.overallHealthScore > 0.0)
        #expect(viewModel.streakCount >= 0)
        #expect(viewModel.errorMessage == nil)
    }
    
    @Test("DashboardViewModel should handle load error gracefully")
    func testLoadDashboardDataError() async throws {
        // Given
        let (healthDataVM, trendsVM, goalsVM, logger) = createMockViewModels()
        let mockFetchUseCase = healthDataVM.fetchHealthDataUseCase as! MockFetchHealthDataUseCase
        mockFetchUseCase.shouldThrowError = true
        
        let viewModel = DashboardViewModel(
            healthDataViewModel: healthDataVM,
            trendsViewModel: trendsVM,
            goalsViewModel: goalsVM,
            logger: logger
        )
        
        // When
        await viewModel.loadDashboardData()
        
        // Then
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.hasData == false)
    }
    
    @Test("DashboardViewModel should execute quick actions correctly")
    func testExecuteQuickActions() async throws {
        // Given
        let (healthDataVM, trendsVM, goalsVM, logger) = createMockViewModels()
        let viewModel = DashboardViewModel(
            healthDataViewModel: healthDataVM,
            trendsViewModel: trendsVM,
            goalsViewModel: goalsVM,
            logger: logger
        )
        
        let syncAction = QuickAction(
            id: UUID(),
            type: .syncHealthKit,
            title: "HealthKit同期",
            icon: "heart.fill",
            color: .red
        )
        
        // When
        await viewModel.executeQuickAction(syncAction)
        
        // Then
        let mockRecordUseCase = healthDataVM.recordHealthDataUseCase as! MockRecordHealthDataUseCase
        #expect(mockRecordUseCase.executeCallCount == 1)
    }
    
    @Test("DashboardViewModel should calculate overall health score correctly")
    func testOverallHealthScoreCalculation() async throws {
        // Given
        let (healthDataVM, trendsVM, goalsVM, logger) = createMockViewModels()
        
        // Setup mock data for health score calculation
        let mockFetchUseCase = healthDataVM.fetchHealthDataUseCase as! MockFetchHealthDataUseCase
        let now = Date()
        let recentRecords = (0..<7).map { dayOffset in
            let record = HealthRecord(type: .weight, value: 70.0, unit: "kg")
            record.timestamp = Calendar.current.date(byAdding: .day, value: -dayOffset, to: now)!
            return record
        }
        mockFetchUseCase.mockRecords = recentRecords
        
        let mockManageGoalsUseCase = goalsVM.manageGoalsUseCase as! MockManageGoalsUseCase
        let activeGoal = try Goal(
            type: .weight,
            targetValue: 65.0,
            deadline: Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        )
        activeGoal.currentValue = 48.75 // 75% progress
        mockManageGoalsUseCase.mockGoals = [activeGoal]
        
        let viewModel = DashboardViewModel(
            healthDataViewModel: healthDataVM,
            trendsViewModel: trendsVM,
            goalsViewModel: goalsVM,
            logger: logger
        )
        
        // When
        await viewModel.loadDashboardData()
        
        // Then
        #expect(viewModel.overallHealthScore > 0.5) // Should be good score with consistent data and good goal progress
        #expect(viewModel.healthSummary?.scoreGrade != nil)
    }
    
    @Test("DashboardViewModel should calculate streak correctly")
    func testStreakCalculation() async throws {
        // Given
        let (healthDataVM, trendsVM, goalsVM, logger) = createMockViewModels()
        let mockFetchUseCase = healthDataVM.fetchHealthDataUseCase as! MockFetchHealthDataUseCase
        
        let now = Date()
        let calendar = Calendar.current
        
        // Create records for consecutive days (3-day streak)
        let streakRecords = (0..<3).map { dayOffset in
            let record = HealthRecord(type: .weight, value: 70.0, unit: "kg")
            record.timestamp = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -dayOffset, to: now)!)
            return record
        }
        
        // Add a gap (no record 4 days ago)
        let olderRecord = HealthRecord(type: .weight, value: 69.0, unit: "kg")
        olderRecord.timestamp = calendar.date(byAdding: .day, value: -5, to: now)!
        
        mockFetchUseCase.mockRecords = streakRecords + [olderRecord]
        
        let viewModel = DashboardViewModel(
            healthDataViewModel: healthDataVM,
            trendsViewModel: trendsVM,
            goalsViewModel: goalsVM,
            logger: logger
        )
        
        // When
        await viewModel.loadDashboardData()
        
        // Then
        #expect(viewModel.streakCount == 3)
    }
    
    @Test("DashboardViewModel should generate today stats correctly")
    func testTodayStatsGeneration() async throws {
        // Given
        let (healthDataVM, trendsVM, goalsVM, logger) = createMockViewModels()
        let mockFetchUseCase = healthDataVM.fetchHealthDataUseCase as! MockFetchHealthDataUseCase
        
        let today = Calendar.current.startOfDay(for: Date())
        let todayRecords = [
            HealthRecord(type: .weight, value: 70.0, unit: "kg"),
            HealthRecord(type: .steps, value: 8000.0, unit: "count"),
            HealthRecord(type: .calories, value: 300.0, unit: "kcal")
        ]
        
        for record in todayRecords {
            record.timestamp = today
        }
        
        mockFetchUseCase.mockRecords = todayRecords
        
        let viewModel = DashboardViewModel(
            healthDataViewModel: healthDataVM,
            trendsViewModel: trendsVM,
            goalsViewModel: goalsVM,
            logger: logger
        )
        
        // When
        await viewModel.loadDashboardData()
        
        // Then
        #expect(viewModel.todayStats != nil)
        #expect(viewModel.todayStats?.dataPointsRecorded == 3)
        #expect(viewModel.todayStats?.recordsByType.count == 3)
        #expect(viewModel.todayProgress >= 0.0)
    }
    
    @Test("DashboardViewModel should generate notifications correctly")
    func testNotificationGeneration() async throws {
        // Given
        let (healthDataVM, trendsVM, goalsVM, logger) = createMockViewModels()
        
        // Setup goal that needs attention
        let mockManageGoalsUseCase = goalsVM.manageGoalsUseCase as! MockManageGoalsUseCase
        let lowProgressGoal = try Goal(
            type: .weight,
            targetValue: 65.0,
            deadline: Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        )
        lowProgressGoal.currentValue = 3.25 // Very low progress (5%)
        mockManageGoalsUseCase.mockGoals = [lowProgressGoal]
        
        let mockGoalTracker = goalsVM.goalTracker as! MockGoalTracker
        let criticalProgressDetail = GoalProgressDetail(
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
        mockGoalTracker.mockProgressDetails[lowProgressGoal.id] = criticalProgressDetail
        
        let viewModel = DashboardViewModel(
            healthDataViewModel: healthDataVM,
            trendsViewModel: trendsVM,
            goalsViewModel: goalsVM,
            logger: logger
        )
        
        // When
        await viewModel.loadDashboardData()
        
        // Then
        #expect(viewModel.urgentNotifications.count > 0)
        #expect(viewModel.needsAttention == true)
        
        let goalNotification = viewModel.urgentNotifications.first { $0.type == .goalNeedsAttention }
        #expect(goalNotification != nil)
        #expect(goalNotification?.priority == .high)
    }
    
    @Test("DashboardViewModel should dismiss notifications correctly")
    func testNotificationDismissal() async throws {
        // Given
        let viewModel = createViewModel()
        let notification = DashboardNotification(
            id: UUID(),
            type: .reminder,
            title: "Test Notification",
            message: "Test Message",
            priority: .medium,
            actionRequired: false
        )
        
        await MainActor.run {
            viewModel.urgentNotifications.append(notification)
        }
        
        #expect(viewModel.urgentNotifications.count == 1)
        
        // When
        await viewModel.dismissNotification(notification)
        
        // Then
        #expect(viewModel.urgentNotifications.isEmpty)
    }
    
    @Test("DashboardViewModel should dismiss all notifications")
    func testDismissAllNotifications() async throws {
        // Given
        let viewModel = createViewModel()
        let notifications = [
            DashboardNotification(
                id: UUID(),
                type: .reminder,
                title: "Notification 1",
                message: "Message 1",
                priority: .medium,
                actionRequired: false
            ),
            DashboardNotification(
                id: UUID(),
                type: .goalNeedsAttention,
                title: "Notification 2",
                message: "Message 2",
                priority: .high,
                actionRequired: true
            )
        ]
        
        await MainActor.run {
            viewModel.urgentNotifications.append(contentsOf: notifications)
        }
        
        #expect(viewModel.urgentNotifications.count == 2)
        
        // When
        await viewModel.dismissAllNotifications()
        
        // Then
        #expect(viewModel.urgentNotifications.isEmpty)
    }
    
    @Test("DashboardViewModel should generate recent achievements")
    func testRecentAchievementsGeneration() async throws {
        // Given
        let (healthDataVM, trendsVM, goalsVM, logger) = createMockViewModels()
        
        // Setup completed goal
        let mockManageGoalsUseCase = goalsVM.manageGoalsUseCase as! MockManageGoalsUseCase
        let completedGoal = try Goal(
            type: .weight,
            targetValue: 65.0,
            deadline: Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        )
        completedGoal.currentValue = 65.0 // Completed
        completedGoal.completedDate = Calendar.current.date(byAdding: .day, value: -2, to: Date()) // Completed 2 days ago
        mockManageGoalsUseCase.mockGoals = [completedGoal]
        
        // Setup recent health records for streak
        let mockFetchUseCase = healthDataVM.fetchHealthDataUseCase as! MockFetchHealthDataUseCase
        let recentRecords = (0..<7).map { dayOffset in
            let record = HealthRecord(type: .weight, value: 70.0, unit: "kg")
            record.timestamp = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
            return record
        }
        mockFetchUseCase.mockRecords = recentRecords
        
        let viewModel = DashboardViewModel(
            healthDataViewModel: healthDataVM,
            trendsViewModel: trendsVM,
            goalsViewModel: goalsVM,
            logger: logger
        )
        
        // When
        await viewModel.loadDashboardData()
        
        // Then
        #expect(viewModel.recentAchievements.count > 0)
        
        let goalAchievement = viewModel.recentAchievements.first { $0.type == .goalCompleted }
        #expect(goalAchievement != nil)
        
        let streakAchievement = viewModel.recentAchievements.first { $0.type == .streakMilestone }
        #expect(streakAchievement != nil)
    }
    
    @Test("DashboardViewModel should clear error message")
    func testClearError() async throws {
        // Given
        let (healthDataVM, trendsVM, goalsVM, logger) = createMockViewModels()
        let mockFetchUseCase = healthDataVM.fetchHealthDataUseCase as! MockFetchHealthDataUseCase
        mockFetchUseCase.shouldThrowError = true
        
        let viewModel = DashboardViewModel(
            healthDataViewModel: healthDataVM,
            trendsViewModel: trendsVM,
            goalsViewModel: goalsVM,
            logger: logger
        )
        
        await viewModel.loadDashboardData()
        #expect(viewModel.errorMessage != nil)
        
        // When
        await viewModel.clearError()
        
        // Then
        #expect(viewModel.errorMessage == nil)
    }
    
    @Test("DashboardViewModel should format last updated time correctly")
    func testFormattedLastUpdated() async throws {
        // Given
        let viewModel = createViewModel()
        
        // When - No last updated time
        let noUpdateText = viewModel.formattedLastUpdated
        
        // Then
        #expect(noUpdateText == "未更新")
        
        // When - Set last updated time
        await viewModel.loadDashboardData()
        let formattedTime = viewModel.formattedLastUpdated
        
        // Then
        #expect(formattedTime != "未更新")
        #expect(formattedTime.contains(":")) // Should contain time format
    }
    
    @Test("DashboardViewModel should prevent concurrent loading")
    func testConcurrentLoadingPrevention() async throws {
        // Given
        let (healthDataVM, trendsVM, goalsVM, logger) = createMockViewModels()
        let mockFetchUseCase = healthDataVM.fetchHealthDataUseCase as! MockFetchHealthDataUseCase
        mockFetchUseCase.shouldDelay = true
        
        let viewModel = DashboardViewModel(
            healthDataViewModel: healthDataVM,
            trendsViewModel: trendsVM,
            goalsViewModel: goalsVM,
            logger: logger
        )
        
        // When - Start two concurrent loads
        async let load1 = viewModel.loadDashboardData()
        async let load2 = viewModel.loadDashboardData()
        
        await load1
        await load2
        
        // Then - Only one load should have executed
        #expect(mockFetchUseCase.fetchCallCount == 1) // Called once from health data VM
    }
}