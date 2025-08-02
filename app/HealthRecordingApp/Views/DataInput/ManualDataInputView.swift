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
    @State private var currentValidationErrors: [DataValidationError] = []
    @State private var validationResult: ValidationResult = .success
    @State private var currentError: (any UserFriendlyError)?
    @State private var validationFeedback: String = ""
    @State private var isValidating = false
    
    // Data integrity alert state
    @State private var showingDuplicateAlert = false
    @State private var showingAnomalyAlert = false
    @State private var showingConsistencyAlert = false
    @State private var duplicateAlertData: DuplicateAlertData?
    @State private var anomalyAlertData: AnomalyAlertData?
    @State private var consistencyAlertData: ConsistencyAlertData?
    @State private var pendingCompletion: ((Bool) -> Void)?
    
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
            .alert("重複データ検出", isPresented: $showingDuplicateAlert) {
                duplicateAlertButtons
            } message: {
                duplicateAlertMessage
            }
            .alert("異常値の検出", isPresented: $showingAnomalyAlert) {
                anomalyAlertButtons
            } message: {
                anomalyAlertMessage
            }
            .alert("データの一貫性問題", isPresented: $showingConsistencyAlert) {
                consistencyAlertButtons
            } message: {
                consistencyAlertMessage
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
        Task {
            await performSaveData()
        }
    }
    
    @MainActor
    private func performSaveData() async {
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
        
        // Phase 9.3.4: Comprehensive data integrity protection
        await performDataIntegrityChecks(healthDataInput) { [weak self] shouldProceed in
            guard let self = self, shouldProceed else { return }
            Task {
                await self.proceedWithSave(healthDataInput: healthDataInput)
            }
        }
        
        await proceedWithSave(healthDataInput: healthDataInput)
    }
    
    @MainActor
    private func proceedWithSave(healthDataInput: HealthDataInput) async {
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
            validationResult = .failure([DataValidationError.invalidFormat(
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
    
    // MARK: - Phase 9.3.4: Data Integrity Protection
    
    @MainActor
    private func performDataIntegrityChecks(
        _ healthDataInput: HealthDataInput,
        completion: @escaping (Bool) -> Void
    ) async {
        logger.info("Starting comprehensive data integrity checks", context: [
            "data_type": healthDataInput.type.rawValue,
            "value": healthDataInput.value,
            "timestamp": healthDataInput.timestamp.ISO8601Format()
        ])
        
        // Step 1: Basic validation
        let basicValidationResult = validationService.validateHealthData(healthDataInput)
        
        switch basicValidationResult {
        case .failure(let errors):
            let criticalErrors = errors.filter { !isSuspiciousValueError($0) }
            if !criticalErrors.isEmpty {
                await showCriticalValidationErrors(criticalErrors)
                completion(false)
                return
            }
        case .success:
            break
        }
        
        do {
            // Step 2: Fetch existing data for comparison
            let existingRecords = try await fetchExistingRecords(for: healthDataInput.type)
            
            // Step 3: Duplicate detection
            let duplicateResult = validationService.detectPotentialDuplicate(healthDataInput, against: existingRecords)
            
            if duplicateResult.isDuplicate {
                await handleDuplicateDetection(duplicateResult, healthDataInput: healthDataInput, completion: completion)
                return
            }
            
            // Step 4: Statistical anomaly detection
            let anomalyResult = await performStatisticalAnomalyDetection(healthDataInput, existingRecords: existingRecords)
            
            if case .anomalyDetected(let anomaly) = anomalyResult {
                await handleAnomalyDetection(anomaly, healthDataInput: healthDataInput, completion: completion)
                return
            }
            
            // Step 5: Data consistency checks
            let consistencyResult = await performDataConsistencyChecks(healthDataInput, existingRecords: existingRecords)
            
            if case .inconsistency(let issue) = consistencyResult {
                await handleConsistencyIssue(issue, healthDataInput: healthDataInput, completion: completion)
                return
            }
            
            // Step 6: Final validation passed
            logger.info("All data integrity checks passed", context: [
                "data_type": healthDataInput.type.rawValue,
                "checks_performed": ["basic_validation", "duplicate_detection", "anomaly_detection", "consistency_check"]
            ])
            
            completion(true)
            
        } catch {
            logger.error(error, context: [
                "operation": "data_integrity_checks",
                "data_type": healthDataInput.type.rawValue
            ])
            
            showValidationError(EnhancedValidationError.dataCorruption(
                details: "データ整合性チェック中にエラーが発生しました: \(error.localizedDescription)"
            ))
            
            completion(false)
        }
    }
    
    private func isSuspiciousValueError(_ error: DataValidationError) -> Bool {
        switch error {
        case .suspiciousValue:
            return true
        default:
            return false
        }
    }
    
    @MainActor
    private func showCriticalValidationErrors(_ errors: [DataValidationError]) async {
        logger.warning("Critical validation errors detected", context: [
            "error_count": errors.count,
            "errors": errors.map { $0.localizedDescription }
        ])
        
        if let firstError = errors.first {
            let enhancedError = convertToEnhancedError(firstError)
            showValidationError(enhancedError)
        }
    }
    
    private func convertToEnhancedError(_ validationError: DataValidationError) -> any UserFriendlyError {
        switch validationError {
        case .valueTooHigh(let value, let maximum, let dataType, let suggestion):
            return EnhancedValidationError.valueOutOfRange(
                value: value,
                range: 0...maximum,
                dataType: dataType
            )
        case .valueTooLow(let value, let minimum, let dataType, let suggestion):
            return EnhancedValidationError.valueOutOfRange(
                value: value,
                range: minimum...Double.greatestFiniteMagnitude,
                dataType: dataType
            )
        case .timestampInFuture(let timestamp, let suggestion):
            return EnhancedValidationError.invalidTimestamp(
                timestamp: timestamp,
                reason: "未来の時刻は入力できません"
            )
        default:
            return EnhancedValidationError.dataCorruption(
                details: validationError.localizedDescription
            )
        }
    }
    
    private func fetchExistingRecords(for dataType: HealthDataType) async throws -> [HealthRecord] {
        // Create mock user for data fetching
        let mockUser = try User(name: "テストユーザー", age: 30, height: 175.0, targetWeight: 70.0)
        
        // Fetch recent records (last 30 days) for comparison
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let dateRange = thirtyDaysAgo...Date()
        
        let useCase = FetchHealthDataUseCase(
            healthRecordRepository: SwiftDataHealthRecordRepository(
                modelContext: modelContext
            ),
            userRepository: SwiftDataUserRepository(
                modelContext: modelContext
            ),
            healthKitService: HealthKitService(),
            logger: logger
        )
        
        let records = try await useCase.fetchHealthRecords(
            for: mockUser,
            type: dataType,
            dateRange: dateRange,
            limit: 100
        )
        
        logger.debug("Fetched existing records for comparison", context: [
            "data_type": dataType.rawValue,
            "record_count": records.count,
            "date_range_days": 30
        ])
        
        return records
    }
    
    @MainActor
    private func handleDuplicateDetection(
        _ result: DuplicateDetectionResult,
        healthDataInput: HealthDataInput,
        completion: @escaping (Bool) -> Void
    ) async {
        logger.warning("Potential duplicate detected", context: [
            "confidence": result.confidence,
            "recommendation": "\(result.recommendation)",
            "existing_records": result.existingRecords.count
        ])
        
        switch result.recommendation {
        case .reject:
            showDuplicateRejectionAlert(result) {
                completion(false)
            }
            
        case .confirmWithUser:
            showDuplicateConfirmationAlert(result, healthDataInput: healthDataInput) { shouldProceed in
                completion(shouldProceed)
            }
            
        case .proceed:
            // Low confidence duplicate - allow but log
            logger.info("Low confidence duplicate - proceeding", context: [
                "confidence": result.confidence
            ])
            completion(true)
        }
    }
    
    private func performStatisticalAnomalyDetection(
        _ healthDataInput: HealthDataInput,
        existingRecords: [HealthRecord]
    ) async -> AnomalyDetectionResult {
        // Require minimum data points for statistical analysis
        guard existingRecords.count >= 5 else {
            return .noAnomalyDetected
        }
        
        let values = existingRecords.map { $0.value }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        let standardDeviation = sqrt(variance)
        
        let zScore = abs(healthDataInput.value - mean) / standardDeviation
        
        logger.debug("Statistical anomaly analysis", context: [
            "data_type": healthDataInput.type.rawValue,
            "input_value": healthDataInput.value,
            "mean": mean,
            "std_dev": standardDeviation,
            "z_score": zScore,
            "sample_size": values.count
        ])
        
        // Z-score thresholds for anomaly detection
        if zScore > 3.0 {
            return .anomalyDetected(StatisticalAnomaly(
                value: healthDataInput.value,
                dataType: healthDataInput.type,
                zScore: zScore,
                severity: .critical,
                explanation: "値が統計的に非常に異常です（Zスコア: \(String(format: "%.2f", zScore))）",
                recommendation: "入力値を再確認してください"
            ))
        } else if zScore > 2.0 {
            return .anomalyDetected(StatisticalAnomaly(
                value: healthDataInput.value,
                dataType: healthDataInput.type,
                zScore: zScore,
                severity: .moderate,
                explanation: "値が一般的な範囲を超えています（Zスコア: \(String(format: "%.2f", zScore))）",
                recommendation: "この値で間違いないか確認してください"
            ))
        }
        
        return .noAnomalyDetected
    }
    
    private func performDataConsistencyChecks(
        _ healthDataInput: HealthDataInput,
        existingRecords: [HealthRecord]
    ) async -> ConsistencyCheckResult {
        // Check for rapid changes that might indicate data entry errors
        guard let latestRecord = existingRecords.sorted(by: { $0.timestamp > $1.timestamp }).first else {
            return .consistent
        }
        
        let timeDifference = healthDataInput.timestamp.timeIntervalSince(latestRecord.timestamp)
        let valueDifference = abs(healthDataInput.value - latestRecord.value)
        
        // Check for rapid weight changes (example: >5kg in <1 day)
        if healthDataInput.type == .weight && timeDifference < 86400 { // 24 hours
            if valueDifference > 5.0 {
                return .inconsistency(DataConsistencyIssue(
                    type: .rapidChange,
                    dataType: healthDataInput.type,
                    currentValue: healthDataInput.value,
                    previousValue: latestRecord.value,
                    timeDifference: timeDifference,
                    explanation: "24時間以内に\(String(format: "%.1f", valueDifference))kgの体重変化は一般的ではありません",
                    recommendation: "入力値が正しいか確認してください"
                ))
            }
        }
        
        // Check for unrealistic step changes (example: >50,000 steps in <1 hour)
        if healthDataInput.type == .steps && timeDifference < 3600 { // 1 hour
            if valueDifference > 50000 {
                return .inconsistency(DataConsistencyIssue(
                    type: .unrealisticRate,
                    dataType: healthDataInput.type,
                    currentValue: healthDataInput.value,
                    previousValue: latestRecord.value,
                    timeDifference: timeDifference,
                    explanation: "1時間以内に\(Int(valueDifference))歩の増加は非現実的です",
                    recommendation: "歩数の入力値を再確認してください"
                ))
            }
        }
        
        return .consistent
    }
    
    @MainActor
    private func handleAnomalyDetection(
        _ anomaly: StatisticalAnomaly,
        healthDataInput: HealthDataInput,
        completion: @escaping (Bool) -> Void
    ) async {
        logger.warning("Statistical anomaly detected", context: [
            "data_type": anomaly.dataType.rawValue,
            "value": anomaly.value,
            "z_score": anomaly.zScore,
            "severity": "\(anomaly.severity)"
        ])
        
        let anomalyError = EnhancedValidationError.statisticalAnomaly(
            value: anomaly.value,
            dataType: anomaly.dataType,
            zScore: anomaly.zScore,
            severity: anomaly.severity,
            explanation: anomaly.explanation
        )
        
        if anomaly.severity == .critical {
            showValidationError(anomalyError)
            completion(false)
        } else {
            // Moderate anomaly - show confirmation dialog
            showAnomalyConfirmationAlert(anomaly) { shouldProceed in
                completion(shouldProceed)
            }
        }
    }
    
    @MainActor
    private func handleConsistencyIssue(
        _ issue: DataConsistencyIssue,
        healthDataInput: HealthDataInput,
        completion: @escaping (Bool) -> Void
    ) async {
        logger.warning("Data consistency issue detected", context: [
            "issue_type": "\(issue.type)",
            "data_type": issue.dataType.rawValue,
            "current_value": issue.currentValue,
            "previous_value": issue.previousValue,
            "time_difference_seconds": issue.timeDifference
        ])
        
        showConsistencyIssueAlert(issue) { shouldProceed in
            completion(shouldProceed)
        }
    }
    
    @MainActor
    private func showDuplicateRejectionAlert(
        _ result: DuplicateDetectionResult,
        completion: @escaping () -> Void
    ) {
        duplicateAlertData = DuplicateAlertData(
            result: result,
            type: .rejection,
            completion: { _ in completion() }
        )
        showingDuplicateAlert = true
    }
    
    @MainActor
    private func showDuplicateConfirmationAlert(
        _ result: DuplicateDetectionResult,
        healthDataInput: HealthDataInput,
        completion: @escaping (Bool) -> Void
    ) {
        duplicateAlertData = DuplicateAlertData(
            result: result,
            type: .confirmation,
            completion: completion
        )
        pendingCompletion = completion
        showingDuplicateAlert = true
    }
    
    @MainActor
    private func showAnomalyConfirmationAlert(
        _ anomaly: StatisticalAnomaly,
        completion: @escaping (Bool) -> Void
    ) {
        anomalyAlertData = AnomalyAlertData(
            anomaly: anomaly,
            completion: completion
        )
        pendingCompletion = completion
        showingAnomalyAlert = true
    }
    
    @MainActor
    private func showConsistencyIssueAlert(
        _ issue: DataConsistencyIssue,
        completion: @escaping (Bool) -> Void
    ) {
        consistencyAlertData = ConsistencyAlertData(
            issue: issue,
            completion: completion
        )
        pendingCompletion = completion
        showingConsistencyAlert = true
    }
    
    // MARK: - SwiftUI Alert Computed Properties
    
    @ViewBuilder
    private var duplicateAlertButtons: some View {
        if let data = duplicateAlertData {
            switch data.type {
            case .rejection:
                Button("OK") {
                    data.completion(false)
                }
            case .confirmation:
                Button("追加する") {
                    data.completion(true)
                }
                Button("キャンセル", role: .cancel) {
                    data.completion(false)
                }
            }
        }
    }
    
    @ViewBuilder
    private var duplicateAlertMessage: some View {
        if let data = duplicateAlertData {
            switch data.type {
            case .rejection:
                Text("同じデータが既に存在します。重複したデータの追加は推奨されません。")
            case .confirmation:
                let confidencePercent = Int(data.result.confidence * 100)
                Text("類似したデータが既に存在します（信頼度: \(confidencePercent)%）。このまま追加しますか？")
            }
        }
    }
    
    @ViewBuilder
    private var anomalyAlertButtons: some View {
        if let data = anomalyAlertData {
            Button("このまま保存") {
                data.completion(true)
            }
            Button("修正する", role: .cancel) {
                data.completion(false)
            }
        }
    }
    
    @ViewBuilder
    private var anomalyAlertMessage: some View {
        if let data = anomalyAlertData {
            Text(data.anomaly.explanation + "\n\n" + data.anomaly.recommendation)
        }
    }
    
    @ViewBuilder
    private var consistencyAlertButtons: some View {
        if let data = consistencyAlertData {
            Button("このまま保存") {
                data.completion(true)
            }
            Button("修正する", role: .cancel) {
                data.completion(false)
            }
        }
    }
    
    @ViewBuilder
    private var consistencyAlertMessage: some View {
        if let data = consistencyAlertData {
            Text(data.issue.explanation + "\n\n" + data.issue.recommendation)
        }
    }
}

// MARK: - Data Integrity Protection Types

enum AnomalyDetectionResult {
    case noAnomalyDetected
    case anomalyDetected(StatisticalAnomaly)
}

struct StatisticalAnomaly {
    let value: Double
    let dataType: HealthDataType
    let zScore: Double
    let severity: AnomalySeverity
    let explanation: String
    let recommendation: String
}

enum AnomalySeverity {
    case moderate
    case critical
}

enum ConsistencyCheckResult {
    case consistent
    case inconsistency(DataConsistencyIssue)
}

struct DataConsistencyIssue {
    let type: InconsistencyType
    let dataType: HealthDataType
    let currentValue: Double
    let previousValue: Double
    let timeDifference: TimeInterval
    let explanation: String
    let recommendation: String
}

enum InconsistencyType {
    case rapidChange
    case unrealisticRate
    case illogicalSequence
}

// MARK: - Alert Data Types

struct DuplicateAlertData {
    let result: DuplicateDetectionResult
    let type: DuplicateAlertType
    let completion: (Bool) -> Void
}

enum DuplicateAlertType {
    case rejection
    case confirmation
}

struct AnomalyAlertData {
    let anomaly: StatisticalAnomaly
    let completion: (Bool) -> Void
}

struct ConsistencyAlertData {
    let issue: DataConsistencyIssue
    let completion: (Bool) -> Void
}

// MARK: - Enhanced Validation Error Extensions

extension EnhancedValidationError {
    static func statisticalAnomaly(
        value: Double,
        dataType: HealthDataType,
        zScore: Double,
        severity: AnomalySeverity,
        explanation: String
    ) -> EnhancedValidationError {
        return .suspiciousValue(
            value: value,
            dataType: dataType,
            reason: .outlier(standardDeviations: zScore),
            context: ValidationErrorContext(
                userAction: "異常値確認",
                additionalInfo: [
                    "explanation": explanation,
                    "z_score": String(zScore),
                    "severity": "\(severity)"
                ]
            )
        )
    }
    
    static func invalidTimestamp(
        timestamp: Date,
        reason: String
    ) -> EnhancedValidationError {
        return .timestampInvalid(
            timestamp: timestamp,
            reason: .future,
            context: ValidationErrorContext(
                userAction: "時刻修正",
                additionalInfo: ["reason": reason]
            )
        )
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