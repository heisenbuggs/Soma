import XCTest
@testable import Soma

final class BehaviorEngineTests: XCTestCase {

    // MARK: - Helpers

    private func makeMetrics(date: Date, recovery: Double, sleep: Double, hrv: Double? = nil) -> DailyMetrics {
        DailyMetrics(
            date: date,
            recoveryScore: recovery,
            strainScore: 10,
            sleepScore: sleep,
            stressScore: 30,
            hrvAverage: hrv,
            restingHR: nil,
            sleepDurationHours: nil,
            sleepNeedHours: nil,
            activeCalories: nil,
            stepCount: nil,
            vo2Max: nil,
            respiratoryRate: nil,
            sleepingHR: nil,
            sleepingHRV: hrv,
            sleepInterruptions: nil
        )
    }

    private func makeCheckIn(date: Date, alcohol: Bool = false, caffeine: Bool = false,
                              meditation: Bool = false, lateMeal: Bool = false) -> DailyCheckIn {
        var ci = DailyCheckIn(date: date)
        ci.alcoholConsumed = alcohol
        ci.caffeineAfter5PM = caffeine
        ci.meditated = meditation
        ci.lateMealBeforeBed = lateMeal
        return ci
    }

    // MARK: - generateInsights

    func test_generateInsights_insufficientData_returnsEmpty() {
        let checkIns = (0..<4).map { i -> DailyCheckIn in
            makeCheckIn(date: Date(timeIntervalSinceNow: Double(-i * 86400)), alcohol: true)
        }
        let metrics: [DailyMetrics] = []
        let insights = BehaviorEngine.generateInsights(checkIns: checkIns, metrics: metrics)
        XCTAssertTrue(insights.isEmpty, "Need at least \(BehaviorEngine.minObservations) check-ins")
    }

    func test_generateInsights_noMatchingNextDayMetrics_returnsEmpty() {
        // 10 check-ins with alcohol, 10 without, but no matching next-day metrics
        let cal = Calendar.current
        var checkIns: [DailyCheckIn] = []
        for i in 0..<10 {
            let date = cal.date(byAdding: .day, value: -i * 2, to: Date())!
            checkIns.append(makeCheckIn(date: date, alcohol: i % 2 == 0))
        }
        let insights = BehaviorEngine.generateInsights(checkIns: checkIns, metrics: [])
        XCTAssertTrue(insights.isEmpty)
    }

    func test_generateInsights_alcoholReducesRecovery() {
        // Build 10 pairs: on alcohol nights, next-day recovery is 50 lower
        let cal = Calendar.current
        var checkIns: [DailyCheckIn] = []
        var metrics: [DailyMetrics] = []

        for i in 0..<10 {
            let checkDate = cal.date(byAdding: .day, value: -(i * 2 + 1), to: Date())!
            let nextDate  = cal.date(byAdding: .day, value: 1, to: checkDate)!
            let isAlcohol = i < 6  // 6 with alcohol, 4 without
            checkIns.append(makeCheckIn(date: checkDate, alcohol: isAlcohol))
            let recovery = isAlcohol ? 40.0 : 80.0
            metrics.append(makeMetrics(date: nextDate, recovery: recovery, sleep: 70))
        }

        let insights = BehaviorEngine.generateInsights(checkIns: checkIns, metrics: metrics)

        // Should have at least one insight about alcohol and recovery
        let alcoholRecovery = insights.first {
            $0.behaviorName == "Alcohol" && $0.metricName == "Recovery Score"
        }
        XCTAssertNotNil(alcoholRecovery, "Expected an alcohol–recovery correlation")
        XCTAssertTrue(alcoholRecovery?.isNegativeImpact == true,
                      "Alcohol should be flagged as negative for recovery")
        // delta ≈ 40-80 = -40
        XCTAssertLessThan(alcoholRecovery?.delta ?? 0, -BehaviorEngine.minMeaningfulDelta)
    }

