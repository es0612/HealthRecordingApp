import Foundation

final class GoalTracker: GoalTrackerProtocol {
    private let logger: AILoggerProtocol
    
    init(logger: AILoggerProtocol = AILogger()) {
        self.logger = logger
    }
    
    // MARK: - Progress Analysis
    
    func analyzeGoalProgress(for goal: Goal, using healthRecords: [HealthRecordProtocol]) async throws -> GoalProgressDetail {
        let startTime = Date()
        logger.debug("Starting goal progress analysis", context: ["goalId": goal.id.uuidString, "recordCount": healthRecords.count])
        
        // Filter relevant health records
        let relevantRecords = healthRecords.filter { $0.type == goal.type }
        
        // Update goal's current value based on records
        let currentValue = calculateCurrentValue(for: goal, from: relevantRecords)
        let progress = min(1.0, max(0.0, currentValue / goal.targetValue))
        let progressPercentage = progress * 100.0
        let remainingValue = max(0.0, goal.targetValue - currentValue)
        let remainingDays = max(0, goal.remainingDays)
        
        // Calculate daily required progress
        let dailyRequiredProgress = remainingDays > 0 ? remainingValue / Double(remainingDays) : 0.0
        
        // Determine if on track
        let expectedProgress = calculateExpectedProgress(for: goal)
        let isOnTrack = progress >= expectedProgress * 0.8 // 80% tolerance
        
        // Calculate achievability score
        let achievabilityScore = try await calculateAchievabilityScore(for: goal, progressHistory: [])
        
        // Determine motivation level
        let motivationLevel = determineMotivationLevel(
            progress: progress,
            isOnTrack: isOnTrack,
            achievabilityScore: achievabilityScore,
            remainingDays: remainingDays
        )
        
        // Generate milestones
        let milestones = try await generateMilestones(for: goal, strategy: .adaptive)
        let updatedMilestones = updateMilestoneProgress(milestones: milestones, currentValue: currentValue)
        
        // Generate basic recommendations
        let progressDetail = GoalProgressDetail(
            goalId: goal.id,
            goalType: goal.type,
            targetValue: goal.targetValue,
            currentValue: currentValue,
            progress: progress,
            progressPercentage: progressPercentage,
            remainingValue: remainingValue,
            remainingDays: remainingDays,
            dailyRequiredProgress: dailyRequiredProgress,
            isOnTrack: isOnTrack,
            achievabilityScore: achievabilityScore,
            motivationLevel: motivationLevel,
            milestones: updatedMilestones,
            recommendations: []
        )
        
        logger.logPerformance("analyzeGoalProgress", duration: Date().timeIntervalSince(startTime), success: true)
        return progressDetail
    }
    
    func analyzeMultipleGoals(goals: [Goal], using healthRecords: [HealthRecordProtocol]) async throws -> [GoalProgressDetail] {
        logger.debug("Analyzing multiple goals", context: ["goalCount": goals.count])
        
        var progressDetails: [GoalProgressDetail] = []
        
        for goal in goals {
            do {
                let detail = try await analyzeGoalProgress(for: goal, using: healthRecords)
                progressDetails.append(detail)
            } catch {
                logger.error(error, context: ["goalId": goal.id.uuidString])
                // Continue with other goals even if one fails
            }
        }
        
        return progressDetails
    }
    
    func calculateAchievabilityScore(for goal: Goal, progressHistory: [GoalProgressSnapshot]) async throws -> Double {
        // Base score starts at 0.5
        var score = 0.5
        
        // Factor 1: Time remaining (more time = higher achievability)
        let remainingDays = Double(goal.remainingDays)
        let totalDays = Calendar.current.dateComponents([.day], from: goal.createdAt, to: goal.deadline).day ?? 1
        let timeRatio = remainingDays / Double(totalDays)
        score += timeRatio * 0.2
        
        // Factor 2: Current progress (higher progress = higher achievability)
        let currentProgress = goal.progress
        score += currentProgress * 0.3
        
        // Factor 3: Progress velocity (if history available)
        if !progressHistory.isEmpty {
            let velocity = calculateProgressVelocity(from: progressHistory, timeframe: .week)
            let requiredVelocity = goal.progress < 1.0 ? (1.0 - goal.progress) / (remainingDays / 7.0) : 0.0
            
            if requiredVelocity > 0 {
                let velocityRatio = min(2.0, velocity / requiredVelocity)
                score += velocityRatio * 0.2
            }
        }
        
        // Clamp between 0 and 1
        return min(1.0, max(0.0, score))
    }
    
    // MARK: - Milestone Management
    
    func generateMilestones(for goal: Goal, strategy: MilestoneStrategy) async throws -> [Milestone] {
        logger.debug("Generating milestones", context: ["goalId": goal.id.uuidString, "strategy": strategy.rawValue])
        
        let milestoneCount = calculateOptimalMilestoneCount(for: goal)
        var milestones: [Milestone] = []
        
        let totalDays = Calendar.current.dateComponents([.day], from: goal.createdAt, to: goal.deadline).day ?? 30
        let dayInterval = Double(totalDays) / Double(milestoneCount + 1)
        
        for i in 1...milestoneCount {
            let targetValue: Double
            let targetDate = Calendar.current.date(byAdding: .day, value: Int(dayInterval * Double(i)), to: goal.createdAt)!
            
            switch strategy {
            case .linear:
                targetValue = goal.targetValue * (Double(i) / Double(milestoneCount + 1))
            case .exponential:
                let exponentialFactor = pow(Double(i) / Double(milestoneCount + 1), 1.5)
                targetValue = goal.targetValue * exponentialFactor
            case .adaptive:
                // Start conservative, accelerate later
                let adaptiveFactor = Double(i) <= Double(milestoneCount) / 2.0 ?
                    Double(i) / Double(milestoneCount + 1) * 0.8 :
                    0.4 + (Double(i) - Double(milestoneCount) / 2.0) / (Double(milestoneCount + 1) - Double(milestoneCount) / 2.0) * 0.6
                targetValue = goal.targetValue * adaptiveFactor
            case .custom:
                // For now, fallback to linear
                targetValue = goal.targetValue * (Double(i) / Double(milestoneCount + 1))
            }
            
            let milestone = Milestone(
                goalId: goal.id,
                title: generateMilestoneTitle(for: goal, sequence: i, total: milestoneCount),
                description: generateMilestoneDescription(for: goal, targetValue: targetValue),
                targetValue: targetValue,
                currentValue: 0.0,
                progress: 0.0,
                isCompleted: false,
                targetDate: targetDate,
                priority: determineMilestonePriority(sequence: i, total: milestoneCount),
                category: determineMilestoneCategory(for: goal, targetDate: targetDate)
            )
            
            milestones.append(milestone)
        }
        
        return milestones
    }
    
