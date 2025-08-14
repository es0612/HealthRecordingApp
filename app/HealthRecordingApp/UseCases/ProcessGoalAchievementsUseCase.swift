import Foundation
import SwiftData

/// 目標達成処理Use Case
/// 目標達成・マイルストーン・ストリークの検出と通知を統合管理
public final class ProcessGoalAchievementsUseCase {
    
    // MARK: - Dependencies
    
    private let goalRepository: GoalRepositoryProtocol
    private let healthRecordRepository: HealthRecordRepositoryProtocol
    private let goalAchievementService: GoalAchievementNotificationService
    private let logger: AILoggerProtocol
    
    // MARK: - Configuration
    
    /// 目標チェックの遡及日数
    private let lookbackDays: Int = 30
    
    /// 最小処理間隔（秒）- 頻繁な呼び出しを防ぐ
    private let minimumProcessingInterval: TimeInterval = 300 // 5分
    
    /// 最後の処理時刻
    private var lastProcessingTime: Date?
    
    // MARK: - Initialization
    
    public init(
        goalRepository: GoalRepositoryProtocol,
        healthRecordRepository: HealthRecordRepositoryProtocol,
        goalAchievementService: GoalAchievementNotificationService,
        logger: AILoggerProtocol
    ) {
        self.goalRepository = goalRepository
        self.healthRecordRepository = healthRecordRepository
        self.goalAchievementService = goalAchievementService
        self.logger = logger
    }
    
    // MARK: - Primary Use Case Methods
    
    /// 全ての目標の達成状況をチェックし通知を送信
    public func execute() async throws {
        logger.info("目標達成処理Use Case実行開始", context: nil)
        
        // 処理間隔チェック
        if let lastTime = lastProcessingTime,
           Date().timeIntervalSince(lastTime) < minimumProcessingInterval {
            logger.debug("処理間隔が短いためスキップ", context: [
                "lastProcessingTime": lastTime.description,
                "minimumInterval": minimumProcessingInterval
            ])
            return
        }
        
        let startTime = Date()
        
        do {
            // アクティブな目標を取得
            let activeGoals = try await goalRepository.fetchActiveGoals()
            
            if activeGoals.isEmpty {
                logger.info("アクティブな目標がありません", context: nil)
                lastProcessingTime = Date()
                return
            }
            
            // 関連する健康レコードを取得
            let recentRecords = try await fetchRecentHealthRecords(for: activeGoals)
            
            // 目標達成処理を実行
            try await goalAchievementService.processGoalAchievements(
                goals: activeGoals,
                recentRecords: recentRecords
            )
            
            // 期限切迫アラートをチェック
            try await goalAchievementService.sendGoalDeadlineAlerts(for: activeGoals)
            
            // 古い処理済み記録をクリーンアップ
            await goalAchievementService.cleanupProcessedMilestones()
            
            let processingTime = Date().timeIntervalSince(startTime)
            logger.info("目標達成処理Use Case実行完了", context: [
                "processingTime": processingTime,
                "goalCount": activeGoals.count,
                "recordCount": recentRecords.count
            ])
            
            lastProcessingTime = Date()
            
        } catch {
            logger.error(error, context: ["operation": "ProcessGoalAchievementsUseCase.execute"])
            throw GoalAchievementError.processingFailed(error)
        }
    }
    
    /// 特定の目標の達成状況をチェック
    public func executeForGoal(_ goalId: UUID) async throws {
        logger.info("個別目標達成チェック", context: ["goalId": goalId.uuidString])
        
        do {
            // 特定の目標を取得
            guard let goal = try await goalRepository.fetchGoal(byId: goalId),
                  goal.isActive else {
                logger.warning("目標が見つからないか非アクティブ", context: ["goalId": goalId.uuidString])
                return
            }
            
            // 関連する健康レコードを取得
            let recentRecords = try await fetchRecentHealthRecords(for: [goal])
            
            // 目標達成処理を実行
            try await goalAchievementService.processGoalAchievements(
                goals: [goal],
                recentRecords: recentRecords
            )
            
            logger.info("個別目標達成チェック完了", context: ["goalId": goalId.uuidString])
            
        } catch {
            logger.error(error, context: [
                "operation": "ProcessGoalAchievementsUseCase.executeForGoal",
                "goalId": goalId.uuidString
            ])
            throw GoalAchievementError.goalProcessingFailed(goalId, error)
        }
    }
    
