import Foundation

/// Repository protocol for Badge data access operations
/// Provides abstraction layer between Use Cases and Infrastructure
protocol BadgeRepositoryProtocol {
    
    /// Save a badge to persistent storage
    /// - Parameter badge: The Badge to save
    /// - Throws: HealthAppError if save operation fails
    func save(_ badge: Badge) async throws
    
    /// Fetch all badges from persistent storage
    /// - Returns: Array of all badges
    /// - Throws: HealthAppError if fetch operation fails
    func fetchAllBadges() async throws -> [Badge]
    
    /// Fetch earned badges for a user from persistent storage
    /// - Parameter user: The User to fetch earned badges for
    /// - Returns: Array of earned badges for the user
    /// - Throws: HealthAppError if fetch operation fails
    func fetchEarnedBadges(for user: User) async throws -> [Badge]
    
    /// Fetch badges by type from persistent storage
    /// - Parameter type: The BadgeType to filter by
    /// - Returns: Array of badges matching the type
    /// - Throws: HealthAppError if fetch operation fails
    func fetchBadges(byType type: BadgeType) async throws -> [Badge]
    
    /// Mark a badge as earned for a user
    /// - Parameters:
    ///   - badge: The Badge to mark as earned
    ///   - user: The User who earned the badge
    /// - Throws: HealthAppError if operation fails
    func markAsEarned(_ badge: Badge, for user: User) async throws
    
    /// Delete a badge from persistent storage
    /// - Parameter badge: The Badge to delete
    /// - Throws: HealthAppError if delete operation fails
    func delete(_ badge: Badge) async throws
}