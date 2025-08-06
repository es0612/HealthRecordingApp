import Foundation
import SwiftUI

// MARK: - Validation Error Framework

/// Comprehensive error handling framework for user-facing validation errors
/// Provides structured error categorization, localized messages, and recovery suggestions

// MARK: - Error Categories

enum ErrorCategory {
    case input          // User input errors
    case system         // System/technical errors  
    case network        // Network connectivity errors
    case permission     // Permission/authorization errors
    case data           // Data consistency/integrity errors
    
    var iconName: String {
        switch self {
        case .input: return "exclamationmark.triangle.fill"
        case .system: return "gear.badge.xmark"
        case .network: return "wifi.exclamationmark"
        case .permission: return "lock.fill"
        case .data: return "externaldrive.badge.exclamationmark"
        }
    }
    
    var color: Color {
        switch self {
        case .input: return .orange
        case .system: return .red
        case .network: return .blue
        case .permission: return .purple
        case .data: return .yellow
        }
    }
}

enum ErrorSeverity {
    case info       // Informational, user can continue
    case warning    // Warning, user should be cautious
    case error      // Error, user action required
    case critical   // Critical error, blocks further action
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .red
        }
    }
    
    var iconName: String {
        switch self {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }
}

// MARK: - User-Friendly Error Protocol

protocol UserFriendlyError: Error {
    var category: ErrorCategory { get }
    var severity: ErrorSeverity { get }
    var title: String { get }
    var message: String { get }
    var suggestion: String? { get }
    var actions: [ErrorAction] { get }
    var technicalDetails: String? { get }
}

// MARK: - Error Actions

struct ErrorAction {
    let title: String
    let style: ActionStyle
    let handler: () -> Void
    
    enum ActionStyle {
        case primary
        case secondary
        case destructive
        case cancel
        
        var color: Color {
            switch self {
            case .primary: return .blue
            case .secondary: return .gray
            case .destructive: return .red
            case .cancel: return .gray
            }
        }
    }
}

// MARK: - Enhanced Validation Errors

enum EnhancedValidationError: UserFriendlyError {
    // Input Value Errors
    case valueOutOfRange(
        value: Double,
        range: ClosedRange<Double>,
        dataType: HealthDataType,
        context: ValidationErrorContext? = nil
    )
    
    case invalidFormat(
        input: String,
        expectedFormat: String,
        dataType: HealthDataType,
        context: ValidationErrorContext? = nil
    )
    
    case suspiciousValue(
        value: Double,
        dataType: HealthDataType,
        reason: SuspiciousValueReason,
        context: ValidationErrorContext? = nil
    )
    
    // Timestamp Errors
    case timestampInvalid(
        timestamp: Date,
        reason: TimestampErrorReason,
        context: ValidationErrorContext? = nil
    )
    
    // Data Integrity Errors
    case potentialDuplicate(
        existingData: HealthRecord,
        confidence: Double,
        context: ValidationErrorContext? = nil
    )
    
    case dataInconsistency(
        reason: DataInconsistencyReason,
        context: ValidationErrorContext? = nil
    )
    
    // System Errors
    case validationServiceUnavailable(
        context: ValidationErrorContext? = nil
    )
    
    case dataCorruption(
        details: String,
        context: ValidationErrorContext? = nil
    )
    
    // MARK: - UserFriendlyError Implementation
    
    var category: ErrorCategory {
        switch self {
        case .valueOutOfRange, .invalidFormat, .suspiciousValue:
            return .input
        case .timestampInvalid:
            return .input
        case .potentialDuplicate, .dataInconsistency:
            return .data
        case .validationServiceUnavailable:
            return .system
        case .dataCorruption:
            return .data
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .valueOutOfRange, .invalidFormat:
            return .error
        case .suspiciousValue:
            return .warning
        case .timestampInvalid:
            return .error
        case .potentialDuplicate:
            return .warning
        case .dataInconsistency:
            return .error
        case .validationServiceUnavailable:
            return .critical
        case .dataCorruption:
            return .critical
        }
    }
    
