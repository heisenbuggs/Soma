import Foundation

@MainActor
final class DayDetailViewModel: ObservableObject {

    let metrics: DailyMetrics
    let checkIn: DailyCheckIn?
    let notificationRecord: NotificationRecord?

    init(metrics: DailyMetrics, checkInStore: CheckInStore) {
        self.metrics = metrics
        self.checkIn = checkInStore.load(for: metrics.date)
        let cal = Calendar.current
        let day = cal.startOfDay(for: metrics.date)
        self.notificationRecord = NotificationStore.shared.loadAll()
            .first { cal.startOfDay(for: $0.timestamp) == day }
    }

    // MARK: - Formatted Date

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

    // MARK: - Sleep

    var sleepSummaryLine: String {
        guard let hours = metrics.sleepDurationHours else { return "No sleep data recorded" }
        let need = metrics.sleepNeedHours ?? 8.0
        let debt = max(0, need - hours)
        let sleptStr = Self.formatHours(hours)
        if debt < 0.1 {
            return "\(sleptStr) slept — sleep need met"
        }
        let debtStr = Self.formatHours(debt)
        let needStr = Self.formatHours(need)
        return "\(sleptStr) slept — \(debtStr) short of \(needStr) need"
    }

    var sleepInterruptionLine: String? {
        guard let n = metrics.sleepInterruptions, n > 0 else { return nil }
        return "\(n) interruption\(n == 1 ? "" : "s") during sleep"
    }

    var sleepStartFormatted: String? {
        metrics.sleepStartTime.map { timeStr($0) }
    }

    var sleepEndFormatted: String? {
        metrics.sleepEndTime.map { timeStr($0) }
    }

    var deepSleepFormatted: String? {
        metrics.deepSleepMinutes.map { Self.formatHours($0 / 60.0) }
    }

    var remSleepFormatted: String? {
        metrics.remSleepMinutes.map { Self.formatHours($0 / 60.0) }
    }

    var coreSleepFormatted: String? {
        metrics.coreSleepMinutes.map { Self.formatHours($0 / 60.0) }
    }

    var napFormatted: String? {
        guard let nap = metrics.napDurationMinutes, nap > 0 else { return nil }
        let mins = Int(nap.rounded())
        return "\(mins) min"
    }

    var sleepConsistencyFormatted: String? {
        metrics.sleepConsistencyScore.map { String(format: "%.0f / 100", $0) }
    }

    // MARK: - Strain / Activity

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

    var stepsFormatted: String? {
        guard let steps = metrics.stepCount else { return nil }
        return steps >= 1000
            ? String(format: "%.1fk", steps / 1000)
            : "\(Int(steps))"
    }

    var activeCalFormatted: String? {
        metrics.activeCalories.map { "\(Int($0)) kcal" }
    }

    var standHoursFormatted: String? {
        metrics.standHours.map { "\(Int($0)) h" }
    }

    var mindfulMinutesFormatted: String? {
        guard let m = metrics.mindfulMinutes, m > 0 else { return nil }
        return "\(Int(m)) min"
    }

    // MARK: - Vitals

    var hrvFormatted: String? {
        metrics.hrvAverage.map { String(format: "%.0f ms", $0) }
    }

    var restingHRFormatted: String? {
        metrics.restingHR.map { String(format: "%.0f bpm", $0) }
    }

    var sleepingHRFormatted: String? {
        metrics.sleepingHR.map { String(format: "%.0f bpm", $0) }
    }

    var sleepingHRVFormatted: String? {
        metrics.sleepingHRV.map { String(format: "%.0f ms", $0) }
    }

    var spo2Formatted: String? {
        metrics.bloodOxygen.map { String(format: "%.1f%%", $0) }
    }

    var respiratoryRateFormatted: String? {
        metrics.respiratoryRate.map { String(format: "%.1f br/min", $0) }
    }

    var walkingHRFormatted: String? {
        metrics.walkingHRAverage.map { String(format: "%.0f bpm", $0) }
    }

    var wristTempFormatted: String? {
        guard let dev = metrics.wristTempDeviation else { return nil }
        let sign = dev >= 0 ? "+" : ""
        return String(format: "\(sign)%.2f °C", dev)
    }

    var eveningStressFormatted: String? {
        metrics.eveningStressScore.map { String(format: "%.0f / 100", $0) }
    }

    var vo2TrendFormatted: String? {
        guard let t = metrics.vo2MaxTrend else { return nil }
        let sign = t >= 0 ? "+" : ""
        return String(format: "\(sign)%.2f", t)
    }

    // MARK: - Check-In

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

    // MARK: - Physiological Insights (generated from that day's metrics)