    func updateMilestoneProgress(milestones: [Milestone], currentValue: Double) -> [Milestone] {
        return milestones.map { milestone in
            let progress = milestone.targetValue > 0 ? min(1.0, currentValue / milestone.targetValue) : 0.0
            
            return Milestone(
                goalId: milestone.goalId,
                title: milestone.title,
                description: milestone.description,
                targetValue: milestone.targetValue,
                currentValue: currentValue,
                progress: progress,
                isCompleted: milestone.isCompleted,
                completedDate: milestone.completedDate,
                targetDate: milestone.targetDate,
                priority: milestone.priority,
                category: milestone.category
            )
        }
    }
    
    func checkMilestoneCompletion(milestones: [Milestone], currentValue: Double) -> [Milestone] {
        return milestones.map { milestone in
            let isCompleted = currentValue >= milestone.targetValue
            let completedDate = isCompleted && !milestone.isCompleted ? Date() : milestone.completedDate
            
            return Milestone(
                goalId: milestone.goalId,
                title: milestone.title,
                description: milestone.description,
                targetValue: milestone.targetValue,
                currentValue: currentValue,
                progress: min(1.0, currentValue / milestone.targetValue),
                isCompleted: isCompleted,
                completedDate: completedDate,
                targetDate: milestone.targetDate,
                priority: milestone.priority,
                category: milestone.category
            )
        }
    }
    
    // MARK: - Recommendation Generation
    
    func generateRecommendations(for goalProgress: GoalProgressDetail, userProfile: GoalUserProfile) async throws -> [GoalRecommendation] {
        logger.debug("Generating recommendations", context: ["goalId": goalProgress.goalId.uuidString])
        
        var recommendations: [GoalRecommendation] = []
        
        // Generate recommendations based on progress status
        if goalProgress.progress < 0.3 {
            // Low progress - focus on getting started
            recommendations.append(contentsOf: generateLowProgressRecommendations(for: goalProgress, userProfile: userProfile))
        } else if goalProgress.progress < 0.7 {
            // Medium progress - maintain momentum
            recommendations.append(contentsOf: generateMediumProgressRecommendations(for: goalProgress, userProfile: userProfile))
        } else if goalProgress.progress < 1.0 {
            // High progress - push to finish
            recommendations.append(contentsOf: generateHighProgressRecommendations(for: goalProgress, userProfile: userProfile))
        } else {
            // Completed - celebrate and maintain
            recommendations.append(contentsOf: generateCompletionRecommendations(for: goalProgress, userProfile: userProfile))
        }
        
        // Add motivation-specific recommendations
        recommendations.append(contentsOf: generateMotivationRecommendations(for: goalProgress, userProfile: userProfile))
        
        // Add tracking recommendations if insufficient data
        if goalProgress.achievabilityScore < 0.4 {
            recommendations.append(contentsOf: generateTrackingRecommendations(for: goalProgress, userProfile: userProfile))
        }
        
        return recommendations.prefix(5).map { $0 } // Limit to top 5
    }
    
    func prioritizeRecommendations(recommendations: [GoalRecommendation], context: GoalContext) -> [GoalRecommendation] {
        return recommendations.sorted { first, second in
            // Primary sort: Priority level
            if first.priority != second.priority {
                let priorityOrder: [RecommendationPriority] = [.critical, .high, .medium, .low]
                let firstIndex = priorityOrder.firstIndex(of: first.priority) ?? priorityOrder.count
                let secondIndex = priorityOrder.firstIndex(of: second.priority) ?? priorityOrder.count
                return firstIndex < secondIndex
            }
            
            // Secondary sort: Estimated impact
            if abs(first.estimatedImpact - second.estimatedImpact) > 0.01 {
                return first.estimatedImpact > second.estimatedImpact
            }
            
            // Tertiary sort: Difficulty (easier first for same impact)
            let difficultyOrder: [RecommendationDifficulty] = [.easy, .medium, .hard, .expert]
            let firstDiffIndex = difficultyOrder.firstIndex(of: first.difficulty) ?? difficultyOrder.count
            let secondDiffIndex = difficultyOrder.firstIndex(of: second.difficulty) ?? difficultyOrder.count
            return firstDiffIndex < secondDiffIndex
        }
    }
    
    func personalizeRecommendations(recommendations: [GoalRecommendation], for user: User) async throws -> [GoalRecommendation] {
        return recommendations.map { recommendation in
            let personalizedTitle = personalizeText(recommendation.title, for: user)
            let personalizedDescription = personalizeText(recommendation.description, for: user)
            let personalizedActions = recommendation.actionItems.map { personalizeText($0, for: user) }
            
            return GoalRecommendation(
                goalId: recommendation.goalId,
                type: recommendation.type,
                title: personalizedTitle,
                description: personalizedDescription,
                actionItems: personalizedActions,
                priority: recommendation.priority,
                estimatedImpact: recommendation.estimatedImpact,
                difficulty: recommendation.difficulty,
                category: recommendation.category,
                isPersonalized: true
            )
        }
    }
    
    // MARK: - Trend Analysis
    
    func analyzeTrends(for goal: Goal, progressHistory: [GoalProgressSnapshot], timeframe: GoalTimeframe) async throws -> GoalTrendAnalysis {
        guard !progressHistory.isEmpty else {
            throw ValidationError.invalidInput("GoalTracker", value: "empty", reason: "Progress history is required for trend analysis")
        }
        
        let sortedHistory = progressHistory.sorted { $0.timestamp < $1.timestamp }
        let progressValues = sortedHistory.map { $0.progress }
        
        // Determine trend direction
        let progressTrend = determineTrendDirection(from: progressValues)
        
        // Calculate velocity trend
        let velocities = calculateVelocities(from: sortedHistory)
        let velocityTrend = determineTrendDirection(from: velocities)
        
        // Calculate average progress
        let averageProgress = progressValues.reduce(0, +) / Double(progressValues.count)
        
        // Calculate progress velocity (progress per day)
        let progressVelocity = calculateProgressVelocity(from: sortedHistory, timeframe: timeframe)
        
        // Project completion date
        let projectedCompletion = calculateProjectedCompletion(
            currentProgress: goal.progress,
            velocity: progressVelocity,
            targetProgress: 1.0
        )
        
        // Calculate confidence level
        let confidenceLevel = calculateTrendConfidence(from: progressValues)
        
        // Assess risk factors
        let riskFactors = assessProgressRisks(for: goal, progressHistory: sortedHistory)
        
        // Calculate success probability
        let successProbability = try await calculateSuccessProbability(for: goal, based: sortedHistory)
        
        return GoalTrendAnalysis(
            goalId: goal.id,
            timeframe: timeframe,
            progressTrend: progressTrend,
            velocityTrend: velocityTrend,
            averageProgress: averageProgress,
            progressVelocity: progressVelocity,
            projectedCompletion: projectedCompletion,
            confidenceLevel: confidenceLevel,
            riskFactors: riskFactors,
            successProbability: successProbability
        )
    }
    
