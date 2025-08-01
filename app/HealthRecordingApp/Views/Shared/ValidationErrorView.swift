import SwiftUI

// MARK: - Validation Error View

/// SwiftUI component for displaying user-friendly validation errors
/// Provides consistent error presentation with contextual actions
struct ValidationErrorView: View {
    let error: any UserFriendlyError
    let onDismiss: () -> Void
    let onActionTapped: ((ErrorAction) -> Void)?
    
    @State private var showTechnicalDetails = false
    
    init(
        error: any UserFriendlyError,
        onDismiss: @escaping () -> Void,
        onActionTapped: ((ErrorAction) -> Void)? = nil
    ) {
        self.error = error
        self.onDismiss = onDismiss
        self.onActionTapped = onActionTapped
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with icon and title
            headerSection
            
            // Error message
            messageSection
            
            // Suggestion (if available)
            if let suggestion = error.suggestion {
                suggestionSection(suggestion)
            }
            
            // Technical details toggle (debug builds only)
            #if DEBUG
            technicalDetailsSection
            #endif
            
            // Action buttons
            if !error.actions.isEmpty {
                actionButtonsSection
            }
        }
        .padding()
        .background(backgroundForSeverity(error.severity))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(error.severity.color.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: error.severity.color.opacity(0.2), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(spacing: 12) {
            // Error icon
            Image(systemName: error.severity.iconName)
                .font(.title2)
                .foregroundColor(error.severity.color)
                .frame(width: 24, height: 24)
            
            // Title and category
            VStack(alignment: .leading, spacing: 2) {
                Text(error.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(categoryDescription(error.category))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Message Section
    
    private var messageSection: some View {
        Text(error.message)
            .font(.body)
            .foregroundColor(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    // MARK: - Suggestion Section
    
    private func suggestionSection(_ suggestion: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.subheadline)
                .foregroundColor(.orange)
                .frame(width: 16, height: 16)
            
            Text(suggestion)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Technical Details Section (Debug)
    
    #if DEBUG
    private var technicalDetailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showTechnicalDetails.toggle()
                }
            }) {
                HStack {
                    Text("技術的詳細")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Image(systemName: showTechnicalDetails ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            
            if showTechnicalDetails {
                if let technicalDetails = error.technicalDetails {
                    Text(technicalDetails)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                        .textSelection(.enabled)
                }
            }
        }
    }
    #endif
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 8) {
            ForEach(error.actions.indices, id: \.self) { index in
                let action = error.actions[index]
                
                Button(action: {
                    action.handler()
                    onActionTapped?(action)
                }) {
                    HStack {
                        Text(action.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        if action.style == .primary {
                            Image(systemName: "arrow.right")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(foregroundColorForActionStyle(action.style))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(backgroundColorForActionStyle(action.style))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func categoryDescription(_ category: ErrorCategory) -> String {
        switch category {
        case .input: return "入力エラー"
        case .system: return "システムエラー"
        case .network: return "ネットワークエラー"
        case .permission: return "権限エラー"
        case .data: return "データエラー"
        }
    }
    
    private func backgroundForSeverity(_ severity: ErrorSeverity) -> Color {
        switch severity {
        case .info: return Color.blue.opacity(0.05)
        case .warning: return Color.orange.opacity(0.05)
        case .error: return Color.red.opacity(0.05)
        case .critical: return Color.red.opacity(0.1)
        }
    }
    
    private func foregroundColorForActionStyle(_ style: ErrorAction.ActionStyle) -> Color {
        switch style {
        case .primary: return .white
        case .secondary: return .primary
        case .destructive: return .white
        case .cancel: return .secondary
        }
    }
    
    private func backgroundColorForActionStyle(_ style: ErrorAction.ActionStyle) -> Color {
        switch style {
        case .primary: return .blue
        case .secondary: return Color.gray.opacity(0.2)
        case .destructive: return .red
        case .cancel: return Color.clear
        }
    }
}

// MARK: - Error Alert Modifier

struct ValidationErrorAlert: ViewModifier {
    @Binding var error: (any UserFriendlyError)?
    let onActionTapped: ((ErrorAction) -> Void)?
    
    func body(content: Content) -> some View {
        content
            .alert(
                error?.title ?? "エラー",
                isPresented: .constant(error != nil),
                presenting: error
            ) { error in
                ForEach(error.actions.indices, id: \.self) { index in
                    let action = error.actions[index]
                    Button(action.title, role: buttonRole(for: action.style)) {
                        action.handler()
                        onActionTapped?(action)
                        self.error = nil
                    }
                }
            } message: { error in
                VStack(alignment: .leading, spacing: 8) {
                    Text(error.message)
                    
                    if let suggestion = error.suggestion {
                        Text("💡 \(suggestion)")
                            .font(.caption)
                    }
                }
            }
    }
    
    private func buttonRole(for style: ErrorAction.ActionStyle) -> ButtonRole? {
        switch style {
        case .destructive: return .destructive
        case .cancel: return .cancel
        default: return nil
        }
    }
}

extension View {
    func validationErrorAlert(
        error: Binding<(any UserFriendlyError)?>,
        onActionTapped: ((ErrorAction) -> Void)? = nil
    ) -> some View {
        modifier(ValidationErrorAlert(error: error, onActionTapped: onActionTapped))
    }
}

// MARK: - Error Toast View

struct ValidationErrorToast: View {
    let error: any UserFriendlyError
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        HStack(spacing: 12) {
            // Error icon
            Image(systemName: error.severity.iconName)
                .font(.title3)
                .foregroundColor(error.severity.color)
            
            // Error content
            VStack(alignment: .leading, spacing: 2) {
                Text(error.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(error.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(backgroundForSeverity(error.severity))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(error.severity.color.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .offset(x: dragOffset.width)
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    if abs(value.translation.x) > 100 {
                        onDismiss()
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = .zero
                        }
                    }
                }
        )
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }
    
    private func backgroundForSeverity(_ severity: ErrorSeverity) -> Color {
        switch severity {
        case .info: return Color.blue.opacity(0.1)
        case .warning: return Color.orange.opacity(0.1)
        case .error: return Color.red.opacity(0.1)
        case .critical: return Color.red.opacity(0.2)
        }
    }
}

// MARK: - Error List View

struct ValidationErrorListView: View {
    let errors: [any UserFriendlyError]
    let onErrorTapped: ((any UserFriendlyError) -> Void)?
    let onClearAll: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("エラー履歴")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !errors.isEmpty, let onClearAll = onClearAll {
                    Button("すべてクリア") {
                        onClearAll()
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }
            
            if errors.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    
                    Text("エラーはありません")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Error list
                LazyVStack(spacing: 8) {
                    ForEach(errors.indices, id: \.self) { index in
                        ValidationErrorRowView(
                            error: errors[index],
                            onTapped: { onErrorTapped?(errors[index]) }
                        )
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Error Row View

struct ValidationErrorRowView: View {
    let error: any UserFriendlyError
    let onTapped: (() -> Void)?
    
    var body: some View {
        Button(action: { onTapped?() }) {
            HStack(spacing: 12) {
                // Severity icon
                Image(systemName: error.severity.iconName)
                    .font(.subheadline)
                    .foregroundColor(error.severity.color)
                    .frame(width: 20, height: 20)
                
                // Error content
                VStack(alignment: .leading, spacing: 2) {
                    Text(error.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(error.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Category badge
                Text(categoryBadge(error.category))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(error.category.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(error.category.color.opacity(0.2))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func categoryBadge(_ category: ErrorCategory) -> String {
        switch category {
        case .input: return "入力"
        case .system: return "システム"
        case .network: return "ネット"
        case .permission: return "権限"
        case .data: return "データ"
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            // Sample validation error
            ValidationErrorView(
                error: EnhancedValidationError.valueOutOfRange(
                    value: 300,
                    range: 10...200,
                    dataType: .weight
                ),
                onDismiss: {},
                onActionTapped: { _ in }
            )
            
            // Sample toast
            ValidationErrorToast(
                error: EnhancedValidationError.suspiciousValue(
                    value: 150,
                    dataType: .heartRate,
                    reason: .unusuallyHigh(threshold: 100)
                ),
                onDismiss: {}
            )
            
            // Sample error list
            ValidationErrorListView(
                errors: [
                    EnhancedValidationError.invalidFormat(
                        input: "abc",
                        expectedFormat: "数値",
                        dataType: .weight
                    )
                ],
                onErrorTapped: { _ in },
                onClearAll: {}
            )
        }
        .padding()
    }
}