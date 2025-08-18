import Foundation
import SwiftUI
import SwiftData

/// ViewModel for the Progressive Goal Setup Wizard
/// Manages all state and business logic for step-by-step goal creation
@Observable
final class GoalSetupWizardViewModel {
    
    // MARK: - Published Properties
    
    // Step 1: Data Type Selection
    var selectedDataType: HealthDataType?
    var availableDataTypes: [HealthDataType] = []
    
    // Step 2: AI Suggestions
    var aiSuggestions: [AIGoalSuggestion] = []
    var selectedAISuggestion: AIGoalSuggestion?
    var isLoadingAISuggestions = false
    
    // Step 3: Target Customization
    var targetValue: Double = 0.0
    var timeframe: GoalTimeframe = .month
    
    // Step 4: Seasonal Adaptation
    var seasonalAdjustments: [SeasonalGoalAdjustment] = []
    var enableSeasonalAdaptation = false
    
    // Step 5: Progressive Planning
    var progressivePlan: ProgressiveGoalPlan?
    var enableProgressivePlanning = false
    var phaseCount: Int = 3
    
    // Step 6: Confirmation
    var goalSummary: GoalSummary?
    
    // General state
    var isLoading = false
    var errorMessage: String?
    var isSaving = false
    
    // MARK: - Dependencies
    private let goalTracker: GoalTrackerProtocol
    private let manageGoalsUseCase: ManageGoalsUseCaseProtocol
    private let fetchHealthDataUseCase: FetchHealthDataUseCaseProtocol
    private let logger: AILoggerProtocol
    
    // MARK: - Initialization
    init(
        goalTracker: GoalTrackerProtocol = GoalTracker(),
        manageGoalsUseCase: ManageGoalsUseCaseProtocol,
        fetchHealthDataUseCase: FetchHealthDataUseCaseProtocol,
        logger: AILoggerProtocol = AILogger()
    ) {
        self.goalTracker = goalTracker
        self.manageGoalsUseCase = manageGoalsUseCase
        self.fetchHealthDataUseCase = fetchHealthDataUseCase
        self.logger = logger
        
        logger.debug("GoalSetupWizardViewModel initialized", context: nil)
    }
    
    // MARK: - Wizard State Management
    
    /// Check if the user can proceed from the current step
    func canProceedFromCurrentStep(_ step: WizardStep) -> Bool {
        switch step {
        case .dataTypeSelection:
            return selectedDataType != nil
            
        case .aiSuggestions:
            return selectedAISuggestion != nil || !aiSuggestions.isEmpty
            
        case .targetCustomization:
            return targetValue > 0
            
        case .seasonalAdaptation:
            return true // Always can proceed from seasonal adaptation
            
        case .progressivePlanning:
            return true // Always can proceed from progressive planning
            
        case .confirmation:
            return goalSummary != nil && !isSaving
        }
    }
    
    // MARK: - Data Loading
    
