import Foundation

/// Use Case implementation for recording health data operations
/// Coordinates between HealthKitService, Repositories, and business logic
final class RecordHealthDataUseCase: RecordHealthDataUseCaseProtocol {
    
    private let healthRecordRepository: HealthRecordRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let badgeRepository: BadgeRepositoryProtocol
    let healthKitService: HealthKitServiceProtocol
    private let logger: AILoggerProtocol
    
    init(
        healthRecordRepository: HealthRecordRepositoryProtocol,
        userRepository: UserRepositoryProtocol,
        badgeRepository: BadgeRepositoryProtocol,
        healthKitService: HealthKitServiceProtocol,
        logger: AILoggerProtocol = AILogger()
    ) {
        self.healthRecordRepository = healthRecordRepository
        self.userRepository = userRepository
        self.badgeRepository = badgeRepository
        self.healthKitService = healthKitService
        self.logger = logger
    }
    
    func recordFromHealthKit(for user: User) async throws -> [HealthRecord] {
        let startTime = Date()
        
        do {
            logger.info("Starting HealthKit data sync", context: [
                "user_id": user.id.uuidString,
                "operation": "healthkit_sync"
            ])
            
            // Request authorization if needed
            let supportedTypes: Set<HealthDataType> = [.weight, .steps, .calories, .heartRate]
            _ = try await healthKitService.requestAuthorization(for: supportedTypes)
            
            // Read data from HealthKit for the last 7 days
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
            let supportedTypesArray: [HealthDataType] = [.weight, .steps, .calories, .heartRate]
            
            var healthKitData: [HealthKitData] = []
            for type in supportedTypesArray {
                do {
                    let typeData = try await healthKitService.readHealthData(
                        type: type,
                        startDate: startDate,
                        endDate: endDate
                    )
                    healthKitData.append(contentsOf: typeData)
                } catch {
                    // Continue with other types if one fails
                    logger.warning("Failed to read HealthKit data for type: \(type.rawValue)", context: [
                        "error": error.localizedDescription
                    ])
                    continue
                }
            }
            
            // Convert HealthKit data to HealthRecord objects
            var recordedData: [HealthRecord] = []
            
            for data in healthKitData {
                do {
                    let healthRecord = HealthRecord(
                        type: data.type,
                        value: data.value,
                        unit: data.unit,
                        source: .healthKit
                    )
                    healthRecord.timestamp = data.startDate
                    healthRecord.user = user
                    
                    // Validate the record
                    guard healthRecord.isValid else {
                        logger.warning("Invalid HealthKit data skipped", context: [
                            "type": data.type.rawValue,
                            "value": data.value,
                            "reason": "validation_failed"
                        ])
                        continue
                    }
                    
                    // Save to repository
                    try await healthRecordRepository.save(healthRecord)
                    recordedData.append(healthRecord)
                    
                } catch {
                    logger.error(error, context: [
                        "operation": "healthkit_record_conversion",
                        "data_type": data.type.rawValue
                    ])
                    continue
                }
            }
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("healthkit_sync", duration: duration, success: true)
            
            logger.info("HealthKit sync completed successfully", context: [
                "user_id": user.id.uuidString,
                "records_synced": recordedData.count,
                "duration_seconds": duration
            ])
            
            return recordedData
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("healthkit_sync", duration: duration, success: false)
            
            logger.error(error, context: [
                "user_id": user.id.uuidString,
                "operation": "healthkit_sync"
            ])
            
            throw UseCaseError.healthKitSyncFailed(error)
        }
    }
    
