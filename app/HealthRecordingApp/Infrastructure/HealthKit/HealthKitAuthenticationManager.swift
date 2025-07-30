import Foundation
import HealthKit

/// Manager for handling HealthKit authentication flow
/// Provides high-level operations for permission requests and status checking
@MainActor
final class HealthKitAuthenticationManager: ObservableObject {
    
    // MARK: - Properties
    
    private let healthKitService: HealthKitServiceProtocol
    private let logger: AILoggerProtocol
    
    @Published var isAuthenticationInProgress = false
    @Published var lastAuthenticationError: Error?
    @Published var authenticationStatus: HealthKitAuthenticationStatus = .notDetermined
    
    // MARK: - Initialization
    
    init(healthKitService: HealthKitServiceProtocol, logger: AILoggerProtocol) {
        self.healthKitService = healthKitService
        self.logger = logger
        
        // Initialize status
        updateAuthenticationStatus()
    }
    
    // MARK: - Authentication Status
    
    /// Update the current authentication status
    func updateAuthenticationStatus() {
        let currentStatus = healthKitService.authorizationStatus
        
        switch currentStatus {
        case .notDetermined:
            authenticationStatus = .notDetermined
        case .sharingDenied:
            authenticationStatus = .denied
        case .sharingAuthorized:
            authenticationStatus = .authorized
        }
        
        logger.debug("HealthKit authentication status updated", context: [
            "status": authenticationStatus.rawValue
        ])
    }
    
    /// Check if HealthKit is available on this device
    var isHealthKitAvailable: Bool {
        return healthKitService.isHealthDataAvailable
    }
    
    /// Check if specific data types are authorized
    func isAuthorized(for dataTypes: Set<HealthDataType>) -> Bool {
        let statusMap = healthKitService.authorizationStatus(for: dataTypes)
        return statusMap.values.contains(.sharingAuthorized)
    }
    
    /// Get detailed authorization status for each data type
    func getDetailedAuthorizationStatus() -> [HealthDataType: HealthKitAuthorizationStatus] {
        let commonTypes: Set<HealthDataType> = [.weight, .steps, .calories, .heartRate]
        return healthKitService.authorizationStatus(for: commonTypes)
    }
    
    // MARK: - Authentication Flow
    
    /// Request HealthKit authorization for common health data types
    func requestAuthorization() async -> HealthKitAuthenticationResult {
        let commonTypes: Set<HealthDataType> = [.weight, .steps, .calories, .heartRate]
        return await requestAuthorization(for: commonTypes)
    }
    
    /// Request HealthKit authorization for specific data types
    func requestAuthorization(for dataTypes: Set<HealthDataType>) async -> HealthKitAuthenticationResult {
        isAuthenticationInProgress = true
        lastAuthenticationError = nil
        
        logger.info("Starting HealthKit authorization request", context: [
            "requested_data_types": dataTypes.map { $0.rawValue }
        ])
        
        defer {
            isAuthenticationInProgress = false
            updateAuthenticationStatus()
        }
        
        // Check if HealthKit is available
        guard isHealthKitAvailable else {
            let error = HealthKitError.dataAccessFailed(
                NSError(domain: "HealthKitAuthenticationManager", code: 1001, userInfo: [
                    NSLocalizedDescriptionKey: "HealthKit is not available on this device"
                ])
            )
            lastAuthenticationError = error
            
            logger.error(error, context: [
                "operation": "healthkit_availability_check"
            ])
            
            return .unavailable
        }
        
        do {
            let success = try await healthKitService.requestAuthorization(for: dataTypes)
            
            if success {
                // Check which specific types were authorized
                let statusMap = healthKitService.authorizationStatus(for: dataTypes)
                let authorizedTypes = statusMap.filter { $0.value == .sharingAuthorized }.keys
                let deniedTypes = statusMap.filter { $0.value == .sharingDenied }.keys
                
                logger.info("HealthKit authorization completed", context: [
                    "success": true,
                    "authorized_types": Array(authorizedTypes).map { $0.rawValue },
                    "denied_types": Array(deniedTypes).map { $0.rawValue }
                ])
                
                if !authorizedTypes.isEmpty {
                    return .authorized(authorizedTypes: Set(authorizedTypes))
                } else {
                    return .denied
                }
            } else {
                logger.info("HealthKit authorization denied by user", context: nil)
                return .denied
            }
            
        } catch {
            lastAuthenticationError = error
            
            logger.error(error, context: [
                "operation": "healthkit_authorization_request"
            ])
            
            if let healthKitError = error as? HealthKitError {
                switch healthKitError {
                case .authorizationDenied:
                    return .denied
                case .dataAccessFailed, .unsupportedDataType:
                    return .error(healthKitError)
                }
            }
            
            return .error(error)
        }
    }
    
