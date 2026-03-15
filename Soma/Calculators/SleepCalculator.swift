import Foundation

struct SleepCalculator {

    // MARK: - Sleep Score

    // Optimal stage targets (as fraction of total sleep)
    static let optimalDeepRatio: Double = 0.20   // 20%
    static let optimalREMRatio: Double  = 0.22   // 22%
    static let optimalCoreRatio: Double = 0.50   // 50%

    /// Calculates sleep score 0–100.
    ///
    /// Weights:
    ///   Duration     (30%): min(100, T/N × 100)
    ///   Stage mix    (30%): weighted deep/REM/core vs optimal ratios
    ///   HRV sleep    (15%): sleeping HRV relative to baseline
    ///   HR sleep     (15%): sleeping HR relative to baseline (lower = better)
    ///   Interruptions(10%): wake segments during sleep
    ///
    /// When sleeping HRV/HR data is unavailable those components default to 50 (neutral).
    static func calculateScore(
        sleep: SleepData,
        sleepNeed: Double,
        sleepingHRV: Double? = nil,
        sleepingHR: Double? = nil,
        hrvBaseline: Double? = nil,
        sleepingHRBaseline: Double? = nil
    ) -> Double {
        let totalHours = sleep.totalDuration / 3600.0
        guard totalHours > 0, sleepNeed > 0 else { return 0 }

        // 1. Duration
        let durationScore = min(100.0, totalHours / sleepNeed * 100.0)

        // 2. Stage quality
        let deepRatio  = sleep.deepSleepDuration / sleep.totalDuration
        let remRatio   = sleep.remSleepDuration  / sleep.totalDuration
        let coreRatio  = sleep.coreSleepDuration / sleep.totalDuration
        let deepScore  = min(100.0, deepRatio / optimalDeepRatio  * 100.0)
        let remScore   = min(100.0, remRatio  / optimalREMRatio   * 100.0)
        let coreScore  = min(100.0, coreRatio / optimalCoreRatio  * 100.0)
        let stageScore = 0.40 * deepScore + 0.40 * remScore + 0.20 * coreScore

        // 3. HRV during sleep (higher = better; ratio vs baseline)
        let hrvScore = computeSleepingHRVScore(sleepingHRV: sleepingHRV, baseline: hrvBaseline)

        // 4. Heart rate during sleep (lower = better; ratio vs baseline)
        let hrScore = computeSleepingHRScore(sleepingHR: sleepingHR, baseline: sleepingHRBaseline)

        // 5. Interruptions
        let interruptionScore = computeInterruptionScore(count: sleep.interruptionCount)

        let score = 0.30 * durationScore
                  + 0.30 * stageScore
                  + 0.15 * hrvScore
                  + 0.15 * hrScore
                  + 0.10 * interruptionScore

        return BaselineCalculator.clamp(score, min: 0, max: 100)
    }

    // MARK: - Sub-component Helpers

    static func computeSleepingHRVScore(sleepingHRV: Double?, baseline: Double?) -> Double {
        guard let hrv = sleepingHRV, let base = baseline, base > 0 else { return 50 }
        // ratio in [0.7, 1.3] → score [0, 100]
        return BaselineCalculator.normalizeRatio(hrv / base, low: 0.7, high: 1.3)
    }

    static func computeSleepingHRScore(sleepingHR: Double?, baseline: Double?) -> Double {
        guard let hr = sleepingHR, let base = baseline, base > 0 else { return 50 }
        // Lower sleeping HR = better → invert ratio
        // ratio in [0.7, 1.3] → score [100, 0] (inverted)
        let ratio = hr / base
        return BaselineCalculator.normalizeRatio(ratio, low: 1.3, high: 0.7)
    }

    static func computeInterruptionScore(count: Int) -> Double {
        // Each interruption costs 15 points; floor at 0
        return max(0.0, 100.0 - Double(count) * 15.0)
    }

    // MARK: - Sleep Need

    /// Calculates sleep need in hours.
    /// - Parameters:
    ///   - baselineSleep: User's preferred baseline sleep (default 8h)
    ///   - last7DaysNeedVsActual: Array of (need, actual) for last 7 nights
    ///   - yesterdayStrain: Yesterday's strain score 0–21
    static func calculateSleepNeed(
        baselineSleep: Double = 7.0,
        recentNeedVsActual: [(need: Double, actual: Double)],
        yesterdayStrain: Double
    ) -> Double {
        // Debt = average nightly shortfall vs sleep goal over the last 3 days.
        // Older debt is not carried forward — window resets beyond 3 days.
        let debtPerNight: Double
        if recentNeedVsActual.isEmpty {
            debtPerNight = 0
        } else {
            let totalDebt = recentNeedVsActual.reduce(0.0) { acc, pair in
                acc + max(0, baselineSleep - pair.actual)
            }
            debtPerNight = totalDebt / Double(recentNeedVsActual.count)
        }

        let strainFactor = (yesterdayStrain / 21.0) * 0.5  // up to +30 min

        let need = baselineSleep + debtPerNight + strainFactor
        return BaselineCalculator.clamp(need, min: 7.0, max: 9.5)
    }

    // MARK: - Sleep Debt

    /// Total sleep debt from the last N days (hours).
    static func computeSleepDebt(needVsActual: [(need: Double, actual: Double)]) -> Double {
        needVsActual.reduce(0.0) { acc, pair in acc + max(0, pair.need - pair.actual) }
    }

    // MARK: - Bedtime Recommendation

    /// Returns the recommended bedtime to meet a given sleep need on a specific wake time.
    /// - Parameters:
    ///   - wakeTime: The target wake time for tomorrow.
    ///   - sleepNeed: Sleep need in hours.
    ///   - latencyMinutes: Estimated time to fall asleep once in bed (default 12 min).
    static func bedtimeTarget(wakeTime: Date, sleepNeed: Double, latencyMinutes: Int = 12) -> Date {
        let totalSeconds = (sleepNeed * 3600.0) + Double(latencyMinutes * 60)
        return wakeTime.addingTimeInterval(-totalSeconds)
    }
}
