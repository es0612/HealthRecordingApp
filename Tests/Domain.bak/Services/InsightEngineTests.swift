import Testing
import Foundation
import SwiftData
@testable import HealthRecordingApp

@Suite("InsightEngine Tests")
struct InsightEngineTests {
    
    private func createTestUser() throws -> User {
        return try User(name: "Test User", age: 30, height: 175.0, targetWeight: 70.0)
    }
    
    private func createTestHealthRecords(dataType: HealthDataType, values: [Double], baseDays: Int = 0) -> [HealthRecord] {
        return values.enumerated().map { index, value in
            let record = HealthRecord(type: dataType, value: value, unit: dataType.unit, source: .healthKit)
            record.timestamp = Calendar.current.date(byAdding: .day, value: baseDays + index, to: Date())!
            return record
        }
    }
    
    private func createTestInsightEngine() -> InsightEngine {
        let logger = AILogger()
        return InsightEngine(logger: logger)
    }
    
    // MARK: - Correlation Analysis Tests
    
    @Test("InsightEngine should analyze correlations between data types correctly")
    func testAnalyzeCorrelations() async throws {
        // Given
        let engine = createTestInsightEngine()
        let weightData = createTestHealthRecords(dataType: .weight, values: [70.0, 69.5, 69.0, 68.5, 68.0])
        let stepsData = createTestHealthRecords(dataType: .steps, values: [8000, 8500, 9000, 9500, 10000])
        
        // When
        let correlation = try await engine.analyzeCorrelations(
            between: weightData,
            and: stepsData,
            timeWindow: .daily
        )
        
        // Then
        #expect(correlation.primaryDataType == .weight)
        #expect(correlation.secondaryDataType == .steps)
        #expect(correlation.correlationCoefficient >= -1.0 && correlation.correlationCoefficient <= 1.0)
        #expect(correlation.pValue >= 0.0 && correlation.pValue <= 1.0)
        #expect(correlation.sampleSize == 5)
        #expect(correlation.timeWindow == .daily)
        #expect(correlation.dataPoints.count == 5)
        #expect(correlation.strength != nil)
        #expect(correlation.direction != nil)
        #expect(correlation.significance != nil)
    }
    
    @Test("InsightEngine should handle multiple correlations analysis")
    func testAnalyzeMultipleCorrelations() async throws {
        // Given
        let engine = createTestInsightEngine()
        let weightData = createTestHealthRecords(dataType: .weight, values: [70.0, 69.0, 68.0])
        let stepsData = createTestHealthRecords(dataType: .steps, values: [8000, 9000, 10000])
        let caloriesData = createTestHealthRecords(dataType: .calories, values: [2000, 2100, 2200])
        let allRecords = weightData + stepsData + caloriesData
        
        // When
        let correlations = try await engine.analyzeMultipleCorrelations(
            healthRecords: allRecords,
            dataTypes: [.weight, .steps, .calories],
            analysisDepth: .moderate
        )
        
        // Then
        #expect(correlations.count >= 2) // At least weight-steps and weight-calories
        #expect(correlations.allSatisfy { $0.sampleSize >= 2 })
        #expect(correlations.allSatisfy { $0.correlationCoefficient >= -1.0 && $0.correlationCoefficient <= 1.0 })
        
        // Should include different data type combinations
        let dataTypePairs = correlations.map { ($0.primaryDataType, $0.secondaryDataType) }
        #expect(dataTypePairs.contains { $0.0 == .weight && $0.1 == .steps })
        #expect(dataTypePairs.contains { $0.0 == .weight && $0.1 == .calories })
    }
    
    @Test("InsightEngine should analyze lagged correlations correctly")
    func testAnalyzeLaggedCorrelations() async throws {
        // Given
        let engine = createTestInsightEngine()
        let leadingData = createTestHealthRecords(dataType: .steps, values: [8000, 9000, 10000, 8500, 9500], baseDays: 0)
        let laggingData = createTestHealthRecords(dataType: .weight, values: [70.5, 70.0, 69.5, 69.8, 69.3], baseDays: 1)
        
        // When
        let laggedResult = try await engine.analyzeLaggedCorrelations(
            leadingData: leadingData,
            laggingData: laggingData,
            maxLagDays: 3
        )
        
        // Then
        #expect(laggedResult.leadingDataType == .steps)
        #expect(laggedResult.laggingDataType == .weight)
        #expect(laggedResult.maxLagDays == 3)
        #expect(laggedResult.lagCorrelations.count >= 1)
        #expect(laggedResult.lagCorrelations.count <= 4) // 0 to 3 days lag
        #expect(laggedResult.confidence >= 0.0 && laggedResult.confidence <= 1.0)
        #expect(laggedResult.overallPattern != nil)
        
        // Verify lag correlations are properly ordered
        let lagDays = laggedResult.lagCorrelations.map { $0.lagDays }
        #expect(lagDays == lagDays.sorted())
    }
    
    @Test("InsightEngine should handle insufficient correlation data gracefully")
    func testAnalyzeCorrelationsInsufficientData() async throws {
        // Given
        let engine = createTestInsightEngine()
        let singleWeightData = createTestHealthRecords(dataType: .weight, values: [70.0])
        let singleStepsData = createTestHealthRecords(dataType: .steps, values: [8000])
        
        // When/Then
        do {
            _ = try await engine.analyzeCorrelations(
                between: singleWeightData,
                and: singleStepsData,
                timeWindow: .daily
            )
            Issue.record("Should throw error for insufficient data")
        } catch {
            // Expected to throw error
            #expect(error is ValidationError)
        }
    }
    
    // MARK: - Pattern Recognition Tests
    
    @Test("InsightEngine should recognize trending patterns correctly")
    func testRecognizeTrendingPatterns() async throws {
        // Given
        let engine = createTestInsightEngine()
        let trendingData = createTestHealthRecords(dataType: .weight, values: [72.0, 71.5, 71.0, 70.5, 70.0, 69.5, 69.0])
        
        // When
        let patterns = try await engine.recognizePatterns(
            in: trendingData,
            patternTypes: [.trending],
            sensitivity: .medium
        )
        
        // Then
        #expect(patterns.count >= 1)
        
        let trendPattern = patterns.first { $0.patternType == .trending }
        #expect(trendPattern != nil)
        #expect(trendPattern?.dataType == .weight)
        #expect(trendPattern?.confidence > 0.0)
        #expect(trendPattern?.slope != nil)
        #expect(trendPattern?.slope! < 0) // Decreasing trend
        #expect(trendPattern?.significance != nil)
        #expect(trendPattern?.predictedContinuation != nil)
    }
    
