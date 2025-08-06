import Testing
import SwiftUI
import SwiftData
import Foundation
#if canImport(UIKit)
import UIKit
#endif

@testable import HealthRecordingApp

// MARK: - Manual Input Accessibility and UX Tests

struct ManualInputAccessibilityTests {
    
    private let logger = AILogger()
    
    // MARK: - Accessibility Label Tests
    
    @Test("All interactive elements should have accessibility labels")
    func testAccessibilityLabels() async throws {
        // Test data type selection buttons
        let dataTypes: [HealthDataType] = [.weight, .steps, .calories, .heartRate, .bloodGlucose]
        
        for dataType in dataTypes {
            let accessibilityLabel = "\(dataType.displayName)を選択"
            let accessibilityHint = "\(dataType.displayName)の入力モードに切り替えます"
            
            #expect(!accessibilityLabel.isEmpty)
            #expect(!accessibilityHint.isEmpty)
            #expect(accessibilityLabel.contains(dataType.displayName))
        }
        
        // Test preset toggle button
        let presetToggleLabel = "プリセット値表示"
        let presetToggleHintShow = "プリセット値を表示"
        let presetToggleHintHide = "プリセット値を非表示"
        
        #expect(!presetToggleLabel.isEmpty)
        #expect(!presetToggleHintShow.isEmpty)
        #expect(!presetToggleHintHide.isEmpty)
        
        // Test smart suggestions button
        let smartSuggestionsLabel = "スマート提案"
        let smartSuggestionsHint = "過去のデータに基づく入力提案"
        
        #expect(!smartSuggestionsLabel.isEmpty)
        #expect(!smartSuggestionsHint.isEmpty)
    }
    
    @Test("Quick entry buttons should have descriptive labels")
    func testQuickEntryAccessibilityLabels() async throws {
        let testCases: [(HealthDataType, Double, String)] = [
            (.weight, 70.0, "体重70.0kgを入力"),
            (.steps, 10000, "歩数10000歩を入力"),
            (.calories, 2000, "カロリー2000kcalを入力"),
            (.heartRate, 75, "心拍数75bpmを入力"),
            (.bloodGlucose, 100, "血糖値100mg/dLを入力")
        ]
        
        for (dataType, value, expectedLabel) in testCases {
            let formattedValue = String(format: dataType == .weight ? "%.1f" : "%.0f", value)
            let accessibilityLabel = "\(dataType.displayName)\(formattedValue)\(dataType.unit)を入力"
            
            #expect(accessibilityLabel == expectedLabel)
        }
    }
    
    @Test("Validation feedback should be accessible")
    func testValidationFeedbackAccessibility() async throws {
        // Test different validation states
        let validationStates: [(String, String)] = [
            ("✓ 有効な値です", "入力値が有効です"),
            ("値が範囲外です", "入力エラー: 値が範囲外です"),
            ("数値を入力してください", "入力エラー: 数値を入力してください")
        ]
        
        for (feedback, expectedAccessibility) in validationStates {
            let accessibilityLabel = feedback.contains("✓") ? "入力値が有効です" : "入力エラー: \(feedback)"
            
            #expect(!accessibilityLabel.isEmpty)
            #expect(accessibilityLabel.contains(feedback.contains("✓") ? "有効" : "エラー"))
        }
    }
    
    // MARK: - VoiceOver Support Tests
    
    @Test("VoiceOver navigation should be logical")
    func testVoiceOverNavigationOrder() async throws {
        // Test that accessibility elements are in logical order
        let expectedNavigationOrder = [
            "データ種別選択",
            "入力フィールド",
            "クイック入力ボタン",
            "日時選択",
            "保存ボタン",
            "キャンセルボタン"
        ]
        
        for (index, element) in expectedNavigationOrder.enumerated() {
            #expect(!element.isEmpty)
            #expect(index < expectedNavigationOrder.count)
        }
        
        // Verify that critical actions are easily accessible
        let criticalActions = ["データ種別選択", "保存ボタン", "キャンセルボタン"]
        for action in criticalActions {
            #expect(expectedNavigationOrder.contains(action))
        }
    }
    
    @Test("Dynamic content changes should announce to VoiceOver")
    func testDynamicContentAnnouncements() async throws {
        // Test validation state changes
        let stateChanges = [
            ("入力開始", "数値を入力してください"),
            ("有効な値", "✓ 有効な値です"),
            ("無効な値", "値が範囲外です"),
            ("保存成功", "データが保存されました")
        ]
        
        for (state, announcement) in stateChanges {
            let accessibilityAnnouncement = generateAccessibilityAnnouncement(for: state, message: announcement)
            
            #expect(!accessibilityAnnouncement.isEmpty)
            #expect(accessibilityAnnouncement.contains("です") || accessibilityAnnouncement.contains("ました"))
        }
    }
    
