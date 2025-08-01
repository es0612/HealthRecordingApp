import Foundation

// MARK: - Health Data Validation Service Protocol

/// Comprehensive validation service for health data input
/// Provides detailed validation rules for each health data type with contextual error messages
protocol HealthDataValidationServiceProtocol {
    /// Validate health data input with comprehensive rules
    func validateHealthData(_ data: HealthDataInput) -> ValidationResult
    
    /// Validate specific value for a data type
    func validateValue(_ value: Double, for dataType: HealthDataType) -> ValidationResult
    
    /// Validate timestamp for health data
    func validateTimestamp(_ timestamp: Date) -> ValidationResult
    
    /// Validate unit for data type
    func validateUnit(_ unit: String, for dataType: HealthDataType) -> ValidationResult
    
    /// Get validation constraints for a data type
    func getConstraints(for dataType: HealthDataType) -> HealthDataConstraints
    
    /// Check for potential duplicate data
    func detectPotentialDuplicate(_ data: HealthDataInput, against existing: [HealthRecord]) -> DuplicateDetectionResult
    
    /// Validate data consistency and integrity
    func validateDataIntegrity(_ data: HealthDataInput, context: ValidationContext?) -> ValidationResult
}

// MARK: - Health Data Validation Service Implementation

final class HealthDataValidationService: HealthDataValidationServiceProtocol {
    
    // MARK: - Dependencies
    
    private let logger: AILoggerProtocol
    
    // MARK: - Configuration
    
    private let duplicateDetectionThreshold: TimeInterval = 300 // 5 minutes
    private let anomalyDetectionSensitivity: Double = 2.5 // Standard deviations
    
    // MARK: - Initialization
    
    init(logger: AILoggerProtocol = AILogger()) {
        self.logger = logger
        
        logger.debug("HealthDataValidationService initialized", context: [
            "duplicate_threshold_seconds": duplicateDetectionThreshold,
            "anomaly_sensitivity": anomalyDetectionSensitivity
        ])
    }
    
    // MARK: - HealthDataValidationServiceProtocol Implementation
    
    func validateHealthData(_ data: HealthDataInput) -> ValidationResult {
        logger.debug("Starting comprehensive health data validation", context: [
            "data_type": data.type.rawValue,
            "value": data.value,
            "timestamp": data.timestamp.ISO8601Format()
        ])
        
        // Collect all validation errors
        var errors: [ValidationError] = []
        
        // 1. Validate value
        let valueResult = validateValue(data.value, for: data.type)
        if case .failure(let valueErrors) = valueResult {
            errors.append(contentsOf: valueErrors)
        }
        
        // 2. Validate timestamp
        let timestampResult = validateTimestamp(data.timestamp)
        if case .failure(let timestampErrors) = timestampResult {
            errors.append(contentsOf: timestampErrors)
        }
        
        // 3. Validate unit
        let unitResult = validateUnit(data.unit, for: data.type)
        if case .failure(let unitErrors) = unitResult {
            errors.append(contentsOf: unitErrors)
        }
        
        // 4. Validate data integrity
        let integrityResult = validateDataIntegrity(data, context: nil)
        if case .failure(let integrityErrors) = integrityResult {
            errors.append(contentsOf: integrityErrors)
        }
        
        if errors.isEmpty {
            logger.info("Health data validation successful", context: [
                "data_type": data.type.rawValue,
                "value": data.value
            ])
            return .success
        } else {
            logger.warning("Health data validation failed", context: [
                "data_type": data.type.rawValue,
                "error_count": errors.count,
                "errors": errors.map { $0.errorDescription ?? "Unknown error" }
            ])
            return .failure(errors)
        }
    }
    