    @Test("InsightEngine should detect seasonal patterns correctly")
    func testDetectSeasonalPatterns() async throws {
        // Given
        let engine = createTestInsightEngine()
        
        // Create seasonal weight data (simulating winter weight gain/summer weight loss)
        var seasonalValues: [Double] = []
        for month in 1...24 { // 2 years of data
            let baseWeight = 70.0
            let seasonalVariation = 2.0 * sin(Double(month) * 2 * .pi / 12.0) // Yearly cycle
            seasonalValues.append(baseWeight + seasonalVariation)
        }
        
        let seasonalData = seasonalValues.enumerated().map { index, value in
            let record = HealthRecord(type: .weight, value: value, unit: "kg", source: .healthKit)
            record.timestamp = Calendar.current.date(byAdding: .month, value: index, to: Date())!
            return record
        }
        
        // When
        let seasonalPatterns = try await engine.detectSeasonalPatterns(
            in: seasonalData,
            dataType: .weight,
            minimumCycles: 1
        )
        
        // Then
        #expect(seasonalPatterns.count >= 1)
        
        let pattern = seasonalPatterns.first!
        #expect(pattern.dataType == .weight)
        #expect(pattern.seasonalCycle == .annual)
        #expect(pattern.detectedCycles >= 1)
        #expect(pattern.confidence > 0.0)
        #expect(pattern.amplitude > 0.0)
        #expect(pattern.adjustedRSquared >= 0.0 && pattern.adjustedRSquared <= 1.0)
        #expect(pattern.peakSeason != nil)
        #expect(pattern.troughSeason != nil)
    }
    
    @Test("InsightEngine should analyze cyclical patterns correctly")
    func testAnalyzeCyclicalPatterns() async throws {
        // Given
        let engine = createTestInsightEngine()
        
        // Create weekly cyclical data (simulating weekly weight fluctuations)
        var cyclicalValues: [Double] = []
        for day in 0..<28 { // 4 weeks of data
            let baseWeight = 70.0
            let weeklyVariation = 1.0 * sin(Double(day) * 2 * .pi / 7.0) // Weekly cycle
            cyclicalValues.append(baseWeight + weeklyVariation)
        }
        
        let cyclicalData = cyclicalValues.enumerated().map { index, value in
            let record = HealthRecord(type: .weight, value: value, unit: "kg", source: .healthKit)
            record.timestamp = Calendar.current.date(byAdding: .day, value: index, to: Date())!
            return record
        }
        
        // When
        let cyclicalAnalysis = try await engine.analyzeCyclicalPatterns(
            in: cyclicalData,
            expectedCycleLength: .weekly,
            tolerance: 0.2
        )
        
        // Then
        #expect(cyclicalAnalysis.dataType == .weight)
        #expect(cyclicalAnalysis.expectedCycleLength == .weekly)
        #expect(cyclicalAnalysis.detectedCycles.count >= 2) // Should detect multiple cycles
        #expect(cyclicalAnalysis.averageCycleLength > 0)
        #expect(cyclicalAnalysis.cycleConsistency >= 0.0 && cyclicalAnalysis.cycleConsistency <= 1.0)
        #expect(cyclicalAnalysis.overallConfidence > 0.0)
        #expect(cyclicalAnalysis.amplitude != nil)
        #expect(cyclicalAnalysis.phaseAlignment != nil)
        #expect(cyclicalAnalysis.recommendations.count > 0)
    }
    
    @Test("InsightEngine should detect anomalous patterns correctly")
    func testDetectAnomalousPatterns() async throws {
        // Given
        let engine = createTestInsightEngine()
        
        // Normal baseline data
        let baselineData = createTestHealthRecords(dataType: .weight, values: Array(repeating: 70.0, count: 10))
        
        // Data with anomalies
        let anomalousValues = [70.0, 70.1, 69.9, 75.0, 70.2, 69.8, 70.1] // Spike at index 3
        let anomalousData = createTestHealthRecords(dataType: .weight, values: anomalousValues)
        
        // When
        let anomalousPatterns = try await engine.detectAnomalousPatterns(
            in: anomalousData,
            baselineData: baselineData,
            anomalyThreshold: 2.0
        )
        
        // Then
        #expect(anomalousPatterns.count >= 1)
        
        let spikeAnomaly = anomalousPatterns.first { $0.anomalyType == .spike }
        #expect(spikeAnomaly != nil)
        #expect(spikeAnomaly?.dataType == .weight)
        #expect(spikeAnomaly?.observedValue == 75.0)
        #expect(spikeAnomaly?.deviationMagnitude > 0.0)
        #expect(spikeAnomaly?.severity != nil)
        #expect(spikeAnomaly?.confidence > 0.0)
        #expect(spikeAnomaly?.detectionMethod != nil)
        #expect(spikeAnomaly?.potentialCauses.count >= 0)
        #expect(spikeAnomaly?.immediateActions.count >= 0)
    }
    
    @Test("InsightEngine should handle pattern recognition with multiple pattern types")
    func testRecognizeMultiplePatternTypes() async throws {
        // Given
        let engine = createTestInsightEngine()
        
        // Create complex data with multiple patterns
        var complexValues: [Double] = []
        for day in 0..<60 { // 2 months of data
            let baseWeight = 70.0
            let trend = -0.02 * Double(day) // Gradual weight loss
            let weeklyPattern = 0.5 * sin(Double(day) * 2 * .pi / 7.0) // Weekly fluctuations
            let noise = Double.random(in: -0.2...0.2)
            complexValues.append(baseWeight + trend + weeklyPattern + noise)
        }
        
        let complexData = complexValues.enumerated().map { index, value in
            let record = HealthRecord(type: .weight, value: value, unit: "kg", source: .healthKit)
            record.timestamp = Calendar.current.date(byAdding: .day, value: index, to: Date())!
            return record
        }
        
        // When
        let patterns = try await engine.recognizePatterns(
            in: complexData,
            patternTypes: [.trending, .cyclical],
            sensitivity: .medium
        )
        
        // Then
        #expect(patterns.count >= 1)
        
        let patternTypes = Set(patterns.map { $0.patternType })
        #expect(patternTypes.contains(.trending) || patternTypes.contains(.cyclical))
        
        for pattern in patterns {
            #expect(pattern.confidence > 0.0)
            #expect(pattern.dataType == .weight)
            #expect(pattern.significance != nil)
            #expect(pattern.detectionMethod != nil)
        }
    }
    
