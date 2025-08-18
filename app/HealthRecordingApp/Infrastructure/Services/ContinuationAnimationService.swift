import Foundation
import SwiftUI

// MARK: - Continuation Animation Service Protocol

protocol ContinuationAnimationServiceProtocol {
    func triggerStreakAnimation(streakCount: Int) async
    func triggerProgressAnimation(progress: Double, type: HealthDataType) async
    func triggerMotivationalPulse() async
    func triggerDataEntrySuccess() async
    func triggerGoalProgressUpdate(progress: Double) async
    func triggerDailyCheckInReminder() async
}

// MARK: - Continuation Animation Service

@MainActor
final class ContinuationAnimationService: ContinuationAnimationServiceProtocol {
    
    private let logger: AILoggerProtocol
    private var animationQueue: [AnimationEvent] = []
    private var isProcessingAnimations = false
    
    init(logger: AILoggerProtocol = AILogger()) {
        self.logger = logger
    }
    
    // MARK: - Public Methods
    
    func triggerStreakAnimation(streakCount: Int) async {
        let animation = AnimationEvent.streak(count: streakCount, intensity: getStreakIntensity(for: streakCount))
        await queueAnimation(animation)
    }
    
    func triggerProgressAnimation(progress: Double, type: HealthDataType) async {
        let animation = AnimationEvent.progress(
            value: progress,
            type: type,
            milestone: getProgressMilestone(for: progress)
        )
        await queueAnimation(animation)
    }
    
    func triggerMotivationalPulse() async {
        let animation = AnimationEvent.motivationalPulse(
            message: getRandomMotivationalMessage(),
            intensity: .medium
        )
        await queueAnimation(animation)
    }
    
    func triggerDataEntrySuccess() async {
        let animation = AnimationEvent.dataEntrySuccess(
            celebration: .sparkle,
            duration: 1.5
        )
        await queueAnimation(animation)
    }
    
    func triggerGoalProgressUpdate(progress: Double) async {
        let milestoneReached = isProgressMilestone(progress)
        let animation = AnimationEvent.goalProgress(
            progress: progress,
            milestoneReached: milestoneReached,
            encouragement: getProgressEncouragement(for: progress)
        )
        await queueAnimation(animation)
    }
    
    func triggerDailyCheckInReminder() async {
        let animation = AnimationEvent.dailyReminder(
            type: .gentle,
            message: "今日の記録はいかがですか？",
            urgency: .low
        )
        await queueAnimation(animation)
    }
    
    // MARK: - Private Methods
    
    private func queueAnimation(_ animation: AnimationEvent) async {
        animationQueue.append(animation)
        
        logger.debug("Animation queued", context: [
            "animation_type": animation.type,
            "queue_length": animationQueue.count
        ])
        
        if !isProcessingAnimations {
            await processAnimationQueue()
        }
    }
    
    private func processAnimationQueue() async {
        isProcessingAnimations = true
        
        while !animationQueue.isEmpty {
            let animation = animationQueue.removeFirst()
            await executeAnimation(animation)
            
            // Small delay between animations to prevent overwhelming
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        }
        
        isProcessingAnimations = false
    }
    
    private func executeAnimation(_ animation: AnimationEvent) async {
        let startTime = Date()
        
        do {
            logger.info("Executing animation", context: [
                "animation_type": animation.type,
                "animation_id": animation.id.uuidString
            ])
            
            // Post notification for UI components to listen to
            NotificationCenter.default.post(
                name: .continuationAnimationTriggered,
                object: animation,
                userInfo: ["animation": animation]
            )
            
            // Wait for animation duration
            let duration = animation.duration
            try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            
            let executionTime = Date().timeIntervalSince(startTime)
            logger.logPerformance("animation_execution", duration: executionTime, success: true)
            
        } catch {
            let executionTime = Date().timeIntervalSince(startTime)
            logger.logPerformance("animation_execution", duration: executionTime, success: false)
            
            logger.error(error, context: [
                "animation_type": animation.type,
                "operation": "execute_animation"
            ])
        }
    }
    
    private func getStreakIntensity(for count: Int) -> AnimationIntensity {
        switch count {
        case 1...3: return .low
        case 4...7: return .medium
        case 8...14: return .high
        case 15...30: return .epic
        default: return .legendary
        }
    }
    
