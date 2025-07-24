import Foundation

/// Repository protocol for HealthRecord data access operations
/// Provides abstraction layer between Use Cases and Infrastructure
protocol HealthRecordRepositoryProtocol {
    
    /// Save a health record to persistent storage
    /// - Parameter record: The HealthRecord to save
    /// - Throws: HealthAppError if save operation fails
    func save(_ record: HealthRecord) async throws
    
    /// Fetch health records with optional filtering
    /// - Parameters:
    ///   - user: The user whose records to fetch
    ///   - type: Optional health data type filter
    ///   - startDate: Optional start date for time range filtering
    ///   - endDate: Optional end date for time range filtering
    /// - Returns: Array of matching HealthRecord objects
    /// - Throws: HealthAppError if fetch operation fails
    func fetchRecords(
        for user: User,
        type: HealthDataType?,
        from startDate: Date?,
        to endDate: Date?
    ) async throws -> [HealthRecord]
    
    /// Delete a health record from persistent storage
    /// - Parameter record: The HealthRecord to delete
    /// - Throws: HealthAppError if delete operation fails
    func delete(_ record: HealthRecord) async throws
    
    /// Synchronize data with HealthKit
    /// Triggers CloudKit sync and updates local data
    /// - Throws: HealthAppError if sync operation fails
    func syncWithHealthKit() async throws
}