import Foundation

struct StrainCalculator {

    static let maxExpectedLoad: Double = 1500  // calibration constant

    /// Calculates strain score 0–21 from timed HR samples.
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

        // Logarithmic scale
        let strain = 21.0 * log(1.0 + load) / log(1.0 + Self.maxExpectedLoad)
        return BaselineCalculator.clamp(strain, min: 0, max: 21)
    }

    /// Calculate max HR using age-based formula.
    static func estimatedMaxHR(age: Int) -> Double {
        Double(220 - age)
    }
}
