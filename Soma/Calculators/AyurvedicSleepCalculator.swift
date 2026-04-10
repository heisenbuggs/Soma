import Foundation

struct AyurvedicSleepCalculator {

    // MARK: - Scoring Window

    struct ScoringWindow {
        let start: Date
        let end: Date
        let pointsPerHour: Double
        let label: String
    }

    /// Normalization denominator: represents an ideal circadian-aligned night (≈10 PM – 6 AM).
    /// Raw points for that window: 2h×2 + 3h×1 + 3h×0.5 = 8.5, so 8 pts is a realistic ceiling.
    static let maxRawPoints: Double = 8.0

    // MARK: - Window Construction

    /// Builds the four scoring windows for the night anchored to `eveningDate`.
    /// `eveningDate` = the calendar day on which the night began (e.g. March 15 for
    ///                 a sleep starting at 10:30 PM March 15 and ending March 16).
    ///
    /// Edge case: sleep before 9 PM still earns the first-window rate (2 pts/hr).
    /// Edge case: points stop accumulating after 8 AM (last window end).
    static func buildWindows(eveningDate: Date) -> [ScoringWindow] {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: eveningDate)

        // 9 PM anchor (same evening)
        comps.hour = 21; comps.minute = 0; comps.second = 0
        let ninePM   = cal.date(from: comps)!

        // Extend first window back to 5 PM so early sleepers still get 2 pts/hr
        let fivePM   = ninePM.addingTimeInterval(-4 * 3600)
        let midnight = ninePM.addingTimeInterval(3 * 3600)   // +3 h
        let threeAM  = midnight.addingTimeInterval(3 * 3600) // +3 h
        let sixAM    = threeAM.addingTimeInterval(3 * 3600)  // +3 h
        let eightAM  = sixAM.addingTimeInterval(2 * 3600)    // +2 h

        return [
            ScoringWindow(start: fivePM,   end: midnight, pointsPerHour: 2.0,  label: "Before 12 AM"),
            ScoringWindow(start: midnight, end: threeAM,  pointsPerHour: 1.0,  label: "12–3 AM"),
            ScoringWindow(start: threeAM,  end: sixAM,    pointsPerHour: 0.5,  label: "3–6 AM"),
            ScoringWindow(start: sixAM,    end: eightAM,  pointsPerHour: 0.25, label: "6–8 AM"),
        ]
    }

    // MARK: - Raw Points

    static func rawPoints(start: Date, end: Date, windows: [ScoringWindow]) -> Double {
        windows.reduce(0.0) { acc, w in
            let overlapStart = max(start, w.start)
            let overlapEnd   = min(end,   w.end)
            guard overlapEnd > overlapStart else { return acc }
            let hours = overlapEnd.timeIntervalSince(overlapStart) / 3600.0
            return acc + hours * w.pointsPerHour
        }
    }

    // MARK: - Final Score (0–10)

    /// Calculates the Ayurvedic Sleep Points score (0.0–10.0, 1 decimal place).
    /// Pass multiple intervals for fragmented sleep; each segment is scored separately.
    static func calculate(
        intervals: [(start: Date, end: Date)],
        eveningDate: Date
    ) -> Double {
        guard !intervals.isEmpty else { return 0 }
        let windows = buildWindows(eveningDate: eveningDate)
        let raw = intervals.reduce(0.0) { acc, interval in
            acc + rawPoints(start: interval.start, end: interval.end, windows: windows)
        }
        let normalized = min(10.0, (raw / maxRawPoints) * 10.0)
        return (normalized * 10).rounded() / 10
    }

    // MARK: - Per-Window Breakdown (for detail view)

    struct WindowBreakdown {
        let label: String
        let hoursSlept: Double
        let pointsPerHour: Double
        let earned: Double
    }

    static func breakdown(
        start: Date,
        end: Date,
        eveningDate: Date
    ) -> [WindowBreakdown] {
        buildWindows(eveningDate: eveningDate).map { w in
            let overlapStart = max(start, w.start)
            let overlapEnd   = min(end,   w.end)
            let hours = overlapEnd > overlapStart
                ? overlapEnd.timeIntervalSince(overlapStart) / 3600.0
                : 0
            return WindowBreakdown(
                label: w.label,
                hoursSlept: hours,
                pointsPerHour: w.pointsPerHour,
                earned: hours * w.pointsPerHour
            )
        }
    }

    // MARK: - Guidance

    static func guidanceText(for score: Double) -> String {
        switch score {
        case 8...10: return "Excellent circadian sleep"
        case 6..<8:  return "Good alignment"
        case 4..<6:  return "Late sleep pattern"
        default:     return "Very late sleep pattern"
        }
    }

    static func guidanceHex(for score: Double) -> String {
        switch score {
        case 8...10: return "00C853"
        case 6..<8:  return "FFD600"
        case 4..<6:  return "FFD600"
        default:     return "FF1744"
        }
    }

    // MARK: - Improvement Tip

    static func improvementTip(
        sleepStart: Date,
        sleepEnd: Date,
        currentScore: Double,
        eveningDate: Date
    ) -> String? {
        guard currentScore < 8.0 else { return nil }
        let windows = buildWindows(eveningDate: eveningDate)

        // Check if completely missing the prime window (before midnight)
        let midnight = windows[0].end
        if sleepStart >= midnight {
            return "Most of your sleep is occurring after midnight. Try going to bed before midnight for better recovery."
        }

        // Check if missing the 9–11 PM prime hours
        let elevenPM = windows[0].start.addingTimeInterval(6 * 3600) // 5 PM + 6 h = 11 PM
        if sleepStart > elevenPM {
            // Try shifting earlier to find a meaningful improvement
            for minutes in [30, 45, 60, 90] {
                let shiftedStart = sleepStart.addingTimeInterval(-Double(minutes) * 60)
                let shiftedEnd   = sleepEnd.addingTimeInterval(-Double(minutes) * 60)
                let newRaw   = rawPoints(start: shiftedStart, end: shiftedEnd, windows: windows)
                let newScore = min(10.0, (newRaw / maxRawPoints) * 10.0)
                let pct = ((newScore - currentScore) / max(currentScore, 0.1)) * 100
                if pct >= 8 {
                    return "Going to bed \(minutes) minutes earlier could boost your sleep points by \(Int(pct.rounded()))%."
                }
            }
            return "You are missing the highest recovery window (9–11 PM)."
        }

        return "Going to bed a little earlier would improve your circadian alignment."
    }
}
