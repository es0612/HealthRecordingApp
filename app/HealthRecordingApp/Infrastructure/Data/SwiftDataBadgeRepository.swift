import Foundation
import SwiftData

/// SwiftData implementation of BadgeRepository
/// Provides badge data persistence using SwiftData with CloudKit integration
final class SwiftDataBadgeRepository: BadgeRepositoryProtocol {
    
    private let modelContext: ModelContext
    private let logger: AILoggerProtocol
    
    init(modelContext: ModelContext, logger: AILoggerProtocol = AILogger()) {
        self.modelContext = modelContext
        self.logger = logger
    }
    
    func save(_ badge: Badge) async throws {
        let startTime = Date()
        
        do {
            // Validation is handled by the Badge domain model
            modelContext.insert(badge)
            
            // Save changes
            try modelContext.save()
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("save_badge", duration: duration, success: true)
            
            logger.info("Badge saved successfully", context: [
                "badge_id": badge.id.uuidString,
                "name": badge.name,
                "type": badge.type.rawValue
            ])
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("save_badge", duration: duration, success: false)
            
            logger.error(error, context: [
                "badge_id": badge.id.uuidString,
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
    
    func fetchAllBadges() async throws -> [Badge] {
        let startTime = Date()
        
        do {
            let descriptor = FetchDescriptor<Badge>(
                sortBy: [SortDescriptor(\Badge.name, order: .forward)]
            )
            
            let badges = try modelContext.fetch(descriptor)
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("fetch_all_badges", duration: duration, success: true)
            
            logger.info("All badges fetched successfully", context: [
                "badge_count": badges.count
            ])
            
            return badges
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("fetch_all_badges", duration: duration, success: false)
            
            logger.error(error, context: [
                "operation": "fetch_all_badges"
            ])
            
            throw DataError.swiftDataOperationFailed(error)
        }
    }
    
    func fetchEarnedBadges(for user: User) async throws -> [Badge] {
        let startTime = Date()
        
        do {
            let descriptor = FetchDescriptor<Badge>(
                sortBy: [SortDescriptor(\Badge.earnedDate, order: .reverse)]
            )
            
            let allBadges = try modelContext.fetch(descriptor)
            
            // Filter badges that are earned and associated with the user
            let earnedBadges = allBadges.filter { badge in
                badge.isEarned && badge.user?.id == user.id
            }
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("fetch_earned_badges", duration: duration, success: true)
            
            logger.info("Earned badges fetched successfully", context: [
                "user_id": user.id.uuidString,
                "earned_badge_count": earnedBadges.count
            ])
            
            return earnedBadges
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("fetch_earned_badges", duration: duration, success: false)
            
            logger.error(error, context: [
                "user_id": user.id.uuidString,
                "operation": "fetch_earned_badges"
            ])
            
            throw DataError.swiftDataOperationFailed(error)
        }
    }
    
    func fetchBadges(byType type: BadgeType) async throws -> [Badge] {
        let startTime = Date()
        
        do {
            let descriptor = FetchDescriptor<Badge>(
                sortBy: [SortDescriptor(\Badge.name, order: .forward)]
            )
            
            let allBadges = try modelContext.fetch(descriptor)
            
            // Filter badges by type using programmatic filtering
            let filteredBadges = allBadges.filter { badge in
                badge.type == type
            }
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("fetch_badges_by_type", duration: duration, success: true)
            
            logger.info("Badges fetched by type successfully", context: [
                "badge_type": type.rawValue,
                "badge_count": filteredBadges.count
            ])
            
            return filteredBadges
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("fetch_badges_by_type", duration: duration, success: false)
            
            logger.error(error, context: [
                "badge_type": type.rawValue,
                "operation": "fetch_badges_by_type"
            ])
            
            throw DataError.swiftDataOperationFailed(error)
        }
    }
    
    func markAsEarned(_ badge: Badge, for user: User) async throws {
        let startTime = Date()
        
        do {
            // Check if badge is already earned by this user
            if badge.isEarned && badge.user?.id == user.id {
                logger.info("Badge already earned by user", context: [
                    "badge_id": badge.id.uuidString,
                    "user_id": user.id.uuidString
                ])
                return // Already earned, no need to duplicate
            }
            
            // Mark badge as earned
            badge.earn(for: user)
            
            // Save changes
            try modelContext.save()
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("mark_badge_earned", duration: duration, success: true)
            
            logger.info("Badge marked as earned successfully", context: [
                "badge_id": badge.id.uuidString,
                "user_id": user.id.uuidString,
                "badge_name": badge.name
            ])
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("mark_badge_earned", duration: duration, success: false)
            
            logger.error(error, context: [
                "badge_id": badge.id.uuidString,
                "user_id": user.id.uuidString,
                "operation": "mark_as_earned"
            ])
            
            throw DataError.swiftDataOperationFailed(error)
        }
    }
    
    func delete(_ badge: Badge) async throws {
        let startTime = Date()
        
        do {
            // Check if badge exists in context by fetching all and filtering
            let descriptor = FetchDescriptor<Badge>()
            let allBadges = try modelContext.fetch(descriptor)
            let existingBadge = allBadges.first { $0.id == badge.id }
            
            guard let badgeToDelete = existingBadge else {
                throw DataError.dataCorruption("Badge", field: "id: \(badge.id)")
            }
            
            // Delete the badge
            modelContext.delete(badgeToDelete)
            
            // Save changes
            try modelContext.save()
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("delete_badge", duration: duration, success: true)
            
            logger.info("Badge deleted successfully", context: [
                "badge_id": badge.id.uuidString,
                "name": badge.name
            ])
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("delete_badge", duration: duration, success: false)
            
            logger.error(error, context: [
                "badge_id": badge.id.uuidString,
                "operation": "delete"
            ])
            
            throw DataError.swiftDataOperationFailed(error)
        }
    }
}