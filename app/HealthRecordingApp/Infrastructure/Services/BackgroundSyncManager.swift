import Foundation
import HealthKit
import BackgroundTasks
import UIKit

// MARK: - Background Sync Manager

final class BackgroundSyncManager: ObservableObject {
    
    static let shared = BackgroundSyncManager()
    
    private let healthKitService: HealthKitService
    private let logger: AILoggerProtocol
    private var backgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid
    private var activeObservers: [HealthDataObserver] = []
    
    // Background task identifier for app refresh
    static let backgroundRefreshTaskIdentifier = "com.healthrecordingapp.background-sync"
    
    private init(
        healthKitService: HealthKitService = HealthKitService(),
        logger: AILoggerProtocol = AILogger()
    ) {
        self.healthKitService = healthKitService
        self.logger = logger
    }
    
    // MARK: - Background Task Registration
    
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.backgroundRefreshTaskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
        
        logger.info("Background tasks registered", context: [
            "task_identifier": Self.backgroundRefreshTaskIdentifier
        ])
    }
    
    // MARK: - Background Sync Setup
    
    func setupBackgroundSync(for dataTypes: Set<HealthDataType>) async throws {
        logger.info("Setting up background sync", context: [
            "data_types": dataTypes.map { $0.rawValue }
        ])
        
        // Clear existing observers
        stopAllObservers()
        
        // Set up new observers for each data type
        for dataType in dataTypes {
            do {
                let observer = try await healthKitService.observeHealthDataChanges(for: dataType) { [weak self] healthRecords in
                    Task { [weak self] in
                        await self?.handleDataUpdate(dataType: dataType, records: healthRecords)
                    }
                }
                activeObservers.append(observer)
                
                logger.debug("Observer setup successful", context: [
                    "data_type": dataType.rawValue
                ])
                
            } catch {
                logger.error(error, context: [
                    "operation": "setup_background_observer",
                    "data_type": dataType.rawValue
                ])
            }
        }
        
        // Schedule background app refresh
        scheduleBackgroundRefresh()
    }
    
    // MARK: - Background Refresh Handling
    
    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        logger.info("Background refresh task started", context: [
            "task_identifier": task.identifier,
            "timestamp": Date().ISO8601Format()
        ])
        
        // Set expiration handler
        task.expirationHandler = { [weak self] in
            self?.logger.warning("Background task expired", context: [
                "task_identifier": task.identifier
            ])
            task.setTaskCompleted(success: false)
        }
        
        // Perform background sync
        Task {
            do {
                await performBackgroundDataSync()
                
                // Schedule next background refresh
                scheduleBackgroundRefresh()
                
                logger.info("Background refresh completed successfully", context: [:])
                task.setTaskCompleted(success: true)
                
            } catch {
                logger.error(error, context: [
                    "operation": "background_refresh"
                ])
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    private func performBackgroundDataSync() async {
        let dataTypes: [HealthDataType] = [.weight, .steps, .calories, .heartRate]
        
        logger.debug("Starting background data sync", context: [
            "data_types": dataTypes.map { $0.rawValue }
        ])
        
        for dataType in dataTypes {
            do {
                // Use anchored query for efficient data fetching
                let newData = try await healthKitService.readNewHealthData(type: dataType, limit: 50)
                
                if !newData.isEmpty {
                    logger.info("New health data found in background", context: [
                        "data_type": dataType.rawValue,
                        "count": newData.count
                    ])
                    
                    // Convert to HealthRecord and process
                    let healthRecords = newData.map { data in
                        let record = HealthRecord(
                            type: data.type,
                            value: data.value,
                            unit: data.unit,
                            source: .healthKit
                        )
                        // Set the actual HealthKit data timestamp
                        record.timestamp = data.startDate
                        return record
                    }
                    
                    // Send notification to update UI when app becomes active
                    await handleDataUpdate(dataType: dataType, records: healthRecords)
                }
                
            } catch {
                logger.error(error, context: [
                    "operation": "background_sync_data_type",
                    "data_type": dataType.rawValue
                ])
            }
        }
    }
    
    // MARK: - Data Update Handling
    
    private func handleDataUpdate(dataType: HealthDataType, records: [HealthRecord]) async {
        logger.debug("Handling data update", context: [
            "data_type": dataType.rawValue,
            "records_count": records.count
        ])
        
        // Post notification for UI updates
        await MainActor.run {
            NotificationCenter.default.post(
                name: .healthDataUpdated,
                object: nil,
                userInfo: [
                    "dataType": dataType,
                    "records": records
                ]
            )
        }
    }
    
    // MARK: - Background Task Scheduling
    
    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundRefreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.debug("Background refresh scheduled", context: [
                "next_execution": request.earliestBeginDate?.ISO8601Format() ?? "unknown"
            ])
        } catch {
            logger.error(error, context: [
                "operation": "schedule_background_refresh"
            ])
        }
    }
    
    // MARK: - App Lifecycle Management
    
    func handleAppDidEnterBackground() {
        logger.info("App entered background - starting background task", context: [:])
        
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "HealthData-Background-Sync") { [weak self] in
            self?.endBackgroundTask()
        }
        
        // Perform immediate sync if needed
        Task {
            await performBackgroundDataSync()
            endBackgroundTask()
        }
    }
    
    func handleAppWillEnterForeground() {
        logger.info("App will enter foreground", context: [:])
        endBackgroundTask()
        
        // Refresh data when coming back to foreground
        Task {
            await performBackgroundDataSync()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
            logger.debug("Background task ended", context: [:])
        }
    }
    
    // MARK: - Observer Management
    
    func stopAllObservers() {
        for observer in activeObservers {
            healthKitService.stopObserving(observer)
        }
        activeObservers.removeAll()
        
        logger.debug("All background observers stopped", context: [
            "observers_count": activeObservers.count
        ])
    }
    
    // MARK: - Status Methods
    
    var isBackgroundRefreshEnabled: Bool {
        return UIApplication.shared.backgroundRefreshStatus == .available
    }
    
    var backgroundRefreshStatus: UIBackgroundRefreshStatus {
        return UIApplication.shared.backgroundRefreshStatus
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let healthDataUpdated = Notification.Name("healthDataUpdated")
    static let backgroundSyncStatusChanged = Notification.Name("backgroundSyncStatusChanged")
}

// MARK: - Background Sync Error

enum BackgroundSyncError: LocalizedError {
    case backgroundRefreshDisabled
    case healthKitNotAuthorized
    case syncInProgress
    
    var errorDescription: String? {
        switch self {
        case .backgroundRefreshDisabled:
            return "Background app refresh is disabled"
        case .healthKitNotAuthorized:
            return "HealthKit access not authorized"
        case .syncInProgress:
            return "Background sync already in progress"
        }
    }
}