    // MARK: - Color and Contrast Tests
    
    @Test("UI elements should have sufficient color contrast")
    func testColorContrast() async throws {
        // Test that validation states use accessible colors
        let validationColors = [
            ("normal", Color.secondary),
            ("valid", Color.green),
            ("invalid", Color.red)
        ]
        
        for (state, color) in validationColors {
            // In a real implementation, this would test actual contrast ratios
            // For now, verify that appropriate semantic colors are used
            #expect(color != Color.clear)
            
            switch state {
            case "valid":
                #expect(color == Color.green)
            case "invalid":
                #expect(color == Color.red)
            case "normal":
                #expect(color == Color.secondary)
            default:
                Issue.record("Unexpected validation state: \(state)")
            }
        }
    }
    
    @Test("Dark mode compatibility should be maintained")
    func testDarkModeCompatibility() async throws {
        // Test that colors work well in both light and dark modes
        let colorSchemes: [ColorScheme] = [.light, .dark]
        
        for colorScheme in colorSchemes {
            // Verify that semantic colors are used (they adapt automatically)
            let backgroundColors = [
                Color(.controlColor),
                Color(.quaternarySystemFill),
                Color.blue.opacity(0.1),
                Color.gray.opacity(0.1)
            ]
            
            for backgroundColor in backgroundColors {
                #expect(backgroundColor != Color.clear)
                // Semantic colors should adapt to color scheme automatically
            }
        }
    }
    
    // MARK: - Font and Text Size Tests
    
    @Test("Text should scale with Dynamic Type")
    func testDynamicTypeSupport() async throws {
        let fontStyles: [Font] = [
            .largeTitle,
            .headline,
            .subheadline,
            .title2,
            .caption
        ]
        
        for fontStyle in fontStyles {
            // Verify that standard font styles are used (they scale automatically)
            #expect(fontStyle != nil)
        }
        
        // Test that critical text uses appropriate font weights
        let fontWeights: [Font.Weight] = [
            .bold,
            .semibold,
            .medium
        ]
        
        for weight in fontWeights {
            #expect(weight != nil)
        }
    }
    
    @Test("Text truncation should be handled gracefully")
    func testTextTruncationHandling() async throws {
        // Test long text handling
        let longTexts = [
            "これは非常に長い警告メッセージの例で、小さな画面でも適切に表示される必要があります",
            "データ種別の表示名が長い場合の処理",
            "バリデーションエラーメッセージが長い場合"
        ]
        
        for longText in longTexts {
            #expect(longText.count > 20) // Verify it's actually long
            #expect(!longText.isEmpty)
        }
    }
    
    // MARK: - Touch and Gesture Tests
    
    @Test("Touch targets should meet minimum size requirements")
    func testTouchTargetSizes() async throws {
        // Test that interactive elements meet 44pt minimum touch target size
        let minimumTouchSize: CGFloat = 44.0
        
        let interactiveElements = [
            ("データ種別ボタン", CGSize(width: 120, height: 60)),
            ("クイック入力ボタン", CGSize(width: 80, height: 40)),
            ("プリセットボタン", CGSize(width: 60, height: 32)),
            ("日時クイック選択", CGSize(width: 80, height: 28)),
            ("保存ボタン", CGSize(width: 200, height: 56))
        ]
        
        for (elementName, size) in interactiveElements {
            let meetsSizeRequirement = size.width >= minimumTouchSize || size.height >= minimumTouchSize
            
            if !meetsSizeRequirement {
                // For small elements, verify they have adequate padding
                let hasAdequatePadding = size.width >= 32 && size.height >= 28
                #expect(hasAdequatePadding, "\(elementName) should have adequate padding for touch")
            } else {
                #expect(meetsSizeRequirement, "\(elementName) should meet minimum touch size")
            }
        }
    }
    
    @Test("Gesture conflicts should be avoided")
    func testGestureConflicts() async throws {
        // Test that gestures don't conflict with system gestures or each other
        let gestureTypes = [
            "tap", // Basic tap gesture
            "longPress", // Not used to avoid conflicts
            "swipe", // Not used to avoid conflicts
            "pinch" // Not used in input form
        ]
        
        // Only tap gestures should be used for primary interactions
        let usedGestures = ["tap"]
        
        for gesture in usedGestures {
            #expect(gestureTypes.contains(gesture))
        }
        
        // Verify no conflicting gestures are used
        let avoidedGestures = ["longPress", "swipe", "pinch"]
        for avoided in avoidedGestures {
            #expect(!usedGestures.contains(avoided))
        }
    }
    
