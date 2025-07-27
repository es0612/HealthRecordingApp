import Testing
import Foundation

@Suite("Basic Compilation Test")
struct BasicTest {
    
    @Test("Simple arithmetic test - no imports")
    func testBasicArithmetic() {
        let result = 2 + 2
        #expect(result == 4)
    }
    
    @Test("String manipulation test - no imports")
    func testBasicString() {
        let text = "Hello, World!"
        #expect(text.count == 13)
    }
}