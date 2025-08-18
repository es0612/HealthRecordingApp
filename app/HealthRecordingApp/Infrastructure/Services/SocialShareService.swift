import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(Social)
import Social
#endif

// MARK: - Social Share Service Protocol

#if canImport(UIKit)
protocol SocialShareServiceProtocol {
    func shareAchievement(_ badge: Badge, user: User) async throws -> Bool
    func shareProgress(_ progress: HealthProgress, user: User) async throws -> Bool
    func shareGoalCompletion(_ goal: Goal, user: User) async throws -> Bool
    func generateShareImage(for content: ShareableContent) async throws -> UIImage
    func isServiceAvailable(for platform: SocialPlatform) -> Bool
}
#else
// Stub protocol for non-UIKit platforms
protocol SocialShareServiceProtocol {
    func shareAchievement(_ badge: Badge, user: User) async throws -> Bool
    func shareProgress(_ progress: HealthProgress, user: User) async throws -> Bool
    func shareGoalCompletion(_ goal: Goal, user: User) async throws -> Bool
    func isServiceAvailable(for platform: SocialPlatform) -> Bool
}
#endif

// MARK: - Social Share Service Implementation

#if canImport(UIKit)
final class SocialShareService: SocialShareServiceProtocol {
    
    private let logger: AILoggerProtocol
    private let imageGenerator: ShareImageGenerator
    
    init(logger: AILoggerProtocol = AILogger()) {
        self.logger = logger
        self.imageGenerator = ShareImageGenerator()
    }
    
    // MARK: - Public Methods
    
    func shareAchievement(_ badge: Badge, user: User) async throws -> Bool {
        let startTime = Date()
        
        do {
            logger.info("Starting achievement share", context: [
                "badge_name": badge.name,
                "user_id": user.id.uuidString
            ])
            
            let shareContent = ShareableContent.achievement(
                badge: badge,
                user: user,
                message: generateAchievementMessage(for: badge, user: user)
            )
            
            let shareImage = try await generateShareImage(for: shareContent)
            let success = await presentShareSheet(image: shareImage, content: shareContent)
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("share_achievement", duration: duration, success: success)
            
            if success {
                logger.info("Achievement shared successfully", context: [
                    "badge_name": badge.name,
                    "user_id": user.id.uuidString
                ])
            }
            
            return success
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("share_achievement", duration: duration, success: false)
            
            logger.error(error, context: [
                "badge_name": badge.name,
                "user_id": user.id.uuidString,
                "operation": "share_achievement"
            ])
            
            throw SocialShareError.shareFailed(underlying: error)
        }
    }
    
    func shareProgress(_ progress: HealthProgress, user: User) async throws -> Bool {
        let startTime = Date()
        
        do {
            logger.info("Starting progress share", context: [
                "progress_type": progress.type.rawValue,
                "user_id": user.id.uuidString
            ])
            
            let shareContent = ShareableContent.progress(
                progress: progress,
                user: user,
                message: generateProgressMessage(for: progress, user: user)
            )
            
            let shareImage = try await generateShareImage(for: shareContent)
            let success = await presentShareSheet(image: shareImage, content: shareContent)
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("share_progress", duration: duration, success: success)
            
            return success
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("share_progress", duration: duration, success: false)
            
            logger.error(error, context: [
                "progress_type": progress.type.rawValue,
                "user_id": user.id.uuidString,
                "operation": "share_progress"
            ])
            
            throw SocialShareError.shareFailed(underlying: error)
        }
    }
    
    func shareGoalCompletion(_ goal: Goal, user: User) async throws -> Bool {
        let startTime = Date()
        
        do {
            logger.info("Starting goal completion share", context: [
                "goal_id": goal.id.uuidString,
                "goal_type": goal.type.rawValue,
                "user_id": user.id.uuidString
            ])
            
            let shareContent = ShareableContent.goalCompletion(
                goal: goal,
                user: user,
                message: generateGoalCompletionMessage(for: goal, user: user)
            )
            
            let shareImage = try await generateShareImage(for: shareContent)
            let success = await presentShareSheet(image: shareImage, content: shareContent)
            
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("share_goal_completion", duration: duration, success: success)
            
            return success
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.logPerformance("share_goal_completion", duration: duration, success: false)
            
            logger.error(error, context: [
                "goal_id": goal.id.uuidString,
                "user_id": user.id.uuidString,
                "operation": "share_goal_completion"
            ])
            
            throw SocialShareError.shareFailed(underlying: error)
        }
    }
    
