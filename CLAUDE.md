# CLAUDE.md

このファイルは、このリポジトリでコードを扱う際のClaude Code (claude.ai/code) へのガイダンスを提供します。

## プロジェクト概要

iOS 18.5+をターゲットとしたSwiftUIとSwiftDataで構築されたヘルスレコーディングiOSアプリケーションです。クリーンアーキテクチャの原則に従い、健康データ追跡、HealthKit連携、ゲーミフィケーション、AI駆動インサイトに焦点を当てた30代男性向けの本格的なヘルスケアアプリです。

### 主要機能
- **自動データ収集**: HealthKit経由での健康データ自動取得
- **長期トレンド可視化**: Charts frameworkによるリッチなデータ可視化
- **ゲーミフィケーション**: SwiftUIで描画されるカスタムバッジシステム
- **AI連携ログ**: 構造化JSONログによるAIコーディングエージェント支援
- **SNS共有**: 美しい成果画像生成と主要SNSへの共有

## 開発コマンド

### SwiftTestingベース（推奨）

```bash
# テストを実行
swift test

# パッケージをビルド
swift build

# 特定のテストを実行
swift test --filter testTrendAnalyzerMovingAverage

# 詳細ログ付きテスト実行
swift test --verbose
```

### Xcodeプロジェクトベース（補助）

```bash
# プロジェクトをビルド
cd app && xcodebuild -scheme HealthRecordingApp build

# テストを実行
cd app && xcodebuild -scheme HealthRecordingApp -destination 'platform=iOS Simulator,name=iPhone 15' test

# 特定のテストターゲットを実行
cd app && xcodebuild -scheme HealthRecordingApp -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:HealthRecordingAppTests test
```

### プロジェクトを開く

```bash
# Xcodeで開く
open app/HealthRecordingApp.xcodeproj
```

## アーキテクチャ概要

### クリーンアーキテクチャ（4層構造）

プロジェクトは明確に分離された4つの層で構成されています：

#### 1. **プレゼンテーション層** (`app/HealthRecordingApp/Views/`)

- 宣言的UIを持つSwiftUIビュー
- @Observable ViewModels による状態管理
- SwiftUI NavigationStack を使用したナビゲーション
- アニメーション豊富なUI（バッジ獲得、トレンド表示）

#### 2. **アプリケーション層** (`app/HealthRecordingApp/UseCases/`)

- 具体的なビジネスワークフローを実装するUse Cases
- 横断的関心事のためのApp Services
  - NotificationService（通知管理）
  - SocialShareService（SNS共有）
  - BadgeService（ゲーミフィケーション）

#### 3. **ドメイン層** (`app/HealthRecordingApp/Domain/`)

- ビジネスルールを含むドメインモデル（SwiftDataモデル）
- ドメイン固有のビジネスロジック
  - TrendAnalyzer（トレンド分析）
  - GoalTracker（目標追跡）
  - InsightEngine（インサイト生成）
- データアクセス抽象化のためのRepositoryプロトコル

#### 4. **インフラストラクチャ層** (`app/HealthRecordingApp/Infrastructure/`)

- SwiftData による データ永続化とCloudKit同期
- HealthKit連携による健康データアクセス
- 外部API統合（SNS、通知等）

## 主要技術スタック

- **SwiftUI**: 宣言的UIフレームワーク
- **SwiftData**: CloudKit同期を備えたiOS 17+データ永続化
- **@Observable**: モダンな状態管理（@ObservableObjectの置き換え）
- **SwiftTesting**: 新しいテストフレームワーク（ユニットテスト）
- **XCTest**: UI自動テスト用
- **HealthKit**: 健康データ統合
- **CloudKit**: デバイス間データ同期
- **Charts**: データ可視化フレームワーク

## コアドメインモデル

### 現在のモデル

- `Item`: 基本的なSwiftDataモデル（開発中の仮モデル）

### 実装予定モデル（design.md詳細仕様）

#### `HealthRecord`
```swift
@Model
final class HealthRecord {
    var id: UUID
    var type: HealthDataType  // weight, steps, calories, heartRate
    var value: Double
    var unit: String
    var timestamp: Date
    var source: DataSource   // healthKit, manual
    var user: User?
}
```

