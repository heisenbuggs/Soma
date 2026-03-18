import SwiftUI
import WidgetKit

final class UserSettings: ObservableObject {
    @AppStorage("userFirstName") var firstName: String = ""
    @AppStorage("userAge") var age: Int = 30
    @AppStorage("userMaxHR") private var _maxHR: Int = 0
    @AppStorage("baselineSleepHours") var sleepGoalHours: Double = 7.0
    @AppStorage("useMetricUnits") var useMetricUnits: Bool = true
    
    // MARK: - Notification Settings
    @AppStorage("notificationsEnabled") var notificationsEnabled: Bool = true
    @AppStorage("recoveryNotificationHour") var recoveryNotificationHour: Int = 8
    @AppStorage("recoveryNotificationMinute") var recoveryNotificationMinute: Int = 0
    @AppStorage("bedtimeReminderEnabled") var bedtimeReminderEnabled: Bool = false
    @AppStorage("bedtimeReminderMinutesBefore") var bedtimeReminderMinutesBefore: Int = 30
    @AppStorage("checkinReminderEnabled") var checkinReminderEnabled: Bool = false
    @AppStorage("checkinReminderHour") var checkinReminderHour: Int = 21
    @AppStorage("checkinReminderMinute") var checkinReminderMinute: Int = 0

    // MARK: - Per-weekday wake times
    // weekday index: 1=Sunday, 2=Monday, ..., 7=Saturday (matches Calendar.component(.weekday))

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

    /// Today's wake time
    var wakeTime: Date {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return wakeTimeDate(for: weekday)
    }

    var maxHeartRate: Double? {
        get { _maxHR > 0 ? Double(_maxHR) : nil }
        set { _maxHR = Int(newValue ?? 0) }
    }
    
    // MARK: - Notification Time Helpers
    
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

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = UserSettings()
    @State private var showResetAlert = false
    @State private var customMaxHR: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.somaBackground.ignoresSafeArea()

