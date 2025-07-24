# 設計文書

## 概要

ヘルスレコーディングアプリは、iOS 18.5をターゲットとしたSwiftUIネイティブアプリとして設計されます。クリーンアーキテクチャの原則に基づき、@Observable、SwiftData、SwiftTestingなどのモダンなiOS開発技術を活用します。TDD（テスト駆動開発）とDDD（ドメイン駆動設計）のアプローチを採用し、保守性と拡張性を重視した設計とします。

## アーキテクチャ

### クリーンアーキテクチャ概要

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                       │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │   SwiftUI Views │    │   @Observable   │                │
│  │                 │◄──►│   ViewModels    │                │
│  │ - DashboardView │    │ - HealthVM      │                │
│  │ - ChartsView    │    │ - TrendsVM      │                │
│  │ - SettingsView  │    │ - GoalsVM       │                │
│  └─────────────────┘    └─────────────────┘                │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                        │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │   Use Cases     │    │   App Services  │                │
│  │                 │◄──►│                 │                │
│  │ - RecordHealth  │    │ - Notification  │                │
│  │ - AnalyzeTrends │    │ - SocialShare   │                │
│  │ - ManageGoals   │    │ - Animation     │                │
│  └─────────────────┘    └─────────────────┘                │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                     Domain Layer                            │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │   Domain Models │    │   Domain        │                │
│  │                 │◄──►│   Services      │                │
│  │ - HealthRecord  │    │ - TrendAnalyzer │                │
│  │ - User          │    │ - GoalTracker   │                │
│  │ - Goal          │    │ - InsightEngine │                │
│  └─────────────────┘    └─────────────────┘                │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                  Infrastructure Layer                       │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │   Data Sources  │    │   External APIs │                │
│  │                 │◄──►│                 │                │
│  │ - SwiftData     │    │ - HealthKit     │                │
│  │ - CloudKit      │    │ - Social APIs   │                │
│  │ - Keychain      │    │ - Notification  │                │
│  └─────────────────┘    └─────────────────┘                │
└─────────────────────────────────────────────────────────────┘
```

### レイヤー詳細

#### 1. Presentation Layer
- **SwiftUI Views**: 宣言的UI、@Observable対応
- **ViewModels**: @Observable マクロによる状態管理
- **Navigation**: SwiftUI NavigationStack使用

#### 2. Application Layer  
- **Use Cases**: ビジネスロジックの具体的な実装
- **App Services**: アプリケーション横断的な機能

#### 3. Domain Layer
- **Domain Models**: ビジネスルールを含むエンティティ
- **Domain Services**: ドメイン固有のビジネスロジック
- **Repository Protocols**: データアクセスの抽象化

#### 4. Infrastructure Layer
- **SwiftData**: iOS 17+の新しいデータ永続化フレームワーク
- **HealthKit**: 健康データアクセス
- **CloudKit**: クラウド同期

## コンポーネントと インターフェース

### ドメインモデル（SwiftData）

#### HealthRecord
```swift
import SwiftData
import Foundation

@Model
final class HealthRecord {
    var id: UUID
    var type: HealthDataType
    var value: Double
    var unit: String
    var timestamp: Date
    var source: DataSource
    
    // Relationships
    var user: User?
    
    init(type: HealthDataType, value: Double, unit: String, source: DataSource = .healthKit) {
        self.id = UUID()
        self.type = type
        self.value = value
        self.unit = unit
        self.timestamp = Date()
        self.source = source
    }
}

enum HealthDataType: String, CaseIterable, Codable {
    case weight = "weight"
    case steps = "steps"
    case calories = "calories"
    case heartRate = "heartRate"
}

enum DataSource: String, Codable {
    case healthKit = "healthKit"
    case manual = "manual"
}
```

#### User
```swift
@Model
final class User {
    var id: UUID
    var name: String
    var age: Int
    var height: Double
    var targetWeight: Double
    var createdAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade) var healthRecords: [HealthRecord] = []
    @Relationship(deleteRule: .cascade) var goals: [Goal] = []
    
    init(name: String, age: Int, height: Double, targetWeight: Double) {
        self.id = UUID()
        self.name = name
        self.age = age
        self.height = height
        self.targetWeight = targetWeight
        self.createdAt = Date()
    }
}
```

#### Goal
```swift
@Model
final class Goal {
    var id: UUID
    var type: HealthDataType
    var targetValue: Double
    var currentValue: Double
    var deadline: Date
    var isActive: Bool
    var createdAt: Date
    
