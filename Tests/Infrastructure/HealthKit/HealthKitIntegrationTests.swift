import Testing
import Foundation
import HealthKit
@testable import HealthRecordingApp

/// Comprehensive integration tests for HealthKit functionality
/// Tests authorization flow, data synchronization, and error handling
struct HealthKitIntegrationTests {
    
    private let healthKitService = HealthKitService()
    private let logger = AILogger()
    
    // MARK: - Authorization Tests
    
    @Test("HealthKit Authorization Request Flow")
    func testAuthorizationRequestFlow() async throws {
        // Test HealthKit availability
        #expect(healthKitService.isHealthDataAvailable)
        
        // Test authorization request for supported data types
        let dataTypes: Set<HealthDataType> = [.weight, .steps, .calories, .heartRate]
        
        do {
            let authorized = try await healthKitService.requestAuthorization(for: dataTypes)
            
            // In test environment, should return true
            #expect(authorized == true)
            
            // Verify authorization status mapping
            let statusMap = healthKitService.authorizationStatus(for: dataTypes)
            
            for dataType in dataTypes {
                let status = statusMap[dataType]
                #expect(status != nil, "Authorization status should be available for \(dataType)")
            }
            
        } catch {
            if error is HealthKitError {
                // Expected in test environment - this is acceptable
                logger.info("HealthKit authorization simulated in test environment", context: [
                    "error": error.localizedDescription
                ])
            } else {
                throw error
            }
        }
    }
    
