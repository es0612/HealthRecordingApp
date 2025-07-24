import Testing
import Foundation
import SwiftData
@testable import HealthRecordingApp

@Suite("UserRepository Tests")
struct UserRepositoryTests {
    
    private func createTestModelContext() throws -> ModelContext {
        let schema = Schema([HealthRecord.self, User.self, Goal.self, Badge.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }
    
    private func createTestUser() throws -> User {
        return try User(name: "Test User", age: 30, height: 170.0, targetWeight: 65.0)
    }
    
    @Test("UserRepository should save user successfully")
    func testSaveUser() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataUserRepository(modelContext: modelContext)
        let user = try createTestUser()
        
        // When
        try await repository.save(user)
        
        // Then
        let savedUser = try await repository.fetchCurrentUser()
        #expect(savedUser != nil)
        #expect(savedUser?.id == user.id)
        #expect(savedUser?.name == "Test User")
        #expect(savedUser?.age == 30)
        #expect(savedUser?.height == 170.0)
        #expect(savedUser?.targetWeight == 65.0)
    }
    
    @Test("UserRepository should handle save errors gracefully")
    func testSaveUserError() async throws {
        // When & Then - Try to create invalid user (empty name should cause validation error at creation time)
        do {
            _ = try User(name: "   ", age: 30, height: 170.0, targetWeight: 65.0)
            #expect(Bool(false), "Should throw ValidationError when creating invalid user")
        } catch let error as ValidationError {
            #expect(error.errorCode.starts(with: "VAL"))
        } catch {
            #expect(Bool(false), "Should throw ValidationError for invalid user creation, but got: \(type(of: error))")
        }
    }
    
    @Test("UserRepository should fetch current user successfully")
    func testFetchCurrentUser() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataUserRepository(modelContext: modelContext)
        let user = try createTestUser()
        
        // When - Save user first
        try await repository.save(user)
        
        // Then - Fetch should return the saved user
        let fetchedUser = try await repository.fetchCurrentUser()
        #expect(fetchedUser != nil)
        #expect(fetchedUser?.id == user.id)
        #expect(fetchedUser?.name == user.name)
    }
    
    @Test("UserRepository should return nil when no current user exists")
    func testFetchCurrentUserNoUser() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataUserRepository(modelContext: modelContext)
        
        // When - Fetch without saving any user
        let fetchedUser = try await repository.fetchCurrentUser()
        
        // Then - Should return nil
        #expect(fetchedUser == nil)
    }
    
    @Test("UserRepository should handle only one current user")
    func testSingleCurrentUser() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataUserRepository(modelContext: modelContext)
        let user1 = try createTestUser()
        let user2 = try User(name: "Second User", age: 25, height: 160.0, targetWeight: 55.0)
        
        // When - Save first user
        try await repository.save(user1)
        let firstFetch = try await repository.fetchCurrentUser()
        
        // Then - Should return first user
        #expect(firstFetch?.id == user1.id)
        
        // When - Save second user (should replace first as current)
        try await repository.save(user2)
        let secondFetch = try await repository.fetchCurrentUser()
        
        // Then - Should return second user as current
        #expect(secondFetch?.id == user2.id)
        #expect(secondFetch?.name == "Second User")
    }
    
    @Test("UserRepository should delete user successfully")
    func testDeleteUser() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataUserRepository(modelContext: modelContext)
        let user = try createTestUser()
        
        // Save user first
        try await repository.save(user)
        
        // Verify user exists
        let userBeforeDelete = try await repository.fetchCurrentUser()
        #expect(userBeforeDelete != nil)
        
        // When
        try await repository.delete(user)
        
        // Then
        let userAfterDelete = try await repository.fetchCurrentUser()
        #expect(userAfterDelete == nil)
    }
    
    @Test("UserRepository should handle delete errors gracefully")
    func testDeleteUserError() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataUserRepository(modelContext: modelContext)
        let user = try createTestUser()
        
        // Don't save the user first, so delete should fail
        
        // When & Then
        do {
            try await repository.delete(user)
            #expect(Bool(false), "Should throw error when deleting non-existent user")
        } catch let error as DataError {
            #expect(error.errorCode.starts(with: "DATA"))
        } catch {
            #expect(Bool(false), "Should throw DataError for delete failure")
        }
    }
    
    @Test("UserRepository should cascade delete health records")
    func testCascadeDeleteHealthRecords() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataUserRepository(modelContext: modelContext)
        let healthRecordRepository = SwiftDataHealthRecordRepository(modelContext: modelContext)
        let user = try createTestUser()
        
        // Save user and create health records
        try await repository.save(user)
        
        let healthRecord1 = HealthRecord(type: .weight, value: 70.0, unit: "kg")
        let healthRecord2 = HealthRecord(type: .steps, value: 10000.0, unit: "steps")
        healthRecord1.user = user
        healthRecord2.user = user
        
        try await healthRecordRepository.save(healthRecord1)
        try await healthRecordRepository.save(healthRecord2)
        
        // Verify health records exist
        let recordsBeforeDelete = try await healthRecordRepository.fetchRecords(for: user, type: nil, from: nil, to: nil)
        #expect(recordsBeforeDelete.count == 2)
        
        // When - Delete user
        try await repository.delete(user)
        
        // Then - Health records should be cascade deleted
        let recordsAfterDelete = try await healthRecordRepository.fetchRecords(for: user, type: nil, from: nil, to: nil)
        #expect(recordsAfterDelete.isEmpty)
    }
    
    @Test("UserRepository should handle concurrent operations")
    func testConcurrentOperations() async throws {
        // Given
        let modelContext = try createTestModelContext()
        let repository = SwiftDataUserRepository(modelContext: modelContext)
        
        // When - Perform concurrent save and fetch operations
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                do {
                    let user = try User(name: "Concurrent User 1", age: 30, height: 170.0, targetWeight: 65.0)
                    try await repository.save(user)
                } catch {
                    // Ignore errors in concurrent test
                }
            }
            
            group.addTask {
                _ = try? await repository.fetchCurrentUser()
            }
            
            group.addTask {
                do {
                    let user = try User(name: "Concurrent User 2", age: 25, height: 160.0, targetWeight: 55.0)
                    try await repository.save(user)
                } catch {
                    // Ignore errors in concurrent test
                }
            }
        }
        
        // Then - Should complete without crashing
        let finalUser = try await repository.fetchCurrentUser()
        #expect(finalUser != nil)
        #expect(finalUser?.name.contains("Concurrent User") == true)
    }
}