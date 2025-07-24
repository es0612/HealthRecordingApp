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
    
    init(name: String, age: Int, height: Double, targetWeight: Double) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            fatalError("User name cannot be empty")
        }
        guard age >= 10 && age <= 120 else {
            fatalError("User age must be between 10 and 120")
        }
        guard height > 0 && height <= 300 else {
            fatalError("User height must be between 0 and 300 cm")
        }
        guard targetWeight > 0 && targetWeight <= 500 else {
            fatalError("User target weight must be between 0 and 500 kg")
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

@Model
final class Goal {
    var id: UUID
    var type: HealthDataType
    var targetValue: Double
    var currentValue: Double
    var deadline: Date
    var isActive: Bool
    var createdAt: Date
    
    // Relationship
    var user: User?
    
    init(type: HealthDataType, targetValue: Double, deadline: Date) {
        guard targetValue > 0 else {
            fatalError("Goal target value must be positive")
        }
        
        self.id = UUID()
        self.type = type
        self.targetValue = targetValue
        self.currentValue = 0.0
        self.deadline = deadline
        self.isActive = true
        self.createdAt = Date()
    }
    
    /// 目標の進捗を0.0から1.0の範囲で計算
    var progress: Double {
        let calculatedProgress = currentValue / targetValue
        return min(calculatedProgress, 1.0) // 最大1.0に制限
    }
    
    /// 目標が完了しているかどうか
    var isCompleted: Bool {
        return currentValue >= targetValue
    }
    
    /// 目標が期限切れかどうか
    var isExpired: Bool {
        return Date() > deadline
    }
    
    /// ユーザーの健康記録から現在値を更新
    func updateCurrentValueFromHealthRecords() {
        guard let user = user else { return }
        
        let relevantRecords = user.healthRecords
            .filter { $0.type == type }
            .sorted { $0.timestamp > $1.timestamp }
        
        if let latestRecord = relevantRecords.first {
            currentValue = latestRecord.value
        }
    }
}