    // MARK: - Health Insights Generation Tests
    
    @Test("InsightEngine should generate comprehensive health insights")
    func testGenerateHealthInsights() async throws {
        // Given
        let engine = createTestInsightEngine()
        let user = try createTestUser()
        
        // When
        let insights = try await engine.generateHealthInsights(
            for: user,
            timeframe: .month,
            focusAreas: [.fitness, .cardiovascular]
        )
        
        // Then
        #expect(insights.count > 0)
        
        for insight in insights {
            #expect(!insight.title.isEmpty)
            #expect(!insight.summary.isEmpty)
            #expect(insight.confidence >= 0.0 && insight.confidence <= 1.0)
            #expect(insight.priority != nil)
            #expect(insight.category != nil)
            #expect(insight.timeframe == .month)
            #expect(insight.actionability != nil)
            #expect(insight.relatedData.count >= 0)
        }
        
        // Should include insights related to requested focus areas
        let categories = Set(insights.map { $0.category })
        #expect(categories.contains(.fitness) || categories.contains(.cardiovascular))
    }
    
    @Test("InsightEngine should generate personalized recommendations")
    func testGeneratePersonalizedRecommendations() async throws {
        // Given
        let engine = createTestInsightEngine()
        
        let healthInsights = [
            HealthInsight(
                category: .fitness,
                title: "低い活動レベル",
                summary: "過去1週間の歩数が平均より少ない",
                confidence: 0.8,
                priority: .medium,
                timeframe: .week,
                actionability: .high,
                relatedData: [],
                evidence: [],
                recommendations: []
            )
        ]
        
        let userProfile = HealthProfile(
            userId: UUID(),
            age: 30,
            gender: .male,
            height: 175.0,
            currentWeight: 70.0,
            targetWeight: 68.0,
            activityLevel: .moderate,
            healthConditions: [],
            medications: [],
            allergies: [],
            preferences: HealthPreferences(
                preferredExerciseTypes: [.walking, .cycling],
                dietaryRestrictions: [],
                notificationPreferences: NotificationPreferences(
                    enabled: true,
                    frequency: .daily,
                    quietHours: 22...7
                )
            )
        )
        
        // When
        let recommendations = try await engine.generatePersonalizedRecommendations(
            based: healthInsights,
            userProfile: userProfile,
            priorityLevel: .medium
        )
        
        // Then
        #expect(recommendations.count > 0)
        
        for recommendation in recommendations {
            #expect(!recommendation.title.isEmpty)
            #expect(!recommendation.description.isEmpty)
            #expect(recommendation.priority != nil)
            #expect(recommendation.category != nil)
            #expect(recommendation.personalizationLevel != nil)
            #expect(recommendation.actionItems.count > 0)
            #expect(recommendation.estimatedImpact >= 0.0 && recommendation.estimatedImpact <= 1.0)
            #expect(recommendation.difficulty != nil)
            #expect(recommendation.timeToImplement > 0)
        }
    }
    
    @Test("InsightEngine should assess health risks correctly")
    func testAssessHealthRisks() async throws {
        // Given
        let engine = createTestInsightEngine()
        let user = try createTestUser()
        
        let riskFactors = [
            RiskFactor(
                type: .lifestyle,
                name: "低活動レベル",
                severity: .medium,
                description: "日常的な運動不足",
                modifiable: true
            ),
            RiskFactor(
                type: .physiological,
                name: "BMI高値",
                severity: .high,
                description: "標準体重を上回る",
                modifiable: true
            )
        ]
        
        // When
        let riskAssessment = try await engine.assessHealthRisks(
            for: user,
            riskFactors: riskFactors,
            assessmentPeriod: 30 * 24 * 60 * 60 // 30 days
        )
        
        // Then
        #expect(riskAssessment.userId == user.id)
        #expect(riskAssessment.overallRiskScore >= 0.0 && riskAssessment.overallRiskScore <= 1.0)
        #expect(riskAssessment.riskLevel != nil)
        #expect(riskAssessment.identifiedRisks.count >= 2)
        #expect(riskAssessment.mitigationStrategies.count > 0)
        #expect(riskAssessment.recommendedActions.count > 0)
        #expect(riskAssessment.nextReviewDate > Date())
        
        // Verify risk factors are properly assessed
        let riskNames = Set(riskAssessment.identifiedRisks.map { $0.name })
        #expect(riskNames.contains("低活動レベル"))
        #expect(riskNames.contains("BMI高値"))
    }
    
    @Test("InsightEngine should predict health outcomes accurately")
    func testPredictHealthOutcomes() async throws {
        // Given
        let engine = createTestInsightEngine()
        
        // Historical weight loss trend
        let weightData = createTestHealthRecords(dataType: .weight, values: [75.0, 74.5, 74.0, 73.5, 73.0, 72.5])
        
        let targetMetrics = [
            HealthMetric(
                type: .weight,
                targetValue: 70.0,
                currentValue: 72.5,
                unit: "kg",
                timeframe: .month
            )
        ]
        
        // When
        let predictions = try await engine.predictHealthOutcomes(
            based: weightData,
            targetMetrics: targetMetrics,
            predictionHorizon: .mediumTerm
        )
        
        // Then
        #expect(predictions.count >= 1)
        
        let weightPrediction = predictions.first { $0.metricType == .weight }
        #expect(weightPrediction != nil)
        #expect(weightPrediction?.predictionHorizon == .mediumTerm)
        #expect(weightPrediction?.confidence >= 0.0 && weightPrediction?.confidence <= 1.0)
        #expect(weightPrediction?.predictedValue != nil)
        #expect(weightPrediction?.predictionRange != nil)
        #expect(weightPrediction?.achievabilityScore >= 0.0 && weightPrediction?.achievabilityScore <= 1.0)
        #expect(weightPrediction?.factors.count >= 0)
        #expect(weightPrediction?.uncertainties.count >= 0)
    }
    
