import Foundation

/// Estimates menstrual-cycle phase and a recovery compensation so that the *normal*
/// physiology of the luteal phase isn't misread as poor recovery.
///
/// Why this exists: in the luteal phase (after ovulation, before the next period),
/// progesterone rises — which elevates resting heart rate (~2–5 bpm), raises core/
/// wrist temperature (~0.3–0.5°C), and suppresses HRV. Those are exactly the inputs
/// the recovery score keys on, so without cycle awareness the app tells a menstruating
/// user they are "under-recovered" for roughly a week every cycle, when in fact their
/// body is behaving completely normally. This calculator lets recovery compensate for
/// that expected, benign shift.
///
/// All of this is opt-in by data: with no period history, every method is a no-op.
///
/// ⚠️ NOT CURRENTLY WIRED. The app presently targets men only, so this is intentionally
/// disconnected from the recovery pipeline and the app does not request menstrual
/// HealthKit permissions. The logic + tests are kept ready for when the app supports
/// women. To re-enable, search for "FUTURE (women)" in DashboardViewModel and
/// HealthKitManager.
struct MenstrualCycleCalculator {

    enum Phase: String {
        case menstrual    // bleeding (≈ days 1–5)
        case follicular   // after bleeding, before ovulation
        case ovulatory    // ovulation window (±1 day)
        case luteal       // after ovulation, before next period
    }

    struct CycleInfo: Equatable {
        let phase: Phase
        let cycleDay: Int     // 1-based day within the current cycle
        let cycleLength: Int  // estimated cycle length in days
    }

    /// Fallback cycle length when there isn't enough history to estimate one.
    static let defaultCycleLength = 28
    /// The luteal phase is roughly constant (~14 days) across cycle lengths; ovulation
    /// timing varies in the follicular phase, not the luteal one.
    static let lutealLength = 14
    /// Largest recovery add-back (points) applied at peak late-luteal physiology.
    static let maxRecoveryAdjustment = 6.0

    /// Estimates the current cycle phase from recent period-start dates.
    ///
    /// - Parameters:
    ///   - periodStartDates: dates flagged as the first day of menstruation (any order).
    ///   - asOf: the day to evaluate (defaults to today).
    /// - Returns: the estimated cycle info, or nil when there's no usable/recent history.
    static func cycleInfo(periodStartDates: [Date], asOf: Date) -> CycleInfo? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: asOf)
        let starts = periodStartDates
            .map { cal.startOfDay(for: $0) }
            .filter { $0 <= today }
            .sorted()
        guard let lastStart = starts.last else { return nil }

        // Estimate cycle length from the mean of recent, physiologically-plausible gaps.
        let gaps = zip(starts, starts.dropFirst()).compactMap { a, b -> Int? in
            let d = cal.dateComponents([.day], from: a, to: b).day ?? 0
            return (15...45).contains(d) ? d : nil
        }
        let cycleLength = gaps.isEmpty
            ? defaultCycleLength
            : Int((Double(gaps.reduce(0, +)) / Double(gaps.count)).rounded())

        let daysSince = cal.dateComponents([.day], from: lastStart, to: today).day ?? 0
        // If the last logged period is more than ~1.5 cycles old, the data is stale —
        // don't guess a phase from it.
        guard daysSince >= 0, daysSince <= cycleLength + 15 else { return nil }

        let cycleDay = daysSince + 1   // 1-based
        let ovulationDay = max(1, cycleLength - lutealLength)

        let phase: Phase
        switch cycleDay {
        case ...5:
            phase = .menstrual
        case (ovulationDay - 1)...(ovulationDay + 1):
            phase = .ovulatory
        case ..<(ovulationDay - 1):
            phase = .follicular
        default:
            phase = .luteal
        }
        return CycleInfo(phase: phase, cycleDay: cycleDay, cycleLength: cycleLength)
    }

    /// Recovery compensation (points to add back) that offsets the normal late-luteal
    /// HRV suppression / RHR elevation. Ramps up over the ~5 days before the expected
    /// period and is zero in every other phase, so it never inflates recovery outside
    /// the window where cyclic physiology is genuinely depressing the raw signals.
    static func recoveryAdjustment(for info: CycleInfo?) -> Double {
        guard let info, info.phase == .luteal else { return 0 }
        let daysUntilPeriod = info.cycleLength - info.cycleDay
        guard daysUntilPeriod >= 0, daysUntilPeriod <= 5 else { return 0 }
        // 0 days out → full adjustment; 5 days out → 1/6 of it (linear ramp).
        let proximity = Double(6 - daysUntilPeriod) / 6.0
        return maxRecoveryAdjustment * proximity
    }
}
