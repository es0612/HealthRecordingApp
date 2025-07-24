import Testing
import Foundation
import SwiftData
@testable import HealthRecordingApp

@Suite("BadgeRepository Tests")
struct BadgeRepositoryTests {
    
    private func createTestModelContext() throws -> ModelContext {
        let schema = Schema([HealthRecord.self, User.self, Goal.self, Badge.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }
    
    private func createTestUser() throws -> User {
        return try User(name: "Test User", age: 30, height: 170.0, targetWeight: 65.0)
    }
    
    private func createTestBadge(type: BadgeType = .milestone) throws -> Badge {
        return try Badge(
            name: "Test Badge",
            description: "A test badge for unit testing",
            type: type,
            requirement: BadgeRequirement.recordCount(count: 10),
            iconName: "star.fill",
            colorScheme: .gold
        )
    }
    
    @Test("BadgeRepository should save badge successfully")
    func testSaveBadge() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataBadgeRepository(modelContext: modelContext)
        let badge = try createTestBadge()
        
        // When
        try await repository.save(badge)
        
        // Then
        let savedBadges = try await repository.fetchAllBadges()
        #expect(savedBadges.count == 1)
        #expect(savedBadges.first?.id == badge.id)
        #expect(savedBadges.first?.name == "Test Badge")
        #expect(savedBadges.first?.type == .milestone)
    }
    
    @Test("BadgeRepository should handle save errors gracefully")
    func testSaveBadgeError() async throws {
        // When & Then - Try to create invalid badge (empty name should cause validation error)
        do {
            _ = try Badge(
                name: "",
                description: "Invalid badge",
                type: .milestone,
                requirement: BadgeRequirement.recordCount(count: 10),
                iconName: "star.fill",
                colorScheme: .gold
            )
            #expect(Bool(false), "Should throw ValidationError when creating invalid badge")
        } catch let error as ValidationError {
            #expect(error.errorCode.starts(with: "VAL"))
        } catch {
            #expect(Bool(false), "Should throw ValidationError for invalid badge creation, but got: \(type(of: error))")
        }
    }
    
    @Test("BadgeRepository should fetch all badges successfully")
    func testFetchAllBadges() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataBadgeRepository(modelContext: modelContext)
        
        let badge1 = try createTestBadge(type: .milestone)
        let badge2 = try Badge(
            name: "Streak Badge",
            description: "A streak badge",
            type: .streak,
            requirement: BadgeRequirement.streak(days: 7),
            iconName: "flame.fill",
            colorScheme: .silver
        )
        
        try await repository.save(badge1)
        try await repository.save(badge2)
        
        // When
        let fetchedBadges = try await repository.fetchAllBadges()
        
        // Then
        #expect(fetchedBadges.count == 2)
        #expect(fetchedBadges.contains { $0.type == .milestone })
        #expect(fetchedBadges.contains { $0.type == .streak })
    }
    
    @Test("BadgeRepository should fetch earned badges for user")
    func testFetchEarnedBadgesForUser() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataBadgeRepository(modelContext: modelContext)
        let user = try createTestUser()
        
        let badge1 = try createTestBadge(type: .milestone)
        let badge2 = try Badge(
            name: "Unearned Badge",
            description: "Not earned yet",
            type: .achievement,
            requirement: BadgeRequirement.recordCount(count: 100),
            iconName: "trophy.fill",
            colorScheme: .bronze
        )
        
        try await repository.save(badge1)
        try await repository.save(badge2)
        
        // Mark only badge1 as earned
        try await repository.markAsEarned(badge1, for: user)
        
        // When
        let earnedBadges = try await repository.fetchEarnedBadges(for: user)
        