    func predictGoalCompletion(based on: GoalProgressDetail, progressHistory: [GoalProgressSnapshot]) async throws -> GoalCompletionPrediction {
        let currentProgress = on.progress
        let remainingProgress = 1.0 - currentProgress
        let remainingDays = Double(on.remainingDays)
        
        // Calculate required daily progress
        let requiredDailyProgress = remainingDays > 0 ? remainingProgress / remainingDays : 0.0
        
        // Calculate historical velocity
        let velocity = progressHistory.isEmpty ? 0.0 : calculateProgressVelocity(from: progressHistory, timeframe: .week) / 7.0
        
        // Predict completion date based on current velocity
        let predictedCompletionDate: Date?
        if velocity > 0 {
            let daysToCompletion = remainingProgress / velocity
            predictedCompletionDate = Calendar.current.date(byAdding: .day, value: Int(daysToCompletion), to: Date())
        } else {
            predictedCompletionDate = nil
        }
        
        // Calculate confidence level
        let confidenceLevel = calculatePredictionConfidence(
            velocity: velocity,
            requiredVelocity: requiredDailyProgress,
            progressHistory: progressHistory
        )
        
        // Calculate success probability (simplified - would need actual goal reference)
        let successProbability = velocity > 0 ? min(1.0, velocity / (requiredDailyProgress + 0.001)) : 0.3
        
        // Generate alternative scenarios
        let alternativeScenarios = generateCompletionScenarios(
            currentProgress: currentProgress,
            remainingDays: Int(remainingDays),
            historicalVelocity: velocity
        )
        
        return GoalCompletionPrediction(
            goalId: on.goalId,
            predictedCompletionDate: predictedCompletionDate,
            confidenceLevel: confidenceLevel,
            successProbability: successProbability,
            requiredDailyProgress: requiredDailyProgress,
            alternativeScenarios: alternativeScenarios
        )
    }
    
    func calculateProgressVelocity(from progressHistory: [GoalProgressSnapshot], timeframe: GoalTimeframe) -> Double {
        guard progressHistory.count >= 2 else { return 0.0 }
        
        let sortedHistory = progressHistory.sorted { $0.timestamp < $1.timestamp }
        let timeframeInterval: TimeInterval
        
        switch timeframe {
        case .week:
            timeframeInterval = 7 * 24 * 60 * 60
        case .month:
            timeframeInterval = 30 * 24 * 60 * 60
        case .quarter:
            timeframeInterval = 90 * 24 * 60 * 60
        case .overall:
            guard let firstHistory = sortedHistory.first,
                  let lastHistory = sortedHistory.last else {
                return 0.0 // Return safe default for empty history
            }
            timeframeInterval = lastHistory.timestamp.timeIntervalSince(firstHistory.timestamp)
        }
        
        guard let firstHistory = sortedHistory.first,
              let lastHistory = sortedHistory.last else {
            return 0.0 // Return safe default for empty history
        }
        
        let progressChange = lastHistory.progress - firstHistory.progress
        let timeInterval = lastHistory.timestamp.timeIntervalSince(firstHistory.timestamp)
        
        guard timeInterval > 0 else { return 0.0 }
        
        // Return velocity normalized to the specified timeframe
        return (progressChange / timeInterval) * timeframeInterval
    }
    
    // MARK: - Risk Assessment
    
    func assessGoalRisks(for goalProgress: GoalProgressDetail, progressHistory: [GoalProgressSnapshot]) async throws -> [GoalRiskFactor] {
        var riskFactors: [GoalRiskFactor] = []
        
        // Risk 1: Time constraint
        if goalProgress.remainingDays < 7 && goalProgress.progress < 0.8 {
            riskFactors.append(GoalRiskFactor(
                goalId: goalProgress.goalId,
                type: .timeConstraint,
                severity: .critical,
                description: "目標期限まで残り\(goalProgress.remainingDays)日ですが、進捗が\(Int(goalProgress.progressPercentage))%です",
                impact: 0.9,
                mitigation: "期限の延長または目標値の調整を検討してください",
                isAddressable: true
            ))
        }
        
        // Risk 2: Lack of progress
        if goalProgress.progress < 0.1 && goalProgress.remainingDays < goalProgress.remainingDays {
            riskFactors.append(GoalRiskFactor(
                goalId: goalProgress.goalId,
                type: .lackOfProgress,
                severity: .high,
                description: "進捗が非常に遅れています（\(Int(goalProgress.progressPercentage))%）",
                impact: 0.8,
                mitigation: "より小さな目標に分割し、毎日の習慣を確立してください",
                isAddressable: true
            ))
        }
        
        // Risk 3: Motivation decline
        if goalProgress.motivationLevel == .low || goalProgress.motivationLevel == .critical {
            riskFactors.append(GoalRiskFactor(
                goalId: goalProgress.goalId,
                type: .motivationDecline,
                severity: goalProgress.motivationLevel == .critical ? .critical : .medium,
                description: "モチベーションが低下しています",
                impact: 0.7,
                mitigation: "サポートシステムの活用や報酬システムの導入を検討してください",
                isAddressable: true
            ))
        }
        
        // Risk 4: Unrealistic target (based on achievability score)
        if goalProgress.achievabilityScore < 0.3 {
            riskFactors.append(GoalRiskFactor(
                goalId: goalProgress.goalId,
                type: .unrealisticTarget,
                severity: .high,
                description: "現在のペースでは目標達成が困難です（達成可能性: \(Int(goalProgress.achievabilityScore * 100))%）",
                impact: 0.8,
                mitigation: "目標値を現実的な範囲に調整することを推奨します",
                isAddressable: true
            ))
        }
        
        return riskFactors
    }
    
    func calculateSuccessProbability(for goal: Goal, based on: [GoalProgressSnapshot]) async throws -> Double {
        guard !on.isEmpty else { return 0.5 }
        
        let currentProgress = goal.progress
        let remainingDays = Double(goal.remainingDays)
        
        // Base probability from current progress
        var probability = currentProgress * 0.4
        
        // Factor in velocity
        let velocity = calculateProgressVelocity(from: on, timeframe: .week) / 7.0 // Daily velocity
        let requiredVelocity = remainingDays > 0 ? (1.0 - currentProgress) / remainingDays : 0.0
        
        if requiredVelocity > 0 {
            let velocityRatio = min(2.0, velocity / requiredVelocity)
            probability += velocityRatio * 0.3
        }
        
        // Factor in consistency
        let consistencyScore = calculateConsistency(from: on)
        probability += consistencyScore * 0.2
        
        // Factor in time remaining
        let timeScore = remainingDays > 0 ? min(1.0, remainingDays / 30.0) : 0.0
        probability += timeScore * 0.1
        
        return min(1.0, max(0.0, probability))
    }
    
