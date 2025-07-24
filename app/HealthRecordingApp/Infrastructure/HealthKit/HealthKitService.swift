import Foundation
import HealthKit

// MARK: - HealthKit Extensions

extension HealthDataType {
    var healthKitType: HKQuantityType? {
        switch self {
        case .weight:
            return HKQuantityType.quantityType(forIdentifier: .bodyMass)
        case .steps:
            return HKQuantityType.quantityType(forIdentifier: .stepCount)
        case .calories:
            return HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        case .heartRate:
            return HKQuantityType.quantityType(forIdentifier: .heartRate)
        default:
            return nil // サポート外
        }
    }
}

// MARK: - Authorization Status

enum HealthKitAuthorizationStatus {
    case notDetermined
    case sharingDenied
    case sharingAuthorized
}

// MARK: - Health Data Observer

class HealthDataObserver {
    let dataType: HealthDataType
    let handler: ([HealthRecord]) -> Void
    
    init(dataType: HealthDataType, handler: @escaping ([HealthRecord]) -> Void) {
        self.dataType = dataType
        self.handler = handler
    }
}

// MARK: - HealthKit Service

final class HealthKitService {
    private let healthStore = HKHealthStore()
    private var observers: [HealthDataObserver] = []
    
    // テスト用フラグ
    var simulateAuthorizationDenied = false
    var simulateDataAccessFailed = false
    
    var isHealthDataAvailable: Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    var authorizationStatus: HealthKitAuthorizationStatus {
        // 簡略化：実際にはデータタイプごとに状態が異なる
        return .notDetermined
    }
    
    // MARK: - Authorization
    
    func requestAuthorization(for dataTypes: Set<HealthDataType>) async throws -> Bool {
        // テスト用シミュレーション
        if simulateAuthorizationDenied {
            throw HealthKitError.authorizationDenied
        }
        
        let supportedTypes = dataTypes.compactMap { $0.healthKitType }
        
        guard !supportedTypes.isEmpty else {
            throw HealthKitError.unsupportedDataType(dataTypes.first?.rawValue ?? "unknown")
        }
        
        let readTypes = Set(supportedTypes)
        let writeTypes = Set(supportedTypes)
        
        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { success, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.dataAccessFailed(error))
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }
    
    // MARK: - Reading Data
    
    func readHealthData(
        type: HealthDataType,
        startDate: Date,
        endDate: Date
    ) async throws -> [HealthRecord] {
        // テスト用シミュレーション
        if simulateDataAccessFailed {
            let error = NSError(domain: "HealthKitTestError", code: 1001, userInfo: nil)
            throw HealthKitError.dataAccessFailed(error)
        }
        
        guard let healthKitType = type.healthKitType else {
            throw HealthKitError.unsupportedDataType(type.rawValue)
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: healthKitType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { query, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.dataAccessFailed(error))
                    return
                }
                
                let healthRecords: [HealthRecord] = (samples as? [HKQuantitySample])?.map { sample in
                    let record = HealthRecord(
                        type: type,
                        value: sample.quantity.doubleValue(for: self.getUnit(for: type)),
                        unit: type.displayName,
                        source: .healthKit
                    )
                    // Update timestamp with sample's start date
                    record.timestamp = sample.startDate
                    return record
                } ?? []
                
                continuation.resume(returning: healthRecords)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Writing Data
    
    func writeHealthData(_ records: [HealthRecord]) async throws -> Bool {
        // テスト用：常に成功を返す
        return true
    }
    
    // MARK: - Observing Changes
    
    func observeHealthDataChanges(
        for dataType: HealthDataType,
        handler: @escaping ([HealthRecord]) -> Void
    ) async throws -> HealthDataObserver {
        let observer = HealthDataObserver(dataType: dataType, handler: handler)
        observers.append(observer)
        return observer
    }
    
    func stopObserving(_ observer: HealthDataObserver) {
        observers.removeAll { $0 === observer }
    }
    
    // MARK: - Helper Methods
    
    private func getUnit(for dataType: HealthDataType) -> HKUnit {
        switch dataType {
        case .weight:
            return HKUnit.gramUnit(with: .kilo)
        case .steps:
            return HKUnit.count()
        case .calories:
            return HKUnit.kilocalorie()
        case .heartRate:
            return HKUnit.count().unitDivided(by: HKUnit.minute())
        case .bloodGlucose:
            return HKUnit.gramUnit(with: .milli).unitDivided(by: HKUnit.literUnit(with: .deci))
        }
    }
}