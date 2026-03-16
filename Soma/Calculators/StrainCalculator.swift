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
        let strain: Double  // raw StrainLoad for this workout
    }

    struct WorkoutStrainResult {
        let total: Double            // total StrainLoad for the day
        let workoutStrain: Double    // StrainLoad from workout windows
        let incidentalStrain: Double // StrainLoad from non-workout windows
        let details: [WorkoutStrainDetail]
    }
}

struct StrainCalculator {

    // MARK: - Calibration Constants

    /// Estimated daily capacity used during the first 7-day calibration period.
    static let estimatedCalibrationCapacity: Double = 350

    /// Minimum days of history required before leaving calibration.
    static let calibrationDays: Int = 7

    /// Number of days used for the rolling personal capacity average.
    static let rollingCapacityDays: Int = 14

    // MARK: - StrainLoad

    /// Computes raw StrainLoad from timed HR samples.
    ///
    /// StrainLoad = Σ (minutesInZone × zoneWeight)
    ///
    /// Zones are based on MaxHR percentage thresholds:
    ///   Zone 1 (50–60%): weight 1
    ///   Zone 2 (60–70%): weight 2
    ///   Zone 3 (70–80%): weight 3
    ///   Zone 4 (80–90%): weight 4
    ///   Zone 5 (90–100%): weight 5
    static func calculate(samples: [(Date, Double)], maxHR: Double) -> Double {
        guard samples.count > 1 else { return 0 }

        var zoneMinutes: [HeartRateZone: Double] = [:]
        HeartRateZone.allCases.forEach { zoneMinutes[$0] = 0 }

        for i in 1..<samples.count {
            let (prevTime, prevHR) = samples[i - 1]
            let (currTime, currHR) = samples[i]
            let minutes = currTime.timeIntervalSince(prevTime) / 60.0
            guard minutes > 0 else { continue }

            let avgHR = (prevHR + currHR) / 2.0
            let zone = HeartRateZone.zone(for: avgHR, maxHR: maxHR)
            zoneMinutes[zone, default: 0] += minutes
        }

        return zoneMinutes.reduce(0.0) { acc, entry in
            acc + entry.value * entry.key.weight
        }
    }

    // MARK: - Strain Score

    /// Converts a raw StrainLoad to a 0–100 score relative to personal capacity.
    ///
    /// StrainScore = (StrainLoad / Capacity) × 100, clamped to 100.
    static func score(load: Double, capacity: Double) -> Double {
        guard capacity > 0 else { return 0 }
        return min(100.0, (load / capacity) * 100.0)
    }

    // MARK: - Capacity Model

    /// Returns the personal daily capacity to use for scoring.
    ///
    /// - During the first 7 days (calibration): returns `estimatedCalibrationCapacity` (350).
    /// - After 7+ days: returns the rolling 14-day average of StrainLoad values.
    ///
    /// - Parameter loadHistory: Historical StrainLoad values ordered oldest→newest.
    static func capacity(fromLoads loadHistory: [Double]) -> Double {
        guard loadHistory.count >= calibrationDays else {
            return estimatedCalibrationCapacity
        }
        let recent = loadHistory.suffix(rollingCapacityDays)
        guard !recent.isEmpty else { return estimatedCalibrationCapacity }
        return recent.reduce(0, +) / Double(recent.count)
    }

    /// Returns true while the calibration period is still active (< 7 days of data).
    static func isCalibrating(loadHistory: [Double]) -> Bool {
        loadHistory.count < calibrationDays
    }

    // MARK: - Max HR Estimation

    /// Calculates max HR using the standard age-based formula: 220 − age.
    static func estimatedMaxHR(age: Int) -> Double {
        Double(220 - age)
    }

    // MARK: - Workout-Aware Strain

    /// Partitions HR samples into workout vs incidental windows and returns
    /// a breakdown of total, workout, and incidental StrainLoad.
    static func calculateWorkoutAware(
        workoutIntervals: [WorkoutInterval],
        allSamples: [(Date, Double)],
        maxHR: Double
    ) -> WorkoutStrainResult {
        guard !allSamples.isEmpty else {
            return WorkoutStrainResult(total: 0, workoutStrain: 0, incidentalStrain: 0, details: [])
        }

        let total = calculate(samples: allSamples, maxHR: maxHR)

        guard !workoutIntervals.isEmpty else {
            return WorkoutStrainResult(total: total, workoutStrain: 0, incidentalStrain: total, details: [])
        }

        func isInWorkout(_ date: Date) -> Bool {
            workoutIntervals.contains { date >= $0.start && date <= $0.end }
        }

        let workoutSamples    = allSamples.filter { isInWorkout($0.0) }
        let incidentalSamples = allSamples.filter { !isInWorkout($0.0) }

        let wLoad = calculate(samples: workoutSamples,    maxHR: maxHR)
        let iLoad = calculate(samples: incidentalSamples, maxHR: maxHR)

        let details: [WorkoutStrainDetail] = workoutIntervals.compactMap { interval in
            let samples = allSamples.filter { $0.0 >= interval.start && $0.0 <= interval.end }
            let load = calculate(samples: samples, maxHR: maxHR)
            guard load > 0.5 else { return nil }
            return WorkoutStrainDetail(activityName: interval.activityName, strain: load)
        }

        return WorkoutStrainResult(total: total,
                                   workoutStrain: wLoad,
                                   incidentalStrain: iLoad,
                                   details: details)
    }
}
