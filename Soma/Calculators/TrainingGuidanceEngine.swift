import Foundation

// MARK: - TrainingGuidanceEngine

struct TrainingGuidanceEngine {

    // MARK: - VO2Max Fitness Multiplier

    /// Returns a multiplier that scales the strain target up for fitter athletes.
    /// Higher VO2Max → can tolerate and benefit from higher training loads.
    static func vo2MaxMultiplier(_ vo2Max: Double?) -> Double {
        guard let v = vo2Max else { return 1.0 }
        switch v {
        case ..<35:   return 0.8   // Low fitness
        case 35..<45: return 1.0   // Average
        case 45..<55: return 1.1   // Good
        case 55..<65: return 1.2   // Excellent
        default:      return 1.3   // Elite (65+)
        }
    }

    // MARK: - Acute-to-Chronic Ratio (ACR)

    /// 7-day avg strain / 28-day avg strain.
    /// ACR > 1.3 indicates spike in training load → overtraining risk.
    /// ACR < 0.8 indicates undertraining.
    static func acrRatio(history: [DailyMetrics]) -> Double? {
        let sorted = history.sorted { $0.date < $1.date }
        let last7  = sorted.suffix(7).map  { $0.strainScore }
        let last28 = sorted.suffix(28).map { $0.strainScore }
        guard !last7.isEmpty, !last28.isEmpty else { return nil }
        let acute   = last7.reduce(0, +)  / Double(last7.count)
        let chronic = last28.reduce(0, +) / Double(last28.count)
        guard chronic > 0 else { return nil }
        return acute / chronic
    }

    // MARK: - Muscle / Load Fatigue Detection

    /// Infers accumulated fatigue from recent high-load workout days.
    /// Without per-muscle workout data from HealthKit, we use strain-based proxies.
    static func detectFatigue(history: [DailyMetrics]) -> [String] {
        let recent = history.sorted { $0.date < $1.date }.suffix(3)
        var flags: [String] = []

        let highLoadDays = recent.filter { ($0.workoutStrain ?? 0) > 30 || $0.strainScore > 50 }.count
        if highLoadDays >= 2 {
            flags.append("Accumulated Training Load")
        }

        let highCardio = recent.filter { ($0.workoutStrain ?? 0) > 25 }.count
        if highCardio >= 2 {
            flags.append("Cardio/Legs")
        }

        return flags
    }

    // MARK: - Workout Suggestions

    /// Returns 3–4 appropriate workout suggestions based on activity level and fatigue.
    static func suggestWorkouts(level: ActivityLevel, fatigueFlags: [String]) -> [String] {
        let hasCardioFatigue = fatigueFlags.contains("Cardio/Legs")

        switch level {
        case .rest:
            return ["Stretching", "Meditation", "Short walk", "Rest"]

        case .light:
            return hasCardioFatigue
                ? ["Upper body mobility", "Swimming", "Core work"]
                : ["Walking", "Stretching"]

        case .moderate:
            return hasCardioFatigue
                ? ["Upper body strength", "Swimming", "Strength training", "Pilates"]
                : ["Jogging", "Strength training", "Cycling", "Swimming"]

        case .hard:
            return hasCardioFatigue
                ? ["Strength training", "Upper body focus", "Cross training"]
                : ["Strength training", "Running", "Moderate HIIT", "Cycling"]

        case .peak:
            return ["HIIT", "Running", "Heavy strength training"]
        }
    }

    // MARK: - Main Entry Point

