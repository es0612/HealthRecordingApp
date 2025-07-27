import Foundation

/// Protocol that defines the interface for health records
/// Both SwiftData HealthRecord and test mocks conform to this
protocol HealthRecordProtocol {
    var id: UUID { get }
    var type: HealthDataType { get }
    var value: Double { get }
    var unit: String { get }
    var timestamp: Date { get }
    var source: DataSource { get }
}