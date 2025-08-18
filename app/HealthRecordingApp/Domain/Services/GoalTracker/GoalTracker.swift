import Foundation

public final class GoalTracker: GoalTrackerProtocol {
    private let logger: AILoggerProtocol
    
    public init(logger: AILoggerProtocol = AILogger()) {
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
        let remainingDays = goal.remainingDays
        
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
        // Start with lower base score for realistic assessment
        var score = 0.2
        
        // Factor 1: Current progress (heavily weighted for poor progress scenarios)
        let currentProgress = goal.progress
        if currentProgress >= 1.0 {
            // Completed goal - maximum achievability
            return 1.0
        } else if currentProgress < 0.1 {
            // Very poor progress - heavy penalty
            score -= 0.1
        } else if currentProgress < 0.3 {
            // Poor progress - moderate penalty
            score += currentProgress * 0.2
        } else {
            // Good progress - full weight
            score += currentProgress * 0.4
        }
        
        // Factor 2: Time remaining (more time = higher achievability)
        let remainingDays = Double(goal.remainingDays)
        let totalDays = Calendar.current.dateComponents([.day], from: goal.createdAt, to: goal.deadline).day ?? 1
        let timeRatio = remainingDays / Double(totalDays)
        score += timeRatio * 0.25
        
        // Factor 3: Progress velocity (if history available)
        if !progressHistory.isEmpty {
            let velocity = calculateProgressVelocity(from: progressHistory, timeframe: .week)
            let requiredVelocity = goal.progress < 1.0 ? (1.0 - goal.progress) / (remainingDays / 7.0) : 0.0
            
            if requiredVelocity > 0 {
                let velocityRatio = min(2.0, velocity / requiredVelocity)
                score += velocityRatio * 0.15
            } else {
                // No velocity data or negative velocity - penalty
                score -= 0.1
            }
        } else {
            // No progress history - penalty for insufficient data
            score -= 0.15
        }
        
        // Additional penalty for very poor overall situation
        if currentProgress < 0.15 && timeRatio < 0.5 {
            score -= 0.2 // Extra penalty for both poor progress and little time
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
            guard let targetDate = Calendar.current.date(byAdding: .day, value: Int(dayInterval * Double(i)), to: goal.createdAt) else {
                continue // Skip this milestone if date calculation fails
            }
            
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
            let personalizedTitle = personalizeTitle(recommendation.title, for: user)
            let personalizedDescription = personalizeDescription(recommendation.description, for: user)
            let personalizedActions = recommendation.actionItems.map { personalizeActionItem($0, for: user) }
            
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
        if velocity > 0 && remainingProgress > 0 {
            let daysToCompletion = remainingProgress / velocity
            let daysToAdd = max(1, Int(ceil(daysToCompletion))) // At least 1 day in the future
            predictedCompletionDate = Calendar.current.date(byAdding: .day, value: daysToAdd, to: Date())
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
        if goalProgress.remainingDays <= 0 {
            // Expired goal - always critical time constraint risk
            riskFactors.append(GoalRiskFactor(
                goalId: goalProgress.goalId,
                type: .timeConstraint,
                severity: .critical,
                description: "目標期限が過ぎています。進捗は\(Int(goalProgress.progressPercentage))%です",
                impact: 1.0,
                mitigation: "目標の見直しまたは新しい期限の設定を検討してください",
                isAddressable: true
            ))
        } else if goalProgress.remainingDays < 7 && goalProgress.progress < 0.8 {
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
        if goalProgress.progress < 0.3 && goalProgress.remainingDays > 0 {
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
        if remainingDays <= 0 {
            // Expired goal - critical motivation level
            return .critical
        } else if remainingDays < 7 && goal.progress < 0.8 {
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
        guard let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: now),
              let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now),
              let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: now) else {
            return GoalEngagementMetrics(
                goalId: goal.id,
                overallEngagement: overallEngagement,
                dailyEngagement: 0.0,
                weeklyEngagement: 0.0,
                monthlyEngagement: 0.0,
                engagementTrend: .stable,
                activityFrequency: 0.0,
                sessionDuration: activities.reduce(0) { $0 + $1.duration } / Double(max(1, activities.count)),
                completionRate: 0.0
            )
        }
        
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
        
        // Consider both absolute progress level and projected achievement
        let absoluteProgressFactor = currentProgress < 0.3 ? 0.7 : 1.0 // Penalty for low absolute progress
        let adjustedProjection = projectedFinalValue * absoluteProgressFactor
        
        var suggestedTarget: Double
        var reasoning: String
        var outcome: OptimizationOutcome
        
        // Lower threshold for target reduction when absolute progress is low
        let reductionThreshold = currentProgress < 0.3 ? 0.9 : 0.8
        let increaseThreshold = currentProgress < 0.3 ? 1.5 : 1.2
        
        if adjustedProjection < goal.targetValue * reductionThreshold {
            // Suggest reducing target
            suggestedTarget = max(adjustedProjection * 1.1, goal.targetValue * 0.7) // 10% buffer, minimum 70% of original
            reasoning = "現在のペースでは目標達成が困難です。より現実的な目標に調整することで、達成感と継続的なモチベーションを維持できます。"
            outcome = .targetReduction
        } else if adjustedProjection > goal.targetValue * increaseThreshold {
            // Suggest increasing target
            suggestedTarget = adjustedProjection * 0.9 // Slightly conservative
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
        
        // Calculate actual daily progress rate (what portion of target is achieved per day)
        let totalDaysElapsed = Double(max(1, Calendar.current.dateComponents([.day], from: goal.createdAt, to: Date()).day ?? 1))
        let historicalDailyProgress = currentProgress.progress / totalDaysElapsed // Progress rate per day
        
        let adjustmentType: TimelineAdjustmentType
        let suggestedDeadline: Date
        var reasoning: String
        
        if historicalDailyProgress < requiredDailyProgress * 0.95 {
            // Need more time
            adjustmentType = .extend
            let additionalDays = Int((requiredDailyProgress * Double(currentProgress.remainingDays) / historicalDailyProgress) - Double(currentProgress.remainingDays))
            guard let newDeadline = Calendar.current.date(byAdding: .day, value: additionalDays, to: goal.deadline) else {
                throw ValidationError.invalidInput("GoalTracker", value: "deadline_extension", reason: "Unable to calculate extended deadline")
            }
            suggestedDeadline = newDeadline
            reasoning = "現在のペース（日々\(String(format: "%.1f", historicalDailyProgress))）を考慮すると、\(additionalDays)日の延長が推奨されます。"
        } else if historicalDailyProgress > requiredDailyProgress * 1.5 {
            // Can finish earlier
            adjustmentType = .compress
            let daysToReduce = Int(Double(currentProgress.remainingDays) - (1.0 - currentProgress.progress) / historicalDailyProgress)
            guard let newDeadline = Calendar.current.date(byAdding: .day, value: -Int(daysToReduce), to: goal.deadline) else {
                throw ValidationError.invalidInput("GoalTracker", value: "deadline_compression", reason: "Unable to calculate compressed deadline")
            }
            suggestedDeadline = newDeadline
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
    
    // MARK: - AI Goal Suggestion System (Phase 2.2)
    
    func generateAIGoalSuggestions(
        for user: User,
        healthRecords: [HealthRecordProtocol],
        analysisDepth: AIAnalysisDepth = .standard
    ) async throws -> [AIGoalSuggestion] {
        let startTime = Date()
        logger.debug("Generating AI goal suggestions", context: [
            "userId": user.id.uuidString,
            "recordCount": healthRecords.count,
            "analysisDepth": analysisDepth.rawValue
        ])
        
        // Step 1: Analyze health data patterns
        let patterns = try await analyzeHealthDataPatterns(
            for: user,
            healthRecords: healthRecords,
            timeframe: .quarter,
            analysisDepth: analysisDepth
        )
        
        // Step 2: Generate base suggestions from patterns
        var suggestions: [AIGoalSuggestion] = []
        
        // Generate suggestions for each data type with sufficient data
        for dataType in patterns.dataTypes {
            let relevantRecords = healthRecords.filter { $0.type == dataType }
            guard relevantRecords.count >= 5 else { continue } // Minimum data requirement
            
            if let suggestion = try await generateDataTypeSpecificSuggestion(
                dataType: dataType,
                records: relevantRecords,
                patterns: patterns,
                user: user,
                analysisDepth: analysisDepth
            ) {
                suggestions.append(suggestion)
            }
        }
        
        // Step 3: Apply seasonal adjustments
        let seasonalAdjustments = try await suggestSeasonalGoalAdjustments(
            for: suggestions.map { createGoalFromSuggestion($0) },
            currentSeason: getCurrentSeason(),
            userHistory: []
        )
        
        // Apply seasonal adjustments to suggestions
        for adjustment in seasonalAdjustments {
            if let index = suggestions.firstIndex(where: { $0.goalType == adjustment.adjustedGoal.type }) {
                suggestions[index] = applySeasonalAdjustment(suggestions[index], adjustment: adjustment)
            }
        }
        
        // Step 4: Assess feasibility and filter
        var feasibleSuggestions: [AIGoalSuggestion] = []
        for suggestion in suggestions {
            let feasibility = try await assessGoalFeasibility(
                proposedGoal: createGoalFromSuggestion(suggestion),
                user: user,
                healthRecords: healthRecords,
                analysisDepth: analysisDepth
            )
            
            // Only include suggestions with good+ feasibility
            if feasibility.assessment.rawValue <= FeasibilityLevel.good.rawValue {
                let enhancedSuggestion = enhanceSuggestionWithFeasibility(suggestion, feasibility: feasibility)
                feasibleSuggestions.append(enhancedSuggestion)
            }
        }
        
        // Step 5: Sort by priority and confidence
        feasibleSuggestions.sort { first, second in
            if first.priority != second.priority {
                return first.priority.rawValue < second.priority.rawValue
            }
            return first.confidence > second.confidence
        }
        
        // Limit to top suggestions based on analysis depth
        let maxSuggestions = analysisDepth == .expert ? 10 : (analysisDepth == .comprehensive ? 8 : 5)
        let finalSuggestions = Array(feasibleSuggestions.prefix(maxSuggestions))
        
        logger.logPerformance("generateAIGoalSuggestions", duration: Date().timeIntervalSince(startTime), success: true)
        logger.info("Generated AI goal suggestions", context: [
            "suggestionCount": finalSuggestions.count,
            "analysisDepth": analysisDepth.rawValue
        ])
        
        return finalSuggestions
    }
    
    func analyzeHealthDataPatterns(
        for user: User,
        healthRecords: [HealthRecordProtocol],
        timeframe: AnalysisTimeframe,
        analysisDepth: AIAnalysisDepth
    ) async throws -> HealthDataPatternAnalysis {
        let startTime = Date()
        logger.debug("Analyzing health data patterns", context: [
            "userId": user.id.uuidString,
            "timeframe": timeframe.rawValue,
            "analysisDepth": analysisDepth.rawValue
        ])
        
        // Filter records by timeframe
        let cutoffDate = Date().addingTimeInterval(-Double(timeframe.days * 24 * 60 * 60))
        let relevantRecords = healthRecords.filter { $0.timestamp >= cutoffDate }
        
        // Group by data type
        let recordsByType = Dictionary(grouping: relevantRecords, by: { $0.type })
        let dataTypes = Array(recordsByType.keys)
        
        // Analyze patterns for each data type
        var patterns: [DataPattern] = []
        var trends: [DataTrend] = []
        var anomalies: [PatternAnomaly] = []
        var correlations: [PatternCorrelation] = []
        var seasonalEffects: [SeasonalEffect] = []
        var weeklyPatterns: [WeeklyPattern] = []
        var dailyPatterns: [DailyPattern] = []
        
        for (dataType, records) in recordsByType {
            guard records.count >= 3 else { continue }
            
            // Detect trends
            if let trend = detectTrend(in: records, for: dataType) {
                trends.append(trend)
            }
            
            // Detect patterns
            let detectedPatterns = detectDataPatterns(in: records, for: dataType, analysisDepth: analysisDepth)
            patterns.append(contentsOf: detectedPatterns)
            
            // Detect anomalies (if depth allows)
            if analysisDepth != .basic {
                let detectedAnomalies = detectPatternAnomalies(in: records, for: dataType)
                anomalies.append(contentsOf: detectedAnomalies)
            }
            
            // Analyze weekly patterns
            if let weeklyPattern = analyzeWeeklyPattern(in: records, for: dataType) {
                weeklyPatterns.append(weeklyPattern)
            }
            
            // Analyze daily patterns (for comprehensive+ analysis)
            if analysisDepth.rawValue >= AIAnalysisDepth.comprehensive.rawValue {
                if let dailyPattern = analyzeDailyPattern(in: records, for: dataType) {
                    dailyPatterns.append(dailyPattern)
                }
            }
        }
        
        // Analyze correlations between data types (for standard+ analysis)
        if analysisDepth != .basic && dataTypes.count >= 2 {
            correlations = analyzePatternCorrelations(recordsByType: recordsByType)
        }
        
        // Analyze seasonal effects (for comprehensive+ analysis)
        if analysisDepth.rawValue >= AIAnalysisDepth.comprehensive.rawValue {
            seasonalEffects = analyzeSeasonalEffects(recordsByType: recordsByType)
        }
        
        // Generate insights from patterns
        let insights = generatePatternInsights(
            patterns: patterns,
            trends: trends,
            anomalies: anomalies,
            correlations: correlations
        )
        
        // Recommend focus areas
        let focusAreas = recommendFocusAreas(
            patterns: patterns,
            trends: trends,
            user: user
        )
        
        // Calculate data quality
        let dataQuality = calculateDataQualityScore(healthRecords: relevantRecords)
        
        // Calculate analysis confidence
        let analysisConfidence = calculateAnalysisConfidence(
            recordCount: relevantRecords.count,
            dataTypes: dataTypes,
            timeframe: timeframe
        )
        
        let analysis = HealthDataPatternAnalysis(
            analysisTimeframe: timeframe,
            dataTypes: dataTypes,
            patterns: patterns,
            trends: trends,
            anomalies: anomalies,
            correlations: correlations,
            seasonalEffects: seasonalEffects,
            weeklyPatterns: weeklyPatterns,
            dailyPatterns: dailyPatterns,
            insights: insights,
            recommendedFocusAreas: focusAreas,
            dataQuality: dataQuality,
            analysisConfidence: analysisConfidence
        )
        
        logger.logPerformance("analyzeHealthDataPatterns", duration: Date().timeIntervalSince(startTime), success: true)
        return analysis
    }
    
    func suggestSeasonalGoalAdjustments(
        for goals: [Goal],
        currentSeason: Season,
        userHistory: [SeasonalPerformanceData]
    ) async throws -> [SeasonalGoalAdjustment] {
        logger.debug("Generating seasonal goal adjustments", context: [
            "goalCount": goals.count,
            "currentSeason": currentSeason.rawValue
        ])
        
        var adjustments: [SeasonalGoalAdjustment] = []
        
        for goal in goals {
            // Analyze historical seasonal performance
            let seasonalEvidence = analyzeSeasonalEvidence(
                for: goal.type,
                season: currentSeason,
                userHistory: userHistory
            )
            
            // Determine appropriate adjustment
            let adjustment = determineSeasonalAdjustment(
                goal: goal,
                season: currentSeason,
                evidence: seasonalEvidence
            )
            
            if let adjustmentType = adjustment.adjustmentType,
               let adjustmentRatio = adjustment.ratio {
                
                // Create adjusted goal
                let adjustedGoal = createAdjustedGoal(
                    from: goal,
                    adjustmentType: adjustmentType,
                    ratio: adjustmentRatio
                )
                
                // Create adaptation strategy
                let adaptationStrategy = createSeasonalAdaptationStrategy(
                    for: goal.type,
                    season: currentSeason,
                    adjustmentType: adjustmentType
                )
                
                // Create implementation guide
                let implementationGuide = createSeasonalImplementationGuide(
                    for: adjustmentType,
                    season: currentSeason,
                    goalType: goal.type
                )
                
                // Calculate validity period (typically the season)
                let validityPeriod = getSeasonDateInterval(for: currentSeason)
                
                let seasonalAdjustment = SeasonalGoalAdjustment(
                    originalGoal: goal,
                    adjustedGoal: adjustedGoal,
                    season: currentSeason,
                    adjustmentType: adjustmentType,
                    adjustmentRatio: adjustmentRatio,
                    rationale: adjustment.rationale,
                    historicalEvidence: seasonalEvidence,
                    adaptationStrategy: adaptationStrategy,
                    validityPeriod: validityPeriod,
                    confidence: adjustment.confidence,
                    implementationGuide: implementationGuide
                )
                
                adjustments.append(seasonalAdjustment)
            }
        }
        
        return adjustments
    }
    
    func createProgressiveGoalPlan(
        finalGoal: Goal,
        user: User,
        planningHorizon: TimeInterval,
        adaptabilityLevel: TimelineFlexibility
    ) async throws -> ProgressiveGoalPlan {
        logger.debug("Creating progressive goal plan", context: [
            "finalGoal": finalGoal.id.uuidString,
            "planningHorizon": planningHorizon,
            "adaptabilityLevel": adaptabilityLevel.rawValue
        ])
        
        // Assess user capability profile
        let userCapabilityProfile = try await assessUserCapabilityProfile(for: user)
        
        // Calculate optimal phase count
        let phaseCount = calculateOptimalPhaseCount(
            finalGoal: finalGoal,
            planningHorizon: planningHorizon,
            userCapability: userCapabilityProfile
        )
        
        // Generate phases
        var phases: [GoalPhase] = []
        let phaseDuration = planningHorizon / Double(phaseCount)
        let startDate = Date()
        
        for phaseNumber in 1...phaseCount {
            let phaseStartDate = startDate.addingTimeInterval(Double(phaseNumber - 1) * phaseDuration)
            let phaseEndDate = startDate.addingTimeInterval(Double(phaseNumber) * phaseDuration)
            
            let targetProgress = Double(phaseNumber) / Double(phaseCount)
            let phaseTargetValue = finalGoal.targetValue * targetProgress
            
            let phase = createGoalPhase(
                phaseNumber: phaseNumber,
                totalPhases: phaseCount,
                startDate: phaseStartDate,
                endDate: phaseEndDate,
                targetValue: phaseTargetValue,
                finalGoal: finalGoal,
                userCapability: userCapabilityProfile
            )
            
            phases.append(phase)
        }
        
        // Create timeline
        let timeline = ProgressiveTimeline(
            totalDuration: planningHorizon,
            phaseCount: phaseCount,
            flexibility: adaptabilityLevel,
            bufferTime: planningHorizon * 0.1, // 10% buffer
            criticalMilestones: phases.map { $0.endDate },
            adaptationWindows: createAdaptationWindows(phases: phases),
            reviewFrequency: determineReviewFrequency(planningHorizon: planningHorizon)
        )
        
        // Generate adaptation points
        let adaptationPoints = generateAdaptationPoints(
            phases: phases,
            flexibility: adaptabilityLevel
        )
        
        // Generate progressive milestones
        let milestones = generateProgressiveMilestones(
            phases: phases,
            finalGoal: finalGoal
        )
        
        // Assess risks and create mitigation strategies
        let riskMitigation = generateRiskMitigationStrategies(
            phases: phases,
            userCapability: userCapabilityProfile
        )
        
        // Generate support resources
        let supportResources = generateSupportResources(
            goalType: finalGoal.type,
            userCapability: userCapabilityProfile
        )
        
        // Define success metrics
        let successMetrics = defineSuccessMetrics(
            phases: phases,
            finalGoal: finalGoal
        )
        
        // Create fallback strategies
        let fallbackStrategies = createFallbackStrategies(
            phases: phases,
            finalGoal: finalGoal,
            userCapability: userCapabilityProfile
        )
        
        // Create motivation plan
        let motivationPlan = createProgressiveMotivationPlan(
            phases: phases,
            userCapability: userCapabilityProfile
        )
        
        // Generate review schedule
        let reviewSchedule = generateReviewSchedule(
            timeline: timeline,
            adaptationPoints: adaptationPoints
        )
        
        return ProgressiveGoalPlan(
            finalGoal: finalGoal,
            phases: phases,
            timeline: timeline,
            userCapabilityProfile: userCapabilityProfile,
            adaptationPoints: adaptationPoints,
            milestones: milestones,
            riskMitigation: riskMitigation,
            supportResources: supportResources,
            successMetrics: successMetrics,
            fallbackStrategies: fallbackStrategies,
            motivationPlan: motivationPlan,
            reviewSchedule: reviewSchedule
        )
    }
    
    func assessGoalFeasibility(
        proposedGoal: Goal,
        user: User,
        healthRecords: [HealthRecordProtocol],
        analysisDepth: AIAnalysisDepth
    ) async throws -> GoalFeasibilityAssessment {
        logger.debug("Assessing goal feasibility", context: [
            "proposedGoal": proposedGoal.id.uuidString,
            "userId": user.id.uuidString,
            "analysisDepth": analysisDepth.rawValue
        ])
        
        // Analyze current capability from health records
        let relevantRecords = healthRecords.filter { $0.type == proposedGoal.type }
        let currentCapability = calculateCurrentCapability(from: relevantRecords, for: proposedGoal.type)
        
        // Calculate feasibility score components
        let targetAmbitiousness = calculateTargetAmbitiousness(
            current: currentCapability,
            target: proposedGoal.targetValue,
            goalType: proposedGoal.type
        )
        
        let timeRealism = calculateTimeRealism(
            current: currentCapability,
            target: proposedGoal.targetValue,
            timeframe: proposedGoal.deadline.timeIntervalSinceNow
        )
        
        let historicalSuccess = calculateHistoricalSuccessRate(
            user: user,
            goalType: proposedGoal.type,
            similarAmbition: targetAmbitiousness
        )
        
        // Overall feasibility score (weighted average)
        let feasibilityScore = (targetAmbitiousness * 0.4) + (timeRealism * 0.4) + (historicalSuccess * 0.2)
        
        // Determine feasibility level
        let assessment = determineFeasibilityLevel(score: feasibilityScore)
        
        // Identify strength factors
        let strengthFactors = identifyStrengthFactors(
            user: user,
            goalType: proposedGoal.type,
            healthRecords: relevantRecords
        )
        
        // Identify risk factors
        let riskFactors = identifyRiskFactors(
            proposedGoal: proposedGoal,
            user: user,
            currentCapability: currentCapability,
            healthRecords: relevantRecords
        )
        
        // Generate recommendations
        let recommendations = generateFeasibilityRecommendations(
            assessment: assessment,
            strengthFactors: strengthFactors,
            riskFactors: riskFactors,
            proposedGoal: proposedGoal
        )
        
        // Generate alternative goals if needed
        let alternativeGoals = assessment.rawValue >= FeasibilityLevel.challenging.rawValue
            ? try await generateAlternativeGoals(
                basedOn: proposedGoal,
                user: user,
                targetFeasibility: .good
            ) : []
        
        // Generate preparation steps
        let requiredPreparation = generatePreparationSteps(
            for: proposedGoal,
            strengthFactors: strengthFactors,
            riskFactors: riskFactors
        )
        
        // Suggest timeline adjustments
        let timelineAdjustments = suggestTimelineAdjustments(
            for: proposedGoal,
            feasibilityScore: feasibilityScore,
            riskFactors: riskFactors
        )
        
        // Calculate resource requirements
        let resourceRequirements = calculateResourceRequirements(
            for: proposedGoal,
            user: user,
            riskFactors: riskFactors
        )
        
        // Calculate success probability
        let successProbability = calculateSuccessProbability(
            feasibilityScore: feasibilityScore,
            strengthFactors: strengthFactors,
            riskFactors: riskFactors
        )
        
        // Calculate confidence in assessment
        let confidence = calculateAssessmentConfidence(
            dataPoints: relevantRecords.count,
            timespan: relevantRecords.isEmpty ? 0 : 
                relevantRecords.max(by: { $0.timestamp < $1.timestamp })!.timestamp.timeIntervalSince(
                    relevantRecords.min(by: { $0.timestamp < $1.timestamp })!.timestamp
                ),
            analysisDepth: analysisDepth
        )
        
        return GoalFeasibilityAssessment(
            proposedGoal: proposedGoal,
            feasibilityScore: feasibilityScore,
            assessment: assessment,
            strengthFactors: strengthFactors,
            riskFactors: riskFactors,
            recommendations: recommendations,
            alternativeGoals: alternativeGoals,
            requiredPreparation: requiredPreparation,
            timelineAdjustments: timelineAdjustments,
            resourceRequirements: resourceRequirements,
            successProbability: successProbability,
            confidence: confidence
        )
    }
    
    func generatePersonalizedGoalTypes(
        for user: User,
        healthRecords: [HealthRecordProtocol],
        preferences: UserGoalPreferences
    ) async throws -> [PersonalizedGoalType] {
        logger.debug("Generating personalized goal types", context: [
            "userId": user.id.uuidString,
            "recordCount": healthRecords.count
        ])
        
        // Analyze available data types
        let availableDataTypes = Set(healthRecords.map { $0.type })
        
        // Analyze user's historical engagement
        let engagementAnalysis = analyzeUserEngagement(
            user: user,
            healthRecords: healthRecords
        )
        
        var personalizedTypes: [PersonalizedGoalType] = []
        
        // Generate suggestions for each available data type
        for dataType in availableDataTypes {
            let relevantRecords = healthRecords.filter { $0.type == dataType }
            guard relevantRecords.count >= 3 else { continue }
            
            let personalizedType = createPersonalizedGoalType(
                dataType: dataType,
                user: user,
                records: relevantRecords,
                preferences: preferences,
                engagement: engagementAnalysis
            )
            
            personalizedTypes.append(personalizedType)
        }
        
        // Sort by recommendation score
        personalizedTypes.sort { $0.recommendationScore > $1.recommendationScore }
        
        return personalizedTypes
    }
    
    func optimizeGoalDifficulty(
        goal: Goal,
        user: User,
        progressHistory: [GoalProgressSnapshot],
        targetSuccessRate: Double
    ) async throws -> GoalDifficultyOptimization {
        logger.debug("Optimizing goal difficulty", context: [
            "goalId": goal.id.uuidString,
            "targetSuccessRate": targetSuccessRate
        ])
        
        // Analyze historical performance
        let performanceAnalysis = analyzeHistoricalPerformance(
            user: user,
            goalType: goal.type,
            progressHistory: progressHistory
        )
        
        // Calculate current difficulty level
        let currentDifficulty = calculateGoalDifficulty(
            goal: goal,
            user: user,
            performanceAnalysis: performanceAnalysis
        )
        
        // Calculate optimal difficulty
        let optimalDifficulty = calculateOptimalDifficulty(
            targetSuccessRate: targetSuccessRate,
            userCapability: performanceAnalysis.averageCapability,
            motivationProfile: performanceAnalysis.motivationProfile
        )
        
        // Generate optimization recommendations
        let optimization = generateDifficultyOptimization(
            currentGoal: goal,
            currentDifficulty: currentDifficulty,
            optimalDifficulty: optimalDifficulty,
            performanceAnalysis: performanceAnalysis
        )
        
        return optimization
    }
    
    func suggestGoalCombinations(
        availableGoals: [Goal],
        user: User,
        maxConcurrentGoals: Int
    ) async throws -> [GoalCombination] {
        logger.debug("Suggesting goal combinations", context: [
            "availableGoalCount": availableGoals.count,
            "maxConcurrentGoals": maxConcurrentGoals
        ])
        
        // Calculate synergies between all goal pairs
        var synergies: [GoalSynergy] = []
        for i in 0..<availableGoals.count {
            for j in (i+1)..<availableGoals.count {
                let synergy = try await calculateGoalSynergies(
                    primary: availableGoals[i],
                    secondary: availableGoals[j],
                    user: user
                )
                synergies.append(synergy)
            }
        }
        
        // Generate combinations using synergy analysis
        let combinations = generateOptimalCombinations(
            goals: availableGoals,
            synergies: synergies,
            maxConcurrent: maxConcurrentGoals,
            user: user
        )
        
        return combinations
    }
    
    func generateAdaptiveMilestones(
        for goal: Goal,
        user: User,
        adaptationTriggers: [AdaptationTrigger],
        progressHistory: [GoalProgressSnapshot]
    ) async throws -> [AdaptiveMilestone] {
        logger.debug("Generating adaptive milestones", context: [
            "goalId": goal.id.uuidString,
            "triggerCount": adaptationTriggers.count
        ])
        
        // Analyze adaptation patterns from history
        let adaptationPatterns = analyzeAdaptationPatterns(
            progressHistory: progressHistory,
            triggers: adaptationTriggers
        )
        
        // Generate base milestones
        let baseMilestones = try await generateMilestones(for: goal, strategy: .adaptive)
        
        // Enhance with adaptive capabilities
        var adaptiveMilestones: [AdaptiveMilestone] = []
        
        for milestone in baseMilestones {
            let adaptiveMilestone = createAdaptiveMilestone(
                from: milestone,
                adaptationTriggers: adaptationTriggers,
                adaptationPatterns: adaptationPatterns,
                user: user
            )
            adaptiveMilestones.append(adaptiveMilestone)
        }
        
        return adaptiveMilestones
    }
    
    func calculateGoalSynergies(
        primary: Goal,
        secondary: Goal,
        user: User
    ) async throws -> GoalSynergy {
        logger.debug("Calculating goal synergies", context: [
            "primaryGoal": primary.id.uuidString,
            "secondaryGoal": secondary.id.uuidString
        ])
        
        // Calculate direct synergy (how achieving one helps the other)
        let directSynergy = calculateDirectSynergy(
            primary: primary,
            secondary: secondary
        )
        
        // Calculate resource competition
        let resourceCompetition = calculateResourceCompetition(
            primary: primary,
            secondary: secondary,
            user: user
        )
        
        // Calculate motivation impact
        let motivationImpact = calculateMotivationImpact(
            primary: primary,
            secondary: secondary,
            user: user
        )
        
        // Calculate difficulty interaction
        let difficultyInteraction = calculateDifficultyInteraction(
            primary: primary,
            secondary: secondary
        )
        
        // Calculate overall synergy score
        let synergyScore = (directSynergy * 0.4) + (motivationImpact * 0.3) - 
                         (resourceCompetition * 0.2) + (difficultyInteraction * 0.1)
        
        return GoalSynergy(
            primaryGoal: primary,
            secondaryGoal: secondary,
            synergyScore: synergyScore,
            synergyType: determineSynergyType(score: synergyScore),
            directSynergy: directSynergy,
            resourceCompetition: resourceCompetition,
            motivationImpact: motivationImpact,
            difficultyInteraction: difficultyInteraction,
            recommendedSequencing: determineOptimalSequencing(
                primary: primary,
                secondary: secondary,
                synergyScore: synergyScore
            ),
            expectedOutcome: predictCombinedOutcome(
                primary: primary,
                secondary: secondary,
                synergyScore: synergyScore
            )
        )
    }
    
    func predictGoalOutcomes(
        for goals: [Goal],
        user: User,
        predictionHorizon: TimeInterval,
        confidenceLevel: Double
    ) async throws -> [GoalOutcomePrediction] {
        logger.debug("Predicting goal outcomes", context: [
            "goalCount": goals.count,
            "predictionHorizon": predictionHorizon,
            "confidenceLevel": confidenceLevel
        ])
        
        var predictions: [GoalOutcomePrediction] = []
        
        for goal in goals {
            // Analyze historical data for similar goals
            let historicalAnalysis = analyzeHistoricalOutcomes(
                goalType: goal.type,
                user: user,
                similarTargets: goal.targetValue
            )
            
            // Calculate prediction factors
            let userCapability = calculateUserCapability(for: goal.type, user: user)
            let goalDifficulty = calculateGoalDifficulty(goal: goal, user: user, performanceAnalysis: historicalAnalysis)
            let environmentalFactors = assessEnvironmentalFactors(for: goal, user: user)
            
            // Generate prediction
            let prediction = generateOutcomePrediction(
                goal: goal,
                historicalAnalysis: historicalAnalysis,
                userCapability: userCapability,
                goalDifficulty: goalDifficulty,
                environmentalFactors: environmentalFactors,
                predictionHorizon: predictionHorizon,
                confidenceLevel: confidenceLevel
            )
            
            predictions.append(prediction)
        }
        
        return predictions
    }
}

// MARK: - Private Helper Methods

private extension GoalTracker {
    
    // MARK: - AI Goal Suggestion Helper Methods
    
    func generateDataTypeSpecificSuggestion(
        dataType: HealthDataType,
        records: [HealthRecordProtocol],
        patterns: HealthDataPatternAnalysis,
        user: User,
        analysisDepth: AIAnalysisDepth
    ) async throws -> AIGoalSuggestion? {
        // Calculate baseline statistics
        let values = records.map { $0.value }
        guard !values.isEmpty else { return nil }
        
        let currentAverage = values.reduce(0, +) / Double(values.count)
        let currentMax = values.max() ?? 0
        let currentMin = values.min() ?? 0
        
        // Determine goal direction and target based on data type
        let (suggestedTarget, rationale) = calculateSuggestedTarget(
            dataType: dataType,
            currentAverage: currentAverage,
            currentMax: currentMax,
            patterns: patterns,
            user: user
        )
        
        // Determine timeframe based on data type and ambition
        let timeframe = determineOptimalTimeframe(
            dataType: dataType,
            currentValue: currentAverage,
            targetValue: suggestedTarget,
            userHistory: records
        )
        
        // Calculate confidence based on data quality and patterns
        let confidence = calculateSuggestionConfidence(
            dataType: dataType,
            recordCount: records.count,
            patterns: patterns,
            analysisDepth: analysisDepth
        )
        
        // Determine priority based on health impact and user needs
        let priority = determineSuggestionPriority(
            dataType: dataType,
            patterns: patterns,
            user: user
        )
        
        // Generate evidence sources
        let evidenceSource = generateEvidenceSources(
            dataType: dataType,
            records: records,
            patterns: patterns
        )
        
        // Generate personalization factors
        let personalizedFactors = generatePersonalizationFactors(
            user: user,
            dataType: dataType,
            patterns: patterns
        )
        
        // Estimate difficulty
        let estimatedDifficulty = estimateGoalDifficulty(
            dataType: dataType,
            currentValue: currentAverage,
            targetValue: suggestedTarget,
            timeframe: timeframe,
            userHistory: records
        )
        
        // Generate expected benefits
        let expectedBenefits = generateExpectedBenefits(
            dataType: dataType,
            targetValue: suggestedTarget,
            currentValue: currentAverage
        )
        
        // Create adaptation strategy
        let adaptationStrategy = createAdaptationStrategy(
            dataType: dataType,
            targetValue: suggestedTarget,
            user: user
        )
        
        return AIGoalSuggestion(
            goalType: dataType,
            suggestedTarget: suggestedTarget,
            targetUnit: dataType.defaultUnit,
            timeframe: timeframe,
            priority: priority,
            confidence: confidence,
            rationale: rationale,
            evidenceSource: evidenceSource,
            personalizedFactors: personalizedFactors,
            estimatedDifficulty: estimatedDifficulty,
            expectedBenefits: expectedBenefits,
            adaptationStrategy: adaptationStrategy
        )
    }
    
    func createGoalFromSuggestion(_ suggestion: AIGoalSuggestion) -> Goal {
        return Goal(
            id: UUID(),
            type: suggestion.goalType,
            targetValue: suggestion.suggestedTarget,
            deadline: Date().addingTimeInterval(suggestion.timeframe.timeInterval),
            isActive: true
        )
    }
    
    func getCurrentSeason() -> Season {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 3, 4, 5: return .spring
        case 6, 7, 8: return .summer
        case 9, 10, 11: return .autumn
        default: return .winter
        }
    }
    
    func applySeasonalAdjustment(_ suggestion: AIGoalSuggestion, adjustment: SeasonalGoalAdjustment) -> AIGoalSuggestion {
        return AIGoalSuggestion(
            goalType: suggestion.goalType,
            suggestedTarget: adjustment.adjustedGoal.targetValue,
            targetUnit: suggestion.targetUnit,
            timeframe: suggestion.timeframe,
            priority: suggestion.priority,
            confidence: suggestion.confidence * adjustment.confidence,
            rationale: "\(suggestion.rationale) 季節調整: \(adjustment.rationale)",
            evidenceSource: suggestion.evidenceSource + adjustment.historicalEvidence,
            personalizedFactors: suggestion.personalizedFactors,
            estimatedDifficulty: suggestion.estimatedDifficulty,
            expectedBenefits: suggestion.expectedBenefits,
            adaptationStrategy: suggestion.adaptationStrategy
        )
    }
    
    func enhanceSuggestionWithFeasibility(_ suggestion: AIGoalSuggestion, feasibility: GoalFeasibilityAssessment) -> AIGoalSuggestion {
        return AIGoalSuggestion(
            goalType: suggestion.goalType,
            suggestedTarget: suggestion.suggestedTarget,
            targetUnit: suggestion.targetUnit,
            timeframe: suggestion.timeframe,
            priority: suggestion.priority,
            confidence: min(suggestion.confidence, feasibility.confidence),
            rationale: suggestion.rationale,
            evidenceSource: suggestion.evidenceSource,
            personalizedFactors: suggestion.personalizedFactors,
            estimatedDifficulty: suggestion.estimatedDifficulty,
            expectedBenefits: suggestion.expectedBenefits,
            prerequisites: feasibility.requiredPreparation.map { preparation in
                GoalPrerequisite(
                    id: UUID(),
                    description: preparation.description,
                    type: .preparation,
                    isCompleted: false,
                    estimatedDuration: preparation.estimatedDuration
                )
            },
            adaptationStrategy: suggestion.adaptationStrategy
        )
    }
    
    // MARK: - Pattern Analysis Helper Methods
    
    func detectTrend(in records: [HealthRecordProtocol], for dataType: HealthDataType) -> DataTrend? {
        guard records.count >= 3 else { return nil }
        
        let sortedRecords = records.sorted { $0.timestamp < $1.timestamp }
        let values = sortedRecords.map { $0.value }
        
        // Simple linear regression for trend detection
        let n = Double(values.count)
        let sumX = (0..<values.count).reduce(0) { $0 + $1 }
        let sumY = values.reduce(0, +)
        let sumXY = zip(0..<values.count, values).reduce(0) { $0 + Double($1.0) * $1.1 }
        let sumX2 = (0..<values.count).reduce(0) { $0 + $1 * $1 }
        
        let slope = (n * sumXY - Double(sumX) * sumY) / (n * Double(sumX2) - Double(sumX * sumX))
        
        let trendDirection: TrendDirection = slope > 0.1 ? .increasing : 
                                           slope < -0.1 ? .decreasing : .stable
        
        return DataTrend(
            id: UUID(),
            dataType: dataType,
            direction: trendDirection,
            magnitude: abs(slope),
            confidence: calculateTrendConfidence(from: values),
            timeRange: DateInterval(start: sortedRecords.first!.timestamp, 
                                  end: sortedRecords.last!.timestamp),
            description: generateTrendDescription(direction: trendDirection, magnitude: abs(slope), dataType: dataType)
        )
    }
    
    func detectDataPatterns(in records: [HealthRecordProtocol], for dataType: HealthDataType, analysisDepth: AIAnalysisDepth) -> [DataPattern] {
        var patterns: [DataPattern] = []
        
        guard records.count >= 7 else { return patterns }
        
        let sortedRecords = records.sorted { $0.timestamp < $1.timestamp }
        let values = sortedRecords.map { $0.value }
        
        // Detect plateau patterns
        if let plateauPattern = detectPlateauPattern(values: values, dataType: dataType) {
            patterns.append(plateauPattern)
        }
        
        // Detect cyclical patterns (if depth allows)
        if analysisDepth != .basic {
            if let cyclicalPattern = detectCyclicalPattern(records: sortedRecords, dataType: dataType) {
                patterns.append(cyclicalPattern)
            }
        }
        
        // Detect volatility patterns
        if let volatilityPattern = detectVolatilityPattern(values: values, dataType: dataType) {
            patterns.append(volatilityPattern)
        }
        
        return patterns
    }
    
    func detectPatternAnomalies(in records: [HealthRecordProtocol], for dataType: HealthDataType) -> [PatternAnomaly] {
        var anomalies: [PatternAnomaly] = []
        
        guard records.count >= 5 else { return anomalies }
        
        let values = records.map { $0.value }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        let standardDeviation = sqrt(variance)
        
        // Statistical outlier detection
        for (index, record) in records.enumerated() {
            let zScore = abs(record.value - mean) / standardDeviation
            
            if zScore > 2.5 { // 2.5 sigma threshold
                let anomaly = PatternAnomaly(
                    id: UUID(),
                    dataType: dataType,
                    timestamp: record.timestamp,
                    observedValue: record.value,
                    expectedValue: mean,
                    severity: zScore > 3.0 ? .high : .medium,
                    confidence: min(0.95, zScore / 3.0),
                    description: "統計的外れ値を検出: \(dataType.displayName)が平均から\(String(format: "%.1f", zScore))σ逸脱"
                )
                anomalies.append(anomaly)
            }
        }
        
        return anomalies
    }
    
    func analyzeWeeklyPattern(in records: [HealthRecordProtocol], for dataType: HealthDataType) -> WeeklyPattern? {
        guard records.count >= 14 else { return nil }
        
        let calendar = Calendar.current
        var dayOfWeekValues: [Int: [Double]] = [:]
        
        // Group values by day of week
        for record in records {
            let dayOfWeek = calendar.component(.weekday, from: record.timestamp)
            dayOfWeekValues[dayOfWeek, default: []].append(record.value)
        }
        
        // Calculate averages for each day
        var dailyAverages: [Int: Double] = [:]
        for (day, values) in dayOfWeekValues {
            dailyAverages[day] = values.reduce(0, +) / Double(values.count)
        }
        
        // Check if there's a significant weekly pattern
        let allAverages = Array(dailyAverages.values)
        let weeklyMean = allAverages.reduce(0, +) / Double(allAverages.count)
        let weeklyVariance = allAverages.map { pow($0 - weeklyMean, 2) }.reduce(0, +) / Double(allAverages.count)
        
        // If variance is significant, we have a weekly pattern
        if weeklyVariance > weeklyMean * 0.1 {
            return WeeklyPattern(
                id: UUID(),
                dataType: dataType,
                dailyAverages: dailyAverages,
                variance: weeklyVariance,
                significance: min(0.95, weeklyVariance / weeklyMean),
                description: generateWeeklyPatternDescription(dailyAverages: dailyAverages, dataType: dataType)
            )
        }
        
        return nil
    }
    
    func analyzeDailyPattern(in records: [HealthRecordProtocol], for dataType: HealthDataType) -> DailyPattern? {
        guard records.count >= 20 else { return nil }
        
        let calendar = Calendar.current
        var hourlyValues: [Int: [Double]] = [:]
        
        // Group values by hour of day
        for record in records {
            let hour = calendar.component(.hour, from: record.timestamp)
            hourlyValues[hour, default: []].append(record.value)
        }
        
        // Calculate averages for each hour
        var hourlyAverages: [Int: Double] = [:]
        for (hour, values) in hourlyValues {
            hourlyAverages[hour] = values.reduce(0, +) / Double(values.count)
        }
        
        // Check if there's a significant daily pattern
        let allAverages = Array(hourlyAverages.values)
        guard !allAverages.isEmpty else { return nil }
        
        let dailyMean = allAverages.reduce(0, +) / Double(allAverages.count)
        let dailyVariance = allAverages.map { pow($0 - dailyMean, 2) }.reduce(0, +) / Double(allAverages.count)
        
        // If variance is significant, we have a daily pattern
        if dailyVariance > dailyMean * 0.05 {
            return DailyPattern(
                id: UUID(),
                dataType: dataType,
                hourlyAverages: hourlyAverages,
                peakHours: findPeakHours(hourlyAverages: hourlyAverages),
                variance: dailyVariance,
                significance: min(0.95, dailyVariance / dailyMean),
                description: generateDailyPatternDescription(hourlyAverages: hourlyAverages, dataType: dataType)
            )
        }
        
        return nil
    }
    
    func analyzePatternCorrelations(recordsByType: [HealthDataType: [HealthRecordProtocol]]) -> [PatternCorrelation] {
        var correlations: [PatternCorrelation] = []
        let dataTypes = Array(recordsByType.keys)
        
        // Calculate correlations between all pairs of data types
        for i in 0..<dataTypes.count {
            for j in (i+1)..<dataTypes.count {
                let type1 = dataTypes[i]
                let type2 = dataTypes[j]
                
                guard let records1 = recordsByType[type1],
                      let records2 = recordsByType[type2],
                      records1.count >= 5, records2.count >= 5 else { continue }
                
                if let correlation = calculatePatternCorrelation(
                    records1: records1,
                    records2: records2,
                    type1: type1,
                    type2: type2
                ) {
                    correlations.append(correlation)
                }
            }
        }
        
        return correlations
    }
    
    func analyzeSeasonalEffects(recordsByType: [HealthDataType: [HealthRecordProtocol]]) -> [SeasonalEffect] {
        var seasonalEffects: [SeasonalEffect] = []
        
        for (dataType, records) in recordsByType {
            guard records.count >= 30 else { continue } // Need at least 30 records for seasonal analysis
            
            if let seasonalEffect = analyzeSeasonalEffect(records: records, dataType: dataType) {
                seasonalEffects.append(seasonalEffect)
            }
        }
        
        return seasonalEffects
    }
    
    // MARK: - Calculation Helper Methods
    
    func calculateSuggestedTarget(
        dataType: HealthDataType,
        currentAverage: Double,
        currentMax: Double,
        patterns: HealthDataPatternAnalysis,
        user: User
    ) -> (target: Double, rationale: String) {
        
        switch dataType {
        case .weight:
            // Weight loss goal based on current weight and health recommendations
            let targetWeight = max(currentAverage * 0.9, user.targetWeight)
            return (targetWeight, "健康的な体重減少目標として現在の体重から10%削減を提案")
            
        case .steps:
            // Steps goal based on current average and incremental improvement
            let improvementFactor = currentAverage < 5000 ? 1.5 : 1.2
            let targetSteps = min(currentAverage * improvementFactor, 15000)
            return (targetSteps, "現在の歩数から段階的な向上を目指す目標")
            
        case .calories:
            // Calorie burn goal based on activity level
            let targetCalories = currentAverage * 1.15
            return (targetCalories, "活動レベル向上のため15%増加目標")
            
        case .heartRate:
            // Heart rate optimization (depends on context - resting vs exercise)
            let targetHR = currentAverage > 100 ? currentAverage * 0.9 : currentAverage * 1.1
            return (targetHR, "心拍数の最適化目標")
            
        case .sleep:
            // Sleep optimization - target 7-8 hours
            let targetSleep = currentAverage < 7 ? min(7.5, currentAverage + 1) : 
                             currentAverage > 8.5 ? max(7.5, currentAverage - 0.5) : currentAverage
            return (targetSleep, "推奨睡眠時間への最適化")
            
        default:
            // Generic improvement goal
            let targetValue = currentAverage * 1.1
            return (targetValue, "段階的な改善目標")
        }
    }
    
    func determineOptimalTimeframe(
        dataType: HealthDataType,
        currentValue: Double,
        targetValue: Double,
        userHistory: [HealthRecordProtocol]
    ) -> GoalTimeframe {
        
        let changeRate = abs(targetValue - currentValue) / currentValue
        
        switch dataType {
        case .weight:
            // Weight loss should be gradual
            return changeRate > 0.15 ? .month : .quarter
            
        case .steps, .calories:
            // Activity goals can be achieved faster
            return changeRate > 0.3 ? .month : .quarter
            
        case .sleep:
            // Sleep habits can be adjusted relatively quickly
            return .month
            
        case .heartRate:
            // Heart rate improvements need time
            return .quarter
            
        default:
            // Default based on change magnitude
            return changeRate > 0.2 ? .quarter : .month
        }
    }
    
    func calculateSuggestionConfidence(
        dataType: HealthDataType,
        recordCount: Int,
        patterns: HealthDataPatternAnalysis,
        analysisDepth: AIAnalysisDepth
    ) -> Double {
        var confidence = 0.5 // Base confidence
        
        // Adjust based on data quantity
        if recordCount >= 30 {
            confidence += 0.3
        } else if recordCount >= 10 {
            confidence += 0.2
        } else if recordCount >= 5 {
            confidence += 0.1
        }
        
        // Adjust based on pattern strength
        let relevantPatterns = patterns.patterns.filter { $0.dataType == dataType }
        if !relevantPatterns.isEmpty {
            let avgPatternStrength = relevantPatterns.map { $0.strength }.reduce(0, +) / Double(relevantPatterns.count)
            confidence += avgPatternStrength * 0.2
        }
        
        // Adjust based on analysis depth
        switch analysisDepth {
        case .expert:
            confidence += 0.1
        case .comprehensive:
            confidence += 0.05
        default:
            break
        }
        
        return min(0.95, confidence)
    }
    
    func determineSuggestionPriority(
        dataType: HealthDataType,
        patterns: HealthDataPatternAnalysis,
        user: User
    ) -> AIGoalPriority {
        
        // Check for concerning patterns
        let relevantAnomalies = patterns.anomalies.filter { $0.dataType == dataType }
        if !relevantAnomalies.isEmpty {
            let highSeverityAnomalies = relevantAnomalies.filter { $0.severity == .high }
            if !highSeverityAnomalies.isEmpty {
                return .critical
            }
        }
        
        // Data type based priority
        switch dataType {
        case .weight, .bloodPressure:
            return .high
        case .steps, .calories, .sleep:
            return .medium
        case .heartRate:
            return .medium
        default:
            return .low
        }
    }
    
    // Additional helper methods would continue here...
    // Due to length constraints, I'm showing the pattern but would need to implement all referenced methods
    
    func generateEvidenceSources(
        dataType: HealthDataType,
        records: [HealthRecordProtocol],
        patterns: HealthDataPatternAnalysis
    ) -> [EvidenceSource] {
        let timeRange = DateInterval(
            start: records.min { $0.timestamp < $1.timestamp }?.timestamp ?? Date(),
            end: records.max { $0.timestamp < $1.timestamp }?.timestamp ?? Date()
        )
        
        return [
            EvidenceSource(
                type: .healthData,
                description: "\(dataType.displayName)の\(records.count)件のデータ",
                reliability: 0.9,
                dataPoints: records.count,
                timeRange: timeRange,
                source: "HealthKit自動収集"
            )
        ]
    }
    
    func generatePersonalizationFactors(
        user: User,
        dataType: HealthDataType,
        patterns: HealthDataPatternAnalysis
    ) -> [PersonalizationFactor] {
        return [
            PersonalizationFactor(
                id: UUID(),
                factor: .userAge,
                description: "年齢を考慮した目標設定",
                impact: 0.7,
                confidence: 0.9
            )
        ]
    }
    
    // MARK: - Additional AI Goal Suggestion Helper Methods
    
    func estimateGoalDifficulty(
        dataType: HealthDataType,
        currentValue: Double,
        targetValue: Double,
        timeframe: GoalTimeframe,
        userHistory: [HealthRecordProtocol]
    ) -> GoalDifficulty {
        let changeRequired = abs(targetValue - currentValue) / currentValue
        let timeAvailable = timeframe.timeInterval
        
        // Analyze historical change rate capability
        let historicalChangeRate = calculateHistoricalChangeRate(
            from: userHistory,
            dataType: dataType
        )
        
        let requiredChangeRate = changeRequired / (timeAvailable / (24 * 60 * 60)) // per day
        let difficultyRatio = requiredChangeRate / max(historicalChangeRate, 0.001)
        
        switch difficultyRatio {
        case 0...0.5:
            return .easy
        case 0.5...1.0:
            return .moderate
        case 1.0...2.0:
            return .challenging
        default:
            return .extreme
        }
    }
    
    func generateExpectedBenefits(
        dataType: HealthDataType,
        targetValue: Double,
        currentValue: Double
    ) -> [ExpectedBenefit] {
        let improvementPercentage = abs(targetValue - currentValue) / currentValue * 100
        
        var benefits: [ExpectedBenefit] = []
        
        switch dataType {
        case .weight:
            if targetValue < currentValue {
                benefits.append(ExpectedBenefit(
                    category: .physical,
                    description: "体重減少により心血管疾患リスクが\(String(format: "%.1f", improvementPercentage * 0.02))%減少",
                    likelihood: 0.8,
                    timeframe: .month
                ))
                benefits.append(ExpectedBenefit(
                    category: .mental,
                    description: "自己肯定感の向上",
                    likelihood: 0.9,
                    timeframe: .week
                ))
            }
            
        case .steps:
            benefits.append(ExpectedBenefit(
                category: .physical,
                description: "心肺機能の向上",
                likelihood: 0.85,
                timeframe: .month
            ))
            benefits.append(ExpectedBenefit(
                category: .mental,
                description: "ストレス軽減とメンタルヘルス改善",
                likelihood: 0.75,
                timeframe: .week
            ))
            
        case .sleep:
            benefits.append(ExpectedBenefit(
                category: .mental,
                description: "認知機能とメンタルヘルスの改善",
                likelihood: 0.9,
                timeframe: .week
            ))
            benefits.append(ExpectedBenefit(
                category: .physical,
                description: "免疫機能の強化",
                likelihood: 0.7,
                timeframe: .month
            ))
            
        default:
            benefits.append(ExpectedBenefit(
                category: .general,
                description: "全体的な健康状態の改善",
                likelihood: 0.8,
                timeframe: .month
            ))
        }
        
        return benefits
    }
    
    func createAdaptationStrategy(
        dataType: HealthDataType,
        targetValue: Double,
        user: User
    ) -> AdaptationStrategy {
        let baseStrategy = AdaptationStrategy(
            triggerConditions: generateTriggerConditions(for: dataType),
            adjustmentMethods: generateAdjustmentMethods(for: dataType),
            fallbackPlans: generateFallbackPlans(for: dataType, user: user),
            reviewFrequency: determineReviewFrequency(for: dataType),
            flexibilityLevel: .moderate
        )
        
        return baseStrategy
    }
    
    func generateTriggerConditions(for dataType: HealthDataType) -> [AdaptationTrigger] {
        var triggers: [AdaptationTrigger] = []
        
        // Common triggers for all data types
        triggers.append(AdaptationTrigger(
            type: .progressStagnation,
            threshold: 0.05,
            timeWindow: .week,
            description: "進捗が1週間以上停滞している"
        ))
        
        triggers.append(AdaptationTrigger(
            type: .significantRegression,
            threshold: 0.15,
            timeWindow: .day,
            description: "大幅な後退が検出された"
        ))
        
        // Data type specific triggers
        switch dataType {
        case .weight:
            triggers.append(AdaptationTrigger(
                type: .plateauDetected,
                threshold: 0.02,
                timeWindow: .month,
                description: "体重減少のプラトー期を検出"
            ))
            
        case .steps:
            triggers.append(AdaptationTrigger(
                type: .consistentUnderperformance,
                threshold: 0.8,
                timeWindow: .week,
                description: "目標歩数の80%を下回る日が続いている"
            ))
            
        case .sleep:
            triggers.append(AdaptationTrigger(
                type: .sleepQualityDegradation,
                threshold: 0.2,
                timeWindow: .week,
                description: "睡眠の質が継続的に低下している"
            ))
            
        default:
            break
        }
        
        return triggers
    }
    
    func generateAdjustmentMethods(for dataType: HealthDataType) -> [AdjustmentMethod] {
        var methods: [AdjustmentMethod] = []
        
        // Universal adjustment methods
        methods.append(AdjustmentMethod(
            type: .targetReduction,
            parameters: ["reductionPercentage": 0.15],
            description: "目標値を15%下方修正"
        ))
        
        methods.append(AdjustmentMethod(
            type: .timelineExtension,
            parameters: ["extensionWeeks": 2],
            description: "達成期限を2週間延長"
        ))
        
        // Data type specific methods
        switch dataType {
        case .weight:
            methods.append(AdjustmentMethod(
                type: .phaseBasedApproach,
                parameters: ["phaseCount": 3],
                description: "段階的な体重減少アプローチに変更"
            ))
            
        case .steps:
            methods.append(AdjustmentMethod(
                type: .weeklyTarget,
                parameters: ["weeklyIncrease": 500],
                description: "週単位での歩数目標の段階的増加"
            ))
            
        default:
            break
        }
        
        return methods
    }
    
    func generateFallbackPlans(for dataType: HealthDataType, user: User) -> [FallbackPlan] {
        var fallbackPlans: [FallbackPlan] = []
        
        // Maintenance plan as universal fallback
        fallbackPlans.append(FallbackPlan(
            name: "現状維持プラン",
            description: "現在の水準を維持することに焦点を当てる",
            triggerConditions: ["目標達成困難", "モチベーション低下"],
            actions: ["現在値の維持", "習慣の定着", "次の挑戦に向けた準備"],
            duration: .month
        ))
        
        switch dataType {
        case .weight:
            fallbackPlans.append(FallbackPlan(
                name: "健康的な体重維持プラン",
                description: "無理のない範囲での体重管理",
                triggerConditions: ["急激な体重変動", "健康上の懸念"],
                actions: ["栄養バランス重視", "適度な運動", "専門家相談"],
                duration: .quarter
            ))
            
        case .steps:
            fallbackPlans.append(FallbackPlan(
                name: "基本活動量確保プラン",
                description: "最低限の活動量確保に重点",
                triggerConditions: ["継続的な目標未達", "身体的制約"],
                actions: ["短時間の散歩", "階段利用", "日常活動の工夫"],
                duration: .month
            ))
            
        default:
            break
        }
        
        return fallbackPlans
    }
    
    func calculateHistoricalChangeRate(
        from records: [HealthRecordProtocol],
        dataType: HealthDataType
    ) -> Double {
        guard records.count >= 2 else { return 0.001 }
        
        let sortedRecords = records.sorted { $0.timestamp < $1.timestamp }
        let timeSpan = sortedRecords.last!.timestamp.timeIntervalSince(sortedRecords.first!.timestamp)
        let valueChange = abs(sortedRecords.last!.value - sortedRecords.first!.value)
        let relativeChange = valueChange / max(sortedRecords.first!.value, 0.001)
        
        // Return change rate per day
        return relativeChange / (timeSpan / (24 * 60 * 60))
    }
    
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
        case .bloodPressure:
            // Use latest value for blood pressure
            return records.max(by: { $0.timestamp < $1.timestamp })?.value ?? 0.0
        case .sleep:
            // Use latest daily sleep value
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let todayRecords = records.filter { calendar.startOfDay(for: $0.timestamp) >= today }
            return todayRecords.max(by: { $0.timestamp < $1.timestamp })?.value ?? 0.0
        case .hydration:
            // Sum daily hydration values
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let todayRecords = records.filter { calendar.startOfDay(for: $0.timestamp) >= today }
            return todayRecords.reduce(0) { $0 + $1.value }
        case .exercise:
            // Sum daily exercise values
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let todayRecords = records.filter { calendar.startOfDay(for: $0.timestamp) >= today }
            return todayRecords.reduce(0) { $0 + $1.value }
        case .custom:
            // Use latest value for custom goals
            return records.max(by: { $0.timestamp < $1.timestamp })?.value ?? 0.0
        }
    }
    
    func calculateExpectedProgress(for goal: Goal) -> Double {
        let totalDays = Calendar.current.dateComponents([.day], from: goal.createdAt, to: goal.deadline).day ?? 1
        let elapsedDays = Calendar.current.dateComponents([.day], from: goal.createdAt, to: Date()).day ?? 0
        return min(1.0, Double(elapsedDays) / Double(totalDays))
    }
    
    func determineMotivationLevel(progress: Double, isOnTrack: Bool, achievabilityScore: Double, remainingDays: Int) -> MotivationLevel {
        // Special handling for expired goals
        if remainingDays <= 0 {
            // Expired goal - return critical or low based on progress
            return progress < 0.5 ? .critical : .low
        }
        
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
    
    func personalizeTitle(_ title: String, for user: User) -> String {
        // Handle generic titles
        if title.contains("Generic") {
            return "\(user.name)さんへの専用アドバイス"
        }
        
        // Replace generic pronouns
        return title
            .replacingOccurrences(of: "あなた", with: user.name + "さん")
            .replacingOccurrences(of: "ユーザー", with: user.name + "さん")
    }
    
    func personalizeDescription(_ description: String, for user: User) -> String {
        // Handle generic descriptions
        if description.contains("Generic") {
            return "\(user.name)さんに最適化された詳細なガイダンスをお届けします。"
        }
        
        // Replace generic pronouns and add personal touches
        return description
            .replacingOccurrences(of: "あなた", with: user.name + "さん")
            .replacingOccurrences(of: "ユーザー", with: user.name + "さん")
    }
    
    func personalizeActionItem(_ actionItem: String, for user: User) -> String {
        // Handle generic actions
        if actionItem.contains("Generic") {
            return "\(user.name)さん専用のカスタマイズされた行動プラン"
        }
        
        // Replace generic pronouns
        return actionItem
            .replacingOccurrences(of: "あなた", with: user.name + "さん")
            .replacingOccurrences(of: "ユーザー", with: user.name + "さん")
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
        if let optimisticDate = Calendar.current.date(byAdding: .day, value: optimisticDays, to: Date()) {
            scenarios.append(CompletionScenario(
                name: "楽観的シナリオ",
                probability: 0.3,
                description: "順調に進捗が加速した場合",
                completionDate: optimisticDate,
                requiredChanges: ["毎日の記録継続", "習慣の最適化"]
            ))
        }
        
        // Realistic scenario
        let realisticDays = historicalVelocity > 0 ? Int((1.0 - currentProgress) / historicalVelocity) : remainingDays * 2
        if let realisticDate = Calendar.current.date(byAdding: .day, value: realisticDays, to: Date()) {
            scenarios.append(CompletionScenario(
                name: "現実的シナリオ",
                probability: 0.5,
                description: "現在のペースを維持した場合",
                completionDate: realisticDate,
                requiredChanges: ["現在の習慣継続"]
            ))
        }
        
        // Conservative scenario
        let conservativeDays = remainingDays + (remainingDays / 2)
        if let conservativeDate = Calendar.current.date(byAdding: .day, value: conservativeDays, to: Date()) {
            scenarios.append(CompletionScenario(
                name: "保守的シナリオ",
                probability: 0.2,
                description: "予期しない障害が発生した場合",
                completionDate: conservativeDate,
                requiredChanges: ["目標の再調整", "サポート体制の強化"]
            ))
        }
        
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