    func generateShareImage(for content: ShareableContent) async throws -> UIImage {
        return try await imageGenerator.generateImage(for: content)
    }
    
    func isServiceAvailable(for platform: SocialPlatform) -> Bool {
        switch platform {
        case .twitter:
            #if canImport(Social)
            return SLComposeViewController.isAvailable(forServiceType: SLServiceTypeTwitter)
            #else
            return false
            #endif
        case .facebook:
            #if canImport(Social)
            return SLComposeViewController.isAvailable(forServiceType: SLServiceTypeFacebook)
            #else
            return false
            #endif
        case .instagram:
            // Instagram sharing requires special handling
            guard let url = URL(string: "instagram://app") else { return false }
            return UIApplication.shared.canOpenURL(url)
        case .native:
            return true // Always available through UIActivityViewController
        }
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func presentShareSheet(image: UIImage, content: ShareableContent) async -> Bool {
        return await withCheckedContinuation { continuation in
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController else {
                continuation.resume(returning: false)
                return
            }
            
            let activityViewController = UIActivityViewController(
                activityItems: [image, content.message],
                applicationActivities: nil
            )
            
            // Exclude irrelevant activities
            activityViewController.excludedActivityTypes = [
                .assignToContact,
                .print,
                .addToReadingList,
                .openInIBooks
            ]
            
            activityViewController.completionWithItemsHandler = { _, completed, _, error in
                if let error = error {
                    self.logger.error(error, context: ["operation": "share_sheet_completion"])
                }
                continuation.resume(returning: completed)
            }
            
            // For iPad
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = rootViewController.view
                popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, 
                                          y: rootViewController.view.bounds.midY, 
                                          width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootViewController.present(activityViewController, animated: true)
        }
    }
    
    private func generateAchievementMessage(for badge: Badge, user: User) -> String {
        let badgeEmoji = getBadgeEmoji(for: badge)
        return "🎉 新しいバッジを獲得しました！\n\n\(badgeEmoji) \(badge.name)\n\(badge.description)\n\n#健康記録 #HealthRecording #Achievement"
    }
    
    private func generateProgressMessage(for progress: HealthProgress, user: User) -> String {
        let progressEmoji = getProgressEmoji(for: progress.type)
        let percentageText = String(format: "%.1f", progress.percentageComplete)
        return "\(progressEmoji) 健康目標の進捗報告！\n\n目標達成率: \(percentageText)%\n継続は力なり！\n\n#健康記録 #HealthProgress #Wellness"
    }
    
    private func generateGoalCompletionMessage(for goal: Goal, user: User) -> String {
        let goalEmoji = getGoalEmoji(for: goal.type)
        return "🏆 目標達成しました！\n\n\(goalEmoji) \(goal.type.displayName)目標\n\(goal.description ?? "")\n\n継続的な努力が実りました！\n\n#目標達成 #HealthGoals #Success"
    }
    
    private func getBadgeEmoji(for badge: Badge) -> String {
        switch badge.type {
        case .milestone: return "🏁"
        case .streak: return "🔥"
        case .achievement: return "🏆"
        case .special: return "⭐"
        }
    }
    
    private func getProgressEmoji(for type: HealthDataType) -> String {
        switch type {
        case .weight: return "⚖️"
        case .steps: return "👟"
        case .calories: return "🔥"
        case .heartRate: return "❤️"
        case .bloodGlucose: return "🩸"
        case .bloodPressure: return "💗"
        case .sleep: return "😴"
        case .hydration: return "💧"
        case .exercise: return "💪"
        case .custom: return "📊"
        }
    }
    
    private func getGoalEmoji(for type: HealthDataType) -> String {
        return getProgressEmoji(for: type)
    }
}

// MARK: - Share Image Generator

final class ShareImageGenerator {
    
    func generateImage(for content: ShareableContent) async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                do {
                    let image = try self.createShareImage(for: content)
                    continuation.resume(returning: image)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    @MainActor
    private func createShareImage(for content: ShareableContent) throws -> UIImage {
        let size = CGSize(width: 1200, height: 630) // Optimal for social media
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            
            // Background gradient
            let gradient = createBackgroundGradient(for: content)
            gradient.draw(in: rect)
            
            switch content {
            case .achievement(let badge, let user, let message):
                drawAchievementContent(badge: badge, user: user, message: message, in: rect, context: context)
                
            case .progress(let progress, let user, let message):
                drawProgressContent(progress: progress, user: user, message: message, in: rect, context: context)
                
            case .goalCompletion(let goal, let user, let message):
                drawGoalCompletionContent(goal: goal, user: user, message: message, in: rect, context: context)
            }
            
            // Add app branding
            drawAppBranding(in: rect, context: context)
        }
    }
    