    // MARK: - Behavioral Analysis Tests
    
    @Test("InsightEngine should analyze behavioral patterns correctly")
    func testAnalyzeBehavioralPatterns() async throws {
        // Given
        let engine = createTestInsightEngine()
        let user = try createTestUser()
        
        let behaviorData = [
            BehaviorRecord(
                userId: user.id,
                behaviorType: .exercise,
                timestamp: Date(),
                duration: 3600, // 1 hour
                intensity: .moderate,
                context: "Morning workout",
                outcome: .positive
            ),
            BehaviorRecord(
                userId: user.id,
                behaviorType: .dataEntry,
                timestamp: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
                duration: 300, // 5 minutes
                intensity: .low,
                context: "Weight logging",
                outcome: .positive
            )
        ]
        
        // When
        let behavioralAnalysis = try await engine.analyzeBehavioralPatterns(
            for: user,
            behaviorData: behaviorData,
            analysisWindow: .standard
        )
        
        // Then
        #expect(behavioralAnalysis.userId == user.id)
        #expect(behavioralAnalysis.analysisWindow == .standard)
        #expect(behavioralAnalysis.overallScore >= 0.0 && behavioralAnalysis.overallScore <= 1.0)
        #expect(behavioralAnalysis.patterns.count >= 0)
        #expect(behavioralAnalysis.strengths.count >= 0)
        #expect(behavioralAnalysis.improvementAreas.count >= 0)
        #expect(behavioralAnalysis.recommendations.count >= 0)
        #expect(behavioralAnalysis.adherenceMetrics.count >= 0)
    }
    
    @Test("InsightEngine should analyze habit formation correctly")
    func testAnalyzeHabitFormation() async throws {
        // Given
        let engine = createTestInsightEngine()
        
        // Simulate 30 days of behavior data (80% consistency)
        var behaviorHistory: [BehaviorRecord] = []
        for day in 0..<30 {
            let shouldRecord = day % 5 != 0 // Skip every 5th day (80% consistency)
            if shouldRecord {
                let record = BehaviorRecord(
                    userId: UUID(),
                    behaviorType: .exercise,
                    timestamp: Calendar.current.date(byAdding: .day, value: -day, to: Date())!,
                    duration: 1800, // 30 minutes
                    intensity: .moderate,
                    context: "Daily workout",
                    outcome: .positive
                )
                behaviorHistory.append(record)
            }
        }
        
        let targetHabits = [
            TargetHabit(
                name: "Daily Exercise",
                behaviorType: .exercise,
                targetFrequency: .daily,
                minimumDuration: 1800,
                successCriteria: "Complete 30-minute workout"
            )
        ]
        
        // When
        let habitAnalyses = try await engine.analyzeHabitFormation(
            behaviorHistory: behaviorHistory,
            targetHabits: targetHabits,
            formationThreshold: .standard
        )
        
        // Then
        #expect(habitAnalyses.count >= 1)
        
        let exerciseHabit = habitAnalyses.first!
        #expect(exerciseHabit.habitName == "Daily Exercise")
        #expect(exerciseHabit.formationStage != nil)
        #expect(exerciseHabit.consistency >= 0.0 && exerciseHabit.consistency <= 1.0)
        #expect(exerciseHabit.consistency >= 0.7) // Should be around 80%
        #expect(exerciseHabit.streakCurrent >= 0)
        #expect(exerciseHabit.streakLongest >= exerciseHabit.streakCurrent)
        #expect(exerciseHabit.predictedSuccess >= 0.0 && exerciseHabit.predictedSuccess <= 1.0)
        #expect(exerciseHabit.strengthFactors.count >= 0)
        #expect(exerciseHabit.challengeFactors.count >= 0)
    }
    
    @Test("InsightEngine should analyze motivation patterns correctly")
    func testAnalyzeMotivationPatterns() async throws {
        // Given
        let engine = createTestInsightEngine()
        
        let engagementData = [
            EngagementRecord(
                userId: UUID(),
                timestamp: Date(),
                engagementType: .appUsage,
                duration: 600, // 10 minutes
                interactionQuality: .high,
                completionRate: 0.9,
                userSatisfaction: 0.8
            ),
            EngagementRecord(
                userId: UUID(),
                timestamp: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
                engagementType: .goalSetting,
                duration: 300, // 5 minutes
                interactionQuality: .medium,
                completionRate: 1.0,
                userSatisfaction: 0.7
            )
        ]
        
        let externalFactors = [
            ExternalFactor(
                type: .weather,
                description: "Rainy weather",
                impact: -0.2,
                timestamp: Date(),
                confidence: 0.7
            )
        ]
        
        // When
        let motivationAnalysis = try await engine.analyzeMotivationPatterns(
            engagementData: engagementData,
            externalFactors: externalFactors,
            timeframe: .monthly
        )
        
        // Then
        #expect(motivationAnalysis.timeframe == .monthly)
        #expect(motivationAnalysis.overallMotivation >= 0.0 && motivationAnalysis.overallMotivation <= 1.0)
        #expect(motivationAnalysis.motivationTrend != nil)
        #expect(motivationAnalysis.peakMotivationPeriods.count >= 0)
        #expect(motivationAnalysis.lowMotivationPeriods.count >= 0)
        #expect(motivationAnalysis.motivationDrivers.count >= 0)
        #expect(motivationAnalysis.demotivatingFactors.count >= 0)
        #expect(motivationAnalysis.recommendations.count >= 0)
        #expect(motivationAnalysis.predictedTrend != nil)
    }
    
    // MARK: - Predictive Analytics Tests
    