    func validateValue(_ value: Double, for dataType: HealthDataType) -> ValidationResult {
        let constraints = getConstraints(for: dataType)
        var errors: [ValidationError] = []
        
        // Basic range validation
        if value < constraints.minimumValue {
            errors.append(ValidationError.valueTooLow(
                value: value,
                minimum: constraints.minimumValue,
                dataType: dataType,
                suggestion: "最小値は\(constraints.minimumValue)\(constraints.unit)です"
            ))
        }
        
        if value > constraints.maximumValue {
            errors.append(ValidationError.valueTooHigh(
                value: value,
                maximum: constraints.maximumValue,
                dataType: dataType,
                suggestion: "最大値は\(constraints.maximumValue)\(constraints.unit)です"
            ))
        }
        
        // Precision validation
        if !constraints.allowedPrecisions.isEmpty {
            let decimalPlaces = getDecimalPlaces(value)
            if !constraints.allowedPrecisions.contains(decimalPlaces) {
                errors.append(ValidationError.invalidPrecision(
                    value: value,
                    allowedPrecisions: constraints.allowedPrecisions,
                    dataType: dataType,
                    suggestion: "小数点以下は\(constraints.allowedPrecisions.map { "\($0)桁" }.joined(separator: "または"))で入力してください"
                ))
            }
        }
        
        // Special validation rules per data type
        switch dataType {
        case .weight:
            if value > 0 && value < 20 {
                errors.append(ValidationError.suspiciousValue(
                    value: value,
                    dataType: dataType,
                    reason: "体重が20kg未満です",
                    suggestion: "正しい値を確認してください"
                ))
            }
            
        case .steps:
            if value > 50000 {
                errors.append(ValidationError.suspiciousValue(
                    value: value,
                    dataType: dataType,
                    reason: "1日の歩数が50,000歩を超えています",
                    suggestion: "歩数を確認してください"
                ))
            }
            
        case .calories:
            if value > 5000 {
                errors.append(ValidationError.suspiciousValue(
                    value: value,
                    dataType: dataType,
                    reason: "1日の消費カロリーが5,000kcalを超えています",
                    suggestion: "カロリー数を確認してください"
                ))
            }
            
        case .heartRate:
            if value < 40 {
                errors.append(ValidationError.suspiciousValue(
                    value: value,
                    dataType: dataType,
                    reason: "心拍数が40bpm未満です",
                    suggestion: "安静時心拍数としても低い値です"
                ))
            }
            if value > 180 {
                errors.append(ValidationError.suspiciousValue(
                    value: value,
                    dataType: dataType,
                    reason: "心拍数が180bpmを超えています",
                    suggestion: "運動時でも高い値です"
                ))
            }
            
        case .bloodGlucose:
            if value < 50 {
                errors.append(ValidationError.suspiciousValue(
                    value: value,
                    dataType: dataType,
                    reason: "血糖値が50mg/dL未満です",
                    suggestion: "低血糖の可能性があります"
                ))
            }
            if value > 400 {
                errors.append(ValidationError.suspiciousValue(
                    value: value,
                    dataType: dataType,
                    reason: "血糖値が400mg/dLを超えています",
                    suggestion: "高血糖の可能性があります"
                ))
            }
        }
        
        return errors.isEmpty ? .success : .failure(errors)
    }
    
    func validateTimestamp(_ timestamp: Date) -> ValidationResult {
        var errors: [ValidationError] = []
        
        let now = Date()
        let maxPastDate = Calendar.current.date(byAdding: .year, value: -5, to: now) ?? now
        let maxFutureDate = Calendar.current.date(byAdding: .minute, value: 5, to: now) ?? now
        
        // Future date validation
        if timestamp > maxFutureDate {
            errors.append(ValidationError.timestampInFuture(
                timestamp: timestamp,
                suggestion: "未来の日時は入力できません"
            ))
        }
        
        // Too old data validation
        if timestamp < maxPastDate {
            errors.append(ValidationError.timestampTooOld(
                timestamp: timestamp,
                maxAge: 5,
                suggestion: "5年以上前のデータは入力できません"
            ))
        }
        
        return errors.isEmpty ? .success : .failure(errors)
    }
    
    func validateUnit(_ unit: String, for dataType: HealthDataType) -> ValidationResult {
        let constraints = getConstraints(for: dataType)
        
        if !constraints.allowedUnits.contains(unit) {
            return .failure([ValidationError.invalidUnit(
                unit: unit,
                allowedUnits: constraints.allowedUnits,
                dataType: dataType,
                suggestion: "使用可能な単位: \(constraints.allowedUnits.joined(separator: ", "))"
            )])
        }
        
        return .success
    }
    
