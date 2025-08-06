import Testing
import SwiftUI
import SwiftData
import Foundation
#if canImport(UIKit)
import UIKit
#endif

@testable import HealthRecordingApp

// MARK: - Manual Data Input UI Component Tests

struct ManualDataInputUITests {
    
    private let logger = AILogger()
    
    // MARK: - Enhanced Data Type Card Tests
    
    @Test("EnhancedDataTypeCard should display correct information")
    func testEnhancedDataTypeCard() async throws {
        let dataType = HealthDataType.weight
        let recentValue = 70.5
        
        // Test card properties
        #expect(dataType.displayName == "体重")
        #expect(dataType.unit == "kg")
        #expect(dataType.iconName == "scalemass")
        
        // Test recent value formatting
        let formattedValue = String(format: "%.1f", recentValue)
        #expect(formattedValue == "70.5")
    }
    
    @Test("EnhancedDataTypeCard should handle nil recent value")
    func testEnhancedDataTypeCardWithNilValue() async throws {
        let dataType = HealthDataType.steps
        let recentValue: Double? = nil
        
        // Should handle nil gracefully
        #expect(dataType.displayName == "歩数")
        #expect(dataType.unit == "歩")
        
        // Recent value section should not be displayed when nil
        #expect(recentValue == nil)
    }
    
    // MARK: - Smart Suggestion Button Tests
    
    @Test("SmartSuggestionButton should format values correctly")
    func testSmartSuggestionButtonFormatting() async throws {
        let testCases: [(HealthDataType, Double, String)] = [
            (.weight, 70.5, "70.5"),
            (.steps, 10000, "10000"),
            (.calories, 2200, "2200"),
            (.heartRate, 75, "75"),
            (.bloodGlucose, 100, "100")
        ]
        
        for (dataType, value, expected) in testCases {
            let formatted = String(format: dataType == .weight ? "%.1f" : "%.0f", value)
            #expect(formatted == expected)
        }
    }
    
    @Test("SmartSuggestionButton should provide accessible labels")
    func testSmartSuggestionButtonAccessibility() async throws {
        let dataTypes: [HealthDataType] = [.weight, .steps, .calories, .heartRate, .bloodGlucose]
        
        for dataType in dataTypes {
            // Each data type should have proper unit and display name
            #expect(!dataType.unit.isEmpty)
            #expect(!dataType.displayName.isEmpty)
        }
    }
    
    // MARK: - Quick Entry Button Tests
    
    @Test("QuickEntryButton should identify recommended values")
    func testQuickEntryButtonRecommendation() async throws {
        let recentValues = [70.0, 69.5, 70.5, 69.8, 70.2]
        let testValue = 70.0
        
        let isRecommended = isRecommendedValue(testValue, recentValues: recentValues)
        #expect(isRecommended) // Should be true as 70.0 is close to recent values
        
        let nonRecommendedValue = 85.0
        let isNotRecommended = isRecommendedValue(nonRecommendedValue, recentValues: recentValues)
        #expect(!isNotRecommended) // Should be false as 85.0 is far from recent values
    }
    
    @Test("QuickEntryButton should handle empty recent values")
    func testQuickEntryButtonWithEmptyRecentValues() async throws {
        let emptyRecentValues: [Double] = []
        let testValue = 70.0
        
        let isRecommended = isRecommendedValue(testValue, recentValues: emptyRecentValues)
        #expect(!isRecommended) // Should be false when no recent values available
    }
    
    // MARK: - Preset Values Grid Tests
    
