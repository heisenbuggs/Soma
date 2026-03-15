import SwiftUI

final class UserSettings: ObservableObject {
    @AppStorage("userAge") var age: Int = 30
    @AppStorage("userMaxHR") private var _maxHR: Int = 0
    @AppStorage("baselineSleepHours") var baselineSleepHours: Double = 8.0
    @AppStorage("useMetricUnits") var useMetricUnits: Bool = true

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
                Color.black.ignoresSafeArea()

                Form {
                    Section("Personal") {
                        HStack {
                            Label("Age", systemImage: "person.fill")
                                .foregroundColor(.white)
                            Spacer()
                            Stepper("\(settings.age)", value: $settings.age, in: 13...99)
                                .labelsHidden()
                                .foregroundColor(Color(hex: "8E8E93"))
                        }

                        HStack {
                            Label("Max Heart Rate", systemImage: "heart.fill")
                                .foregroundColor(.white)
                            Spacer()
                            if settings.maxHeartRate == nil {
                                Text("Auto (\(Int(settings.effectiveMaxHR)))")
                                    .foregroundColor(Color(hex: "8E8E93"))
                                    .font(.subheadline)
                            } else {
                                Text("\(Int(settings.effectiveMaxHR)) bpm")
                                    .foregroundColor(.white)
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
                                .foregroundColor(.white)
                            Spacer()
                            TextField("e.g. 185", text: $customMaxHR)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(Color(hex: "8E8E93"))
                                .frame(width: 80)
                                .onSubmit { applyCustomMaxHR() }
                        }
                    }
                    .listRowBackground(Color(hex: "1C1C1E"))

                    Section("Sleep") {
                        HStack {
                            Label("Baseline Sleep Need", systemImage: "moon.fill")
                                .foregroundColor(.white)
                            Spacer()
                            Stepper(
                                String(format: "%.1fh", settings.baselineSleepHours),
                                value: $settings.baselineSleepHours,
                                in: 5.0...12.0,
                                step: 0.5
                            )
                            .labelsHidden()
                            .foregroundColor(Color(hex: "8E8E93"))
                        }
                    }
                    .listRowBackground(Color(hex: "1C1C1E"))

                    Section("Preferences") {
                        Toggle(isOn: $settings.useMetricUnits) {
                            Label("Metric Units", systemImage: "ruler.fill")
                                .foregroundColor(.white)
                        }
                        .tint(Color(hex: "00C853"))
                    }
                    .listRowBackground(Color(hex: "1C1C1E"))

                    Section("Data") {
                        Button {
                            showResetAlert = true
                        } label: {
                            Label("Reset Baselines", systemImage: "arrow.clockwise")
                                .foregroundColor(Color(hex: "FF1744"))
                        }
                    }
                    .listRowBackground(Color(hex: "1C1C1E"))

                    Section("About") {
                        HStack {
                            Text("Version").foregroundColor(.white)
                            Spacer()
                            Text("1.0").foregroundColor(Color(hex: "8E8E93"))
                        }
                        HStack {
                            Text("Privacy").foregroundColor(.white)
                            Spacer()
                            Text("All data stays on device").foregroundColor(Color(hex: "8E8E93")).font(.caption)
                        }
                    }
                    .listRowBackground(Color(hex: "1C1C1E"))
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