    func recordManualData(_ data: ManualHealthData, for user: User) async throws -> HealthRecord {
        let startTime = Date()
        
        do {
            logger.info("Recording manual health data", context: [
                "user_id": user.id.uuidString,
                "data_type": data.type.rawValue,
                "value": data.value,
                "operation": "manual_data_entry"
            ])
            
            // Validate manual data input
            try validateManualData(data)
            
            // Create HealthRecord from manual data
            let healthRecord = HealthRecord(
                type: data.type,
                value: data.value,
                unit: data.unit,
                source: data.source
            )
            healthRecord.timestamp = data.timestamp
            healthRecord.user = user
            
            // Additional validation
            guard healthRecord.isValid else {
                throw ValidationError.invalidInput(
                    "HealthRecord",
                    value: "\(data.value)",
                    reason: "Manual health data validation failed"
                )
            }
            
            // Save to repository
            try await healthRecordRepository.save(healthRecord)
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("manual_data_entry", duration: duration, success: true)
            
            logger.info("Manual health data recorded successfully", context: [
                "user_id": user.id.uuidString,
                "record_id": healthRecord.id.uuidString,
                "data_type": data.type.rawValue,
                "duration_seconds": duration
            ])
            
            return healthRecord
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("manual_data_entry", duration: duration, success: false)
            
            logger.error(error, context: [
                "user_id": user.id.uuidString,
                "data_type": data.type.rawValue,
                "operation": "manual_data_entry"
            ])
            
            if error is ValidationError {
                throw error
            } else {
                throw UseCaseError.manualDataRecordingFailed(error)
            }
        }
    }
    
    func syncAllData(for user: User) async throws -> HealthSyncResult {
        let startTime = Date()
        
        do {
            logger.info("Starting full data sync", context: [
                "user_id": user.id.uuidString,
                "operation": "full_sync"
            ])
            
            // Get existing records count for comparison
            let existingRecords = try await healthRecordRepository.fetchRecords(
                for: user,
                type: nil,
                from: nil,
                to: nil
            )
            let initialCount = existingRecords.count
            
            // Sync from HealthKit
            let healthKitRecords = try await recordFromHealthKit(for: user)
            
            // Get updated records count
            let updatedRecords = try await healthRecordRepository.fetchRecords(
                for: user,
                type: nil,
                from: nil,
                to: nil
            )
            let finalCount = updatedRecords.count
            
            // Process badge earning
            let earnedBadges = try await processBadgeEarning(for: user)
            
            let duration = Date().timeIntervalSince(startTime)
            
            let syncResult = HealthSyncResult(
                syncedRecordsCount: healthKitRecords.count,
                newRecordsCount: finalCount - initialCount,
                duplicateRecordsCount: 0, // Simplified for now
                errorsCount: 0,
                earnedBadges: earnedBadges,
                syncDuration: duration
            )
            
            logger.logPerformance("full_sync", duration: duration, success: true)
            
            logger.info("Full data sync completed successfully", context: [
                "user_id": user.id.uuidString,
                "synced_records": syncResult.syncedRecordsCount,
                "new_records": syncResult.newRecordsCount,
                "earned_badges": earnedBadges.count,
                "duration_seconds": duration
            ])
            
            return syncResult
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("full_sync", duration: duration, success: false)
            
            logger.error(error, context: [
                "user_id": user.id.uuidString,
                "operation": "full_sync"
            ])
            
            // Return error result
            let errorResult = HealthSyncResult(
                syncedRecordsCount: 0,
                newRecordsCount: 0,
                duplicateRecordsCount: 0,
                errorsCount: 1,
                earnedBadges: [],
                syncDuration: duration
            )
            
            return errorResult
        }
    }
    
