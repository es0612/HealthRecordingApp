import Testing
import Foundation
@testable import HealthRecordingApp

@Suite("HealthRecord Tests")
struct HealthRecordTests {
    
    @Test("HealthRecord should be created with valid data")
    func testHealthRecordCreation() async throws {
        // Given
        let type = HealthDataType.weight
        let value = 70.0
        let unit = "kg"
        
        // When
        let healthRecord = HealthRecord(type: type, value: value, unit: unit)
        
        // Then
        #expect(healthRecord.type == .weight)
        #expect(healthRecord.value == 70.0)
        #expect(healthRecord.unit == "kg")
        #expect(!healthRecord.id.uuidString.isEmpty)
        #expect(healthRecord.timestamp.timeIntervalSinceNow < 1.0) // 現在時刻に近い
        #expect(healthRecord.source == .healthKit)  // デフォルト値
    }
    
    @Test("HealthRecord should be created with manual data source")
    func testHealthRecordCreationWithManualSource() async throws {
        // Given
        let type = HealthDataType.steps
        let value = 10000.0
        let unit = "count"
        let source = DataSource.manual
        
        // When
        let healthRecord = HealthRecord(type: type, value: value, unit: unit, source: source)
        
        // Then
        #expect(healthRecord.type == .steps)
        #expect(healthRecord.value == 10000.0)
        #expect(healthRecord.unit == "count")
        #expect(healthRecord.source == .manual)
    }
    
    @Test("HealthRecord should have unique ID for each instance")
    func testHealthRecordUniqueID() async throws {
        // Given & When
        let record1 = HealthRecord(type: .weight, value: 70.0, unit: "kg")
        let record2 = HealthRecord(type: .weight, value: 70.0, unit: "kg")
        
        // Then
        #expect(record1.id != record2.id)
    }
    
    @Test("HealthRecord timestamp should be recent")
    func testHealthRecordTimestamp() async throws {
        // Given
        let beforeCreation = Date()
        
        // When
        let healthRecord = HealthRecord(type: .calories, value: 2000.0, unit: "kcal")
        
        // Then
        let afterCreation = Date()
        #expect(healthRecord.timestamp >= beforeCreation)
        #expect(healthRecord.timestamp <= afterCreation)
    }
    
    @Test("HealthRecord should validate data ranges correctly")
    func testHealthRecordValidation() async throws {
        // Given & When & Then
        let validWeight = HealthRecord(type: .weight, value: 70.0, unit: "kg")
        #expect(validWeight.isValid == true)
        
        let validSteps = HealthRecord(type: .steps, value: 10000.0, unit: "count")
        #expect(validSteps.isValid == true)
        
        let validCalories = HealthRecord(type: .calories, value: 2000.0, unit: "kcal")
        #expect(validCalories.isValid == true)
        
        let validHeartRate = HealthRecord(type: .heartRate, value: 80.0, unit: "bpm")
        #expect(validHeartRate.isValid == true)
    }
}