    /// Generates a full training guidance recommendation from today's metrics and history.
    ///
    /// - Parameters:
    ///   - metrics: Today's computed DailyMetrics.
    ///   - history: Recent history (up to 28 days) for ACR and fatigue.
    ///   - hrvBaseline: 30-day rolling HRV baseline, or nil if insufficient data.
    ///   - rhrBaseline: 30-day rolling RHR baseline, or nil if insufficient data.
    ///   - sleepGoal: User's target sleep duration in hours.
    ///   - isCalibrating: True if fewer than 7 days of data exist.
    static func generate(
        metrics: DailyMetrics,
        history: [DailyMetrics],
        hrvBaseline: Double?,
        rhrBaseline: Double?,
        sleepGoal: Double,
        isCalibrating: Bool
    ) -> DailyTrainingGuidance {

        // During calibration, physiology baselines don't exist yet.
        // Default to Moderate and explain why.
        if isCalibrating {
            let factors = ReadinessFactors(
                recoveryScore: metrics.recoveryScore,
                sleepScore: metrics.sleepScore,
                hrvRatio: nil, rhrDelta: nil,
                sleepDebtHours: 0, yesterdayStrain: 0,
                acrRatio: nil, vo2Max: metrics.vo2Max,
                fitnessMultiplier: 1.0
            )
            return DailyTrainingGuidance(
                date: metrics.date,
                readinessScore: 50,
                activityLevel: .moderate,
                targetStrainMin: ActivityLevel.moderate.baseTargetStrainMin,
                targetStrainMax: ActivityLevel.moderate.baseTargetStrainMax,
                suggestedWorkouts: ["Jogging", "Strength training", "Cycling", "Swimming"],  // moderate defaults
                fatigueFlags: [],
                factors: factors,
                explanation: "Baseline physiology is still being established (< 7 days of data). Moderate activity is recommended during calibration."
            )
        }

        // — Inputs —

        let hrvRatio: Double? = {
            guard let hrv = metrics.hrvAverage, let base = hrvBaseline, base > 0 else { return nil }
            return hrv / base
        }()

        let rhrDelta: Double? = {
            guard let rhr = metrics.restingHR, let base = rhrBaseline else { return nil }
            return rhr - base
        }()

        let sleepDebt = max(0, sleepGoal - (metrics.sleepDurationHours ?? sleepGoal))

        let cal = Calendar.current
        let previousDay = cal.date(byAdding: .day, value: -1, to: metrics.date)!
        let yesterdayStrain = history.first {
            cal.isDate($0.date, inSameDayAs: previousDay)
        }?.strainScore ?? 0

        let acr = acrRatio(history: history)
        let multiplier = vo2MaxMultiplier(metrics.vo2Max)

        // — Step 1: Base Readiness —
        // readiness = recovery×0.5 + sleep×0.3 + hrv_ratio×100×0.2
        // If HRV unavailable, redistribute weight: recovery×0.6 + sleep×0.4
        var readiness: Double
        if let ratio = hrvRatio {
            readiness = metrics.recoveryScore * 0.5
                      + metrics.sleepScore    * 0.3
                      + ratio * 100.0         * 0.2
        } else {
            readiness = metrics.recoveryScore * 0.6
                      + metrics.sleepScore    * 0.4
        }

        // — Step 2: Penalties —
        if sleepDebt > 1.0          { readiness -= 10 }
        if (rhrDelta ?? 0) > 5      { readiness -= 10 }
        if yesterdayStrain > 80     { readiness -= 10 }

        readiness = max(0, min(100, readiness))

        // — Step 3: Activity Level + ACR Overtraining Cap —
        var level = levelFor(readiness: readiness)
        if let acr, acr > 1.3 {
            level = capLevel(level, to: .light)
        }

        // — Step 4: Fatigue Detection —
        let fatigueFlags = detectFatigue(history: history)

        // — Step 5: Strain Target (adjusted by VO2Max, capped by ACR) —
        var strainMin = Int((Double(level.baseTargetStrainMin) * multiplier).rounded())
        var strainMax = Int((Double(level.baseTargetStrainMax) * multiplier).rounded())
        if let acr, acr > 1.3 {
            strainMax = min(strainMax, 40)
            strainMin = min(strainMin, strainMax)
        }
        strainMin = max(0, min(100, strainMin))
        strainMax = max(strainMin, min(100, strainMax))

        // — Step 6: Suggestions + Explanation —
        let workouts    = suggestWorkouts(level: level, fatigueFlags: fatigueFlags)
        let explanation = buildExplanation(
            metrics: metrics, readiness: readiness, level: level,
            hrvRatio: hrvRatio, rhrDelta: rhrDelta,
            sleepDebt: sleepDebt, yesterdayStrain: yesterdayStrain,
            acr: acr, fatigueFlags: fatigueFlags
        )

        let factors = ReadinessFactors(
            recoveryScore: metrics.recoveryScore,
            sleepScore: metrics.sleepScore,
            hrvRatio: hrvRatio, rhrDelta: rhrDelta,
            sleepDebtHours: sleepDebt,
            yesterdayStrain: yesterdayStrain,
            acrRatio: acr,
            vo2Max: metrics.vo2Max,
            fitnessMultiplier: multiplier
        )

        return DailyTrainingGuidance(
            date: metrics.date,
            readinessScore: readiness,
            activityLevel: level,
            targetStrainMin: strainMin,
            targetStrainMax: strainMax,
            suggestedWorkouts: workouts,
            fatigueFlags: fatigueFlags,
            factors: factors,
            explanation: explanation
        )
    }

