import SwiftData
import Foundation

@Model
final class HealthRecord {
    var id: UUID
    var type: HealthDataType
    var value: Double
    var unit: String
    var timestamp: Date
    var source: DataSource
    
    // Relationships
    var user: User?
    
    init(type: HealthDataType, value: Double, unit: String, source: DataSource = .healthKit) {
        guard value >= 0 else {
            fatalError("Health record value cannot be negative")
        }
        guard !unit.isEmpty else {
            fatalError("Health record unit cannot be empty")
        }
        
        self.id = UUID()
        self.type = type
        self.value = value
        self.unit = unit
        self.timestamp = Date()
        self.source = source
    }
    
    /// データ値が有効範囲内かチェック
    var isValid: Bool {
        switch type {
        case .weight:
            return value > 0 && value < 500 // 0-500kg
        case .steps:
            return value >= 0 && value <= 100000 // 0-100,000歩
        case .calories:
            return value >= 0 && value <= 10000 // 0-10,000kcal
        case .heartRate:
            return value > 0 && value < 300 // 1-300bpm
        case .bloodGlucose:
            return value > 0 && value < 1000 // 0-1000mg/dL
        }
    }
}

enum HealthDataType: String, CaseIterable, Codable {
    case weight = "weight"
    case steps = "steps"  
    case calories = "calories"
    case heartRate = "heartRate"
    case bloodGlucose = "bloodGlucose" // テスト用（サポート外として使用）
    
    var displayName: String {
        switch self {
        case .weight: return "kg"
        case .steps: return "歩"
        case .calories: return "kcal"
        case .heartRate: return "bpm"
        case .bloodGlucose: return "mg/dL"
        }
    }
}

enum DataSource: String, Codable {
    case healthKit = "healthKit"
    case manual = "manual"
}