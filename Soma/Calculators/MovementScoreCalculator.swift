import Foundation

/// Combines Apple Stand hours, walking heart rate efficiency, and step count
/// into a single 0–100 movement quality score.
///
/// Components:
///   - Stand Score (40%): stand hours / 12 × 100  (12h = full marks)
///   - Step Score  (35%): steps / 8,000 × 100      (8k steps = full marks)
///   - Walking HR Efficiency (25%): lower walking HR → better cardiovascular fitness.
///     Mapped from 60–120 bpm inverted to 0–100.
///
/// Each component defaults to 0 when the underlying data is unavailable.
struct MovementScoreCalculator {

    private static let standWeight   = 0.40
    private static let stepWeight    = 0.35
    private static let walkingWeight = 0.25

    /// Step goal for full marks. 8,000 — not the marketing-derived 10,000. Large
    /// cohort studies (e.g. Lancet Public Health 2022) show all-cause mortality
    /// benefit saturates around 7,000–8,000 steps, and lower still for older adults.
    static let stepGoal: Double = 8_000

    /// Stand-hours goal for full marks (matches Apple's Stand ring).
    static let standGoalHours: Double = 12

    static func calculate(
        standHours: Int?,
        stepCount: Double?,
        walkingHRAverage: Double?
    ) -> Double? {
        // Renormalize weights across only the components that have data, so a
        // missing signal (e.g. Apple Watch often lacks a walking-HR average) does
        // not silently cap the score below 100. Previously a perfect steps + stand
        // day with no walking HR was stuck at 75/100.
        var weightedSum = 0.0
        var totalWeight = 0.0

        if let h = standHours {
            weightedSum += standWeight * standComponent(standHours: h)
            totalWeight += standWeight
        }
        if let steps = stepCount {
            weightedSum += stepWeight * stepComponent(stepCount: steps)
            totalWeight += stepWeight
        }
        if let bpm = walkingHRAverage {
            weightedSum += walkingWeight * walkingHRComponent(walkingHRAverage: bpm)
            totalWeight += walkingWeight
        }

        // No real data point → no score.
        guard totalWeight > 0 else { return nil }

        let score = weightedSum / totalWeight
        return min(100, max(0, score))
    }

    // MARK: - Components

    private static func standComponent(standHours: Int) -> Double {
        min(100.0, Double(standHours) / standGoalHours * 100.0)
    }

    private static func stepComponent(stepCount: Double) -> Double {
        min(100.0, stepCount / stepGoal * 100.0)
    }

    /// Lower walking HR = better cardiac efficiency.
    /// Maps bpm 60→100 down to score 100→0, clipped beyond that range.
    private static func walkingHRComponent(walkingHRAverage: Double) -> Double {
        let clamped = min(120, max(60, walkingHRAverage))
        return (120 - clamped) / 60.0 * 100.0
    }
}
