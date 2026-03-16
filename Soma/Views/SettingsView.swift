import SwiftUI

final class UserSettings: ObservableObject {
    @AppStorage("userFirstName") var firstName: String = ""
    @AppStorage("userAge") var age: Int = 30
    @AppStorage("userMaxHR") private var _maxHR: Int = 0
    @AppStorage("baselineSleepHours") var sleepGoalHours: Double = 7.0
    @AppStorage("useMetricUnits") var useMetricUnits: Bool = true

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
}
