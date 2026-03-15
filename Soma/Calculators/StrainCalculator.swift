import Foundation

// MARK: - Workout-Aware Types

extension StrainCalculator {

    struct WorkoutInterval {
        let start: Date
        let end: Date
        let activityName: String
    }

    struct WorkoutStrainDetail: Identifiable {
        let id = UUID()
        let activityName: String
        let strain: Double
    }

    struct WorkoutStrainResult {
        let total: Double
        let workoutStrain: Double
        let incidentalStrain: Double
        let details: [WorkoutStrainDetail]
    }
}

struct StrainCalculator {

    static let maxExpectedLoad: Double = 1500  // calibration constant

    /// Calculates strain score 0–100 from timed HR samples.
    /// - Parameters:
    ///   - samples: Array of (timestamp, heartRate bpm) for the day
    ///   - restingHR: Resting heart rate in bpm
    ///   - maxHR: Maximum heart rate in bpm
    static func calculate(samples: [(Date, Double)], restingHR: Double, maxHR: Double) -> Double {
        guard samples.count > 1 else { return 0 }

        var zoneMinutes: [HeartRateZone: Double] = [:]
        HeartRateZone.allCases.forEach { zoneMinutes[$0] = 0 }

        // Approximate time in each zone using trapezoidal intervals
        for i in 1..<samples.count {
            let (prevTime, prevHR) = samples[i - 1]
            let (currTime, currHR) = samples[i]
            let minutes = currTime.timeIntervalSince(prevTime) / 60.0

            // Use average HR for this interval
            let avgHR = (prevHR + currHR) / 2.0
            let zone = HeartRateZone.zone(for: avgHR, restingHR: restingHR, maxHR: maxHR)
            zoneMinutes[zone, default: 0] += minutes
        }

        // Weighted load
        let load = zoneMinutes.reduce(0.0) { acc, entry in
            acc + entry.value * entry.key.weight
        }

        // Logarithmic scale 0–100
        let strain = 100.0 * log(1.0 + load) / log(1.0 + Self.maxExpectedLoad)
        return BaselineCalculator.clamp(strain, min: 0, max: 100)
    }

    /// Calculate max HR using age-based formula.
    static func estimatedMaxHR(age: Int) -> Double {
        Double(220 - age)
    }

    // MARK: - Workout-Aware Strain

    /// Partitions HR samples into workout vs incidental windows and returns
    /// a breakdown of total, workout, and incidental strain.
    static func calculateWorkoutAware(
        workoutIntervals: [WorkoutInterval],
        allSamples: [(Date, Double)],
        restingHR: Double,
        maxHR: Double
    ) -> WorkoutStrainResult {
        guard !allSamples.isEmpty else {
            return WorkoutStrainResult(total: 0, workoutStrain: 0, incidentalStrain: 0, details: [])
        }

        let total = calculate(samples: allSamples, restingHR: restingHR, maxHR: maxHR)

        guard !workoutIntervals.isEmpty else {
            return WorkoutStrainResult(total: total, workoutStrain: 0, incidentalStrain: total, details: [])
        }

        // Partition samples
        func isInWorkout(_ date: Date) -> Bool {
            workoutIntervals.contains { date >= $0.start && date <= $0.end }
        }

        let workoutSamples    = allSamples.filter { isInWorkout($0.0) }
        let incidentalSamples = allSamples.filter { !isInWorkout($0.0) }

        let wStrain = calculate(samples: workoutSamples,    restingHR: restingHR, maxHR: maxHR)
        let iStrain = calculate(samples: incidentalSamples, restingHR: restingHR, maxHR: maxHR)

        // Per-workout breakdown
        let details: [WorkoutStrainDetail] = workoutIntervals.compactMap { interval in
            let samples = allSamples.filter { $0.0 >= interval.start && $0.0 <= interval.end }
            let strain  = calculate(samples: samples, restingHR: restingHR, maxHR: maxHR)
            guard strain > 0.05 else { return nil }
            return WorkoutStrainDetail(activityName: interval.activityName, strain: strain)
        }

        return WorkoutStrainResult(total: total,
                                   workoutStrain: wStrain,
                                   incidentalStrain: iStrain,
                                   details: details)
    }
}
