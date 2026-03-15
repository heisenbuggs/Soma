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

    /// Schedules (or replaces) the daily recovery notification immediately.
    /// Called once per day after scores are freshly computed.
    func scheduleRecoveryNotification(metrics: DailyMetrics) {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized else { return }

            let content = UNMutableNotificationContent()
            content.sound = .default
            let (title, body) = Self.content(for: metrics)
            content.title = title
            content.body  = body

            // Fire after a short delay so it appears as a morning notification
            // (delivered after sleep processing, not on a fixed schedule)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
            let request = UNNotificationRequest(
                identifier: recoveryNotificationID,
                content: content,
                trigger: trigger
            )

            center.removePendingNotificationRequests(withIdentifiers: [recoveryNotificationID])
            try? await center.add(request)
        }
    }

    func cancelPendingNotifications() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [recoveryNotificationID])
    }

    // MARK: - Content Generation

    static func content(for metrics: DailyMetrics) -> (title: String, body: String) {
        let score = Int(metrics.recoveryScore.rounded())
        let name  = UserDefaults.standard.string(forKey: "userFirstName") ?? ""
        let prefix = name.isEmpty ? "" : "\(name), "

        switch metrics.recoveryScore {
        case 67...100:
            let sleepNote = metrics.sleepScore >= 75 ? "Sleep and HRV are strong." : ""
            return (
                "Recovery \(score) — Great day to train",
                ("\(prefix)Resting HR was low and recovery looks solid. " + sleepNote).trimmingCharacters(in: .whitespaces)
            )
        case 34..<67:
            let hrNote: String
            if let sHR = metrics.sleepingHR, sHR > 0 {
                hrNote = String(format: "Sleeping HR was %.0f bpm.", sHR)
            } else {
                hrNote = ""
            }
            return (
                "Recovery \(score) — Moderate day",
                ("\(prefix)Keep today's effort balanced. " + hrNote).trimmingCharacters(in: .whitespaces)
            )
        default:
            let sleepNote: String
            if let hours = metrics.sleepDurationHours {
                sleepNote = String(format: "Sleep was %.1fh.", hours)
            } else {
                sleepNote = ""
            }
            return (
                "Recovery \(score) — Rest day recommended",
                ("\(prefix)HRV dipped overnight. Prioritise recovery. " + sleepNote).trimmingCharacters(in: .whitespaces)
            )
        }
    }
}
