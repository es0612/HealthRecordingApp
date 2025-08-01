import SwiftUI
import SwiftData
import Foundation

struct ManualDataInputView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDataType: HealthDataType = .weight
    @State private var inputValue: String = ""
    @State private var selectedDate = Date()
    @State private var isLoading = false
    @State private var showingSuccessMessage = false
    
    // Validation state
    @State private var currentValidationErrors: [ValidationError] = []
    @State private var validationResult: ValidationResult = .success
    @State private var currentError: (any UserFriendlyError)?
    @State private var validationFeedback: String = ""
    @State private var isValidating = false
    
    // Dependencies
    private let logger: AILoggerProtocol
    private let validationService: HealthDataValidationServiceProtocol
    private let errorHandler: ValidationErrorHandler
    
    init(
        isPresented: Binding<Bool>,
        logger: AILoggerProtocol = AILogger(),
        validationService: HealthDataValidationServiceProtocol = HealthDataValidationService(),
        errorHandler: ValidationErrorHandler = ValidationErrorHandler()
    ) {
        self._isPresented = isPresented
        self.logger = logger
        self.validationService = validationService
        self.errorHandler = errorHandler
    }
    
    // Computed property for use case (created dynamically with environment context)
    private var recordHealthDataUseCase: RecordHealthDataUseCaseProtocol {
        RecordHealthDataUseCase(
            healthRecordRepository: SwiftDataHealthRecordRepository(
                modelContext: modelContext
            ),
            userRepository: SwiftDataUserRepository(
                modelContext: modelContext
            ),
            badgeRepository: SwiftDataBadgeRepository(
                modelContext: modelContext
            ),
            healthKitService: HealthKitService(),
            logger: logger
        )
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("手動データ入力")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("HealthKitで取得できないデータを手動で記録できます")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Data type selector
                        dataTypeSelector
                        
                        // Input form
                        inputFormSection
                        
                        // Date selector
                        dateSection
                        
                        // Action buttons
                        actionButtons
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationBarHidden(true)
            .validationErrorAlert(error: $currentError) { action in
                handleErrorAction(action)
            }
            .alert("保存完了", isPresented: $showingSuccessMessage) {
                Button("OK") {
                    showingSuccessMessage = false
                    clearForm()
                }
            } message: {
                Text("データが正常に保存されました")
            }
            .disabled(isLoading)
        }
    }
    
    // MARK: - Data Type Selector
    
    private var dataTypeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("データ種別")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach([HealthDataType.weight, .steps, .calories, .heartRate], id: \.self) { dataType in
                    DataTypeCard(
                        dataType: dataType,
                        isSelected: selectedDataType == dataType
                    ) {
                        selectedDataType = dataType
                        inputValue = "" // Reset input when changing type
                    }
                }
            }
        }
        .padding(.vertical)
    }
    
    // MARK: - Input Form Section
    
    private var inputFormSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(selectedDataType.displayName)を入力")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField(placeholderText, text: $inputValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(keyboardType)
                        .font(.title2)
                        .onChange(of: inputValue) { _, newValue in
                            validateInput(newValue)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(validationBorderColor, lineWidth: validationBorderWidth)
                        )
                    
                    Text(selectedDataType.unit)
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 8)
                }
                
                if !validationFeedback.isEmpty {
                    Text(validationFeedback)
                        .font(.caption)
                        .foregroundColor(validationFeedbackColor)
                        .transition(.opacity)
                } else {
                    Text(inputHint)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Quick entry buttons for common values
            if !quickEntryValues.isEmpty {
                quickEntrySection
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Quick Entry Section
    
    private var quickEntrySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("クイック入力")
                .font(.subheadline)
                .fontWeight(.medium)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(quickEntryValues, id: \.self) { value in
                    Button(action: {
                        inputValue = String(format: selectedDataType == .weight ? "%.1f" : "%.0f", value)
                    }) {
                        Text(String(format: selectedDataType == .weight ? "%.1f" : "%.0f", value))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Date Section
    
    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("記録日時")
                .font(.headline)
                .fontWeight(.semibold)
            
            DatePicker(
                "記録日時を選択",
                selection: $selectedDate,
                in: ...Date(),
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(CompactDatePickerStyle())
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: saveData) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text(isLoading ? "保存中..." : "データを保存")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isCurrentInputValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!isCurrentInputValid || isLoading || isValidating)
            
            Button(action: {
                isPresented = false
            }) {
                Text("キャンセル")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
            }
            .disabled(isLoading)
        }
        .padding(.top)
    }
    
    // MARK: - Computed Properties
    
    private var placeholderText: String {
        switch selectedDataType {
        case .weight:
            return "70.0"
        case .steps:
            return "10000"
        case .calories:
            return "2000"
        case .heartRate:
            return "70"
        case .bloodGlucose:
            return "100"
        }
    }
    
    private var inputHint: String {
        switch selectedDataType {
        case .weight:
            return "30.0〜200.0kgの範囲で入力してください"
        case .steps:
            return "0〜100,000歩の範囲で入力してください"
        case .calories:
            return "0〜10,000kcalの範囲で入力してください"
        case .heartRate:
            return "30〜200bpmの範囲で入力してください"
        case .bloodGlucose:
            return "20〜600mg/dLの範囲で入力してください"
        }
    }
    
    private var keyboardType: UIKeyboardType {
        switch selectedDataType {
        case .weight:
            return .decimalPad
        case .steps, .calories, .heartRate, .bloodGlucose:
            return .numberPad
        }
    }
    
    private var quickEntryValues: [Double] {
        switch selectedDataType {
        case .weight:
            return [60.0, 65.0, 70.0, 75.0, 80.0, 85.0]
        case .steps:
            return [5000, 8000, 10000, 12000, 15000, 20000]
        case .calories:
            return [1500, 1800, 2000, 2200, 2500, 3000]
        case .heartRate:
            return [60, 70, 80, 90, 100, 120]
        case .bloodGlucose:
            return [80, 90, 100, 110, 120, 140]
        }
    }
    
    // MARK: - Validation Properties
    
    private var isCurrentInputValid: Bool {
        switch validationResult {
        case .success:
            return !inputValue.isEmpty && Double(inputValue) != nil
        case .failure:
            return false
        }
    }
    
    private var validationBorderColor: Color {
        if inputValue.isEmpty {
            return Color.clear
        }
        
        switch validationResult {
        case .success:
            return Color.green
        case .failure(let errors):
            if errors.contains(where: { error in
                if case .suspiciousValue = error {
                    return true
                }
                return false
            }) {
                return Color.orange
            }
            return Color.red
        }
    }
    
    private var validationBorderWidth: CGFloat {
        inputValue.isEmpty ? 0 : 2
    }
    
    private var validationFeedbackColor: Color {
        switch validationResult {
        case .success:
            return Color.green
        case .failure(let errors):
            if errors.contains(where: { error in
                if case .suspiciousValue = error {
                    return true
                }
                return false
            }) {
                return Color.orange  
            }
            return Color.red
        }
    }
    
    // MARK: - Actions
    
    private func saveData() {
        guard let value = Double(inputValue) else {
            showValidationError(EnhancedValidationError.invalidFormat(
                input: inputValue,
                expectedFormat: "数値",
                dataType: selectedDataType
            ))
            return
        }
        
        // Perform final comprehensive validation before saving
        let healthDataInput = HealthDataInput(
            type: selectedDataType,
            value: value,
            unit: selectedDataType.unit,
            timestamp: selectedDate,
            source: .manual
        )
        
        let finalValidationResult = validationService.validateHealthData(healthDataInput)
        
        switch finalValidationResult {
        case .success:
            break // Continue with save
        case .failure(let errors):
            // Check if there are critical errors that should block saving
            let criticalErrors = errors.filter { error in
                switch error {
                case .suspiciousValue:
                    return false // Allow suspicious values with confirmation
                default:
                    return true // Block other errors
                }
            }
            
            if !criticalErrors.isEmpty {
                showValidationError(EnhancedValidationError.valueOutOfRange(
                    value: value,
                    range: getValidRange(),
                    dataType: selectedDataType
                ))
                return
            }
            
            // If only suspicious values, allow save but warn
            if errors.contains(where: { error in
                if case .suspiciousValue = error {
                    return true
                }
                return false
            }) {
                showSuspiciousValueWarning(value: value) {
                    proceedWithSave(healthDataInput: healthDataInput)
                }
                return
            }
        }
        
        proceedWithSave(healthDataInput: healthDataInput)
    }
    
    private func proceedWithSave(healthDataInput: HealthDataInput) {
        isLoading = true
        currentError = nil
        
        Task {
            do {
                let manualData = ManualHealthData(
                    type: selectedDataType,
                    value: value,
                    unit: selectedDataType.unit,
                    timestamp: selectedDate,
                    source: .manual
                )
                
                // Create mock user for manual entry
                let mockUser = try User(name: "テストユーザー", age: 30, height: 175.0, targetWeight: 70.0)
                
                _ = try await recordHealthDataUseCase.recordManualData(manualData, for: mockUser)
                
                await MainActor.run {
                    isLoading = false
                    showingSuccessMessage = true
                    
                    logger.info("Manual data saved successfully", context: [
                        "data_type": selectedDataType.rawValue,
                        "value": value,
                        "timestamp": selectedDate.ISO8601Format()
                    ])
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    showValidationError(EnhancedValidationError.dataCorruption(
                        details: error.localizedDescription
                    ))
                    
                    logger.error(error, context: [
                        "operation": "manual_data_save",
                        "data_type": selectedDataType.rawValue,
                        "value": healthDataInput.value
                    ])
                }
            }
        }
    }
    
    private func clearForm() {
        inputValue = ""
        selectedDate = Date()
        currentValidationErrors = []
        validationResult = .success
        validationFeedback = ""
    }
    
    // MARK: - Validation Methods
    
    private func validateInput(_ input: String) {
        // Clear previous validation state
        validationFeedback = ""
        
        // Don't validate empty input
        guard !input.isEmpty else {
            validationResult = .success
            return
        }
        
        // Parse input value
        guard let value = Double(input) else {
            validationResult = .failure([ValidationError.invalidFormat(
                input: input,
                expectedFormat: "数値",
                dataType: selectedDataType,
                suggestion: "数値を入力してください"
            )])
            validationFeedback = "数値を入力してください"
            return
        }
        
        // Validate using comprehensive validation service
        isValidating = true
        
        Task {
            let result = validationService.validateValue(value, for: selectedDataType)
            
            await MainActor.run {
                validationResult = result
                isValidating = false
                updateValidationFeedback(result)
            }
        }
    }
    
    private func updateValidationFeedback(_ result: ValidationResult) {
        switch result {
        case .success:
            validationFeedback = "✓ 有効な値です"
            
        case .failure(let errors):
            if let firstError = errors.first {
                validationFeedback = firstError.recoverySuggestion ?? firstError.errorDescription ?? "入力エラー"
            }
        }
    }
    
    private func showValidationError(_ error: any UserFriendlyError) {
        currentError = error
        errorHandler.handle(error)
    }
    
    private func showSuspiciousValueWarning(value: Double, onConfirm: @escaping () -> Void) {
        let warning = EnhancedValidationError.suspiciousValue(
            value: value,
            dataType: selectedDataType,
            reason: .unusuallyHigh(threshold: getTypicalRange().upperBound)
        )
        
        // Create custom error with confirm action
        let confirmableError = ConfirmableValidationError(
            baseError: warning,
            onConfirm: onConfirm
        )
        
        showValidationError(confirmableError)
    }
    
    private func handleErrorAction(_ action: ErrorAction) {
        logger.info("Error action handled", context: [
            "action_title": action.title,
            "action_style": "\(action.style)"
        ])
    }
    
    private func getValidRange() -> ClosedRange<Double> {
        let constraints = validationService.getConstraints(for: selectedDataType)
        return constraints.minimumValue...constraints.maximumValue
    }
    
    private func getTypicalRange() -> ClosedRange<Double> {
        switch selectedDataType {
        case .weight:
            return 50.0...100.0
        case .steps:
            return 3000...15000
        case .calories:
            return 1200...3000
        case .heartRate:
            return 60...100
        case .bloodGlucose:
            return 70...140
        }
    }
}

