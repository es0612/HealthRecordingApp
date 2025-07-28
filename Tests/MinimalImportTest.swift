import Testing
import Foundation

@Suite("Minimal Test Without HealthRecordingApp Import")
struct MinimalImportTest {
    
    @Test("Test that doesn't import HealthRecordingApp")
    func testWithoutImport() {
        let result = 2 + 2
        #expect(result == 4)
    }
    
    @Test("Test string manipulation without import")
    func testStringWithoutImport() {
        let text = "Test"
        #expect(text.count == 4)
    }
}