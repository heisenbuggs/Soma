import Foundation

/// Computes a sleep consistency score (0–100) from the standard deviation of
/// sleep start and wake times across recent nights.
///
/// Scientific basis: sleep timing regularity (consistent bedtime + wake time) is
/// independently associated with better metabolic health and circadian alignment.
/// A standard deviation of 0 minutes = perfect consistency (score 100).
/// A standard deviation of 120 minutes = no consistency (score 0).
struct SleepConsistencyCalculator {

    /// - Parameters:
    ///   - startTimes: Array of sleep start timestamps (nils are ignored).
    ///   - endTimes:   Array of sleep end (wake) timestamps (nils are ignored).
    /// - Returns: Consistency score 0–100, or nil if fewer than 3 valid nights exist.
    static func calculate(startTimes: [Date?], endTimes: [Date?]) -> Double? {
        let startMins = startTimes.compactMap { minutesFromMidnight($0, isEvening: true) }
        let endMins   = endTimes.compactMap   { minutesFromMidnight($0, isEvening: false) }

        guard startMins.count >= 3, endMins.count >= 3 else { return nil }

        let startStddev = stddev(startMins)
        let endStddev   = stddev(endMins)
        let avgStddev   = (startStddev + endStddev) / 2.0

        // Normalize: 0 min stddev → 100, 120 min stddev → 0
        let maxStddev = 120.0
        return BaselineCalculator.clamp((1.0 - avgStddev / maxStddev) * 100, min: 0, max: 100)
    }

    // MARK: - Private

    /// Converts a Date to minutes-from-midnight, handling sleep-start times that
    /// fall in the evening (hour ≥ 18) as negative offsets before midnight so that
    /// e.g. 11 PM (-60) and 1 AM (+60) yield a sensible mean and stddev.
    private static func minutesFromMidnight(_ date: Date?, isEvening: Bool) -> Double? {
        guard let date else { return nil }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour   = comps.hour   ?? 0
        let minute = comps.minute ?? 0
        var mins   = Double(hour * 60 + minute)
        if isEvening && hour >= 18 {
            mins -= 1440  // treat as "before midnight" so 11 PM = -60, midnight = 0
        }
        return mins
    }

    private static func stddev(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean     = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
        return sqrt(variance)
    }
}
