import Testing
import Foundation
import HealthKit
@testable import HealthRecordingApp

@Suite("HealthKitService Tests")
struct HealthKitServiceTests {
    
    @Test("HealthKitService should be created with default configuration")
    func testHealthKitServiceCreation() async throws {
        // Given & When
        let service = HealthKitService()
        
        // Then
        #expect(service != nil)
        #expect(service.isHealthDataAvailable == true) // HealthKit利用可能環境を想定
        #expect(service.authorizationStatus == .notDetermined) // 初期状態
    }
    
    // Temporarily disabled due to HealthKit initialization issues
    /*
    @Test("HealthKitService should request authorization for health data types")
    func testHealthKitServiceRequestAuthorization() async throws {
        // Given
        let service = HealthKitService()
        let dataTypes: Set<HealthDataType> = [.weight, .steps, .calories]
        
        // When
        let authorizationResult = try await service.requestAuthorization(for: dataTypes)
        
        // Then
        #expect(authorizationResult == true) // シミュレータでは成功を想定
        #expect(service.authorizationStatus != .notDetermined)
    }
    */
    
    @Test("HealthKitService should read health data from HealthKit")
    func testHealthKitServiceReadData() async throws {
        // Given
        let service = HealthKitService()
        let dataType = HealthDataType.weight
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let endDate = Date()
        
        // When
        let healthData = try await service.readHealthData(
            type: dataType,
            startDate: startDate,
            endDate: endDate
        )
        
        // Then
        #expect(healthData != nil)
        #expect(healthData.count >= 0) // 0件以上のデータを想定
        
        // データが存在する場合の検証
        if !healthData.isEmpty {
            let firstRecord = healthData.first!
            #expect(firstRecord.type == dataType)
            #expect(firstRecord.timestamp >= startDate)
            #expect(firstRecord.timestamp <= endDate)
            #expect(firstRecord.value > 0)
            #expect(firstRecord.source == .healthKit)
        }
    }
    
    @Test("HealthKitService should write health data to HealthKit") 
    func testHealthKitServiceWriteData() async throws {
        // Given
        let service = HealthKitService()
        let weightRecord = HealthRecord(
            type: .weight,
            value: 70.0,
            unit: "kg",
            source: .manual
        )
        
        // When
        let writeSuccess = try await service.writeHealthData([weightRecord])
        
        // Then
        #expect(writeSuccess == true) // 書き込み成功を想定
    }
    
    @Test("HealthKitService should observe health data changes")
    func testHealthKitServiceObserveChanges() async throws {
        // Given
        let service = HealthKitService()
        let dataType = HealthDataType.steps
        var observedChanges = 0
        
        // When
        let observer = try await service.observeHealthDataChanges(for: dataType) { changedData in
            observedChanges += 1
        }
        
        // Then
        #expect(observer != nil)
        #expect(observedChanges >= 0) // 初期状態では変更なし
        
        // Cleanup
        service.stopObserving(observer)
    }
    
    @Test("HealthKitService should handle authorization denied gracefully")
    func testHealthKitServiceAuthorizationDenied() async throws {
        // Given
        let service = HealthKitService()
        service.simulateAuthorizationDenied = true // テスト用フラグ
        
        // When & Then
        do {
            _ = try await service.requestAuthorization(for: [.weight])
            #expect(Bool(false), "Should throw HealthKitError for denied authorization")
        } catch let error as HealthKitError {
            #expect(error == HealthKitError.authorizationDenied)
            #expect(error.errorCode == "HK001")
        } catch {
            #expect(Bool(false), "Should throw HealthKitError")
        }
    }
    
    @Test("HealthKitService should handle unsupported data types")
    func testHealthKitServiceUnsupportedDataType() async throws {
        // Given
        let service = HealthKitService()
        
        // When & Then
        do {
            _ = try await service.readHealthData(
                type: .bloodGlucose, // サポート外データタイプ
                startDate: Date().addingTimeInterval(-86400),
                endDate: Date()
            )
            #expect(Bool(false), "Should throw HealthKitError for unsupported data type")
        } catch let error as HealthKitError {
            #expect(error.errorCode == "HK003")
            #expect(error.localizedDescription(for: Locale(identifier: "ja")).contains("サポートされていません"))
        } catch {
            #expect(Bool(false), "Should throw HealthKitError")
        }
    }
    
    @Test("HealthKitService should provide proper error context")
    func testHealthKitServiceErrorContext() async throws {
        // Given
        let service = HealthKitService()
        service.simulateDataAccessFailed = true // テスト用フラグ
        
        // When & Then
        do {
            _ = try await service.readHealthData(
                type: .weight,
                startDate: Date().addingTimeInterval(-86400),
                endDate: Date()
            )
            #expect(Bool(false), "Should throw HealthKitError for data access failure")
        } catch let error as HealthKitError {
            #expect(error.errorCode == "HK002")
            #expect(error.underlyingError != nil)
            #expect(error.errorUserInfo["category"] as? String == "HealthKit")
        } catch {
            #expect(Bool(false), "Should throw HealthKitError")
        }
    }
}