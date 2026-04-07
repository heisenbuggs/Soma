import SwiftUI

struct CheckInView: View {
    @ObservedObject var viewModel: CheckInViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var saveAnimating = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.somaBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        headerBanner

                        checkInSection(title: "Substances") {
                            alcoholRow
                            toggleRow(
                                icon: "cup.and.saucer.fill",
                                label: "Caffeine after 5 PM",
                                color: Color(hex: "FFD600"),
                                binding: $viewModel.draft.caffeineAfter5PM
                            )
                        }

                        checkInSection(title: "Evening Habits") {
                            toggleRow(
                                icon: "fork.knife",
                                label: "Late meal before bed",
                                color: Color(hex: "FF9100"),
                                binding: $viewModel.draft.lateMealBeforeBed
                            )
                            toggleRow(
                                icon: "iphone",
                                label: "Screen use 1h before bed",
                                color: Color(hex: "FF9100"),
                                binding: $viewModel.draft.screenBeforeBed
                            )
                            toggleRow(
                                icon: "figure.run",
                                label: "Workout within 2h of bed",
                                color: Color(hex: "FF9100"),
                                binding: $viewModel.draft.lateWorkout
                            )
                        }

                        checkInSection(title: "Stress Level") {
                            stressSlider
                        }

                        checkInSection(title: "Recovery Practices") {
                            toggleRow(
                                icon: "brain.head.profile",
                                label: "Meditated",
                                color: Color(hex: "00C853"),
                                binding: $viewModel.draft.meditated
                            )
                            toggleRow(
                                icon: "figure.flexibility",
                                label: "Stretched",
                                color: Color(hex: "00C853"),
                                binding: $viewModel.draft.stretched
                            )
                            toggleRow(
                                icon: "snowflake",
                                label: "Cold exposure",
                                color: Color(hex: "2979FF"),
                                binding: $viewModel.draft.coldExposure
                            )
                        }

                        saveButton

                        Spacer(minLength: 32)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Daily Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Skip") { dismiss() }
                        .foregroundColor(Color(hex: "8E8E93"))
                }
            }
        }
        .onChange(of: viewModel.didSave) { _, saved in
            if saved {
                // Brief pause so the checkmark is visible before dismissing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Header

    private var headerBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color(hex: "00C853"))
            VStack(alignment: .leading, spacing: 2) {
                Text("How was yesterday?")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("Takes under 10 seconds")
                    .font(.caption)
                    .foregroundColor(Color(hex: "8E8E93"))
            }
            Spacer()
        }
        .padding(14)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal)
    }

    // MARK: - Alcohol Row

    private var alcoholRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            toggleRow(
                icon: "wineglass.fill",
                label: "Alcohol",
                color: Color(hex: "FF1744"),
                binding: $viewModel.draft.alcoholConsumed
            )
            if viewModel.draft.alcoholConsumed {
                HStack(spacing: 0) {
                    Text("Drinks:")
                        .font(.caption)
                        .foregroundColor(Color(hex: "8E8E93"))
                        .padding(.leading, 44)
                    Spacer()
                    Picker("Drinks", selection: $viewModel.draft.alcoholUnits) {
                        Text("1–2").tag(1)
                        Text("3–4").tag(2)
                        Text("5+") .tag(3)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
            }
        }
    }

    // MARK: - Stress Slider

    private var stressSlider: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(stressColor)
                    .frame(width: 24)
                Text("Stress Level: \(stressLabel)")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
            }
            HStack(spacing: 8) {
                Text("Low").font(.caption2).foregroundColor(Color(hex: "8E8E93"))
                Slider(value: Binding(
                    get: { Double(viewModel.draft.stressLevel) },
                    set: { viewModel.draft.stressLevel = Int($0.rounded()) }
                ), in: 1...5, step: 1)
                .tint(stressColor)
                Text("High").font(.caption2).foregroundColor(Color(hex: "8E8E93"))
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                saveAnimating = true
            }
            viewModel.save()
        } label: {
            HStack(spacing: 8) {
                if viewModel.isSaving {
                    ProgressView().tint(.black).scaleEffect(0.8)
                } else if saveAnimating && !viewModel.isSaving {
                    Image(systemName: "checkmark")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.black)
                        .transition(.scale.combined(with: .opacity))
                    Text("Saved!")
                        .font(.headline)
                        .foregroundColor(.black)
                        .transition(.opacity)
                } else {
                    Text("Save Check-In")
                        .font(.headline)
                        .foregroundColor(.black)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(saveAnimating && !viewModel.isSaving ? Color(hex: "00C853") : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(saveAnimating ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: saveAnimating)
        }
        .disabled(viewModel.isSaving)
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func checkInSection<C: View>(title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Color(hex: "8E8E93"))
                .padding(.horizontal)
                .padding(.bottom, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.somaCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.horizontal)
    }

    private func toggleRow(icon: String, label: String, color: Color, binding: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: binding.wrappedValue ? "\(icon)" : icon)
                .font(.body)
                .foregroundColor(binding.wrappedValue ? color : color.opacity(0.6))
                .frame(width: 28)
                .scaleEffect(binding.wrappedValue ? 1.1 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.65), value: binding.wrappedValue)
            Text(label)
                .font(.subheadline)
                .foregroundColor(binding.wrappedValue ? .primary : .primary.opacity(0.8))
            Spacer()
            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            binding.wrappedValue ? color.opacity(0.06) : Color.clear
        )
        .animation(.easeInOut(duration: 0.2), value: binding.wrappedValue)
    }

    private var stressColor: Color {
        switch viewModel.draft.stressLevel {
        case 1, 2: return Color(hex: "00C853")
        case 3:    return Color(hex: "FFD600")
        default:   return Color(hex: "FF1744")
        }
    }

    private var stressLabel: String {
        switch viewModel.draft.stressLevel {
        case 1: return "Very Low"
        case 2: return "Low"
        case 3: return "Moderate"
        case 4: return "High"
        default: return "Very High"
        }
    }
}
