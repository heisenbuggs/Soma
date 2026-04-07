import Foundation

/// Combines Apple Stand hours, walking heart rate efficiency, and step count
/// into a single 0–100 movement quality score.
///
/// Components:
///   - Stand Score (40%): stand hours / 12 × 100  (12h = full marks)
///   - Step Score  (35%): steps / 10,000 × 100     (10k steps = full marks)
///   - Walking HR Efficiency (25%): lower walking HR → better cardiovascular fitness.
///     Mapped from 60–120 bpm inverted to 0–100.
///
/// Each component defaults to 0 when the underlying data is unavailable.
struct MovementScoreCalculator {

    static func calculate(
        standHours: Int?,
        stepCount: Double?,
        walkingHRAverage: Double?
    ) -> Double? {
        // Need at least one real data point to return a score
        guard standHours != nil || stepCount != nil || walkingHRAverage != nil else { return nil }

        let standScore   = standComponent(standHours: standHours)
        let stepScore    = stepComponent(stepCount: stepCount)
        let walkingScore = walkingHRComponent(walkingHRAverage: walkingHRAverage)

        // Weighted sum — scale weights based on which components have data
        let score = 0.40 * standScore + 0.35 * stepScore + 0.25 * walkingScore
        return min(100, max(0, score))
    }

    // MARK: - Components

    private static func standComponent(standHours: Int?) -> Double {
        guard let h = standHours else { return 0 }
        return min(100.0, Double(h) / 12.0 * 100.0)
    }

    private static func stepComponent(stepCount: Double?) -> Double {
        guard let steps = stepCount else { return 0 }
        return min(100.0, steps / 10_000.0 * 100.0)
    }

    /// Lower walking HR = better cardiac efficiency.
    /// Maps bpm 60→100 down to score 100→0, clipped beyond that range.
    private static func walkingHRComponent(walkingHRAverage: Double?) -> Double {
        guard let bpm = walkingHRAverage else { return 0 }
        let clamped = min(120, max(60, bpm))
        return (120 - clamped) / 60.0 * 100.0
    }
}
