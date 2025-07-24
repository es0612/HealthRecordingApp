import Foundation

/// Use Case protocol for recording health data operations
/// Handles both automatic HealthKit sync and manual data entry
protocol RecordHealthDataUseCaseProtocol {
    
    /// Record health data automatically from HealthKit for a user
    /// - Parameter user: The User to sync data for
    /// - Returns: Array of newly recorded HealthRecord objects
    /// - Throws: HealthAppError if sync operation fails
    func recordFromHealthKit(for user: User) async throws -> [HealthRecord]
    
    /// Record manual health data entry for a user
    /// - Parameters:
    ///   - data: Manual health data input
    ///   - user: The User to record data for
    /// - Returns: The newly created HealthRecord
    /// - Throws: HealthAppError if recording fails
    func recordManualData(_ data: ManualHealthData, for user: User) async throws -> HealthRecord
    
    /// Sync all available health data for a user
    /// - Parameter user: The User to perform full sync for
    /// - Returns: Result summary of the sync operation
    /// - Throws: HealthAppError if sync operation fails
    func syncAllData(for user: User) async throws -> HealthSyncResult
    
    /// Check and process badge earning conditions after data recording
    /// - Parameter user: The User to check badge conditions for
    /// - Returns: Array of newly earned Badge objects
    /// - Throws: HealthAppError if badge processing fails
    func processBadgeEarning(for user: User) async throws -> [Badge]
}

/// Data structure for manual health data input
struct ManualHealthData {
    let type: HealthDataType
    let value: Double
    let unit: String
    let timestamp: Date
    let source: DataSource
    
    init(type: HealthDataType, value: Double, unit: String, timestamp: Date = Date(), source: DataSource = .manual) {
        self.type = type
        self.value = value
        self.unit = unit
        self.timestamp = timestamp
        self.source = source
    }
}

/// Result structure for health data sync operations
struct HealthSyncResult {
    let syncedRecordsCount: Int
    let newRecordsCount: Int
    let duplicateRecordsCount: Int
    let errorsCount: Int
    let earnedBadges: [Badge]
    let syncDuration: TimeInterval
    
    init(syncedRecordsCount: Int, newRecordsCount: Int, duplicateRecordsCount: Int, errorsCount: Int, earnedBadges: [Badge], syncDuration: TimeInterval) {
        self.syncedRecordsCount = syncedRecordsCount
        self.newRecordsCount = newRecordsCount
        self.duplicateRecordsCount = duplicateRecordsCount
        self.errorsCount = errorsCount
        self.earnedBadges = earnedBadges
        self.syncDuration = syncDuration
    }
    
    /// Whether the sync operation was successful
    var isSuccessful: Bool {
        return errorsCount == 0
    }
    
    /// Whether any new data was recorded
    var hasNewData: Bool {
        return newRecordsCount > 0
    }
}