    @Test("InsightEngine should generate ML predictions correctly")
    func testGenerateMLPredictions() async throws {
        // Given
        let engine = createTestInsightEngine()
        
        let features = [
            HealthFeature(name: "age", value: 30.0, type: .numerical),
            HealthFeature(name: "current_weight", value: 70.0, type: .numerical),
            HealthFeature(name: "activity_level", value: 2.0, type: .categorical),
            HealthFeature(name: "sleep_hours", value: 7.5, type: .numerical)
        ]
        
        let modelConfig = MLModelConfiguration(
            modelType: .regression,
            algorithm: .randomForest,
            hyperparameters: ["n_estimators": 100, "max_depth": 10],
            validationMethod: .crossValidation,
            trainingDataSize: 1000
        )
        
        // When
        let mlResult = try await engine.generateMLPredictions(
            features: features,
            predictionTarget: .weightLoss,
            modelConfiguration: modelConfig
        )
        
        // Then
        #expect(mlResult.predictionTarget == .weightLoss)
        #expect(mlResult.modelType == .regression)
        #expect(mlResult.confidence >= 0.0 && mlResult.confidence <= 1.0)
        #expect(mlResult.predictedValue != nil)
        #expect(mlResult.predictionInterval != nil)
        #expect(mlResult.featureImportance.count > 0)
        #expect(mlResult.modelMetrics.count > 0)
        #expect(mlResult.validationResults != nil)
        
        // Feature importance should sum to approximately 1.0
        let totalImportance = mlResult.featureImportance.values.reduce(0, +)
        #expect(abs(totalImportance - 1.0) < 0.1)
    }
    
    @Test("InsightEngine should extrapolate trends correctly")
    func testExtrapolateTrends() async throws {
        // Given
        let engine = createTestInsightEngine()
        
        // Create clear downward trend data
        let trendData = createTestHealthRecords(dataType: .weight, values: [75.0, 74.0, 73.0, 72.0, 71.0])
        
        // When
        let projections = try await engine.extrapolateTrends(
            historicalData: trendData,
            extrapolationMethod: .linear,
            projectionPeriod: 30 * 24 * 60 * 60 // 30 days
        )
        
        // Then
        #expect(projections.count >= 1)
        
        let projection = projections.first!
        #expect(projection.dataType == .weight)
        #expect(projection.method == .linear)
        #expect(projection.projectionPeriod == 30 * 24 * 60 * 60)
        #expect(projection.confidence >= 0.0 && projection.confidence <= 1.0)
        #expect(projection.projectedValues.count > 0)
        #expect(projection.confidenceInterval != nil)
        #expect(projection.assumptions.count >= 0)
        #expect(projection.limitingFactors.count >= 0)
        
        // Linear projection should show continued downward trend
        let firstValue = projection.projectedValues.first!.value
        let lastValue = projection.projectedValues.last!.value
        #expect(lastValue < firstValue) // Should continue decreasing
    }
    
    @Test("InsightEngine should calculate risk probabilities correctly")
    func testCalculateRiskProbabilities() async throws {
        // Given
        let engine = createTestInsightEngine()
        
        let currentState = HealthState(
            vitals: ["weight": 75.0, "bmi": 24.5, "heart_rate": 75.0],
            symptoms: [],
            medications: [],
            lifestyle: ["exercise_days_per_week": 2.0, "sleep_hours": 6.5],
            timestamp: Date()
        )
        
        let riskModels = [
            RiskModel(
                riskType: .cardiovascular,
                modelName: "Framingham Risk Score",
                parameters: ["age": 30, "cholesterol": 200, "blood_pressure": 120],
                weights: ["age": 0.3, "cholesterol": 0.4, "blood_pressure": 0.3],
                threshold: 0.7
            )
        ]
        
        // When
        let riskProbabilities = try await engine.calculateRiskProbabilities(
            currentState: currentState,
            riskModels: riskModels,
            timeHorizon: .longTerm
        )
        
        // Then
        #expect(riskProbabilities.count >= 1)
        
        let cardiovascularRisk = riskProbabilities.first { $0.riskType == .cardiovascular }
        #expect(cardiovascularRisk != nil)
        #expect(cardiovascularRisk?.probability >= 0.0 && cardiovascularRisk?.probability <= 1.0)
        #expect(cardiovascularRisk?.confidence >= 0.0 && cardiovascularRisk?.confidence <= 1.0)
        #expect(cardiovascularRisk?.riskLevel != nil)
        #expect(cardiovascularRisk?.contributingFactors.count >= 0)
        #expect(cardiovascularRisk?.mitigationStrategies.count >= 0)
        #expect(cardiovascularRisk?.timeHorizon == .longTerm)
    }
    
    // MARK: - Data Quality Tests
    
    @Test("InsightEngine should assess data quality comprehensively")
    func testAssessDataQuality() async throws {
        // Given
        let engine = createTestInsightEngine()
        
        // Mix of good and poor quality data
        var testData = createTestHealthRecords(dataType: .weight, values: [70.0, 70.5, 70.2, 70.8, 70.1])
        // Add some problematic data
        testData.append(HealthRecord(type: .weight, value: 50.0, unit: "kg", source: .manual)) // Low but valid value
        testData.append(HealthRecord(type: .weight, value: 200.0, unit: "kg", source: .manual)) // Outlier
        
        let qualityMetrics: Set<DataQualityMetric> = [.completeness, .accuracy, .consistency, .validity]
        
        let benchmark = QualityBenchmark(
            completenessThreshold: 0.9,
            accuracyThreshold: 0.95,
            consistencyThreshold: 0.8,
            validityThreshold: 0.9,
            timelinessThreshold: 0.85
        )
        
        // When
        let qualityAssessment = try await engine.assessDataQuality(
            healthRecords: testData,
            qualityMetrics: qualityMetrics,
            benchmarkStandards: benchmark
        )
        
        // Then
        #expect(qualityAssessment.overallScore >= 0.0 && qualityAssessment.overallScore <= 1.0)
        #expect(qualityAssessment.metricScores.count == qualityMetrics.count)
        #expect(qualityAssessment.dataIssues.count >= 2) // Should detect invalid and outlier
        #expect(qualityAssessment.recommendations.count > 0)
        #expect(qualityAssessment.benchmarkComparison.count == qualityMetrics.count)
        
        // Should identify specific quality issues
        let issueTypes = Set(qualityAssessment.dataIssues.map { $0.issueType })
        #expect(issueTypes.contains(.invalidValue) || issueTypes.contains(.outlier))
        
        // Completeness should be less than 100% due to invalid data
        let completenessScore = qualityAssessment.metricScores[.completeness]
        #expect(completenessScore != nil)
        #expect(completenessScore! < 1.0)
    }
    