    func identifyBarriers(for goal: Goal, progressHistory: [GoalProgressSnapshot]) async throws -> [GoalBarrier] {
        var barriers: [GoalBarrier] = []
        
        // Identify stagnation
        if progressHistory.count >= 5 {
            let recentProgress = Array(progressHistory.suffix(5))
            let progressVariation = calculateVariation(from: recentProgress.map { $0.progress })
            
            if progressVariation < 0.05 { // Less than 5% variation
                barriers.append(GoalBarrier(
                    goalId: goal.id,
                    type: .motivation,
                    severity: .moderate,
                    description: "進捗が停滞しています",
                    suggestedSolutions: [
                        "目標を小さなステップに分解する",
                        "新しい測定方法を試す",
                        "サポートグループに参加する"
                    ],
                    isAddressable: true
                ))
            }
        }
        
        // Identify knowledge gaps (low achievability)
        let achievabilityScore = try await calculateAchievabilityScore(for: goal, progressHistory: progressHistory)
        if achievabilityScore < 0.4 {
            barriers.append(GoalBarrier(
                goalId: goal.id,
                type: .knowledge,
                severity: .major,
                description: "目標達成に必要な知識やスキルが不足している可能性があります",
                suggestedSolutions: [
                    "専門家に相談する",
                    "関連書籍や記事を読む",
                    "オンラインコースを受講する"
                ],
                isAddressable: true
            ))
        }
        
        return barriers
    }
    
    // MARK: - Motivation Analysis
    
    func calculateMotivationLevel(for goal: Goal, progressHistory: [GoalProgressSnapshot], recentActivity: [GoalActivity]) async throws -> MotivationLevel {
        var motivationScore = 0.5 // Base score
        
        // Factor 1: Progress momentum
        if !progressHistory.isEmpty {
            let velocity = calculateProgressVelocity(from: progressHistory, timeframe: .week)
            if velocity > 0 {
                motivationScore += min(0.3, velocity * 0.1)
            } else if velocity < 0 {
                motivationScore -= 0.2
            }
        }
        
        // Factor 2: Recent activity engagement
        if !recentActivity.isEmpty {
            let averageEngagement = recentActivity.reduce(0) { $0 + $1.engagement } / Double(recentActivity.count)
            motivationScore += (averageEngagement - 0.5) * 0.3
            
            // Positive results boost motivation
            let positiveResults = recentActivity.filter { $0.result == .positive }.count
            let positiveRatio = Double(positiveResults) / Double(recentActivity.count)
            motivationScore += (positiveRatio - 0.5) * 0.2
        }
        
        // Factor 3: Time pressure
        let remainingDays = Double(goal.remainingDays)
        if remainingDays < 7 && goal.progress < 0.8 {
            motivationScore -= 0.3 // Stress factor
        } else if remainingDays > 30 {
            motivationScore -= 0.1 // Complacency factor
        }
        
        // Convert to motivation level
        switch motivationScore {
        case 0.8...: return .high
        case 0.5..<0.8: return .medium
        case 0.2..<0.5: return .low
        default: return .critical
        }
    }
    
    func generateMotivationalContent(for goal: Goal, motivationLevel: MotivationLevel, userPreferences: MotivationPreferences) async throws -> [MotivationalContent] {
        var content: [MotivationalContent] = []
        
        for contentType in userPreferences.preferredContentTypes.prefix(3) {
            let motivationalContent = generateContentForType(
                contentType,
                goal: goal,
                motivationLevel: motivationLevel,
                tone: userPreferences.tone,
                personalizationLevel: userPreferences.personalizationLevel
            )
            content.append(motivationalContent)
        }
        
        return content
    }
    
    func trackEngagement(for goal: Goal, activities: [GoalActivity]) async throws -> GoalEngagementMetrics {
        guard !activities.isEmpty else {
            return GoalEngagementMetrics(
                goalId: goal.id,
                overallEngagement: 0.0,
                dailyEngagement: 0.0,
                weeklyEngagement: 0.0,
                monthlyEngagement: 0.0,
                engagementTrend: .stable,
                activityFrequency: 0.0,
                sessionDuration: 0.0,
                completionRate: 0.0
            )
        }
        
        // Calculate overall engagement
        let overallEngagement = activities.reduce(0) { $0 + $1.engagement } / Double(activities.count)
        
        // Calculate time-based engagement
        let now = Date()
        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: now)!
        
        let dailyActivities = activities.filter { $0.timestamp >= oneDayAgo }
        let weeklyActivities = activities.filter { $0.timestamp >= oneWeekAgo }
        let monthlyActivities = activities.filter { $0.timestamp >= oneMonthAgo }
        
        let dailyEngagement = dailyActivities.isEmpty ? 0.0 : dailyActivities.reduce(0) { $0 + $1.engagement } / Double(dailyActivities.count)
        let weeklyEngagement = weeklyActivities.isEmpty ? 0.0 : weeklyActivities.reduce(0) { $0 + $1.engagement } / Double(weeklyActivities.count)
        let monthlyEngagement = monthlyActivities.isEmpty ? 0.0 : monthlyActivities.reduce(0) { $0 + $1.engagement } / Double(monthlyActivities.count)
        
        // Calculate engagement trend
        let engagementTrend: TrendDirection
        if dailyEngagement > weeklyEngagement && weeklyEngagement > monthlyEngagement {
            engagementTrend = .increasing
        } else if dailyEngagement < weeklyEngagement && weeklyEngagement < monthlyEngagement {
            engagementTrend = .decreasing
        } else {
            engagementTrend = .stable
        }
        
        // Calculate activity frequency (activities per day)
        guard let firstActivity = activities.first,
              let lastActivity = activities.last else {
            return GoalEngagementMetrics(
                goalId: goal.id,
                overallEngagement: 0.0,
                dailyEngagement: 0.0,
                weeklyEngagement: 0.0,
                monthlyEngagement: 0.0,
                engagementTrend: .stable,
                activityFrequency: 0.0,
                sessionDuration: 0.0,
                completionRate: 0.0
            )
        }
        
        let timeSpan = lastActivity.timestamp.timeIntervalSince(firstActivity.timestamp)
        let activityFrequency = timeSpan > 0 ? Double(activities.count) / (timeSpan / (24 * 60 * 60)) : 0.0
        
        // Calculate average session duration
        let totalDuration = activities.reduce(0) { $0 + $1.duration }
        let sessionDuration = totalDuration / Double(activities.count)
        
        // Calculate completion rate (positive results / total activities)
        let positiveResults = activities.filter { $0.result == .positive }.count
        let completionRate = Double(positiveResults) / Double(activities.count)
        
