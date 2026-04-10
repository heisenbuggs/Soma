import Foundation

// MARK: - UserDefaults & AppStorage Keys
// Use these constants everywhere instead of raw string literals.

enum UserDefaultsKeys {
    // User profile
    static let userFirstName           = "userFirstName"
    static let userDateOfBirth         = "userDateOfBirth"
    static let userMaxHR               = "userMaxHR"
    static let useMetricUnits          = "useMetricUnits"

    // Onboarding
    static let hasCompletedOnboarding  = "hasCompletedOnboarding"

    // Sleep
    static let baselineSleepHours      = "baselineSleepHours"

    // App behaviour
    static let cacheEnabled            = "cacheEnabled"
    static let lastRefreshedTimestamp  = "lastRefreshedTimestamp"
    static let weeklySummaryGenerated  = "weeklySummaryGenerated"

    // Notifications — recovery
    static let notificationsEnabled         = "notificationsEnabled"
    static let recoveryNotificationHour     = "recoveryNotificationHour"
    static let recoveryNotificationMinute   = "recoveryNotificationMinute"

    // Notifications — bedtime
    static let bedtimeReminderEnabled       = "bedtimeReminderEnabled"
    static let bedtimeReminderMinutesBefore = "bedtimeReminderMinutesBefore"

    // Notifications — check-in
    static let checkinReminderEnabled  = "checkinReminderEnabled"
    static let checkinReminderHour     = "checkinReminderHour"
    static let checkinReminderMinute   = "checkinReminderMinute"

    // Notification history (internal to NotificationStore)
    static let storedNotificationHistory = "storedNotificationHistory"
}