    var title: String {
        switch self {
        case .valueOutOfRange:
            return "入力値エラー"
        case .invalidFormat:
            return "形式エラー"
        case .suspiciousValue:
            return "確認が必要な値"
        case .timestampInvalid:
            return "日時エラー"
        case .potentialDuplicate:
            return "重複データの可能性"
        case .dataInconsistency:
            return "データ不整合"
        case .validationServiceUnavailable:
            return "システムエラー"
        case .dataCorruption:
            return "データ破損"
        }
    }
    
    var message: String {
        switch self {
        case .valueOutOfRange(let value, let range, let dataType, _):
            return "\(dataType.displayName)の値「\(formatValue(value, for: dataType))」が有効範囲（\(formatValue(range.lowerBound, for: dataType))〜\(formatValue(range.upperBound, for: dataType))）を超えています。"
            
        case .invalidFormat(let input, let expectedFormat, let dataType, _):
            return "\(dataType.displayName)の入力「\(input)」が正しい形式ではありません。\(expectedFormat)の形式で入力してください。"
            
        case .suspiciousValue(let value, let dataType, let reason, _):
            return "\(dataType.displayName)の値「\(formatValue(value, for: dataType))」について確認してください。\(reason.description)"
            
        case .timestampInvalid(let timestamp, let reason, _):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return "日時「\(formatter.string(from: timestamp))」が無効です。\(reason.description)"
            
        case .potentialDuplicate(let existingData, let confidence, _):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return "類似したデータが既に存在します（\(formatter.string(from: existingData.timestamp))、類似度: \(Int(confidence * 100))%）。"
            
        case .dataInconsistency(let reason, _):
            return "データに不整合があります。\(reason.description)"
            
        case .validationServiceUnavailable:
            return "データ検証サービスが一時的に利用できません。しばらく経ってから再度お試しください。"
            
        case .dataCorruption(let details, _):
            return "データが破損している可能性があります。詳細: \(details)"
        }
    }
    
    var suggestion: String? {
        switch self {
        case .valueOutOfRange(_, let range, let dataType, _):
            return "有効範囲: \(formatValue(range.lowerBound, for: dataType))〜\(formatValue(range.upperBound, for: dataType))"
            
        case .invalidFormat(_, let expectedFormat, _, _):
            return "正しい形式: \(expectedFormat)"
            
        case .suspiciousValue(_, _, let reason, _):
            return reason.suggestion
            
        case .timestampInvalid(_, let reason, _):
            return reason.suggestion
            
        case .potentialDuplicate:
            return "既存のデータを確認して、重複がないかチェックしてください"
            
        case .dataInconsistency(let reason, _):
            return reason.suggestion
            
        case .validationServiceUnavailable:
            return "ネットワーク接続を確認し、アプリを再起動してみてください"
            
        case .dataCorruption:
            return "アプリを再起動するか、データを再入力してください"
        }
    }
    
