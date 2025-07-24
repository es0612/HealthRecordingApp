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
        let badge = Badge(
            name: name,
            description: description,
            type: type,
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
        let badge1 = Badge(name: "Badge1", description: "Test1", type: .streak,
                          iconName: "star", colorScheme: .bronze)
        let badge2 = Badge(name: "Badge2", description: "Test2", type: .achievement,
                          iconName: "trophy", colorScheme: .silver)
        
        // Then
        #expect(badge1.id != badge2.id)
    }
    
    @Test("Badge should be earned correctly")
    func testBadgeEarning() async throws {
        // Given
        let badge = Badge(name: "継続は力なり", description: "7日連続記録", type: .streak,
                         iconName: "flame", colorScheme: .gold)
        
        // When - Initial state
        #expect(badge.isEarned == false)
        #expect(badge.earnedDate == nil)
        
        // When - Earn badge
        let beforeEarning = Date()
        badge.earn()
        let afterEarning = Date()
        
        // Then
        #expect(badge.isEarned == true)
        #expect(badge.earnedDate != nil)
        #expect(badge.earnedDate! >= beforeEarning)
        #expect(badge.earnedDate! <= afterEarning)
    }
    
    @Test("Badge should not be earned twice")
    func testBadgeEarningOnce() async throws {
        // Given
        let badge = Badge(name: "Test Badge", description: "Test", type: .milestone,
                         iconName: "star", colorScheme: .bronze)
        
        // When - First earning
        badge.earn()
        let firstEarnedDate = badge.earnedDate
        
        // Small delay to ensure different timestamps
        try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        
        // When - Try to earn again
        badge.earn()
        
        // Then - Should not change
        #expect(badge.earnedDate == firstEarnedDate)
        #expect(badge.isEarned == true)
    }
    
    @Test("Badge should reset correctly")
    func testBadgeReset() async throws {
        // Given
        let badge = Badge(name: "Test Badge", description: "Test", type: .streak,
                         iconName: "star", colorScheme: .bronze)
        badge.earn()
        
        // When - Reset badge
        badge.reset()
        
        // Then
        #expect(badge.isEarned == false)
        #expect(badge.earnedDate == nil)
    }
    
    @Test("Badge should validate requirements correctly")
    func testBadgeRequirementValidation() async throws {
        // Given
        let requirement = BadgeRequirement(
            type: .streak,
            targetValue: 7.0,
            dataType: .weight,
            description: "7日連続体重記録"
        )
        
        let badge = Badge(name: "継続バッジ", description: "7日連続", type: .streak,
                         iconName: "flame", colorScheme: .silver)
        badge.requirement = requirement
        
        // When & Then
        #expect(badge.requirement != nil)
        #expect(badge.requirement?.type == .streak)
        #expect(badge.requirement?.targetValue == 7.0)
        #expect(badge.requirement?.dataType == .weight)
    }
    
    @Test("Badge should provide display information")
    func testBadgeDisplayInfo() async throws {
        // Given
        let badge = Badge(name: "マスターバッジ", description: "全目標達成", type: .special,
                         iconName: "crown.fill", colorScheme: .platinum)
        
        // When & Then
        #expect(badge.displayName == "マスターバッジ")
        #expect(badge.displayDescription == "全目標達成")
        #expect(badge.sfSymbolName == "crown.fill")
        #expect(!badge.isSpecialBadge == false) // special type
    }
}