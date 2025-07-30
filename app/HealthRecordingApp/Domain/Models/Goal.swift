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
        let now = Date()
        let timeInterval = deadline.timeIntervalSince(now)
        
        // Convert to days, allowing negative values for expired goals
        let days = Int(ceil(timeInterval / (24 * 60 * 60)))
        return days
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

// MARK: - Goal Suggestion

struct GoalSuggestion: Identifiable, Codable {
    let id = UUID()
    let type: HealthDataType
    let suggestedTargetValue: Double
    let suggestedDeadline: Date
    let title: String
    let description: String
    let reasoning: String
    let confidenceScore: Double // 0.0 to 1.0
    let isRecommended: Bool
    let basedOnData: [String] // What data this suggestion is based on
    let estimatedDifficulty: GoalDifficulty
    let priority: GoalPriority
    
    init(
        type: HealthDataType,
        suggestedTargetValue: Double,
        suggestedDeadline: Date,
        title: String,
        description: String,
        reasoning: String,
        confidenceScore: Double,
        isRecommended: Bool = true,
        basedOnData: [String] = [],
        estimatedDifficulty: GoalDifficulty = .moderate,
        priority: GoalPriority = .medium
    ) {
        self.type = type
        self.suggestedTargetValue = suggestedTargetValue
        self.suggestedDeadline = suggestedDeadline
        self.title = title
        self.description = description
        self.reasoning = reasoning
        self.confidenceScore = confidenceScore
        self.isRecommended = isRecommended
        self.basedOnData = basedOnData
        self.estimatedDifficulty = estimatedDifficulty
        self.priority = priority
    }
    
    // Convert suggestion to actual Goal
    func createGoal() throws -> Goal {
        return try Goal(
            type: type,
            targetValue: suggestedTargetValue,
            deadline: suggestedDeadline,
            goalDescription: description
        )
    }
}

// MARK: - Supporting Enums

enum GoalDifficulty: String, CaseIterable, Codable {
    case easy = "easy"
    case moderate = "moderate"
    case challenging = "challenging"
    case difficult = "difficult"
    
    var displayName: String {
        switch self {
        case .easy: return "簡単"
        case .moderate: return "適度"
        case .challenging: return "挑戦的"
        case .difficult: return "困難"
        }
    }
    
    var color: String { // For UI representation
        switch self {
        case .easy: return "green"
        case .moderate: return "blue"
        case .challenging: return "orange"
        case .difficult: return "red"
        }
    }
}

enum GoalPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .critical: return "重要"
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
}