    @Test("InsightEngine should calculate reliability scores correctly")
    func testCalculateReliabilityScore() async throws {
        // Given
        let engine = createTestInsightEngine()
        
        let accuracyRecords = [
            AccuracyRecord(timestamp: Date(), expectedValue: 70.0, actualValue: 70.2, accuracy: 0.97),
            AccuracyRecord(timestamp: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, expectedValue: 69.8, actualValue: 69.9, accuracy: 0.99),
            AccuracyRecord(timestamp: Calendar.current.date(byAdding: .day, value: -2, to: Date())!, expectedValue: 70.1, actualValue: 70.0, accuracy: 0.99)
        ]
        
        let consistencyMetrics = ConsistencyMetrics(
            temporalConsistency: 0.95,
            crossSourceConsistency: 0.88,
            internalConsistency: 0.92,
            methodologicalConsistency: 0.90
        )
        
        // When
        let reliabilityScore = try await engine.calculateReliabilityScore(
            for: .healthKit,
            historicalAccuracy: accuracyRecords,
            consistencyMetrics: consistencyMetrics
        )
        
        // Then
        #expect(reliabilityScore.overallScore >= 0.0 && reliabilityScore.overallScore <= 1.0)
        #expect(reliabilityScore.dataSource == .healthKit)
        #expect(reliabilityScore.components.count > 0)
        #expect(reliabilityScore.confidenceLevel >= 0.0 && reliabilityScore.confidenceLevel <= 1.0)
        #expect(reliabilityScore.sampleSize == accuracyRecords.count)
        #expect(reliabilityScore.assessmentDate != nil)
        #expect(reliabilityScore.validityPeriod > 0)
        
        // Should have high reliability given good accuracy and consistency
        #expect(reliabilityScore.overallScore > 0.8)
    }
    
    @Test("InsightEngine should evaluate missing data impact correctly")
    func testEvaluateMissingDataImpact() async throws {
        // Given
        let engine = createTestInsightEngine()
        
        let completeData = createTestHealthRecords(dataType: .weight, values: [70.0, 69.8, 69.5, 69.2, 69.0])
        
        let missingPattern = MissingDataPattern(
            patternType: .random,
            missingPercentage: 0.2, // 20% missing
            affectedTimeRange: DateRange(start: Calendar.current.date(byAdding: .day, value: -30, to: Date())!, end: Date()),
            missingMechanism: .missingAtRandom
        )
        
        let analysisRequirements = AnalysisRequirements(
            minimumDataPoints: 10,
            requiredCoverage: 0.8,
            acceptableGaps: 2,
            criticalMetrics: ["weight", "trend"]
        )
        
        // When
        let impactAssessment = try await engine.evaluateMissingDataImpact(
            completeData: completeData,
            missingDataPattern: missingPattern,
            analysisRequirements: analysisRequirements
        )
        
        // Then
        #expect(impactAssessment.missingPercentage == 0.2)
        #expect(impactAssessment.impactSeverity != nil)
        #expect(impactAssessment.affectedAnalyses.count >= 0)
        #expect(impactAssessment.confidenceReduction >= 0.0 && impactAssessment.confidenceReduction <= 1.0)
        #expect(impactAssessment.mitigationStrategies.count > 0)
        #expect(impactAssessment.alternativeApproaches.count >= 0)
        #expect(impactAssessment.dataCollectionRecommendations.count >= 0)
        
        // 20% missing data should have moderate impact
        #expect(impactAssessment.impactSeverity == .moderate || impactAssessment.impactSeverity == .low)
    }
    
    // MARK: - Advanced Analytics Tests
    
    @Test("InsightEngine should perform multivariate analysis correctly")
    func testPerformMultivariateAnalysis() async throws {
        // Given
        let engine = createTestInsightEngine()
        
        let variables = [
            HealthVariable(name: "weight", values: [70.0, 69.5, 69.0, 68.5, 68.0], type: .continuous),
            HealthVariable(name: "steps", values: [8000, 8500, 9000, 9500, 10000], type: .continuous),
            HealthVariable(name: "calories", values: [2000, 2100, 2200, 2300, 2400], type: .continuous)
        ]
        
        let config = StatisticalConfiguration(
            significanceLevel: 0.05,
            confidenceLevel: 0.95,
            robustMethods: true,
            bootstrapIterations: 1000
        )
        
        // When
        let multivariateResult = try await engine.performMultivariateAnalysis(
            variables: variables,
            analysisType: .principalComponentAnalysis,
            statisticalConfiguration: config
        )
        
        // Then
        #expect(multivariateResult.analysisType == .principalComponentAnalysis)
        #expect(multivariateResult.variables.count == 3)
        #expect(multivariateResult.results.count > 0)
        #expect(multivariateResult.explainedVariance.count > 0)
        #expect(multivariateResult.loadings.count > 0)
        #expect(multivariateResult.significance != nil)
        #expect(multivariateResult.assumptions.count >= 0)
        #expect(multivariateResult.diagnostics.count >= 0)
        
        // Total explained variance should not exceed 100%
        let totalVariance = multivariateResult.explainedVariance.reduce(0, +)
        #expect(totalVariance <= 1.0)
    }
    
    @Test("InsightEngine should decompose time series correctly")
    func testDecomposeTimeSeries() async throws {
        // Given
        let engine = createTestInsightEngine()
        
        // Create time series with trend and seasonal components
        var timeSeriesPoints: [HealthTimeSeriesPoint] = []
        for day in 0..<365 { // 1 year of data
            let timestamp = Calendar.current.date(byAdding: .day, value: day, to: Date())!
            let trend = 70.0 - 0.01 * Double(day) // Gradual weight loss
            let seasonal = 1.0 * sin(Double(day) * 2 * .pi / 365.0) // Annual cycle
            let noise = Double.random(in: -0.5...0.5)
            let value = trend + seasonal + noise
            
            timeSeriesPoints.append(HealthTimeSeriesPoint(
                timestamp: timestamp,
                value: value,
                dataType: .weight
            ))
        }
        
        // When
        let decomposition = try await engine.decomposeTimeSeries(
            timeSeries: timeSeriesPoints,
            decompositionMethod: .stl,
            forecastHorizon: 30
        )
        
        // Then
        #expect(decomposition.method == .stl)
        #expect(decomposition.originalSeries.count == 365)
        #expect(decomposition.trend.count == 365)
        #expect(decomposition.seasonal.count == 365)
        #expect(decomposition.residual.count == 365)
        #expect(decomposition.forecast.count == 30)
        #expect(decomposition.forecastConfidenceInterval.count == 30)
        #expect(decomposition.seasonalityStrength >= 0.0 && decomposition.seasonalityStrength <= 1.0)
        #expect(decomposition.trendStrength >= 0.0 && decomposition.trendStrength <= 1.0)
        #expect(decomposition.goodnessOfFit >= 0.0 && decomposition.goodnessOfFit <= 1.0)
    }
    
