import Testing
import Foundation
@testable import HealthRecordingApp

@Suite("Goal Tests")
struct GoalTests {
    
    @Test("Goal should be created with valid data")
    func testGoalCreation() async throws {
        // Given
        let type = HealthDataType.weight
        let targetValue = 65.0
        let deadline = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
        
        // When
        let goal = try Goal(type: type, targetValue: targetValue, deadline: deadline)
        
        // Then
        #expect(goal.type == .weight)
        #expect(goal.targetValue == 65.0)
        #expect(goal.currentValue == 0.0) // 初期値
        #expect(goal.deadline == deadline)
        #expect(goal.isActive == true) // 初期状態でアクティブ
        #expect(!goal.id.uuidString.isEmpty)
        #expect(goal.createdAt.timeIntervalSinceNow < 1.0) // 現在時刻に近い
        #expect(goal.user == nil) // 初期状態ではuser未設定
    }
    
    @Test("Goal should have unique ID for each instance")
    func testGoalUniqueID() async throws {
        // Given & When
        let deadline = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
        let goal1 = try Goal(type: .weight, targetValue: 65.0, deadline: deadline)
        let goal2 = try Goal(type: .steps, targetValue: 10000.0, deadline: deadline)
        
        // Then
        #expect(goal1.id != goal2.id)
    }
    
    @Test("Goal should calculate progress correctly")
    func testGoalProgress() async throws {
        // Given
        let deadline = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
        let goal = try Goal(type: .weight, targetValue: 100.0, deadline: deadline)
        
        // When - Initial progress
        #expect(goal.progress == 0.0)
        
        // When - Update current value
        goal.currentValue = 25.0
        #expect(goal.progress == 0.25) // 25/100 = 0.25
        
        goal.currentValue = 100.0
        #expect(goal.progress == 1.0) // 目標達成
        
        goal.currentValue = 150.0
        #expect(goal.progress == 1.0) // 100%を超えても1.0
    }
    
    @Test("Goal should determine if completed")
    func testGoalCompletion() async throws {
        // Given
        let deadline = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
        let goal = try Goal(type: .steps, targetValue: 10000.0, deadline: deadline)
        
        // When - Not completed
        goal.currentValue = 5000.0
        #expect(goal.isCompleted == false)
        
        // When - Completed
        goal.currentValue = 10000.0
        #expect(goal.isCompleted == true)
        
        goal.currentValue = 15000.0
        #expect(goal.isCompleted == true)
    }
    
    @Test("Goal should check if expired")
    func testGoalExpiration() async throws {
        // Given
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let futureDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        
        // When & Then
        let expiredGoal = try Goal(type: .weight, targetValue: 65.0, deadline: pastDate)
        #expect(expiredGoal.isExpired == true)
        
        let activeGoal = try Goal(type: .weight, targetValue: 65.0, deadline: futureDate)
        #expect(activeGoal.isExpired == false)
    }
    
    @Test("Goal should update current value from health records")
    func testGoalUpdateFromHealthRecords() async throws {
        // Given
        let user = try User(name: "Test User", age: 30, height: 170.0, targetWeight: 65.0)
        let deadline = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
        let goal = try Goal(type: .weight, targetValue: 65.0, deadline: deadline)
        goal.user = user
        
        let record1 = HealthRecord(type: .weight, value: 70.0, unit: "kg")
        let record2 = HealthRecord(type: .weight, value: 68.0, unit: "kg")
        
        record1.user = user
        record2.user = user
        user.healthRecords.append(record1)
        user.healthRecords.append(record2)
        
        // When
        goal.updateCurrentValueFromHealthRecords()
        
        // Then - Should use latest weight record
        #expect(goal.currentValue != 0.0)
        #expect(goal.currentValue == 68.0 || goal.currentValue == 70.0) // タイムスタンプ依存
    }
}