    /// Load initial data for the wizard
    @MainActor
    func loadInitialData() async {
        logger.debug("Loading initial wizard data", context: nil)
        
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let startTime = Date()
            
            // Load available data types
            availableDataTypes = HealthDataType.allCases.filter { $0.isAvailableForGoals }
            
            logger.info("Loaded initial wizard data", context: [
                "availableDataTypesCount": availableDataTypes.count
            ])
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("load_wizard_initial_data", duration: duration, success: true)
            
        } catch {
            let duration = Date().timeIntervalSince(Date())
            logger.logPerformance("load_wizard_initial_data", duration: duration, success: false)
            logger.error(error, context: ["operation": "load_wizard_initial_data"])
            errorMessage = handleError(error)
        }
    }
    
    /// Prepare data for a specific wizard step
    @MainActor
    func prepareForStep(_ step: WizardStep) async {
        logger.debug("Preparing for wizard step", context: [
            "step": step.rawValue,
            "stepTitle": step.title
        ])
        
        switch step {
        case .dataTypeSelection:
            // Already loaded in loadInitialData
            break
            
        case .aiSuggestions:
            await loadAISuggestions()
            
        case .targetCustomization:
            await prepareTargetCustomization()
            
        case .seasonalAdaptation:
            await prepareSeasonalAdaptation()
            
        case .progressivePlanning:
            await prepareProgressivePlanning()
            
        case .confirmation:
            await prepareGoalSummary()
        }
    }
    
    // MARK: - AI Suggestions
    
    @MainActor
    private func loadAISuggestions() async {
        guard let dataType = selectedDataType else {
            logger.warning("Cannot load AI suggestions without selected data type", context: nil)
            return
        }
        
        guard !isLoadingAISuggestions else { return }
        isLoadingAISuggestions = true
        errorMessage = nil
        defer { isLoadingAISuggestions = false }
        
        do {
            let startTime = Date()
            let mockUser = createMockUser()
            
            logger.info("Loading AI goal suggestions", context: [
                "dataType": dataType.rawValue
            ])
            
            // Get recent health records for this data type
            let healthRecords = try await fetchHealthDataUseCase.fetchHealthRecords(
                for: mockUser,
                type: dataType,
                dateRange: DateRange.lastThreeMonths,
                limit: 100
            )
            
            // Generate AI suggestions
            let suggestions = try await goalTracker.generateAIGoalSuggestions(
                for: mockUser,
                healthRecords: healthRecords,
                analysisDepth: .detailed
            )
            
            // Filter suggestions for the selected data type
            aiSuggestions = suggestions.filter { $0.goalType == dataType }
            
            // Auto-select the highest confidence suggestion if available
            if let topSuggestion = aiSuggestions.first {
                selectedAISuggestion = topSuggestion
                targetValue = topSuggestion.suggestedTarget
            }
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("load_ai_suggestions", duration: duration, success: true)
            logger.info("Loaded AI suggestions", context: [
                "suggestionCount": aiSuggestions.count,
                "dataType": dataType.rawValue
            ])
            
        } catch {
            let duration = Date().timeIntervalSince(Date())
            logger.logPerformance("load_ai_suggestions", duration: duration, success: false)
            logger.error(error, context: [
                "operation": "load_ai_suggestions",
                "dataType": dataType.rawValue
            ])
            errorMessage = handleError(error)
        }
    }
    
    // MARK: - Target Customization
    
    @MainActor
    private func prepareTargetCustomization() async {
        guard let dataType = selectedDataType else { return }
        
        // If no AI suggestion was selected, set reasonable defaults
        if selectedAISuggestion == nil && targetValue == 0 {
            targetValue = getDefaultTargetValue(for: dataType)
        }
        
        logger.debug("Prepared target customization", context: [
            "dataType": dataType.rawValue,
            "targetValue": targetValue,
            "timeframe": timeframe.rawValue
        ])
    }
    
    // MARK: - Seasonal Adaptation
    
    @MainActor
    private func prepareSeasonalAdaptation() async {
        guard let dataType = selectedDataType else { return }
        
        do {
            let startTime = Date()
            
            logger.info("Preparing seasonal adaptation", context: [
                "dataType": dataType.rawValue,
                "enableSeasonalAdaptation": enableSeasonalAdaptation
            ])
            
            // Generate seasonal adjustments based on data type and target value
            seasonalAdjustments = await generateSeasonalAdjustments(
                for: dataType,
                targetValue: targetValue
            )
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("prepare_seasonal_adaptation", duration: duration, success: true)
            
        } catch {
            logger.error(error, context: [
                "operation": "prepare_seasonal_adaptation",
                "dataType": dataType.rawValue
            ])
        }
    }
    
    // MARK: - Progressive Planning
    
    @MainActor
    private func prepareProgressivePlanning() async {
        guard let dataType = selectedDataType else { return }
        
        do {
            let startTime = Date()
            
            logger.info("Preparing progressive planning", context: [
                "dataType": dataType.rawValue,
                "enableProgressivePlanning": enableProgressivePlanning,
                "phaseCount": phaseCount
            ])
            
            if enableProgressivePlanning {
                progressivePlan = await generateProgressivePlan(
                    for: dataType,
                    targetValue: targetValue,
                    timeframe: timeframe,
                    phaseCount: phaseCount
                )
            }
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("prepare_progressive_planning", duration: duration, success: true)
            
        } catch {
            logger.error(error, context: [
                "operation": "prepare_progressive_planning",
                "dataType": dataType.rawValue
            ])
        }
    }
    
    // MARK: - Goal Summary
    
    @MainActor
    private func prepareGoalSummary() async {
        guard let dataType = selectedDataType else { return }
        
        goalSummary = GoalSummary(
            goalType: dataType,
            targetValue: targetValue,
            targetUnit: dataType.defaultUnit,
            timeframe: timeframe,
            hasSeasonalAdaptation: enableSeasonalAdaptation,
            hasProgressivePlanning: enableProgressivePlanning,
            phaseCount: enableProgressivePlanning ? phaseCount : 0,
            aiSuggestion: selectedAISuggestion
        )
        
        logger.debug("Prepared goal summary", context: [
            "goalType": dataType.rawValue,
            "targetValue": targetValue,
            "hasSeasonalAdaptation": enableSeasonalAdaptation,
            "hasProgressivePlanning": enableProgressivePlanning
        ])
    }
    
    // MARK: - Goal Creation
    
    /// Create the final goal using the wizard configuration
    @MainActor
    func createGoal(using modelContext: ModelContext) async throws -> Goal {
        logger.debug("Starting goal creation from wizard", context: [
            "goalType": selectedDataType?.rawValue ?? "nil",
            "targetValue": targetValue
        ])
        
        guard let dataType = selectedDataType else {
            throw GoalWizardError.missingDataType
        }
        
        guard !isSaving else {
            logger.warning("Goal creation already in progress", context: nil)
            throw GoalWizardError.operationInProgress
        }
        
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        
        do {
            let startTime = Date()
            let mockUser = createMockUser()
            
            logger.info("Creating goal from wizard", context: [
                "goalType": dataType.rawValue,
                "targetValue": targetValue,
                "timeframe": timeframe.rawValue,
                "hasSeasonalAdaptation": enableSeasonalAdaptation,
                "hasProgressivePlanning": enableProgressivePlanning
            ])
            
            // Create goal creation data
            let goalData = GoalCreationData(
                type: dataType,
                targetValue: targetValue,
                deadline: calculateDeadline(from: timeframe),
                description: generateGoalDescription(),
                seasonalAdjustments: enableSeasonalAdaptation ? seasonalAdjustments : nil,
                progressivePlan: enableProgressivePlanning ? progressivePlan : nil,
                aiSuggestionId: selectedAISuggestion?.id
            )
            
            // Create the goal
            let createdGoal = try await manageGoalsUseCase.createGoal(
                for: mockUser,
                goalData: goalData
            )
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("create_goal_from_wizard", duration: duration, success: true)
            logger.logUserAction("wizard_goal_created", parameters: [
                "goalId": createdGoal.id.uuidString,
                "goalType": dataType.rawValue,
                "targetValue": targetValue,
                "hasSeasonalAdaptation": enableSeasonalAdaptation,
                "hasProgressivePlanning": enableProgressivePlanning,
                "wizardStepsCompleted": 6
            ])
            
            return createdGoal
            
        } catch {
            let duration = Date().timeIntervalSince(Date())
            logger.logPerformance("create_goal_from_wizard", duration: duration, success: false)
            logger.error(error, context: [
                "operation": "create_goal_from_wizard",
                "goalType": dataType.rawValue
            ])
            errorMessage = handleError(error)
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockUser() -> User {
        do {
            return try User(name: "テストユーザー", age: 30, height: 175.0, targetWeight: 70.0)
        } catch {
            logger.error(error, context: ["operation": "create_mock_user"])
            fatalError("Failed to create mock user: \(error)")
        }
    }
    
    private func getDefaultTargetValue(for dataType: HealthDataType) -> Double {
        switch dataType {
        case .weight:
            return 70.0
        case .steps:
            return 10000.0
        case .calories:
            return 300.0
        case .sleep:
            return 8.0
        case .heartRate:
            return 60.0
        case .hydration:
            return 2000.0
        default:
            return 100.0
        }
    }
    
    private func generateSeasonalAdjustments(
        for dataType: HealthDataType,
        targetValue: Double
    ) async -> [SeasonalGoalAdjustment] {
        // Generate seasonal adjustments based on data type patterns
        return Season.allCases.compactMap { season in
            let adjustment = getSeasonalAdjustmentRatio(for: dataType, season: season)
            guard adjustment != 1.0 else { return nil }
            
            return SeasonalGoalAdjustment(
                season: season,
                adjustmentRatio: adjustment,
                rationale: getSeasonalRationale(for: dataType, season: season),
                isActive: true
            )
        }
    }
    
    private func getSeasonalAdjustmentRatio(for dataType: HealthDataType, season: Season) -> Double {
        switch (dataType, season) {
        case (.steps, .winter):
            return 0.85 // Reduced activity in winter
        case (.steps, .summer):
            return 1.15 // Increased outdoor activity
        case (.hydration, .summer):
            return 1.25 // More hydration needed in summer
        case (.hydration, .winter):
            return 0.9 // Less hydration needed in winter
        case (.calories, .winter):
            return 1.1 // More calories burned in cold weather
        default:
            return 1.0 // No adjustment
        }
    }
    
    private func getSeasonalRationale(for dataType: HealthDataType, season: Season) -> String {
        switch (dataType, season) {
        case (.steps, .winter):
            return "寒い季節は屋外活動が減るため、目標を調整します"
        case (.steps, .summer):
            return "暖かい季節は活動量が増える傾向があります"
        case (.hydration, .summer):
            return "暑い季節は脱水予防のため、より多くの水分が必要です"
        case (.hydration, .winter):
            return "寒い季節は水分必要量が減る傾向があります"
        case (.calories, .winter):
            return "寒い季節は基礎代謝が上がる傾向があります"
        default:
            return "季節に応じた目標調整"
        }
    }
    
    private func generateProgressivePlan(
        for dataType: HealthDataType,
        targetValue: Double,
        timeframe: GoalTimeframe,
        phaseCount: Int
    ) async -> ProgressiveGoalPlan {
        let totalDays = timeframe.days
        let daysPerPhase = totalDays / phaseCount
        
        let phases = (0..<phaseCount).map { phaseIndex in
            let phaseProgress = Double(phaseIndex + 1) / Double(phaseCount)
            let phaseTargetValue = targetValue * phaseProgress
            let phaseEndDate = Date().addingTimeInterval(TimeInterval(daysPerPhase * (phaseIndex + 1) * 24 * 3600))
            
            return GoalPhase(
                phaseNumber: phaseIndex + 1,
                targetValue: phaseTargetValue,
                endDate: phaseEndDate,
                description: "フェーズ \(phaseIndex + 1): \(phaseTargetValue, specifier: "%.1f") \(dataType.defaultUnit)まで"
            )
        }
        
        return ProgressiveGoalPlan(
            phases: phases,
            strategy: .linear,
            adaptationRules: []
        )
    }
    
    private func calculateDeadline(from timeframe: GoalTimeframe) -> Date {
        return Date().addingTimeInterval(TimeInterval(timeframe.days * 24 * 3600))
    }
    
    private func generateGoalDescription() -> String {
        guard let dataType = selectedDataType else { return "" }
        
        var description = "\(dataType.displayName)目標: \(targetValue, specifier: "%.1f") \(dataType.defaultUnit)"
        
        if enableSeasonalAdaptation {
            description += "\n季節適応機能付き"
        }
        
        if enableProgressivePlanning {
            description += "\n段階的プラン（\(phaseCount)フェーズ）"
        }
        
        if let aiSuggestion = selectedAISuggestion {
            description += "\nAI提案に基づく目標設定"
        }
        
        return description
    }
    
    // MARK: - Error Handling
    
    @MainActor
    func clearError() {
        errorMessage = nil
        logger.debug("Goal wizard error message cleared by user", context: nil)
    }
    
    private func handleError(_ error: Error) -> String {
        if let wizardError = error as? GoalWizardError {
            return wizardError.localizedDescription
        }
        if let healthAppError = error as? any HealthAppError {
            return healthAppError.localizedDescription
        }
        return "目標設定中にエラーが発生しました: \(error.localizedDescription)"
    }
}

// MARK: - Supporting Types

/// Summary of the goal configuration for final confirmation
struct GoalSummary {
    let goalType: HealthDataType
    let targetValue: Double
    let targetUnit: String
    let timeframe: GoalTimeframe
    let hasSeasonalAdaptation: Bool
    let hasProgressivePlanning: Bool
    let phaseCount: Int
    let aiSuggestion: AIGoalSuggestion?
}

/// Errors specific to the goal setup wizard
enum GoalWizardError: LocalizedError {
    case missingDataType
    case operationInProgress
    case invalidConfiguration
    
    var errorDescription: String? {
        switch self {
        case .missingDataType:
            return "データタイプが選択されていません"
        case .operationInProgress:
            return "処理が進行中です"
        case .invalidConfiguration:
            return "設定が無効です"
        }
    }
}

// MARK: - Extensions

extension HealthDataType {
    /// Whether this data type is available for goal setting
    var isAvailableForGoals: Bool {
        switch self {
        case .weight, .steps, .calories, .sleep, .heartRate, .hydration, .exercise:
            return true
        case .bloodGlucose, .bloodPressure, .custom:
            return false
        }
    }
}

extension GoalTimeframe {
    /// Number of days for this timeframe
    var days: Int {
        switch self {
        case .week:
            return 7
        case .month:
            return 30
        case .quarter:
            return 90
        case .year:
            return 365
        }
    }
}

extension DateRange {
    static var lastThreeMonths: DateRange {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .month, value: -3, to: endDate) ?? endDate
        return DateRange(startDate: startDate, endDate: endDate)
    }
}