import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    let checkInStore: CheckInStore
    let healthKit: HealthDataProviding
    @State private var showSettings = false
    @State private var showCheckIn = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        if viewModel.isBaselineBuilding {
                            baselineBanner
                        }

                        // 2x2 Metric Grid
                        LazyVGrid(columns: columns, spacing: 12) {
                            MetricCardView(
                                title: "Recovery",
                                score: viewModel.todayMetrics.recoveryScore,
                                maxScore: 100,
                                state: viewModel.todayMetrics.recoveryState,
                                sparklineValues: viewModel.sparklineData["recovery"] ?? []
                            )
                            MetricCardView(
                                title: "Strain",
                                score: viewModel.todayMetrics.strainScore,
                                maxScore: 21,
                                state: viewModel.todayMetrics.strainState,
                                sparklineValues: viewModel.sparklineData["strain"] ?? []
                            )
                            MetricCardView(
                                title: "Sleep",
                                score: viewModel.todayMetrics.sleepScore,
                                maxScore: 100,
                                state: viewModel.todayMetrics.sleepState,
                                sparklineValues: viewModel.sparklineData["sleep"] ?? []
                            )
                            MetricCardView(
                                title: "Stress",
                                score: viewModel.todayMetrics.stressScore,
                                maxScore: 100,
                                state: viewModel.todayMetrics.stressState,
                                sparklineValues: viewModel.sparklineData["stress"] ?? []
                            )
                        }
                        .padding(.horizontal)

                        // Daily Check-In prompt
                        if !checkInStore.hasCompletedToday() {
                            checkInPrompt
                        }

                        // How to Improve Today
                        if !viewModel.coachingTips.isEmpty {
                            improvementCard
                        }

                        // Quick Stats
                        quickStatsRow

                        Spacer(minLength: 20)
                    }
                    .padding(.top, 8)
                }
                .refreshable {
                    viewModel.refresh(force: true)
                }

                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                }
            }
            .navigationTitle("Soma")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        if !checkInStore.hasCompletedToday() {
                            Button {
                                showCheckIn = true
                            } label: {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(Color(hex: "00C853"))
                            }
                        }
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(Color(hex: "8E8E93"))
                        }
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showCheckIn) {
                CheckInView(viewModel: CheckInViewModel(
                    checkInStore: checkInStore,
                    healthKit: healthKit
                ))
            }
        }
        .onAppear {
            viewModel.loadCached()
            viewModel.refresh()
        }
    }

    // MARK: - Subviews

    private var baselineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.badge.fill")
                .foregroundColor(Color(hex: "FFD600"))
            Text("Building baseline — add more days for accurate scores.")
                .font(.caption)
                .foregroundColor(Color(hex: "FFD600"))
        }
        .padding(10)
        .background(Color(hex: "FFD600").opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal)
    }

    private var checkInPrompt: some View {
        Button {
            showCheckIn = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(Color(hex: "00C853"))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Check-In")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text("Log yesterday's behaviors to unlock insights")
                        .font(.caption)
                        .foregroundColor(Color(hex: "8E8E93"))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color(hex: "8E8E93"))
            }
            .padding(14)
            .background(Color(hex: "00C853").opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color(hex: "00C853").opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal)
    }

    private var improvementCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: recommendationIcon)
                    .font(.body)
                    .foregroundColor(viewModel.todayMetrics.recoveryState.color)
                Text("How to Improve Today")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Spacer()
            }
            ForEach(Array(viewModel.coachingTips.enumerated()), id: \.offset) { _, tip in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(Color(hex: "2979FF"))
                        .frame(width: 5, height: 5)
                        .padding(.top, 6)
                    Text(tip)
                        .font(.caption)
                        .foregroundColor(Color(hex: "8E8E93"))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .background(Color(hex: "1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }

    private var quickStatsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                quickStat(
                    icon: "figure.walk",
                    value: formattedSteps,
                    label: "Steps"
                )
                quickStat(
                    icon: "flame.fill",
                    value: formattedCalories,
                    label: "Active Cal"
                )
                quickStat(
                    icon: "moon.zzz.fill",
                    value: formattedSleep,
                    label: "Sleep"
                )
                if let vo2 = viewModel.todayMetrics.vo2Max {
                    quickStat(
                        icon: "lungs.fill",
                        value: String(format: "%.0f", vo2),
                        label: "VO2 Max"
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    private func quickStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Color(hex: "2979FF"))
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(Color(hex: "8E8E93"))
        }
        .frame(minWidth: 80)
        .padding(12)
        .background(Color(hex: "1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var recommendationIcon: String {
        switch viewModel.todayMetrics.recoveryScore {
        case 67...100: return "bolt.fill"
        case 34..<67:  return "figure.run"
        default:       return "bed.double.fill"
        }
    }

    private var formattedSteps: String {
        guard let steps = viewModel.todayMetrics.stepCount else { return "--" }
        return steps >= 1000 ? String(format: "%.1fk", steps / 1000) : "\(Int(steps))"
    }

    private var formattedCalories: String {
        guard let cal = viewModel.todayMetrics.activeCalories else { return "--" }
        return "\(Int(cal))"
    }

    private var formattedSleep: String {
        guard let h = viewModel.todayMetrics.sleepDurationHours else { return "--" }
        return String(format: "%.1fh", h)
    }
}