#### `User`
```swift
@Model
final class User {
    var id: UUID
    var name: String
    var age: Int
    var height: Double
    var targetWeight: Double
    @Relationship(deleteRule: .cascade) var healthRecords: [HealthRecord]
    @Relationship(deleteRule: .cascade) var goals: [Goal]
}
```

#### `Goal`
```swift
@Model
final class Goal {
    var id: UUID
    var type: HealthDataType
    var targetValue: Double
    var currentValue: Double
    var deadline: Date
    var isActive: Bool
}
```

#### `Badge`（ゲーミフィケーション）
```swift
@Model
final class Badge {
    var id: UUID
    var name: String           // "はじめの一歩", "継続は力なり" 等
    var description: String
    var type: BadgeType        // streak, milestone, achievement, special
    var requirement: BadgeRequirement
    var isEarned: Bool
    var earnedDate: Date?
    var iconName: String       // SF Symbols
    var colorScheme: BadgeColorScheme  // bronze, silver, gold, platinum
}
```

## テスト戦略

### SwiftTesting フレームワーク（70% - ユニットテスト）

```swift
import Testing
import SwiftData

@Test("TrendAnalyzer should calculate correct moving average")
func testTrendAnalyzerMovingAverage() async throws {
    let analyzer = TrendAnalyzer()
    let records = TestHealthData.sampleWeightData
    let analysis = analyzer.analyzeTrends(from: records, timeRange: .month)
    
    #expect(analysis.trendPoints.count > 0)
    #expect(analysis.trendPoints.first?.movingAverage != nil)
}
```

### Package.swift テスト設定

```swift
let package = Package(
    name: "HealthRecordingApp",
    platforms: [.iOS(.v17)],  // Note: Xcodeプロジェクトは18.5設定
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

### 統合テスト（20%）

- SwiftData Repository実装テスト
- HealthKit連携テスト
- CloudKit同期テスト

### UIテスト（10% - XCTest）

- 重要なユーザーフローの自動テスト
- HealthKit権限要求フロー
- バッジ獲得アニメーション

## 実装ガイドライン

### ファイル構造

```text
app/HealthRecordingApp/
├── Views/                  # SwiftUIビュー（プレゼンテーション層）
│   ├── Dashboard/          # メインダッシュボード
│   ├── Trends/            # データ可視化画面
│   ├── Goals/             # 目標設定・追跡
│   ├── Badges/            # バッジコレクション
│   └── Settings/          # 設定・プライバシー
├── ViewModels/            # @Observable ViewModels
├── UseCases/              # アプリケーション層
│   ├── RecordHealthDataUseCase.swift
│   ├── AnalyzeTrendsUseCase.swift
│   └── ManageGoalsUseCase.swift
├── Domain/
│   ├── Models/            # SwiftData ドメインモデル
│   ├── Services/          # ドメインビジネスロジック
│   └── Protocols/         # Repository抽象化
├── Infrastructure/
│   ├── Repositories/      # SwiftData Repository実装
│   ├── Services/          # HealthKit、CloudKit、通知
│   └── External/          # SNS API、外部統合
└── Shared/                # 共通ユーティリティ、拡張
    ├── Extensions/
    ├── Utils/
    └── Logging/           # AI連携対応ロギング