    func getConstraints(for dataType: HealthDataType) -> HealthDataConstraints {
        switch dataType {
        case .weight:
            return HealthDataConstraints(
                minimumValue: 10.0,
                maximumValue: 300.0,
                defaultValue: 70.0,
                unit: "kg",
                allowedUnits: ["kg", "lbs"],
                allowedPrecisions: [0, 1],
                description: "体重",
                validationRules: [
                    "10kg以上300kg以下で入力してください",
                    "小数点以下は1桁まで入力可能です"
                ]
            )
            
        case .steps:
            return HealthDataConstraints(
                minimumValue: 0,
                maximumValue: 100000,
                defaultValue: 8000,
                unit: "歩",
                allowedUnits: ["歩", "steps"],
                allowedPrecisions: [0],
                description: "歩数",
                validationRules: [
                    "0歩以上100,000歩以下で入力してください",
                    "整数で入力してください"
                ]
            )
            
        case .calories:
            return HealthDataConstraints(
                minimumValue: 0,
                maximumValue: 10000,
                defaultValue: 2000,
                unit: "kcal",
                allowedUnits: ["kcal", "cal"],
                allowedPrecisions: [0],
                description: "消費カロリー",
                validationRules: [
                    "0kcal以上10,000kcal以下で入力してください",
                    "整数で入力してください"
                ]
            )
            
        case .heartRate:
            return HealthDataConstraints(
                minimumValue: 30,
                maximumValue: 220,
                defaultValue: 70,
                unit: "bpm",
                allowedUnits: ["bpm"],
                allowedPrecisions: [0],
                description: "心拍数",
                validationRules: [
                    "30bpm以上220bpm以下で入力してください",
                    "整数で入力してください"
                ]
            )
            
        case .bloodGlucose:
            return HealthDataConstraints(
                minimumValue: 20,
                maximumValue: 600,
                defaultValue: 100,
                unit: "mg/dL",
                allowedUnits: ["mg/dL", "mmol/L"],
                allowedPrecisions: [0, 1],
                description: "血糖値",
                validationRules: [
                    "20mg/dL以上600mg/dL以下で入力してください",
                    "小数点以下は1桁まで入力可能です"
                ]
            )
        }
    }
    
    func detectPotentialDuplicate(_ data: HealthDataInput, against existing: [HealthRecord]) -> DuplicateDetectionResult {
        let potentialDuplicates = existing.filter { record in
            // Same data type
            guard record.type == data.type else { return false }
            
            // Time window check
            let timeDifference = abs(record.timestamp.timeIntervalSince(data.timestamp))
            guard timeDifference <= duplicateDetectionThreshold else { return false }
            
            // Value similarity check (within 5% or exact match)
            let valueDifference = abs(record.value - data.value)
            let percentageDifference = valueDifference / record.value
            
            return percentageDifference <= 0.05 || valueDifference <= 0.1
        }
        
        if potentialDuplicates.isEmpty {
            return DuplicateDetectionResult(
                isDuplicate: false,
                confidence: 0,
                existingRecords: [],
                recommendation: .proceed
            )
        }
        
        let confidence = calculateDuplicateConfidence(data, potentialDuplicates)
        let recommendation: DuplicateRecommendation
        
        if confidence > 0.8 {
            recommendation = .reject
        } else if confidence > 0.5 {
            recommendation = .confirmWithUser
        } else {
            recommendation = .proceed
        }
        
        logger.info("Duplicate detection completed", context: [
            "data_type": data.type.rawValue,
            "potential_duplicates": potentialDuplicates.count,
            "confidence": confidence,
            "recommendation": "\(recommendation)"
        ])
        
        return DuplicateDetectionResult(
            isDuplicate: !potentialDuplicates.isEmpty,
            confidence: confidence,
            existingRecords: potentialDuplicates,
            recommendation: recommendation
        )
    }
    
