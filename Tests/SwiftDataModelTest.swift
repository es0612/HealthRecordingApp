import Testing
import Foundation
@testable import HealthRecordingApp

@Suite("SwiftData Model Tests")
struct SwiftDataModelTest {
    
    @Test("HealthRecord should initialize with valid data")
    func testHealthRecordInitialization() async throws {
        // Given
        let type = HealthDataType.weight
        let value = 70.0
        let unit = "kg"
        let source = DataSource.manual
        
        // When
        let healthRecord = HealthRecord(type: type, value: value, unit: unit, source: source)
        
        // Then
        #expect(healthRecord.type == type)
        #expect(healthRecord.value == value)
        #expect(healthRecord.unit == unit)
        #expect(healthRecord.source == source)
        #expect(healthRecord.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        #expect(healthRecord.isValid == true)
    }
    
    @Test("HealthRecord should handle negative values")
    func testHealthRecordNegativeValue() async throws {
        // Given
        let type = HealthDataType.weight
        let negativeValue = -10.0
        let unit = "kg"
        
        // When
        let healthRecord = HealthRecord(type: type, value: negativeValue, unit: unit)
        
        // Then - Should correct negative value to 0
        #expect(healthRecord.value == 0.0)
        #expect(healthRecord.isValid == false) // 0 weight is invalid
    }
    
    @Test("HealthRecord should handle empty unit")
    func testHealthRecordEmptyUnit() async throws {
        // Given
        let type = HealthDataType.weight
        let value = 70.0
        let emptyUnit = ""
        
        // When
        let healthRecord = HealthRecord(type: type, value: value, unit: emptyUnit)
        
        // Then - Should use default unit
        #expect(healthRecord.unit == type.unit)
        #expect(healthRecord.isValid == true)
    }
    
    @Test("HealthDataType should provide correct display names")
    func testHealthDataTypeDisplayNames() async throws {
        #expect(HealthDataType.weight.displayName == "体重")
        #expect(HealthDataType.steps.displayName == "歩数")
        #expect(HealthDataType.calories.displayName == "カロリー")
        #expect(HealthDataType.heartRate.displayName == "心拍数")
    }
    
    @Test("HealthDataType should provide correct units")
    func testHealthDataTypeUnits() async throws {
        #expect(HealthDataType.weight.unit == "kg")
        #expect(HealthDataType.steps.unit == "歩")
        #expect(HealthDataType.calories.unit == "kcal")
        #expect(HealthDataType.heartRate.unit == "bpm")
    }
    
    @Test("DataSource should have correct raw values")
    func testDataSourceRawValues() async throws {
        #expect(DataSource.healthKit.rawValue == "healthKit")
        #expect(DataSource.manual.rawValue == "manual")
    }
}