        return GoalEngagementMetrics(
            goalId: goal.id,
            overallEngagement: overallEngagement,
            dailyEngagement: dailyEngagement,
            weeklyEngagement: weeklyEngagement,
            monthlyEngagement: monthlyEngagement,
            engagementTrend: engagementTrend,
            activityFrequency: activityFrequency,
            sessionDuration: sessionDuration,
            completionRate: completionRate
        )
    }
    
    // MARK: - Goal Optimization
    
    func optimizeGoalTarget(for goal: Goal, based on: [GoalProgressSnapshot], constraints: GoalConstraints) async throws -> GoalOptimizationSuggestion {
        let velocity = calculateProgressVelocity(from: on, timeframe: .week) / 7.0 // Daily velocity
        let remainingDays = Double(goal.remainingDays)
        let currentProgress = goal.progress
        
        // Calculate what's realistically achievable
        let projectedFinalProgress = currentProgress + (velocity * remainingDays)
        let projectedFinalValue = projectedFinalProgress * goal.targetValue
        
        var suggestedTarget: Double
        var reasoning: String
        var outcome: OptimizationOutcome
        
        if projectedFinalValue < goal.targetValue * 0.8 {
            // Suggest reducing target
            suggestedTarget = projectedFinalValue * 1.1 // 10% buffer
            reasoning = "現在のペースでは目標達成が困難です。より現実的な目標に調整することで、達成感と継続的なモチベーションを維持できます。"
            outcome = .targetReduction
        } else if projectedFinalValue > goal.targetValue * 1.2 {
            // Suggest increasing target
            suggestedTarget = projectedFinalValue * 0.9 // Slightly conservative
            reasoning = "現在の順調な進捗を考慮すると、より挑戦的な目標設定が可能です。"
            outcome = .targetIncrease
        } else {
            // Target is appropriate
            suggestedTarget = goal.targetValue
            reasoning = "現在の目標は適切な挑戦レベルです。"
            outcome = .strategyChange
        }
        
        let confidenceLevel = calculateOptimizationConfidence(
            velocity: velocity,
            consistency: calculateConsistency(from: on),
            timeRemaining: remainingDays
        )
        
        let implementationSteps = generateOptimizationSteps(
            currentTarget: goal.targetValue,
            suggestedTarget: suggestedTarget,
            outcome: outcome
        )
        
        return GoalOptimizationSuggestion(
            goalId: goal.id,
            suggestedTarget: suggestedTarget,
            reasoningForDecrease: outcome == .targetReduction ? reasoning : nil,
            reasoningForIncrease: outcome == .targetIncrease ? reasoning : nil,
            confidenceLevel: confidenceLevel,
            expectedOutcome: outcome,
            implementationSteps: implementationSteps
        )
    }
    
    func suggestTimelineAdjustment(for goal: Goal, currentProgress: GoalProgressDetail) async throws -> TimelineAdjustmentSuggestion {
        let requiredDailyProgress = currentProgress.dailyRequiredProgress
        let historicalDailyProgress = currentProgress.currentValue / Double(max(1, Calendar.current.dateComponents([.day], from: goal.createdAt, to: Date()).day ?? 1))
        
        let adjustmentType: TimelineAdjustmentType
        let suggestedDeadline: Date
        var reasoning: String
        
        if historicalDailyProgress < requiredDailyProgress * 0.8 {
            // Need more time
            adjustmentType = .extend
            let additionalDays = Int((requiredDailyProgress * Double(currentProgress.remainingDays) / historicalDailyProgress) - Double(currentProgress.remainingDays))
            suggestedDeadline = Calendar.current.date(byAdding: .day, value: additionalDays, to: goal.deadline)!
            reasoning = "現在のペース（日々\(String(format: "%.1f", historicalDailyProgress))）を考慮すると、\(additionalDays)日の延長が推奨されます。"
        } else if historicalDailyProgress > requiredDailyProgress * 1.5 {
            // Can finish earlier
            adjustmentType = .compress
            let daysToReduce = Int(Double(currentProgress.remainingDays) - (1.0 - currentProgress.progress) / historicalDailyProgress)
            suggestedDeadline = Calendar.current.date(byAdding: .day, value: -Int(daysToReduce), to: goal.deadline)!
            reasoning = "順調な進捗により、\(daysToReduce)日早く完了できる可能性があります。"
        } else {
            // Current timeline is appropriate
            adjustmentType = .redistribute
            suggestedDeadline = goal.deadline
            reasoning = "現在のタイムラインは適切です。進捗の配分を最適化することを推奨します。"
        }
        
        let confidenceLevel = min(1.0, max(0.0, 0.8 - abs(historicalDailyProgress - requiredDailyProgress) / requiredDailyProgress))
        
        return TimelineAdjustmentSuggestion(
            goalId: goal.id,
            suggestedDeadline: suggestedDeadline,
            adjustmentType: adjustmentType,
            reasoning: reasoning,
            confidenceLevel: confidenceLevel,
            estimatedImpact: 0.7
        )
    }
    
    func calculateOptimalDailyTarget(for goal: Goal, currentProgress: Double, remainingDays: Int) -> Double {
        guard remainingDays > 0 else { return 0.0 }
        
        let remainingValue = goal.targetValue - currentProgress
        return remainingValue / Double(remainingDays)
    }
    
    // MARK: - Comparative Analysis
    
    func compareGoalPerformance(goals: [Goal], metric: GoalComparisonMetric) async throws -> GoalComparisonResult {
        var rankings: [GoalRanking] = []
        
        for (index, goal) in goals.enumerated() {
            let score: Double
            
            switch metric {
            case .progress:
                score = goal.progress
            case .velocity:
                // This would require progress history - simplified for now
                score = goal.progress // Placeholder
            case .consistency:
                // This would require progress history - simplified for now
                score = goal.progress // Placeholder
            case .achievability:
                score = try await calculateAchievabilityScore(for: goal, progressHistory: [])
            }
            
            rankings.append(GoalRanking(
                goalId: goal.id,
                rank: index + 1, // Will be recalculated
                score: score,
                percentile: 0.0 // Will be calculated
            ))
        }
        
        // Sort by score and assign ranks
        rankings.sort { $0.score > $1.score }
        for (index, _) in rankings.enumerated() {
            rankings[index] = GoalRanking(
                goalId: rankings[index].goalId,
                rank: index + 1,
                score: rankings[index].score,
                percentile: Double(goals.count - index) / Double(goals.count) * 100.0
            )
        }
        
        let insights = generateComparisonInsights(from: rankings, metric: metric)
        
        return GoalComparisonResult(
            comparedGoals: goals.map { $0.id },
            metric: metric,
            rankings: rankings,
            insights: insights
        )
    }
    
    func benchmarkAgainstSimilarGoals(goal: Goal, similarGoals: [Goal]) async throws -> GoalBenchmarkResult {
        let allGoals = similarGoals + [goal]
        let progressValues = allGoals.map { $0.progress }
        
        // Calculate target goal's percentile
        let betterGoals = similarGoals.filter { $0.progress > goal.progress }.count
        let percentileRank = (Double(similarGoals.count - betterGoals) / Double(similarGoals.count)) * 100.0
        
        // Calculate average performance
        let averagePerformance = progressValues.reduce(0, +) / Double(progressValues.count)
        
        // Generate insights from top performers
        let topPerformers = similarGoals.filter { $0.progress > 0.8 }
        let topPerformerInsights = topPerformers.isEmpty ? 
            ["類似する目標の優れた実行者はいません"] : 
            ["上位実行者の平均進捗: \(String(format: "%.1f", topPerformers.map { $0.progress }.reduce(0, +) / Double(topPerformers.count) * 100))%"]
        
        // Generate improvement suggestions
        let improvementSuggestions: [String]
        if goal.progress < averagePerformance {
            improvementSuggestions = [
                "平均より\(String(format: "%.1f", (averagePerformance - goal.progress) * 100))%低い進捗です",
                "より頻繁な記録とモニタリングを推奨します",
                "類似目標の成功者からアドバイスを求めてください"
            ]
        } else {
            improvementSuggestions = [
                "平均を\(String(format: "%.1f", (goal.progress - averagePerformance) * 100))%上回る優秀な進捗です",
                "現在の戦略を継続してください"
            ]
        }
        
        return GoalBenchmarkResult(
            targetGoalId: goal.id,
            comparisonGoals: similarGoals.map { $0.id },
            percentileRank: percentileRank,
            averagePerformance: averagePerformance,
            topPerformerInsights: topPerformerInsights,
            improvementSuggestions: improvementSuggestions
        )
    }
    
    func generateInsights(from comparisons: [GoalComparisonResult]) async throws -> [GoalInsight] {
        var insights: [GoalInsight] = []
        
        for comparison in comparisons {
            // Performance insight
            let topGoal = comparison.rankings.first
            let bottomGoal = comparison.rankings.last
            
            if let top = topGoal, let bottom = bottomGoal, top.score - bottom.score > 0.3 {
                insights.append(GoalInsight(
                    title: "大きなパフォーマンス差",
                    description: "目標間で\(String(format: "%.1f", (top.score - bottom.score) * 100))%のパフォーマンス差があります。上位目標の戦略を他の目標にも適用できるかもしれません。",
                    confidence: 0.8,
                    actionable: true,
                    category: .performance,
                    relatedGoals: [top.goalId, bottom.goalId]
                ))
            }
            
            // Pattern insight
            let averageScore = comparison.rankings.reduce(0) { $0 + $1.score } / Double(comparison.rankings.count)
            if averageScore < 0.5 {
                insights.append(GoalInsight(
                    title: "全体的な進捗の遅れ",
                    description: "全目標の平均進捗が\(String(format: "%.1f", averageScore * 100))%です。目標設定や戦略の見直しが必要かもしれません。",
                    confidence: 0.9,
                    actionable: true,
                    category: .patterns,
                    relatedGoals: comparison.comparedGoals
                ))
            }
        }
        
        return insights
    }
}

