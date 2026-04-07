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
        /// Zone minutes within this workout window. Key = zone, value = minutes.
        let zoneMinutes: [HeartRateZone: Double]
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
    static let estimatedCalibrationCapacity: Double = 500

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
    ///   Zone 1 (50–60%): weight 0  — recovery intensity, no strain contribution
    ///   Zone 2 (60–70%): weight 1
    ///   Zone 3 (70–80%): weight 2
    ///   Zone 4 (80–90%): weight 3
    ///   Zone 5 (90–100%): weight 4
    ///
    /// Gap capping: HealthKit HR samples are sparse outside workouts (every 5–10 min).
    /// Each inter-sample interval is capped at 1 minute so a long gap between passive
    /// readings is never misinterpreted as continuous cardiovascular effort.
    ///
    /// Passive HR filter: samples whose average HR is below 50% of maxHR represent
    /// resting physiology and are skipped entirely.
    static func calculate(samples: [(Date, Double)], maxHR: Double) -> Double {
        guard samples.count > 1 else { return 0 }

        var zoneMinutes: [HeartRateZone: Double] = [:]
        HeartRateZone.allCases.forEach { zoneMinutes[$0] = 0 }

        for i in 1..<samples.count {
            let (prevTime, prevHR) = samples[i - 1]
            let (currTime, currHR) = samples[i]
            let rawMinutes = currTime.timeIntervalSince(prevTime) / 60.0
            guard rawMinutes > 0 else { continue }

            // Cap interval to 1 minute — prevents sparse passive readings from
            // inflating StrainLoad when the Watch samples infrequently.
            let minutes = min(rawMinutes, 1.0)

            let avgHR = (prevHR + currHR) / 2.0

            // Skip resting/passive heart rate — below 50% maxHR is not effort.
            guard avgHR >= 0.5 * maxHR else { continue }

            let zone = HeartRateZone.zone(for: avgHR, maxHR: maxHR)
            zoneMinutes[zone, default: 0] += minutes
        }

        #if DEBUG
        let load = zoneMinutes.reduce(0.0) { $0 + $1.value * $1.key.weight }
        print("[StrainCalculator] Zone minutes — Z1: \(String(format: "%.1f", zoneMinutes[.zone1] ?? 0)) Z2: \(String(format: "%.1f", zoneMinutes[.zone2] ?? 0)) Z3: \(String(format: "%.1f", zoneMinutes[.zone3] ?? 0)) Z4: \(String(format: "%.1f", zoneMinutes[.zone4] ?? 0)) Z5: \(String(format: "%.1f", zoneMinutes[.zone5] ?? 0)) | StrainLoad: \(String(format: "%.1f", load))")
        return load
        #else
        return zoneMinutes.reduce(0.0) { $0 + $1.value * $1.key.weight }
        #endif
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
    /// - During the first 7 days (calibration): returns `estimatedCalibrationCapacity` (500).
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

    /// Partitions StrainLoad across workout vs incidental windows by tagging each
    /// consecutive HR sample pair, preserving the full timeline continuity.
    ///
    /// Why not filter samples then call calculate()?
    /// Filtering breaks time continuity: two samples that were far apart in the
    /// original timeline end up adjacent after filtering, producing an inflated
    /// interval duration. Instead, we iterate all pairs in order and tag each one.
    static func calculateWorkoutAware(
        workoutIntervals: [WorkoutInterval],
        allSamples: [(Date, Double)],
        maxHR: Double
    ) -> WorkoutStrainResult {
        guard !allSamples.isEmpty else {
            return WorkoutStrainResult(total: 0, workoutStrain: 0, incidentalStrain: 0, details: [])
        }

        guard !workoutIntervals.isEmpty else {
            let total = calculate(samples: allSamples, maxHR: maxHR)
            return WorkoutStrainResult(total: total, workoutStrain: 0, incidentalStrain: total, details: [])
        }

        var totalLoad = 0.0
        var wLoad     = 0.0
        var iLoad     = 0.0
        var detailLoads = [Int: Double]()                     // workoutIntervals index → load
        var detailZones = [Int: [HeartRateZone: Double]]()    // workoutIntervals index → zone minutes

        for i in 1..<allSamples.count {
            let (prevTime, prevHR) = allSamples[i - 1]
            let (currTime, currHR) = allSamples[i]
            let rawMinutes = currTime.timeIntervalSince(prevTime) / 60.0
            guard rawMinutes > 0 else { continue }

            let minutes = min(rawMinutes, 1.0)
            let avgHR   = (prevHR + currHR) / 2.0
            guard avgHR >= 0.5 * maxHR else { continue }

            let zone          = HeartRateZone.zone(for: avgHR, maxHR: maxHR)
            let intervalLoad  = minutes * zone.weight
            guard intervalLoad > 0 else { continue }

            totalLoad += intervalLoad

            // Tag this pair by its midpoint's membership in a workout window.
            let midpoint = prevTime.addingTimeInterval(currTime.timeIntervalSince(prevTime) / 2)
            if let idx = workoutIntervals.firstIndex(where: { midpoint >= $0.start && midpoint <= $0.end }) {
                wLoad += intervalLoad
                detailLoads[idx, default: 0] += intervalLoad
                detailZones[idx, default: [:]][zone, default: 0] += minutes
            } else {
                iLoad += intervalLoad
            }
        }

        let details: [WorkoutStrainDetail] = workoutIntervals.enumerated().compactMap { idx, interval in
            let load = detailLoads[idx] ?? 0
            guard load > 0.5 else { return nil }
            return WorkoutStrainDetail(
                activityName: interval.activityName,
                strain: load,
                zoneMinutes: detailZones[idx] ?? [:]
            )
        }

        return WorkoutStrainResult(total: totalLoad,
                                   workoutStrain: wLoad,
                                   incidentalStrain: iLoad,
                                   details: details)
    }
}
