import Testing
import Foundation
@testable import HealthRecordingApp

@Test("Simple test to verify testing infrastructure")
func testSimple() async throws {
    // This is a basic test to verify the testing infrastructure works
    let value = 42
    #expect(value == 42)
}

@Test("Test HealthDataType enum")
func testHealthDataType() async throws {
    // Test basic enum functionality
    let weightType = HealthDataType.weight
    #expect(weightType.rawValue == "weight")
    #expect(weightType.displayName == "kg")
}

@Test("Test DataSource enum")
func testDataSource() async throws {
    // Test basic enum functionality
    let manualSource = DataSource.manual
    #expect(manualSource.rawValue == "manual")
}