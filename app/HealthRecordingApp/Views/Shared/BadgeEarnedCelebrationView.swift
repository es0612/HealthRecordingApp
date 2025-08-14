import SwiftUI

/// Celebration view displayed when a user earns a new badge
/// Features confetti animation, badge spotlight, and congratulatory message
struct BadgeEarnedCelebrationView: View {
    let badge: Badge
    let onDismiss: () -> Void
    
    @State private var isAnimating = false
    @State private var showConfetti = false
    @State private var badgeScale: CGFloat = 0.1
    @State private var titleOpacity: Double = 0
    @State private var messageOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
            // Background with blur effect
            Color.black
                .opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissWithAnimation()
                }
            
            // Confetti layer
            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
            }
            
            // Main celebration card
            VStack(spacing: 24) {
                // Badge with spotlight effect
                ZStack {
                    // Spotlight background
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .blur(radius: 20)
                        .opacity(isAnimating ? 1 : 0)
                    
                    // Enlarged badge
                    BadgeView(badge: badge)
                        .scaleEffect(badgeScale)
                        .rotation3DEffect(
                            .degrees(isAnimating ? 360 : 0),
                            axis: (x: 0, y: 1, z: 0)
                        )
                        .shadow(
                            color: Color(hex: badge.colorScheme.accent).opacity(0.6),
                            radius: 20,
                            x: 0,
                            y: 10
                        )
                }
                
                // Congratulations text
                VStack(spacing: 12) {
                    Text("おめでとうございます！")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(hex: badge.colorScheme.accent),
                                    Color(hex: badge.colorScheme.base)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(titleOpacity)
                    
                    Text("新しいバッジを獲得しました")
                        .font(.headline)
                        .foregroundColor(.white)
                        .opacity(titleOpacity)
                }
                
                // Badge details
                VStack(spacing: 8) {
                    Text(badge.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .opacity(messageOpacity)
                    
                    Text(badge.displayDescription)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .opacity(messageOpacity)
                    
                    // Earned date
                    if let earnedDate = badge.earnedDate {
                        Text("獲得日時: \(earnedDate, formatter: dateTimeFormatter)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .opacity(messageOpacity)
                    }
                }
                
                // Share button
                Button(action: shareAchievement) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("成果を共有")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(hex: badge.colorScheme.accent),
                                Color(hex: badge.colorScheme.base)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 25))
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .opacity(buttonOpacity)
                
                // Dismiss button
                Button("続ける") {
                    dismissWithAnimation()
                }
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .opacity(buttonOpacity)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 40)
            }
            .onAppear {
                startCelebrationAnimation()
                generateConfetti(screenWidth: geometry.size.width, screenHeight: geometry.size.height)
            }
        }
    }
    
    private func startCelebrationAnimation() {
        // Start confetti immediately
        showConfetti = true
        
        // Badge scale animation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
            badgeScale = 1.5
            isAnimating = true
        }
        
        // Title animation
        withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
            titleOpacity = 1
        }
        
        // Message animation
        withAnimation(.easeOut(duration: 0.6).delay(0.6)) {
            messageOpacity = 1
        }
        
        // Button animation
        withAnimation(.easeOut(duration: 0.6).delay(0.9)) {
            buttonOpacity = 1
        }
    }
    
    private func dismissWithAnimation() {
        withAnimation(.easeIn(duration: 0.3)) {
            badgeScale = 0.1
            titleOpacity = 0
            messageOpacity = 0
            buttonOpacity = 0
            showConfetti = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
    
    private func shareAchievement() {
        // TODO: Implement sharing functionality
        // This would integrate with SocialShareService
        print("Sharing badge achievement: \(badge.displayName)")
    }
    
    private var dateTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

/// Animated confetti effect for celebration
struct ConfettiView: View {
    @State private var confettiParticles: [ConfettiParticle] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiParticles, id: \.id) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .opacity(particle.opacity)
                        .animation(
                            .linear(duration: particle.animationDuration)
                            .repeatForever(autoreverses: false),
                            value: particle.position
                        )
                }
            }
        }
    }
    
    private func generateConfetti(screenWidth: Double = 400, screenHeight: Double = 800) {
        let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink]
        
        for _ in 0..<100 {
            let particle = ConfettiParticle(
                id: UUID(),
                color: colors.randomElement() ?? .blue,
                size: Double.random(in: 4...10),
                position: CGPoint(
                    x: Double.random(in: 0...screenWidth),
                    y: -20
                ),
                targetPosition: CGPoint(
                    x: Double.random(in: 0...screenWidth),
                    y: screenHeight + 20
                ),
                opacity: Double.random(in: 0.6...1.0),
                animationDuration: Double.random(in: 2...4)
            )
            
            confettiParticles.append(particle)
            
            // Animate particle position
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let index = confettiParticles.firstIndex(where: { $0.id == particle.id }) {
                    confettiParticles[index].position = particle.targetPosition
                }
            }
        }
        
        // Remove particles after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            confettiParticles.removeAll()
        }
    }
}

/// Individual confetti particle data
struct ConfettiParticle {
    let id: UUID
    let color: Color
    let size: Double
    var position: CGPoint
    let targetPosition: CGPoint
    let opacity: Double
    let animationDuration: Double
}

/// Streak indicator view for showing consecutive achievements
struct StreakIndicatorView: View {
    let streakCount: Int
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundColor(isActive ? .orange : .gray)
                .symbolEffect(.pulse, isActive: isActive)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(streakCount)日連続")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(isActive ? .primary : .secondary)
                
                Text("継続記録中")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isActive ? Color.orange.opacity(0.1) : Color.gray.opacity(0.1))
                .stroke(isActive ? Color.orange.opacity(0.3) : Color.gray.opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(isActive ? 1.05 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isActive)
    }
}

// MARK: - Previews

#Preview("Badge Earned Celebration") {
    BadgeEarnedCelebrationView(
        badge: {
            let badge = try! Badge(
                name: "はじめの一歩",
                description: "初回の健康記録を達成しました！素晴らしいスタートです。",
                type: .milestone,
                requirement: .recordCount(count: 1),
                iconName: "star.fill",
                colorScheme: .gold
            )
            badge.isEarned = true
            badge.earnedDate = Date()
            return badge
        }(),
        onDismiss: {}
    )
}

#Preview("Streak Indicator") {
    VStack(spacing: 20) {
        StreakIndicatorView(streakCount: 7, isActive: true)
        StreakIndicatorView(streakCount: 3, isActive: false)
    }
    .padding()
}