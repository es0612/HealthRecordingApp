import Foundation
@testable import HealthRecordingApp

/// Test double for HealthRecord without SwiftData dependencies
struct MockHealthRecord: HealthRecordProtocol {
    let id: UUID
    let type: HealthDataType
    let value: Double
    let unit: String
    var timestamp: Date
    let source: DataSource
    
    init(type: HealthDataType, value: Double, unit: String, source: DataSource = .healthKit) {
        self.id = UUID()
        self.type = type
        self.value = value
        self.unit = unit
        self.timestamp = Date()
        self.source = source
    }
    
    /// Convert to actual HealthRecord interface for testing
    func toHealthRecord() -> TestHealthRecordInterface {
        return TestHealthRecordInterface(
            id: self.id,
            type: self.type,
            value: self.value,
            unit: self.unit,
            timestamp: self.timestamp,
            source: self.source
        )
    }
}

/// Interface that matches HealthRecord properties for testing
struct TestHealthRecordInterface: HealthRecordProtocol {
    let id: UUID
    let type: HealthDataType
    let value: Double
    let unit: String
    let timestamp: Date
    let source: DataSource
}

/// Helper to create test health records
struct TestHealthDataFactory {
    
    static func createTestHealthRecords() -> [TestHealthRecordInterface] {
        let records = [
            MockHealthRecord(type: .weight, value: 70.0, unit: "kg", source: .healthKit),
            MockHealthRecord(type: .weight, value: 69.5, unit: "kg", source: .manual),
            MockHealthRecord(type: .weight, value: 69.0, unit: "kg", source: .healthKit),
            MockHealthRecord(type: .weight, value: 68.8, unit: "kg", source: .manual),
            MockHealthRecord(type: .weight, value: 68.5, unit: "kg", source: .healthKit),
            MockHealthRecord(type: .weight, value: 68.2, unit: "kg", source: .manual),
            MockHealthRecord(type: .weight, value: 68.0, unit: "kg", source: .healthKit),
            MockHealthRecord(type: .weight, value: 67.8, unit: "kg", source: .manual),
            MockHealthRecord(type: .weight, value: 67.5, unit: "kg", source: .healthKit),
            MockHealthRecord(type: .weight, value: 67.2, unit: "kg", source: .manual)
        ]
        
        let baseDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        return records.enumerated().map { index, record in
            var mutableRecord = record
            mutableRecord.timestamp = Calendar.current.date(byAdding: .day, value: index, to: baseDate)!
            return mutableRecord.toHealthRecord()
        }
    }
    
    static func createTestRecordsWithAnomalies() -> [TestHealthRecordInterface] {
        let records = [
            MockHealthRecord(type: .weight, value: 70.0, unit: "kg", source: .healthKit),
            MockHealthRecord(type: .weight, value: 69.8, unit: "kg", source: .manual),
            MockHealthRecord(type: .weight, value: 69.5, unit: "kg", source: .healthKit),
            MockHealthRecord(type: .weight, value: 75.0, unit: "kg", source: .manual), // Anomaly
            MockHealthRecord(type: .weight, value: 69.2, unit: "kg", source: .healthKit),
            MockHealthRecord(type: .weight, value: 69.0, unit: "kg", source: .manual),
            MockHealthRecord(type: .weight, value: 65.0, unit: "kg", source: .healthKit), // Anomaly
            MockHealthRecord(type: .weight, value: 68.5, unit: "kg", source: .manual),
            MockHealthRecord(type: .weight, value: 68.3, unit: "kg", source: .healthKit),
            MockHealthRecord(type: .weight, value: 68.0, unit: "kg", source: .manual)
        ]
        
        let baseDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        return records.enumerated().map { index, record in
            var mutableRecord = record
            mutableRecord.timestamp = Calendar.current.date(byAdding: .day, value: index, to: baseDate)!
            return mutableRecord.toHealthRecord()
        }
    }
}