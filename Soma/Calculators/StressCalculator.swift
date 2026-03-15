import Foundation

struct StressCalculator {

    /// Calculates stress score 0–100.
    /// - Parameters:
    ///   - daytimeHRV: Average HRV during daytime (8AM–8PM) in ms
    ///   - daytimeAvgHR: Average heart rate during daytime in bpm
    ///   - hrvBaseline: Rolling HRV baseline
    ///   - rhrBaseline: Rolling resting HR baseline
    static func calculate(
        daytimeHRV: Double?,
        daytimeAvgHR: Double?,
        hrvBaseline: Double?,
        rhrBaseline: Double?
    ) -> Double {
        let hrvSuppression = computeHRVSuppression(daytimeHRV: daytimeHRV, baseline: hrvBaseline)
        let hrElevation = computeHRElevation(daytimeAvgHR: daytimeAvgHR, rhrBaseline: rhrBaseline)

        let stress = (0.6 * hrvSuppression + 0.4 * hrElevation) * 100
        return BaselineCalculator.clamp(stress, min: 0, max: 100)
    }

    // MARK: - Private

    private static func computeHRVSuppression(daytimeHRV: Double?, baseline: Double?) -> Double {
        guard let hrv = daytimeHRV, let base = baseline, base > 0 else { return 0 }
        return max(0, 1.0 - hrv / base)
    }

    private static func computeHRElevation(daytimeAvgHR: Double?, rhrBaseline: Double?) -> Double {
        guard let hr = daytimeAvgHR, let base = rhrBaseline, base > 0 else { return 0 }
        return max(0, (hr - base) / base)
    }
}

// MARK: - Daytime HR Filter

extension StressCalculator {
    /// Filters heart rate samples to daytime window (8AM – 8PM).
    static func filterDaytime(_ samples: [(Date, Double)], on date: Date) -> [(Date, Double)] {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        guard let eightAM = cal.date(bySettingHour: 8, minute: 0, second: 0, of: startOfDay),
              let eightPM = cal.date(bySettingHour: 20, minute: 0, second: 0, of: startOfDay)
        else { return [] }
        return samples.filter { $0.0 >= eightAM && $0.0 <= eightPM }
    }

    static func average(_ samples: [(Date, Double)]) -> Double? {
        guard !samples.isEmpty else { return nil }
        let sum = samples.reduce(0.0) { $0 + $1.1 }
        return sum / Double(samples.count)
    }
}
