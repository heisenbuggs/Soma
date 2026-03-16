import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    let checkInStore: CheckInStore
    let healthKit: HealthDataProviding
    @AppStorage("userFirstName") private var firstName: String = ""
    @State private var showSettings = false
    @State private var showCheckIn = false
    @State private var activeMetric: DashboardMetric?
    @State private var showAyurvedicDetail = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.somaBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        if let error = viewModel.errorMessage {
                            errorBanner(error)
                        }

                        if viewModel.isBaselineBuilding {
                            baselineBanner
                        }

                        // 2x2 Metric Grid
                        LazyVGrid(columns: columns, spacing: 12) {
                            metricCard(.recovery)
                            metricCard(.strain)
                            metricCard(.sleep)
                            metricCard(.stress)
                        }
                        .padding(.horizontal)

                        // Ayurvedic Sleep Points widget
                        ayurvedicSleepWidget
                            .padding(.horizontal)

                        // Training Guidance card
                        if let guidance = viewModel.trainingGuidance {
                            trainingGuidanceCard(guidance)
                                .padding(.horizontal)
                        }

                        // Daily Check-In prompt
                        if !checkInStore.hasCompletedToday() {
                            checkInPrompt
                        }

                        // How to Improve Today
                        if !viewModel.coachingTips.isEmpty {
                            improvementCard
                        }

                        // Bedtime recommendation
                        if let bedtime = viewModel.bedtimeTarget {
                            bedtimeCard(bedtime)
                        }

                        // Quick Stats
                        quickStatsRow

                        Spacer(minLength: 20)
                    }
                    .padding(.top, 8)
                }
                .scrollBounceBehavior(.basedOnSize)
                .refreshable {
                    viewModel.refresh(force: true)
                }

                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                }
            }
            .navigationTitle(firstName.isEmpty ? "Hi there" : "Hi, \(firstName)")
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
            .sheet(item: $activeMetric) { metric in
                MetricDetailView(metric: metric, viewModel: viewModel)
            }
            .sheet(isPresented: $showAyurvedicDetail) {
                AyurvedicSleepDetailView(
                    score: viewModel.todayMetrics.ayurvedicSleepPoints ?? 0,
                    sleepStart: viewModel.todayMetrics.sleepStartTime,
                    sleepEnd: viewModel.todayMetrics.sleepEndTime,
                    eveningDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
                    history: viewModel.loadHistory(days: 365)
                )
            }
        }
        .onAppear {
            viewModel.loadCached()
            viewModel.refresh()
        }
    }

    // MARK: - Ayurvedic Sleep Points Widget

    private var ayurvedicSleepWidget: some View {
        let points = viewModel.todayMetrics.ayurvedicSleepPoints
        let score  = points ?? 0
        let accentHex = AyurvedicSleepCalculator.guidanceHex(for: score)
        let accent = Color(hex: accentHex)
        return Button { showAyurvedicDetail = true } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.stars.fill")
                            .foregroundColor(accent)
                            .font(.subheadline)
                        Text("Ayurvedic Sleep Points")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    Text(AyurvedicSleepCalculator.guidanceText(for: score))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if points != nil {
                    Text(String(format: "%.1f", score))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(accent)
                    Text("/ 10")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("--")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color(hex: "8E8E93"))
            }
            .padding(14)
            .background(accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(accent.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Training Guidance Card

    private func trainingGuidanceCard(_ guidance: DailyTrainingGuidance) -> some View {
        let accent = Color(hex: guidance.activityLevel.colorHex)
        return VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack(spacing: 10) {
                Image(systemName: guidance.activityLevel.icon)
                    .font(.title3)
                    .foregroundColor(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Training Guidance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(guidance.activityLevel.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(accent)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Readiness")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(Int(guidance.readinessScore.rounded()))")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(accent)
                }
            }

            // Strain target range
            HStack(spacing: 6) {
                Image(systemName: "target")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Target strain: \(guidance.targetStrainMin)–\(guidance.targetStrainMax)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Suggested workouts
            if !guidance.suggestedWorkouts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(guidance.suggestedWorkouts, id: \.self) { workout in
                            Text(workout)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(accent.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // Explanation
            if !guidance.explanation.isEmpty {
                Text(guidance.explanation)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(accent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(accent.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Metric Card (tappable)

    private func metricCard(_ metric: DashboardMetric) -> some View {
        Button { activeMetric = metric } label: {
            MetricCardView(
                title: metric.title,
                score: metric.score(from: viewModel.todayMetrics),
                maxScore: 100,
                state: metric.state(from: viewModel.todayMetrics),
                sparklineValues: viewModel.sparklineData[metric.rawValue] ?? []
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subviews

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color(hex: "FF1744"))
            Text(message)
                .font(.caption)
                .foregroundColor(Color(hex: "FF1744"))
        }
        .padding(10)
        .background(Color(hex: "FF1744").opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal)
    }

    private var baselineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.badge.fill")
                .foregroundColor(Color(hex: "FFD600"))
            Text("Building baseline — scores improve after 3 days of Apple Watch data.")
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
                        .foregroundColor(.primary)
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
                    .foregroundColor(.primary)
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
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }

    private func bedtimeCard(_ bedtime: Date) -> some View {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let needStr: String = {
            guard let h = viewModel.todayMetrics.sleepNeedHours else { return "" }
            let totalMinutes = Int(h * 60)
            let hrs = totalMinutes / 60; let mins = totalMinutes % 60
            let formatted = mins == 0 ? "\(hrs)h" : "\(hrs)h \(mins)m"
            return "\(formatted) need"
        }()
        return HStack(spacing: 12) {
            Image(systemName: "bed.double.fill")
                .font(.title2)
                .foregroundColor(Color(hex: "2979FF"))
            VStack(alignment: .leading, spacing: 2) {
                Text("Bedtime Target")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text("Aim for bed by \(formatter.string(from: bedtime))\(needStr.isEmpty ? "" : " · \(needStr)")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "moon.fill")
                .foregroundColor(Color(hex: "2979FF"))
        }
        .padding(14)
        .background(Color(hex: "2979FF").opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(hex: "2979FF").opacity(0.25), lineWidth: 1)
        )
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
                quickStat(
                    icon: "figure.run",
                    value: formattedWorkoutMinutes,
                    label: "Workout"
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
                .foregroundColor(.primary)
            Text(label)
                .font(.caption2)
                .foregroundColor(Color(hex: "8E8E93"))
        }
        .frame(minWidth: 80)
        .padding(12)
        .background(Color.somaCard)
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

    private var formattedWorkoutMinutes: String {
        guard let mins = viewModel.todayMetrics.workoutMinutes else { return "--" }
        let h = Int(mins) / 60
        let m = Int(mins) % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    private var formattedSleep: String {
        guard let h = viewModel.todayMetrics.sleepDurationHours else { return "--" }
        let totalMinutes = Int(h * 60)
        let hrs = totalMinutes / 60
        let mins = totalMinutes % 60
        if hrs == 0 { return "\(mins)m" }
        if mins == 0 { return "\(hrs)h" }
        return "\(hrs)h \(mins)m"
    }
}
