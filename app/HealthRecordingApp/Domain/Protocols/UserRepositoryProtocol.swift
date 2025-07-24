import Foundation

/// Repository protocol for User data access operations
/// Provides abstraction layer between Use Cases and Infrastructure
protocol UserRepositoryProtocol {
    
    /// Save a user to persistent storage
    /// - Parameter user: The User to save
    /// - Throws: HealthAppError if save operation fails
    func save(_ user: User) async throws
    
    /// Fetch the current user from persistent storage
    /// - Returns: The current User if exists, nil otherwise
    /// - Throws: HealthAppError if fetch operation fails
    func fetchCurrentUser() async throws -> User?
    
    /// Delete a user from persistent storage
    /// This will cascade delete all related health records and goals
    /// - Parameter user: The User to delete
    /// - Throws: HealthAppError if delete operation fails
    func delete(_ user: User) async throws
}