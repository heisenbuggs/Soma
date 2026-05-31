import Foundation

struct BaselineCalculator {

    static let minDaysRequired = 7

    /// Computes HRV baseline from historical data (mean of daily averages).
    /// Returns nil if fewer than minDaysRequired samples.
    static func computeHRVBaseline(from history: [(Date, Double)]) -> Double? {
        guard !history.isEmpty else { return nil }
        let values = history.map { $0.1 }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Computes RHR baseline from historical data.
    static func computeRHRBaseline(from history: [(Date, Double)]) -> Double? {
        guard !history.isEmpty else { return nil }
        let values = history.map { $0.1 }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Computes a generic rolling mean baseline from any (Date, Double) history.
    /// Used for sleeping HR, sleeping HRV, sleep duration, etc.
    static func computeBaseline(from history: [(Date, Double)]) -> Double? {
        guard !history.isEmpty else { return nil }
        let values = history.map { $0.1 }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Derives (Date, Double) history from stored DailyMetrics using the given key path.
    static func extractHistory(
        from metrics: [DailyMetrics],
        _ keyPath: KeyPath<DailyMetrics, Double?>
    ) -> [(Date, Double)] {
        metrics.compactMap { m in
            guard let v = m[keyPath: keyPath] else { return nil }
            return (m.date, v)
        }
    }

    /// Whether there is enough data for a reliable baseline.
    static func hasEnoughData(_ history: [(Date, Double)]) -> Bool {
        history.count >= minDaysRequired
    }

    /// Normalize a ratio (e.g., HRV ratio) clamped to [low, high] → 0–100
    /// Supports inverted ranges where high < low (e.g. sleeping HR where lower is better)
    static func normalizeRatio(_ value: Double, low: Double, high: Double) -> Double {
        guard low != high else { return 50 } // Default to neutral if range is invalid
        
        if high > low {
            // Standard range: low maps to 0, high maps to 100
            return clamp((value - low) / (high - low) * 100, min: 0, max: 100)
        } else {
            // Inverted range: low maps to 100, high maps to 0 (lower is better)
            return clamp((low - value) / (low - high) * 100, min: 0, max: 100)
        }
    }

    static func clamp(_ value: Double, min minVal: Double, max maxVal: Double) -> Double {
        Swift.max(minVal, Swift.min(maxVal, value))
    }

    // MARK: - Log-domain HRV statistics

    /// Recency-weighted geometric baseline + log-domain spread of an HRV series.
    ///
    /// HRV (rMSSD/SDNN) is log-normally distributed, so taking a raw arithmetic mean
    /// or a raw ratio distorts both tails. Industry HRV tools (Elite HRV, HRV4Training,
    /// Oura) work in ln space. This computes:
    ///   - `meanLn`: an exponentially-weighted moving average of ln(value), so recent
    ///               days count more than three-week-old ones (a flat mean lets stale
    ///               data anchor the baseline as hard as last night).
    ///   - `sdLn`:   the standard deviation of ln(value) — the person's *own* day-to-day
    ///               variability, which is what a meaningful deviation should be measured
    ///               against (some people are naturally more variable than others).
    ///
    /// `values` must be ordered oldest → newest. Returns nil with fewer than
    /// `minDaysRequired` positive samples.
    static func logHRVStats(values: [Double]) -> (meanLn: Double, sdLn: Double)? {
        let positives = values.filter { $0 > 0 }
        guard positives.count >= minDaysRequired else { return nil }
        let lns = positives.map { log($0) }

        // EWMA of ln, alpha tuned for ~7-day responsiveness.
        let alpha = 2.0 / (7.0 + 1.0)   // 0.25
        var ewma = lns[0]
        for i in 1..<lns.count {
            ewma = alpha * lns[i] + (1 - alpha) * ewma
        }

        // Sample standard deviation of ln across the window.
        let mean = lns.reduce(0, +) / Double(lns.count)
        let variance = lns.reduce(0) { $0 + Foundation.pow($1 - mean, 2) } / Double(lns.count - 1)
        let sd = Foundation.sqrt(variance)
        return (meanLn: ewma, sdLn: sd)
    }

    /// Z-score of today's HRV against the personal log-domain baseline.
    /// Positive = HRV above personal norm (better recovery). Nil if the series is too
    /// short or has no spread.
    static func hrvZScore(today: Double, values: [Double]) -> Double? {
        guard today > 0, let stats = logHRVStats(values: values), stats.sdLn > 0 else { return nil }
        return (Foundation.log(today) - stats.meanLn) / stats.sdLn
    }
}
