import Foundation

struct RecoveryInput {
    var todayHRV: Double?
    var hrvBaseline: Double?
    var todayRestingHR: Double?
    var rhrBaseline: Double?
    var sleepScore: Double        // 0–100
    var yesterdayStrain: Double   // 0–21
}

struct RecoveryCalculator {

    /// Calculates recovery score 0–100.
    static func calculate(input: RecoveryInput) -> Double {
        let hrv = computeHRVComponent(todayHRV: input.todayHRV, baseline: input.hrvBaseline)
        let rhr = computeRHRComponent(todayRHR: input.todayRestingHR, baseline: input.rhrBaseline)
        let sleep = clamp(input.sleepScore, 0, 100)
        let strainRecovery = clamp((1.0 - input.yesterdayStrain / 21.0), 0, 1) * 100

        let recovery = 0.40 * hrv + 0.25 * rhr + 0.25 * sleep + 0.10 * strainRecovery
        return clamp(recovery, 0, 100)
    }

    // MARK: - Training Recommendation

    static func trainingRecommendation(
        recovery: Double,
        last3DayStrainAvg: Double,
        sleepDebtHours: Double
    ) -> String {
        var base: String
        switch recovery {
        case 67...100:
            base = "Peak day — push intensity. Your body is recovered."
        case 50..<67:
            base = "Moderate day — steady training is fine."
        case 34..<50:
            base = "Easy day — stick to low intensity."
        default:
            base = "Rest day — prioritize recovery and sleep."
        }

        var suffixes: [String] = []
        if last3DayStrainAvg > 15 {
            suffixes.append("Consider a deload — high cumulative strain.")
        }
        if sleepDebtHours > 2 {
            suffixes.append("Sleep debt is elevated — aim for extra sleep tonight.")
        }

        if suffixes.isEmpty {
            return base
        }
        return base + " " + suffixes.joined(separator: " ")
    }

    // MARK: - Private

    private static func computeHRVComponent(todayHRV: Double?, baseline: Double?) -> Double {
        guard let hrv = todayHRV, let base = baseline, base > 0 else { return 50 }
        let ratio = hrv / base
        // clamp ratio [0.5, 1.5] → [0, 100]
        return BaselineCalculator.normalizeRatio(ratio, low: 0.5, high: 1.5)
    }

    private static func computeRHRComponent(todayRHR: Double?, baseline: Double?) -> Double {
        guard let rhr = todayRHR, let base = baseline else { return 50 }
        let deviation = base - rhr // positive = lower HR = better
        // clamp deviation [-10, 10] → [0, 100]
        return BaselineCalculator.normalizeRatio(deviation, low: -10, high: 10)
    }

    private static func clamp(_ value: Double, _ min: Double, _ max: Double) -> Double {
        BaselineCalculator.clamp(value, min: min, max: max)
    }
}