    /// データ入力時の即座チェック（新しいレコード追加時）
    public func executeForNewRecord(_ record: HealthRecord) async throws {
        logger.info("新規レコード対応目標チェック", context: [
            "recordId": record.id.uuidString,
            "dataType": record.type.rawValue
        ])
        
        do {
            // 該当データタイプの目標を取得  
            let allActiveGoals = try await goalRepository.fetchActiveGoals()
            let relatedGoals = allActiveGoals.filter { $0.type == record.type }
            
            if relatedGoals.isEmpty {
                logger.debug("該当する目標がありません", context: ["dataType": record.type.rawValue])
                return
            }
            
            // 最近のレコード（新しいレコード含む）を取得
            let recentRecords = try await fetchRecentHealthRecords(for: relatedGoals)
            
            // 目標達成処理を実行
            try await goalAchievementService.processGoalAchievements(
                goals: relatedGoals,
                recentRecords: recentRecords
            )
            
            logger.info("新規レコード対応チェック完了", context: [
                "recordId": record.id.uuidString,
                "affectedGoals": relatedGoals.count
            ])
            
        } catch {
            logger.error(error, context: [
                "operation": "ProcessGoalAchievementsUseCase.executeForNewRecord",
                "recordId": record.id.uuidString
            ])
            throw GoalAchievementError.recordProcessingFailed(record.id, error)
        }
    }
    
    /// バックグラウンドでの定期チェック実行
    public func executeBackgroundCheck() async throws {
        logger.info("バックグラウンド目標チェック開始", context: nil)
        
        // バックグラウンドでは軽量な処理のみ実行
        // 期限切迫アラートと重要なマイルストーンのみチェック
        
        do {
            let activeGoals = try await goalRepository.fetchActiveGoals()
            
            // 期限切迫アラートのみ送信（通常の達成処理はスキップ）
            try await goalAchievementService.sendGoalDeadlineAlerts(for: activeGoals)
            
            logger.info("バックグラウンドチェック完了", context: [
                "goalCount": activeGoals.count
            ])
            
        } catch {
            logger.error(error, context: ["operation": "executeBackgroundCheck"])
            // バックグラウンドエラーは重大でない限りthrowしない
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// 目標に関連する最近の健康レコードを取得
    private func fetchRecentHealthRecords(for goals: [Goal]) async throws -> [HealthRecord] {
        let dataTypes = Set(goals.map { $0.type })
        let startDate = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: Date()) ?? Date()
        
        var allRecords: [HealthRecord] = []
        
        for dataType in dataTypes {
            // Get all users who have goals for this data type
            let goalsForType = goals.filter { $0.type == dataType }
            for goal in goalsForType {
                if let user = goal.user {
                    let records = try await healthRecordRepository.fetchRecords(
                        for: user,
                        type: dataType,
                        from: startDate,
                        to: Date()
                    )
                    allRecords.append(contentsOf: records)
                }
            }
        }
        
        logger.debug("健康レコード取得", context: [
            "dataTypes": dataTypes.map { $0.rawValue }.joined(separator: ", "),
            "recordCount": allRecords.count,
            "lookbackDays": lookbackDays
        ])
        
        return allRecords
    }
}

// MARK: - Automatic Scheduling

/// 目標達成チェックの自動スケジューラー
public final class GoalAchievementScheduler {
    
    private let useCase: ProcessGoalAchievementsUseCase
    private let logger: AILoggerProtocol
    
    /// チェック間隔（秒）
    private let checkInterval: TimeInterval = 3600 // 1時間
    