    func test_generateInsights_meditationBeneficial() {
        let cal = Calendar.current
        var checkIns: [DailyCheckIn] = []
        var metrics: [DailyMetrics] = []

        for i in 0..<12 {
            let checkDate = cal.date(byAdding: .day, value: -(i * 2 + 1), to: Date())!
            let nextDate  = cal.date(byAdding: .day, value: 1, to: checkDate)!
            let didMeditate = i < 6  // 6 meditation nights vs 6 without
            checkIns.append(makeCheckIn(date: checkDate, meditation: didMeditate))
            let recovery = didMeditate ? 80.0 : 55.0
            metrics.append(makeMetrics(date: nextDate, recovery: recovery, sleep: 75))
        }

        let insights = BehaviorEngine.generateInsights(checkIns: checkIns, metrics: metrics)
        let meditationInsight = insights.first {
            $0.behaviorName == "Meditation" && $0.metricName == "Recovery Score"
        }
        XCTAssertNotNil(meditationInsight)
        XCTAssertFalse(meditationInsight?.isNegativeImpact ?? true,
                       "Meditation should be beneficial for recovery")
    }

    func test_generateInsights_sortedByAbsoluteDeltaDescending() {
        let cal = Calendar.current
        var checkIns: [DailyCheckIn] = []
        var metrics: [DailyMetrics] = []

        for i in 0..<12 {
            let checkDate = cal.date(byAdding: .day, value: -(i * 2 + 1), to: Date())!
            let nextDate  = cal.date(byAdding: .day, value: 1, to: checkDate)!
            let hasAlcohol = i < 6
            var ci = makeCheckIn(date: checkDate, alcohol: hasAlcohol, caffeine: hasAlcohol)
            checkIns.append(ci)
            let recovery = hasAlcohol ? 40.0 : 80.0
            let sleep    = hasAlcohol ? 60.0 : 70.0  // smaller delta
            metrics.append(makeMetrics(date: nextDate, recovery: recovery, sleep: sleep))
        }

        let insights = BehaviorEngine.generateInsights(checkIns: checkIns, metrics: metrics)
        // Insights should be sorted by descending |delta|
        for i in 0..<max(0, insights.count - 1) {
            XCTAssertGreaterThanOrEqual(abs(insights[i].delta), abs(insights[i + 1].delta))
        }
    }

    func test_generateInsights_smallDeltaFiltered() {
        let cal = Calendar.current
        var checkIns: [DailyCheckIn] = []
        var metrics: [DailyMetrics] = []

        // alcohol changes recovery by only 1 point — below minMeaningfulDelta=2
        for i in 0..<12 {
            let checkDate = cal.date(byAdding: .day, value: -(i * 2 + 1), to: Date())!
            let nextDate  = cal.date(byAdding: .day, value: 1, to: checkDate)!
            let hasAlcohol = i < 6
            checkIns.append(makeCheckIn(date: checkDate, alcohol: hasAlcohol))
            let recovery = hasAlcohol ? 70.0 : 71.0
            metrics.append(makeMetrics(date: nextDate, recovery: recovery, sleep: 75))
        }

        let insights = BehaviorEngine.generateInsights(checkIns: checkIns, metrics: metrics)
        let alcoholInsight = insights.first {
            $0.behaviorName == "Alcohol" && $0.metricName == "Recovery Score"
        }
        XCTAssertNil(alcoholInsight, "Delta < \(BehaviorEngine.minMeaningfulDelta) should be filtered out")
    }

    // MARK: - impactDescription

    func test_impactDescription_negativeRecovery() {
        let insight = BehaviorInsight(
            behaviorName: "Alcohol",
            metricName: "Recovery Score",
            averageWith: 45,
            averageWithout: 75,
            occurrences: 8,
            isNegativeImpact: true
        )
        let desc = insight.impactDescription
        XCTAssertTrue(desc.contains("Alcohol"))
        XCTAssertTrue(desc.contains("reduces"))
        XCTAssertTrue(desc.contains("Recovery Score"))
        XCTAssertTrue(desc.contains("30 points"))
    }

