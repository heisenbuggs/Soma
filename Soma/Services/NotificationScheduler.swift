import Foundation
@preconcurrency import UserNotifications

// MARK: - NotificationScheduler

@MainActor
final class NotificationScheduler {

    static let shared = NotificationScheduler()

    private let recoveryNotificationID = "com.soma.daily-recovery"

    private init() {}

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - Schedule

    /// Schedules (or replaces) the daily recovery notification for 8 AM.
    ///
    /// Using a calendar trigger means:
    /// - If metrics are computed before 8 AM (e.g. background refresh), the
    ///   notification fires that same morning at 8 AM.
    /// - If computed after 8 AM (e.g. afternoon app open), it fires at 8 AM
    ///   the next morning — still useful for planning the following day.
    ///
    /// Called once per day after scores are freshly computed.
    func scheduleRecoveryNotification(metrics: DailyMetrics, guidance: DailyTrainingGuidance? = nil) {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized else { return }

            let content = UNMutableNotificationContent()
            content.sound = .default
            let (title, body) = Self.content(for: metrics, guidance: guidance)
            content.title = title
            content.body  = body

            // Fire at the next occurrence of 8:00 AM.
            // UNCalendarNotificationTrigger automatically picks today if it's
            // before 8 AM, or tomorrow if it's already past 8 AM.
            var components = DateComponents()
            components.hour   = 8
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: recoveryNotificationID,
                content: content,
                trigger: trigger
            )

            center.removePendingNotificationRequests(withIdentifiers: [recoveryNotificationID])
            try? await center.add(request)

            // Persist to notification history (one record per calendar day).
            NotificationStore.shared.save(
                NotificationRecord(title: title, body: body)
            )
        }
    }

    func cancelPendingNotifications() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [recoveryNotificationID])
    }

    // MARK: - Content Generation

    static func content(for metrics: DailyMetrics, guidance: DailyTrainingGuidance? = nil) -> (title: String, body: String) {
        let score = Int(metrics.recoveryScore.rounded())
        let name  = UserDefaults.standard.string(forKey: "userFirstName") ?? ""
        let prefix = name.isEmpty ? "" : "\(name), "

        // Build training suffix from guidance if available
        let trainingSuffix: String = {
            guard let g = guidance else { return "" }
            let range = "\(g.targetStrainMin)–\(g.targetStrainMax)"
            return " Recommended: \(g.activityLevel.title) (strain \(range))."
        }()

        switch metrics.recoveryScore {
        case 67...100:
            let sleepNote = metrics.sleepScore >= 75 ? "Sleep and HRV are strong." : ""
            return (
                "Recovery \(score) — \(guidance?.activityLevel.shortTitle ?? "Great day to train")",
                ("\(prefix)Resting HR was low and recovery looks solid. " + sleepNote + trainingSuffix).trimmingCharacters(in: .whitespaces)
            )
        case 34..<67:
            let hrNote: String
            if let sHR = metrics.sleepingHR, sHR > 0 {
                hrNote = String(format: "Sleeping HR was %.0f bpm.", sHR)
            } else {
                hrNote = ""
            }
            return (
                "Recovery \(score) — \(guidance?.activityLevel.shortTitle ?? "Moderate day")",
                ("\(prefix)Keep today's effort balanced. " + hrNote + trainingSuffix).trimmingCharacters(in: .whitespaces)
            )
        default:
            let sleepNote: String
            if let hours = metrics.sleepDurationHours {
                sleepNote = String(format: "Sleep was %.1fh.", hours)
            } else {
                sleepNote = ""
            }
            return (
                "Recovery \(score) — \(guidance?.activityLevel.shortTitle ?? "Rest day recommended")",
                ("\(prefix)HRV dipped overnight. Prioritise recovery. " + sleepNote + trainingSuffix).trimmingCharacters(in: .whitespaces)
            )
        }
    }
}
