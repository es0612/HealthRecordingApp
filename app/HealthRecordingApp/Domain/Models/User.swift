import SwiftData
import Foundation

@Model
final class User {
    var id: UUID
    var name: String
    var age: Int
    var height: Double
    var targetWeight: Double
    var createdAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade) var healthRecords: [HealthRecord] = []
    @Relationship(deleteRule: .cascade) var goals: [Goal] = []
    
    init(name: String, age: Int, height: Double, targetWeight: Double) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidInput("User", value: name, reason: "User name cannot be empty")
        }
        guard age >= 10 && age <= 120 else {
            throw ValidationError.invalidInput("User", value: "\(age)", reason: "User age must be between 10 and 120")
        }
        guard height > 0 && height <= 300 else {
            throw ValidationError.invalidInput("User", value: "\(height)", reason: "User height must be between 0 and 300 cm")
        }
        guard targetWeight > 0 && targetWeight <= 500 else {
            throw ValidationError.invalidInput("User", value: "\(targetWeight)", reason: "User target weight must be between 0 and 500 kg")
        }
        
        self.id = UUID()
        self.name = name
        self.age = age
        self.height = height
        self.targetWeight = targetWeight
        self.createdAt = Date()
    }
    
    /// ターゲット体重に基づくBMI計算
    var targetBMI: Double {
        let heightInMeters = height / 100.0
        return targetWeight / (heightInMeters * heightInMeters)
    }
    
    /// 年齢が有効範囲内かチェック
    var isValidAge: Bool {
        return age >= 10 && age <= 120
    }
    
    /// BMIカテゴリの判定
    var bmiCategory: BMICategory {
        switch targetBMI {
        case ..<18.5:
            return .underweight
        case 18.5..<25.0:
            return .normal
        case 25.0..<30.0:
            return .overweight
        default:
            return .obese
        }
    }
    
    /// ユーザーの現在の体重を取得（最新のHealthRecordから）
    var currentWeight: Double? {
        return healthRecords
            .filter { $0.type == .weight }
            .sorted { $0.timestamp > $1.timestamp }
            .first?.value
    }
}

enum BMICategory: String, CaseIterable {
    case underweight = "低体重"
    case normal = "普通体重" 
    case overweight = "肥満(1度)"
    case obese = "肥満(2度以上)"
}