// MARK: - Private Helper Methods

private extension GoalTracker {
    
    func calculateCurrentValue(for goal: Goal, from records: [HealthRecordProtocol]) -> Double {
        guard !records.isEmpty else { return 0.0 }
        
        switch goal.type {
        case .weight, .bloodGlucose:
            // Use latest value
            return records.max(by: { $0.timestamp < $1.timestamp })?.value ?? 0.0
        case .steps, .calories:
            // Sum daily values
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let todayRecords = records.filter { calendar.startOfDay(for: $0.timestamp) >= today }
            return todayRecords.reduce(0) { $0 + $1.value }
        case .heartRate:
            // Average recent values
            let recent = records.filter { $0.timestamp.timeIntervalSinceNow > -24 * 60 * 60 }
            return recent.isEmpty ? 0.0 : recent.reduce(0) { $0 + $1.value } / Double(recent.count)
        }
    }
    
    func calculateExpectedProgress(for goal: Goal) -> Double {
        let totalDays = Calendar.current.dateComponents([.day], from: goal.createdAt, to: goal.deadline).day ?? 1
        let elapsedDays = Calendar.current.dateComponents([.day], from: goal.createdAt, to: Date()).day ?? 0
        return min(1.0, Double(elapsedDays) / Double(totalDays))
    }
    
    func determineMotivationLevel(progress: Double, isOnTrack: Bool, achievabilityScore: Double, remainingDays: Int) -> MotivationLevel {
        var score = progress * 0.4
        score += isOnTrack ? 0.2 : -0.1
        score += achievabilityScore * 0.3
        
        if remainingDays < 7 && progress < 0.8 {
            score -= 0.2 // Time pressure penalty
        }
        
        switch score {
        case 0.8...: return .high
        case 0.5..<0.8: return .medium
        case 0.2..<0.5: return .low
        default: return .critical
        }
    }
    
    func calculateOptimalMilestoneCount(for goal: Goal) -> Int {
        let totalDays = Calendar.current.dateComponents([.day], from: goal.createdAt, to: goal.deadline).day ?? 30
        
        switch totalDays {
        case 0..<14: return 2
        case 14..<30: return 3
        case 30..<90: return 4
        default: return 5
        }
    }
    
    func generateMilestoneTitle(for goal: Goal, sequence: Int, total: Int) -> String {
        let percentage = Int((Double(sequence) / Double(total + 1)) * 100)
        return "\(goal.type.displayName) \(percentage)%達成"
    }
    
    func generateMilestoneDescription(for goal: Goal, targetValue: Double) -> String {
        return "\(String(format: "%.1f", targetValue))\(goal.type.unit)を目指しましょう"
    }
    
    func determineMilestonePriority(sequence: Int, total: Int) -> MilestonePriority {
        let ratio = Double(sequence) / Double(total)
        switch ratio {
        case 0..<0.3: return .low
        case 0.3..<0.7: return .medium
        default: return .high
        }
    }
    
    func determineMilestoneCategory(for goal: Goal, targetDate: Date) -> MilestoneCategory {
        let daysFromNow = Calendar.current.dateComponents([.day], from: Date(), to: targetDate).day ?? 0
        
        switch daysFromNow {
        case 0..<7: return .weekly
        case 7..<30: return .monthly
        default: return .custom
        }
    }
    
    // Additional helper methods for recommendations
    func generateLowProgressRecommendations(for goalProgress: GoalProgressDetail, userProfile: GoalUserProfile) -> [GoalRecommendation] {
        return [
            GoalRecommendation(
                goalId: goalProgress.goalId,
                type: .behaviorChange,
                title: "小さな一歩から始めましょう",
                description: "大きな目標を小さな行動に分解して、毎日続けられる習慣を作りましょう",
                actionItems: ["毎日5分間の記録をつける", "週に3回小さな進歩を確認する"],
                priority: .high,
                estimatedImpact: 0.7,
                difficulty: .easy,
                category: .mindset
            )
        ]
    }
    
    func generateMediumProgressRecommendations(for goalProgress: GoalProgressDetail, userProfile: GoalUserProfile) -> [GoalRecommendation] {
        return [
            GoalRecommendation(
                goalId: goalProgress.goalId,
                type: .motivationalBoost,
                title: "順調な進捗を維持しましょう",
                description: "現在のペースを継続し、さらなる改善の機会を探しましょう",
                actionItems: ["週次レビューを実施する", "成功要因を分析する"],
                priority: .medium,
                estimatedImpact: 0.6,
                difficulty: .medium,
                category: .tracking
            )
        ]
    }
    
    func generateHighProgressRecommendations(for goalProgress: GoalProgressDetail, userProfile: GoalUserProfile) -> [GoalRecommendation] {
        return [
            GoalRecommendation(
                goalId: goalProgress.goalId,
                type: .motivationalBoost,
                title: "ゴールまであと少し！",
                description: "素晴らしい進捗です。最後のスパートをかけて目標を達成しましょう",
                actionItems: ["毎日の進捗確認を継続する", "達成後の計画を立てる"],
                priority: .high,
                estimatedImpact: 0.8,
                difficulty: .medium,
                category: .mindset
            )
        ]
    }
    