    /// スケジュール実行中フラグ
    private var isScheduled: Bool = false
    
    public init(
        useCase: ProcessGoalAchievementsUseCase,
        logger: AILoggerProtocol
    ) {
        self.useCase = useCase
        self.logger = logger
    }
    
    /// 定期的な目標チェックを開始
    public func startPeriodicChecking() {
        guard !isScheduled else {
            logger.warning("目標チェックは既にスケジュール済み", context: nil)
            return
        }
        
        isScheduled = true
        logger.info("定期目標チェック開始", context: ["interval": checkInterval])
        
        Task {
            while isScheduled {
                do {
                    try await useCase.execute()
                } catch {
                    logger.error(error, context: ["operation": "periodicCheck"])
                }
                
                // 次のチェックまで待機
                try await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
            }
        }
    }
    
    /// 定期チェックを停止
    public func stopPeriodicChecking() {
        isScheduled = false
        logger.info("定期目標チェック停止", context: nil)
    }
}

// MARK: - Error Types

public enum GoalAchievementError: Error, LocalizedError {
    case processingFailed(Error)
    case goalProcessingFailed(UUID, Error)
    case recordProcessingFailed(UUID, Error)
    case invalidGoal(UUID)
    case noActiveGoals
    
    public var errorDescription: String? {
        switch self {
        case .processingFailed(let error):
            return "目標達成処理中にエラーが発生しました: \\(error.localizedDescription)"
        case .goalProcessingFailed(let goalId, let error):
            return "目標\\(goalId)の処理中にエラーが発生しました: \\(error.localizedDescription)"
        case .recordProcessingFailed(let recordId, let error):
            return "レコード\\(recordId)の処理中にエラーが発生しました: \\(error.localizedDescription)"
        case .invalidGoal(let goalId):
            return "無効な目標です: \\(goalId)"
        case .noActiveGoals:
            return "アクティブな目標がありません"
        }
    }
}

// MARK: - Repository Protocol Extensions

extension GoalRepositoryProtocol {
    /// データタイプ別のアクティブ目標取得（デフォルト実装）
    func fetchActiveGoals(for dataType: HealthDataType, user: User) async throws -> [Goal] {
        let allActiveGoals = try await fetchGoals(for: user, activeOnly: true)
        return allActiveGoals.filter { $0.type == dataType }
    }
}

// MARK: - Integration Helpers

/// 目標達成処理の統合ヘルパー
public struct GoalAchievementIntegrationHelper {
    
    /// アプリ起動時の初期化
    public static func initializeOnAppLaunch(
        dependencies: GoalAchievementDependencies
    ) async throws {
        let useCase = ProcessGoalAchievementsUseCase(
            goalRepository: dependencies.goalRepository,
            healthRecordRepository: dependencies.healthRecordRepository,
            goalAchievementService: dependencies.goalAchievementService,
            logger: dependencies.logger
        )
        
        // 初回チェック実行
        try await useCase.execute()
        
        // 定期チェック開始
        let scheduler = GoalAchievementScheduler(useCase: useCase, logger: dependencies.logger)
        scheduler.startPeriodicChecking()
    }
    
    /// データ入力後の即座チェック
    public static func processNewRecord(
        _ record: HealthRecord,
        using dependencies: GoalAchievementDependencies
    ) async throws {
        let useCase = ProcessGoalAchievementsUseCase(
            goalRepository: dependencies.goalRepository,
            healthRecordRepository: dependencies.healthRecordRepository,
            goalAchievementService: dependencies.goalAchievementService,
            logger: dependencies.logger
        )
        
        try await useCase.executeForNewRecord(record)
    }
}

/// 依存関係をまとめる構造体
public struct GoalAchievementDependencies {
    let goalRepository: GoalRepositoryProtocol
    let healthRecordRepository: HealthRecordRepositoryProtocol
    let goalAchievementService: GoalAchievementNotificationService
    let logger: AILoggerProtocol
}