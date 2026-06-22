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

    /// Default DOB shown when none is set: 04/07/2000.
    static let defaultDateOfBirth: Date = {
        var comps = DateComponents()
        comps.year = 2000
        comps.month = 4
        comps.day = 7
        return Calendar.current.date(from: comps) ?? Date(timeIntervalSince1970: 954979200)
    }()

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

    /// Tomorrow's wake time as an absolute `Date` — tomorrow's calendar day at
    /// the wake hour/minute configured for tomorrow's weekday. Use this to
    /// compute tonight's bedtime: subtract the sleep need from the *next*
    /// wake-up, not today's (which would place bedtime in this morning's hours).
    var tomorrowWakeTime: Date {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let weekday = cal.component(.weekday, from: tomorrow)
        var comps = cal.dateComponents([.year, .month, .day], from: tomorrow)
        comps.hour   = wakeHour(for: weekday)
        comps.minute = wakeMinute(for: weekday)
        comps.second = 0
        return cal.date(from: comps) ?? Date()
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

    private let weekdays: [(Int, String)] =
        [(1,"Sunday"),(2,"Monday"),(3,"Tuesday"),(4,"Wednesday"),(5,"Thursday"),(6,"Friday"),(7,"Saturday")]

    var body: some View {
        NavigationStack {
            ZStack {
                SomaGradient.canvas(tint: .somaBlue)

                ScrollView {
                    VStack(spacing: Space.lg) {
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
                    .padding(.horizontal, Space.md)
                    .padding(.top, Space.sm)
                    .padding(.bottom, 44)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.somaBlue)
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
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.somaGreen, .somaBlue],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 84, height: 84)
                    .shadow(color: Color.somaBlue.opacity(0.45), radius: 16, x: 0, y: 8)
                Text(settings.firstName.isEmpty ? "?" : String(settings.firstName.prefix(1)).uppercased())
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            TextField("", text: $settings.firstName, prompt: Text("Your name").foregroundColor(.somaTextTertiary))
                .multilineTextAlignment(.center)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 0) {
                settingRow("Date of Birth", icon: "calendar", tint: .somaBlue) {
                    DatePicker("", selection: Binding(
                        get: { settings.dateOfBirth ?? UserSettings.defaultDateOfBirth },
                        set: { settings.dateOfBirth = $0 }),
                        in: ...Calendar.current.date(byAdding: .year, value: -13, to: Date())!,
                        displayedComponents: .date)
                    .labelsHidden()
                }
                hairline
                settingRow("Max Heart Rate", subtitle: settings.maxHeartRate == nil ? "Auto · \(Int(settings.effectiveMaxHR)) bpm" : nil,
                           icon: "heart.fill", tint: .somaRed) {
                    HStack(spacing: 6) {
                        TextField("e.g. 185", text: $customMaxHR)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(settings.maxHeartRate != nil ? .white : Color.somaTextTertiary)
                            .frame(width: 64)
                            .onSubmit { applyCustomMaxHR() }
                        if settings.maxHeartRate != nil {
                            Button {
                                settings.maxHeartRate = nil
                                customMaxHR = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(Color.somaTextTertiary)
                            }
                        }
                    }
                }
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .premiumCard(cornerRadius: Radius.xl, padding: 20)
    }

    // MARK: - Sleep

    private var sleepSection: some View {
        card("Sleep", icon: "moon.zzz.fill", tint: .somaBlue) {
            settingRow("Sleep Goal", subtitle: "Target duration each night") {
                HStack(spacing: 14) {
                    stepperButton("minus", enabled: settings.sleepGoalHours > 5.0) {
                        settings.sleepGoalHours = max(5.0, settings.sleepGoalHours - 0.5)
                    }
                    Text(String(format: "%.1fh", settings.sleepGoalHours))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.somaBlue)
                        .frame(width: 48)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: settings.sleepGoalHours)
                    stepperButton("plus", enabled: settings.sleepGoalHours < 12.0) {
                        settings.sleepGoalHours = min(12.0, settings.sleepGoalHours + 0.5)
                    }
                }
            }
        }
    }

    // MARK: - Wake Times

    private var wakeTimeSection: some View {
        card("Wake Times", icon: "alarm.fill", tint: .somaOrange) {
            VStack(spacing: 0) {
                ForEach(weekdays, id: \.0) { weekday, label in
                    settingRow(label) {
                        IntervalTimePicker(selection: Binding(
                            get: { settings.wakeTimeDate(for: weekday) },
                            set: { settings.setWakeTimeDate($0, for: weekday) }),
                            minuteInterval: 5)
                    }
                    if weekday < 7 { hairline }
                }
            }
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        card("Notifications", icon: "bell.fill", tint: .somaPurple) {
            VStack(spacing: 0) {
                toggleRow("Enable Notifications", isOn: $settings.notificationsEnabled, tint: .somaGreen)
                    .onChange(of: settings.notificationsEnabled) { _, enabled in
                        if enabled { Task { await NotificationScheduler.shared.requestPermission() } }
                        NotificationScheduler.shared.updateAllSchedules(settings: settings)
                    }

                if settings.notificationsEnabled {
                    hairline
                    settingRow("Daily Recovery", icon: "heart.fill", tint: .somaGreen) {
                        DatePicker("", selection: Binding(
                            get: { settings.recoveryNotificationTime },
                            set: {
                                settings.setRecoveryNotificationTime($0)
                                NotificationScheduler.shared.updateAllSchedules(settings: settings)
                            }), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    }

                    hairline
                    toggleRow("Bedtime Reminder", isOn: $settings.bedtimeReminderEnabled, tint: .somaBlue)
                        .onChange(of: settings.bedtimeReminderEnabled) { _, _ in
                            NotificationScheduler.shared.updateAllSchedules(settings: settings)
                        }
                    if settings.bedtimeReminderEnabled {
                        settingRow("Remind me before") {
                            Picker("", selection: $settings.bedtimeReminderMinutesBefore) {
                                Text("15 min").tag(15); Text("30 min").tag(30)
                                Text("45 min").tag(45); Text("60 min").tag(60)
                            }
                            .pickerStyle(.menu).tint(Color.somaBlue)
                            .onChange(of: settings.bedtimeReminderMinutesBefore) { _, _ in
                                NotificationScheduler.shared.updateAllSchedules(settings: settings)
                            }
                        }
                    }

                    hairline
                    toggleRow("Check-In Reminder", isOn: $settings.checkinReminderEnabled, tint: .somaGreen)
                        .onChange(of: settings.checkinReminderEnabled) { _, _ in
                            NotificationScheduler.shared.updateAllSchedules(settings: settings)
                        }
                    if settings.checkinReminderEnabled {
                        settingRow("Daily at") {
                            DatePicker("", selection: Binding(
                                get: { settings.checkinReminderTime },
                                set: {
                                    settings.setCheckinReminderTime($0)
                                    NotificationScheduler.shared.updateAllSchedules(settings: settings)
                                }), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        card("Preferences", icon: "slider.horizontal.3", tint: .somaGray) {
            VStack(alignment: .leading, spacing: 0) {
                toggleRow("Metric Units", isOn: $settings.useMetricUnits, tint: .somaGreen)
                hairline
                toggleRow("Enable Data Cache", isOn: $settings.cacheEnabled, tint: .somaGreen)
                Text(settings.cacheEnabled
                     ? "Cached data is valid for 1 hour. Reduces battery usage."
                     : "Data refreshes every 5 minutes. Pull to refresh to fetch immediately.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.somaTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        card("Data", icon: "externaldrive.fill", tint: .somaRed) {
            Button {
                Haptics.tap()
                showResetAlert = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.clockwise").font(.system(size: 15, weight: .semibold))
                    Text("Reset Baselines & Clear Cache").font(.system(size: 15, weight: .medium))
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Color.somaTextTertiary)
                }
                .foregroundStyle(Color.somaRed)
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        card("About", icon: "info.circle.fill", tint: .somaBlue) {
            VStack(spacing: 0) {
                settingRow("Version") {
                    Text("1.0").font(.system(size: 15)).foregroundStyle(Color.somaTextSecondary)
                }
                hairline
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill").font(.caption).foregroundStyle(Color.somaGreen)
                    Text("All data stays on your device")
                        .font(.system(size: 13)).foregroundStyle(Color.somaTextSecondary)
                    Spacer()
                }
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Debug

    #if DEBUG
    private var debugSection: some View {
        card("Debug", icon: "ant.fill", tint: .somaYellow) {
            VStack(spacing: 0) {
                Button { testWidgetData() } label: {
                    settingRow("Test Widget Data") { Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Color.somaTextTertiary) }
                }
                .foregroundStyle(.white)
                hairline
                Button { WidgetCenter.shared.reloadAllTimelines() } label: {
                    settingRow("Refresh Widgets") { Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Color.somaTextTertiary) }
                }
                .foregroundStyle(.white)
            }
        }
    }
    #endif

    // MARK: - Reusable building blocks

    @ViewBuilder
    private func card<Content: View>(_ title: String, icon: String, tint: Color,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(tint.opacity(0.16)))
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .premiumCard(cornerRadius: Radius.lg, padding: 18)
    }

    /// A labelled row with an optional leading icon, optional subtitle, and a trailing control.
    @ViewBuilder
    private func settingRow<Trailing: View>(_ label: String, subtitle: String? = nil,
                                            icon: String? = nil, tint: Color = .somaGray,
                                            @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(tint.opacity(0.16)))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
                if let subtitle {
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(Color.somaTextTertiary)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.vertical, 11)
    }

    private func toggleRow(_ label: String, isOn: Binding<Bool>, tint: Color) -> some View {
        Toggle(isOn: isOn) {
            Text(label).font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
        }
        .tint(tint)
        .padding(.vertical, 9)
    }

    private func stepperButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button { if enabled { Haptics.tap(); action() } } label: {
            Image(systemName: "\(icon).circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(enabled ? Color.somaBlue : Color.somaTextTertiary.opacity(0.5))
        }
    }

    private var hairline: some View {
        Rectangle().fill(Color.somaHairline).frame(height: 1)
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

// MARK: - Interval Time Picker

/// A time picker that constrains the minute field to a fixed interval
/// (e.g. 5-minute steps: 06:00, 06:05, …). SwiftUI's `DatePicker` does not
/// expose `minuteInterval`, so we wrap `UIDatePicker` directly.
struct IntervalTimePicker: UIViewRepresentable {
    @Binding var selection: Date
    var minuteInterval: Int = 5

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .compact
        picker.minuteInterval = minuteInterval
        picker.date = selection
        picker.setContentHuggingPriority(.required, for: .horizontal)
        picker.setContentCompressionResistancePriority(.required, for: .horizontal)
        picker.addTarget(context.coordinator,
                         action: #selector(Coordinator.valueChanged(_:)),
                         for: .valueChanged)
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        picker.minuteInterval = minuteInterval
        if picker.date != selection { picker.date = selection }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        private let parent: IntervalTimePicker
        init(_ parent: IntervalTimePicker) { self.parent = parent }

        @objc func valueChanged(_ sender: UIDatePicker) {
            parent.selection = sender.date
        }
    }
}
