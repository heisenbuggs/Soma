import Foundation

// MARK: - WeeklySummaryEngine

/// Generates a rule-based 3–4 paragraph plain-language narrative summarising the past week.
/// Uses template selection — no external API. Designed for Monday-morning delivery.
struct WeeklySummaryEngine {

    struct WeeklySummary {
        let narrative: String   // Full 3–4 paragraph text for in-app display
        let teaser: String      // ~120-char excerpt for push notification body
        let weekStart: Date
        let weekEnd: Date
    }

    // MARK: - Public Entry Point

    /// Generates a weekly summary from the past 7 days of data.
    /// Returns nil if fewer than 3 days of metrics are available.
    static func generate(
        metrics: [DailyMetrics],
        checkIns: [DailyCheckIn],
        hrvBaseline: Double?,
        rhrBaseline: Double?
    ) -> WeeklySummary? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let weekStart = cal.date(byAdding: .day, value: -6, to: today) else { return nil }

        let weekMetrics = metrics
            .filter { cal.startOfDay(for: $0.date) >= weekStart }
            .sorted { $0.date < $1.date }

        guard weekMetrics.count >= 3 else { return nil }

        let weekCheckIns = checkIns.filter { cal.startOfDay(for: $0.date) >= weekStart }

        let p1 = hrvParagraph(metrics: weekMetrics, baseline: hrvBaseline)
        let p2 = sleepParagraph(metrics: weekMetrics)
        let p3 = trainingParagraph(metrics: weekMetrics)
        let p4 = behavioralParagraph(checkIns: weekCheckIns)

        var paragraphs = [p1, p2, p3]
        if let p4 { paragraphs.append(p4) }

        let narrative = paragraphs.joined(separator: "\n\n")
        let teaser = p1.count > 120 ? String(p1.prefix(120)) + "…" : p1