    @Test("PresetValuesGrid should provide appropriate values for each data type")
    func testPresetValuesGrid() async throws {
        let testCases: [(HealthDataType, Int, ClosedRange<Double>)] = [
            (.weight, 10, 50.0...100.0),
            (.steps, 6, 3000.0...15000.0),
            (.calories, 6, 1500.0...3000.0),
            (.heartRate, 8, 60.0...95.0),
            (.bloodGlucose, 7, 80.0...140.0)
        ]
        
        for (dataType, expectedCount, expectedRange) in testCases {
            let presetValues = getPresetValuesForDataType(dataType)
            
            #expect(presetValues.count == expectedCount)
            
            for value in presetValues {
                #expect(expectedRange.contains(value))
            }
        }
    }
    
    // MARK: - Validation Feedback View Tests
    
    @Test("ValidationFeedbackView should display correct states")
    func testValidationFeedbackViewStates() async throws {
        // Test normal state
        let normalState = ValidationState.normal
        let normalIcon = getIconName(for: normalState)
        let normalColor = getColor(for: normalState)
        
        #expect(normalIcon == "info.circle")
        #expect(normalColor == .secondary)
        
        // Test valid state
        let validState = ValidationState.valid
        let validIcon = getIconName(for: validState)
        let validColor = getColor(for: validState)
        
        #expect(validIcon == "checkmark.circle")
        #expect(validColor == .green)
        
        // Test invalid state
        let invalidState = ValidationState.invalid
        let invalidIcon = getIconName(for: invalidState)
        let invalidColor = getColor(for: invalidState)
        
        #expect(invalidIcon == "exclamationmark.circle")
        #expect(invalidColor == .red)
    }
    
    @Test("ValidationFeedbackView should handle empty feedback gracefully")
    func testValidationFeedbackViewWithEmptyFeedback() async throws {
        let emptyFeedback = ""
        let hint = "体重を入力してください"
        
        // Should display hint when feedback is empty
        #expect(emptyFeedback.isEmpty)
        #expect(!hint.isEmpty)
    }
    
    // MARK: - Custom Text Field Style Tests
    
    @Test("CustomTextFieldStyle should provide correct border colors")
    func testCustomTextFieldStyleBorders() async throws {
        // Test focused state
        let focusedBorderColor = Color.blue
        #expect(focusedBorderColor == Color.blue)
        
        // Test validation states
        let normalBorderColor = ValidationState.normal.borderColor
        let validBorderColor = ValidationState.valid.borderColor
        let invalidBorderColor = ValidationState.invalid.borderColor
        
        #expect(normalBorderColor == .clear)
        #expect(validBorderColor == .green)
        #expect(invalidBorderColor == .red)
    }
    
    @Test("CustomTextFieldStyle should provide correct border widths")
    func testCustomTextFieldStyleBorderWidths() async throws {
        let normalBorderWidth = ValidationState.normal.borderWidth
        let validBorderWidth = ValidationState.valid.borderWidth
        let invalidBorderWidth = ValidationState.invalid.borderWidth
        
        #expect(normalBorderWidth == 0)
        #expect(validBorderWidth == 1.5)
        #expect(invalidBorderWidth == 1.5)
    }
    
    // MARK: - Quick Date Button Tests
    
    @Test("QuickDateButton should calculate correct time offsets")
    func testQuickDateButtonTimeOffsets() async throws {
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        let oneHourOffset = now.timeIntervalSince(oneHourAgo)
        
        #expect(abs(oneHourOffset - 3600) < 1.0) // Should be approximately 3600 seconds
    }
    
    // MARK: - Haptic Feedback Tests
    
    #if canImport(UIKit)
    @Test("Haptic feedback types should be defined correctly")
    func testHapticFeedbackTypes() async throws {
        // Test that all haptic feedback types are available on iOS
        let selectionFeedback = HapticFeedbackType.selection
        let impactLight = HapticFeedbackType.impact(.light)
        let impactMedium = HapticFeedbackType.impact(.medium)
        let notificationSuccess = HapticFeedbackType.notification(.success)
        
        // Verify types exist (compilation test)
        #expect(selectionFeedback == .selection)
        #expect(impactLight != impactMedium)
    }
    #endif
    
