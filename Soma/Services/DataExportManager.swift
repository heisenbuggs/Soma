import Foundation

// MARK: - Export Data Structures

struct SomaWakeTime: Codable {
    let weekday: Int
    let hour: Int
    let minute: Int
}

struct SomaSettingsExport: Codable {
    // Profile
    let firstName: String
    let dateOfBirthTimestamp: Double
    let maxHR: Int

    // Sleep
    let sleepGoalHours: Double

    // Preferences
    let useMetricUnits: Bool
    let cacheEnabled: Bool
    let hasCompletedOnboarding: Bool

    // Notifications — recovery
    let notificationsEnabled: Bool
    let recoveryNotificationHour: Int
    let recoveryNotificationMinute: Int

    // Notifications — bedtime
    let bedtimeReminderEnabled: Bool
    let bedtimeReminderMinutesBefore: Int

    // Notifications — check-in
    let checkinReminderEnabled: Bool
    let checkinReminderHour: Int
    let checkinReminderMinute: Int

    // Per-weekday wake times (weekday indices 1=Sun … 7=Sat)
    let wakeTimes: [SomaWakeTime]
}

struct SomaExportData: Codable {
    let exportVersion: Int
    let exportDate: Date
    let appVersion: String

    let settings: SomaSettingsExport
    let dailyMetrics: [DailyMetrics]
    let checkIns: [DailyCheckIn]
    let notificationHistory: [NotificationRecord]
}

// MARK: - DataExportManager

final class DataExportManager {

    static let shared = DataExportManager()

    private let appGroupID  = "group.com.prasjain.Soma"
    private let metricsKey  = "storedDailyMetrics"
    private let checkInsKey = "dailyCheckIns"

    private var appGroupDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    private init() {}

    // MARK: - Export

    /// Encodes all app data to a JSON file in the temp directory and returns its URL.
    func export() throws -> URL {
        let payload = try buildExportData()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(payload)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let fileName = "soma-export-\(formatter.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try jsonData.write(to: url, options: .atomic)
        return url
    }

    private func buildExportData() throws -> SomaExportData {
        let std = UserDefaults.standard

        // Wake times for each weekday (1 = Sunday … 7 = Saturday)
        let wakeTimes = (1...7).map { weekday in
            SomaWakeTime(
                weekday: weekday,
                hour:    std.object(forKey: "wakeHour_\(weekday)") as? Int ?? 6,
                minute:  std.object(forKey: "wakeMin_\(weekday)") as? Int  ?? 30
            )
        }

        let settings = SomaSettingsExport(
            firstName:                  std.string(forKey: UserDefaultsKeys.userFirstName) ?? "",
            dateOfBirthTimestamp:       std.double(forKey: UserDefaultsKeys.userDateOfBirth),
            maxHR:                      std.integer(forKey: UserDefaultsKeys.userMaxHR),
            sleepGoalHours:             std.object(forKey: UserDefaultsKeys.baselineSleepHours) as? Double ?? 7.0,
            useMetricUnits:             std.object(forKey: UserDefaultsKeys.useMetricUnits) as? Bool ?? true,
            cacheEnabled:               std.bool(forKey: UserDefaultsKeys.cacheEnabled),
            hasCompletedOnboarding:     std.bool(forKey: UserDefaultsKeys.hasCompletedOnboarding),
            notificationsEnabled:       std.object(forKey: UserDefaultsKeys.notificationsEnabled) as? Bool ?? true,
            recoveryNotificationHour:   std.object(forKey: UserDefaultsKeys.recoveryNotificationHour) as? Int ?? 8,
            recoveryNotificationMinute: std.object(forKey: UserDefaultsKeys.recoveryNotificationMinute) as? Int ?? 0,
            bedtimeReminderEnabled:     std.bool(forKey: UserDefaultsKeys.bedtimeReminderEnabled),
            bedtimeReminderMinutesBefore: std.object(forKey: UserDefaultsKeys.bedtimeReminderMinutesBefore) as? Int ?? 30,
            checkinReminderEnabled:     std.bool(forKey: UserDefaultsKeys.checkinReminderEnabled),
            checkinReminderHour:        std.object(forKey: UserDefaultsKeys.checkinReminderHour) as? Int ?? 21,
            checkinReminderMinute:      std.object(forKey: UserDefaultsKeys.checkinReminderMinute) as? Int ?? 0,
            wakeTimes:                  wakeTimes
        )

        // Daily metrics (stored in App Group defaults)
        let dailyMetrics: [DailyMetrics]
        if let data    = appGroupDefaults.data(forKey: metricsKey),
           let decoded = try? JSONDecoder().decode([DailyMetrics].self, from: data) {
            dailyMetrics = decoded
        } else {
            dailyMetrics = []
        }

        // Check-ins (stored in standard defaults)
        let checkIns: [DailyCheckIn]
        if let data    = std.data(forKey: checkInsKey),
           let decoded = try? JSONDecoder().decode([DailyCheckIn].self, from: data) {
            checkIns = decoded
        } else {
            checkIns = []
        }

        let notificationHistory = NotificationStore.shared.loadAll()

        return SomaExportData(
            exportVersion:       1,
            exportDate:          Date(),
            appVersion:          Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            settings:            settings,
            dailyMetrics:        dailyMetrics,
            checkIns:            checkIns,
            notificationHistory: notificationHistory
        )
    }

