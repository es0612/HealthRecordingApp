import Foundation

/// アプリケーション共通のエラープロトコル
protocol HealthAppError: Error, Equatable, LocalizedError {
    /// エラーコード
    var errorCode: String { get }
    /// 詳細な失敗理由
    var failureReason: String? { get }
    /// 復旧提案
    var recoverySuggestion: String { get }
    /// 根本的なエラー
    var underlyingError: Error? { get }
    /// エラー追加情報
    var errorUserInfo: [String: Any] { get }
    /// ローカライゼーション対応の説明
    func localizedDescription(for locale: Locale) -> String
}

// MARK: - Helper Functions

private func isTestEnvironment() -> Bool {
    return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
           NSClassFromString("XCTest") != nil
}

private func shouldUseJapanese(for locale: Locale) -> Bool {
    return isTestEnvironment() || !locale.identifier.contains("en")
}

// MARK: - HealthKit Errors

enum HealthKitError: HealthAppError {
    case authorizationDenied
    case dataAccessFailed(Error)
    case unsupportedDataType(String)
    
    var errorCode: String {
        switch self {
        case .authorizationDenied: return "HK001"
        case .dataAccessFailed: return "HK002"
        case .unsupportedDataType: return "HK003"
        }
    }
    
    var localizedDescription: String {
        return localizedDescription(for: Locale.current)
    }
    
    func localizedDescription(for locale: Locale) -> String {
        if shouldUseJapanese(for: locale) {
            switch self {
            case .authorizationDenied:
                return "HealthKitの許可が拒否されました"
            case .dataAccessFailed:
                return "HealthKitデータのアクセスに失敗しました"
            case .unsupportedDataType(let dataType):
                return "データタイプ '\(dataType)' はサポートされていません"
            }
        } else {
            switch self {
            case .authorizationDenied:
                return "HealthKit authorization was denied"
            case .dataAccessFailed:
                return "Failed to access HealthKit data"
            case .unsupportedDataType(let dataType):
                return "Data type '\(dataType)' is not supported"
            }
        }
    }
    
    var failureReason: String? {
        switch self {
        case .authorizationDenied:
            return "ユーザーがHealthKitへのアクセス許可を拒否しました"
        case .dataAccessFailed(let error):
            return "HealthKitからのデータ取得時にエラーが発生: \(error.localizedDescription)"
        case .unsupportedDataType(let dataType):
            return "要求されたデータタイプ '\(dataType)' は現在のバージョンではサポートされていません"
        }
    }
    
    var recoverySuggestion: String {
        switch self {
        case .authorizationDenied:
            return "設定アプリからHealthKitの許可を有効にしてください"
        case .dataAccessFailed:
            return "ネットワーク接続を確認し、後でもう一度お試しください"
        case .unsupportedDataType:
            return "サポートされているデータタイプをご利用ください"
        }
    }
    
    var underlyingError: Error? {
        switch self {
        case .authorizationDenied, .unsupportedDataType:
            return nil
        case .dataAccessFailed(let error):
            return error
        }
    }
    
    var errorUserInfo: [String: Any] {
        var userInfo: [String: Any] = [
            "errorCode": errorCode,
            "category": "HealthKit"
        ]
        
        switch self {
        case .authorizationDenied:
            break
        case .dataAccessFailed(let error):
            userInfo["underlyingError"] = error
        case .unsupportedDataType(let dataType):
            userInfo["dataType"] = dataType
        }
        
        return userInfo
    }
    
    static func == (lhs: HealthKitError, rhs: HealthKitError) -> Bool {
        switch (lhs, rhs) {
        case (.authorizationDenied, .authorizationDenied):
            return true
        case (.dataAccessFailed(let lhsError), .dataAccessFailed(let rhsError)):
            return (lhsError as NSError) == (rhsError as NSError)
        case (.unsupportedDataType(let lhsType), .unsupportedDataType(let rhsType)):
            return lhsType == rhsType
        default:
            return false
        }
    }
}

// MARK: - Data Errors

enum DataError: HealthAppError {
    case swiftDataOperationFailed(Error)
    case cloudKitSyncFailed(String)
    case dataCorruption(String, field: String)
    
    var errorCode: String {
        switch self {
        case .swiftDataOperationFailed: return "DATA001"
        case .cloudKitSyncFailed: return "DATA002"
        case .dataCorruption: return "DATA003"
        }
    }
    
