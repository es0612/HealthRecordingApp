import SwiftUI
import HealthKit

struct HealthKitPermissionView: View {
    // MARK: - Properties
    @StateObject private var authManager: HealthKitAuthenticationManager
    @State private var showingError = false
    @State private var errorMessage = ""
    
    let onPermissionGranted: () -> Void
    let onPermissionDenied: () -> Void
    let onSkip: (() -> Void)?
    
    // MARK: - Initialization
    init(
        authManager: HealthKitAuthenticationManager,
        onPermissionGranted: @escaping () -> Void,
        onPermissionDenied: @escaping () -> Void,
        onSkip: (() -> Void)? = nil
    ) {
        self._authManager = StateObject(wrappedValue: authManager)
        self.onPermissionGranted = onPermissionGranted
        self.onPermissionDenied = onPermissionDenied
        self.onSkip = onSkip
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Illustration
                        illustrationView
                        
                        // Title and Description
                        titleSection
                        
                        // Benefits
                        benefitsSection
                        
                        // Data Types
                        dataTypesSection
                        
                        // Privacy Information
                        privacySection
                    }
                    .padding()
                }
                
                // Action Buttons
                actionButtons
            }
            .navigationBarBackButtonHidden(true)
            .overlay {
                if authManager.isAuthenticationInProgress {
                    LoadingOverlay(
                        isVisible: true,
                        message: "HealthKitアクセスを確認中..."
                    )
                }
            }
            .alert("エラー", isPresented: $showingError) {
                Button("OK") {
                    showingError = false
                }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Views
    
    private var headerView: some View {
        HStack {
            Button("戻る") {
                // Handle back navigation
            }
            .foregroundColor(.accentColor)
            
            Spacer()
            
            if let onSkip = onSkip {
                Button("スキップ") {
                    onSkip()
                }
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.primary.colorInvert())
    }
    
    private var illustrationView: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background Circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.red.opacity(0.1), Color.red.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                // HealthKit Icon
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundColor(.red)
            }
            
            // App Integration Visualization
            HStack(spacing: 20) {
                // Health App
                VStack(spacing: 8) {
                    Image(systemName: "heart.circle.fill")
                        .font(.title)
                        .foregroundColor(.red)
                    Text("ヘルスケア")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Connection Arrow
                Image(systemName: "arrow.left.and.right")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                // This App
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.title3)
                                .foregroundColor(.white)
                        )
                    Text("このアプリ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var titleSection: some View {
        VStack(spacing: 16) {
            Text("ヘルスケアデータへのアクセス")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Apple ヘルスケアからデータを読み取り、より正確な健康管理をサポートします")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
        }
    }
    
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("メリット")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                BenefitRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "自動データ同期",
                    description: "手動入力の手間なく、健康データを自動で記録"
                )
                
                BenefitRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "詳細なトレンド分析",
                    description: "長期間のデータから意味のあるインサイトを生成"
                )
                
                BenefitRow(
                    icon: "target",
                    title: "パーソナライズされた目標",
                    description: "あなたのデータに基づいた現実的な目標を提案"
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var dataTypesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("アクセスするデータ")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                DataTypeRow(
                    icon: "scalemass.fill",
                    name: "体重",
                    description: "体重の変化を追跡",
                    color: .purple
                )
                
                DataTypeRow(
                    icon: "figure.walk",
                    name: "歩数",
                    description: "日々の活動量を記録",
                    color: .blue
                )
                
                DataTypeRow(
                    icon: "flame.fill",
                    name: "消費カロリー",
                    description: "エネルギー消費を監視",
                    color: .orange
                )
                
                DataTypeRow(
                    icon: "heart.fill",
                    name: "心拍数",
                    description: "心血管系の健康を評価",
                    color: .red
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Text("プライバシーとセキュリティ")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                PrivacyPoint("データはデバイス上で暗号化されて保存されます")
                PrivacyPoint("第三者とデータを共有することはありません")
                PrivacyPoint("いつでも設定からアクセス許可を変更できます")
                PrivacyPoint("Apple ヘルスケアのプライバシー設定が適用されます")
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Primary Action
            Button(action: requestHealthKitPermission) {
                HStack {
                    if authManager.isAuthenticationInProgress {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    
                    Text(authManager.isAuthenticationInProgress ? "許可を要求中..." : "HealthKitアクセスを許可")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor)
                )
            }
            .disabled(authManager.isAuthenticationInProgress)
            
            // Secondary Action
            Button("後で設定する") {
                onPermissionDenied()
            }
            .foregroundColor(.secondary)
            .padding(.bottom)
        }
        .padding(.horizontal)
        .background(Color.primary.colorInvert())
    }
    
    // MARK: - Actions
    
    private func requestHealthKitPermission() {
        Task {
            await performHealthKitRequest()
        }
    }
    
    @MainActor
    private func performHealthKitRequest() async {
        // Check if HealthKit is available first
        guard authManager.isHealthKitAvailable else {
            errorMessage = "このデバイスではHealthKitが利用できません。"
            showingError = true
            return
        }
        
        let result = await authManager.requestAuthorization()
        
        switch result {
        case .authorized(_):
            // Success - at least some data types were authorized
            onPermissionGranted()
            
        case .denied:
            // User denied permission
            onPermissionDenied()
            
        case .unavailable:
            // HealthKit not available
            errorMessage = "このデバイスではHealthKitが利用できません。"
            showingError = true
            
        case .error(let error):
            // Error occurred during authorization
            errorMessage = handlePermissionError(error)
            showingError = true
        }
    }
    
    private func handlePermissionError(_ error: Error) -> String {
        if let healthAppError = error as? any HealthAppError {
            return healthAppError.localizedDescription
        }
        
        return "HealthKitアクセスの要求中にエラーが発生しました。\n\nエラー: \(error.localizedDescription)"
    }
}

// MARK: - Supporting Views

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            }
        }
    }
}

struct DataTypeRow: View {
    let icon: String
    let name: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(.green)
        }
        .padding(.vertical, 4)
    }
}

struct PrivacyPoint: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
                .padding(.top, 2)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(nil)
        }
    }
}

// MARK: - Supporting Types

// Note: Permission status and errors are now handled by HealthKitAuthenticationManager

// MARK: - Convenience Initializers

extension HealthKitPermissionView {
    init(
        authManager: HealthKitAuthenticationManager,
        onCompletion: @escaping (Bool) -> Void
    ) {
        self.init(
            authManager: authManager,
            onPermissionGranted: { onCompletion(true) },
            onPermissionDenied: { onCompletion(false) }
        )
    }
}

// MARK: - Preview

#Preview {
    HealthKitPermissionView(
        authManager: HealthKitAuthenticationManager.preview(),
        onPermissionGranted: {
            print("Permission granted")
        },
        onPermissionDenied: {
            print("Permission denied")
        },
        onSkip: {
            print("Skipped")
        }
    )
}