    var actions: [ErrorAction] {
        switch self {
        case .valueOutOfRange, .invalidFormat:
            return [
                ErrorAction(title: "修正する", style: .primary) { },
                ErrorAction(title: "キャンセル", style: .cancel) { }
            ]
            
        case .suspiciousValue:
            return [
                ErrorAction(title: "このまま保存", style: .primary) { },
                ErrorAction(title: "値を修正", style: .secondary) { },
                ErrorAction(title: "キャンセル", style: .cancel) { }
            ]
            
        case .timestampInvalid:
            return [
                ErrorAction(title: "日時を修正", style: .primary) { },
                ErrorAction(title: "現在時刻を使用", style: .secondary) { },
                ErrorAction(title: "キャンセル", style: .cancel) { }
            ]
            
        case .potentialDuplicate:
            return [
                ErrorAction(title: "新しいデータとして保存", style: .primary) { },
                ErrorAction(title: "既存データを確認", style: .secondary) { },
                ErrorAction(title: "キャンセル", style: .cancel) { }
            ]
            
        case .dataInconsistency:
            return [
                ErrorAction(title: "データを修正", style: .primary) { },
                ErrorAction(title: "リセット", style: .destructive) { },
                ErrorAction(title: "キャンセル", style: .cancel) { }
            ]
            
        case .validationServiceUnavailable:
            return [
                ErrorAction(title: "再試行", style: .primary) { },
                ErrorAction(title: "後で試す", style: .cancel) { }
            ]
            
        case .dataCorruption:
            return [
                ErrorAction(title: "アプリを再起動", style: .primary) { },
                ErrorAction(title: "データを削除", style: .destructive) { },
                ErrorAction(title: "キャンセル", style: .cancel) { }
            ]
        }
    }
    
