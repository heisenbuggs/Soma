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
        rhrBaseline: Double?,
        mindfulMinutes: Double? = nil
    ) -> Double {
        let hrvSuppression = computeHRVSuppression(daytimeHRV: daytimeHRV, baseline: hrvBaseline)
        let hrElevation = computeHRElevation(daytimeAvgHR: daytimeAvgHR, rhrBaseline: rhrBaseline)

        var stress = (0.6 * hrvSuppression + 0.4 * hrElevation) * 100

        // Mindful minutes bonus: 10–60 min maps linearly to up to -5 pts.
        // Encourages meditation by creating a visible feedback loop.
        if let mins = mindfulMinutes, mins >= 10 {
            let bonus = min((mins - 10) / 50.0, 1.0) * 5.0  // 0→5 across 10→60 min
            stress -= bonus
        }

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

    /// Filters heart rate samples to the evening pre-sleep window (8PM – 11PM).
    /// Used to detect elevated autonomic arousal before bed, which can impair sleep quality.
    static func filterEvening(_ samples: [(Date, Double)], on date: Date) -> [(Date, Double)] {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        guard let eightPM  = cal.date(bySettingHour: 20, minute: 0, second: 0, of: startOfDay),
              let elevenPM = cal.date(bySettingHour: 23, minute: 0, second: 0, of: startOfDay)
        else { return [] }
        return samples.filter { $0.0 >= eightPM && $0.0 <= elevenPM }
    }

    /// Computes an evening stress score (0–100) based solely on HR elevation above the resting baseline.
    /// Used for the 8PM–11PM window where separate HRV data is not available.
    /// Returns nil when there are no evening HR samples.
    static func calculateEveningStress(
        eveningAvgHR: Double?,
        rhrBaseline: Double?
    ) -> Double? {
        guard let hr = eveningAvgHR else { return nil }
        let elevation = computeHRElevation(daytimeAvgHR: hr, rhrBaseline: rhrBaseline)
        return BaselineCalculator.clamp(elevation * 100, min: 0, max: 100)
    }

    static func average(_ samples: [(Date, Double)]) -> Double? {
        guard !samples.isEmpty else { return nil }
        let sum = samples.reduce(0.0) { $0 + $1.1 }
        return sum / Double(samples.count)
    }
}