    // Relationships
    var user: User?
    
    init(type: HealthDataType, targetValue: Double, deadline: Date) {
        self.id = UUID()
        self.type = type
        self.targetValue = targetValue
        self.currentValue = 0.0
        self.deadline = deadline
        self.isActive = true
        self.createdAt = Date()
    }
}
```

#### Badge（ゲーミフィケーション）
```swift
@Model
final class Badge {
    var id: UUID
    var name: String
    var description: String
    var type: BadgeType
    var requirement: BadgeRequirement
    var isEarned: Bool
    var earnedDate: Date?
    var iconName: String
    var colorScheme: BadgeColorScheme
    
    // Relationships
    var user: User?
    
    init(name: String, description: String, type: BadgeType, requirement: BadgeRequirement, iconName: String, colorScheme: BadgeColorScheme) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.type = type
        self.requirement = requirement
        self.isEarned = false
        self.earnedDate = nil
        self.iconName = iconName
        self.colorScheme = colorScheme
    }
}

enum BadgeType: String, CaseIterable, Codable {
    case streak = "継続"
    case milestone = "マイルストーン"
    case achievement = "達成"
    case special = "特別"
}

struct BadgeRequirement: Codable {
    let type: RequirementType
    let value: Double
    let duration: Int? // 日数
    
    enum RequirementType: String, Codable {
        case consecutiveDays = "連続日数"
        case totalRecords = "総記録数"
        case goalAchievement = "目標達成"
        case weightLoss = "体重減少"
        case stepsTotal = "歩数合計"
    }
}

struct BadgeColorScheme: Codable {
    let primary: String // Hex color
    let secondary: String
    let accent: String
    
    static let bronze = BadgeColorScheme(primary: "#CD7F32", secondary: "#8B4513", accent: "#FFD700")
    static let silver = BadgeColorScheme(primary: "#C0C0C0", secondary: "#808080", accent: "#FFFFFF")
    static let gold = BadgeColorScheme(primary: "#FFD700", secondary: "#FFA500", accent: "#FFFF00")
    static let platinum = BadgeColorScheme(primary: "#E5E4E2", secondary: "#BCC6CC", accent: "#FFFFFF")
}
```

### Repository Protocols（Domain Layer）

#### HealthRecordRepository
```swift
protocol HealthRecordRepositoryProtocol {
    func save(_ record: HealthRecord) async throws
    func fetchRecords(for user: User, type: HealthDataType?, from startDate: Date?, to endDate: Date?) async throws -> [HealthRecord]
    func delete(_ record: HealthRecord) async throws
    func syncWithHealthKit() async throws
}
```

#### UserRepository
```swift
protocol UserRepositoryProtocol {
    func save(_ user: User) async throws
    func fetchCurrentUser() async throws -> User?
    func delete(_ user: User) async throws
}
```

### Use Cases（Application Layer）

#### RecordHealthDataUseCase
```swift
struct RecordHealthDataUseCase {
    private let healthRecordRepository: HealthRecordRepositoryProtocol
    private let healthKitService: HealthKitServiceProtocol
    
    func execute(for user: User) async throws {
        let healthKitData = try await healthKitService.fetchLatestData()
        
        for data in healthKitData {
            let record = HealthRecord(
                type: data.type,
                value: data.value,
                unit: data.unit,
                source: .healthKit
            )
            record.user = user
            try await healthRecordRepository.save(record)
        }
    }
}
```

### Infrastructure Services

#### HealthKitService
```swift
import HealthKit

protocol HealthKitServiceProtocol {
    func requestAuthorization() async throws
    func fetchLatestData() async throws -> [HealthKitData]
    func observeHealthData(handler: @escaping ([HealthKitData]) -> Void)
}

struct HealthKitData {
    let type: HealthDataType
    let value: Double
    let unit: String
    let timestamp: Date
}