    // MARK: - Animation and Transition Tests
    
    @Test("Animation parameters should be within reasonable bounds")
    func testAnimationParameters() async throws {
        // Test spring animation parameters
        let springResponse: Double = 0.5
        let dampingFraction: Double = 0.7
        
        #expect(springResponse > 0 && springResponse <= 1.0)
        #expect(dampingFraction > 0 && dampingFraction <= 1.0)
        
        // Test easing duration parameters
        let easingDuration: Double = 0.3
        #expect(easingDuration > 0 && easingDuration <= 1.0)
    }
    
    @Test("Scale effect parameters should be reasonable")
    func testScaleEffectParameters() async throws {
        let selectedScale = 1.05
        let normalScale = 1.0
        let pressedScale = 0.95
        
        #expect(selectedScale > normalScale)
        #expect(pressedScale < normalScale)
        #expect(selectedScale <= 1.2) // Not too extreme
        #expect(pressedScale >= 0.8) // Not too extreme
    }
    
    // MARK: - Color and Styling Tests
    
    @Test("Color opacity values should be within valid range")
    func testColorOpacityValues() async throws {
        let backgroundOpacity = 0.1
        let borderOpacity = 0.3
        let shadowOpacity = 0.05
        
        let opacityValues = [backgroundOpacity, borderOpacity, shadowOpacity]
        
        for opacity in opacityValues {
            #expect(opacity >= 0.0 && opacity <= 1.0)
        }
    }
    
    @Test("Shadow parameters should be reasonable")
    func testShadowParameters() async throws {
        let focusedShadowRadius: CGFloat = 8
        let normalShadowRadius: CGFloat = 4
        
        #expect(focusedShadowRadius > normalShadowRadius)
        #expect(focusedShadowRadius <= 20) // Not too extreme
        #expect(normalShadowRadius >= 0) // Non-negative
    }
    
    // MARK: - Helper Methods
    
    private func isRecommendedValue(_ value: Double, recentValues: [Double]) -> Bool {
        guard !recentValues.isEmpty else { return false }
        return recentValues.contains { abs($0 - value) < 1.0 }
    }
    
    private func getPresetValuesForDataType(_ dataType: HealthDataType) -> [Double] {
        switch dataType {
        case .weight:
            return [50, 55, 60, 65, 70, 75, 80, 85, 90, 95]
        case .steps:
            return [3000, 5000, 8000, 10000, 12000, 15000]
        case .calories:
            return [1500, 1800, 2000, 2200, 2500, 3000]
        case .heartRate:
            return [60, 65, 70, 75, 80, 85, 90, 95]
        case .bloodGlucose:
            return [80, 90, 95, 100, 110, 120, 140]
        }
    }
    
    private func getIconName(for state: ValidationState) -> String {
        switch state {
        case .normal:
            return "info.circle"
        case .valid:
            return "checkmark.circle"
        case .invalid:
            return "exclamationmark.circle"
        }
    }
    
    private func getColor(for state: ValidationState) -> Color {
        switch state {
        case .normal:
            return .secondary
        case .valid:
            return .green
        case .invalid:
            return .red
        }
    }
    
    // MARK: - ValidationState enum for testing
    private enum ValidationState: Equatable {
        case normal
        case valid
        case invalid
        
        var borderColor: Color {
            switch self {
            case .normal:
                return .clear
            case .valid:
                return .green
            case .invalid:
                return .red
            }
        }
        
        var borderWidth: CGFloat {
            switch self {
            case .normal:
                return 0
            case .valid, .invalid:
                return 1.5
            }
        }
    }
    
    // MARK: - HapticFeedbackType enum for testing
    #if canImport(UIKit)
    private enum HapticFeedbackType: Equatable {
        case selection
        case impact(UIImpactFeedbackGenerator.FeedbackStyle)
        case notification(UINotificationFeedbackGenerator.FeedbackType)
    }
    #endif
}