    func generateCompletionRecommendations(for goalProgress: GoalProgressDetail, userProfile: GoalUserProfile) -> [GoalRecommendation] {
        return [
            GoalRecommendation(
                goalId: goalProgress.goalId,
                type: .motivationalBoost,
                title: "目標達成おめでとうございます！",
                description: "素晴らしい成果です。この成功を次の目標にも活かしましょう",
                actionItems: ["成功要因を記録する", "新しい目標を設定する", "成果を祝う"],
                priority: .high,
                estimatedImpact: 0.9,
                difficulty: .easy,
                category: .mindset
            )
        ]
    }
    
    func generateMotivationRecommendations(for goalProgress: GoalProgressDetail, userProfile: GoalUserProfile) -> [GoalRecommendation] {
        switch goalProgress.motivationLevel {
        case .critical:
            return [
                GoalRecommendation(
                    goalId: goalProgress.goalId,
                    type: .motivationalBoost,
                    title: "モチベーション回復が必要です",
                    description: "一度立ち止まって、目標の意味を再確認しましょう",
                    actionItems: ["目標設定の理由を思い出す", "サポートを求める"],
                    priority: .critical,
                    estimatedImpact: 0.8,
                    difficulty: .medium,
                    category: .mindset
                )
            ]
        case .low:
            return [
                GoalRecommendation(
                    goalId: goalProgress.goalId,
                    type: .motivationalBoost,
                    title: "モチベーションを向上させましょう",
                    description: "小さな成功を積み重ねてモチベーションを回復しましょう",
                    actionItems: ["達成できる小さな目標を設定する", "進捗を可視化する"],
                    priority: .high,
                    estimatedImpact: 0.6,
                    difficulty: .easy,
                    category: .mindset
                )
            ]
        default:
            return []
        }
    }
    
    func generateTrackingRecommendations(for goalProgress: GoalProgressDetail, userProfile: GoalUserProfile) -> [GoalRecommendation] {
        return [
            GoalRecommendation(
                goalId: goalProgress.goalId,
                type: .resourceAllocation,
                title: "より詳細な記録をつけましょう",
                description: "データが不足しています。より正確な分析のために記録を増やしましょう",
                actionItems: ["毎日のデータ記録を習慣化する", "自動記録機能を活用する"],
                priority: .medium,
                estimatedImpact: 0.7,
                difficulty: .easy,
                category: .tracking
            )
        ]
    }
    
    func personalizeText(_ text: String, for user: User) -> String {
        return text.replacingOccurrences(of: "あなた", with: user.name + "さん")
    }
    
    // Additional statistical helper methods
    func determineTrendDirection(from values: [Double]) -> TrendDirection {
        guard values.count >= 2 else { return .stable }
        
        let firstHalf = Array(values.prefix(values.count / 2))
        let secondHalf = Array(values.suffix(values.count / 2))
        
        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)
        
        let threshold = 0.05 // 5% threshold
        let relativeDifference = abs(secondAvg - firstAvg) / max(firstAvg, 0.001)
        