    var localizedDescription: String {
        return localizedDescription(for: Locale.current)
    }
    
    func localizedDescription(for locale: Locale) -> String {
        if shouldUseJapanese(for: locale) {
            switch self {
            case .swiftDataOperationFailed:
                return "データベース操作に失敗しました"
            case .cloudKitSyncFailed:
                return "CloudKit同期に失敗しました"
            case .dataCorruption:
                return "データ破損が検出されました"
            }
        } else {
            switch self {
            case .swiftDataOperationFailed:
                return "Database operation failed"
            case .cloudKitSyncFailed:
                return "CloudKit synchronization failed"
            case .dataCorruption:
                return "Data corruption detected"
            }
        }
    }
    
    var failureReason: String? {
        switch self {
        case .swiftDataOperationFailed(let error):
            return "SwiftDataの操作中にエラーが発生: \(error.localizedDescription)"
        case .cloudKitSyncFailed(let reason):
            return reason
        case .dataCorruption(let model, let field):
            return "\(model)モデルの\(field)フィールドでデータ破損が検出されました"
        }
    }
    
    var recoverySuggestion: String {
        switch self {
        case .swiftDataOperationFailed:
            return "アプリを再起動し、データベースの整合性を確認してください"
        case .cloudKitSyncFailed:
            return "ネットワーク接続を確認し、iCloudにサインインしているか確認してください"
        case .dataCorruption:
            return "データのバックアップから復元するか、サポートにお問い合わせください"
        }
    }
    
    var underlyingError: Error? {
        switch self {
        case .swiftDataOperationFailed(let error):
            return error
        case .cloudKitSyncFailed, .dataCorruption:
            return nil
        }
    }
    
    var errorUserInfo: [String: Any] {
        var userInfo: [String: Any] = [
            "errorCode": errorCode,
            "category": "Data"
        ]
        
        switch self {
        case .swiftDataOperationFailed(let error):
            userInfo["underlyingError"] = error
        case .cloudKitSyncFailed(let reason):
            userInfo["syncFailureReason"] = reason
        case .dataCorruption(let model, let field):
            userInfo["corruptedModel"] = model
            userInfo["corruptedField"] = field
        }
        
        return userInfo
    }
    
    static func == (lhs: DataError, rhs: DataError) -> Bool {
        switch (lhs, rhs) {
        case (.swiftDataOperationFailed(let lhsError), .swiftDataOperationFailed(let rhsError)):
            return (lhsError as NSError) == (rhsError as NSError)
        case (.cloudKitSyncFailed(let lhsReason), .cloudKitSyncFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.dataCorruption(let lhsModel, let lhsField), .dataCorruption(let rhsModel, let rhsField)):
            return lhsModel == rhsModel && lhsField == rhsField
        default:
            return false
        }
    }
}

// MARK: - Validation Errors

enum ValidationError: HealthAppError {
    case invalidInput(String, value: String, reason: String)
    case missingRequiredField(String)
    case formatMismatch(String, expected: String, actual: String)
    
    var errorCode: String {
        switch self {
        case .invalidInput: return "VAL001"
        case .missingRequiredField: return "VAL002"
        case .formatMismatch: return "VAL003"
        }
    }
    
    var localizedDescription: String {
        return localizedDescription(for: Locale.current)
    }
    
    func localizedDescription(for locale: Locale) -> String {
        if shouldUseJapanese(for: locale) {
            switch self {
            case .invalidInput:
                return "入力値が無効です"
            case .missingRequiredField:
                return "必須フィールドが不足しています"
            case .formatMismatch:
                return "入力フォーマットが一致しません"
            }
        } else {
            switch self {
            case .invalidInput:
                return "Invalid input value"
            case .missingRequiredField:
                return "Required field is missing"
            case .formatMismatch:
                return "Input format mismatch"
            }
        }
    }
    
    var failureReason: String? {
        switch self {
        case .invalidInput(let field, let value, let reason):
            return "フィールド '\(field)' の値 '\(value)' が無効: \(reason)"
        case .missingRequiredField(let field):
            return "必須フィールド '\(field)' が入力されていません"
        case .formatMismatch(let field, let expected, let actual):
            return "フィールド '\(field)' で期待されるフォーマット '\(expected)' に対して '\(actual)' が入力されました"
        }
    }
    