    func test_impactDescription_positiveHRV() {
        let insight = BehaviorInsight(
            behaviorName: "Meditation",
            metricName: "HRV",
            averageWith: 65,
            averageWithout: 55,
            occurrences: 7,
            isNegativeImpact: false
        )
        let desc = insight.impactDescription
        XCTAssertTrue(desc.contains("Meditation"))
        XCTAssertTrue(desc.contains("increases"))
        XCTAssertTrue(desc.contains("HRV"))
        XCTAssertTrue(desc.contains("ms"))
    }

    // MARK: - coachingTips

    func test_coachingTips_harmfulInsightAppearsFirst() {
        let harmful = BehaviorInsight(
            behaviorName: "Alcohol",
            metricName: "Recovery Score",
            averageWith: 45, averageWithout: 75,
            occurrences: 8, isNegativeImpact: true
        )
        let metrics = makeMetrics(date: Date(), recovery: 60, sleep: 70)
        let tips = BehaviorEngine.coachingTips(
            todayMetrics: metrics,
            recentCheckIns: [],
            insights: [harmful]
        )
        XCTAssertFalse(tips.isEmpty)
        XCTAssertTrue(tips[0].contains("Alcohol"))
    }

    func test_coachingTips_fallsBackToGenericIfNoInsights() {
        let metrics = makeMetrics(date: Date(), recovery: 80, sleep: 85)
        let tips = BehaviorEngine.coachingTips(
            todayMetrics: metrics,
            recentCheckIns: [],
            insights: []
        )
        XCTAssertFalse(tips.isEmpty, "Should always return at least one tip")
        // Generic fallback should mention recovery-related advice
        XCTAssertFalse(tips[0].isEmpty)
    }

    func test_coachingTips_maxThreeTips() {
        let insights = (0..<6).map { i in
            BehaviorInsight(
                behaviorName: "Behavior \(i)",
                metricName: "Recovery Score",
                averageWith: 40, averageWithout: 80,
                occurrences: 6, isNegativeImpact: true
            )
        }
        let metrics = makeMetrics(date: Date(), recovery: 50, sleep: 60)
        let tips = BehaviorEngine.coachingTips(
            todayMetrics: metrics,
            recentCheckIns: [],
            insights: insights
        )
        XCTAssertLessThanOrEqual(tips.count, 3)
    }

    func test_coachingTips_elevatedSleepingHR_addsTip() {
        var metrics = makeMetrics(date: Date(), recovery: 70, sleep: 75)
        // Create a metrics with elevated sleeping HR vs resting HR
        let metricsWithHR = DailyMetrics(
            date: Date(),
            recoveryScore: 70, strainScore: 10,
            sleepScore: 75, stressScore: 30,
            hrvAverage: nil, restingHR: 55,
            sleepDurationHours: nil, sleepNeedHours: nil,
            activeCalories: nil, stepCount: nil, vo2Max: nil,
            respiratoryRate: nil,
            sleepingHR: 65,   // 10 bpm above resting HR (threshold is 5)
            sleepingHRV: nil,
            sleepInterruptions: nil
        )
        let tips = BehaviorEngine.coachingTips(
            todayMetrics: metricsWithHR,
            recentCheckIns: [],
            insights: []
        )
        let hasSleepingHRTip = tips.contains { $0.contains("sleeping HR") }
        XCTAssertTrue(hasSleepingHRTip, "Should warn about elevated sleeping HR")
    }

    func test_coachingTips_manyInterruptions_addsTip() {
        let metricsWithInterruptions = DailyMetrics(
            date: Date(),
            recoveryScore: 60, strainScore: 10,
            sleepScore: 65, stressScore: 40,
            hrvAverage: nil, restingHR: nil,
            sleepDurationHours: nil, sleepNeedHours: nil,
            activeCalories: nil, stepCount: nil, vo2Max: nil,
            respiratoryRate: nil,
            sleepingHR: nil, sleepingHRV: nil,
            sleepInterruptions: 4
        )
        let tips = BehaviorEngine.coachingTips(
            todayMetrics: metricsWithInterruptions,
            recentCheckIns: [],
            insights: []
        )
        let hasInterruptionTip = tips.contains { $0.contains("interrupted") }
        XCTAssertTrue(hasInterruptionTip, "Should mention sleep interruptions")
    }
}