    private func getProgressMilestone(for progress: Double) -> ProgressMilestone? {
        let rounded = Int(progress)
        switch rounded {
        case 25: return .quarter
        case 50: return .half
        case 75: return .threeQuarter
        case 100: return .complete
        default: return nil
        }
    }
    
    private func getRandomMotivationalMessage() -> String {
        let messages = [
            "素晴らしい進歩です！",
            "継続は力なり！",
            "今日も頑張りましょう！",
            "あなたならできます！",
            "一歩ずつ前進中！",
            "健康への道のりを歩んでいます！"
        ]
        return messages.randomElement() ?? "頑張りましょう！"
    }
    
    private func isProgressMilestone(_ progress: Double) -> Bool {
        let milestones: [Double] = [25, 50, 75, 90, 100]
        return milestones.contains { abs($0 - progress) < 0.5 }
    }
    
    private func getProgressEncouragement(for progress: Double) -> String {
        switch progress {
        case 0..<25:
            return "良いスタートです！"
        case 25..<50:
            return "順調に進んでいます！"
        case 50..<75:
            return "半分を超えました！"
        case 75..<90:
            return "もう少しでゴールです！"
        case 90..<100:
            return "あと一息！"
        default:
            return "目標達成！"
        }
    }
}

// MARK: - Supporting Types

struct AnimationEvent: Identifiable {
    let id = UUID()
    let type: String
    let duration: TimeInterval
    let intensity: AnimationIntensity
    let payload: [String: Any]
    
    static func streak(count: Int, intensity: AnimationIntensity) -> AnimationEvent {
        return AnimationEvent(
            type: "streak",
            duration: intensity.duration,
            intensity: intensity,
            payload: [
                "count": count,
                "message": "\(count)日連続記録！"
            ]
        )
    }
    
    static func progress(value: Double, type: HealthDataType, milestone: ProgressMilestone?) -> AnimationEvent {
        return AnimationEvent(
            type: "progress",
            duration: milestone != nil ? 2.5 : 1.5,
            intensity: milestone != nil ? .high : .medium,
            payload: [
                "value": value,
                "data_type": type.rawValue,
                "milestone": milestone?.rawValue ?? "",
                "is_milestone": milestone != nil
            ]
        )
    }
    
    static func motivationalPulse(message: String, intensity: AnimationIntensity) -> AnimationEvent {
        return AnimationEvent(
            type: "motivational_pulse",
            duration: intensity.duration,
            intensity: intensity,
            payload: [
                "message": message,
                "pulse_count": intensity.pulseCount
            ]
        )
    }
    
    static func dataEntrySuccess(celebration: CelebrationType, duration: TimeInterval) -> AnimationEvent {
        return AnimationEvent(
            type: "data_entry_success",
            duration: duration,
            intensity: .medium,
            payload: [
                "celebration_type": celebration.rawValue,
                "success_message": "データが記録されました！"
            ]
        )
    }
    
    static func goalProgress(progress: Double, milestoneReached: Bool, encouragement: String) -> AnimationEvent {
        return AnimationEvent(
            type: "goal_progress",
            duration: milestoneReached ? 3.0 : 2.0,
            intensity: milestoneReached ? .epic : .medium,
            payload: [
                "progress": progress,
                "milestone_reached": milestoneReached,
                "encouragement": encouragement
            ]
        )
    }
    
    static func dailyReminder(type: ReminderType, message: String, urgency: ReminderUrgency) -> AnimationEvent {
        return AnimationEvent(
            type: "daily_reminder",
            duration: urgency.duration,
            intensity: urgency.intensity,
            payload: [
                "reminder_type": type.rawValue,
                "message": message,
                "urgency": urgency.rawValue
            ]
        )
    }
}

enum AnimationIntensity {
    case low
    case medium
    case high
    case epic
    case legendary
    
    var duration: TimeInterval {
        switch self {
        case .low: return 1.0
        case .medium: return 1.5
        case .high: return 2.0
        case .epic: return 3.0
        case .legendary: return 4.0
        }
    }
    
    var pulseCount: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .epic: return 4
        case .legendary: return 5
        }
    }
    
    var scaleEffect: CGFloat {
        switch self {
        case .low: return 1.1
        case .medium: return 1.2
        case .high: return 1.3
        case .epic: return 1.5
        case .legendary: return 1.8
        }
    }
}

enum ProgressMilestone: String {
    case quarter = "25%"
    case half = "50%"
    case threeQuarter = "75%"
    case complete = "100%"
}

