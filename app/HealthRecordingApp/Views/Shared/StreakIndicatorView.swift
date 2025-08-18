import SwiftUI

struct StreakIndicatorView: View {
    let streakCount: Int
    let isActive: Bool
    
    @State private var animationService = ContinuationAnimationService()
    @State private var isAnimating = false
    @State private var flameScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.0
    @State private var streakTextOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 8) {
            // Flame icon with animated glow
            ZStack {
                // Glow effect
                Circle()
                    .fill(RadialGradient(
                        colors: [flameColor.opacity(0.3), Color.clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: 25
                    ))
                    .frame(width: 40, height: 40)
                    .opacity(glowOpacity)
                    .scaleEffect(1.5)
                
                // Flame icon
                Image(systemName: flameIconName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(flameColor)
                    .scaleEffect(flameScale)
            }
            
            // Streak count with animated entrance
            VStack(alignment: .leading, spacing: 2) {
                Text("\(streakCount)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(streakCount > 0 ? .primary : .secondary)
                    .offset(y: streakTextOffset)
                
                Text("日連続")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // Streak level indicator
            if streakCount > 0 {
                streakLevelBadge
            }
        }
        .continuationAnimations()
        .onAppear {
            startIdleAnimation()
        }
        .onChange(of: streakCount) { oldValue, newValue in
            if newValue > oldValue {
                Task {
                    await animationService.triggerStreakAnimation(streakCount: newValue)
                    triggerStreakUpdateAnimation()
                }
            }
        }
    }
    
    private var flameIconName: String {
        switch streakCount {
        case 0: return "flame"
        case 1...3: return "flame.fill"
        case 4...7: return "flame.fill"
        case 8...14: return "flame.fill"
        case 15...30: return "flame.fill"
        default: return "flame.fill"
        }
    }
    
    private var flameColor: Color {
        guard isActive && streakCount > 0 else { return .gray }
        
        switch streakCount {
        case 1...3: return .orange
        case 4...7: return .red
        case 8...14: return .purple
        case 15...30: return .blue
        default: return .gold
        }
    }
    
    private var streakLevelBadge: some View {
        Group {
            if let level = getStreakLevel() {
                Text(level.name)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(level.color)
                    )
                    .shadow(radius: 2)
            }
        }
    }
    
    private func getStreakLevel() -> StreakLevel? {
        switch streakCount {
        case 7...13: return StreakLevel(name: "🔥", color: .orange)
        case 14...29: return StreakLevel(name: "🚀", color: .purple)
        case 30...59: return StreakLevel(name: "💎", color: .blue)
        case 60...89: return StreakLevel(name: "👑", color: .gold)
        case 90...: return StreakLevel(name: "🏆", color: .red)
        default: return nil
        }
    }
    
    private func startIdleAnimation() {
        guard isActive && streakCount > 0 else { return }
        
        // Subtle glow animation for active streaks
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            glowOpacity = 0.6
        }
        
        // Gentle flame flickering
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                flameScale = Double.random(in: 0.95...1.05)
            }
        }
    }
    
    private func triggerStreakUpdateAnimation() {
        // Scale animation for the flame
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) {
            flameScale = 1.3
        }
        
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 15).delay(0.2)) {
            flameScale = 1.0
        }
        
        // Text bounce animation
        withAnimation(.interpolatingSpring(stiffness: 400, damping: 10)) {
            streakTextOffset = -5
        }
        
        withAnimation(.interpolatingSpring(stiffness: 400, damping: 10).delay(0.1)) {
            streakTextOffset = 0
        }
        
        // Enhanced glow for celebration
        withAnimation(.easeOut(duration: 0.5)) {
            glowOpacity = 1.0
        }
        
        withAnimation(.easeInOut(duration: 1.0).delay(0.5)) {
            glowOpacity = 0.6
        }
    }
}

struct StreakLevel {
    let name: String
    let color: Color
}

// MARK: - Previews

#Preview("Active Streak") {
    VStack(spacing: 20) {
        StreakIndicatorView(streakCount: 0, isActive: false)
        StreakIndicatorView(streakCount: 3, isActive: true)
        StreakIndicatorView(streakCount: 7, isActive: true)
        StreakIndicatorView(streakCount: 15, isActive: true)
        StreakIndicatorView(streakCount: 30, isActive: true)
        StreakIndicatorView(streakCount: 100, isActive: true)
    }
    .padding()
}