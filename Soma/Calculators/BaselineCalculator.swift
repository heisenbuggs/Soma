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
}
