import SwiftUI
import WidgetKit

final class UserSettings: ObservableObject {
    @AppStorage(UserDefaultsKeys.userFirstName) var firstName: String = ""
    @AppStorage(UserDefaultsKeys.userDateOfBirth) private var _dobTimestamp: Double = 0
    @AppStorage(UserDefaultsKeys.userMaxHR) private var _maxHR: Int = 0

    var dateOfBirth: Date? {
        get { _dobTimestamp > 0 ? Date(timeIntervalSince1970: _dobTimestamp) : nil }
        set { _dobTimestamp = newValue.map { $0.timeIntervalSince1970 } ?? 0; objectWillChange.send() }
    }

    var age: Int {
        guard let dob = dateOfBirth else { return 30 }
        return Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 30
    }

    @AppStorage(UserDefaultsKeys.baselineSleepHours) var sleepGoalHours: Double = 7.0
    @AppStorage(UserDefaultsKeys.useMetricUnits) var useMetricUnits: Bool = true
    @AppStorage(UserDefaultsKeys.cacheEnabled) var cacheEnabled: Bool = false

    // MARK: - Notification Settings
    @AppStorage(UserDefaultsKeys.notificationsEnabled) var notificationsEnabled: Bool = true
    @AppStorage(UserDefaultsKeys.recoveryNotificationHour) var recoveryNotificationHour: Int = 8
    @AppStorage(UserDefaultsKeys.recoveryNotificationMinute) var recoveryNotificationMinute: Int = 0
    @AppStorage(UserDefaultsKeys.bedtimeReminderEnabled) var bedtimeReminderEnabled: Bool = false
    @AppStorage(UserDefaultsKeys.bedtimeReminderMinutesBefore) var bedtimeReminderMinutesBefore: Int = 30
    @AppStorage(UserDefaultsKeys.checkinReminderEnabled) var checkinReminderEnabled: Bool = false
    @AppStorage(UserDefaultsKeys.checkinReminderHour) var checkinReminderHour: Int = 21
    @AppStorage(UserDefaultsKeys.checkinReminderMinute) var checkinReminderMinute: Int = 0

    // MARK: - Per-weekday wake times

    func wakeHour(for weekday: Int) -> Int {
        UserDefaults.standard.object(forKey: "wakeHour_\(weekday)") as? Int ?? 6
    }

    func wakeMinute(for weekday: Int) -> Int {
        UserDefaults.standard.object(forKey: "wakeMin_\(weekday)") as? Int ?? 30
    }

    func setWakeTime(hour: Int, minute: Int, for weekday: Int) {
        UserDefaults.standard.set(hour, forKey: "wakeHour_\(weekday)")
        UserDefaults.standard.set(minute, forKey: "wakeMin_\(weekday)")
        objectWillChange.send()
    }

    func wakeTimeDate(for weekday: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour   = wakeHour(for: weekday)
        comps.minute = wakeMinute(for: weekday)
        comps.second = 0
        return Calendar.current.date(from: comps) ?? Date()
    }

    func setWakeTimeDate(_ date: Date, for weekday: Int) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        setWakeTime(hour: comps.hour ?? 6, minute: comps.minute ?? 30, for: weekday)
    }

    var wakeTime: Date {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return wakeTimeDate(for: weekday)
    }

    var maxHeartRate: Double? {
        get { _maxHR > 0 ? Double(_maxHR) : nil }
        set { _maxHR = Int(newValue ?? 0) }
    }

    var recoveryNotificationTime: Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = recoveryNotificationHour
        comps.minute = recoveryNotificationMinute
        comps.second = 0
        return Calendar.current.date(from: comps) ?? Date()
    }

    func setRecoveryNotificationTime(_ date: Date) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        recoveryNotificationHour = comps.hour ?? 8
        recoveryNotificationMinute = comps.minute ?? 0
        objectWillChange.send()
    }

    var checkinReminderTime: Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = checkinReminderHour
        comps.minute = checkinReminderMinute
        comps.second = 0
        return Calendar.current.date(from: comps) ?? Date()
    }

    func setCheckinReminderTime(_ date: Date) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        checkinReminderHour = comps.hour ?? 21
        checkinReminderMinute = comps.minute ?? 0
        objectWillChange.send()
    }

    var effectiveMaxHR: Double {
        maxHeartRate ?? Double(220 - age)
    }
}

