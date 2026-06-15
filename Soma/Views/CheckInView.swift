import SwiftUI

// MARK: - DAILY CHECK-IN (V2)
// Premium dark-first redesign. Jet-black canvas, grouped premium cards, soft
// accent fills on active toggles, and a glowing save button. Logs the subjective
// inputs (substances, habits, stress, recovery practices) that the behavior engine
// blends with HealthKit signals.

struct CheckInView: View {
    @ObservedObject var viewModel: CheckInViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var saveAnimating = false

    var body: some View {
        NavigationStack {
            ZStack {
                SomaGradient.canvas(tint: .somaGreen)

                ScrollView {
                    VStack(spacing: Space.lg) {
                        headerBanner

                        section(title: "Substances", icon: "wineglass.fill", tint: .somaRed) {
                            alcoholRow
                            rowDivider
                            toggleRow(
                                icon: "cup.and.saucer.fill",
                                label: "Caffeine after 5 PM",
                                color: Color.somaYellow,
                                binding: $viewModel.draft.caffeineAfter5PM
                            )
                        }

                        section(title: "Evening Habits", icon: "moon.stars.fill", tint: .somaOrange) {
                            toggleRow(
                                icon: "fork.knife",
                                label: "Late meal before bed",
                                color: Color.somaOrange,
                                binding: $viewModel.draft.lateMealBeforeBed
                            )
                            rowDivider
                            toggleRow(
                                icon: "iphone",
                                label: "Screen use 1h before bed",
                                color: Color.somaOrange,
                                binding: $viewModel.draft.screenBeforeBed
                            )
                            rowDivider
                            toggleRow(
                                icon: "figure.run",
                                label: "Workout within 2h of bed",
                                color: Color.somaOrange,
                                binding: $viewModel.draft.lateWorkout
                            )
                        }

                        section(title: "Stress Level", icon: "bolt.heart.fill", tint: .somaYellow) {
                            stressSlider
                        }

                        section(title: "Recovery Practices", icon: "leaf.fill", tint: .somaGreen) {
                            toggleRow(
                                icon: "brain.head.profile",
                                label: "Meditated",
                                color: Color.somaGreen,
                                binding: $viewModel.draft.meditated
                            )
                            rowDivider
                            toggleRow(
                                icon: "figure.flexibility",
                                label: "Stretched",
                                color: Color.somaGreen,
                                binding: $viewModel.draft.stretched
                            )
                            rowDivider
                            toggleRow(
                                icon: "snowflake",
                                label: "Cold exposure",
                                color: Color.somaBlue,
                                binding: $viewModel.draft.coldExposure
                            )
                        }

                        saveButton
                        Color.clear.frame(height: 16)
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.top, Space.sm)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Daily Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Skip") { dismiss() }
                        .foregroundStyle(Color.somaTextSecondary)
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
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.somaGreen)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.somaGreen.opacity(0.16)))
            VStack(alignment: .leading, spacing: 2) {
                Text("How was yesterday?")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Takes under 10 seconds — sharpens your scores")
                    .font(.footnote)
                    .foregroundStyle(Color.somaTextSecondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .premiumCard(cornerRadius: Radius.lg, glow: .somaGreen)
    }

    // MARK: - Alcohol Row (with conditional units picker)

    private var alcoholRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            toggleRow(
                icon: "wineglass.fill",
                label: "Alcohol",
                color: Color.somaRed,
                binding: $viewModel.draft.alcoholConsumed
            )
            if viewModel.draft.alcoholConsumed {
                HStack(spacing: 10) {
                    Text("Drinks")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.somaTextSecondary)
                    Spacer()
                    Picker("Drinks", selection: $viewModel.draft.alcoholUnits) {
                        Text("1–2").tag(1)
                        Text("3–4").tag(2)
                        Text("5+") .tag(3)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 170)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.draft.alcoholConsumed)
    }

    // MARK: - Stress Slider

    private var stressSlider: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(stressColor)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(stressColor.opacity(0.16)))
                Text("Stress Level")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(stressLabel)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(stressColor)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(stressColor.opacity(0.16)))
            }
            HStack(spacing: 10) {
                Text("Low").font(.caption2).foregroundStyle(Color.somaTextTertiary)
                Slider(value: Binding(
                    get: { Double(viewModel.draft.stressLevel) },
                    set: { viewModel.draft.stressLevel = Int($0.rounded()) }
                ), in: 1...5, step: 1)
                .tint(stressColor)
                Text("High").font(.caption2).foregroundStyle(Color.somaTextTertiary)
            }
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                saveAnimating = true
            }
            viewModel.save()
        } label: {
            HStack(spacing: 8) {
                if viewModel.isSaving {
                    ProgressView().tint(.black).scaleEffect(0.8)
                } else if saveAnimating {
                    Image(systemName: "checkmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black)
                        .transition(.scale.combined(with: .opacity))
                    Text("Saved!")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .transition(.opacity)
                } else {
                    Text("Save Check-In")
                        .font(.headline)
                        .foregroundStyle(.black)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(saveAnimating && !viewModel.isSaving ? Color.somaGreen : Color.white)
            )
            .shadow(color: (saveAnimating ? Color.somaGreen : .white).opacity(0.25), radius: 16, y: 8)
            .scaleEffect(saveAnimating ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: saveAnimating)
        }
        .disabled(viewModel.isSaving)
    }

    // MARK: - Building blocks

    /// A titled group rendered as a single premium card with an eyebrow header.
    private func section<C: View>(title: String, icon: String, tint: Color, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tint)
                Text(title.uppercased()).eyebrow()
            }
            VStack(spacing: 12) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .premiumCard(cornerRadius: Radius.lg, padding: 14)
        }
    }

    private var rowDivider: some View {
        Divider().overlay(Color.somaHairline)
    }

    private func toggleRow(icon: String, label: String, color: Color, binding: Binding<Bool>) -> some View {
        let on = binding.wrappedValue
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(on ? color : Color.somaTextTertiary)
                .frame(width: 34, height: 34)
                .background(Circle().fill((on ? color : Color.somaGray).opacity(0.16)))
                .scaleEffect(on ? 1.06 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.65), value: on)
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(on ? .white : Color.somaTextSecondary)
            Spacer()
            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(color)
                .onChange(of: binding.wrappedValue) { _, _ in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
        }
    }

    private var stressColor: Color {
        switch viewModel.draft.stressLevel {
        case 1, 2: return Color.somaGreen
        case 3:    return Color.somaYellow
        default:   return Color.somaRed
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

#if DEBUG
#Preview {
    CheckInView(viewModel: CheckInViewModel(checkInStore: CheckInStore(), healthKit: PreviewHealthKit()))
        .preferredColorScheme(.dark)
}
#endif
