import Foundation
@preconcurrency import UserNotifications

// MARK: - NotificationScheduler

@MainActor
final class NotificationScheduler {

    static let shared = NotificationScheduler()

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

    /// Schedules two daily notifications after scores are computed:
    ///   1. Score summary — readiness + key scores + training recommendation.
    ///   2. Insights alert — top high-priority physiological issues (fires 2 min later).
    ///
    /// Using calendar triggers means both fire the next morning if computed after the
    /// notification time, or that same morning if computed before.
    func scheduleRecoveryNotification(metrics: DailyMetrics, guidance: DailyTrainingGuidance? = nil, settings: UserSettings = UserSettings()) {
        Task {
            let center = UNUserNotificationCenter.current()
            let notificationSettings = await center.notificationSettings()
            guard notificationSettings.authorizationStatus == .authorized,
                  settings.notificationsEnabled else { return }

            // ── Notification 1: Score summary ─────────────────────────────
            let scoreContent = UNMutableNotificationContent()
            scoreContent.sound = .default
            let (scoreTitle, scoreBody) = Self.scoreContent(for: metrics, guidance: guidance)
            scoreContent.title = scoreTitle
            scoreContent.body  = scoreBody

            var scoreComponents = DateComponents()
            scoreComponents.hour   = settings.recoveryNotificationHour
            scoreComponents.minute = settings.recoveryNotificationMinute
            let scoreTrigger = UNCalendarNotificationTrigger(dateMatching: scoreComponents, repeats: false)

            center.removePendingNotificationRequests(withIdentifiers: [NotificationIDs.dailyRecovery])
            try? await center.add(UNNotificationRequest(
                identifier: NotificationIDs.dailyRecovery,
                content: scoreContent,
                trigger: scoreTrigger
            ))

            NotificationStore.shared.save(NotificationRecord(title: scoreTitle, body: scoreBody))

            // ── Notification 2: Top insights ──────────────────────────────
            let topInsights = Self.topInsights(for: metrics)
            guard !topInsights.isEmpty else { return }

            let insightsContent = UNMutableNotificationContent()
            insightsContent.sound = .default
            let insightsTitle = "Today's Health Alerts"
            let insightsBody  = topInsights.prefix(3).joined(separator: " · ")
            insightsContent.title = insightsTitle
            insightsContent.body  = insightsBody

            // Fire 2 minutes after the score notification so both are distinct
            var insightsComponents = DateComponents()
            insightsComponents.hour   = settings.recoveryNotificationHour
            insightsComponents.minute = (settings.recoveryNotificationMinute + 2) % 60
            // If wrapping past the hour, bump the hour
            if settings.recoveryNotificationMinute + 2 >= 60 {
                insightsComponents.hour = (settings.recoveryNotificationHour + 1) % 24
            }
            let insightsTrigger = UNCalendarNotificationTrigger(dateMatching: insightsComponents, repeats: false)

            center.removePendingNotificationRequests(withIdentifiers: [NotificationIDs.dailyInsights])
            try? await center.add(UNNotificationRequest(
                identifier: NotificationIDs.dailyInsights,
                content: insightsContent,
                trigger: insightsTrigger
            ))
        }
    }

    /// Schedules a bedtime reminder based on user's wake time and sleep goal
    func scheduleBedtimeReminder(settings: UserSettings = UserSettings()) {
        Task {
            let center = UNUserNotificationCenter.current()
            let notificationSettings = await center.notificationSettings()
            guard notificationSettings.authorizationStatus == .authorized,
                  settings.bedtimeReminderEnabled else { 
                center.removePendingNotificationRequests(withIdentifiers: [NotificationIDs.bedtimeReminder])
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
                identifier: NotificationIDs.bedtimeReminder,
                content: content,
                trigger: trigger
            )

            center.removePendingNotificationRequests(withIdentifiers: [NotificationIDs.bedtimeReminder])
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
                center.removePendingNotificationRequests(withIdentifiers: [NotificationIDs.checkinReminder])
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
                identifier: NotificationIDs.checkinReminder,
                content: content,
                trigger: trigger
            )

            center.removePendingNotificationRequests(withIdentifiers: [NotificationIDs.checkinReminder])
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
                identifier: NotificationIDs.weeklyNarrative,
                content: content,
                trigger: trigger
            )

            center.removePendingNotificationRequests(withIdentifiers: [NotificationIDs.weeklyNarrative])
            try? await center.add(request)

