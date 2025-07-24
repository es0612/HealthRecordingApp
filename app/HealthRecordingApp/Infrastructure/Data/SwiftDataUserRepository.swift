import Foundation
import SwiftData

/// SwiftData implementation of UserRepository
/// Provides user data persistence using SwiftData with CloudKit integration
final class SwiftDataUserRepository: UserRepositoryProtocol {
    
    private let modelContext: ModelContext
    private let logger: AILoggerProtocol
    
    init(modelContext: ModelContext, logger: AILoggerProtocol = AILogger()) {
        self.modelContext = modelContext
        self.logger = logger
    }
    
    func save(_ user: User) async throws {
        let startTime = Date()
        
        do {
            // Insert into model context (validation is handled by domain model)
            modelContext.insert(user)
            
            // Save changes
            try modelContext.save()
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("save_user", duration: duration, success: true)
            
            logger.info("User saved successfully", context: [
                "user_id": user.id.uuidString,
                "name": user.name,
                "age": user.age
            ])
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("save_user", duration: duration, success: false)
            
            logger.error(error, context: [
                "user_id": user.id.uuidString,
                "operation": "save"
            ])
            
            // Re-throw ValidationErrors directly, wrap other errors in DataError
            if error is ValidationError {
                throw error
            } else {
                throw DataError.swiftDataOperationFailed(error)
            }
        }
    }
    
    func fetchCurrentUser() async throws -> User? {
        let startTime = Date()
        
        do {
            // Fetch all users and return the most recently created one
            let descriptor = FetchDescriptor<User>(
                sortBy: [SortDescriptor(\User.createdAt, order: .reverse)]
            )
            
            let users = try modelContext.fetch(descriptor)
            let currentUser = users.first
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("fetch_current_user", duration: duration, success: true)
            
            logger.info("Current user fetched successfully", context: [
                "user_found": currentUser != nil,
                "user_id": currentUser?.id.uuidString ?? "none"
            ])
            
            return currentUser
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("fetch_current_user", duration: duration, success: false)
            
            logger.error(error, context: [
                "operation": "fetch_current_user"
            ])
            
            throw DataError.swiftDataOperationFailed(error)
        }
    }
    
    func delete(_ user: User) async throws {
        let startTime = Date()
        
        do {
            // Check if user exists in context by fetching all and filtering
            let descriptor = FetchDescriptor<User>()
            let allUsers = try modelContext.fetch(descriptor)
            let existingUser = allUsers.first { $0.id == user.id }
            
            guard let userToDelete = existingUser else {
                throw DataError.dataCorruption("User", field: "id: \(user.id)")
            }
            
            // Delete the user (cascade delete will handle related records)
            modelContext.delete(userToDelete)
            
            // Save changes
            try modelContext.save()
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("delete_user", duration: duration, success: true)
            
            logger.info("User deleted successfully", context: [
                "user_id": user.id.uuidString,
                "name": user.name
            ])
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("delete_user", duration: duration, success: false)
            
            logger.error(error, context: [
                "user_id": user.id.uuidString,
                "operation": "delete"
            ])
            
            throw DataError.swiftDataOperationFailed(error)
        }
    }
}