import SwiftUI
import SwiftData
import BackgroundTasks
#if canImport(UIKit)
import UIKit
#endif

@main
struct HealthRecordingAppApp: App {
    
    // MARK: - Properties
    private let logger = AILogger()
    private let backgroundSyncManager = BackgroundSyncManager.shared
    
    // MARK: - App Lifecycle
    
    init() {
        // Register background tasks
        backgroundSyncManager.registerBackgroundTasks()
        
        logger.info("HealthRecordingApp initialized", context: [
            "app_version": "1.0.0",
            "background_refresh_enabled": backgroundSyncManager.isBackgroundRefreshEnabled
        ])
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(sharedModelContainer)
                .onAppear {
                    setupAppLifecycleHandling()
                    
                    logger.info("HealthRecordingApp launched", context: [
                        "app_version": "1.0.0"
                    ])
                }
        }
    }
    
    // MARK: - App Lifecycle Setup
    
    private func setupAppLifecycleHandling() {
        #if canImport(UIKit)
        // Set up notification observers for app lifecycle events
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            backgroundSyncManager.handleAppDidEnterBackground()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            backgroundSyncManager.handleAppWillEnterForeground()
        }
        #endif
        
        // Setup background sync for essential health data types
        Task {
            do {
                let essentialDataTypes: Set<HealthDataType> = [.weight, .steps, .calories]
                try await backgroundSyncManager.setupBackgroundSync(for: essentialDataTypes)
                
                logger.info("Background sync setup completed", context: [
                    "data_types": essentialDataTypes.map { $0.rawValue }
                ])
                
            } catch {
                logger.error(error, context: [
                    "operation": "background_sync_setup"
                ])
            }
        }
    }
    
    // MARK: - Shared Model Container
    
    var sharedModelContainer: ModelContainer {
        let schema = Schema([
            HealthRecord.self,
            User.self,
            Goal.self,
            Badge.self,
            Item.self  // Keep for backward compatibility during development
        ])
        
        let modelConfiguration = ModelConfiguration(
            isStoredInMemoryOnly: false
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            logger.info("ModelContainer initialized successfully", context: [
                "schema_types": schema.entities.map { $0.name },
                "cloudkit_enabled": true
            ])
            
            return container
            
        } catch {
            logger.error(error, context: [
                "operation": "model_container_initialization",
                "schema_types": schema.entities.map { $0.name }
            ])
            
            // Fallback to in-memory container for development
            do {
                let fallbackConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    allowsSave: true
                )
                
                let fallbackContainer = try ModelContainer(for: schema, configurations: [fallbackConfiguration])
                
                logger.warning("Using fallback in-memory ModelContainer", context: [
                    "reason": "primary_container_failed"
                ])
                
                return fallbackContainer
                
            } catch {
                logger.error(error, context: [
                    "operation": "fallback_container_initialization"
                ])
                
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }
}