            NotificationStore.shared.save(
                NotificationRecord(title: content.title, body: content.body)
            )
        }
    }

    func cancelPendingNotifications() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [
                NotificationIDs.dailyRecovery,
                NotificationIDs.dailyInsights,
                NotificationIDs.bedtimeReminder,
                NotificationIDs.checkinReminder,
                NotificationIDs.weeklyNarrative
            ])
    }

    func cancelPendingInsightsNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [NotificationIDs.dailyInsights])
    }

    // MARK: - Score Content

    static func scoreContent(for metrics: DailyMetrics, guidance: DailyTrainingGuidance? = nil) -> (title: String, body: String) {
        let recoveryScore = Int(metrics.recoveryScore.rounded())
        let sleepScore    = Int(metrics.sleepScore.rounded())
        let readiness     = metrics.readinessScore.map { Int($0.rounded()) }
        let name          = UserDefaults.standard.string(forKey: UserDefaultsKeys.userFirstName) ?? ""
        let prefix        = name.isEmpty ? "" : "\(name), "
        let recoveryLabel = ColorState.recovery(score: metrics.recoveryScore).label

        var parts: [String] = []
        parts.append("\(prefix)Recovery \(recoveryScore) (\(recoveryLabel)).")
        parts.append("Sleep score: \(sleepScore).")
        if let r = readiness {
            parts.append("Readiness: \(r).")
        }
        if let g = guidance {
            parts.append("\(g.activityLevel.title) recommended (strain \(g.targetStrainMin)–\(g.targetStrainMax)).")
        }

        let title = "Readiness \(readiness ?? recoveryScore) — \(recoveryLabel)"
        return (title, parts.joined(separator: " "))
    }

    // MARK: - Top Insights Generator

    /// Returns a list of the most important single-line health alerts based on today's metrics.
    /// Prioritises the most actionable issues (HRV, RHR, sleep stages, stress, SPO2).
    static func topInsights(for metrics: DailyMetrics) -> [String] {
        var alerts: [(priority: Int, text: String)] = []

        // SPO2 (highest priority — health risk)
        if let spo2 = metrics.bloodOxygen, spo2 < 95 {
            alerts.append((0, String(format: "SpO₂ low at %.1f%% — avoid intense exercise", spo2)))
        }

        // Wrist temperature (illness risk)
        if let temp = metrics.wristTempDeviation, temp > 0.5 {
            alerts.append((0, String(format: "Wrist temp +%.1f°C above baseline — possible illness signal", temp)))
        }

        // HRV below baseline
        if let hrv = metrics.sleepingHRV ?? metrics.hrvAverage {
            if hrv < 30 {
                alerts.append((1, String(format: "HRV very low at %.0f ms — rest recommended today", hrv)))
            }
        }

        // Elevated RHR (no baseline needed — absolute threshold)
        if let rhr = metrics.restingHR, rhr > 70 {
            alerts.append((1, String(format: "Resting HR elevated at %.0f bpm", rhr)))
        }

        // Deep sleep critically low
        if let deep = metrics.deepSleepMinutes, deep < 40 {
            alerts.append((1, String(format: "Deep sleep only %.0f min — physical recovery was limited", deep)))
        }

        // Sleep deficit
        if let actual = metrics.sleepDurationHours, let need = metrics.sleepNeedHours, actual < need - 1 {
            let debt = need - actual
            alerts.append((2, String(format: "%.1fh sleep debt — aim for an earlier bedtime tonight", debt)))
        }

        // REM low
        if let rem = metrics.remSleepMinutes, rem < 60 {
            alerts.append((2, String(format: "REM sleep low at %.0f min — mood and memory may be affected", rem)))
        }

        // Recovery in red
        if metrics.recoveryScore < 34 {
            alerts.append((2, "Recovery in the red — prioritise rest and hydration today"))
        }

        // High pre-sleep stress
        if let es = metrics.eveningStressScore, es > 60 {
            alerts.append((2, String(format: "High pre-sleep stress (%.0f) — try breathwork before bed tonight", es)))
        }

        // Respiratory rate elevated
        if let rr = metrics.respiratoryRate, rr > 20, (metrics.workoutMinutes ?? 0) == 0 {
            alerts.append((2, String(format: "Respiratory rate elevated at %.1f br/min at rest", rr)))
        }

        return alerts
            .sorted { $0.priority < $1.priority }
            .map { $0.text }
    }

    // MARK: - Legacy alias (kept for compatibility)

    static func content(for metrics: DailyMetrics, guidance: DailyTrainingGuidance? = nil) -> (title: String, body: String) {
        scoreContent(for: metrics, guidance: guidance)
    }
}