                Form {
                    Section("Profile") {
                        HStack {
                            Label("First Name", systemImage: "person.fill")
                                .foregroundColor(.primary)
                            Spacer()
                            TextField("Your name", text: $settings.firstName)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(Color(hex: "8E8E93"))
                        }
                    }
                    .listRowBackground(Color.somaCard)

                    Section("Personal") {
                        HStack {
                            Label("Age", systemImage: "person.crop.circle")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(settings.age) yrs")
                                .foregroundColor(Color(hex: "8E8E93"))
                            Stepper("", value: $settings.age, in: 13...99)
                                .labelsHidden()
                        }

                        HStack {
                            Label("Max Heart Rate", systemImage: "heart.fill")
                                .foregroundColor(.primary)
                            Spacer()
                            if settings.maxHeartRate == nil {
                                Text("Auto (\(Int(settings.effectiveMaxHR)))")
                                    .foregroundColor(Color(hex: "8E8E93"))
                                    .font(.subheadline)
                            } else {
                                Text("\(Int(settings.effectiveMaxHR)) bpm")
                                    .foregroundColor(.primary)
                                    .font(.subheadline)
                            }
                        }

                        if settings.maxHeartRate != nil {
                            Button("Reset to Auto") {
                                settings.maxHeartRate = nil
                                customMaxHR = ""
                            }
                            .foregroundColor(Color(hex: "FF1744"))
                        }

                        HStack {
                            Label("Custom Max HR", systemImage: "slider.horizontal.3")
                                .foregroundColor(.primary)
                            Spacer()
                            TextField("e.g. 185", text: $customMaxHR)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(Color(hex: "8E8E93"))
                                .frame(width: 80)
                                .onSubmit { applyCustomMaxHR() }
                        }
                    }
                    .listRowBackground(Color.somaCard)

                    Section("Sleep") {
                        HStack {
                            Label("Sleep Goal", systemImage: "moon.fill")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(String(format: "%.1fh", settings.sleepGoalHours))
                                .foregroundColor(Color(hex: "8E8E93"))
                            Stepper("", value: $settings.sleepGoalHours, in: 5.0...12.0, step: 0.5)
                                .labelsHidden()
                        }
                    }
                    .listRowBackground(Color.somaCard)

                    Section("Wake Time") {
                        ForEach(Array(zip(1...7, ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"])), id: \.0) { weekday, label in
                            HStack {
                                Text(label)
                                    .foregroundColor(.primary)
                                    .frame(width: 36, alignment: .leading)
                                Spacer()
                                DatePicker("", selection: Binding(
                                    get: { settings.wakeTimeDate(for: weekday) },
                                    set: { settings.setWakeTimeDate($0, for: weekday) }
                                ), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                            }
                        }
                    }
                    .listRowBackground(Color.somaCard)

                    Section("Notifications") {
                        Toggle(isOn: $settings.notificationsEnabled) {
                            Label("Enable Notifications", systemImage: "bell.fill")
                                .foregroundColor(.primary)
                        }
                        .tint(Color(hex: "00C853"))
                        .onChange(of: settings.notificationsEnabled) { _, enabled in
                            if enabled {
                                requestNotificationPermission()
                            }
                            updateNotificationSchedules()
                        }
                        
                        if settings.notificationsEnabled {
                            HStack {
                                Label("Daily Recovery", systemImage: "heart.fill")
                                    .foregroundColor(.primary)
                                Spacer()
                                DatePicker("", selection: Binding(
                                    get: { settings.recoveryNotificationTime },
                                    set: { 
                                        settings.setRecoveryNotificationTime($0)
                                        updateNotificationSchedules()
                                    }
                                ), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                            }
                            
                            Toggle(isOn: $settings.bedtimeReminderEnabled) {
                                Label("Bedtime Reminder", systemImage: "moon.fill")
                                    .foregroundColor(.primary)
                            }
                            .tint(Color(hex: "00C853"))
                            .onChange(of: settings.bedtimeReminderEnabled) { _, _ in
                                updateNotificationSchedules()
                            }
                            
                            if settings.bedtimeReminderEnabled {
                                HStack {
                                    Text("Remind me")
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 32)
                                    Spacer()
                                    Picker("Minutes before bedtime", selection: $settings.bedtimeReminderMinutesBefore) {
                                        Text("15 min").tag(15)
                                        Text("30 min").tag(30)
                                        Text("45 min").tag(45)
                                        Text("60 min").tag(60)
                                    }
                                    .pickerStyle(.menu)
                                    .onChange(of: settings.bedtimeReminderMinutesBefore) { _, _ in
                                        updateNotificationSchedules()
                                    }
                                    Text("before bedtime")
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Toggle(isOn: $settings.checkinReminderEnabled) {
                                Label("Check-in Reminder", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.primary)
                            }
                            .tint(Color(hex: "00C853"))
                            .onChange(of: settings.checkinReminderEnabled) { _, _ in
                                updateNotificationSchedules()
                            }
                            
                            if settings.checkinReminderEnabled {
                                HStack {
                                    Text("Daily reminder")
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 32)
                                    Spacer()
                                    DatePicker("", selection: Binding(
                                        get: { settings.checkinReminderTime },
                                        set: { 
                                            settings.setCheckinReminderTime($0)
                                            updateNotificationSchedules()
                                        }
                                    ), displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.somaCard)

                    Section("Preferences") {
                        Toggle(isOn: $settings.useMetricUnits) {
                            Label("Metric Units", systemImage: "ruler.fill")
                                .foregroundColor(.primary)
                        }
                        .tint(Color(hex: "00C853"))
                    }
                    .listRowBackground(Color.somaCard)

                    Section("Data") {
                        Button {
                            showResetAlert = true
                        } label: {
                            Label("Reset Baselines", systemImage: "arrow.clockwise")
                                .foregroundColor(Color(hex: "FF1744"))
                        }
                    }
                    .listRowBackground(Color.somaCard)

#if DEBUG
                    Section("Debug") {
                        Button("Test Widget Data") {
                            testWidgetData()
                        }
                        .foregroundColor(.primary)
                        
                        Button("Refresh Widgets") {
                            WidgetCenter.shared.reloadAllTimelines()
                            print("✅ Widget timelines reloaded")
                        }
                        .foregroundColor(.primary)
                    }
                    .listRowBackground(Color.somaCard)
#endif

                    Section("About") {
                        HStack {
                            Text("Version").foregroundColor(.primary)
                            Spacer()
                            Text("1.0").foregroundColor(Color(hex: "8E8E93"))
                        }
                        HStack {
                            Text("Privacy").foregroundColor(.primary)
                            Spacer()
                            Text("All data stays on device").foregroundColor(Color(hex: "8E8E93")).font(.caption)
                        }
                    }
                    .listRowBackground(Color.somaCard)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(hex: "2979FF"))
                }
            }
            .alert("Reset Baselines", isPresented: $showResetAlert) {
                Button("Reset", role: .destructive) {
                    MetricsStore().resetAll()
                    InsightCache.shared.invalidateAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will clear all stored metrics and force a fresh baseline calculation.")
            }
        }
    }

    private func applyCustomMaxHR() {
        if let value = Int(customMaxHR), value > 100, value < 250 {
            settings.maxHeartRate = Double(value)
        }
    }
    
    // MARK: - Notification Helpers
    
    private func requestNotificationPermission() {
        Task {
            await NotificationScheduler.shared.requestPermission()
        }
    }
    
    private func updateNotificationSchedules() {
        NotificationScheduler.shared.updateAllSchedules(settings: settings)
    }
    
    #if DEBUG
    private func testWidgetData() {
        let store = MetricsStore()
        
        // Check if we have today's metrics
        if let todayMetrics = store.load(for: Date()) {
            print("✅ Widget Debug: Today's metrics found")
            print("   Recovery: \(todayMetrics.recoveryScore)")
            print("   Strain: \(todayMetrics.strainScore)")
            print("   Sleep: \(todayMetrics.sleepScore)")
            print("   Stress: \(todayMetrics.stressScore)")
        } else {
            print("❌ Widget Debug: No metrics found for today")
        }
        
        // Check App Group access
        if let groupDefaults = UserDefaults(suiteName: "group.com.prasjain.Soma") {
            print("✅ Widget Debug: App Group accessible")
            
            // Check if widget snapshot exists
            if let data = groupDefaults.data(forKey: "WidgetMetricsSnapshot") {
                print("✅ Widget Debug: Widget snapshot data found (\(data.count) bytes)")
            } else {
                print("❌ Widget Debug: No widget snapshot data found")
                
                // Create test snapshot if we have metrics
                if let todayMetrics = store.load(for: Date()) {
                    let testSnapshot = WidgetMetricsSnapshot(
                        recoveryScore: todayMetrics.recoveryScore,
                        strainScore: todayMetrics.strainScore,
                        sleepScore: todayMetrics.sleepScore,
                        stressScore: todayMetrics.stressScore,
                        date: todayMetrics.date
                    )
                    
                    if let encoded = try? JSONEncoder().encode(testSnapshot) {
                        groupDefaults.set(encoded, forKey: "WidgetMetricsSnapshot")
                        print("✅ Widget Debug: Created widget snapshot")
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
            }
        } else {
            print("❌ Widget Debug: Cannot access App Group - check entitlements")
        }
    }
    #endif
}