```

### TDD（テスト駆動開発）アプローチ

1. **Red**: 失敗するテストを先に書く
2. **Green**: テストを通すための最小限のコードを書く
3. **Refactor**: コードを改善し、テストは通し続ける

### 主要実装原則

1. **SwiftDataモデル**: ドメインエンティティに @Model マクロを使用
2. **状態管理**: @ObservableObject より @Observable を優先
3. **非同期処理**: async/await による構造化並行性を全面採用
4. **HealthKit**: 適切な認証とプライバシー制御で実装
5. **ゲーミフィケーション**: SwiftUI描画による美しいバッジレンダリング
6. **AI連携ログ**: 構造化JSONログ（AILoggerクラス）でデバッグ支援

## AI連携対応ロギング機能

### AILogger の特徴

```swift
final class AILogger: AILoggerProtocol {
    func debug(_ message: String, context: [String: Any]?)
    func info(_ message: String, context: [String: Any]?)
    func warning(_ message: String, context: [String: Any]?)
    func error(_ error: Error, context: [String: Any]?)
    func logUserAction(_ action: String, parameters: [String: Any]?)
    func logPerformance(_ operation: String, duration: TimeInterval, success: Bool)
}
```

### ログ出力例

```json
{
  "timestamp": "2025-07-23T10:30:45Z",
  "level": "info",
  "message": "User action: sync_health_data",
  "context": {
    "action_type": "user_interaction",
    "user_id": "[REDACTED]",
    "data_count": 15
  },
  "source": {
    "file": "RecordHealthDataUseCase.swift",
    "function": "execute(for:)",
    "line": 42
  }
}
```

## ゲーミフィケーション機能

### バッジシステム

- **継続バッジ**: 7日、30日、100日連続記録
- **マイルストーンバッジ**: 初回記録、目標達成等
- **特別バッジ**: 季節イベント、特殊な達成条件

### SwiftUI バッジ描画

```swift
struct BadgeView: View {
    let badge: Badge
    
    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(...))
                .frame(width: 80, height: 80)
            
            Image(systemName: badge.iconName)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(Color(hex: badge.colorScheme.accent))
        }
        .scaleEffect(badge.isEarned ? 1.0 : 0.8)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: badge.isEarned)
    }
}
```

## 要件詳細（doc/requirements.md参照）

### 9つの主要要件

1. **データ自動収集**: HealthKit経由での健康データ自動取得
2. **長期トレンド可視化**: Charts frameworkによる週次・月次・年次グラフ
3. **SNS共有機能**: 美しい成果画像生成とSNS投稿
4. **継続促進機能**: 通知、アニメーション、ストリーク表示
5. **スマートな目標設定**: AI駆動の個人化された目標提案
6. **健康インサイト**: データ相関分析と異常値検出
7. **ゲーミフィケーション**: SwiftUI描画バッジと達成システム
8. **AI連携対応ロギング**: 構造化JSON形式での開発支援ログ
9. **データセキュリティ**: 暗号化、プライバシー保護、GDPR準拠

## 実装計画（doc/tasks.md）

### 23フェーズの開発ロードマップ

**フェーズ1-5**: 基盤実装
- ドメインモデル、HealthKit基盤、Repository層、Use Case層、ドメインサービス

**フェーズ6-10**: UI・UX実装
- ViewModels、基本UI、データ可視化、手動入力、目標設定

**フェーズ11-17**: 高度な機能
- 通知、ゲーミフィケーション、アニメーション、SNS共有、インサイト、AI目標提案、セキュリティ

**フェーズ18-23**: 最適化・統合
- パフォーマンス最適化、統合テスト、アクセシビリティ、最終調整

## ドキュメント参照

包括的な設計と要件ドキュメントは以下で利用可能：

- `doc/requirements.md`: 9つの要件の詳細なユーザーストーリーと受入基準
- `doc/design.md`: 完全なアーキテクチャ設計と実装詳細  
- `doc/tasks.md`: 23フェーズの詳細実装ロードマップ

## 現在のステータス

プロジェクトは初期セットアップ段階：

- Xcodeプロジェクト構造（iOS 18.5 ターゲット） ✅
- SwiftData基本設定 ✅
- 仮のItemモデル ✅

### 次の開発優先事項

1. **ドメインモデル実装**: HealthRecord、User、Goal、Badge
2. **HealthKit統合基盤**: 認証、データ取得、監視
3. **Repository層実装**: SwiftDataベースのデータアクセス
4. **コアUse Cases**: 健康データ記録・取得・分析

## プライバシーとセキュリティ

### データ保護戦略

- **暗号化**: SwiftData/CloudKit による全健康データ暗号化
- **最小権限**: HealthKit必要最小限のアクセス権限要求
- **PII除去**: 本番ログでの個人情報完全削除
- **データ削除**: GDPR準拠の完全データ削除機能
- **透明性**: ユーザーへの明確なデータ使用目的説明

### セキュア通信

- TLS 1.3による全通信暗号化
- エンドツーエンド暗号化でのCloudKit同期
- 第三者データ共有時の明示的同意管理

---

このガイドラインに従って開発を進めることで、モダンなiOS開発手法とAI連携機能を活用した高品質なヘルスケアアプリの構築が可能です。