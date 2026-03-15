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
    ///   Duration (40%): min(100, T/N × 100)
    ///   Deep     (30%): min(100, (D/T) / 0.20 × 100)
    ///   REM      (20%): min(100, (R/T) / 0.22 × 100)
    ///   Core     (10%): min(100, (C/T) / 0.50 × 100)
    static func calculateScore(sleep: SleepData, sleepNeed: Double) -> Double {
        let totalHours = sleep.totalDuration / 3600.0
        guard totalHours > 0, sleepNeed > 0 else { return 0 }

        let durationScore = min(100.0, totalHours / sleepNeed * 100.0)

        let deepRatio  = sleep.deepSleepDuration / sleep.totalDuration
        let remRatio   = sleep.remSleepDuration  / sleep.totalDuration
        let coreRatio  = sleep.coreSleepDuration / sleep.totalDuration

        let deepScore  = min(100.0, deepRatio  / optimalDeepRatio  * 100.0)
        let remScore   = min(100.0, remRatio   / optimalREMRatio   * 100.0)
        let coreScore  = min(100.0, coreRatio  / optimalCoreRatio  * 100.0)

        let score = 0.40 * durationScore
                  + 0.30 * deepScore
                  + 0.20 * remScore
                  + 0.10 * coreScore

        return BaselineCalculator.clamp(score, min: 0, max: 100)
    }

    // MARK: - Sleep Need

    /// Calculates sleep need in hours.
    /// - Parameters:
    ///   - baselineSleep: User's preferred baseline sleep (default 8h)
    ///   - last7DaysNeedVsActual: Array of (need, actual) for last 7 nights
    ///   - yesterdayStrain: Yesterday's strain score 0–21
    static func calculateSleepNeed(
        baselineSleep: Double = 8.0,
        last7DaysNeedVsActual: [(need: Double, actual: Double)],
        yesterdayStrain: Double
    ) -> Double {
        // Sleep debt: average nightly deficit, capped at 2h per night
        let debtPerNight: Double
        if last7DaysNeedVsActual.isEmpty {
            debtPerNight = 0
        } else {
            let totalDebt = last7DaysNeedVsActual.reduce(0.0) { acc, pair in
                acc + min(max(0, pair.need - pair.actual), 2.0)
            }
            debtPerNight = totalDebt / Double(last7DaysNeedVsActual.count)
        }

        let strainFactor = (yesterdayStrain / 21.0) * 1.0  // up to +1h

        let need = baselineSleep + debtPerNight + strainFactor
        return BaselineCalculator.clamp(need, min: 7.0, max: 12.0)
    }

    // MARK: - Sleep Debt

    /// Total sleep debt from the last N days (hours).
    static func computeSleepDebt(needVsActual: [(need: Double, actual: Double)]) -> Double {
        needVsActual.reduce(0.0) { acc, pair in acc + max(0, pair.need - pair.actual) }
    }
}
