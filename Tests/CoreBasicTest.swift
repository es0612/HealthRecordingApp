import Testing
import Foundation

@Suite("Core Basic Test - No Imports")
struct CoreBasicTest {
    
    @Test("Basic Swift functionality")
    func testBasicSwift() {
        let number = 42
        #expect(number == 42)
        
        let text = "Hello"
        #expect(text.count == 5)
    }
    
    @Test("Basic Date functionality")
    func testBasicDate() {
        let now = Date()
        let interval = now.timeIntervalSince1970
        #expect(interval > 0)
    }
}