import Foundation
import SwiftData

/// SwiftData implementation of GoalRepository
/// Provides data persistence using SwiftData with CloudKit integration
final class SwiftDataGoalRepository: GoalRepositoryProtocol {
    
    private let modelContext: ModelContext
    private let logger: AILoggerProtocol
    
    init(modelContext: ModelContext, logger: AILoggerProtocol = AILogger()) {
        self.modelContext = modelContext
        self.logger = logger
    }
    
    func save(_ goal: Goal) async throws {
        let startTime = Date()
        
        do {
            // Insert or update in model context
            modelContext.insert(goal)
            
            // Save changes
            try modelContext.save()
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("save_goal", duration: duration, success: true)
            
            logger.info("Goal saved successfully", context: [
                "goal_id": goal.id.uuidString,
                "type": goal.type.rawValue,
                "target_value": goal.targetValue,
                "is_active": goal.isActive
            ])
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("save_goal", duration: duration, success: false)
            
            logger.error(error, context: [
                "goal_id": goal.id.uuidString,
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
    
    func fetchGoals(for user: User, activeOnly: Bool) async throws -> [Goal] {
        let startTime = Date()
        
        do {
            // Fetch all goals first, then filter programmatically to avoid predicate issues
            let descriptor = FetchDescriptor<Goal>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            
            let allGoals = try modelContext.fetch(descriptor)
            
            // Filter programmatically
            let goals = allGoals.filter { goal in
                // Filter by user
                guard goal.user?.id == user.id else { return false }
                
                // Filter by active status if specified
                if activeOnly {
                    return goal.isActive
                }
                
                return true
            }
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("fetch_goals", duration: duration, success: true)
            
            logger.info("Goals fetched successfully", context: [
                "user_id": user.id.uuidString,
                "active_only": activeOnly,
                "goals_count": goals.count
            ])
            
            return goals
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("fetch_goals", duration: duration, success: false)
            
            logger.error(error, context: [
                "user_id": user.id.uuidString,
                "active_only": activeOnly,
                "operation": "fetch_goals"
            ])
            
            throw DataError.swiftDataOperationFailed(error)
        }
    }
    
    func fetchGoal(byId id: UUID) async throws -> Goal? {
        let startTime = Date()
        
        do {
            let predicate = #Predicate<Goal> { goal in
                goal.id == id
            }
            
            let descriptor = FetchDescriptor<Goal>(predicate: predicate)
            let goals = try modelContext.fetch(descriptor)
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("fetch_goal_by_id", duration: duration, success: true)
            
            logger.info("Goal fetched by ID", context: [
                "goal_id": id.uuidString,
                "found": goals.first != nil
            ])
            
            return goals.first
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("fetch_goal_by_id", duration: duration, success: false)
            
            logger.error(error, context: [
                "goal_id": id.uuidString,
                "operation": "fetch_goal_by_id"
            ])
            
            throw DataError.swiftDataOperationFailed(error)
        }
    }
    
    func fetchGoals(byType type: HealthDataType, for user: User) async throws -> [Goal] {
        let startTime = Date()
        
        do {
            // Fetch all goals first, then filter programmatically to avoid predicate issues
            let descriptor = FetchDescriptor<Goal>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            
            let allGoals = try modelContext.fetch(descriptor)
            
            // Filter programmatically
            let goals = allGoals.filter { goal in
                // Filter by user and type
                return goal.user?.id == user.id && goal.type == type
            }
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("fetch_goals_by_type", duration: duration, success: true)
            
            logger.info("Goals fetched by type", context: [
                "user_id": user.id.uuidString,
                "type": type.rawValue,
                "goals_count": goals.count
            ])
            
            return goals
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("fetch_goals_by_type", duration: duration, success: false)
            
            logger.error(error, context: [
                "user_id": user.id.uuidString,
                "type": type.rawValue,
                "operation": "fetch_goals_by_type"
            ])
            
            throw DataError.swiftDataOperationFailed(error)
        }
    }
    
    func fetchCompletedGoals(for user: User) async throws -> [Goal] {
        let startTime = Date()
        
        do {
            // Fetch all goals first, then filter programmatically to avoid predicate issues
            let descriptor = FetchDescriptor<Goal>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            
            let allGoals = try modelContext.fetch(descriptor)
            
            // Filter programmatically
            let goals = allGoals.filter { goal in
                // Filter by user and completion status
                return goal.user?.id == user.id && goal.isCompleted
            }
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("fetch_completed_goals", duration: duration, success: true)
            
            logger.info("Completed goals fetched", context: [
                "user_id": user.id.uuidString,
                "completed_goals_count": goals.count
            ])
            
            return goals
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("fetch_completed_goals", duration: duration, success: false)
            
            logger.error(error, context: [
                "user_id": user.id.uuidString,
                "operation": "fetch_completed_goals"
            ])
            
            throw DataError.swiftDataOperationFailed(error)
        }
    }
    
    func fetchExpiredGoals(for user: User) async throws -> [Goal] {
        let startTime = Date()
        
        do {
            let currentDate = Date()
            
            // Fetch all goals first, then filter programmatically to avoid predicate issues
            let descriptor = FetchDescriptor<Goal>(
                sortBy: [SortDescriptor(\.deadline, order: .reverse)]
            )
            
            let allGoals = try modelContext.fetch(descriptor)
            
            // Filter programmatically
            let goals = allGoals.filter { goal in
                // Filter by user, deadline, and completion status
                return goal.user?.id == user.id && 
                       goal.deadline < currentDate && 
                       !goal.isCompleted
            }
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("fetch_expired_goals", duration: duration, success: true)
            
            logger.info("Expired goals fetched", context: [
                "user_id": user.id.uuidString,
                "expired_goals_count": goals.count
            ])
            
            return goals
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("fetch_expired_goals", duration: duration, success: false)
            
            logger.error(error, context: [
                "user_id": user.id.uuidString,
                "operation": "fetch_expired_goals"
            ])
            
            throw DataError.swiftDataOperationFailed(error)
        }
    }
    
    func delete(_ goal: Goal) async throws {
        let startTime = Date()
        
        do {
            // Remove from model context
            modelContext.delete(goal)
            
            // Save changes
            try modelContext.save()
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("delete_goal", duration: duration, success: true)
            
            logger.info("Goal deleted successfully", context: [
                "goal_id": goal.id.uuidString,
                "type": goal.type.rawValue
            ])
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("delete_goal", duration: duration, success: false)
            
            logger.error(error, context: [
                "goal_id": goal.id.uuidString,
                "operation": "delete"
            ])
            
            throw DataError.swiftDataOperationFailed(error)
        }
    }
    
    func updateProgress(_ goal: Goal) async throws {
        let startTime = Date()
        
        do {
            // Update progress is calculated automatically by the Goal model
            // based on currentValue and targetValue. We just need to save.
            try modelContext.save()
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("update_goal_progress", duration: duration, success: true)
            
            logger.info("Goal progress updated", context: [
                "goal_id": goal.id.uuidString,
                "current_value": goal.currentValue,
                "target_value": goal.targetValue,
                "progress": goal.progress
            ])
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("update_goal_progress", duration: duration, success: false)
            
            logger.error(error, context: [
                "goal_id": goal.id.uuidString,
                "operation": "update_progress"
            ])
            
            throw DataError.swiftDataOperationFailed(error)
        }
    }
}