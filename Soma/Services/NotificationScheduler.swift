import Foundation
@preconcurrency import UserNotifications

// MARK: - NotificationScheduler

@MainActor
final class NotificationScheduler {

    static let shared = NotificationScheduler()

    private let recoveryNotificationID  = "com.soma.daily-recovery"
    private let bedtimeReminderID       = "com.soma.bedtime-reminder"
    private let checkinReminderID       = "com.soma.checkin-reminder"
    private let weeklyNarrativeID       = "com.soma.weekly-narrative"

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

    /// Schedules (or replaces) the daily recovery notification at the user's preferred time.
    ///
    /// Using a calendar trigger means:
    /// - If metrics are computed before the notification time, it fires that same morning.
    /// - If computed after the notification time, it fires the next morning.
    ///
    /// Called once per day after scores are freshly computed.
    func scheduleRecoveryNotification(metrics: DailyMetrics, guidance: DailyTrainingGuidance? = nil, settings: UserSettings = UserSettings()) {
        Task {
            let center = UNUserNotificationCenter.current()
            let notificationSettings = await center.notificationSettings()
            guard notificationSettings.authorizationStatus == .authorized,
                  settings.notificationsEnabled else { return }

            let content = UNMutableNotificationContent()
            content.sound = .default
            let (title, body) = Self.content(for: metrics, guidance: guidance)
            content.title = title
            content.body  = body

            // Fire at the user's preferred time
            var components = DateComponents()
            components.hour   = settings.recoveryNotificationHour
            components.minute = settings.recoveryNotificationMinute
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

    /// Schedules a bedtime reminder based on user's wake time and sleep goal
    func scheduleBedtimeReminder(settings: UserSettings = UserSettings()) {
        Task {
            let center = UNUserNotificationCenter.current()
            let notificationSettings = await center.notificationSettings()
            guard notificationSettings.authorizationStatus == .authorized,
                  settings.bedtimeReminderEnabled else { 
                center.removePendingNotificationRequests(withIdentifiers: [bedtimeReminderID])
                return 
            }

            // Calculate bedtime based on tomorrow's wake time and sleep goal
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            let tomorrowWeekday = Calendar.current.component(.weekday, from: tomorrow)
            let tomorrowWakeTime = settings.wakeTimeDate(for: tomorrowWeekday)
            
            let sleepDuration = settings.sleepGoalHours * 3600 // in seconds
            let reminderOffset = TimeInterval(settings.bedtimeReminderMinutesBefore * 60)
            
            let bedtime = tomorrowWakeTime.addingTimeInterval(-sleepDuration)
            let reminderTime = bedtime.addingTimeInterval(-reminderOffset)
            
            let content = UNMutableNotificationContent()
            content.sound = .default
            content.title = "Bedtime Reminder"
            
            let minutesUntilBed = settings.bedtimeReminderMinutesBefore
            let bedtimeFormatted = DateFormatter.localizedString(from: bedtime, dateStyle: .none, timeStyle: .short)
            
            if minutesUntilBed == 30 {
                content.body = "Time to start winding down. Bedtime is at \(bedtimeFormatted) for optimal recovery."
            } else {
                content.body = "\(minutesUntilBed) minutes until bedtime at \(bedtimeFormatted). Time to start your wind-down routine."
            }

            let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

            let request = UNNotificationRequest(
                identifier: bedtimeReminderID,
                content: content,
                trigger: trigger
            )

            center.removePendingNotificationRequests(withIdentifiers: [bedtimeReminderID])
            try? await center.add(request)
        }
    }
    
    /// Schedules a daily check-in reminder at the user's preferred time
    func scheduleCheckinReminder(settings: UserSettings = UserSettings()) {
        Task {
            let center = UNUserNotificationCenter.current()
            let notificationSettings = await center.notificationSettings()
            guard notificationSettings.authorizationStatus == .authorized,
                  settings.checkinReminderEnabled else { 
                center.removePendingNotificationRequests(withIdentifiers: [checkinReminderID])
                return 
            }

            let content = UNMutableNotificationContent()
            content.sound = .default
            content.title = "Daily Check-In"
            content.body = "How was yesterday? Quick check-in to improve your health insights."

            var components = DateComponents()
            components.hour = settings.checkinReminderHour
            components.minute = settings.checkinReminderMinute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

            let request = UNNotificationRequest(
                identifier: checkinReminderID,
                content: content,
                trigger: trigger
            )

            center.removePendingNotificationRequests(withIdentifiers: [checkinReminderID])
            try? await center.add(request)
        }
    }
    
    /// Updates all notification schedules based on current settings
    func updateAllSchedules(settings: UserSettings = UserSettings()) {
        scheduleBedtimeReminder(settings: settings)
        scheduleCheckinReminder(settings: settings)
    }

    // MARK: - Weekly Narrative (3.4)

    /// Schedules the Monday-morning weekly health narrative notification.
    /// Fires at the same time as the daily recovery notification on Mondays.
    func scheduleWeeklyNarrative(summary: WeeklySummaryEngine.WeeklySummary, settings: UserSettings = UserSettings()) {
        Task {
            let center = UNUserNotificationCenter.current()
            let notifSettings = await center.notificationSettings()
            guard notifSettings.authorizationStatus == .authorized,
                  settings.notificationsEnabled else { return }

            let content = UNMutableNotificationContent()
            content.sound = .default
            content.title = "Your Week in Review"
            content.body  = summary.teaser

            // Fire Monday at the user's recovery notification time.
            var components = DateComponents()
            components.weekday = 2   // Monday
            components.hour    = settings.recoveryNotificationHour
            components.minute  = settings.recoveryNotificationMinute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

            let request = UNNotificationRequest(
                identifier: weeklyNarrativeID,
                content: content,
                trigger: trigger
            )

            center.removePendingNotificationRequests(withIdentifiers: [weeklyNarrativeID])
            try? await center.add(request)

            NotificationStore.shared.save(
                NotificationRecord(title: content.title, body: content.body)
            )
        }
    }

    func cancelPendingNotifications() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [
                recoveryNotificationID,
                bedtimeReminderID,
                checkinReminderID,
                weeklyNarrativeID
            ])
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
