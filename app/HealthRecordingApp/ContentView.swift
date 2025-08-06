import SwiftUI
import SwiftData

struct ContentView: View {
    // MARK: - Environment
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - State
    @State private var isInitialized = false
    @State private var isLoading = true
    @State private var initializationError: Error?
    
    // MARK: - Dependencies
    @State private var healthDataViewModel: HealthDataViewModel?
    @State private var trendsViewModel: TrendsViewModel?
    @State private var goalsViewModel: GoalsViewModel?
    @State private var dashboardViewModel: DashboardViewModel?
    @State private var healthKitAuthManager: HealthKitAuthenticationManager?
    
    private let logger = AILogger()
    
    var body: some View {
        ZStack {
            if isLoading {
                LoadingView(message: "アプリを初期化中...")
            } else if let error = initializationError {
                ErrorView(
                    error: error,
                    title: "初期化エラー",
                    message: "アプリの初期化に失敗しました。",
                    primaryAction: UIErrorAction("再試行") {
                        Task {
                            await initializeApp()
                        }
                    }
                )
            } else if let healthDataVM = healthDataViewModel,
                      let trendsVM = trendsViewModel,
                      let goalsVM = goalsViewModel,
                      let dashboardVM = dashboardViewModel,
                      let authManager = healthKitAuthManager {
                MainTabView(
                    healthDataViewModel: healthDataVM,
                    trendsViewModel: trendsVM,
                    goalsViewModel: goalsVM,
                    dashboardViewModel: dashboardVM,
                    healthKitAuthManager: authManager
                )
            } else {
                // Fallback loading state
                LoadingView(message: "ViewModelsを準備中...")
            }
        }
        .task {
            if !isInitialized {
                await initializeApp()
            }
        }
    }
    
    // MARK: - Initialization
    
    @MainActor
    private func initializeApp() async {
        logger.info("Starting app initialization", context: nil)
        isLoading = true
        initializationError = nil
        
        do {
            // Initialize repositories
            let healthRecordRepository = SwiftDataHealthRecordRepository(modelContext: modelContext)
            let userRepository = SwiftDataUserRepository(modelContext: modelContext)
            let goalRepository = SwiftDataGoalRepository(modelContext: modelContext)
            let badgeRepository = SwiftDataBadgeRepository(modelContext: modelContext)
            
            // Initialize services
            let healthKitService = HealthKitService()
            let trendAnalyzer = TrendAnalyzer(logger: logger)
            let goalTracker = GoalTracker()
            let insightEngine = InsightEngine()
            
            // Initialize use cases
            let recordHealthDataUseCase = RecordHealthDataUseCase(
                healthRecordRepository: healthRecordRepository,
                userRepository: userRepository,
                badgeRepository: badgeRepository,
                healthKitService: healthKitService,
                logger: logger
            )
            
            let fetchHealthDataUseCase = FetchHealthDataUseCase(
                healthRecordRepository: healthRecordRepository,
                userRepository: userRepository,
                logger: logger
            )
            
            let manageGoalsUseCase = ManageGoalsUseCase(
                goalRepository: goalRepository,
                healthRecordRepository: healthRecordRepository,
                userRepository: userRepository,
                logger: logger
            )
            
            // Initialize HealthKit Authentication Manager
            let authManager = HealthKitAuthenticationManager(
                healthKitService: healthKitService,
                logger: logger
            )
            
            // Initialize ViewModels
            let healthDataVM = HealthDataViewModel(
                recordHealthDataUseCase: recordHealthDataUseCase,
                fetchHealthDataUseCase: fetchHealthDataUseCase,
                logger: logger
            )
            
            let trendsVM = TrendsViewModel(
                fetchHealthDataUseCase: fetchHealthDataUseCase,
                trendAnalyzer: trendAnalyzer,
                logger: logger
            )
            
            let goalsVM = GoalsViewModel(
                manageGoalsUseCase: manageGoalsUseCase,
                fetchHealthDataUseCase: fetchHealthDataUseCase,
                goalTracker: goalTracker,
                logger: logger
            )
            
            let dashboardVM = DashboardViewModel(
                healthDataViewModel: healthDataVM,
                trendsViewModel: trendsVM,
                goalsViewModel: goalsVM,
                logger: logger
            )
            
            // Set ViewModels and Managers
            self.healthKitAuthManager = authManager
            self.healthDataViewModel = healthDataVM
            self.trendsViewModel = trendsVM
            self.goalsViewModel = goalsVM
            self.dashboardViewModel = dashboardVM
            
            isInitialized = true
            isLoading = false
            
            logger.info("App initialization completed successfully", context: [
                "viewmodels_created": 4,
                "repositories_created": 4,
                "use_cases_created": 3
            ])
            
        } catch {
            logger.error(error, context: [
                "operation": "app_initialization"
            ])
            
            initializationError = error
            isLoading = false
        }
    }
}

// MARK: - Dependency Injection Helpers

extension ContentView {
    
    /// Create a default user if none exists
    private func createDefaultUserIfNeeded() async throws {
        let userRepository = SwiftDataUserRepository(modelContext: modelContext)
        
        do {
            let existingUser = try await userRepository.fetchCurrentUser()
            if existingUser == nil {
                let defaultUser = try User(
                    name: "ユーザー",
                    age: 30,
                    height: 170.0,
                    targetWeight: 65.0
                )
                try await userRepository.save(defaultUser)
                
                logger.info("Default user created", context: [
                    "user_id": defaultUser.id.uuidString
                ])
            }
        } catch {
            logger.warning("Failed to create default user", context: [
                "error": error.localizedDescription
            ])
            // Non-fatal error, continue with app initialization
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(previewContainer)
}

// MARK: - Preview Model Container

private var previewContainer: ModelContainer {
    let schema = Schema([
        HealthRecord.self,
        User.self,
        Goal.self,
        Badge.self,
        Item.self
    ])
    
    let configuration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: true
    )
    
    do {
        let container = try ModelContainer(for: schema, configurations: [configuration])
        
        // Add sample data for preview
        Task {
            await addSampleData(to: container.mainContext)
        }
        
        return container
    } catch {
        fatalError("Could not create preview ModelContainer: \(error)")
    }
}

@MainActor
private func addSampleData(to context: ModelContext) {
    do {
        // Create sample user
        let sampleUser = try User(
            name: "サンプルユーザー",
            age: 30,
            height: 175.0,
            targetWeight: 70.0
        )
        context.insert(sampleUser)
        
        // Create sample health records
        let sampleRecords = [
            HealthRecord(type: .weight, value: 72.5, unit: "kg", source: .healthKit),
            HealthRecord(type: .weight, value: 72.0, unit: "kg", source: .healthKit),
            HealthRecord(type: .weight, value: 71.8, unit: "kg", source: .healthKit),
            HealthRecord(type: .steps, value: 8500, unit: "count", source: .healthKit),  
            HealthRecord(type: .calories, value: 2200, unit: "kcal", source: .healthKit)
        ]
        
        for record in sampleRecords {
            record.user = sampleUser
            context.insert(record)
        }
        
        // Create sample goal
        let sampleGoal = try Goal(
            type: .weight,
            targetValue: 70.0,
            deadline: Date().addingTimeInterval(86400 * 30)
        )
        sampleGoal.user = sampleUser
        context.insert(sampleGoal)
        
        try context.save()
        
    } catch {
        print("Failed to add sample data: \(error)")
    }
}