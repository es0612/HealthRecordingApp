import SwiftUI

struct ErrorView: View {
    // MARK: - Properties
    let error: Error
    let title: String?
    let message: String?
    let primaryAction: ErrorAction?
    let secondaryAction: ErrorAction?
    
    // MARK: - Initialization
    init(
        error: Error,
        title: String? = nil,
        message: String? = nil,
        primaryAction: ErrorAction? = nil,
        secondaryAction: ErrorAction? = nil
    ) {
        self.error = error
        self.title = title
        self.message = message
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Error Icon
            errorIcon
            
            // Title and Message
            VStack(spacing: 12) {
                Text(displayTitle)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(displayMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            
            // Action Buttons
            actionButtons
        }
        .padding(32)
        .background(Color.primary.colorInvert())
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Computed Properties
    
    private var displayTitle: String {
        if let title = title {
            return title
        }
        
        return errorCategory.defaultTitle
    }
    
    private var displayMessage: String {
        if let message = message {
            return message
        }
        
        return errorCategory.defaultMessage
    }
    
    private var errorCategory: ErrorCategory {
        if let healthAppError = error as? any HealthAppError {
            switch healthAppError {
            case is HealthKitError:
                return .healthKit
            case is DataError:
                return .data
            case is NetworkError:
                return .network
            default:
                return .general
            }
        }
        
        return .general
    }
    
    private var errorIcon: some View {
        Image(systemName: errorCategory.iconName)
            .font(.system(size: 48, weight: .medium))
            .foregroundColor(errorCategory.color)
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Primary Action
            if let primaryAction = primaryAction {
                Button(action: primaryAction.action) {
                    Text(primaryAction.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            // Secondary Action
            if let secondaryAction = secondaryAction {
                Button(action: secondaryAction.action) {
                    Text(secondaryAction.title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct ErrorAction {
    let title: String
    let action: () -> Void
    
    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
}

enum ErrorCategory {
    case healthKit
    case data
    case network
    case permission
    case general
    
    var iconName: String {
        switch self {
        case .healthKit: return "heart.text.square"
        case .data: return "externaldrive.trianglebadge.exclamationmark"
        case .network: return "wifi.exclamationmark"
        case .permission: return "lock.trianglebadge.exclamationmark"
        case .general: return "exclamationmark.triangle"
        }
    }
    
    var color: Color {
        switch self {
        case .healthKit: return .red
        case .data: return .orange
        case .network: return .blue
        case .permission: return .purple
        case .general: return .red
        }
    }
    
    var defaultTitle: String {
        switch self {
        case .healthKit: return "HealthKitエラー"
        case .data: return "データエラー"
        case .network: return "ネットワークエラー"
        case .permission: return "アクセス許可が必要です"
        case .general: return "エラーが発生しました"
        }
    }
    
    var defaultMessage: String {
        switch self {
        case .healthKit: return "HealthKitとの連携で問題が発生しました。設定を確認してください。"
        case .data: return "データの読み込みまたは保存で問題が発生しました。"
        case .network: return "インターネット接続を確認してください。"
        case .permission: return "この機能を使用するには許可が必要です。"
        case .general: return "予期しないエラーが発生しました。しばらく待ってからお試しください。"
        }
    }
}

// MARK: - Specialized Error Views

struct HealthKitErrorView: View {
    let error: Error
    let onRetry: () -> Void
    let onOpenSettings: () -> Void
    
    var body: some View {
        ErrorView(
            error: error,
            title: "HealthKitアクセスエラー",
            message: "ヘルスケアデータにアクセスできません。設定でアクセス許可を確認してください。",
            primaryAction: ErrorAction("設定を開く", action: onOpenSettings),
            secondaryAction: ErrorAction("再試行", action: onRetry)
        )
    }
}

struct NetworkErrorView: View {
    let error: Error
    let onRetry: () -> Void
    
    var body: some View {
        ErrorView(
            error: error,
            title: "接続エラー",
            message: "インターネット接続を確認して、もう一度お試しください。",
            primaryAction: ErrorAction("再試行", action: onRetry)
        )
    }
}

struct DataErrorView: View {
    let error: Error
    let onRetry: () -> Void
    let onRefresh: () -> Void
    
    var body: some View {
        ErrorView(
            error: error,
            title: "データ読み込みエラー",
            message: "データの読み込みに失敗しました。",
            primaryAction: ErrorAction("再読み込み", action: onRefresh),
            secondaryAction: ErrorAction("再試行", action: onRetry)
        )
    }
}

struct PermissionErrorView: View {
    let feature: String
    let onRequestPermission: () -> Void
    let onSkip: (() -> Void)?
    
    var body: some View {
        ErrorView(
            error: PermissionError.denied(feature),
            title: "アクセス許可が必要です",
            message: "\(feature)を使用するには許可が必要です。",
            primaryAction: ErrorAction("許可する", action: onRequestPermission),
            secondaryAction: onSkip.map { ErrorAction("スキップ", action: $0) }
        )
    }
}

// MARK: - Compact Error Views

struct CompactErrorView: View {
    let message: String
    let onRetry: (() -> Void)?
    
    init(message: String, onRetry: (() -> Void)? = nil) {
        self.message = message
        self.onRetry = onRetry
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            if let onRetry = onRetry {
                Button("再試行") {
                    onRetry()
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct InlineErrorView: View {
    let message: String
    let isVisible: Bool
    
    var body: some View {
        if isVisible {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
                
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(1)
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
            .animation(.easeInOut(duration: 0.3), value: isVisible)
        }
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    let type: BannerType
    let onDismiss: (() -> Void)?
    let onAction: (() -> Void)?
    let actionTitle: String?
    
    init(
        message: String,
        type: BannerType = .error,
        onDismiss: (() -> Void)? = nil,
        onAction: (() -> Void)? = nil,
        actionTitle: String? = nil
    ) {
        self.message = message
        self.type = type
        self.onDismiss = onDismiss
        self.onAction = onAction
        self.actionTitle = actionTitle
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.iconName)
                .foregroundColor(type.color)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            Spacer()
            
            HStack(spacing: 8) {
                if let onAction = onAction, let actionTitle = actionTitle {
                    Button(actionTitle) {
                        onAction()
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
                
                if let onDismiss = onDismiss {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(type.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(type.borderColor, lineWidth: 1)
        )
    }
}

enum BannerType {
    case error
    case warning
    case info
    
    var iconName: String {
        switch self {
        case .error: return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .error: return .red.opacity(0.1)
        case .warning: return .orange.opacity(0.1)
        case .info: return .blue.opacity(0.1)
        }
    }
    
    var borderColor: Color {
        switch self {
        case .error: return .red.opacity(0.3)
        case .warning: return .orange.opacity(0.3)
        case .info: return .blue.opacity(0.3)
        }
    }
}

// MARK: - Error Types

enum PermissionError: LocalizedError {
    case denied(String)
    
    var errorDescription: String? {
        switch self {
        case .denied(let feature):
            return "\(feature)のアクセス許可が拒否されました。"
        }
    }
}

// MARK: - Error State Container

struct ErrorStateView<Content: View>: View {
    let isError: Bool
    let error: Error?
    let onRetry: () -> Void
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        if isError, let error = error {
            ErrorView(
                error: error,
                primaryAction: ErrorAction("再試行", action: onRetry)
            )
        } else {
            content()
        }
    }
}

// MARK: - Preview

#Preview("Error Views") {
    ScrollView {
        VStack(spacing: 20) {
            ErrorView(
                error: MockNetworkError.noConnection,
                primaryAction: ErrorAction("再試行") {},
                secondaryAction: ErrorAction("キャンセル") {}
            )
            
            CompactErrorView(
                message: "データの読み込みに失敗しました",
                onRetry: {}
            )
            
            ErrorBanner(
                message: "HealthKitとの同期でエラーが発生しました",
                type: .error,
                onDismiss: {},
                onAction: {},
                actionTitle: "設定"
            )
        }
        .padding()
    }
}

#Preview("Specialized Errors") {
    VStack(spacing: 20) {
        HealthKitErrorView(
            error: MockHealthKitError.accessDenied,
            onRetry: {},
            onOpenSettings: {}
        )
        
        PermissionErrorView(
            feature: "HealthKit",
            onRequestPermission: {},
            onSkip: {}
        )
    }
    .padding()
}

// Mock error types for preview
private enum MockNetworkError: LocalizedError {
    case noConnection
    
    var errorDescription: String? {
        return "インターネット接続がありません"
    }
}

private enum MockHealthKitError: LocalizedError {
    case accessDenied
    
    var errorDescription: String? {
        return "HealthKitアクセスが拒否されました"
    }
}