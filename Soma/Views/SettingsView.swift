import SwiftUI

final class UserSettings: ObservableObject {
    @AppStorage("userAge") var age: Int = 30
    @AppStorage("userMaxHR") private var _maxHR: Int = 0
    @AppStorage("baselineSleepHours") var baselineSleepHours: Double = 8.0
    @AppStorage("useMetricUnits") var useMetricUnits: Bool = true
    @AppStorage("wakeTimeHour")   var wakeTimeHour: Int = 6
    @AppStorage("wakeTimeMinute") var wakeTimeMinute: Int = 30

    var maxHeartRate: Double? {
        get { _maxHR > 0 ? Double(_maxHR) : nil }
        set { _maxHR = Int(newValue ?? 0) }
    }

    var effectiveMaxHR: Double {
        maxHeartRate ?? Double(220 - age)
    }

    /// Wake time as a Date (using today's date for the time components).
    var wakeTime: Date {
        get {
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            comps.hour   = wakeTimeHour
            comps.minute = wakeTimeMinute
            comps.second = 0
            return Calendar.current.date(from: comps) ?? Date()
        }
        set {
            let comps    = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            wakeTimeHour   = comps.hour   ?? 6
            wakeTimeMinute = comps.minute ?? 30
        }
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
                    Section("Personal") {
                        HStack {
                            Label("Age", systemImage: "person.fill")
                                .foregroundColor(.primary)
                            Spacer()
                            Stepper("\(settings.age)", value: $settings.age, in: 13...99)
                                .labelsHidden()
                                .foregroundColor(Color(hex: "8E8E93"))
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
                            Label("Baseline Sleep Need", systemImage: "moon.fill")
                                .foregroundColor(.primary)
                            Spacer()
                            Stepper(
                                String(format: "%.1fh", settings.baselineSleepHours),
                                value: $settings.baselineSleepHours,
                                in: 5.0...12.0,
                                step: 0.5
                            )
                            .labelsHidden()
                            .foregroundColor(.secondary)
                        }
                        HStack {
                            Label("Wake Time", systemImage: "alarm.fill")
                                .foregroundColor(.primary)
                            Spacer()
                            DatePicker("", selection: Binding(
                                get: { settings.wakeTime },
                                set: { settings.wakeTime = $0 }
                            ), displayedComponents: .hourAndMinute)
                            .labelsHidden()
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
