import SwiftUI

struct LoadingView: View {
    // MARK: - Properties
    let message: String
    let showCancelButton: Bool
    let onCancel: (() -> Void)?
    
    @State private var isAnimating = false
    
    // MARK: - Initialization
    init(
        message: String = "読み込み中...",
        showCancelButton: Bool = false,
        onCancel: (() -> Void)? = nil
    ) {
        self.message = message
        self.showCancelButton = showCancelButton
        self.onCancel = onCancel
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Loading Animation
            loadingAnimation
            
            // Message
            Text(message)
                .font(.headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            // Cancel Button (if enabled)
            if showCancelButton, let onCancel = onCancel {
                Button("キャンセル") {
                    onCancel()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
        }
        .padding(32)
        .background(Color.primary.colorInvert())
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
    
    private var loadingAnimation: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 4)
                .frame(width: 60, height: 60)
            
            // Animated ring
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 60, height: 60)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
        }
    }
}

// MARK: - Specialized Loading Views

struct HealthDataLoadingView: View {
    var body: some View {
        LoadingView(message: "健康データを読み込み中...")
    }
}

struct SyncLoadingView: View {
    let onCancel: () -> Void
    
    var body: some View {
        LoadingView(
            message: "HealthKitと同期中...\n少々お待ちください",
            showCancelButton: true,
            onCancel: onCancel
        )
    }
}

struct TrendAnalysisLoadingView: View {
    var body: some View {
        LoadingView(message: "トレンドを分析中...")
    }
}

struct GoalCalculationLoadingView: View {
    var body: some View {
        LoadingView(message: "目標進捗を計算中...")
    }
}

// MARK: - Compact Loading Views

struct CompactLoadingView: View {
    let message: String
    
    init(message: String = "読み込み中...") {
        self.message = message
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .clipShape(Capsule())
    }
}

struct InlineLoadingView: View {
    let message: String
    
    init(message: String = "読み込み中...") {
        self.message = message
    }
    
    var body: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.7)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    let isVisible: Bool
    let message: String
    let onCancel: (() -> Void)?
    
    init(
        isVisible: Bool,
        message: String = "読み込み中...",
        onCancel: (() -> Void)? = nil
    ) {
        self.isVisible = isVisible
        self.message = message
        self.onCancel = onCancel
    }
    
    var body: some View {
        if isVisible {
            ZStack {
                // Background overlay
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                // Loading content
                LoadingView(
                    message: message,
                    showCancelButton: onCancel != nil,
                    onCancel: onCancel
                )
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: isVisible)
        }
    }
}

// MARK: - Card Loading States

struct LoadingCard: View {
    let height: CGFloat
    let cornerRadius: CGFloat
    
    init(height: CGFloat = 120, cornerRadius: CGFloat = 12) {
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.1))
            .frame(height: height)
            .overlay(
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("読み込み中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            )
            .redacted(reason: .placeholder)
    }
}

struct SkeletonCard: View {
    let height: CGFloat
    let cornerRadius: CGFloat
    
    @State private var isAnimating = false
    
    init(height: CGFloat = 120, cornerRadius: CGFloat = 12) {
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        Color.gray.opacity(0.1),
                        Color.gray.opacity(0.2),
                        Color.gray.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: height)
            .scaleEffect(isAnimating ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Preview

#Preview("Loading Views") {
    VStack(spacing: 20) {
        LoadingView()
        
        CompactLoadingView(message: "データを同期中...")
        
        InlineLoadingView()
        
        LoadingCard()
    }
    .padding()
}

#Preview("Specialized Loading") {
    VStack(spacing: 20) {
        HealthDataLoadingView()
        
        TrendAnalysisLoadingView()
        
        GoalCalculationLoadingView()
    }
    .padding()
}

#Preview("Loading Overlay") {
    ZStack {
        // Sample background content
        VStack {
            Text("Background Content")
            Rectangle()
                .fill(Color.blue.opacity(0.3))
                .frame(height: 200)
        }
        .padding()
        
        LoadingOverlay(
            isVisible: true,
            message: "HealthKitと同期中...",
            onCancel: {}
        )
    }
}