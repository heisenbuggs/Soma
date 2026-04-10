import Foundation

// MARK: - Behavior Insight

struct BehaviorInsight: Identifiable, Codable {
    let id: UUID
    let behaviorName: String
    let metricName: String
    let averageWith: Double
    let averageWithout: Double
    let occurrences: Int
    let isNegativeImpact: Bool   // true = behavior harms this metric

    var delta: Double { averageWith - averageWithout }

    var impactDescription: String {
        let absVal = abs(delta)
        let direction = delta > 0 ? "increases" : "reduces"
        let unit: String
        switch metricName {
        case "HRV", "Sleeping HRV":       unit = "ms"
        case "Sleeping HR":                unit = "bpm"
        default:                           unit = "points"
        }
        let formatted = absVal >= 1 ? String(format: "%.0f", absVal) : String(format: "%.1f", absVal)
        return "\(behaviorName) \(direction) your \(metricName) by \(formatted) \(unit)."
    }
}

// MARK: - Behavior Engine

struct BehaviorEngine {

    static let minObservations = 5
    static let minMeaningfulDelta = 2.0   // ignore changes smaller than this

    // MARK: - Public API

    /// Generates behavior–outcome correlation insights from stored check-ins and daily metrics.
    static func generateInsights(
        checkIns: [DailyCheckIn],
        metrics: [DailyMetrics]
    ) -> [BehaviorInsight] {
        guard checkIns.count >= minObservations else { return [] }

        let cal = Calendar.current
        var metricsByDay: [Date: DailyMetrics] = [:]
        for m in metrics {
            metricsByDay[cal.startOfDay(for: m.date)] = m
        }

        let behaviors: [(name: String, flag: (DailyCheckIn) -> Bool)] = [
            ("Alcohol",           { $0.alcoholConsumed }),
            ("Late Caffeine",     { $0.caffeineAfter5PM }),
            ("Late Meal",         { $0.lateMealBeforeBed }),
            ("Screen Before Bed", { $0.screenBeforeBed }),
            ("Late Workout",      { $0.lateWorkout }),
            ("Meditation",        { $0.meditated }),
            ("Stretching",        { $0.stretched }),
            ("Cold Exposure",     { $0.coldExposure }),
        ]

        // Metrics where higher = better
        let positiveMetrics: [(name: String, key: KeyPath<DailyMetrics, Double>)] = [
            ("Sleep Score",    \.sleepScore),
            ("Recovery Score", \.recoveryScore),
        ]
        // Metrics stored as optional
        let optionalPositiveMetrics: [(name: String, key: KeyPath<DailyMetrics, Double?>)] = [
            ("HRV",            \.hrvAverage),
            ("Sleeping HRV",   \.sleepingHRV),
        ]
        let optionalNegativeMetrics: [(name: String, key: KeyPath<DailyMetrics, Double?>)] = [
            ("Sleeping HR",    \.sleepingHR),
        ]

        var insights: [BehaviorInsight] = []

        for behavior in behaviors {
            let withDays    = checkIns.filter {  behavior.flag($0) }
            let withoutDays = checkIns.filter { !behavior.flag($0) }
            guard withDays.count >= minObservations,
                  withoutDays.count >= minObservations else { continue }

            // Required metrics
            for metric in positiveMetrics {
                if let insight = analyze(
                    behaviorName: behavior.name,
                    metricName: metric.name,
                    withDays: withDays, withoutDays: withoutDays,
                    metricsByDay: metricsByDay,
                    extract: { m in m[keyPath: metric.key] },
                    higherIsBetter: true
                ) { insights.append(insight) }
            }

            // Optional positive metrics
            for metric in optionalPositiveMetrics {
                if let insight = analyze(
                    behaviorName: behavior.name,
                    metricName: metric.name,
                    withDays: withDays, withoutDays: withoutDays,
                    metricsByDay: metricsByDay,
                    extract: { m in m[keyPath: metric.key] },
                    higherIsBetter: true
                ) { insights.append(insight) }
            }

            // Optional negative metrics (lower is better)
            for metric in optionalNegativeMetrics {
                if let insight = analyze(
                    behaviorName: behavior.name,
                    metricName: metric.name,
                    withDays: withDays, withoutDays: withoutDays,
                    metricsByDay: metricsByDay,
                    extract: { m in m[keyPath: metric.key] },
                    higherIsBetter: false
                ) { insights.append(insight) }
            }
        }

        return insights
            .filter { abs($0.delta) >= minMeaningfulDelta }
            .sorted { abs($0.delta) > abs($1.delta) }
    }

    // MARK: - Recovery Coaching