        if relativeDifference < threshold {
            return .stable
        } else if secondAvg > firstAvg {
            return .increasing
        } else {
            return .decreasing
        }
    }
    
    func calculateVelocities(from snapshots: [GoalProgressSnapshot]) -> [Double] {
        guard snapshots.count >= 2 else { return [] }
        
        var velocities: [Double] = []
        for i in 1..<snapshots.count {
            let timeInterval = snapshots[i].timestamp.timeIntervalSince(snapshots[i-1].timestamp)
            let progressDifference = snapshots[i].progress - snapshots[i-1].progress
            let velocity = timeInterval > 0 ? progressDifference / (timeInterval / (24 * 60 * 60)) : 0.0
            velocities.append(velocity)
        }
        
        return velocities
    }
    
    func calculateProjectedCompletion(currentProgress: Double, velocity: Double, targetProgress: Double) -> Date? {
        guard velocity > 0 && currentProgress < targetProgress else { return nil }
        
        let remainingProgress = targetProgress - currentProgress
        let daysToCompletion = remainingProgress / velocity
        
        return Calendar.current.date(byAdding: .day, value: Int(daysToCompletion), to: Date())
    }
    
    func calculateTrendConfidence(from values: [Double]) -> Double {
        guard values.count >= 3 else { return 0.3 }
        
        // Calculate R-squared for linear regression
        let n = Double(values.count)
        let sumX = (0..<values.count).reduce(0) { $0 + $1 }
        let sumY = values.reduce(0, +)
        let sumXY = zip(0..<values.count, values).reduce(0) { $0 + Double($1.0) * $1.1 }
        let sumXX = (0..<values.count).reduce(0) { $0 + $1 * $1 }
        
        let denominator = n * Double(sumXX) - Double(sumX * sumX)
        guard denominator != 0 else { return 0.3 }
        
        let slope = (n * sumXY - Double(sumX) * sumY) / denominator
        let intercept = (sumY - slope * Double(sumX)) / n
        
        // Calculate R-squared
        let yMean = sumY / n
        let totalSumSquares = values.reduce(0) { $0 + pow($1 - yMean, 2) }
        let residualSumSquares = values.enumerated().reduce(0) { sum, element in
            let predicted = slope * Double(element.offset) + intercept
            return sum + pow(element.element - predicted, 2)
        }
        
        let rSquared = totalSumSquares > 0 ? 1 - (residualSumSquares / totalSumSquares) : 0
        return min(1.0, max(0.3, rSquared))
    }
    
    func assessProgressRisks(for goal: Goal, progressHistory: [GoalProgressSnapshot]) -> [GoalRiskFactor] {
        var risks: [GoalRiskFactor] = []
        
        if progressHistory.isEmpty {
            risks.append(GoalRiskFactor(
                goalId: goal.id,
                type: .lackOfProgress,
                severity: .medium,
                description: "進捗データが不足しています",
                impact: 0.5,
                mitigation: "定期的なデータ記録を開始してください",
                isAddressable: true
            ))
        }
        
        return risks
    }
    
    func calculateConsistency(from snapshots: [GoalProgressSnapshot]) -> Double {
        guard snapshots.count >= 3 else { return 0.5 }
        
        let velocities = calculateVelocities(from: snapshots)
        guard !velocities.isEmpty else { return 0.5 }
        
        let meanVelocity = velocities.reduce(0, +) / Double(velocities.count)
        let variance = velocities.reduce(0) { $0 + pow($1 - meanVelocity, 2) } / Double(velocities.count)
        let standardDeviation = sqrt(variance)
        
        // Lower standard deviation = higher consistency
        let coefficientOfVariation = abs(meanVelocity) > 0.001 ? standardDeviation / abs(meanVelocity) : 1.0
        return max(0.0, min(1.0, 1.0 - coefficientOfVariation))
    }
    
    func calculateVariation(from values: [Double]) -> Double {
        guard values.count >= 2 else { return 0.0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
        return sqrt(variance) / mean
    }
    
    func generateContentForType(_ type: MotivationalContentType, goal: Goal, motivationLevel: MotivationLevel, tone: MotivationTone, personalizationLevel: PersonalizationLevel) -> MotivationalContent {
        
        let title: String
        let message: String
        let actionable: Bool
        let personalizedElements: [String]
        
        switch type {
        case .encouragement:
            title = "頑張っています！"
            message = "あなたの努力は必ず実を結びます。一歩一歩前進していきましょう。"
            actionable = true
            personalizedElements = ["目標タイプ: \(goal.type.displayName)", "現在の進捗: \(Int(goal.progress * 100))%"]
            
        case .celebration:
            title = "素晴らしい進歩です！"
            message = "今週の進歩を祝いましょう。この調子で続けていけば目標達成間違いなしです。"
            actionable = false
            personalizedElements = ["達成率", "期間"]
            
        case .reminder:
            title = "記録の時間です"
            message = "今日の進捗を記録して、目標に向けた歩みを確認しましょう。"
            actionable = true
            personalizedElements = ["記録タイプ", "推奨時間"]
            
        case .challenge:
            title = "新しいチャレンジ"
            message = "今週は少し挑戦的な目標を設定してみませんか？"
            actionable = true
            personalizedElements = ["チャレンジ内容", "期待される効果"]
            
        case .insight:
            title = "データからの洞察"
            message = "あなたのデータから興味深い傾向が見えてきました。"
            actionable = false
            personalizedElements = ["トレンド分析", "相関関係"]
            
        case .tip:
            title = "今日のヒント"
            message = "目標達成に役立つ実践的なアドバイスをお届けします。"
            actionable = true
            personalizedElements = ["実践方法", "期待される結果"]
        }
        
        return MotivationalContent(
            goalId: goal.id,
            contentType: type,
            title: title,
            message: message,
            actionable: actionable,
            personalizedElements: personalizedElements
        )
    }
    
    func calculatePredictionConfidence(velocity: Double, requiredVelocity: Double, progressHistory: [GoalProgressSnapshot]) -> Double {
        var confidence = 0.5
        
        // Factor 1: Velocity match
        if requiredVelocity > 0 {
            let velocityRatio = min(2.0, velocity / requiredVelocity)
            confidence += (velocityRatio - 1.0) * 0.3
        }
        
        // Factor 2: Data points
        let dataQuality = min(1.0, Double(progressHistory.count) / 10.0)
        confidence += dataQuality * 0.2
        
        // Factor 3: Consistency
        if progressHistory.count >= 3 {
            let consistencyScore = calculateConsistency(from: progressHistory)
            confidence += consistencyScore * 0.3
        }
        
        return min(1.0, max(0.1, confidence))
    }
    
    func generateCompletionScenarios(currentProgress: Double, remainingDays: Int, historicalVelocity: Double) -> [CompletionScenario] {
        var scenarios: [CompletionScenario] = []
        
        // Optimistic scenario
        let optimisticVelocity = historicalVelocity * 1.5
        let optimisticDays = Int((1.0 - currentProgress) / optimisticVelocity)
        scenarios.append(CompletionScenario(
            name: "楽観的シナリオ",
            probability: 0.3,
            description: "順調に進捗が加速した場合",
            completionDate: Calendar.current.date(byAdding: .day, value: optimisticDays, to: Date())!,
            requiredChanges: ["毎日の記録継続", "習慣の最適化"]
        ))
        
        // Realistic scenario
        let realisticDays = historicalVelocity > 0 ? Int((1.0 - currentProgress) / historicalVelocity) : remainingDays * 2
        scenarios.append(CompletionScenario(
            name: "現実的シナリオ",
            probability: 0.5,
            description: "現在のペースを維持した場合",
            completionDate: Calendar.current.date(byAdding: .day, value: realisticDays, to: Date())!,
            requiredChanges: ["現在の習慣継続"]
        ))
        
        // Conservative scenario
        let conservativeDays = remainingDays + (remainingDays / 2)
        scenarios.append(CompletionScenario(
            name: "保守的シナリオ",
            probability: 0.2,
            description: "予期しない障害が発生した場合",
            completionDate: Calendar.current.date(byAdding: .day, value: conservativeDays, to: Date())!,
            requiredChanges: ["目標の再調整", "サポート体制の強化"]
        ))
        
        return scenarios
    }
    
    func calculateOptimizationConfidence(velocity: Double, consistency: Double, timeRemaining: Double) -> Double {
        var confidence = 0.5
        
        // More data = higher confidence
        confidence += consistency * 0.3
        
        // Stable velocity = higher confidence
        if velocity > 0 {
            confidence += 0.2
        }
        
        // More time remaining = lower confidence in predictions
        let timeScore = min(1.0, timeRemaining / 30.0)
        confidence += (1.0 - timeScore) * 0.2
        
        return min(1.0, max(0.2, confidence))
    }
    
    func generateOptimizationSteps(currentTarget: Double, suggestedTarget: Double, outcome: OptimizationOutcome) -> [String] {
        switch outcome {
        case .targetReduction:
            return [
                "現在の目標値を\(String(format: "%.1f", currentTarget))から\(String(format: "%.1f", suggestedTarget))に調整",
                "調整理由をメモに記録",
                "新しい目標に向けて週間計画を更新",
                "進捗を毎日モニタリング"
            ]
        case .targetIncrease:
            return [
                "より挑戦的な目標値\(String(format: "%.1f", suggestedTarget))に更新",
                "追加のサポートリソースを確保",
                "成功時の報酬システムを設計",
                "週次レビューで進捗確認"
            ]
        case .timelineExtension:
            return [
                "期限を適切に延長",
                "新しいタイムラインで計画を再構築",
                "延長理由を記録して学習"
            ]
        case .strategyChange:
            return [
                "現在の戦略を分析",
                "新しいアプローチを検討",
                "試験的に新戦略を実施",
                "結果を測定して評価"
            ]
        }
    }
    
    func generateComparisonInsights(from rankings: [GoalRanking], metric: GoalComparisonMetric) -> [String] {
        guard !rankings.isEmpty else { return [] }
        
        var insights: [String] = []
        
        let topScore = rankings.first?.score ?? 0.0
        let bottomScore = rankings.last?.score ?? 0.0
        let averageScore = rankings.reduce(0) { $0 + $1.score } / Double(rankings.count)
        
        insights.append("平均\(metric.displayName): \(String(format: "%.1f", averageScore * 100))%")
        
        if topScore - bottomScore > 0.3 {
            insights.append("目標間で大きな差があります（\(String(format: "%.1f", (topScore - bottomScore) * 100))%差）")
        }
        
        if averageScore < 0.5 {
            insights.append("全体的に\(metric.displayName)の改善が必要です")
        } else if averageScore > 0.8 {
            insights.append("全体的に優秀な\(metric.displayName)を示しています")
        }
        
        return insights
    }
}