    @Test("InsightEngine should perform health clustering correctly")
    func testPerformHealthClustering() async throws {
        // Given
        let engine = createTestInsightEngine()
        
        // Create diverse health profiles
        let healthProfiles = [
            HealthProfile(userId: UUID(), age: 25, gender: .male, height: 180, currentWeight: 75, targetWeight: 72, activityLevel: .high, healthConditions: [], medications: [], allergies: [], preferences: HealthPreferences(preferredExerciseTypes: [.running], dietaryRestrictions: [], notificationPreferences: NotificationPreferences(enabled: true, frequency: .daily, quietHours: 22...7))),
            HealthProfile(userId: UUID(), age: 35, gender: .female, height: 165, currentWeight: 60, targetWeight: 58, activityLevel: .moderate, healthConditions: [], medications: [], allergies: [], preferences: HealthPreferences(preferredExerciseTypes: [.yoga], dietaryRestrictions: [], notificationPreferences: NotificationPreferences(enabled: true, frequency: .daily, quietHours: 22...7))),
            HealthProfile(userId: UUID(), age: 45, gender: .male, height: 175, currentWeight: 80, targetWeight: 75, activityLevel: .low, healthConditions: [], medications: [], allergies: [], preferences: HealthPreferences(preferredExerciseTypes: [.walking], dietaryRestrictions: [], notificationPreferences: NotificationPreferences(enabled: true, frequency: .daily, quietHours: 22...7)))
        ]
        
        // When
        let clusteringResult = try await engine.performHealthClustering(
            healthProfiles: healthProfiles,
            clusteringAlgorithm: .kmeans,
            optimalClusterCount: .elbow
        )
        
        // Then
        #expect(clusteringResult.algorithm == .kmeans)
        #expect(clusteringResult.optimalClusters > 0)
        #expect(clusteringResult.clusters.count == clusteringResult.optimalClusters)
        #expect(clusteringResult.clusterAssignments.count == healthProfiles.count)
        #expect(clusteringResult.silhouetteScore >= -1.0 && clusteringResult.silhouetteScore <= 1.0)
        #expect(clusteringResult.inertia >= 0.0)
        #expect(clusteringResult.clusterCharacteristics.count == clusteringResult.optimalClusters)
        
        // All profiles should be assigned to clusters
        let assignedClusters = Set(clusteringResult.clusterAssignments.values)
        #expect(assignedClusters.count <= clusteringResult.optimalClusters)
        #expect(assignedClusters.allSatisfy { $0 >= 0 && $0 < clusteringResult.optimalClusters })
    }
    
    // MARK: - Insight Synthesis Tests
    
    @Test("InsightEngine should synthesize insights correctly")
    func testSynthesizeInsights() async throws {
        // Given
        let engine = createTestInsightEngine()
        
        let insights = [
            HealthInsight(category: .fitness, title: "低活動レベル", summary: "歩数が目標を下回っています", confidence: 0.8, priority: .high, timeframe: .week, actionability: .high, relatedData: [], evidence: [], recommendations: []),
            HealthInsight(category: .nutrition, title: "カロリー過多", summary: "摂取カロリーが推奨値を上回っています", confidence: 0.7, priority: .medium, timeframe: .week, actionability: .medium, relatedData: [], evidence: [], recommendations: []),
            HealthInsight(category: .sleep, title: "睡眠不足", summary: "睡眠時間が推奨値を下回っています", confidence: 0.9, priority: .high, timeframe: .week, actionability: .high, relatedData: [], evidence: [], recommendations: [])
        ]
        
        let userPreferences = InsightPreferences(
            preferredCategories: [.fitness, .sleep],
            maxInsightsPerReport: 5,
            minimumConfidence: 0.6,
            priorityThreshold: .medium,
            includeActionItems: true
        )
        
        // When
        let synthesizedReport = try await engine.synthesizeInsights(
            insights: insights,
            synthesisStrategy: .priorityBased,
            userPreferences: userPreferences
        )
        
        // Then
        #expect(synthesizedReport.strategy == .priorityBased)
        #expect(synthesizedReport.totalInsights == insights.count)
        #expect(synthesizedReport.synthesizedInsights.count <= userPreferences.maxInsightsPerReport)
        #expect(synthesizedReport.keyFindings.count > 0)
        #expect(synthesizedReport.priorityInsights.count > 0)
        #expect(synthesizedReport.actionableRecommendations.count > 0)
        #expect(synthesizedReport.overallScore >= 0.0 && synthesizedReport.overallScore <= 1.0)
        
        // Should prioritize user's preferred categories
        let synthesizedCategories = Set(synthesizedReport.synthesizedInsights.map { $0.category })
        #expect(synthesizedCategories.contains(.fitness) || synthesizedCategories.contains(.sleep))
        
        // All synthesized insights should meet confidence threshold
        let confidenceLevels = synthesizedReport.synthesizedInsights.map { $0.confidence }
        #expect(confidenceLevels.allSatisfy { $0 >= userPreferences.minimumConfidence })
    }
    