    func processBadgeEarning(for user: User) async throws -> [Badge] {
        let startTime = Date()
        
        do {
            logger.info("Processing badge earning", context: [
                "user_id": user.id.uuidString,
                "operation": "badge_processing"
            ])
            
            // Get all available badges
            let allBadges = try await badgeRepository.fetchAllBadges()
            
            // Get user's current health records
            _ = try await healthRecordRepository.fetchRecords(
                for: user,
                type: nil,
                from: nil,
                to: nil
            )
            
            var earnedBadges: [Badge] = []
            
            // Check each badge requirement
            for badge in allBadges {
                // Skip if already earned
                if badge.isEarned && badge.user?.id == user.id {
                    continue
                }
                
                // Check if requirement is met
                if badge.requirement.isMet(for: user) {
                    try await badgeRepository.markAsEarned(badge, for: user)
                    earnedBadges.append(badge)
                    
                    logger.info("Badge earned", context: [
                        "user_id": user.id.uuidString,
                        "badge_id": badge.id.uuidString,
                        "badge_name": badge.name,
                        "badge_type": badge.type.rawValue
                    ])
                }
            }
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("badge_processing", duration: duration, success: true)
            
            logger.info("Badge processing completed", context: [
                "user_id": user.id.uuidString,
                "earned_badges_count": earnedBadges.count,
                "duration_seconds": duration
            ])
            
            return earnedBadges
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("badge_processing", duration: duration, success: false)
            
            logger.error(error, context: [
                "user_id": user.id.uuidString,
                "operation": "badge_processing"
            ])
            
            throw UseCaseError.badgeProcessingFailed(error)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func validateManualData(_ data: ManualHealthData) throws {
        // Validate value based on data type
        switch data.type {
        case .weight:
            guard data.value > 0 && data.value <= 500 else {
                throw ValidationError.invalidInput(
                    "ManualHealthData",
                    value: "\(data.value)",
                    reason: "Weight must be between 0 and 500 kg"
                )
            }
            
        case .steps:
            guard data.value >= 0 && data.value <= 100000 else {
                throw ValidationError.invalidInput(
                    "ManualHealthData",
                    value: "\(data.value)",
                    reason: "Steps must be between 0 and 100,000"
                )
            }
            
        case .calories:
            guard data.value >= 0 && data.value <= 10000 else {
                throw ValidationError.invalidInput(
                    "ManualHealthData",
                    value: "\(data.value)",
                    reason: "Calories must be between 0 and 10,000"
                )
            }
            
        case .heartRate:
            guard data.value > 0 && data.value <= 250 else {
                throw ValidationError.invalidInput(
                    "ManualHealthData",
                    value: "\(data.value)",
                    reason: "Heart rate must be between 0 and 250 bpm"
                )
            }
            
        case .bloodGlucose:
            guard data.value > 0 && data.value <= 500 else {
                throw ValidationError.invalidInput(
                    "ManualHealthData",
                    value: "\(data.value)",
                    reason: "Blood glucose must be between 0 and 500 mg/dL"
                )
            }
        }
        
        // Validate timestamp is not in the future
        guard data.timestamp <= Date() else {
            throw ValidationError.invalidInput(
                "ManualHealthData",
                value: data.timestamp.description,
                reason: "Timestamp cannot be in the future"
            )
        }
        
        // Validate unit matches data type
        let expectedUnit = data.type.displayName
        guard data.unit == expectedUnit || isValidAlternativeUnit(data.unit, for: data.type) else {
            throw ValidationError.invalidInput(
                "ManualHealthData",
                value: data.unit,
                reason: "Invalid unit '\(data.unit)' for data type '\(data.type.rawValue)'"
            )
        }
    }
    
    private func isValidAlternativeUnit(_ unit: String, for type: HealthDataType) -> Bool {
        switch type {
        case .weight:
            return ["kg", "lbs", "pounds"].contains(unit.lowercased())
        case .steps:
            return ["count", "steps"].contains(unit.lowercased())
        case .calories:
            return ["kcal", "cal", "calories"].contains(unit.lowercased())
        case .heartRate:
            return ["bpm", "beats/min"].contains(unit.lowercased())
        case .bloodGlucose:
            return ["mg/dl", "mg/l", "mmol/l"].contains(unit.lowercased())
        }
    }
}

/// Use Case specific error types
enum UseCaseError: Error, LocalizedError {
    case healthKitSyncFailed(Error)
    case manualDataRecordingFailed(Error)
    case badgeProcessingFailed(Error)
    case userNotFound
    case invalidOperation(String)
    
    var errorDescription: String? {
        switch self {
        case .healthKitSyncFailed(let error):
            return "HealthKit sync failed: \(error.localizedDescription)"
        case .manualDataRecordingFailed(let error):
            return "Manual data recording failed: \(error.localizedDescription)"
        case .badgeProcessingFailed(let error):
            return "Badge processing failed: \(error.localizedDescription)"
        case .userNotFound:
            return "User not found"
        case .invalidOperation(let message):
            return "Invalid operation: \(message)"
        }
    }
}