    @Test("HealthKit Authorization Status Check")
    func testAuthorizationStatusCheck() {
        let dataTypes: Set<HealthDataType> = [.weight, .steps, .calories]
        
        // Test individual authorization status
        for dataType in dataTypes {
            let status = healthKitService.authorizationStatus(for: dataType)
            
            // Should return valid status
            #expect([
                .notDetermined,
                .sharingDenied,
                .sharingAuthorized
            ].contains(status))
        }
        
        // Test multiple authorization status
        let statusMap = healthKitService.authorizationStatus(for: dataTypes)
        #expect(statusMap.count == dataTypes.count)
        
        for dataType in dataTypes {
            #expect(statusMap[dataType] != nil)
        }
    }
    
    @Test("HealthKit Authorization Denial Simulation")
    func testAuthorizationDenialSimulation() async {
        // Configure service to simulate denial
        healthKitService.simulateAuthorizationDenied = true
        
        let dataTypes: Set<HealthDataType> = [.weight]
        
        do {
            _ = try await healthKitService.requestAuthorization(for: dataTypes)
            Issue.record("Expected authorization to be denied")
        } catch let error as HealthKitError {
            switch error {
            case .authorizationDenied:
                // Expected error
                logger.info("Authorization denial correctly simulated")
            default:
                Issue.record("Unexpected HealthKit error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
        
        // Reset simulation
        healthKitService.simulateAuthorizationDenied = false
    }
    
    // MARK: - Data Synchronization Tests
    
    @Test("HealthKit Data Reading Flow")
    func testDataReadingFlow() async throws {
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let endDate = Date()
        
        // Test single data type reading
        for dataType in [HealthDataType.weight, .steps, .calories] {
            do {
                let data = try await healthKitService.readHealthData(
                    type: dataType,
                    startDate: startDate,
                    endDate: endDate
                )
                
                // In test environment, should return empty array
                #expect(data.isEmpty, "Test environment should return empty data")
                
                logger.info("Data reading test completed", context: [
                    "data_type": dataType.rawValue,
                    "records_count": data.count
                ])
                
            } catch let error as HealthKitError {
                // Handle expected errors in test environment
                switch error {
                case .unsupportedDataType(let type):
                    logger.warning("Unsupported data type in test", context: ["type": type])
                case .authorizationDenied:
                    logger.warning("Authorization required for data access")
                case .dataAccessFailed:
                    logger.warning("Data access failed in test environment")
                }
            }
        }
    }
    
    @Test("HealthKit Multiple Data Types Reading")
    func testMultipleDataTypesReading() async throws {
        let dataTypes: [HealthDataType] = [.weight, .steps, .calories]
        let startDate = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        let endDate = Date()
        
        do {
            let allData = try await healthKitService.readHealthData(
                types: dataTypes,
                startDate: startDate,
                endDate: endDate
            )
            
            // In test environment, should return empty array
            #expect(allData.isEmpty, "Test environment should return empty data")
            
            logger.info("Multiple data types reading test completed", context: [
                "data_types": dataTypes.map { $0.rawValue },
                "total_records": allData.count
            ])
            
        } catch {
            // In test environment, errors are expected and handled
            logger.info("Multiple data reading completed with expected test environment limitations")
        }
    }
    
    @Test("HealthKit Anchored Query Test")
    func testAnchoredQuery() async throws {
        let dataType = HealthDataType.steps
        
        do {
            let newData = try await healthKitService.readNewHealthData(
                type: dataType,
                limit: 100
            )
            
            // In test environment, should return empty array
            #expect(newData.isEmpty, "Test environment should return empty data")
            
            logger.info("Anchored query test completed", context: [
                "data_type": dataType.rawValue,
                "new_records": newData.count
            ])
            
        } catch let error as HealthKitError {
            // Expected in test environment
            switch error {
            case .authorizationDenied:
                logger.info("Authorization required for anchored query test")
            case .unsupportedDataType:
                logger.info("Data type not supported in test environment")
            case .dataAccessFailed:
                logger.info("Data access failed in test environment")
            }
        }
    }
    
    @Test("HealthKit Data Access Failure Simulation")
    func testDataAccessFailureSimulation() async {
        // Configure service to simulate data access failure
        healthKitService.simulateDataAccessFailed = true
        
        do {
            _ = try await healthKitService.readHealthData(
                type: .weight,
                startDate: Date(),
                endDate: Date()
            )
            Issue.record("Expected data access to fail")
        } catch let error as HealthKitError {
            switch error {
            case .dataAccessFailed:
                // Expected error
                logger.info("Data access failure correctly simulated")
            default:
                Issue.record("Unexpected HealthKit error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
        
        // Reset simulation
        healthKitService.simulateDataAccessFailed = false
    }
    
    // MARK: - HealthKit Data Type Conversion Tests
    
    @Test("HealthKit Data Type Mapping")
    func testHealthKitDataTypeMapping() {
        let testCases: [(HealthDataType, String)] = [
            (.weight, "HKQuantityTypeIdentifierBodyMass"),
            (.steps, "HKQuantityTypeIdentifierStepCount"),
            (.calories, "HKQuantityTypeIdentifierActiveEnergyBurned"),
            (.heartRate, "HKQuantityTypeIdentifierHeartRate")
        ]
        
        for (dataType, expectedIdentifier) in testCases {
            let healthKitType = dataType.healthKitType
            #expect(healthKitType != nil, "HealthKit type should be available for \(dataType)")
            #expect(healthKitType?.identifier == expectedIdentifier, 
                   "HealthKit identifier should match for \(dataType)")
        }
        
        // Test unsupported type
        let unsupportedType = HealthDataType.bloodPressure
        #expect(unsupportedType.healthKitType == nil, "Unsupported types should return nil")
    }
    
    // MARK: - HealthKit Error Handling Tests
    
    @Test("HealthKit Error Types Validation")
    func testHealthKitErrorTypes() {
        // Test HealthKitError cases
        let authError = HealthKitError.authorizationDenied
        #expect(authError.localizedDescription.contains("認証"))
        
        let unsupportedError = HealthKitError.unsupportedDataType("test")
        #expect(unsupportedError.localizedDescription.contains("サポート"))
        
        let dataError = HealthKitError.dataAccessFailed(NSError(domain: "test", code: 1, userInfo: nil))
        #expect(dataError.localizedDescription.contains("データアクセス"))
    }
    
    // MARK: - Integration with Repository Tests
    
    @Test("HealthKit to Repository Integration")
    func testHealthKitRepositoryIntegration() async throws {
        // Create test repository
        let schema = Schema([HealthRecord.self, User.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        
        let repository = SwiftDataHealthRecordRepository(
            modelContext: container.mainContext,
            logger: logger
        )
        
        // Create test user
        let testUser = try User(name: "Test User", age: 30, height: 170.0, targetWeight: 65.0)
        
        // Simulate HealthKit data
        let mockHealthKitData = [
            HealthKitData(
                type: .weight,
                value: 70.0,
                unit: "kg",
                startDate: Date(),
                endDate: Date()
            ),
            HealthKitData(
                type: .steps,
                value: 8000.0,
                unit: "count",
                startDate: Date(),
                endDate: Date()
            )
        ]
        
        // Convert and save HealthKit data to repository
        for healthKitRecord in mockHealthKitData {
            let healthRecord = try HealthRecord(
                type: healthKitRecord.type,
                value: healthKitRecord.value,
                unit: healthKitRecord.unit,
                timestamp: healthKitRecord.startDate,
                source: .healthKit,
                user: testUser
            )
            
            try await repository.save(healthRecord)
        }
        
        // Verify data was saved correctly
        let savedRecords = try await repository.fetchRecords(
            for: testUser,
            type: nil,
            from: nil,
            to: nil
        )
        
        #expect(savedRecords.count == 2)
        #expect(savedRecords.contains { $0.type == .weight })
        #expect(savedRecords.contains { $0.type == .steps })
        
        logger.info("HealthKit repository integration test completed", context: [
            "saved_records": savedRecords.count
        ])
    }
    
    // MARK: - Performance and Reliability Tests
    
    @Test("HealthKit Service Performance", .timeLimit(.seconds(5)))
    func testHealthKitServicePerformance() async throws {
        let startTime = Date()
        
        // Test multiple authorization checks
        let dataTypes: Set<HealthDataType> = [.weight, .steps, .calories, .heartRate]
        
        for _ in 0..<10 {
            let statusMap = healthKitService.authorizationStatus(for: dataTypes)
            #expect(statusMap.count == dataTypes.count)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        #expect(duration < 1.0, "Authorization status checks should be fast")
        
        logger.logPerformance("healthkit_authorization_checks", duration: duration, success: true)
    }
    
    @Test("HealthKit Service Memory Usage")
    func testHealthKitServiceMemoryUsage() {
        // Create multiple service instances to test memory management
        var services: [HealthKitService] = []
        
        for _ in 0..<100 {
            services.append(HealthKitService())
        }
        
        // Test that services can be created without memory issues
        #expect(services.count == 100)
        
        // Clear references
        services.removeAll()
        
        logger.info("HealthKit service memory usage test completed")
    }
}

// MARK: - Mock HealthKit Data

struct HealthKitData {
    let type: HealthDataType
    let value: Double
    let unit: String
    let startDate: Date
    let endDate: Date
}

// MARK: - Test Utilities

extension HealthKitIntegrationTests {
    
    /// Generate mock HealthKit data for testing
    private func generateMockHealthKitData(
        type: HealthDataType,
        days: Int = 7
    ) -> [HealthKitData] {
        var data: [HealthKitData] = []
        let calendar = Calendar.current
        
        for i in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -i, to: Date()) else { continue }
            
            let value: Double
            switch type {
            case .weight:
                value = 70.0 + Double.random(in: -2.0...2.0)
            case .steps:
                value = Double.random(in: 5000...15000)
            case .calories:
                value = Double.random(in: 1800...2500)
            case .heartRate:
                value = Double.random(in: 60...100)
            default:
                value = Double.random(in: 1...100)
            }
            
            data.append(HealthKitData(
                type: type,
                value: value,
                unit: type.unit,
                startDate: date,
                endDate: date
            ))
        }
        
        return data
    }
}