final class HealthKitService: HealthKitServiceProtocol {
    private let healthStore = HKHealthStore()
    
    func requestAuthorization() async throws {
        let typesToRead: Set<HKQuantityType> = [
            HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
    }
    
    func fetchLatestData() async throws -> [HealthKitData] {
        // HealthKit データ取得実装
        []
    }
    
    func observeHealthData(handler: @escaping ([HealthKitData]) -> Void) {
        // HealthKit データ監視実装
    }
}
```

### Presentation Layer（@Observable ViewModels）

#### HealthDataViewModel
```swift
import SwiftUI
import SwiftData

@Observable
final class HealthDataViewModel {
    var healthRecords: [HealthRecord] = []
    var isLoading = false
    var errorMessage: String?
    
    private let recordHealthDataUseCase: RecordHealthDataUseCase
    private let fetchHealthDataUseCase: FetchHealthDataUseCase
    
    init(recordHealthDataUseCase: RecordHealthDataUseCase, fetchHealthDataUseCase: FetchHealthDataUseCase) {
        self.recordHealthDataUseCase = recordHealthDataUseCase
        self.fetchHealthDataUseCase = fetchHealthDataUseCase
    }
    
    @MainActor
    func loadHealthData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            healthRecords = try await fetchHealthDataUseCase.execute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    func syncWithHealthKit() async {
        do {
            try await recordHealthDataUseCase.execute()
            await loadHealthData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

#### TrendsViewModel
```swift
@Observable
final class TrendsViewModel {
    var trendData: [TrendPoint] = []
    var selectedTimeRange: TimeRange = .month
    var insights: [HealthInsight] = []
    
    private let analyzeTrendsUseCase: AnalyzeTrendsUseCase
    
    func updateTrends() async {
        do {
            let analysis = try await analyzeTrendsUseCase.execute(timeRange: selectedTimeRange)
            trendData = analysis.trendPoints
            insights = analysis.insights
        } catch {
            // エラーハンドリング
        }
    }
}

enum TimeRange: String, CaseIterable {
    case week = "週"
    case month = "月"
    case year = "年"
}
```

### Domain Services

#### TrendAnalyzer
```swift
struct TrendAnalyzer {
    func analyzeTrends(from records: [HealthRecord], timeRange: TimeRange) -> TrendAnalysis {
        let filteredRecords = filterRecords(records, for: timeRange)
        let trendPoints = calculateTrendPoints(from: filteredRecords)
        let insights = generateInsights(from: filteredRecords)
        
        return TrendAnalysis(trendPoints: trendPoints, insights: insights)
    }
    
    private func calculateTrendPoints(from records: [HealthRecord]) -> [TrendPoint] {
        // 移動平均、傾向分析の実装
        []
    }
    
    private func generateInsights(from records: [HealthRecord]) -> [HealthInsight] {
        // インサイト生成ロジック
        []
    }
}

struct TrendAnalysis {
    let trendPoints: [TrendPoint]
    let insights: [HealthInsight]
}

struct TrendPoint {
    let date: Date
    let value: Double
    let movingAverage: Double
}

struct HealthInsight {
    let title: String
    let description: String
    let type: InsightType
    let confidence: Double
}

enum InsightType {
    case positive, neutral, warning
}
```

### ゲーミフィケーション機能

#### BadgeService
```swift
protocol BadgeServiceProtocol {
    func checkAndAwardBadges(for user: User) async throws -> [Badge]
    func generateBadgeView(for badge: Badge) -> AnyView
    func createDefaultBadges() -> [Badge]
}

final class BadgeService: BadgeServiceProtocol {
    private let badgeRepository: BadgeRepositoryProtocol
    private let healthRecordRepository: HealthRecordRepositoryProtocol
    
    init(badgeRepository: BadgeRepositoryProtocol, healthRecordRepository: HealthRecordRepositoryProtocol) {
        self.badgeRepository = badgeRepository
        self.healthRecordRepository = healthRecordRepository
    }
    
    func checkAndAwardBadges(for user: User) async throws -> [Badge] {
        let userBadges = try await badgeRepository.fetchBadges(for: user)
        let unearnedBadges = userBadges.filter { !$0.isEarned }
        var newlyEarnedBadges: [Badge] = []
        
        for badge in unearnedBadges {
            if try await checkBadgeRequirement(badge, for: user) {
                badge.isEarned = true
                badge.earnedDate = Date()
                try await badgeRepository.save(badge)
                newlyEarnedBadges.append(badge)
            }
        }
        
        return newlyEarnedBadges
    }
    
    private func checkBadgeRequirement(_ badge: Badge, for user: User) async throws -> Bool {
        switch badge.requirement.type {
        case .consecutiveDays:
            return try await checkConsecutiveDays(badge.requirement.value, for: user)
        case .totalRecords:
            return try await checkTotalRecords(badge.requirement.value, for: user)
        case .goalAchievement:
            return try await checkGoalAchievement(for: user)
        case .weightLoss:
            return try await checkWeightLoss(badge.requirement.value, for: user)
        case .stepsTotal:
            return try await checkStepsTotal(badge.requirement.value, for: user)
        }
    }
    
    func generateBadgeView(for badge: Badge) -> AnyView {
        AnyView(
            BadgeView(
                badge: badge,
                colorScheme: badge.colorScheme,
                isEarned: badge.isEarned
            )
        )
    }
    
    func createDefaultBadges() -> [Badge] {
        return [
            Badge(
                name: "はじめの一歩",
                description: "初回記録を達成",
                type: .milestone,
                requirement: BadgeRequirement(type: .totalRecords, value: 1, duration: nil),
                iconName: "star.fill",
                colorScheme: .bronze
            ),
            Badge(
                name: "継続は力なり",
                description: "7日連続記録を達成",
                type: .streak,
                requirement: BadgeRequirement(type: .consecutiveDays, value: 7, duration: 7),
                iconName: "flame.fill",
                colorScheme: .silver
            ),
            Badge(
                name: "健康マスター",
                description: "30日連続記録を達成",
                type: .streak,
                requirement: BadgeRequirement(type: .consecutiveDays, value: 30, duration: 30),
                iconName: "crown.fill",
                colorScheme: .gold
            )
        ]
    }
}
```

#### BadgeView（SwiftUI描画）
```swift
import SwiftUI

struct BadgeView: View {
    let badge: Badge
    let colorScheme: BadgeColorScheme
    let isEarned: Bool
    
    var body: some View {
        ZStack {
            // 背景円
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: colorScheme.primary),
                            Color(hex: colorScheme.secondary)
                        ],
                        center: .topLeading,
                        startRadius: 5,
                        endRadius: 50
                    )
                )
                .frame(width: 80, height: 80)
                .opacity(isEarned ? 1.0 : 0.3)
            
            // 装飾リング
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: colorScheme.accent),
                            Color(hex: colorScheme.primary)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: 85, height: 85)
                .opacity(isEarned ? 1.0 : 0.2)
            
            // アイコン
            Image(systemName: badge.iconName)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(Color(hex: colorScheme.accent))
                .opacity(isEarned ? 1.0 : 0.4)
            
            // 未獲得時のロックアイコン
            if !isEarned {
                Image(systemName: "lock.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
                    .offset(x: 25, y: 25)
            }
        }
        .scaleEffect(isEarned ? 1.0 : 0.8)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isEarned)
    }
}

// Color extension for hex support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
```

### AI連携対応ロギング機能

#### AILogger
```swift
import Foundation
import os.log

protocol AILoggerProtocol {
    func debug(_ message: String, context: [String: Any]?)
    func info(_ message: String, context: [String: Any]?)
    func warning(_ message: String, context: [String: Any]?)
    func error(_ error: Error, context: [String: Any]?)
    func logUserAction(_ action: String, parameters: [String: Any]?)
    func logPerformance(_ operation: String, duration: TimeInterval, success: Bool)
}

final class AILogger: AILoggerProtocol {
    private let logger = Logger(subsystem: "com.asapapalab.HealthRecordingApp", category: "AILogger")
    private let logLevel: LogLevel
    private let isProduction: Bool
    
    enum LogLevel: Int, CaseIterable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        
        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            }
        }
    }
    
    init(logLevel: LogLevel = .info, isProduction: Bool = false) {
        self.logLevel = logLevel
        self.isProduction = isProduction
    }
    
    func debug(_ message: String, context: [String: Any]? = nil) {
        log(level: .debug, message: message, context: context)
    }
    
    func info(_ message: String, context: [String: Any]? = nil) {
        log(level: .info, message: message, context: context)
    }
    
    func warning(_ message: String, context: [String: Any]? = nil) {
        log(level: .warning, message: message, context: context)
    }
    
    func error(_ error: Error, context: [String: Any]? = nil) {
        var errorContext = context ?? [:]
        errorContext["error_type"] = String(describing: type(of: error))
        errorContext["error_description"] = error.localizedDescription
        
        if let healthAppError = error as? HealthAppError {
            errorContext["app_error_type"] = String(describing: healthAppError)
        }
        
        log(level: .error, message: "Error occurred", context: errorContext)
    }
    
    func logUserAction(_ action: String, parameters: [String: Any]? = nil) {
        var context = parameters ?? [:]
        context["action_type"] = "user_interaction"
        context["timestamp"] = ISO8601DateFormatter().string(from: Date())
        
        info("User action: \(action)", context: context)
    }
    
    func logPerformance(_ operation: String, duration: TimeInterval, success: Bool) {
        let context: [String: Any] = [
            "operation": operation,
            "duration_ms": Int(duration * 1000),
            "success": success,
            "performance_category": categorizePerformance(duration)
        ]
        
        let message = "Performance: \(operation) (\(Int(duration * 1000))ms)"
        
        if success {
            info(message, context: context)
        } else {
            warning("\(message) - FAILED", context: context)
        }
    }
    
    private func log(level: LogLevel, message: String, context: [String: Any]?) {
        guard level.rawValue >= logLevel.rawValue else { return }
        
        let logEntry = createLogEntry(level: level, message: message, context: context)
        
        // Console logging
        logger.log(level: osLogLevel(for: level), "\(logEntry.consoleMessage)")
        
        // Structured logging for AI analysis
        if !isProduction || level.rawValue >= LogLevel.warning.rawValue {
            logStructuredEntry(logEntry)
        }
    }
    
    private func createLogEntry(level: LogLevel, message: String, context: [String: Any]?) -> LogEntry {
        var sanitizedContext = context ?? [:]
        
        // Remove PII in production
        if isProduction {
            sanitizedContext = sanitizeContext(sanitizedContext)
        }
        
        return LogEntry(
            timestamp: Date(),
            level: level,
            message: message,
            context: sanitizedContext,
            thread: Thread.current.name ?? "unknown",
            file: #file,
            function: #function,
            line: #line
        )
    }
    
    private func sanitizeContext(_ context: [String: Any]) -> [String: Any] {
        var sanitized = context
        
        // Remove potential PII
        let piiKeys = ["name", "email", "phone", "address", "user_id"]
        for key in piiKeys {
            if sanitized[key] != nil {
                sanitized[key] = "[REDACTED]"
            }
        }
        
        return sanitized
    }
    
    private func logStructuredEntry(_ entry: LogEntry) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: entry.toDictionary(), options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("AI_LOG: \(jsonString)")
            }
        } catch {
            logger.error("Failed to serialize log entry: \(error.localizedDescription)")
        }
    }
    
    private func osLogLevel(for level: LogLevel) -> OSLogType {
        switch level {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }
    
    private func categorizePerformance(_ duration: TimeInterval) -> String {
        switch duration {
        case 0..<0.1: return "excellent"
        case 0.1..<0.5: return "good"
        case 0.5..<1.0: return "acceptable"
        case 1.0..<3.0: return "slow"
        default: return "very_slow"
        }
    }
}

struct LogEntry {
    let timestamp: Date
    let level: AILogger.LogLevel
    let message: String
    let context: [String: Any]
    let thread: String
    let file: String
    let function: String
    let line: Int
    
    var consoleMessage: String {
        let timeString = ISO8601DateFormatter().string(from: timestamp)
        let fileName = (file as NSString).lastPathComponent
        return "\(level.emoji) [\(timeString)] \(fileName):\(line) \(function) - \(message)"
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "timestamp": ISO8601DateFormatter().string(from: timestamp),
            "level": String(describing: level),
            "message": message,
            "context": context,
            "thread": thread,
            "source": [
                "file": (file as NSString).lastPathComponent,
                "function": function,
                "line": line
            ]
        ]
    }
}

// Usage example in Use Cases
extension RecordHealthDataUseCase {
    func execute(for user: User) async throws {
        let startTime = Date()
        let logger = AILogger()
        
        logger.logUserAction("sync_health_data", parameters: ["user_id": user.id.uuidString])
        
        do {
            let healthKitData = try await healthKitService.fetchLatestData()
            logger.info("Fetched \(healthKitData.count) health records from HealthKit")
            
            for data in healthKitData {
                let record = HealthRecord(
                    type: data.type,
                    value: data.value,
                    unit: data.unit,
                    source: .healthKit
                )
                record.user = user
                try await healthRecordRepository.save(record)
            }
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("sync_health_data", duration: duration, success: true)
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("sync_health_data", duration: duration, success: false)
            logger.error(error, context: ["user_id": user.id.uuidString])
            throw error
        }
    }
}
```

### App Services

#### NotificationService
```swift
import UserNotifications

protocol NotificationServiceProtocol {
    func requestPermission() async throws
    func scheduleReminder(at time: Date, message: String) async throws
    func sendAchievementNotification(for achievement: Achievement) async throws
}

final class NotificationService: NotificationServiceProtocol {
    func requestPermission() async throws {
        let center = UNUserNotificationCenter.current()
        try await center.requestAuthorization(options: [.alert, .badge, .sound])
    }
    
    func scheduleReminder(at time: Date, message: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = "健康記録のリマインダー"
        content.body = message
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: time.timeIntervalSinceNow, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        try await UNUserNotificationCenter.current().add(request)
    }
    
    func sendAchievementNotification(for achievement: Achievement) async throws {
        // 達成通知の実装
    }
}
```

#### SocialShareService
```swift
import UIKit
import Social

protocol SocialShareServiceProtocol {
    func generateShareImage(from data: ShareData) async -> UIImage
    func shareContent(_ content: ShareContent) async throws
}

final class SocialShareService: SocialShareServiceProtocol {
    func generateShareImage(from data: ShareData) async -> UIImage {
        // SwiftUIビューから画像生成
        await MainActor.run {
            let renderer = ImageRenderer(content: ShareImageView(data: data))
            return renderer.uiImage ?? UIImage()
        }
    }
    
    func shareContent(_ content: ShareContent) async throws {
        await MainActor.run {
            let activityVC = UIActivityViewController(
                activityItems: [content.image, content.text],
                applicationActivities: nil
            )
            
            // 現在のViewControllerから表示
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        }
    }
}

struct ShareData {
    let healthRecords: [HealthRecord]
    let achievements: [Achievement]
    let timeRange: TimeRange
}

struct ShareContent {
    let image: UIImage
    let text: String
}
```

## SwiftData設定

### ModelContainer設定
```swift
import SwiftData

extension HealthRecordingAppApp {
    var sharedModelContainer: ModelContainer {
        let schema = Schema([
            HealthRecord.self,
            User.self,
            Goal.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.asapapalab.HealthRecordingApp")
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
```

### Repository実装（Infrastructure Layer）

#### SwiftDataHealthRecordRepository
```swift
import SwiftData
import Foundation

final class SwiftDataHealthRecordRepository: HealthRecordRepositoryProtocol {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func save(_ record: HealthRecord) async throws {
        modelContext.insert(record)
        try modelContext.save()
    }
    
    func fetchRecords(for user: User, type: HealthDataType?, from startDate: Date?, to endDate: Date?) async throws -> [HealthRecord] {
        var predicate = #Predicate<HealthRecord> { record in
            record.user?.id == user.id
        }
        
        if let type = type {
            predicate = #Predicate<HealthRecord> { record in
                record.user?.id == user.id && record.type == type
            }
        }
        
        if let startDate = startDate, let endDate = endDate {
            predicate = #Predicate<HealthRecord> { record in
                record.user?.id == user.id && 
                record.timestamp >= startDate && 
                record.timestamp <= endDate
            }
        }
        
        let descriptor = FetchDescriptor<HealthRecord>(predicate: predicate)
        return try modelContext.fetch(descriptor)
    }
    
    func delete(_ record: HealthRecord) async throws {
        modelContext.delete(record)
        try modelContext.save()
    }
    
    func syncWithHealthKit() async throws {
        // CloudKit同期は自動的に処理される
    }
}
```

## エラーハンドリング

### エラー型定義
```swift
enum HealthAppError: LocalizedError {
    case healthKitNotAvailable
    case healthKitAuthorizationDenied
    case dataFetchFailed(underlying: Error)
    case dataSaveFailed(underlying: Error)
    case networkError(underlying: Error)
    case invalidData(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .healthKitNotAvailable:
            return "HealthKitが利用できません"
        case .healthKitAuthorizationDenied:
            return "HealthKitへのアクセスが拒否されました"
        case .dataFetchFailed(let error):
            return "データの取得に失敗しました: \(error.localizedDescription)"
        case .dataSaveFailed(let error):
            return "データの保存に失敗しました: \(error.localizedDescription)"
        case .networkError(let error):
            return "ネットワークエラー: \(error.localizedDescription)"
        case .invalidData(let reason):
            return "無効なデータ: \(reason)"
        }
    }
}
```

### エラーハンドリング戦略
1. **HealthKitエラー**: フォールバック機能（手動入力）を提供
2. **ネットワークエラー**: オフライン機能とリトライ機能
3. **データエラー**: ユーザーフレンドリーなエラーメッセージ表示
4. **クラッシュ防止**: 防御的プログラミングとログ記録

## テスト戦略（SwiftTesting使用）

### テストピラミッド

#### 1. Unit Tests (70%) - SwiftTesting
```swift
import Testing
import SwiftData

@Test("TrendAnalyzer should calculate correct moving average")
func testTrendAnalyzerMovingAverage() async throws {
    // Given
    let analyzer = TrendAnalyzer()
    let records = TestHealthData.sampleWeightData
    
    // When
    let analysis = analyzer.analyzeTrends(from: records, timeRange: .month)
    
    // Then
    #expect(analysis.trendPoints.count > 0)
    #expect(analysis.trendPoints.first?.movingAverage != nil)
}

@Test("HealthDataViewModel should load data correctly")
func testHealthDataViewModelLoadData() async throws {
    // Given
    let mockRepository = MockHealthRecordRepository()
    let mockUseCase = FetchHealthDataUseCase(repository: mockRepository)
    let viewModel = HealthDataViewModel(
        recordHealthDataUseCase: RecordHealthDataUseCase(repository: mockRepository, healthKitService: MockHealthKitService()),
        fetchHealthDataUseCase: mockUseCase
    )
    
    // When
    await viewModel.loadHealthData()
    
    // Then
    #expect(!viewModel.isLoading)
    #expect(viewModel.errorMessage == nil)
}
```

#### 2. Integration Tests (20%) - SwiftTesting
```swift
@Test("SwiftData repository should save and fetch records")
func testSwiftDataRepository() async throws {
    // Given
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: HealthRecord.self, User.self, configurations: config)
    let context = ModelContext(container)
    let repository = SwiftDataHealthRecordRepository(modelContext: context)
    
    let user = User(name: "Test User", age: 30, height: 170.0, targetWeight: 65.0)
    let record = HealthRecord(type: .weight, value: 70.0, unit: "kg")
    record.user = user
    
    // When
    try await repository.save(record)
    let fetchedRecords = try await repository.fetchRecords(for: user, type: .weight, from: nil, to: nil)
    
    // Then
    #expect(fetchedRecords.count == 1)
    #expect(fetchedRecords.first?.value == 70.0)
}

@Test("HealthKit service should request authorization")
func testHealthKitAuthorization() async throws {
    // Given
    let service = HealthKitService()
    
    // When & Then
    // Note: 実際のテストではMockHealthKitServiceを使用
    await #expect(throws: Never.self) {
        try await MockHealthKitService().requestAuthorization()
    }
}
```

#### 3. UI Tests (10%) - XCTest
```swift
import XCTest

final class HealthRecordingAppUITests: XCTestCase {
    func testDashboardNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        
        // メインダッシュボードが表示されることを確認
        XCTAssertTrue(app.navigationBars["ダッシュボード"].exists)
        
        // チャート画面への遷移をテスト
        app.buttons["トレンド"].tap()
        XCTAssertTrue(app.navigationBars["トレンド"].exists)
    }
}
```

### テスト環境とMock

#### MockHealthKitService
```swift
final class MockHealthKitService: HealthKitServiceProtocol {
    var shouldThrowError = false
    var mockData: [HealthKitData] = []
    
    func requestAuthorization() async throws {
        if shouldThrowError {
            throw HealthAppError.healthKitAuthorizationDenied
        }
    }
    
    func fetchLatestData() async throws -> [HealthKitData] {
        if shouldThrowError {
            throw HealthAppError.dataFetchFailed(underlying: NSError(domain: "Test", code: 1))
        }
        return mockData
    }
    
    func observeHealthData(handler: @escaping ([HealthKitData]) -> Void) {
        // Mock implementation
    }
}
```

#### MockHealthRecordRepository
```swift
final class MockHealthRecordRepository: HealthRecordRepositoryProtocol {
    private var records: [HealthRecord] = []
    
    func save(_ record: HealthRecord) async throws {
        records.append(record)
    }
    
    func fetchRecords(for user: User, type: HealthDataType?, from startDate: Date?, to endDate: Date?) async throws -> [HealthRecord] {
        return records.filter { $0.user?.id == user.id }
    }
    
    func delete(_ record: HealthRecord) async throws {
        records.removeAll { $0.id == record.id }
    }
    
    func syncWithHealthKit() async throws {
        // Mock implementation
    }
}
```

### テストデータ
```swift
struct TestHealthData {
    static let sampleWeightData: [HealthRecord] = [
        HealthRecord(type: .weight, value: 70.0, unit: "kg"),
        HealthRecord(type: .weight, value: 69.5, unit: "kg"),
        HealthRecord(type: .weight, value: 69.0, unit: "kg")
    ]
    
    static let sampleStepsData: [HealthRecord] = [
        HealthRecord(type: .steps, value: 8000, unit: "count"),
        HealthRecord(type: .steps, value: 10000, unit: "count")
    ]
    
    static let sampleUser: User = {
        User(name: "テストユーザー", age: 30, height: 170.0, targetWeight: 65.0)
    }()
}
```

### テスト実行設定
```swift
// Package.swift (テスト用)
let package = Package(
    name: "HealthRecordingApp",
    platforms: [.iOS(.v17)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.4.0")
    ],
    targets: [
        .testTarget(
            name: "HealthRecordingAppTests",
            dependencies: [
                "HealthRecordingApp",
                .product(name: "Testing", package: "swift-testing")
            ]
        )
    ]
)
```

## セキュリティとプライバシー

### データ保護
1. **暗号化**: Core Dataの暗号化とKeychain使用
2. **アクセス制御**: HealthKitの最小権限原則
3. **データ匿名化**: 共有時の個人情報除去
4. **セキュアな通信**: TLS 1.3使用

### プライバシー設計
1. **データ最小化**: 必要最小限のデータのみ収集
2. **透明性**: データ使用目的の明確化
3. **ユーザー制御**: データ削除・エクスポート機能
4. **同意管理**: 段階的な権限要求

## パフォーマンス最適化

### データ処理最適化
1. **バックグラウンド処理**: 重い計算処理の非同期実行
2. **データキャッシュ**: 頻繁にアクセスするデータのメモリキャッシュ
3. **遅延読み込み**: 大量データの段階的読み込み
4. **バッチ処理**: HealthKitデータの効率的な一括取得

### UI最適化
1. **SwiftUI最適化**: @State、@ObservedObjectの適切な使用
2. **アニメーション最適化**: 60FPSを維持するスムーズなアニメーション
3. **メモリ管理**: 画像キャッシュとメモリリーク防止
4. **レスポンシブデザイン**: 異なる画面サイズへの対応