// MARK: - SettingsView

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = UserSettings()
    @State private var showResetAlert = false
    @State private var customMaxHR: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.somaBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        profileHeader
                        sleepSection
                        wakeTimeSection
                        notificationsSection
                        preferencesSection
                        dataSection

                        #if DEBUG
                        debugSection
                        #endif

                        aboutSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundColor(Color.somaBlue)
                }
            }
            .alert("Reset Baselines", isPresented: $showResetAlert) {
                Button("Reset", role: .destructive) {
                    MetricsStore().resetAll()
                    InsightCache.shared.invalidateAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will clear all stored metrics and force a fresh baseline calculation over the next 7 days.")
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.somaGreen, Color.somaBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                Text(settings.firstName.isEmpty ? "?" : String(settings.firstName.prefix(1)).uppercased())
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            VStack(spacing: 12) {
                // Name field
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    TextField("Your first name", text: $settings.firstName)
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.somaCardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Date of birth
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    DatePicker(
                        "Date of Birth",
                        selection: Binding(
                            get: { settings.dateOfBirth ?? Calendar.current.date(byAdding: .year, value: -30, to: Date())! },
                            set: { settings.dateOfBirth = $0 }
                        ),
                        in: ...Calendar.current.date(byAdding: .year, value: -13, to: Date())!,
                        displayedComponents: .date
                    )
                    .font(.subheadline)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.somaCardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Max HR
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(Color.somaRed)
                        .frame(width: 20)
                    Text("Max Heart Rate")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    if settings.maxHeartRate == nil {
                        Text("Auto · \(Int(settings.effectiveMaxHR)) bpm")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    TextField("e.g. 185", text: $customMaxHR)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(settings.maxHeartRate != nil ? .primary : .secondary)
                        .frame(width: 70)
                        .onSubmit { applyCustomMaxHR() }
                    if settings.maxHeartRate != nil {
                        Button {
                            settings.maxHeartRate = nil
                            customMaxHR = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.somaCardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Sleep Section

    private var sleepSection: some View {
        settingsCard(title: "Sleep", icon: "moon.zzz.fill", iconColor: Color.somaBlue) {
            VStack(spacing: 0) {
                // Sleep goal stepper
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sleep Goal")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Text("Target duration each night")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        Button {
                            if settings.sleepGoalHours > 5.0 {
                                settings.sleepGoalHours = max(5.0, settings.sleepGoalHours - 0.5)
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundColor(settings.sleepGoalHours <= 5.0 ? .secondary : Color.somaBlue)
                        }
                        Text(String(format: "%.1fh", settings.sleepGoalHours))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(Color.somaBlue)
                            .frame(width: 44)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3), value: settings.sleepGoalHours)
                        Button {
                            if settings.sleepGoalHours < 12.0 {
                                settings.sleepGoalHours = min(12.0, settings.sleepGoalHours + 0.5)
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(settings.sleepGoalHours >= 12.0 ? .secondary : Color.somaBlue)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Wake Time Section

    private var wakeTimeSection: some View {
        settingsCard(title: "Wake Times", icon: "alarm.fill", iconColor: Color.somaOrange) {
            VStack(spacing: 0) {
                let days: [(Int, String)] = [(1,"Sun"),(2,"Mon"),(3,"Tue"),(4,"Wed"),(5,"Thu"),(6,"Fri"),(7,"Sat")]
                ForEach(days, id: \.0) { weekday, label in
                    HStack {
                        Text(label)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .frame(width: 36, alignment: .leading)
                        Spacer()
                        DatePicker("", selection: Binding(
                            get: { settings.wakeTimeDate(for: weekday) },
                            set: { settings.setWakeTimeDate($0, for: weekday) }
                        ), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    }
                    .padding(.vertical, 2)
                    if weekday < 7 {
                        Divider().padding(.leading, 36)
                    }
                }
            }
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        settingsCard(title: "Notifications", icon: "bell.fill", iconColor: Color.somaPurple) {
            VStack(spacing: 0) {

                // Master toggle
                settingsToggle(label: "Enable Notifications", value: $settings.notificationsEnabled, tint: Color.somaGreen)
                    .onChange(of: settings.notificationsEnabled) { _, enabled in
                        if enabled { Task { await NotificationScheduler.shared.requestPermission() } }
                        NotificationScheduler.shared.updateAllSchedules(settings: settings)
                    }

                if settings.notificationsEnabled {
                    Divider()

                    // Recovery notification time
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(Color.somaGreen)
                            .frame(width: 20)
                        Text("Daily Recovery")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        DatePicker("", selection: Binding(
                            get: { settings.recoveryNotificationTime },
                            set: {
                                settings.setRecoveryNotificationTime($0)
                                NotificationScheduler.shared.updateAllSchedules(settings: settings)
                            }
                        ), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    }
                    .padding(.vertical, 2)

                    Divider()

                    // Bedtime reminder
                    settingsToggle(label: "Bedtime Reminder", value: $settings.bedtimeReminderEnabled, tint: Color.somaBlue)
                        .onChange(of: settings.bedtimeReminderEnabled) { _, _ in
                            NotificationScheduler.shared.updateAllSchedules(settings: settings)
                        }

                    if settings.bedtimeReminderEnabled {
                        HStack {
                            Text("Remind me")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 28)
                            Spacer()
                            Picker("", selection: $settings.bedtimeReminderMinutesBefore) {
                                Text("15 min").tag(15)
                                Text("30 min").tag(30)
                                Text("45 min").tag(45)
                                Text("60 min").tag(60)
                            }
                            .pickerStyle(.menu)
                            .tint(Color.somaBlue)
                            .onChange(of: settings.bedtimeReminderMinutesBefore) { _, _ in
                                NotificationScheduler.shared.updateAllSchedules(settings: settings)
                            }
                            Text("before bedtime")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    // Check-in reminder
                    settingsToggle(label: "Check-In Reminder", value: $settings.checkinReminderEnabled, tint: Color.somaGreen)
                        .onChange(of: settings.checkinReminderEnabled) { _, _ in
                            NotificationScheduler.shared.updateAllSchedules(settings: settings)
                        }

                    if settings.checkinReminderEnabled {
                        HStack {
                            Text("Daily at")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 28)
                            Spacer()
                            DatePicker("", selection: Binding(
                                get: { settings.checkinReminderTime },
                                set: {
                                    settings.setCheckinReminderTime($0)
                                    NotificationScheduler.shared.updateAllSchedules(settings: settings)
                                }
                            ), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        settingsCard(title: "Preferences", icon: "slider.horizontal.3", iconColor: Color.somaGray) {
            VStack(spacing: 0) {
                settingsToggle(label: "Metric Units", value: $settings.useMetricUnits, tint: Color.somaGreen)
                Divider()
                settingsToggle(label: "Enable Data Cache", value: $settings.cacheEnabled, tint: Color.somaGreen)
                if settings.cacheEnabled {
                    Text("Cached data is valid for 1 hour. Reduces battery usage.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 6)
                } else {
                    Text("Data refreshes every 5 minutes. Pull down on the dashboard to fetch immediately.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 6)
                }
            }
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        settingsCard(title: "Data", icon: "externaldrive.fill", iconColor: Color.somaRed) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showResetAlert = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline)
                    Text("Reset Baselines & Clear Cache")
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .foregroundColor(Color.somaRed)
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        settingsCard(title: "About", icon: "info.circle.fill", iconColor: Color.somaBlue) {
            VStack(spacing: 0) {
                HStack {
                    Text("Version")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text("1.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Divider().padding(.vertical, 4)
                HStack {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(Color.somaGreen)
                        .font(.caption)
                    Text("All data stays on your device")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Debug Section

    #if DEBUG
    private var debugSection: some View {
        settingsCard(title: "Debug", icon: "ant.fill", iconColor: Color.somaYellow) {
            VStack(spacing: 0) {
                Button("Test Widget Data") { testWidgetData() }
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Divider().padding(.vertical, 4)
                Button("Refresh Widgets") {
                    WidgetCenter.shared.reloadAllTimelines()
                }
                .font(.subheadline)
                .foregroundColor(.primary)
            }
        }
    }
    #endif

    // MARK: - Reusable Components

    private func settingsCard<Content: View>(
        title: String,
        icon: String,
        iconColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            content()
        }
        .padding(16)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func settingsToggle(label: String, value: Binding<Bool>, tint: Color) -> some View {
        Toggle(isOn: value) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .tint(tint)
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    private func applyCustomMaxHR() {
        if let value = Int(customMaxHR), value > 100, value < 250 {
            settings.maxHeartRate = Double(value)
        }
    }

    #if DEBUG
    private func testWidgetData() {
        let store = MetricsStore()
        if let m = store.load(for: Date()) {
            print("✅ Recovery: \(m.recoveryScore), Sleep: \(m.sleepScore)")
        }
        if let groupDefaults = UserDefaults(suiteName: "group.com.prasjain.Soma") {
            if let m = MetricsStore().load(for: Date()),
               let snap = try? JSONEncoder().encode(WidgetMetricsSnapshot(
                   recoveryScore: m.recoveryScore, strainScore: m.strainScore,
                   sleepScore: m.sleepScore, stressScore: m.stressScore, date: m.date)) {
                groupDefaults.set(snap, forKey: "WidgetMetricsSnapshot")
                WidgetCenter.shared.reloadAllTimelines()
                print("✅ Widget snapshot written")
            }
        }
    }
    #endif
}