    // MARK: - Import

    enum ImportError: LocalizedError {
        case invalidFile
        case unsupportedVersion(Int)
        case decodingFailed(Error)

        var errorDescription: String? {
            switch self {
            case .invalidFile:
                return "The file could not be read as a valid Soma export."
            case .unsupportedVersion(let v):
                return "Export version \(v) is not supported by this version of Soma."
            case .decodingFailed(let e):
                return "Failed to decode export file: \(e.localizedDescription)"
            }
        }
    }

    struct ImportResult {
        let metricsCount: Int
        let checkInsCount: Int
        let notificationCount: Int
    }

    /// Reads a `.json` export file and restores all data into the app's stores.
    /// Returns a summary of how many records were imported.
    @discardableResult
    func `import`(from url: URL) throws -> ImportResult {
        let didScope = url.startAccessingSecurityScopedResource()
        defer { if didScope { url.stopAccessingSecurityScopedResource() } }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ImportError.invalidFile
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let export: SomaExportData
        do {
            export = try decoder.decode(SomaExportData.self, from: data)
        } catch {
            throw ImportError.decodingFailed(error)
        }

        guard export.exportVersion == 1 else {
            throw ImportError.unsupportedVersion(export.exportVersion)
        }

        restoreSettings(export.settings)
        restoreMetrics(export.dailyMetrics)
        restoreCheckIns(export.checkIns)
        restoreNotifications(export.notificationHistory)

        return ImportResult(
            metricsCount:      export.dailyMetrics.count,
            checkInsCount:     export.checkIns.count,
            notificationCount: export.notificationHistory.count
        )
    }

    // MARK: - Private restore helpers

    private func restoreSettings(_ s: SomaSettingsExport) {
        let std = UserDefaults.standard

        std.set(s.firstName,                  forKey: UserDefaultsKeys.userFirstName)
        std.set(s.dateOfBirthTimestamp,        forKey: UserDefaultsKeys.userDateOfBirth)
        std.set(s.maxHR,                       forKey: UserDefaultsKeys.userMaxHR)
        std.set(s.sleepGoalHours,              forKey: UserDefaultsKeys.baselineSleepHours)
        std.set(s.useMetricUnits,              forKey: UserDefaultsKeys.useMetricUnits)
        std.set(s.cacheEnabled,                forKey: UserDefaultsKeys.cacheEnabled)
        std.set(s.hasCompletedOnboarding,      forKey: UserDefaultsKeys.hasCompletedOnboarding)
        std.set(s.notificationsEnabled,        forKey: UserDefaultsKeys.notificationsEnabled)
        std.set(s.recoveryNotificationHour,    forKey: UserDefaultsKeys.recoveryNotificationHour)
        std.set(s.recoveryNotificationMinute,  forKey: UserDefaultsKeys.recoveryNotificationMinute)
        std.set(s.bedtimeReminderEnabled,      forKey: UserDefaultsKeys.bedtimeReminderEnabled)
        std.set(s.bedtimeReminderMinutesBefore, forKey: UserDefaultsKeys.bedtimeReminderMinutesBefore)
        std.set(s.checkinReminderEnabled,      forKey: UserDefaultsKeys.checkinReminderEnabled)
        std.set(s.checkinReminderHour,         forKey: UserDefaultsKeys.checkinReminderHour)
        std.set(s.checkinReminderMinute,       forKey: UserDefaultsKeys.checkinReminderMinute)

        for wt in s.wakeTimes {
            std.set(wt.hour,   forKey: "wakeHour_\(wt.weekday)")
            std.set(wt.minute, forKey: "wakeMin_\(wt.weekday)")
        }
    }

    private func restoreMetrics(_ metrics: [DailyMetrics]) {
        // Re-encode with the default (non-ISO8601) encoder so MetricsStore can decode normally
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(metrics) {
            appGroupDefaults.set(data, forKey: metricsKey)
        }
    }

    private func restoreCheckIns(_ checkIns: [DailyCheckIn]) {
        if let data = try? JSONEncoder().encode(checkIns) {
            UserDefaults.standard.set(data, forKey: checkInsKey)
        }
    }

    private func restoreNotifications(_ records: [NotificationRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: UserDefaultsKeys.storedNotificationHistory)
        }
    }
}