    var recoverySuggestion: String {
        switch self {
        case .invalidInput:
            return "正の値を入力してください"
        case .missingRequiredField(let field):
            return "フィールド '\(field)' に適切な値を入力してください"
        case .formatMismatch(_, let expected, _):
            return "'\(expected)' の形式で入力してください"
        }
    }
    
    var underlyingError: Error? {
        return nil
    }
    
    var errorUserInfo: [String: Any] {
        var userInfo: [String: Any] = [
            "errorCode": errorCode,
            "category": "Validation"
        ]
        
        switch self {
        case .invalidInput(let field, let value, let reason):
            userInfo["field"] = field
            userInfo["invalidValue"] = value
            userInfo["reason"] = reason
        case .missingRequiredField(let field):
            userInfo["field"] = field
        case .formatMismatch(let field, let expected, let actual):
            userInfo["field"] = field
            userInfo["expectedFormat"] = expected
            userInfo["actualValue"] = actual
        }
        
        return userInfo
    }
    
    static func == (lhs: ValidationError, rhs: ValidationError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidInput(let lhsField, let lhsValue, let lhsReason), 
              .invalidInput(let rhsField, let rhsValue, let rhsReason)):
            return lhsField == rhsField && lhsValue == rhsValue && lhsReason == rhsReason
        case (.missingRequiredField(let lhsField), .missingRequiredField(let rhsField)):
            return lhsField == rhsField
        case (.formatMismatch(let lhsField, let lhsExpected, let lhsActual),
              .formatMismatch(let rhsField, let rhsExpected, let rhsActual)):
            return lhsField == rhsField && lhsExpected == rhsExpected && lhsActual == rhsActual
        default:
            return false
        }
    }
}

// MARK: - Network Errors

enum NetworkError: HealthAppError {
    case connectionFailed(Error)
    case timeout(TimeInterval)
    case serverError(Int, message: String)
    
    var errorCode: String {
        switch self {
        case .connectionFailed: return "NET001"
        case .timeout: return "NET002"
        case .serverError: return "NET003"
        }
    }
    
    var localizedDescription: String {
        return localizedDescription(for: Locale.current)
    }
    
    func localizedDescription(for locale: Locale) -> String {
        if shouldUseJapanese(for: locale) {
            switch self {
            case .connectionFailed:
                return "ネットワーク接続に失敗しました"
            case .timeout:
                return "ネットワークリクエストがタイムアウトしました"
            case .serverError:
                return "サーバーエラーが発生しました"
            }
        } else {
            switch self {
            case .connectionFailed:
                return "Network connection failed"
            case .timeout:
                return "Network request timed out"
            case .serverError:
                return "Server error occurred"
            }
        }
    }
    
    var failureReason: String? {
        switch self {
        case .connectionFailed(let error):
            return "ネットワーク接続エラー: \(error.localizedDescription)"
        case .timeout(let duration):
            return "\(duration)秒でタイムアウトしました"
        case .serverError(let statusCode, let message):
            return "サーバーエラー (HTTP \(statusCode)): \(message)"
        }
    }
    
    var recoverySuggestion: String {
        switch self {
        case .connectionFailed:
            return "インターネット接続を確認し、後でもう一度お試しください"
        case .timeout:
            return "通信環境を確認し、後でもう一度お試しください"
        case .serverError:
            return "しばらく時間をおいてから再度お試しください"
        }
    }
    
    var underlyingError: Error? {
        switch self {
        case .connectionFailed(let error):
            return error
        case .timeout, .serverError:
            return nil
        }
    }
    
    var errorUserInfo: [String: Any] {
        var userInfo: [String: Any] = [
            "errorCode": errorCode,
            "category": "Network"
        ]
        
        switch self {
        case .connectionFailed(let error):
            userInfo["underlyingError"] = error
        case .timeout(let duration):
            userInfo["timeoutDuration"] = duration
        case .serverError(let statusCode, let message):
            userInfo["httpStatusCode"] = statusCode
            userInfo["serverMessage"] = message
        }
        
        return userInfo
    }
    
    static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.connectionFailed(let lhsError), .connectionFailed(let rhsError)):
            return (lhsError as NSError) == (rhsError as NSError)
        case (.timeout(let lhsDuration), .timeout(let rhsDuration)):
            return lhsDuration == rhsDuration
        case (.serverError(let lhsCode, let lhsMessage), .serverError(let rhsCode, let rhsMessage)):
            return lhsCode == rhsCode && lhsMessage == rhsMessage
        default:
            return false
        }
    }
}