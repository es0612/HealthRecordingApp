import Testing
import Foundation
@testable import HealthRecordingApp

@Suite("Badge Tests")
struct BadgeTests {
    
    @Test("Badge should be created with valid data")
    func testBadgeCreation() async throws {
        // Given
        let name = "はじめの一歩"
        let description = "初回健康データを記録しました"
        let type = BadgeType.milestone
        let iconName = "star.fill"
        let colorScheme = BadgeColorScheme.bronze
        
        // When
        let badge = try Badge(
            name: name,
            description: description,
            type: type,
            requirement: BadgeRequirement.recordCount(count: 1),
            iconName: iconName,
            colorScheme: colorScheme
        )
        
        // Then
        #expect(badge.name == "はじめの一歩")
        #expect(badge.badgeDescription == "初回健康データを記録しました")
        #expect(badge.type == .milestone)
        #expect(badge.iconName == "star.fill")
        #expect(badge.colorScheme == .bronze)
        #expect(badge.isEarned == false) // 初期状態では未獲得
        #expect(badge.earnedDate == nil) // 初期状態では獲得日未設定
        #expect(!badge.id.uuidString.isEmpty)
        #expect(badge.createdAt.timeIntervalSinceNow < 1.0)
    }
    
    @Test("Badge should have unique ID for each instance")
    func testBadgeUniqueID() async throws {
        // Given & When
        let badge1 = try Badge(name: "Badge1", description: "Test1", type: .streak,
                          requirement: BadgeRequirement.streak(days: 7),
                          iconName: "star", colorScheme: .bronze)
        let badge2 = try Badge(name: "Badge2", description: "Test2", type: .achievement,
                          requirement: BadgeRequirement.recordCount(count: 10),
                          iconName: "trophy", colorScheme: .silver)
        
        // Then
        #expect(badge1.id != badge2.id)
    }
    
    @Test("Badge should be earned correctly")
    func testBadgeEarning() async throws {
        // Given
        let badge = try Badge(name: "継続は力なり", description: "7日連続記録", type: .streak,
                         requirement: BadgeRequirement.streak(days: 7),
                         iconName: "flame", colorScheme: .gold)
        let user = try User(name: "Test User", age: 30, height: 170.0, targetWeight: 65.0)
        
        // When - Initial state
        #expect(badge.isEarned == false)
        #expect(badge.earnedDate == nil)
        #expect(badge.user == nil)
        
        // When - Earn badge
        let beforeEarning = Date()
        badge.earn(for: user)
        let afterEarning = Date()
        
        // Then
        #expect(badge.isEarned == true)
        #expect(badge.earnedDate != nil)
        #expect(badge.earnedDate! >= beforeEarning)
        #expect(badge.earnedDate! <= afterEarning)
        #expect(badge.user?.id == user.id)
    }
    
    @Test("Badge should not be earned twice")
    func testBadgeEarningOnce() async throws {
        // Given
        let badge = try Badge(name: "Test Badge", description: "Test", type: .milestone,
                         requirement: BadgeRequirement.recordCount(count: 10),
                         iconName: "star", colorScheme: .bronze)
        let user = try User(name: "Test User", age: 30, height: 170.0, targetWeight: 65.0)
        
        // When - First earning
        badge.earn(for: user)
        let firstEarnedDate = badge.earnedDate
        
        // Small delay to ensure different timestamps
        try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        
        // When - Try to earn again
        badge.earn(for: user)
        
        // Then - Should not change
        #expect(badge.earnedDate == firstEarnedDate)
        #expect(badge.isEarned == true)
    }
    
    @Test("Badge should reset correctly")
    func testBadgeReset() async throws {
        // Given
        let badge = try Badge(name: "Test Badge", description: "Test", type: .streak,
                         requirement: BadgeRequirement.streak(days: 7),
                         iconName: "star", colorScheme: .bronze)
        let user = try User(name: "Test User", age: 30, height: 170.0, targetWeight: 65.0)
        badge.earn(for: user)
        
        // When - Reset badge
        badge.reset()
        
        // Then
        #expect(badge.isEarned == false)
        #expect(badge.earnedDate == nil)
        #expect(badge.user == nil)
    }
    
    @Test("Badge should validate requirements correctly")
    func testBadgeRequirementValidation() async throws {
        // Given
        let requirement = BadgeRequirement.streak(days: 7)
        
        let badge = try Badge(name: "継続バッジ", description: "7日連続", type: .streak,
                         requirement: requirement,
                         iconName: "flame", colorScheme: .silver)
        
        // When & Then
        #expect(badge.requirement == BadgeRequirement.streak(days: 7))
        #expect(badge.requirement.description == "7日連続記録")
        
        // Test user to check if requirement is met
        let user = try User(name: "Test User", age: 30, height: 170.0, targetWeight: 65.0)
        #expect(badge.requirement.isMet(for: user) == false) // No records yet
    }
    
    @Test("Badge should provide display information")
    func testBadgeDisplayInfo() async throws {
        // Given
        let badge = try Badge(name: "マスターバッジ", description: "全目標達成", type: .special,
                         requirement: BadgeRequirement.special,
                         iconName: "crown.fill", colorScheme: .platinum)
        
        // When & Then
        #expect(badge.displayName == "マスターバッジ")
        #expect(badge.displayDescription == "全目標達成")
        #expect(badge.sfSymbolName == "crown.fill")
        #expect(badge.isSpecialBadge == true) // special type should be true
    }
}