        return WeeklySummary(narrative: narrative, teaser: teaser, weekStart: weekStart, weekEnd: today)
    }

    // MARK: - Paragraph 1: HRV Arc

    private static func hrvParagraph(metrics: [DailyMetrics], baseline: Double?) -> String {
        let values = metrics.compactMap { $0.hrvAverage }
        guard !values.isEmpty else {
            return "HRV data wasn't available this week — make sure your Apple Watch is charged before sleep for the best overnight readings."
        }

        let weekAvg = values.reduce(0, +) / Double(values.count)

        // Trend: first half vs second half
        let mid = max(1, values.count / 2)
        let firstAvg = values.prefix(mid).reduce(0, +) / Double(values.prefix(mid).count)
        let lastAvg  = values.suffix(mid).reduce(0, +) / Double(values.suffix(mid).count)
        let delta = lastAvg - firstAvg
        let trend: String
        if delta > 3      { trend = "trending upward through the week" }
        else if delta < -3 { trend = "trending downward through the week" }
        else               { trend = "stable across the week" }

        let baselineNote: String
        if let base = baseline, base > 0 {
            let ratio = weekAvg / base
            if ratio > 1.10 {
                let pct = Int(((ratio - 1) * 100).rounded())
                baselineNote = " — sitting \(pct)% above your 30-day average, an encouraging sign of adaptation."
            } else if ratio < 0.90 {
                let pct = Int(((1 - ratio) * 100).rounded())
                baselineNote = " — running \(pct)% below your 30-day average, suggesting accumulated fatigue or an underlying stressor."
            } else {
                baselineNote = " — right in line with your 30-day average."
            }
        } else {
            baselineNote = "."
        }

        return "Your HRV averaged \(String(format: "%.0f", weekAvg)) ms this week, \(trend)\(baselineNote) HRV is the most reliable window into how well your autonomic nervous system is recovering, so this number shapes how aggressively you should train next week."
    }

    // MARK: - Paragraph 2: Sleep Patterns

    private static func sleepParagraph(metrics: [DailyMetrics]) -> String {
        let actuals = metrics.compactMap { $0.sleepDurationHours }
        guard !actuals.isEmpty else {
            return "Sleep data wasn't recorded this week. Wear your Apple Watch to bed every night for personalized sleep insights."
        }

        let goals    = metrics.compactMap { $0.sleepNeedHours }
        let avgGoal  = goals.isEmpty ? 8.0 : goals.reduce(0, +) / Double(goals.count)
        let avgSleep = actuals.reduce(0, +) / Double(actuals.count)
        let metGoal  = actuals.filter { $0 >= avgGoal - 0.25 }.count
        let totalDebt = actuals.map { max(0, avgGoal - $0) }.reduce(0, +)

        let scores   = metrics.compactMap { $0.sleepScore }
        let avgScore = scores.isEmpty ? nil : scores.reduce(0, +) / Double(scores.count)

        var parts: [String] = []
        parts.append("Sleep averaged \(formatHours(avgSleep)) per night this week, with \(metGoal) out of \(actuals.count) nights meeting your personalised goal.")

        if totalDebt > 1.5 {
            parts.append("You accumulated \(formatHours(totalDebt)) of sleep debt across the week — prioritising an earlier bedtime over the next few days will meaningfully restore recovery capacity.")
        } else if totalDebt > 0.5 {
            parts.append("Modest sleep debt of \(formatHours(totalDebt)) built up — a consistent bedtime this week will clear it quickly.")
        } else {
            parts.append("Sleep debt was minimal, a healthy sign heading into next week.")
        }

        if let q = avgScore {
            if q >= 75      { parts.append("Sleep quality was strong (average score \(Int(q.rounded()))).")}
            else if q >= 50 { parts.append("Sleep quality was moderate (average score \(Int(q.rounded()))) — consistent sleep timing tends to lift this score over time.") }
            else            { parts.append("Sleep quality was below par (average score \(Int(q.rounded()))) — focus on a calming wind-down routine and a fixed wake time.") }
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Paragraph 3: Training Load Story

    private static func trainingParagraph(metrics: [DailyMetrics]) -> String {
        let strains   = metrics.map { $0.strainScore }
        let avgStrain = strains.reduce(0, +) / Double(strains.count)
        let peak      = strains.max() ?? 0
        let restDays  = strains.filter { $0 < 20 }.count
        let highDays  = strains.filter { $0 > 60 }.count

        let descriptor: String
        switch avgStrain {
        case 60...:  descriptor = "high-intensity week"
        case 40..<60: descriptor = "solid training week"
        case 20..<40: descriptor = "moderate week"
        default:      descriptor = "recovery-focused week"
        }

        var parts: [String] = [
            "Training load paints the picture of a \(descriptor) — average strain was \(Int(avgStrain.rounded())) with a single-day peak of \(Int(peak.rounded()))."
        ]

        if restDays >= 2 {
            parts.append("You took \(restDays) rest or very light days, a healthy cadence for long-term progress.")
        } else if restDays == 0 && highDays >= 3 {
            parts.append("There were no true rest days this week — building in at least one planned recovery day next week will protect fitness gains.")
        }

        let acr = TrainingGuidanceEngine.acrRatio(history: metrics)
        if let acr {
            if acr > 1.3 {
                parts.append("Your acute-to-chronic ratio is elevated at \(String(format: "%.2f", acr)), signalling a recent spike in load — scaling back intensity next week is the smart play.")
            } else if acr < 0.8 {
                parts.append("Your training load has been consistently low (ACR \(String(format: "%.2f", acr))) — there's room to gradually increase intensity next week if recovery stays strong.")
            }
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Paragraph 4: Behavioural Correlations (optional)

    private static func behavioralParagraph(checkIns: [DailyCheckIn]) -> String? {
        guard checkIns.count >= 3 else { return nil }

        var findings: [String] = []

        let alcoholNights = checkIns.filter { $0.alcoholConsumed }.count
        if alcoholNights >= 3 {
            findings.append("alcohol on \(alcoholNights) nights (which can suppress HRV and deepen sleep debt)")
        }

        let screenNights = checkIns.filter { $0.screenBeforeBed }.count
        if screenNights >= 4 {
            findings.append("screen use before bed on \(screenNights) nights (a consistent pattern linked to reduced sleep quality)")
        }

        let meditationDays = checkIns.filter { $0.meditated }.count
        if meditationDays >= 3 {
            findings.append("meditation on \(meditationDays) days (a habit reliably associated with lower stress and improved HRV)")
        }

        let lateWorkoutNights = checkIns.filter { $0.lateWorkout }.count
        if lateWorkoutNights >= 2 {
            findings.append("late workouts on \(lateWorkoutNights) evenings (which tend to elevate overnight heart rate)")
        }

        let caffeineNights = checkIns.filter { $0.caffeineAfter5PM }.count
        if caffeineNights >= 3 {
            findings.append("caffeine after 5 PM on \(caffeineNights) days (a common driver of sleep latency and fragmentation)")
        }

        guard !findings.isEmpty else { return nil }

        let list = findings.joined(separator: "; ")
        return "Behaviourally, this week included \(list). These patterns show up reliably in your recovery scores — even one or two small adjustments here often produce outsized gains in sleep quality and morning readiness."
    }

    // MARK: - Helpers

    private static func formatHours(_ h: Double) -> String {
        let total = Int((h * 60).rounded())
        let hrs   = total / 60
        let mins  = total % 60
        if hrs == 0  { return "\(mins)m" }
        if mins == 0 { return "\(hrs)h" }
        return "\(hrs)h \(mins)m"
    }
}
