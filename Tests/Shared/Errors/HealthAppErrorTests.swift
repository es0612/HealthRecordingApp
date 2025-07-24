import Testing
import Foundation
@testable import HealthRecordingApp

@Suite("HealthAppError Tests")
struct HealthAppErrorTests {
    
    // MARK: - HealthKit Error Tests
    
    @Test("HealthKitError should be created with authorization denied")
    func testHealthKitErrorAuthorizationDenied() async throws {
        // Given & When
        let error = HealthKitError.authorizationDenied
        
        // Then
        #expect(error.errorCode == "HK001")
        #expect(error.localizedDescription(for: Locale(identifier: "ja")).contains("許可が拒否"))
        #expect(error.failureReason != nil)
        #expect(error.recoverySuggestion.contains("設定"))
    }
    
    @Test("HealthKitError should be created with data access failed")
    func testHealthKitErrorDataAccessFailed() async throws {
        // Given
        let underlyingError = NSError(domain: "TestDomain", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server Error"])
        
        // When
        let error = HealthKitError.dataAccessFailed(underlyingError)
        
        // Then
        #expect(error.errorCode == "HK002")
        #expect(error.localizedDescription(for: Locale(identifier: "ja")).contains("データのアクセス"))
        #expect(error.underlyingError != nil)
        #expect(error.underlyingError?.localizedDescription == "Server Error")
    }
    
    @Test("HealthKitError should be created with unsupported data type")
    func testHealthKitErrorUnsupportedDataType() async throws {
        // Given & When
        let error = HealthKitError.unsupportedDataType("血糖値")
        
        // Then
        #expect(error.errorCode == "HK003")
        #expect(error.localizedDescription.contains("血糖値"))
        #expect(error.localizedDescription(for: Locale(identifier: "ja")).contains("サポートされていません"))
    }
    
    // MARK: - Data Error Tests
    
    @Test("DataError should be created with SwiftData operation failed")
    func testDataErrorSwiftDataFailed() async throws {
        // Given
        let underlyingError = NSError(domain: "SwiftData", code: 100, userInfo: nil)
        
        // When
        let error = DataError.swiftDataOperationFailed(underlyingError)
        
        // Then
        #expect(error.errorCode == "DATA001")
        #expect(error.localizedDescription(for: Locale(identifier: "ja")).contains("データベース操作"))
        #expect(error.underlyingError != nil)
    }
    
    @Test("DataError should be created with CloudKit sync failed")
    func testDataErrorCloudKitSyncFailed() async throws {
        // Given & When
        let error = DataError.cloudKitSyncFailed("ネットワーク接続エラー")
        
        // Then
        #expect(error.errorCode == "DATA002")
        #expect(error.localizedDescription(for: Locale(identifier: "ja")).contains("同期"))
        #expect(error.failureReason == "ネットワーク接続エラー")
    }
    
    @Test("DataError should be created with data corruption")
    func testDataErrorDataCorruption() async throws {
        // Given & When
        let error = DataError.dataCorruption("HealthRecord", field: "value")
        
        // Then
        #expect(error.errorCode == "DATA003")
        #expect(error.localizedDescription(for: Locale(identifier: "ja")).contains("データ破損"))
        #expect(error.failureReason?.contains("HealthRecord") == true)
        #expect(error.failureReason?.contains("value") == true)
    }
    
    // MARK: - Validation Error Tests
    
    @Test("ValidationError should be created with invalid input")
    func testValidationErrorInvalidInput() async throws {
        // Given & When
        let error = ValidationError.invalidInput("weight", value: "-10", reason: "負の値は許可されていません")
        
        // Then
        #expect(error.errorCode == "VAL001")
        #expect(error.localizedDescription(for: Locale(identifier: "ja")).contains("入力値"))
        #expect(error.failureReason?.contains("-10") == true)
        #expect(error.recoverySuggestion.contains("正の値"))
    }
    
    @Test("ValidationError should be created with missing required field")
    func testValidationErrorMissingRequiredField() async throws {
        // Given & When
        let error = ValidationError.missingRequiredField("email")
        
        // Then
        #expect(error.errorCode == "VAL002")
        #expect(error.localizedDescription(for: Locale(identifier: "ja")).contains("必須フィールド"))
        #expect(error.failureReason?.contains("email") == true)
    }
    
    @Test("ValidationError should be created with format mismatch")
    func testValidationErrorFormatMismatch() async throws {
        // Given & When
        let error = ValidationError.formatMismatch("date", expected: "YYYY-MM-DD", actual: "2024/01/01")
        
        // Then
        #expect(error.errorCode == "VAL003")
        #expect(error.localizedDescription(for: Locale(identifier: "ja")).contains("フォーマット"))
        #expect(error.failureReason?.contains("YYYY-MM-DD") == true)
        #expect(error.failureReason?.contains("2024/01/01") == true)
    }
    
    // MARK: - Network Error Tests
    
    @Test("NetworkError should be created with connection failed")
    func testNetworkErrorConnectionFailed() async throws {
        // Given
        let underlyingError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        
        // When
        let error = NetworkError.connectionFailed(underlyingError)
        
        // Then
        #expect(error.errorCode == "NET001")
        #expect(error.localizedDescription(for: Locale(identifier: "ja")).contains("接続"))
        #expect(error.underlyingError != nil)
    }
    
    @Test("NetworkError should be created with timeout")
    func testNetworkErrorTimeout() async throws {
        // Given & When
        let error = NetworkError.timeout(30.0)
        
        // Then
        #expect(error.errorCode == "NET002")
        #expect(error.localizedDescription(for: Locale(identifier: "ja")).contains("タイムアウト"))
        #expect(error.failureReason?.contains("30.0") == true)
    }
    
    @Test("NetworkError should be created with server error")
    func testNetworkErrorServerError() async throws {
        // Given & When
        let error = NetworkError.serverError(500, message: "Internal Server Error")
        
        // Then
        #expect(error.errorCode == "NET003")
        #expect(error.localizedDescription(for: Locale(identifier: "ja")).contains("サーバー"))
        #expect(error.failureReason?.contains("500") == true)
        #expect(error.failureReason?.contains("Internal Server Error") == true)
    }
    
    // MARK: - Error Protocol Tests
    
    @Test("HealthAppError should provide comprehensive error information")
    func testHealthAppErrorInformation() async throws {
        // Given
        let error = ValidationError.invalidInput("age", value: "150", reason: "年齢は120歳以下である必要があります")
        
        // When & Then
        #expect(!error.errorCode.isEmpty)
        #expect(!error.localizedDescription.isEmpty)
        #expect(error.failureReason != nil)
        #expect(!error.recoverySuggestion.isEmpty)
        #expect(error.errorUserInfo.count > 0)
        
        // Error user info should contain relevant information
        #expect(error.errorUserInfo["errorCode"] as? String == error.errorCode)
        #expect(error.errorUserInfo["field"] as? String == "age")
        #expect(error.errorUserInfo["invalidValue"] as? String == "150")
    }
    
    @Test("HealthAppError should be equatable")
    func testHealthAppErrorEquatable() async throws {
        // Given
        let error1 = ValidationError.missingRequiredField("name")
        let error2 = ValidationError.missingRequiredField("name")
        let error3 = ValidationError.missingRequiredField("email")
        
        // When & Then
        #expect(error1 == error2)
        #expect(error1 != error3)
    }
    
    @Test("HealthAppError should support localization")
    func testHealthAppErrorLocalization() async throws {
        // Given
        let error = HealthKitError.authorizationDenied
        
        // When
        let localizedMessage = error.localizedDescription
        let englishMessage = error.localizedDescription(for: Locale(identifier: "en"))
        
        // Then
        #expect(!localizedMessage.isEmpty)
        #expect(!englishMessage.isEmpty)
        // Default locale should be Japanese, English should be different
        if Locale.current.identifier.contains("ja") {
            #expect(localizedMessage != englishMessage)
        }
    }
}