    private func createBackgroundGradient(for content: ShareableContent) -> CAGradientLayer {
        let gradient = CAGradientLayer()
        gradient.frame = CGRect(x: 0, y: 0, width: 1200, height: 630)
        
        switch content {
        case .achievement(let badge, _, _):
            let colors = getBadgeGradientColors(for: badge)
            gradient.colors = colors.map { $0.cgColor }
            
        case .progress:
            gradient.colors = [
                UIColor.systemBlue.cgColor,
                UIColor.systemPurple.cgColor
            ]
            
        case .goalCompletion:
            gradient.colors = [
                UIColor.systemGreen.cgColor,
                UIColor.systemTeal.cgColor
            ]
        }
        
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        
        return gradient
    }
    
    private func getBadgeGradientColors(for badge: Badge) -> [UIColor] {
        switch badge.colorScheme {
        case .bronze:
            return [UIColor(red: 0.8, green: 0.5, blue: 0.2, alpha: 1.0),
                    UIColor(red: 0.9, green: 0.7, blue: 0.4, alpha: 1.0)]
        case .silver:
            return [UIColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1.0),
                    UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)]
        case .gold:
            return [UIColor(red: 0.9, green: 0.7, blue: 0.1, alpha: 1.0),
                    UIColor(red: 1.0, green: 0.9, blue: 0.3, alpha: 1.0)]
        case .platinum:
            return [UIColor(red: 0.8, green: 0.8, blue: 0.9, alpha: 1.0),
                    UIColor(red: 0.9, green: 0.9, blue: 1.0, alpha: 1.0)]
        }
    }
    
    private func drawAchievementContent(badge: Badge, user: User, message: String, in rect: CGRect, context: UIGraphicsImageRendererContext) {
        // Draw large badge icon
        let iconSize: CGFloat = 150
        let iconRect = CGRect(
            x: (rect.width - iconSize) / 2,
            y: rect.height * 0.2,
            width: iconSize,
            height: iconSize
        )
        
        // Badge circle background
        context.cgContext.setFillColor(UIColor.white.withAlphaComponent(0.3).cgColor)
        context.cgContext.fillEllipse(in: iconRect)
        
        // Badge icon (would need SF Symbols rendering)
        drawText(badge.iconName, in: iconRect, fontSize: 80, color: .white, centered: true, context: context)
        
        // Badge name
        let titleRect = CGRect(x: 50, y: iconRect.maxY + 30, width: rect.width - 100, height: 60)
        drawText(badge.name, in: titleRect, fontSize: 48, color: .white, centered: true, context: context)
        
        // Badge description
        let descRect = CGRect(x: 50, y: titleRect.maxY + 20, width: rect.width - 100, height: 40)
        drawText(badge.description, in: descRect, fontSize: 24, color: .white, centered: true, context: context)
    }
    
    private func drawProgressContent(progress: HealthProgress, user: User, message: String, in rect: CGRect, context: UIGraphicsImageRendererContext) {
        // Progress circle
        let circleSize: CGFloat = 200
        let circleRect = CGRect(
            x: (rect.width - circleSize) / 2,
            y: rect.height * 0.25,
            width: circleSize,
            height: circleSize
        )
        
        drawProgressCircle(progress: progress.percentageComplete, in: circleRect, context: context)
        
        // Progress text
        let progressText = String(format: "%.1f%%", progress.percentageComplete)
        drawText(progressText, in: circleRect, fontSize: 36, color: .white, centered: true, context: context)
    }
    
    private func drawGoalCompletionContent(goal: Goal, user: User, message: String, in rect: CGRect, context: UIGraphicsImageRendererContext) {
        // Trophy icon area
        let trophyRect = CGRect(x: (rect.width - 150) / 2, y: rect.height * 0.2, width: 150, height: 150)
        drawText("🏆", in: trophyRect, fontSize: 120, color: .white, centered: true, context: context)
        
        // Goal completion text
        let titleRect = CGRect(x: 50, y: trophyRect.maxY + 30, width: rect.width - 100, height: 60)
        drawText("目標達成！", in: titleRect, fontSize: 48, color: .white, centered: true, context: context)
        
        // Goal details
        let detailRect = CGRect(x: 50, y: titleRect.maxY + 20, width: rect.width - 100, height: 40)
        drawText(goal.type.displayName, in: detailRect, fontSize: 24, color: .white, centered: true, context: context)
    }
    
    private func drawProgressCircle(progress: Double, in rect: CGRect, context: UIGraphicsImageRendererContext) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - 10
        let startAngle = -CGFloat.pi / 2
        let endAngle = startAngle + 2 * CGFloat.pi * CGFloat(progress / 100.0)
        
        // Background circle
        context.cgContext.setStrokeColor(UIColor.white.withAlphaComponent(0.3).cgColor)
        context.cgContext.setLineWidth(8)
        context.cgContext.addArc(center: center, radius: radius, startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: false)
        context.cgContext.strokePath()
        
        // Progress arc
        context.cgContext.setStrokeColor(UIColor.white.cgColor)
        context.cgContext.setLineWidth(8)
        context.cgContext.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        context.cgContext.strokePath()
    }
    
    private func drawText(_ text: String, in rect: CGRect, fontSize: CGFloat, color: UIColor, centered: Bool, context: UIGraphicsImageRendererContext) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: fontSize),
            .foregroundColor: color
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()
        
        let drawRect: CGRect
        if centered {
            drawRect = CGRect(
                x: rect.midX - textSize.width / 2,
                y: rect.midY - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )
        } else {
            drawRect = rect
        }
        
        attributedString.draw(in: drawRect)
    }
    
    private func drawAppBranding(in rect: CGRect, context: UIGraphicsImageRendererContext) {
        let brandingRect = CGRect(x: rect.width - 250, y: rect.height - 50, width: 200, height: 30)
        drawText("Health Recording App", in: brandingRect, fontSize: 16, color: UIColor.white.withAlphaComponent(0.8), centered: false, context: context)
    }
}

