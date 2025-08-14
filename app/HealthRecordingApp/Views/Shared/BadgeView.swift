import SwiftUI

/// SwiftUI view for displaying badges with sophisticated visual design
/// Supports earned/unearned states with beautiful animations and gradients
struct BadgeView: View {
    let badge: Badge
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Main badge circle with radial gradient
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: badge.colorScheme.accent),
                            Color(hex: badge.colorScheme.base)
                        ],
                        center: .topLeading,
                        startRadius: 5,
                        endRadius: 50
                    )
                )
                .frame(width: 80, height: 80)
                .opacity(badge.isEarned ? 1.0 : 0.3)
                .shadow(
                    color: Color(hex: badge.colorScheme.accent).opacity(badge.isEarned ? 0.6 : 0.2),
                    radius: badge.isEarned ? 8 : 4,
                    x: 0,
                    y: 4
                )
            
            // Decorative border ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: badge.colorScheme.accent).opacity(0.8),
                            Color(hex: badge.colorScheme.base).opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: badge.isEarned ? 3 : 2
                )
                .frame(width: 85, height: 85)
                .opacity(badge.isEarned ? 1.0 : 0.4)
            
            // Badge icon
            Image(systemName: badge.iconName)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color(hex: badge.colorScheme.accent).opacity(0.9)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(badge.isEarned ? 1.0 : 0.5)
                .scaleEffect(badge.isEarned ? 1.0 : 0.8)
            
            // Lock overlay for unearned badges
            if !badge.isEarned {
                ZStack {
                    // Semi-transparent overlay
                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 80, height: 80)
                    
                    // Lock icon
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                }
            }
            
            // Sparkle effect for earned badges
            if badge.isEarned {
                ForEach(0..<6, id: \.self) { index in
                    Image(systemName: "sparkle")
                        .font(.system(size: 8, weight: .light))
                        .foregroundColor(Color(hex: badge.colorScheme.accent))
                        .opacity(isAnimating ? 0.8 : 0.3)
                        .offset(
                            x: cos(Double(index) * .pi / 3) * 45,
                            y: sin(Double(index) * .pi / 3) * 45
                        )
                        .scaleEffect(isAnimating ? 1.2 : 0.8)
                        .animation(
                            .easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                            value: isAnimating
                        )
                }
            }
        }
        .scaleEffect(badge.isEarned ? 1.0 : 0.85)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: badge.isEarned)
        .onAppear {
            if badge.isEarned {
                isAnimating = true
            }
        }
    }
}

/// Compact badge view for smaller display areas
struct BadgeViewCompact: View {
    let badge: Badge
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: badge.colorScheme.accent),
                            Color(hex: badge.colorScheme.base)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .opacity(badge.isEarned ? 1.0 : 0.4)
            
            Image(systemName: badge.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .opacity(badge.isEarned ? 1.0 : 0.6)
            
            if !badge.isEarned {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                    .offset(x: 12, y: 12)
            }
        }
        .scaleEffect(badge.isEarned ? 1.0 : 0.9)
    }
}

/// Badge view with label for collection displays
struct BadgeViewWithLabel: View {
    let badge: Badge
    let showProgress: Bool
    let progress: Double
    
    init(badge: Badge, showProgress: Bool = false, progress: Double = 0.0) {
        self.badge = badge
        self.showProgress = showProgress
        self.progress = progress
    }
    
    var body: some View {
        VStack(spacing: 8) {
            BadgeView(badge: badge)
            
            VStack(spacing: 4) {
                Text(badge.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(badge.displayDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                if showProgress && !badge.isEarned {
                    ProgressView(value: progress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: badge.colorScheme.accent)))
                        .scaleEffect(x: 1, y: 0.5)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption2)
                        .foregroundColor(Color(hex: badge.colorScheme.accent))
                }
                
                if badge.isEarned, let earnedDate = badge.earnedDate {
                    Text("獲得日: \(earnedDate, formatter: dateFormatter)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: 120)
        .padding(.vertical, 8)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }
}

/// Color extension for hex string support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Previews

#Preview("Badge View States") {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            // Earned badge
            BadgeView(badge: createEarnedBadge(
                name: "はじめの一歩",
                description: "初回の健康記録を達成",
                type: .milestone,
                requirement: .recordCount(count: 1),
                iconName: "star.fill",
                colorScheme: .gold
            ))
            
            // Unearned badge
            BadgeView(badge: try! Badge(
                name: "継続は力なり",
                description: "7日連続記録を達成",
                type: .streak,
                requirement: .streak(days: 7),
                iconName: "flame.fill",
                colorScheme: .silver
            ))
        }
        
        HStack(spacing: 20) {
            BadgeViewCompact(badge: createEarnedBadge(
                name: "記録マスター",
                description: "10回の健康記録を達成",
                type: .milestone,
                requirement: .recordCount(count: 10),
                iconName: "chart.line.uptrend.xyaxis",
                colorScheme: .bronze
            ))
            
            BadgeViewCompact(badge: try! Badge(
                name: "健康マスター",
                description: "総合的な健康目標を達成",
                type: .achievement,
                requirement: .special,
                iconName: "heart.fill",
                colorScheme: .platinum
            ))
        }
        
        BadgeViewWithLabel(
            badge: try! Badge(
                name: "データコレクター",
                description: "50回の健康記録を達成",
                type: .milestone,
                requirement: .recordCount(count: 50),
                iconName: "folder.fill",
                colorScheme: .gold
            ),
            showProgress: true,
            progress: 0.6
        )
    }
    .padding()
}

// Helper for badge modification in previews
private func createEarnedBadge(
    name: String,
    description: String,
    type: BadgeType,
    requirement: BadgeRequirement,
    iconName: String,
    colorScheme: BadgeColorScheme
) -> Badge {
    let badge = try! Badge(
        name: name,
        description: description,
        type: type,
        requirement: requirement,
        iconName: iconName,
        colorScheme: colorScheme
    )
    badge.isEarned = true
    badge.earnedDate = Date()
    return badge
}