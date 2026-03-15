import Foundation

@MainActor
final class DayDetailViewModel: ObservableObject {

    let metrics: DailyMetrics
    let checkIn: DailyCheckIn?

    init(metrics: DailyMetrics, checkInStore: CheckInStore) {
        self.metrics  = metrics
        self.checkIn  = checkInStore.load(for: metrics.date)
    }

    // MARK: - Formatted Values

    var formattedDayOfWeek: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: metrics.date)
    }

    var formattedMonthDay: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM d"
        return f.string(from: metrics.date)
    }

    var sleepSummaryLine: String {
        guard let hours = metrics.sleepDurationHours else { return "No sleep data recorded" }
        let need = metrics.sleepNeedHours ?? 8.0
        let debt = max(0, need - hours)
        if debt < 0.1 {
            return String(format: "%.1fh slept — sleep need met", hours)
        }
        return String(format: "%.1fh slept — %.1fh short of %.1fh need", hours, debt, need)
    }

    var sleepInterruptionLine: String? {
        guard let n = metrics.sleepInterruptions, n > 0 else { return nil }
        return "\(n) interruption\(n == 1 ? "" : "s") during sleep"
    }

    var hasWorkoutBreakdown: Bool {
        metrics.workoutStrain != nil || metrics.incidentalStrain != nil
    }

    var workoutStrainText: String {
        guard let ws = metrics.workoutStrain else { return "--" }
        return String(format: "%.1f", ws)
    }

    var incidentalStrainText: String {
        guard let is_ = metrics.incidentalStrain else { return "--" }
        return String(format: "%.1f", is_)
    }

    var checkInStressLabel: String {
        guard let ci = checkIn else { return "Not logged" }
        switch ci.stressLevel {
        case 1: return "Very Low"
        case 2: return "Low"
        case 3: return "Moderate"
        case 4: return "High"
        default: return "Very High"
        }
    }

    // MARK: - Coaching Insight

    var coachingInsight: String {
        if metrics.recoveryScore < 34 {
            if let hrv = metrics.hrvAverage, hrv < 30 {
                return "HRV dropped to \(Int(hrv)) ms. Prioritise sleep and avoid hard training."
            }
            return "Low recovery. Light movement and extra sleep are recommended."
        }
        if let n = metrics.sleepInterruptions, n >= 3 {
            return "Sleep was interrupted \(n) times. A consistent bedtime and limiting fluids before bed can help."
        }
        if let sHR = metrics.sleepingHR, let rhr = metrics.restingHR, sHR > rhr + 5 {
            return String(format: "Sleeping HR (%.0f bpm) was elevated vs resting HR (%.0f bpm). Alcohol or late meals may be a factor.", sHR, rhr)
        }
        if metrics.strainScore > 18 {
            return "Strain was very high. Ensure tonight's sleep is sufficient to recover."
        }
        if metrics.recoveryScore >= 67 {
            return "You were well recovered. A good day to have pushed intensity."
        }
        return "Moderate recovery. Steady training was appropriate — avoid consecutive hard days."
    }
}
