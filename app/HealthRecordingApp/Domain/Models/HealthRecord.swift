import SwiftData
import Foundation
import SwiftUI

@Model
public final class HealthRecord: HealthRecordProtocol {
    public var id: UUID
    var type: HealthDataType
    var value: Double
    var unit: String
    var timestamp: Date
    var source: DataSource
    
    // Relationships
    var user: User?
    
    public init(
        type: HealthDataType,
        value: Double,
        unit: String,
        timestamp: Date = Date(),
        source: DataSource = .manual
    ) throws {
        guard value >= 0 else {
            throw ValidationError.invalidInput("HealthRecord", value: "\(value)", reason: "Value must be non-negative")
        }
        
        guard !unit.isEmpty else {
            throw ValidationError.invalidInput("HealthRecord", value: unit, reason: "Unit cannot be empty")
        }
        
        self.id = UUID()
        self.type = type
        self.value = value
        self.unit = unit
        self.timestamp = timestamp
        self.source = source
    }
    
    // MARK: - Convenience methods
    
    func formattedValue() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = type.preferredDecimalPlaces
        formatter.minimumFractionDigits = 0
        
        let number = NSNumber(value: value)
        return formatter.string(from: number) ?? String(value)
    }
    
    func displayString() -> String {
        return "\(formattedValue()) \(unit)"
    }
    
    /// データの妥当性をチェック
    public var isValid: Bool {
        guard value >= 0 else { return false }
        guard !unit.isEmpty else { return false }
        
        // Type-specific validation
        switch type {
        case .weight:
            return value > 0 && value <= 500 // 0-500kg range
        case .steps:
            return value <= 100000 // Max 100k steps per day
        case .calories:
            return value <= 10000 // Max 10k calories per day
        case .heartRate:
            return value >= 30 && value <= 220 // 30-220 bpm range
        case .bloodGlucose:
            return value >= 50 && value <= 600 // 50-600 mg/dL range
        case .bloodPressure:
            return value >= 50 && value <= 250 // 50-250 mmHg range
        case .sleep:
            return value >= 0 && value <= 24 // 0-24 hours range
        case .hydration:
            return value >= 0 && value <= 10 // 0-10 L per day
        case .exercise:
            return value >= 0 && value <= 1440 // 0-1440 minutes per day
        case .custom:
            return value >= 0 // Basic non-negative validation for custom types
        }
    }
}

public enum HealthDataType: String, CaseIterable, Codable, Sendable {
    case weight = "weight"
    case steps = "steps"  
    case calories = "calories"
    case heartRate = "heartRate"
    case bloodGlucose = "bloodGlucose" // テスト用（サポート外として使用）
    case bloodPressure = "bloodPressure"
    case sleep = "sleep"
    case hydration = "hydration"
    case exercise = "exercise"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .weight:
            return "体重"
        case .steps:
            return "歩数"
        case .calories:
            return "カロリー"
        case .heartRate:
            return "心拍数"
        case .bloodGlucose:
            return "血糖値"
        case .bloodPressure:
            return "血圧"
        case .sleep:
            return "睡眠"
        case .hydration:
            return "水分摂取"
        case .exercise:
            return "運動"
        case .custom:
            return "カスタム"
        }
    }
    
    var unit: String {
        switch self {
        case .weight:
            return "kg"
        case .steps:
            return "歩"
        case .calories:
            return "kcal"
        case .heartRate:
            return "bpm"
        case .bloodGlucose:
            return "mg/dL"
        case .bloodPressure:
            return "mmHg"
        case .sleep:
            return "時間"
        case .hydration:
            return "L"
        case .exercise:
            return "分"
        case .custom:
            return ""
        }
    }
    
    var color: Color {
        switch self {
        case .weight: return .purple
        case .steps: return .blue
        case .calories: return .orange
        case .heartRate: return .red
        case .bloodGlucose: return .green
        case .bloodPressure: return .purple
        case .sleep: return .indigo
        case .hydration: return .cyan
        case .exercise: return .mint
        case .custom: return .gray
        }
    }
    
    var iconName: String {
        switch self {
        case .weight: return "scalemass"
        case .steps: return "figure.walk"
        case .calories: return "flame"
        case .heartRate: return "heart"
        case .bloodGlucose: return "drop"
        case .bloodPressure: return "waveform.path.ecg"
        case .sleep: return "bed.double"
        case .hydration: return "drop.fill"
        case .exercise: return "figure.run"
        case .custom: return "circle.dashed"
        }
    }
    
    var preferredDecimalPlaces: Int {
        switch self {
        case .weight, .bloodGlucose, .hydration:
            return 1
        case .steps, .calories, .heartRate, .bloodPressure, .sleep, .exercise:
            return 0
        case .custom:
            return 1
        }
    }
}

public enum DataSource: String, Codable {
    case healthKit = "healthKit"
    case manual = "manual"
}