    /// Returns the top targeted coaching tips based on today's metrics and recent check-ins.
    static func coachingTips(
        todayMetrics: DailyMetrics,
        recentCheckIns: [DailyCheckIn],
        insights: [BehaviorInsight]
    ) -> [String] {
        var tips: [String] = []

        // 1. Behavior-driven tips from correlations (top harmful behaviors first)
        let harmful = insights.filter { $0.isNegativeImpact }.prefix(2)
        for insight in harmful {
            tips.append(insight.impactDescription)
        }

        // 2. Physiological tips — ordered roughly by actionability

        // Pre-sleep stress — most actionable before tonight
        if let es = todayMetrics.eveningStressScore, es > 55 {
            tips.append("Pre-sleep autonomic stress was high. Try 4-7-8 breathing or light stretching in the hour before bed.")
        }

        // Sleeping HR elevation
        if let sleepingHR = todayMetrics.sleepingHR,
           let rhr = todayMetrics.restingHR,
           sleepingHR > rhr + 5 {
            tips.append("Your sleeping HR was \(Int(sleepingHR)) bpm — elevated vs resting. Avoid alcohol and heavy meals within 3h of bed.")
        }

        // Fragmented sleep
        if let interruptions = todayMetrics.sleepInterruptions, interruptions >= 3 {
            tips.append("Sleep was fragmented (\(interruptions) interruptions). Limit fluids after 7 PM and keep your room cool and dark.")
        }

        // Low stand hours — only after 8 PM when the day is effectively over
        let currentHour = Calendar.current.component(.hour, from: Date())
        if let stand = todayMetrics.standHours, stand < 6, currentHour >= 20 {
            tips.append("You only stood for \(stand)h today. Even a 5-minute walk each hour improves insulin sensitivity and recovery.")
        }

        // Irregular sleep schedule
        if let consistency = todayMetrics.sleepConsistencyScore, consistency < 45 {
            tips.append("Your sleep schedule is irregular. Pick a fixed wake time and hold it — even on weekends — to stabilize your circadian rhythm.")
        }

        // Long nap
        if let nap = todayMetrics.napDurationMinutes, nap > 90 {
            tips.append("Your nap was \(Int(nap)) min — quite long. Cap naps at 25 min to avoid sleep inertia and protect tonight's sleep pressure.")
        }

        // Blood oxygen low
        if let spo2 = todayMetrics.bloodOxygen, spo2 < 95 {
            tips.append("SpO2 is \(String(format: "%.1f", spo2))% — skip intense training today and ensure good room ventilation while sleeping.")
        }

        // Walking HR elevated
        if let whr = todayMetrics.walkingHRAverage, whr > 95 {
            tips.append("Walking heart rate is elevated (\(Int(whr)) bpm). Your cardiovascular system is under load — keep today's effort light.")
        }

        // VO2 Max trending down
        if let trend = todayMetrics.vo2MaxTrend, trend < -0.5 {
            tips.append("Aerobic fitness is drifting down. Two 30-minute zone 2 sessions per week (easy conversational pace) will reverse the trend.")
        }

        // No mindfulness logged — suggest it
        if (todayMetrics.mindfulMinutes ?? 0) == 0,
           todayMetrics.stressScore > 45 {
            tips.append("Stress is elevated and no mindfulness was logged. Even 5 minutes of focused breathing lowers cortisol and improves HRV.")
        }

        // High recovery — encourage training
        if todayMetrics.recoveryScore >= 80, tips.count < 2 {
            tips.append("Recovery is excellent — your body is ready. A quality training session today will yield the best adaptation.")
        }

        // 3. Fallback: generic recommendation from recovery
        if tips.isEmpty {
            tips.append(RecoveryCalculator.trainingRecommendation(
                recovery: todayMetrics.recoveryScore,
                last3DayStrainAvg: 0,
                sleepDebtHours: 0
            ))
        }

        return Array(tips.prefix(4))
    }
}

// MARK: - Private Helpers

private extension BehaviorEngine {

    /// Computes average metric on days with vs without a behavior (using next-day metrics).
    static func analyze(
        behaviorName: String,
        metricName: String,
        withDays: [DailyCheckIn],
        withoutDays: [DailyCheckIn],
        metricsByDay: [Date: DailyMetrics],
        extract: (DailyMetrics) -> Double?,
        higherIsBetter: Bool
    ) -> BehaviorInsight? {
        let cal = Calendar.current

        func nextDayValues(for checkIns: [DailyCheckIn]) -> [Double] {
            checkIns.compactMap { ci -> Double? in
                let day = cal.startOfDay(for: ci.date)
                let next = cal.date(byAdding: .day, value: 1, to: day)!
                return metricsByDay[next].flatMap(extract).flatMap { $0 > 0 ? $0 : nil }
            }
        }

        let valsWith    = nextDayValues(for: withDays)
        let valsWithout = nextDayValues(for: withoutDays)

        guard valsWith.count >= BehaviorEngine.minObservations,
              valsWithout.count >= BehaviorEngine.minObservations else { return nil }

        let avgWith    = valsWith.reduce(0, +) / Double(valsWith.count)
        let avgWithout = valsWithout.reduce(0, +) / Double(valsWithout.count)
        let delta      = avgWith - avgWithout
        let isNegative = higherIsBetter ? delta < 0 : delta > 0

        return BehaviorInsight(
            id: UUID(),
            behaviorName: behaviorName,
            metricName: metricName,
            averageWith: avgWith,
            averageWithout: avgWithout,
            occurrences: valsWith.count,
            isNegativeImpact: isNegative
        )
    }
}