// MARK: - Data Type Card

struct DataTypeCard: View {
    let dataType: HealthDataType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: dataType.iconName)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(dataType.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(dataType.unit)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - HealthDataType Extensions

extension HealthDataType {
    var iconName: String {
        switch self {
        case .weight:
            return "scalemass"
        case .steps:
            return "figure.walk"
        case .calories:
            return "flame"
        case .heartRate:
            return "heart"
        case .bloodGlucose:
            return "drop"
        }
    }
}

// MARK: - Supporting Types

extension DataSource {
    static let manual = DataSource.manual
}

// MARK: - Confirmable Validation Error

struct ConfirmableValidationError: UserFriendlyError {
    private let baseError: any UserFriendlyError
    private let onConfirm: () -> Void
    
    init(baseError: any UserFriendlyError, onConfirm: @escaping () -> Void) {
        self.baseError = baseError
        self.onConfirm = onConfirm
    }
    
    var category: ErrorCategory { baseError.category }
    var severity: ErrorSeverity { baseError.severity }
    var title: String { baseError.title }
    var message: String { baseError.message }
    var suggestion: String? { baseError.suggestion }
    var technicalDetails: String? { baseError.technicalDetails }
    
    var actions: [ErrorAction] {
        [
            ErrorAction(title: "このまま保存", style: .primary) {
                onConfirm()
            },
            ErrorAction(title: "値を修正", style: .secondary) { },
            ErrorAction(title: "キャンセル", style: .cancel) { }
        ]
    }
}

#Preview {
    ManualDataInputView(isPresented: .constant(true))
}