enum CelebrationType: String {
    case sparkle = "sparkle"
    case confetti = "confetti"
    case glow = "glow"
    case bounce = "bounce"
}

enum ReminderType: String {
    case gentle = "gentle"
    case encouraging = "encouraging"
    case urgent = "urgent"
}

enum ReminderUrgency: String {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var duration: TimeInterval {
        switch self {
        case .low: return 2.0
        case .medium: return 2.5
        case .high: return 3.0
        }
    }
    
    var intensity: AnimationIntensity {
        switch self {
        case .low: return .medium
        case .medium: return .high
        case .high: return .epic
        }
    }
}

// MARK: - SwiftUI Animation Components

struct ContinuationAnimationWrapper<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var animationState = AnimationState()
    
    var body: some View {
        content()
            .scaleEffect(animationState.scale)
            .opacity(animationState.opacity)
            .offset(x: animationState.offsetX, y: animationState.offsetY)
            .rotationEffect(.degrees(animationState.rotation))
            .onReceive(NotificationCenter.default.publisher(for: .continuationAnimationTriggered)) { notification in
                if let animation = notification.object as? AnimationEvent {
                    executeUIAnimation(animation)
                }
            }
    }
    
    private func executeUIAnimation(_ animation: AnimationEvent) {
        switch animation.type {
        case "streak":
            executeStreakAnimation(animation)
        case "progress":
            executeProgressAnimation(animation)
        case "motivational_pulse":
            executeMotivationalPulse(animation)
        case "data_entry_success":
            executeDataEntrySuccess(animation)
        case "goal_progress":
            executeGoalProgressAnimation(animation)
        case "daily_reminder":
            executeDailyReminder(animation)
        default:
            break
        }
    }
    
    private func executeStreakAnimation(_ animation: AnimationEvent) {
        let pulseCount = animation.intensity.pulseCount
        
        for i in 0..<pulseCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    animationState.scale = animation.intensity.scaleEffect
                }
                withAnimation(.easeInOut(duration: 0.3).delay(0.15)) {
                    animationState.scale = 1.0
                }
            }
        }
    }
    
    private func executeProgressAnimation(_ animation: AnimationEvent) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            animationState.scale = 1.1
            animationState.rotation = 5
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
            animationState.scale = 1.0
            animationState.rotation = 0
        }
    }
    
    private func executeMotivationalPulse(_ animation: AnimationEvent) {
        withAnimation(.easeInOut(duration: 0.5).repeatCount(2, autoreverses: true)) {
            animationState.opacity = 0.7
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.2)) {
                animationState.opacity = 1.0
            }
        }
    }
    
    private func executeDataEntrySuccess(_ animation: AnimationEvent) {
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) {
            animationState.scale = 1.2
            animationState.offsetY = -10
        }
        
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 15).delay(0.2)) {
            animationState.scale = 1.0
            animationState.offsetY = 0
        }
    }
    
    private func executeGoalProgressAnimation(_ animation: AnimationEvent) {
        let milestoneReached = animation.payload["milestone_reached"] as? Bool ?? false
        
        if milestoneReached {
            // Celebration animation for milestone
            withAnimation(.easeOut(duration: 0.5)) {
                animationState.scale = 1.3
                animationState.rotation = 360
            }
            
            withAnimation(.easeInOut(duration: 0.5).delay(0.5)) {
                animationState.scale = 1.0
                animationState.rotation = 0
            }
        } else {
            // Gentle progress animation
            withAnimation(.easeInOut(duration: 0.4)) {
                animationState.scale = 1.05
            }
            
            withAnimation(.easeInOut(duration: 0.4).delay(0.2)) {
                animationState.scale = 1.0
            }
        }
    }
    
    private func executeDailyReminder(_ animation: AnimationEvent) {
        withAnimation(.easeInOut(duration: 0.8).repeatCount(3, autoreverses: true)) {
            animationState.offsetX = 5
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeInOut(duration: 0.2)) {
                animationState.offsetX = 0
            }
        }
    }
}

struct AnimationState {
    var scale: CGFloat = 1.0
    var opacity: Double = 1.0
    var offsetX: CGFloat = 0
    var offsetY: CGFloat = 0
    var rotation: Double = 0
}

// MARK: - Notification Extension

extension Notification.Name {
    static let continuationAnimationTriggered = Notification.Name("continuationAnimationTriggered")
}

// MARK: - View Extensions

extension View {
    func continuationAnimations() -> some View {
        ContinuationAnimationWrapper {
            self
        }
    }
}