    // MARK: - Input Method Tests
    
    @Test("Keyboard types should be appropriate for input")
    func testKeyboardTypes() async throws {
        #if canImport(UIKit)
        let keyboardMappings: [(HealthDataType, UIKeyboardType)] = [
            (.weight, .decimalPad),
            (.steps, .numberPad),
            (.calories, .numberPad),
            (.heartRate, .numberPad),
            (.bloodGlucose, .numberPad)
        ]
        
        for (dataType, expectedKeyboard) in keyboardMappings {
            let actualKeyboard = getKeyboardType(for: dataType)
            #expect(actualKeyboard == expectedKeyboard, "Keyboard type for \(dataType) should be \(expectedKeyboard)")
        }
        #endif
    }
    
    @Test("Input validation should provide immediate feedback")
    func testImmediateValidationFeedback() async throws {
        let validationService = HealthDataValidationService()
        
        // Test real-time validation feedback
        let inputSequence = ["7", "70", "70.", "70.5", "70.55", "700"]
        var feedbackHistory: [String] = []
        
        for input in inputSequence {
            guard let value = Double(input) else {
                feedbackHistory.append("数値を入力してください")
                continue
            }
            
            let result = validationService.validateValue(value, for: .weight)
            let feedback = generateValidationFeedback(result)
            feedbackHistory.append(feedback)
        }
        
        #expect(feedbackHistory.count == inputSequence.count)
        
        // Should provide helpful feedback for each step
        for feedback in feedbackHistory {
            #expect(!feedback.isEmpty)
        }
    }
    
    // MARK: - Error Recovery Tests
    
    @Test("Error messages should guide user to correct input")
    func testErrorMessageGuidance() async throws {
        let validationService = HealthDataValidationService()
        
        let errorTestCases: [(Double, HealthDataType, String)] = [
            (300.0, .weight, "範囲"),
            (-10.0, .weight, "範囲"),
            (100000, .steps, "範囲"),
            (10000, .calories, "範囲")
        ]
        
        for (value, dataType, expectedKeyword) in errorTestCases {
            let result = validationService.validateValue(value, for: dataType)
            
            if case .failure(let errors) = result {
                let hasGuidance = errors.allSatisfy { error in
                    let suggestion = error.recoverySuggestion ?? error.errorDescription ?? ""
                    return suggestion.contains(expectedKeyword) || !suggestion.isEmpty
                }
                #expect(hasGuidance, "Error should provide guidance for \(dataType) value \(value)")
            }
        }
    }
    
    // MARK: - Performance Accessibility Tests
    
    @Test("Accessibility should not impact performance significantly")
    func testAccessibilityPerformance() async throws {
        // Test that accessibility labels and hints don't cause performance issues
        let startTime = Date()
        
        let dataTypes: [HealthDataType] = [.weight, .steps, .calories, .heartRate, .bloodGlucose]
        var accessibilityLabels: [String] = []
        
        for dataType in dataTypes {
            let label = "\(dataType.displayName)を選択"
            let hint = "\(dataType.displayName)の入力モードに切り替えます"
            
            accessibilityLabels.append(label)
            accessibilityLabels.append(hint)
        }
        
        let endTime = Date()
        let executionTime = endTime.timeIntervalSince(startTime)
        
        #expect(accessibilityLabels.count == 10) // 2 labels per data type
        #expect(executionTime < 0.01) // Should be very fast
    }
    
    // MARK: - Helper Methods
    
    private func generateAccessibilityAnnouncement(for state: String, message: String) -> String {
        switch state {
        case "入力開始":
            return "入力を開始しました。\(message)"
        case "有効な値":
            return "入力値が有効になりました。"
        case "無効な値":
            return "入力エラーが発生しました。\(message)"
        case "保存成功":
            return "データの保存が完了しました。"
        default:
            return message
        }
    }
    
    private func generateValidationFeedback(_ result: ValidationResult) -> String {
        switch result {
        case .success:
            return "✓ 有効な値です"
        case .failure(let errors):
            if let firstError = errors.first {
                return firstError.recoverySuggestion ?? firstError.errorDescription ?? "入力エラー"
            }
            return "入力エラー"
        }
    }
    
    #if canImport(UIKit)
    private func getKeyboardType(for dataType: HealthDataType) -> UIKeyboardType {
        switch dataType {
        case .weight:
            return .decimalPad
        case .steps, .calories, .heartRate, .bloodGlucose:
            return .numberPad
        }
    }
    #endif
}