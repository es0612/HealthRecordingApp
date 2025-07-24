import Foundation
@testable import HealthRecordingApp

struct TestHealthData {
    // テスト用の健康データサンプル
    static let sampleWeightData: [Double] = [70.0, 69.8, 69.5, 69.2, 69.0]
    static let sampleStepsData: [Double] = [8000, 10000, 12000, 9500, 11000]
    static let sampleCaloriesData: [Double] = [2000, 2200, 1900, 2100, 2050]
    
    // テスト用ユーザーデータ
    static let testUserName = "テストユーザー"
    static let testUserAge = 30
    static let testUserHeight = 170.0
    static let testUserTargetWeight = 65.0
    
    // テスト用バッジデータ
    static let firstStepBadgeName = "はじめの一歩"
    static let firstStepBadgeDescription = "初回記録を達成"
    static let streakBadgeName = "継続は力なり"
    static let streakBadgeDescription = "7日連続記録を達成"
}