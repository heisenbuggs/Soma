import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    let checkInStore: CheckInStore
    let healthKit: HealthDataProviding
    @AppStorage("userFirstName") private var firstName: String = ""
    @AppStorage("cacheEnabled") private var cacheEnabled: Bool = false
    @State private var showSettings = false
    @State private var showCheckIn = false
    @State private var showRawData = false
    @State private var activeMetric: DashboardMetric?
    @State private var showAyurvedicDetail = false
    @State private var showWeeklySummary = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.somaBackground.ignoresSafeArea()

                ScrollView(.vertical) {
                    VStack(spacing: 16) {
                        if let error = viewModel.errorMessage {
                            errorBanner(error)
                        }

                        // 3.1 — Illness Arc persistent amber banner
                        if viewModel.illnessArcActive {
                            illnessArcBanner
                        }

                        if viewModel.isBaselineBuilding {
                            baselineBanner
                        }

                        // 3.3 — Readiness hero KPI ring (full-width, above the 2×2 grid)
                        if let guidance = viewModel.trainingGuidance {
                            readinessHeroCard(guidance: guidance)
                                .padding(.horizontal)
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

                        // 3.4 — Weekly Summary (shown on Mondays when available)
                        if let summary = viewModel.weeklySummary {
                            weeklySummaryTeaser(summary)
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
                .scrollIndicators(.hidden)
                .refreshable {
                    await viewModel.refresh(force: true)?.value
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
                            showRawData = true
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundColor(Color(hex: "8E8E93"))
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
            .sheet(isPresented: $showRawData) {
                RawDataView(metrics: viewModel.todayMetrics, lastRefreshed: viewModel.lastRefreshed)
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
                    history: viewModel.loadHistory(days: 365),
                    napDurationMinutes: viewModel.todayMetrics.napDurationMinutes,
                    napStartTime: viewModel.todayMetrics.napStartTime,
                    napEndTime: viewModel.todayMetrics.napEndTime
                )
            }
            .sheet(isPresented: $showWeeklySummary) {
                if let summary = viewModel.weeklySummary {
                    WeeklySummarySheet(summary: summary)
                }
            }
        }
        .onAppear {
            viewModel.loadCached()
            viewModel.refresh(force: true)
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
                    if let start = viewModel.todayMetrics.sleepStartTime,
                       let end   = viewModel.todayMetrics.sleepEndTime {
                        Text("Slept \(start.formatted(.dateTime.hour().minute())) · Woke \(end.formatted(.dateTime.hour().minute()))")
                            .font(.caption2)
                            .foregroundColor(Color(hex: "8E8E93"))
                    }
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
                sparklineValues: viewModel.sparklineData[metric.rawValue] ?? [],
                weekDelta: weekDelta(for: metric)
            )
        }
        .buttonStyle(.plain)
    }

    /// Change vs. prior 6-day average for a given metric's sparkline data.
    private func weekDelta(for metric: DashboardMetric) -> Double? {
        let values = viewModel.sparklineData[metric.rawValue] ?? []
        guard values.count >= 2 else { return nil }
        let prior = Array(values.dropLast())
        let avg   = prior.reduce(0, +) / Double(prior.count)
        return values.last.map { $0 - avg }
    }

    // MARK: - Readiness Hero Card (3.3)

    @ViewBuilder
    private func readinessHeroCard(guidance: DailyTrainingGuidance) -> some View {
        let factors = guidance.factors

        // HRV score: ratio × 70 maps baseline (1.0) → 70, above-baseline → higher.
        // Clamped 0–100. A ratio of 1.43 saturates at 100.
        let hrvScore: Double? = factors.hrvRatio.map { ratio in
            max(0, min(100, ratio * 70))
        }

        // RHR score: score = 80 − delta×3.
        // delta=0 (at baseline) → 80; delta=+5 (elevated, penalty territory) → 65;
        // delta=−5 (below baseline, great) → 95; delta=+15 → 35.
        let rhrScore: Double? = factors.rhrDelta.map { delta in
            max(0, min(100, 80 - delta * 3))
        }

        ReadinessHeroView(
            readinessScore: guidance.readinessScore,
            recoveryScore: factors.recoveryScore,
            sleepScore: factors.sleepScore,
            hrvScore: hrvScore,
            rhrScore: rhrScore
        )
    }

    // MARK: - Illness Arc Banner (3.1)

    private var illnessArcBanner: some View {
        let daysText = viewModel.illnessArcDays == 1 ? "1 night" : "\(viewModel.illnessArcDays) nights"
        let recoveryEstimate: String = {
            let remaining = max(0, 5 - viewModel.illnessArcDays)
            if remaining <= 1 { return "You may be in the clear soon — watch for a return to baseline temperature." }
            return "Typical recovery takes 3–5 days. Estimated \(remaining)+ days remaining."
        }()
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "thermometer.medium")
                    .foregroundColor(Color(hex: "FF9100"))
                    .font(.subheadline)
                Text("Illness Arc Detected — \(daysText)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "FF9100"))
            }
            Text("Elevated wrist temperature detected. All strain targets are disabled. Focus on rest, hydration, and sleep.")
                .font(.caption)
                .foregroundColor(Color(hex: "FF9100").opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Text(recoveryEstimate)
                .font(.caption)
                .foregroundColor(Color(hex: "FF9100").opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "FF9100").opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(hex: "FF9100").opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal)
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
        let threeColumns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
        return VStack(alignment: .leading, spacing: 10) {
            Text("Today's Stats")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.horizontal)

            LazyVGrid(columns: threeColumns, spacing: 10) {
                quickStat(icon: "figure.walk",    value: formattedSteps,          label: "Steps")
                quickStat(icon: "flame.fill",      value: formattedCalories,       label: "Active Cal")
                quickStat(icon: "moon.zzz.fill",   value: formattedSleep,          label: "Sleep")
                quickStat(icon: "figure.run",      value: formattedWorkoutMinutes, label: "Workout")

                if let vo2 = viewModel.todayMetrics.vo2Max {
                    quickStat(icon: "lungs.fill",
                              value: String(format: "%.0f", vo2),
                              label: "VO2 Max")
                }
                if let bloodOx = viewModel.todayMetrics.bloodOxygen {
                    quickStat(icon: "drop.circle.fill",
                              value: String(format: "%.1f%%", bloodOx),
                              label: "SpO2")
                }
                if let exercise = viewModel.todayMetrics.exerciseMinutes {
                    quickStat(icon: "figure.strengthtraining.traditional",
                              value: String(format: "%.0f min", exercise),
                              label: "Activity")
                }
                if let movement = viewModel.todayMetrics.movementScore {
                    quickStat(icon: "figure.walk.motion",
                              value: String(format: "%.0f", movement),
                              label: "Movement")
                }
                if let standH = viewModel.todayMetrics.standHours {
                    quickStat(icon: "figure.stand",
                              value: "\(standH)h",
                              label: "Stand")
                }
            }
            .padding(.horizontal)
        }
    }

    private func quickStat(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(Color(hex: "2979FF"))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(Color(hex: "8E8E93"))
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Weekly Summary Teaser (3.4)

    private func weeklySummaryTeaser(_ summary: WeeklySummaryEngine.WeeklySummary) -> some View {
        Button { showWeeklySummary = true } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(Color(hex: "2979FF"))
                        .font(.subheadline)
                    Text("Your Week in Review")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Color(hex: "8E8E93"))
                }
                Text(summary.teaser)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(Color(hex: "2979FF").opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color(hex: "2979FF").opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
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

// MARK: - Weekly Summary Sheet (3.4)

private struct WeeklySummarySheet: View {
    let summary: WeeklySummaryEngine.WeeklySummary
    @Environment(\.dismiss) private var dismiss

    private var weekRange: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return "\(fmt.string(from: summary.weekStart)) – \(fmt.string(from: summary.weekEnd))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.somaBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(weekRange)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        // Narrative paragraphs
                        let paragraphs = summary.narrative.components(separatedBy: "\n\n")
                        ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, para in
                            Text(para)
                                .font(.body)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal)
                                .padding(.top, 16)
                        }
                        Spacer(minLength: 32)
                    }
                }
            }
            .navigationTitle("Week in Review")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(hex: "2979FF"))
                }
            }
        }
    }
}

