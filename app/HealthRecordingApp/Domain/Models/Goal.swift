import SwiftData
import Foundation

@Model
final class Goal {
    var id: UUID
    var type: HealthDataType
    var targetValue: Double
    var currentValue: Double
    var deadline: Date
    var isActive: Bool
    var isCompleted: Bool
    var goalDescription: String?
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    var user: User?
    
    init(
        type: HealthDataType,
        targetValue: Double,
        deadline: Date,
        goalDescription: String? = nil,
        isActive: Bool = true
    ) throws {
        guard targetValue > 0 else {
            throw ValidationError.invalidInput("Goal", value: "\(targetValue)", reason: "Target value must be positive")
        }
        
        guard deadline > Date() else {
            throw ValidationError.invalidInput("Goal", value: deadline.description, reason: "Deadline must be in the future")
        }
        
        self.id = UUID()
        self.type = type
        self.targetValue = targetValue
        self.currentValue = 0.0
        self.deadline = deadline
        self.isActive = isActive
        self.isCompleted = false
        self.goalDescription = goalDescription
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Computed Properties
    
    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(1.0, currentValue / targetValue)
    }
    
    var progressPercentage: Double {
        return progress * 100
    }
    
    var isExpired: Bool {
        return deadline < Date() && !isCompleted
    }
    
    var remainingDays: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: deadline)
        return max(0, components.day ?? 0)
    }
    
    // MARK: - Methods
    
    func updateCurrentValue(from healthRecords: [HealthRecord]) {
        let relevantRecords = healthRecords.filter { $0.type == type }
        
        switch type {
        case .weight:
            // For weight goals, use the latest record
            if let latestRecord = relevantRecords.max(by: { $0.timestamp < $1.timestamp }) {
                currentValue = latestRecord.value
            }
        case .steps, .calories:
            // For steps/calories, sum recent daily values
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let recentRecords = relevantRecords.filter { calendar.startOfDay(for: $0.timestamp) >= today }
            currentValue = recentRecords.reduce(0) { $0 + $1.value }
        case .heartRate:
            // For heart rate, use average of recent records
            let recentRecords = relevantRecords.filter { 
                $0.timestamp.timeIntervalSinceNow > -24 * 60 * 60 // Last 24 hours
            }
            if !recentRecords.isEmpty {
                currentValue = recentRecords.reduce(0) { $0 + $1.value } / Double(recentRecords.count)
            }
        case .bloodGlucose:
            // For blood glucose, use latest reading
            if let latestRecord = relevantRecords.max(by: { $0.timestamp < $1.timestamp }) {
                currentValue = latestRecord.value
            }
        }
        
        // Check if goal is completed
        if currentValue >= targetValue && !isCompleted {
            isCompleted = true
            updatedAt = Date()
        }
    }
    
    func deactivate() {
        isActive = false
        updatedAt = Date()
    }
    
    func activate() {
        isActive = true
        updatedAt = Date()
    }
    
    func complete() {
        isCompleted = true
        updatedAt = Date()
    }
    
    func updateCurrentValueFromHealthRecords() {
        guard let user = user else { return }
        updateCurrentValue(from: user.healthRecords)
    }
}