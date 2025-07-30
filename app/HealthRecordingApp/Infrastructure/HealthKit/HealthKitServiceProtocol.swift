import Foundation

/// Protocol for HealthKit service operations
/// Provides abstraction for health data access and management
protocol HealthKitServiceProtocol {
    
    /// Check if health data is available on this device
    var isHealthDataAvailable: Bool { get }
    
    /// Current authorization status for health data access
    var authorizationStatus: HealthKitAuthorizationStatus { get }
    
    /// Request authorization for specified health data types
    /// - Parameter dataTypes: Set of health data types to request access for
    /// - Returns: Boolean indicating if authorization was granted
    /// - Throws: HealthKitError if authorization request fails
    func requestAuthorization(for dataTypes: Set<HealthDataType>) async throws -> Bool
    
    /// Check authorization status for a specific data type
    /// - Parameter dataType: The health data type to check
    /// - Returns: Current authorization status for the data type
    func authorizationStatus(for dataType: HealthDataType) -> HealthKitAuthorizationStatus
    
    /// Check if a specific data type is authorized
    /// - Parameter dataType: The health data type to check
    /// - Returns: Boolean indicating if the data type is authorized
    func isAuthorized(for dataType: HealthDataType) -> Bool
    
    /// Get authorization status for multiple data types
    /// - Parameter dataTypes: Set of health data types to check
    /// - Returns: Dictionary mapping each data type to its authorization status
    func authorizationStatus(for dataTypes: Set<HealthDataType>) -> [HealthDataType: HealthKitAuthorizationStatus]
    
    /// Read health data for a specific type within a date range
    /// - Parameters:
    ///   - type: The type of health data to read
    ///   - startDate: Start date for the data range
    ///   - endDate: End date for the data range
    /// - Returns: Array of HealthKitData objects
    /// - Throws: HealthKitError if data reading fails
    func readHealthData(type: HealthDataType, startDate: Date, endDate: Date) async throws -> [HealthKitData]
    
    /// Write health data to HealthKit
    /// - Parameter records: Array of HealthRecord objects to write
    /// - Returns: Boolean indicating if write operation was successful
    /// - Throws: HealthKitError if data writing fails
    func writeHealthData(_ records: [HealthRecord]) async throws -> Bool
    
    /// Observe changes in health data for a specific type
    /// - Parameters:
    ///   - dataType: The type of health data to observe
    ///   - handler: Closure to handle data changes
    /// - Returns: HealthDataObserver for managing the observation
    /// - Throws: HealthKitError if observation setup fails
    func observeHealthDataChanges(for dataType: HealthDataType, handler: @escaping ([HealthRecord]) -> Void) async throws -> HealthDataObserver
    
    /// Stop observing health data changes
    /// - Parameter observer: The observer to stop
    func stopObserving(_ observer: HealthDataObserver)
}

/// Data structure representing health data from HealthKit
struct HealthKitData {
    let type: HealthDataType
    let value: Double
    let unit: String
    let startDate: Date
    let endDate: Date
    
    init(type: HealthDataType, value: Double, unit: String, startDate: Date, endDate: Date) {
        self.type = type
        self.value = value
        self.unit = unit
        self.startDate = startDate
        self.endDate = endDate
    }
}

/// Extension to make HealthKitService conform to the protocol
extension HealthKitService: HealthKitServiceProtocol {
    /// Default authorization request for common health data types
    func requestAuthorization() async throws {
        let commonTypes: Set<HealthDataType> = [.weight, .steps, .calories, .heartRate]
        _ = try await requestAuthorization(for: commonTypes)
    }
}