    // MARK: - Private Helpers

    private static func levelFor(readiness: Double) -> ActivityLevel {
        switch readiness {
        case 85...100: return .peak
        case 65..<85:  return .hard
        case 45..<65:  return .moderate
        case 30..<45:  return .light
        default:       return .rest
        }
    }

    /// Returns the lower of the two levels (more conservative).
    private static func capLevel(_ level: ActivityLevel, to cap: ActivityLevel) -> ActivityLevel {
        level.rawValue <= cap.rawValue ? level : cap
    }

    private static func buildExplanation(
        metrics: DailyMetrics,
        readiness: Double,
        level: ActivityLevel,
        hrvRatio: Double?,
        rhrDelta: Double?,
        sleepDebt: Double,
        yesterdayStrain: Double,
        acr: Double?,
        fatigueFlags: [String]
    ) -> String {
        var parts: [String] = []

        let recoveryLabel = ColorState.recovery(score: metrics.recoveryScore).label.lowercased()
        parts.append("Your recovery is \(recoveryLabel) today.")

        if let ratio = hrvRatio {
            let pct = Int((abs(1.0 - ratio) * 100).rounded())
            if ratio < 0.90 {
                parts.append("HRV is \(pct)% below baseline.")
            } else if ratio > 1.10 {
                parts.append("HRV is \(pct)% above baseline — well recovered.")
            }
        }

        if sleepDebt > 0.25 {
            let mins = Int((sleepDebt * 60).rounded())
            if mins >= 60 {
                let h = mins / 60; let m = mins % 60
                let debtStr = m == 0 ? "\(h)h" : "\(h)h \(m)m"
                parts.append("You have \(debtStr) of sleep debt.")
            } else {
                parts.append("You have \(mins) minutes of sleep debt.")
            }
        }

        if let delta = rhrDelta, delta > 5 {
            parts.append("Resting HR is \(Int(delta.rounded())) bpm above baseline.")
        }

        if yesterdayStrain > 80 {
            parts.append("Yesterday was a very high strain day.")
        }

        if let acr, acr > 1.3 {
            parts.append("Training load is elevated (ACR \(String(format: "%.2f", acr))) — a lighter session protects against overtraining.")
        } else if let acr, acr < 0.8 {
            parts.append("Training load has been low recently — your body is ready for more.")
        }

        if fatigueFlags.contains("Cardio/Legs") {
            parts.append("Recent workouts have loaded the legs — upper body or mobility work is advised.")
        } else if fatigueFlags.contains("Accumulated Training Load") {
            parts.append("Accumulated training load detected — varied activity is advised.")
        }

        return parts.joined(separator: " ")
    }
}