    func validateDataIntegrity(_ data: HealthDataInput, context: ValidationContext?) -> ValidationResult {
        var errors: [ValidationError] = []
        
        // Check for reasonable data patterns
        if let context = context {
            errors.append(contentsOf: validateWithContext(data, context: context))
        }
        
        // Check for data anomalies
        let anomalyResult = detectDataAnomaly(data)
        if case .failure(let anomalyErrors) = anomalyResult {
            errors.append(contentsOf: anomalyErrors)
        }
        
        return errors.isEmpty ? .success : .failure(errors)
    }
    
    // MARK: - Private Helper Methods
    
    private func getDecimalPlaces(_ value: Double) -> Int {
        let string = String(value)
        if let dotIndex = string.firstIndex(of: ".") {
            return string.distance(from: string.index(after: dotIndex), to: string.endIndex)
        }
        return 0
    }
    
    private func calculateDuplicateConfidence(_ data: HealthDataInput, _ existing: [HealthRecord]) -> Double {
        guard let closest = existing.min(by: { 
            abs($0.timestamp.timeIntervalSince(data.timestamp)) < abs($1.timestamp.timeIntervalSince(data.timestamp))
        }) else { return 0 }
        
        let timeFactor = max(0, 1 - (abs(closest.timestamp.timeIntervalSince(data.timestamp)) / duplicateDetectionThreshold))
        let valueFactor = max(0, 1 - (abs(closest.value - data.value) / max(closest.value, data.value)))
        
        return (timeFactor * 0.6 + valueFactor * 0.4)
    }
    
    private func validateWithContext(_ data: HealthDataInput, context: ValidationContext) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        // Example: Check if weight change is reasonable
        if data.type == .weight, let lastWeight = context.lastWeightRecord {
            let daysDifference = Calendar.current.dateComponents([.day], from: lastWeight.timestamp, to: data.timestamp).day ?? 0
            let weightChange = abs(data.value - lastWeight.value)
            let maxReasonableChange = Double(daysDifference) * 0.5 // 0.5kg per day max
            
            if weightChange > maxReasonableChange && daysDifference < 30 {
                errors.append(ValidationError.suspiciousValue(
                    value: data.value,
                    dataType: data.type,
                    reason: "前回の記録から\(String(format: "%.1f", weightChange))kgの変化があります",
                    suggestion: "体重の変化が大きいため、値を確認してください"
                ))
            }
        }
        
        return errors
    }
    
    private func detectDataAnomaly(_ data: HealthDataInput) -> ValidationResult {
        // Simple anomaly detection based on typical ranges
        switch data.type {
        case .weight:
            // Check for extremely unusual weight values
            if data.value < 30 || data.value > 250 {
                return .failure([ValidationError.suspiciousValue(
                    value: data.value,
                    dataType: data.type,
                    reason: "一般的ではない体重の値です",
                    suggestion: "入力値を確認してください"
                )])
            }
            
        case .steps:
            // Already handled in validateValue
            break
            
        case .calories:
            // Already handled in validateValue
            break
            
        case .heartRate:
            // Already handled in validateValue
            break
            
        case .bloodGlucose:
            // Already handled in validateValue
            break
        }
        
        return .success
    }
}

// MARK: - Supporting Types

struct HealthDataInput {
    let type: HealthDataType
    let value: Double
    let unit: String
    let timestamp: Date
    let source: DataSource
}

struct HealthDataConstraints {
    let minimumValue: Double
    let maximumValue: Double
    let defaultValue: Double
    let unit: String
    let allowedUnits: [String]
    let allowedPrecisions: [Int]
    let description: String
    let validationRules: [String]
}

struct ValidationContext {
    let lastWeightRecord: HealthRecord?
    let recentRecords: [HealthRecord]
    let userProfile: User?
}

enum ValidationResult {
    case success
    case failure([ValidationError])
}

struct DuplicateDetectionResult {
    let isDuplicate: Bool
    let confidence: Double
    let existingRecords: [HealthRecord]
    let recommendation: DuplicateRecommendation
}

enum DuplicateRecommendation {
    case proceed
    case confirmWithUser
    case reject
}

