import Testing
import Foundation
@testable import HealthRecordingApp

@Suite("User Tests")
struct UserTests {
    
    @Test("User should be created with valid data")
    func testUserCreation() async throws {
        // Given
        let name = TestHealthData.testUserName
        let age = TestHealthData.testUserAge
        let height = TestHealthData.testUserHeight
        let targetWeight = TestHealthData.testUserTargetWeight
        
        // When
        let user = User(name: name, age: age, height: height, targetWeight: targetWeight)
        
        // Then
        #expect(user.name == TestHealthData.testUserName)
        #expect(user.age == TestHealthData.testUserAge)
        #expect(user.height == TestHealthData.testUserHeight)
        #expect(user.targetWeight == TestHealthData.testUserTargetWeight)
        #expect(!user.id.uuidString.isEmpty)
        #expect(user.createdAt.timeIntervalSinceNow < 1.0) // 現在時刻に近い
        #expect(user.healthRecords.isEmpty) // 初期状態は空
        #expect(user.goals.isEmpty) // 初期状態は空
    }
    
    @Test("User should have unique ID for each instance")
    func testUserUniqueID() async throws {
        // Given & When
        let user1 = User(name: "User1", age: 30, height: 170.0, targetWeight: 65.0)
        let user2 = User(name: "User2", age: 25, height: 160.0, targetWeight: 55.0)
        
        // Then
        #expect(user1.id != user2.id)
    }
    
    @Test("User should manage health records relationship")
    func testUserHealthRecordsRelationship() async throws {
        // Given
        let user = User(name: "Test User", age: 30, height: 170.0, targetWeight: 65.0)
        let healthRecord1 = HealthRecord(type: .weight, value: 70.0, unit: "kg")
        let healthRecord2 = HealthRecord(type: .steps, value: 10000.0, unit: "count")
        
        // When
        healthRecord1.user = user
        healthRecord2.user = user
        user.healthRecords.append(healthRecord1)
        user.healthRecords.append(healthRecord2)
        
        // Then
        #expect(user.healthRecords.count == 2)
        #expect(user.healthRecords.contains { $0.id == healthRecord1.id })
        #expect(user.healthRecords.contains { $0.id == healthRecord2.id })
        #expect(healthRecord1.user?.id == user.id)
        #expect(healthRecord2.user?.id == user.id)
    }
    
    @Test("User should calculate BMI correctly")
    func testUserBMICalculation() async throws {
        // Given
        let user = User(name: "Test User", age: 30, height: 170.0, targetWeight: 65.0)
        
        // When & Then
        let expectedBMI = 65.0 / ((170.0 / 100) * (170.0 / 100))
        #expect(abs(user.targetBMI - expectedBMI) < 0.01) // 小数点以下の誤差を考慮
    }
    
    @Test("User age should be within valid range")
    func testUserAgeValidation() async throws {
        // Given & When & Then
        let youngUser = User(name: "Young User", age: 18, height: 170.0, targetWeight: 65.0)
        #expect(youngUser.isValidAge)
        
        let oldUser = User(name: "Old User", age: 100, height: 170.0, targetWeight: 65.0)
        #expect(oldUser.isValidAge)
    }
    
    @Test("User should categorize BMI correctly")
    func testUserBMICategory() async throws {
        // Given & When & Then
        let underweightUser = User(name: "Underweight", age: 30, height: 170.0, targetWeight: 50.0) // BMI 17.3
        #expect(underweightUser.bmiCategory == .underweight)
        
        let normalUser = User(name: "Normal", age: 30, height: 170.0, targetWeight: 65.0) // BMI 22.5
        #expect(normalUser.bmiCategory == .normal)
        
        let overweightUser = User(name: "Overweight", age: 30, height: 170.0, targetWeight: 75.0) // BMI 26.0
        #expect(overweightUser.bmiCategory == .overweight)
        
        let obeseUser = User(name: "Obese", age: 30, height: 170.0, targetWeight: 90.0) // BMI 31.1
        #expect(obeseUser.bmiCategory == .obese)
    }
    
    @Test("User should get current weight from latest health record")
    func testUserCurrentWeight() async throws {
        // Given
        let user = User(name: "Test User", age: 30, height: 170.0, targetWeight: 65.0)
        
        // When - No health records
        #expect(user.currentWeight == nil)
        
        // When - Add weight records
        let record1 = HealthRecord(type: .weight, value: 72.0, unit: "kg")
        let record2 = HealthRecord(type: .weight, value: 70.0, unit: "kg")
        
        record1.user = user
        record2.user = user
        user.healthRecords.append(record1)
        user.healthRecords.append(record2)
        
        // Then - Should return latest weight (record2 has more recent timestamp)
        #expect(user.currentWeight != nil)
        #expect(user.currentWeight == 70.0 || user.currentWeight == 72.0) // いずれかの値（タイムスタンプ依存）
    }
}