// MARK: - Raw Data Sheet

private struct RawDataView: View {
    let metrics: DailyMetrics
    let lastRefreshed: Date?
    @Environment(\.dismiss) private var dismiss

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.somaBackground.ignoresSafeArea()
                List {
                    Section("Fetch Info") {
                        rawRow("Last Refreshed", value: lastRefreshed.map { timeFormatter.string(from: $0) } ?? "Never")
                        rawRow("Data Date", value: timeFormatter.string(from: metrics.date))
                    }
                    .listRowBackground(Color.somaCard)

                    Section("Heart") {
                        rawRow("HRV (avg)", value: metrics.hrvAverage.map { String(format: "%.1f ms", $0) })
                        rawRow("Resting HR", value: metrics.restingHR.map { String(format: "%.0f bpm", $0) })
                        rawRow("Sleeping HR", value: metrics.sleepingHR.map { String(format: "%.0f bpm", $0) })
                        rawRow("Sleeping HRV", value: metrics.sleepingHRV.map { String(format: "%.1f ms", $0) })
                        rawRow("Respiratory Rate", value: metrics.respiratoryRate.map { String(format: "%.1f br/min", $0) })
                        rawRow("Blood Oxygen (SpO2)", value: metrics.bloodOxygen.map { String(format: "%.1f%%", $0) })
                        rawRow("VO2 Max", value: metrics.vo2Max.map { String(format: "%.1f ml/kg·min", $0) })
                    }
                    .listRowBackground(Color.somaCard)

                    Section("Sleep") {
                        rawRow("Duration", value: metrics.sleepDurationHours.map { formatHours($0) })
                        rawRow("Sleep Need", value: metrics.sleepNeedHours.map { formatHours($0) })
                        rawRow("Interruptions", value: metrics.sleepInterruptions.map { "\($0)" })
                        rawRow("Sleep Start", value: metrics.sleepStartTime.map { timeFormatter.string(from: $0) })
                        rawRow("Sleep End", value: metrics.sleepEndTime.map { timeFormatter.string(from: $0) })
                        rawRow("Ayurvedic Points", value: metrics.ayurvedicSleepPoints.map { String(format: "%.1f / 10", $0) })
                    }
                    .listRowBackground(Color.somaCard)

                    Section("Activity") {
                        rawRow("Active Calories", value: metrics.activeCalories.map { String(format: "%.0f kcal", $0) })
                        rawRow("Steps", value: metrics.stepCount.map { String(format: "%.0f", $0) })
                        rawRow("Activity Minutes", value: metrics.exerciseMinutes.map { String(format: "%.0f min", $0) })
                        rawRow("Workout Minutes", value: metrics.workoutMinutes.map { String(format: "%.0f min", $0) })
                    }
                    .listRowBackground(Color.somaCard)

                    Section("Strain") {
                        rawRow("Strain Load", value: metrics.strainLoad.map { String(format: "%.1f", $0) })
                        rawRow("Workout Strain", value: metrics.workoutStrain.map { String(format: "%.1f", $0) })
                        rawRow("Incidental Strain", value: metrics.incidentalStrain.map { String(format: "%.1f", $0) })
                    }
                    .listRowBackground(Color.somaCard)

                    Section("Computed Scores") {
                        rawRow("Recovery", value: String(format: "%.1f", metrics.recoveryScore))
                        rawRow("Strain", value: String(format: "%.1f", metrics.strainScore))
                        rawRow("Sleep Score", value: String(format: "%.1f", metrics.sleepScore))
                        rawRow("Stress", value: String(format: "%.1f", metrics.stressScore))
                    }
                    .listRowBackground(Color.somaCard)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Raw Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(hex: "2979FF"))
                }
            }
        }
    }

    private func rawRow(_ label: String, value: String?) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.primary)
            Spacer()
            Text(value ?? "--")
                .foregroundColor(value != nil ? Color(hex: "8E8E93") : Color(hex: "8E8E93").opacity(0.5))
                .font(.subheadline)
        }
    }

    private func formatHours(_ h: Double) -> String {
        let total = Int(h * 60)
        let hrs = total / 60; let mins = total % 60
        if hrs == 0 { return "\(mins)m" }
        if mins == 0 { return "\(hrs)h" }
        return "\(hrs)h \(mins)m"
    }
}