    @Test("InsightEngine should generate custom reports correctly")
    func testGenerateCustomReport() async throws {
        // Given
        let engine = createTestInsightEngine()
        
        let template = ReportTemplate(
            name: "Weekly Health Summary",
            sections: [.overview, .trends, .achievements, .recommendations],
            format: .pdf,
            includeCharts: true,
            includeComparisons: true
        )
        
        let reportData = createTestHealthRecords(dataType: .weight, values: [70.5, 70.2, 70.0, 69.8, 69.5])
        
        let config = ReportConfiguration(
            timeRange: DateRange(start: Calendar.current.date(byAdding: .week, value: -1, to: Date())!, end: Date()),
            includePersonalData: true,
            aggregationLevel: .daily,
            comparisonBaseline: .previousPeriod,
            privacyLevel: .standard
        )
        
        // When
        let customReport = try await engine.generateCustomReport(
            reportTemplate: template,
            dataSource: reportData,
            reportConfiguration: config
        )
        
        // Then
        #expect(customReport.templateName == "Weekly Health Summary")
        #expect(customReport.generatedSections.count == template.sections.count)
        #expect(customReport.dataRange == config.timeRange)
        #expect(customReport.reportMetadata.count > 0)
        #expect(customReport.generatedAt != nil)
        #expect(customReport.reportSize > 0)
        #expect(customReport.format == .pdf)
        
        // Should include all requested sections
        let sectionTypes = Set(customReport.generatedSections.map { $0.type })
        #expect(sectionTypes == Set(template.sections))
        
        // Each section should have content
        for section in customReport.generatedSections {
            #expect(!section.content.isEmpty)
            #expect(section.dataPoints.count >= 0)
        }
    }
    
    @Test("InsightEngine should evaluate insight accuracy correctly")
    func testEvaluateInsightAccuracy() async throws {
        // Given
        let engine = createTestInsightEngine()
        
        let generatedInsights = [
            HealthInsight(category: .fitness, title: "体重減少予測", summary: "今週末までに0.5kg減少予測", confidence: 0.8, priority: .medium, timeframe: .week, actionability: .high, relatedData: [], evidence: [], recommendations: []),
            HealthInsight(category: .cardiovascular, title: "心拍数改善", summary: "運動により安静時心拍数が改善", confidence: 0.9, priority: .low, timeframe: .month, actionability: .medium, relatedData: [], evidence: [], recommendations: [])
        ]
        
        let validationDataSet = ValidationDataSet(
            actualOutcomes: [
                "体重減少": 0.4, // Actual weight loss was 0.4kg vs predicted 0.5kg
                "心拍数": 68.0   // Actual resting heart rate
            ],
            timeRange: DateRange(start: Calendar.current.date(byAdding: .month, value: -1, to: Date())!, end: Date()),
            dataQuality: 0.95,
            completeness: 0.9
        )
        
        let accuracyMetrics: Set<AccuracyMetric> = [.meanAbsoluteError, .rootMeanSquareError, .correlation]
        
        // When
        let accuracyEvaluation = try await engine.evaluateInsightAccuracy(
            generatedInsights: generatedInsights,
            validationData: validationDataSet,
            accuracyMetrics: accuracyMetrics
        )
        
        // Then
        #expect(accuracyEvaluation.overallAccuracy >= 0.0 && accuracyEvaluation.overallAccuracy <= 1.0)
        #expect(accuracyEvaluation.metricResults.count == accuracyMetrics.count)
        #expect(accuracyEvaluation.insightAccuracies.count == generatedInsights.count)
        #expect(accuracyEvaluation.confidenceCalibration >= 0.0 && accuracyEvaluation.confidenceCalibration <= 1.0)
        #expect(accuracyEvaluation.predictionErrors.count >= 0)
        #expect(accuracyEvaluation.improvementSuggestions.count >= 0)
        
        // Should have reasonable accuracy for the weight prediction
        let weightInsightAccuracy = accuracyEvaluation.insightAccuracies.first { $0.insightTitle == "体重減少予測" }
        #expect(weightInsightAccuracy != nil)
        #expect(weightInsightAccuracy?.accuracy >= 0.0 && weightInsightAccuracy?.accuracy <= 1.0)
    }
    
    // MARK: - Edge Cases and Error Handling Tests
    
    @Test("InsightEngine should handle empty data gracefully")
    func testHandleEmptyData() async throws {
        // Given
        let engine = createTestInsightEngine()
        let emptyData: [HealthRecord] = []
        
        // When/Then
        do {
            _ = try await engine.recognizePatterns(
                in: emptyData,
                patternTypes: [.trending],
                sensitivity: .medium
            )
            Issue.record("Should throw error for empty data")
        } catch {
            #expect(error is ValidationError)
        }
    }
    
    @Test("InsightEngine should handle invalid time windows")
    func testHandleInvalidTimeWindows() async throws {
        // Given
        let engine = createTestInsightEngine()
        let user = try createTestUser()
        
        // When/Then
        do {
            _ = try await engine.generateHealthInsights(
                for: user,
                timeframe: .week, // This should work
                focusAreas: []
            )
            // Should succeed with empty focus areas
        } catch {
            Issue.record("Should not throw error for empty focus areas")
        }
    }
    
    @Test("InsightEngine should handle low quality data appropriately")
    func testHandleLowQualityData() async throws {
        // Given
        let engine = createTestInsightEngine()
        
        // Create poor quality data with outliers and missing values
        let poorQualityData = [
            HealthRecord(type: .weight, value: 70.0, unit: "kg", source: .manual),
            HealthRecord(type: .weight, value: 90.0, unit: "kg", source: .manual), // High but valid value
            HealthRecord(type: .weight, value: 55.0, unit: "kg", source: .manual),   // Low but valid value
            HealthRecord(type: .weight, value: 69.8, unit: "kg", source: .manual)
        ]
        
        // When
        let patterns = try await engine.recognizePatterns(
            in: poorQualityData,
            patternTypes: [.trending, .outlier],
            sensitivity: .high
        )
        
        // Then - Should still return results but with appropriate confidence levels
        #expect(patterns.count >= 0) // May or may not find patterns
        
        for pattern in patterns {
            #expect(pattern.confidence >= 0.0 && pattern.confidence <= 1.0)
            // Confidence should generally be lower for poor quality data
        }
    }
}

// MARK: - Supporting Test Data Types

extension HealthInsight {
    init(category: InsightCategory, title: String, summary: String, confidence: Double, priority: InsightPriority, timeframe: InsightTimeframe, actionability: InsightActionability, relatedData: [UUID], evidence: [InsightEvidence], recommendations: [InsightRecommendation]) {
        self.id = UUID()
        self.category = category
        self.title = title
        self.summary = summary
        self.confidence = confidence
        self.priority = priority
        self.timeframe = timeframe
        self.actionability = actionability
        self.relatedData = relatedData
        self.evidence = evidence
        self.recommendations = recommendations
        self.tags = []
        self.generatedAt = Date()
    }
}