#else
// Stub implementation for non-UIKit platforms
final class SocialShareService: SocialShareServiceProtocol {
    private let logger: AILoggerProtocol
    
    init(logger: AILoggerProtocol = AILogger()) {
        self.logger = logger
    }
    
    func shareAchievement(_ badge: Badge, user: User) async throws -> Bool {
        logger.info("Social share not available on this platform", context: [
            "feature": "shareAchievement",
            "platform": "non-UIKit"
        ])
        return false
    }
    
    func shareProgress(_ progress: HealthProgress, user: User) async throws -> Bool {
        logger.info("Social share not available on this platform", context: [
            "feature": "shareProgress",
            "platform": "non-UIKit"
        ])
        return false
    }
    
    func shareGoalCompletion(_ goal: Goal, user: User) async throws -> Bool {
        logger.info("Social share not available on this platform", context: [
            "feature": "shareGoalCompletion",
            "platform": "non-UIKit"
        ])
        return false
    }
    
    func isServiceAvailable(for platform: SocialPlatform) -> Bool {
        return false
    }
}

// Stub implementations for UIKit-dependent types
final class ShareImageGenerator {
    init() {}
}
#endif

// MARK: - Supporting Types

enum SocialPlatform {
    case twitter
    case facebook
    case instagram
    case native // Uses UIActivityViewController
}

enum ShareableContent {
    case achievement(badge: Badge, user: User, message: String)
    case progress(progress: HealthProgress, user: User, message: String)
    case goalCompletion(goal: Goal, user: User, message: String)
    
    var message: String {
        switch self {
        case .achievement(_, _, let message),
             .progress(_, _, let message),
             .goalCompletion(_, _, let message):
            return message
        }
    }
}

struct HealthProgress {
    let type: HealthDataType
    let percentageComplete: Double
    let currentValue: Double
    let targetValue: Double
}

// MARK: - Error Types

enum SocialShareError: LocalizedError {
    case shareFailed(underlying: Error)
    case imageGenerationFailed(reason: String)
    case platformUnavailable(platform: SocialPlatform)
    
    var errorDescription: String? {
        switch self {
        case .shareFailed(let error):
            return "共有に失敗しました: \(error.localizedDescription)"
        case .imageGenerationFailed(let reason):
            return "画像生成に失敗しました: \(reason)"
        case .platformUnavailable(let platform):
            return "選択されたプラットフォームは利用できません: \(platform)"
        }
    }
}