    /// Re-check authorization status (useful after returning from Settings)
    func recheckAuthorizationStatus() {
        updateAuthenticationStatus()
        
        logger.info("HealthKit authorization status rechecked", context: [
            "current_status": authenticationStatus.rawValue
        ])
    }
    
    /// Open HealthKit settings in the Settings app
    func openHealthKitSettings() {
        // TODO: Implement settings URL opening for production app
        logger.info("HealthKit settings opening requested", context: nil)
    }
}

// MARK: - Supporting Types

enum HealthKitAuthenticationStatus: String, CaseIterable {
    case notDetermined = "not_determined"
    case authorized = "authorized"
    case denied = "denied"
    
    var displayName: String {
        switch self {
        case .notDetermined:
            return "未確認"
        case .authorized:
            return "許可済み"
        case .denied:
            return "拒否"
        }
    }
    
    var description: String {
        switch self {
        case .notDetermined:
            return "HealthKitアクセスの許可がまだ確認されていません"
        case .authorized:
            return "HealthKitアクセスが許可されています"
        case .denied:
            return "HealthKitアクセスが拒否されています"
        }
    }
}

enum HealthKitAuthenticationResult {
    case authorized(authorizedTypes: Set<HealthDataType>)
    case denied
    case unavailable
    case error(Error)
    
    var isSuccess: Bool {
        switch self {
        case .authorized:
            return true
        case .denied, .unavailable, .error:
            return false
        }
    }
    
    var errorMessage: String? {
        switch self {
        case .authorized:
            return nil
        case .denied:
            return "HealthKitアクセスが拒否されました"
        case .unavailable:
            return "このデバイスではHealthKitが利用できません"
        case .error(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Preview Support

#if DEBUG
extension HealthKitAuthenticationManager {
    static func preview() -> HealthKitAuthenticationManager {
        let mockService = MockHealthKitService()
        let mockLogger = MockAILogger()
        return HealthKitAuthenticationManager(healthKitService: mockService, logger: mockLogger)
    }
}

private class MockHealthKitService: HealthKitServiceProtocol {
    var isHealthDataAvailable: Bool = true
    var authorizationStatus: HealthKitAuthorizationStatus = .notDetermined
    
    func requestAuthorization(for dataTypes: Set<HealthDataType>) async throws -> Bool {
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay for testing
        return true
    }
    
    func authorizationStatus(for dataType: HealthDataType) -> HealthKitAuthorizationStatus {
        return .sharingAuthorized
    }
    
    func isAuthorized(for dataType: HealthDataType) -> Bool {
        return true
    }
    
    func authorizationStatus(for dataTypes: Set<HealthDataType>) -> [HealthDataType: HealthKitAuthorizationStatus] {
        return dataTypes.reduce(into: [:]) { result, type in
            result[type] = .sharingAuthorized
        }
    }
    
    func readHealthData(type: HealthDataType, startDate: Date, endDate: Date) async throws -> [HealthKitData] {
        return []
    }
    
    func writeHealthData(_ records: [HealthRecord]) async throws -> Bool {
        return true
    }
    
    func observeHealthDataChanges(for dataType: HealthDataType, handler: @escaping ([HealthRecord]) -> Void) async throws -> HealthDataObserver {
        return HealthDataObserver(dataType: dataType, handler: handler)
    }
    
    func stopObserving(_ observer: HealthDataObserver) {}
}

private class MockAILogger: AILoggerProtocol {
    var logLevel: AILogLevel = .debug
    var isEnabled: Bool = true
    var shouldRedactPII: Bool = true
    
    func debug(_ message: String, context: [String: Any]?) {}
    func info(_ message: String, context: [String: Any]?) {}
    func warning(_ message: String, context: [String: Any]?) {}
    func error(_ error: Error, context: [String: Any]?) {}
    func logUserAction(_ action: String, parameters: [String: Any]?) {}
    func logPerformance(_ operation: String, duration: TimeInterval, success: Bool) {}
}
#endif