// MARK: - Enhanced ValidationError

enum ValidationError: Error, LocalizedError, Equatable {
    case valueTooLow(value: Double, minimum: Double, dataType: HealthDataType, suggestion: String)
    case valueTooHigh(value: Double, maximum: Double, dataType: HealthDataType, suggestion: String)
    case invalidPrecision(value: Double, allowedPrecisions: [Int], dataType: HealthDataType, suggestion: String)
    case suspiciousValue(value: Double, dataType: HealthDataType, reason: String, suggestion: String)
    case timestampInFuture(timestamp: Date, suggestion: String)
    case timestampTooOld(timestamp: Date, maxAge: Int, suggestion: String)
    case invalidUnit(unit: String, allowedUnits: [String], dataType: HealthDataType, suggestion: String)
    case potentialDuplicate(existingRecord: HealthRecord, confidence: Double, suggestion: String)
    case dataIntegrityViolation(reason: String, suggestion: String)
    
    var errorDescription: String? {
        switch self {
        case .valueTooLow(let value, let minimum, let dataType, _):
            return "\(dataType.displayName)の値\(value)が最小値\(minimum)を下回っています"
        case .valueTooHigh(let value, let maximum, let dataType, _):
            return "\(dataType.displayName)の値\(value)が最大値\(maximum)を上回っています"
        case .invalidPrecision(let value, _, let dataType, _):
            return "\(dataType.displayName)の値\(value)の小数点桁数が無効です"
        case .suspiciousValue(let value, let dataType, let reason, _):
            return "\(dataType.displayName)の値\(value): \(reason)"
        case .timestampInFuture(_, _):
            return "未来の日時は入力できません"
        case .timestampTooOld(_, let maxAge, _):
            return "\(maxAge)年以上前のデータは入力できません"
        case .invalidUnit(let unit, _, let dataType, _):
            return "\(dataType.displayName)に対して単位'\(unit)'は無効です"
        case .potentialDuplicate(_, let confidence, _):
            return "類似したデータが既に存在します（類似度: \(Int(confidence * 100))%）"
        case .dataIntegrityViolation(let reason, _):
            return "データ整合性エラー: \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .valueTooLow(_, _, _, let suggestion),
             .valueTooHigh(_, _, _, let suggestion),
             .invalidPrecision(_, _, _, let suggestion),
             .suspiciousValue(_, _, _, let suggestion),
             .timestampInFuture(_, let suggestion),
             .timestampTooOld(_, _, let suggestion),
             .invalidUnit(_, _, _, let suggestion),
             .potentialDuplicate(_, _, let suggestion),
             .dataIntegrityViolation(_, let suggestion):
            return suggestion
        }
    }
    
    // Equatable conformance
    static func == (lhs: ValidationError, rhs: ValidationError) -> Bool {
        switch (lhs, rhs) {
        case (.valueTooLow(let lValue, let lMin, let lType, _), .valueTooLow(let rValue, let rMin, let rType, _)):
            return lValue == rValue && lMin == rMin && lType == rType
        case (.valueTooHigh(let lValue, let lMax, let lType, _), .valueTooHigh(let rValue, let rMax, let rType, _)):
            return lValue == rValue && lMax == rMax && lType == rType
        case (.suspiciousValue(let lValue, let lType, let lReason, _), .suspiciousValue(let rValue, let rType, let rReason, _)):
            return lValue == rValue && lType == rType && lReason == rReason
        case (.timestampInFuture(let lTime, _), .timestampInFuture(let rTime, _)):
            return lTime == rTime
        case (.timestampTooOld(let lTime, let lAge, _), .timestampTooOld(let rTime, let rAge, _)):
            return lTime == rTime && lAge == rAge
        case (.invalidUnit(let lUnit, let lAllowed, let lType, _), .invalidUnit(let rUnit, let rAllowed, let rType, _)):
            return lUnit == rUnit && lAllowed == rAllowed && lType == rType
        case (.dataIntegrityViolation(let lReason, _), .dataIntegrityViolation(let rReason, _)):
            return lReason == rReason
        default:
            return false
        }
    }
}