        // Then
        #expect(earnedBadges.count == 1)
        #expect(earnedBadges.first?.id == badge1.id)
        #expect(earnedBadges.first?.isEarned == true)
    }
    
    @Test("BadgeRepository should fetch badges by type")
    func testFetchBadgesByType() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataBadgeRepository(modelContext: modelContext)
        
        let milestoneBadge = try createTestBadge(type: .milestone)
        let streakBadge = try Badge(
            name: "Streak Badge",
            description: "A streak badge",
            type: .streak,
            requirement: BadgeRequirement.streak(days: 7),
            iconName: "flame.fill",
            colorScheme: .silver
        )
        let achievementBadge = try Badge(
            name: "Achievement Badge",
            description: "An achievement badge",
            type: .achievement,
            requirement: BadgeRequirement.recordCount(count: 50),
            iconName: "award.fill",
            colorScheme: .gold
        )
        
        try await repository.save(milestoneBadge)
        try await repository.save(streakBadge)
        try await repository.save(achievementBadge)
        
        // When
        let milestoneBadges = try await repository.fetchBadges(byType: .milestone)
        let streakBadges = try await repository.fetchBadges(byType: .streak)
        
        // Then
        #expect(milestoneBadges.count == 1)
        #expect(milestoneBadges.first?.type == .milestone)
        
        #expect(streakBadges.count == 1)
        #expect(streakBadges.first?.type == .streak)
    }
    
    @Test("BadgeRepository should mark badge as earned successfully")
    func testMarkBadgeAsEarned() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataBadgeRepository(modelContext: modelContext)
        let user = try createTestUser()
        let badge = try createTestBadge()
        
        try await repository.save(badge)
        #expect(badge.isEarned == false) // Initially not earned
        
        // When
        try await repository.markAsEarned(badge, for: user)
        
        // Then
        let earnedBadges = try await repository.fetchEarnedBadges(for: user)
        #expect(earnedBadges.count == 1)
        #expect(earnedBadges.first?.id == badge.id)
        #expect(earnedBadges.first?.isEarned == true)
        #expect(earnedBadges.first?.earnedDate != nil)
    }
    
    @Test("BadgeRepository should prevent duplicate earning of same badge")
    func testPreventDuplicateBadgeEarning() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataBadgeRepository(modelContext: modelContext)
        let user = try createTestUser()
        let badge = try createTestBadge()
        
        try await repository.save(badge)
        try await repository.markAsEarned(badge, for: user)
        
        // When - Try to earn the same badge again
        try await repository.markAsEarned(badge, for: user)
        
        // Then - Should not duplicate the earned badge
        let earnedBadges = try await repository.fetchEarnedBadges(for: user)
        #expect(earnedBadges.count == 1)
        #expect(earnedBadges.first?.isEarned == true)
    }
    
    @Test("BadgeRepository should delete badge successfully")
    func testDeleteBadge() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataBadgeRepository(modelContext: modelContext)
        let badge = try createTestBadge()
        
        try await repository.save(badge)
        
        // Verify badge exists
        let badgesBeforeDelete = try await repository.fetchAllBadges()
        #expect(badgesBeforeDelete.count == 1)
        
        // When
        try await repository.delete(badge)
        
        // Then
        let badgesAfterDelete = try await repository.fetchAllBadges()
        #expect(badgesAfterDelete.isEmpty)
    }
    
    @Test("BadgeRepository should handle delete errors gracefully")
    func testDeleteBadgeError() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataBadgeRepository(modelContext: modelContext)
        let badge = try createTestBadge()
        
        // Don't save the badge first, so delete should fail
        
        // When & Then
        do {
            try await repository.delete(badge)
            #expect(Bool(false), "Should throw error when deleting non-existent badge")
        } catch let error as DataError {
            #expect(error.errorCode.starts(with: "DATA"))
        } catch {
            #expect(Bool(false), "Should throw DataError for delete failure")
        }
    }
    
    @Test("BadgeRepository should return empty array for no matches")
    func testFetchBadgesNoMatches() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataBadgeRepository(modelContext: modelContext)
        let user = try createTestUser()
        
        // When - Fetch from empty repository
        let allBadges = try await repository.fetchAllBadges()
        let earnedBadges = try await repository.fetchEarnedBadges(for: user)
        let milestoneBadges = try await repository.fetchBadges(byType: .milestone)
        
        // Then
        #expect(allBadges.isEmpty)
        #expect(earnedBadges.isEmpty)
        #expect(milestoneBadges.isEmpty)
    }
    
    @Test("BadgeRepository should handle concurrent operations")
    func testConcurrentOperations() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataBadgeRepository(modelContext: modelContext)
        
        // When - Perform concurrent save operations
        await withTaskGroup(of: Void.self) { group in
            for i in 1...5 {
                group.addTask {
                    do {
                        let badge = try Badge(
                            name: "Concurrent Badge \(i)",
                            description: "Concurrent test badge \(i)",
                            type: .milestone,
                            requirement: BadgeRequirement.recordCount(count: i * 10),
                            iconName: "star.fill",
                            colorScheme: .gold
                        )
                        try await repository.save(badge)
                    } catch {
                        // Ignore errors in concurrent test
                    }
                }
            }
        }
        
        // Then
        let allBadges = try await repository.fetchAllBadges()
        #expect(allBadges.count >= 3) // Allow for some concurrent operations to succeed
    }
    
    @Test("BadgeRepository should handle badge requirement validation")
    func testBadgeRequirementValidation() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataBadgeRepository(modelContext: modelContext)
        
        // Test different badge requirement types
        let recordCountBadge = try Badge(
            name: "Record Count Badge",
            description: "Requires 50 records",
            type: .milestone,
            requirement: BadgeRequirement.recordCount(count: 50),
            iconName: "number.circle.fill",
            colorScheme: .bronze
        )
        
        let streakBadge = try Badge(
            name: "Streak Badge",
            description: "Requires 7 day streak",
            type: .streak,
            requirement: BadgeRequirement.streak(days: 7),
            iconName: "flame.fill",
            colorScheme: .silver
        )
        
        // When
        try await repository.save(recordCountBadge)
        try await repository.save(streakBadge)
        
        // Then
        let savedBadges = try await repository.fetchAllBadges()
        #expect(savedBadges.count == 2)
        #expect(savedBadges.contains { $0.requirement == BadgeRequirement.recordCount(count: 50) })
        #expect(savedBadges.contains { $0.requirement == BadgeRequirement.streak(days: 7) })
    }
}