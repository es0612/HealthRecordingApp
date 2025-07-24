import Foundation

/// Repository protocol for Goal data access operations
/// Provides abstraction layer between Use Cases and Infrastructure
protocol GoalRepositoryProtocol {
    
    /// Save a goal to persistent storage
    /// - Parameter goal: The Goal to save
    /// - Throws: HealthAppError if save operation fails
    func save(_ goal: Goal) async throws
    
    /// Fetch goals for a specific user
    /// - Parameters:
    ///   - user: The User to fetch goals for
    ///   - activeOnly: If true, only fetch active goals. If false, fetch all goals
    /// - Returns: Array of goals for the user
    /// - Throws: HealthAppError if fetch operation fails
    func fetchGoals(for user: User, activeOnly: Bool) async throws -> [Goal]
    
    /// Fetch a specific goal by ID
    /// - Parameter id: The Goal ID to fetch
    /// - Returns: The Goal if found, nil otherwise
    /// - Throws: HealthAppError if fetch operation fails
    func fetchGoal(byId id: UUID) async throws -> Goal?
    
    /// Fetch goals by type
    /// - Parameters:
    ///   - type: The HealthDataType to filter by
    ///   - user: The User to fetch goals for
    /// - Returns: Array of goals matching the type and user
    /// - Throws: HealthAppError if fetch operation fails
    func fetchGoals(byType type: HealthDataType, for user: User) async throws -> [Goal]
    
    /// Fetch completed goals for a user
    /// - Parameter user: The User to fetch completed goals for
    /// - Returns: Array of completed goals for the user
    /// - Throws: HealthAppError if fetch operation fails
    func fetchCompletedGoals(for user: User) async throws -> [Goal]
    
    /// Fetch expired goals for a user
    /// - Parameter user: The User to fetch expired goals for
    /// - Returns: Array of expired goals for the user
    /// - Throws: HealthAppError if fetch operation fails
    func fetchExpiredGoals(for user: User) async throws -> [Goal]
    
    /// Delete a goal from persistent storage
    /// - Parameter goal: The Goal to delete
    /// - Throws: HealthAppError if delete operation fails
    func delete(_ goal: Goal) async throws
    
    /// Update goal progress based on current value
    /// - Parameter goal: The Goal to update progress for
    /// - Throws: HealthAppError if update operation fails
    func updateProgress(_ goal: Goal) async throws
}