    var technicalDetails: String? {
        switch self {
        case .valueOutOfRange(let value, let range, let dataType, let context):
            return "Value: \(value), Range: \(range), DataType: \(dataType.rawValue), Context: \(context?.debugDescription ?? "nil")"
            
        case .invalidFormat(let input, let expectedFormat, let dataType, let context):
            return "Input: '\(input)', Expected: '\(expectedFormat)', DataType: \(dataType.rawValue), Context: \(context?.debugDescription ?? "nil")"
            
        case .suspiciousValue(let value, let dataType, let reason, let context):
            return "Value: \(value), DataType: \(dataType.rawValue), Reason: \(reason), Context: \(context?.debugDescription ?? "nil")"
            
        case .timestampInvalid(let timestamp, let reason, let context):
            return "Timestamp: \(timestamp.ISO8601Format()), Reason: \(reason), Context: \(context?.debugDescription ?? "nil")"
            
        case .potentialDuplicate(let existingData, let confidence, let context):
            return "ExistingRecord: \(existingData.id), Confidence: \(confidence), Context: \(context?.debugDescription ?? "nil")"
            
        case .dataInconsistency(let reason, let context):
            return "Reason: \(reason), Context: \(context?.debugDescription ?? "nil")"
            
        case .validationServiceUnavailable(let context):
            return "ValidationService unavailable, Context: \(context?.debugDescription ?? "nil")"
            
        case .dataCorruption(let details, let context):
            return "Details: \(details), Context: \(context?.debugDescription ?? "nil")"
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatValue(_ value: Double, for dataType: HealthDataType) -> String {
        switch dataType {
        case .weight:
            return String(format: "%.1f", value)
        case .steps, .calories, .heartRate:
            return String(format: "%.0f", value)
        case .bloodGlucose:
            return String(format: "%.1f", value)
        }
    }
}

// MARK: - Supporting Enums

enum SuspiciousValueReason {
    case unusuallyHigh(threshold: Double)
    case unusuallyLow(threshold: Double)
    case rapidChange(previousValue: Double, timeSpan: TimeInterval)
    case outlier(standardDeviations: Double)
    
    var description: String {
        switch self {
        case .unusuallyHigh(let threshold):
            return "通常より高い値です（基準値: \(threshold)）"
        case .unusuallyLow(let threshold):
            return "通常より低い値です（基準値: \(threshold)）"
        case .rapidChange(let previousValue, let timeSpan):
            let hours = Int(timeSpan / 3600)
            return "前回の値（\(previousValue)）から\(hours)時間で大きく変化しています"
        case .outlier(let standardDeviations):
            return "統計的に異常な値です（標準偏差: \(String(format: "%.1f", standardDeviations))）"
        }
    }
    
    var suggestion: String {
        switch self {
        case .unusuallyHigh, .unusuallyLow:
            return "測定値を再確認してください"
        case .rapidChange:
            return "短時間での変化が大きいため、値を確認してください"
        case .outlier:
            return "測定条件や機器の状態を確認してください"
        }
    }
}

enum TimestampErrorReason {
    case futureDate
    case tooOld(maxAge: Int)
    case invalidTime
    
    var description: String {
        switch self {
        case .futureDate:
            return "未来の日時は入力できません"
        case .tooOld(let maxAge):
            return "\(maxAge)年以上前のデータは入力できません"
        case .invalidTime:
            return "無効な日時形式です"
        }
    }
    
    var suggestion: String {
        switch self {
        case .futureDate:
            return "現在時刻以前の日時を選択してください"
        case .tooOld:
            return "より最近の日時を選択してください"
        case .invalidTime:
            return "正しい日時形式で入力してください"
        }
    }
}

enum DataInconsistencyReason {
    case missingRequiredData(field: String)
    case conflictingValues(field1: String, field2: String)
    case invalidRelationship(description: String)
    
    var description: String {
        switch self {
        case .missingRequiredData(let field):
            return "必須項目「\(field)」が不足しています"
        case .conflictingValues(let field1, let field2):
            return "「\(field1)」と「\(field2)」の値が矛盾しています"
        case .invalidRelationship(let description):
            return description
        }
    }
    
    var suggestion: String {
        switch self {
        case .missingRequiredData:
            return "必須項目をすべて入力してください"
        case .conflictingValues:
            return "矛盾する値を確認し、修正してください"
        case .invalidRelationship:
            return "関連するデータの整合性を確認してください"
        }
    }
}

// MARK: - Validation Error Context

struct ValidationErrorContext {
    let userId: String?
    let sessionId: String
    let timestamp: Date
    let appVersion: String
    let deviceInfo: String
    let additionalData: [String: Any]
    
    init(
        userId: String? = nil,
        sessionId: String = UUID().uuidString,
        timestamp: Date = Date(),
        appVersion: String = "1.0.0",
        deviceInfo: String = "iOS",
        additionalData: [String: Any] = [:]
    ) {
        self.userId = userId
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.appVersion = appVersion
        self.deviceInfo = deviceInfo
        self.additionalData = additionalData
    }
}

extension ValidationErrorContext: CustomDebugStringConvertible {
    var debugDescription: String {
        return "ValidationErrorContext(userId: \(userId ?? "nil"), sessionId: \(sessionId), timestamp: \(timestamp), appVersion: \(appVersion), deviceInfo: \(deviceInfo))"
    }
}

// MARK: - Error Handler

class ValidationErrorHandler: ObservableObject {
    @Published var currentError: (any UserFriendlyError)?
    @Published var errorHistory: [any UserFriendlyError] = []
    
    private let logger: AILoggerProtocol
    private let maxHistoryCount = 50
    
    init(logger: AILoggerProtocol = AILogger()) {
        self.logger = logger
    }
    
    func handle(_ error: any UserFriendlyError) {
        DispatchQueue.main.async {
            self.currentError = error
            self.errorHistory.insert(error, at: 0)
            
            // Limit history size
            if self.errorHistory.count > self.maxHistoryCount {
                self.errorHistory.removeLast()
            }
        }
        
        // Log error for AI analysis
        logger.error(error, context: [
            "error_category": "\(error.category)",
            "error_severity": "\(error.severity)",
            "error_title": error.title,
            "error_message": error.message,
            "technical_details": error.technicalDetails ?? "none"
        ])
    }
    
    func clearCurrentError() {
        DispatchQueue.main.async {
            self.currentError = nil
        }
    }
    
    func clearErrorHistory() {
        DispatchQueue.main.async {
            self.errorHistory.removeAll()
        }
    }
    
    func getErrorsByCategory(_ category: ErrorCategory) -> [any UserFriendlyError] {
        return errorHistory.filter { $0.category == category }
    }
    
    func getErrorsBySeverity(_ severity: ErrorSeverity) -> [any UserFriendlyError] {
        return errorHistory.filter { $0.severity == severity }
    }
}