    var physiologicalInsights: [String] {
        var tips: [String] = []

        // Recovery
        if metrics.recoveryScore < 34 {
            if let hrv = metrics.hrvAverage, hrv < 30 {
                tips.append("HRV dropped to \(Int(hrv)) ms — very low autonomic recovery.")
            } else {
                tips.append("Low recovery. Light movement and extra sleep were recommended.")
            }
        } else if metrics.recoveryScore >= 80 {
            tips.append("Excellent recovery — good day to have trained hard.")
        }

        // Sleeping HR vs RHR
        if let sHR = metrics.sleepingHR, let rhr = metrics.restingHR, sHR > rhr + 5 {
            tips.append(String(format: "Sleeping HR (%.0f bpm) was elevated vs resting HR (%.0f bpm). Could indicate alcohol or late meal.", sHR, rhr))
        }

        // Sleeping HRV low
        if let sHRV = metrics.sleepingHRV, sHRV < 30 {
            tips.append(String(format: "Sleeping HRV was low at %.0f ms — autonomic recovery was suppressed overnight.", sHRV))
        }

        // Sleep interruptions
        if let n = metrics.sleepInterruptions, n >= 3 {
            tips.append("Sleep was fragmented with \(n) interruptions — poor sleep architecture.")
        }

        // Deep sleep
        if let deep = metrics.deepSleepMinutes {
            let total = (metrics.sleepDurationHours ?? 0) * 60
            if total > 0 {
                let ratio = deep / total
                if ratio < 0.12 {
                    tips.append(String(format: "Deep sleep was only %.0f min (%.0f%% of total) — below the 20%% target.", deep, ratio * 100))
                } else if ratio >= 0.20 {
                    tips.append(String(format: "Deep sleep was strong at %.0f min (%.0f%% of total).", deep, ratio * 100))
                }
            }
        }

        // REM sleep
        if let rem = metrics.remSleepMinutes {
            let total = (metrics.sleepDurationHours ?? 0) * 60
            if total > 0 {
                let ratio = rem / total
                if ratio < 0.15 {
                    tips.append(String(format: "REM sleep was low at %.0f min (%.0f%%) — may affect memory and mood.", rem, ratio * 100))
                }
            }
        }

        // Sleep consistency
        if let sc = metrics.sleepConsistencyScore, sc < 45 {
            tips.append("Sleep schedule was irregular on this day (consistency score \(Int(sc))).")
        }

        // SpO2
        if let spo2 = metrics.bloodOxygen, spo2 < 95 {
            tips.append(String(format: "Blood oxygen was low at %.1f%% — high-intensity training would not have been advisable.", spo2))
        }

        // Walking HR elevated
        if let whr = metrics.walkingHRAverage, whr > 95 {
            tips.append(String(format: "Walking HR was elevated at %.0f bpm — cardiovascular system was under load.", whr))
        }

        // Evening stress
        if let es = metrics.eveningStressScore, es > 55 {
            tips.append(String(format: "Pre-sleep autonomic stress was high (%.0f). This tends to suppress overnight HRV.", es))
        }

        // Wrist temp
        if let dev = metrics.wristTempDeviation, dev > 0.5 {
            tips.append(String(format: "Wrist temperature was +%.2f °C above baseline — possible physiological stress or early illness signal.", dev))
        }

        // VO2 trend
        if let vo2 = metrics.vo2MaxTrend, vo2 < -0.5 {
            tips.append("Aerobic fitness was trending down on this day.")
        }

        // Nap
        if let nap = metrics.napDurationMinutes {
            if nap > 80 {
                tips.append(String(format: "Nap was long at %.0f min — may have fragmented night sleep.", nap))
            } else if nap >= 30 && nap <= 60 {
                tips.append(String(format: "Power nap of %.0f min — ideal for cognitive recovery.", nap))
            }
        }

        // High strain
        if metrics.strainScore > 80 {
            tips.append(String(format: "Very high strain day (%.0f). Recovery was critical the following night.", metrics.strainScore))
        }

        return Array(tips.prefix(6))
    }

    // MARK: - Coaching Insight (fallback single insight)

    var coachingInsight: String {
        if let first = physiologicalInsights.first { return first }
        if metrics.recoveryScore >= 67 {
            return "You were well recovered. A good day to have pushed intensity."
        }
        return "Moderate recovery. Steady training was appropriate — avoid consecutive hard days."
    }

    // MARK: - Helpers

    private func timeStr(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }

    private static func formatHours(_ h: Double) -> String {
        let total = Int((h * 60).rounded())
        let hrs = total / 60
        let mins = total % 60
        if hrs == 0 { return "\(mins)m" }
        if mins == 0 { return "\(hrs)h" }
        return "\(hrs)h \(mins)m"
    }
}
