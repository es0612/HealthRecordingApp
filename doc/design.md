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