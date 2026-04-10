import SwiftUI
import Charts

// MARK: - Metric Type

enum DashboardMetric: String, Identifiable {
    case recovery, sleep, strain, stress

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recovery: return "Recovery"
        case .sleep:    return "Sleep"
        case .strain:   return "Strain"
        case .stress:   return "Stress"
        }
    }

    var systemImage: String {
        switch self {
        case .recovery: return "heart.fill"
        case .sleep:    return "moon.zzz.fill"
        case .strain:   return "flame.fill"
        case .stress:   return "brain.head.profile"
        }
    }

    var accentColor: Color {
        switch self {
        case .recovery: return Color.somaGreen
        case .sleep:    return Color.somaBlue
        case .strain:   return Color.somaOrange
        case .stress:   return Color.somaYellow
        }
    }

    func score(from m: DailyMetrics) -> Double {
        switch self {
        case .recovery: return m.recoveryScore
        case .sleep:    return m.sleepScore
        case .strain:   return m.strainScore
        case .stress:   return m.stressScore
        }
    }

    func state(from m: DailyMetrics) -> ColorState {
        switch self {
        case .recovery: return m.recoveryState
        case .sleep:    return m.sleepState
        case .strain:   return m.strainState
        case .stress:   return m.stressState
        }
    }
}

// MARK: - MetricInsightGenerator

struct MetricInsightGenerator {

    static func generate(
        for metric: DashboardMetric,
        metrics: DailyMetrics,
        sleepGoal: Double
    ) -> (observations: [String], actions: [String]) {
        switch metric {
        case .sleep:    return sleepInsights(metrics: metrics, sleepGoal: sleepGoal)
        case .recovery: return recoveryInsights(metrics: metrics)
        case .strain:   return strainInsights(metrics: metrics)
        case .stress:   return stressInsights(metrics: metrics)
        }
    }

    private static func sleepInsights(metrics: DailyMetrics, sleepGoal: Double) -> (observations: [String], actions: [String]) {
        var obs: [String] = []
        var acts: [String] = []

        if let actual = metrics.sleepDurationHours {
            let diff = sleepGoal - actual
            if diff > 0.1 {
                let debtStr = formatHours(diff)
                obs.append("You slept \(debtStr) less than your sleep goal")
                acts.append("Increase total sleep duration by \(debtStr)")
            } else {
                obs.append("You met your sleep duration goal")
            }
        }

        if let n = metrics.sleepInterruptions, n > 3 {
            obs.append("Sleep was interrupted \(n) times during the night")
            acts.append("Limit fluids 2 hours before bed to reduce interruptions")
        }

        if let hrv = metrics.sleepingHRV, hrv < 30 {
            obs.append("Sleeping HRV was low, indicating reduced overnight recovery")
            acts.append("Avoid alcohol and screen time before bed to improve HRV")
        }

        if let sHR = metrics.sleepingHR, let rhr = metrics.restingHR, sHR > rhr + 5 {
            obs.append("Sleeping heart rate was elevated compared to your resting HR")
            acts.append("Avoid late meals and alcohol which elevate overnight heart rate")
        }

        if let start = metrics.sleepStartTime {
            let hour = Calendar.current.component(.hour, from: start)
            if hour >= 0 && hour < 5 {
                obs.append("Your sleep start time was later than ideal")
                acts.append("Aim to be in bed before midnight for better recovery")
            }
        }

        if acts.isEmpty { acts.append("Maintain your current sleep routine") }
        return (obs, acts)
    }

    private static func recoveryInsights(metrics: DailyMetrics) -> (observations: [String], actions: [String]) {
        var obs: [String] = []
        var acts: [String] = []

        if metrics.recoveryScore < 50 {
            obs.append("Recovery is below average — your body needs more rest")
            acts.append("Reduce training intensity today and prioritize sleep tonight")
        }

        if let hrv = metrics.hrvAverage, hrv < 30 {
            obs.append("HRV was low, indicating accumulated fatigue")
            acts.append("Take a rest day or limit activity to light movement")
        }

        if let rhr = metrics.restingHR, rhr > 65 {
            obs.append("Resting heart rate was elevated at \(Int(rhr)) bpm")
            acts.append("Hydrate well and avoid caffeine to lower resting HR")
        }

        if metrics.sleepScore < 60 {
            obs.append("Poor sleep quality impacted today's recovery")
            acts.append("Focus on improving tonight's sleep environment")
        }

        if obs.isEmpty {
            obs.append("Recovery looks solid today")
            acts.append("Good day for moderate to high intensity training")
        }
        return (obs, acts)
    }

    static func acrDescription(history: [DailyMetrics]) -> String? {
        let acr = TrainingGuidanceEngine.acrRatio(history: history)
        guard let acr else { return nil }
        let fmt = String(format: "%.2f", acr)
        if acr > 1.3 {
            return "ACR \(fmt) — training spike detected. Up to -10 pts applied to recovery."
        } else if acr < 0.8 {
            return "ACR \(fmt) — training load has been low recently."
        }
        return "ACR \(fmt) — training load is balanced."
    }

    private static func strainInsights(metrics: DailyMetrics) -> (observations: [String], actions: [String]) {
        var obs: [String] = []
        var acts: [String] = []

        let state = ColorState.strain(score: metrics.strainScore)
        obs.append("Strain category: \(state.label)")

        if metrics.strainScore >= 80 {
            acts.append("Ensure tomorrow includes light activity or full rest")
            acts.append("Prioritize 8+ hours of sleep for adequate recovery")
        } else if metrics.strainScore >= 60 {
            acts.append("Maintain hydration and adequate protein intake")
        } else if metrics.strainScore <= 20 {
            obs.append("Mostly resting or light activity today")
            acts.append("Consider adding light movement to support circulation")
        } else {
            acts.append("Continue with your current training approach")
        }

        if let wm = metrics.workoutMinutes, wm > 0 {
            obs.append("\(formatHours(wm / 60)) of workout time contributed to today's strain")
        }
        return (obs, acts)
    }

    private static func stressInsights(metrics: DailyMetrics) -> (observations: [String], actions: [String]) {
        var obs: [String] = []
        var acts: [String] = []

        if metrics.stressScore > 60 {
            obs.append("Stress indicators are elevated today")
            acts.append("Try a 5-minute breathing exercise or short walk")
            acts.append("Reduce caffeine and screen exposure this evening")
        } else if metrics.stressScore > 30 {
            obs.append("Stress is at a moderate level")
            acts.append("Short mindfulness breaks can help maintain balance")
        } else {
            obs.append("Stress levels are low — your nervous system is calm")
            acts.append("Good state for focused work or training")
        }
        return (obs, acts)
    }

    private static func formatHours(_ h: Double) -> String {
        let total = Int((h * 60).rounded())
        let hrs = total / 60; let mins = total % 60
        if hrs == 0 { return "\(mins)m" }
        if mins == 0 { return "\(hrs)h" }
        return "\(hrs)h \(mins)m"
    }
}

// MARK: - MetricDetailView

struct MetricDetailView: View {
    let metric: DashboardMetric
    let viewModel: DashboardViewModel

    @State private var selectedRange: TrendsViewModel.TimeRange = .week
    @State private var selectedDate: Date?
    @State private var intradayHRData: [(Date, Double)] = []
    @State private var intradayDate: Date = Date()
    @State private var selectedStressDate: Date?
    @State private var selectedStrainDate: Date?
    @Environment(\.dismiss) private var dismiss

    private var history: [DailyMetrics] {
        viewModel.loadHistory(days: selectedRange.days)
    }

    private var selectedMetrics: DailyMetrics? {
        if let date = selectedDate {
            return history.min {
                abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
            }
        }
        return history.max { $0.date < $1.date }
    }

    private var sleepGoal: Double {
        let stored = UserDefaults.standard.double(forKey: UserDefaultsKeys.baselineSleepHours)
        return stored > 0 ? stored : 7.0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.somaBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        rangePicker
                        scoreChart
                        if metric == .stress {
                            intradayStressChart
                        }
                        if metric == .strain {
                            intradayStrainChart
                            if let m = selectedMetrics, let zones = m.workoutZoneDetails, !zones.isEmpty {
                                workoutZoneChart(zones)
                            }
                        }
                        if let m = selectedMetrics {
                            insightsPanel(for: m)
                        }
                        // 3.2 — Sleep Regularity Dashboard (sleep metric only)
                        if metric == .sleep {
                            sleepRegularityPanel
                            sleepDebtChart
                            sleepCalendarGrid
                        }
                        statsRow
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(metric.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color.somaBlue)
                }
            }
            .task {
                if metric == .stress || metric == .strain {
                    intradayDate = Date()
                    intradayHRData = await viewModel.fetchIntradayHR(for: Date())
                }
            }
            .onChange(of: selectedDate) { _, newDate in
                if metric == .stress || metric == .strain, let date = newDate {
                    Task {
                        intradayDate = date
                        intradayHRData = await viewModel.fetchIntradayHR(for: date)
                    }
                }
            }
        }
    }

    // MARK: - Range Picker

    private var rangePicker: some View {
        Picker("Range", selection: $selectedRange) {
            ForEach(TrendsViewModel.TimeRange.allCases, id: \.self) {
                Text($0.rawValue).tag($0)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .onChange(of: selectedRange) { _, _ in
            selectedDate = history.max { $0.date < $1.date }?.date
        }
    }

    // MARK: - Score Chart

    private var scoreChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: metric.systemImage)
                    .foregroundColor(metric.accentColor)
                Text("\(metric.title) Score")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                tooltipView
            }

            Chart(history) { entry in
                AreaMark(
                    x: .value("Date", entry.date, unit: .day),
                    y: .value("Score", metric.score(from: entry))
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [metric.accentColor.opacity(0.35), metric.accentColor.opacity(0)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                LineMark(
                    x: .value("Date", entry.date, unit: .day),
                    y: .value("Score", metric.score(from: entry))
                )
                .foregroundStyle(metric.accentColor)
                .interpolationMethod(.catmullRom)
                PointMark(
                    x: .value("Date", entry.date, unit: .day),
                    y: .value("Score", metric.score(from: entry))
                )
                .foregroundStyle(isSelected(entry.date) ? metric.state(from: entry).color : metric.accentColor)
                .symbolSize(isSelected(entry.date) ? 80 : 25)

                if let sel = selectedDate {
                    RuleMark(x: .value("Selected", sel, unit: .day))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                }
            }
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: axisDayStride)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: axisDayFormat)
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 220)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            guard let plotFrameAnchor = proxy.plotFrame else { return }
                            let plotFrame = geo[plotFrameAnchor]
                            let relativeX = location.x - plotFrame.origin.x
                            guard relativeX >= 0, relativeX <= plotFrame.width else { return }
                            if let tappedDate: Date = proxy.value(atX: relativeX) {
                                selectedDate = history.min {
                                    abs($0.date.timeIntervalSince(tappedDate)) < abs($1.date.timeIntervalSince(tappedDate))
                                }?.date
                            }
                        }
                }
            }
            .onAppear {
                selectedDate = history.max { $0.date < $1.date }?.date
            }
        }
        .padding(14)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }

    // MARK: - Intraday Stress Chart

    /// Buckets raw HR samples into 30-minute bins and derives a relative stress level.
    /// Stress per bin = clamp((avgHR - rhrBaseline) / rhrBaseline, 0, 1) × 100
    private var intradayStressBuckets: [(Date, Double)] {
        guard !intradayHRData.isEmpty else { return [] }
        let rhrBaseline = history.compactMap { $0.restingHR }.suffix(7).reduce(0, +)
            / max(1, Double(history.compactMap { $0.restingHR }.suffix(7).count))
        let baseline = rhrBaseline > 0 ? rhrBaseline : 65.0

        let cal = Calendar.current
        var buckets: [Date: [Double]] = [:]
        for (date, hr) in intradayHRData {
            // Round down to nearest 30-min bucket
            var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            comps.minute = (comps.minute ?? 0) < 30 ? 0 : 30
            comps.second = 0
            if let bucket = cal.date(from: comps) {
                buckets[bucket, default: []].append(hr)
            }
        }
        return buckets
            .sorted { $0.key < $1.key }
            .map { (date, hrs) in
                let avg = hrs.reduce(0, +) / Double(hrs.count)
                let stress = min(100, max(0, ((avg - baseline) / baseline) * 100))
                return (date, stress)
            }
    }

    private var intradayStressChart: some View {
        let dayLabel = Calendar.current.isDateInToday(intradayDate) ? "Today" : intradayDate.formatted(.dateTime.month(.abbreviated).day())
        let buckets = intradayStressBuckets
        let accentColor = metric.accentColor

        // Nearest bucket to the user's selection
        let selectedBucket: (Date, Double)? = selectedStressDate.flatMap { sel in
            buckets.min { abs($0.0.timeIntervalSince(sel)) < abs($1.0.timeIntervalSince(sel)) }
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(dayLabel)'s Stress Pattern")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                if let (date, stress) = selectedBucket {
                    let label = stressLabel(for: stress)
                    Text("\(date.formatted(.dateTime.hour().minute())) · \(Int(stress.rounded()))  \(label)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.somaCardElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }

            if buckets.isEmpty {
                Text("No heart rate data available for \(dayLabel.lowercased()).")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            } else {
                Chart(buckets, id: \.0) { date, stress in
                    AreaMark(
                        x: .value("Time", date),
                        y: .value("Stress", stress)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accentColor.opacity(0.35), accentColor.opacity(0)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("Time", date),
                        y: .value("Stress", stress)
                    )
                    .foregroundStyle(accentColor)
                    .interpolationMethod(.catmullRom)
                    if let sel = selectedStressDate {
                        RuleMark(x: .value("Selected", sel))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 4)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.hour())
                    }
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .chartXSelection(value: $selectedStressDate)
                .frame(height: 160)

                Text("Based on heart rate elevation above your resting baseline. Lower HRV + higher HR = higher stress.")
                    .font(.caption)
                    .foregroundColor(Color.somaGray)
            }
        }
        .padding(14)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }

    private func stressLabel(for value: Double) -> String {
        switch value {
        case 70...: return "High"
        case 40..<70: return "Moderate"
        default: return "Low"
        }
    }

    // MARK: - Intraday Strain Chart

    /// Buckets raw HR samples into 30-min bins and computes zone-weighted strain load per bin.
    /// Uses the same zone model as StrainCalculator (50% maxHR threshold, zone weights 0–4).
    private var intradayStrainBuckets: [(Date, Double)] {
        guard !intradayHRData.isEmpty else { return [] }
        let maxHR = viewModel.maxHR
        let cal = Calendar.current

        // Group consecutive samples into 30-min buckets
        var buckets: [Date: [(Date, Double)]] = [:]
        for (date, hr) in intradayHRData {
            var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            comps.minute = (comps.minute ?? 0) < 30 ? 0 : 30
            comps.second = 0
            if let bucket = cal.date(from: comps) {
                buckets[bucket, default: []].append((date, hr))
            }
        }

        return buckets
            .sorted { $0.key < $1.key }
            .compactMap { (bucketDate, samples) -> (Date, Double)? in
                guard samples.count > 1 else { return nil }
                let sorted = samples.sorted { $0.0 < $1.0 }
                var load = 0.0
                for i in 1..<sorted.count {
                    let (prevTime, prevHR) = sorted[i - 1]
                    let (currTime, currHR) = sorted[i]
                    let rawMinutes = currTime.timeIntervalSince(prevTime) / 60.0
                    guard rawMinutes > 0 else { continue }
                    let minutes = min(rawMinutes, 1.0)
                    let avgHR = (prevHR + currHR) / 2.0
                    guard avgHR >= 0.5 * maxHR else { continue }
                    let zone = HeartRateZone.zone(for: avgHR, maxHR: maxHR)
                    load += minutes * zone.weight
                }
                return load > 0 ? (bucketDate, load) : nil
            }
    }

    private var intradayStrainChart: some View {
        let strainColor = DashboardMetric.strain.accentColor
        let dayLabel = Calendar.current.isDateInToday(intradayDate) ? "Today" : intradayDate.formatted(.dateTime.month(.abbreviated).day())
        let buckets = intradayStrainBuckets

        let selectedBucket: (Date, Double)? = selectedStrainDate.flatMap { sel in
            buckets.min { abs($0.0.timeIntervalSince(sel)) < abs($1.0.timeIntervalSince(sel)) }
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(dayLabel)'s Strain Pattern")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                if let (date, load) = selectedBucket {
                    Text("\(date.formatted(.dateTime.hour().minute())) · Load \(String(format: "%.1f", load))")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.somaCardElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }

            if buckets.isEmpty {
                Text("No heart rate data available for \(dayLabel.lowercased()).")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            } else {
                Chart(buckets, id: \.0) { date, load in
                    BarMark(
                        x: .value("Time", date, unit: .minute),
                        y: .value("Load", load),
                        width: .fixed(6)
                    )
                    .foregroundStyle(strainColor.gradient)
                    .cornerRadius(2)
                    if let sel = selectedStrainDate {
                        RuleMark(x: .value("Selected", sel))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 4)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.hour())
                    }
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .chartXSelection(value: $selectedStrainDate)
                .frame(height: 160)

                Text("Zone-weighted strain load per 30-min window. Only HR above 50% of your max contributes.")
                    .font(.caption)
                    .foregroundColor(Color.somaGray)
            }
        }
        .padding(14)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }

    // MARK: - Workout Zone Breakdown (2.4)

    private func workoutZoneChart(_ zones: [WorkoutZoneBreakdown]) -> some View {
        let zoneColors: [(Color, String)] = [
            (Color.somaGray, "Z1"),
            (Color.somaBlue, "Z2"),
            (Color.somaGreen, "Z3"),
            (Color.somaYellow, "Z4"),
            (Color.somaRed, "Z5"),
        ]
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(DashboardMetric.strain.accentColor)
                Text("Workout Zone Breakdown")
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            ForEach(zones) { workout in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(workout.activityName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(String(format: "%.0f min total", workout.totalZoneMinutes))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    // Horizontal stacked bar
                    let totalMins = max(workout.totalZoneMinutes, 1)
                    let fractions: [Double] = [
                        workout.z1Minutes / totalMins,
                        workout.z2Minutes / totalMins,
                        workout.z3Minutes / totalMins,
                        workout.z4Minutes / totalMins,
                        workout.z5Minutes / totalMins,
                    ]
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { i in
                                if fractions[i] > 0 {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(zoneColors[i].0)
                                        .frame(width: max(4, geo.size.width * fractions[i]))
                                }
                            }
                        }
                    }
                    .frame(height: 12)
                    // Zone legend
                    HStack(spacing: 10) {
                        ForEach(0..<5, id: \.self) { i in
                            let mins = [workout.z1Minutes, workout.z2Minutes, workout.z3Minutes,
                                        workout.z4Minutes, workout.z5Minutes][i]
                            if mins > 0 {
                                HStack(spacing: 3) {
                                    Circle().fill(zoneColors[i].0).frame(width: 6, height: 6)
                                    Text("\(zoneColors[i].1): \(String(format: "%.0f", mins))m")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
                if zones.last?.id != workout.id {
                    Divider()
                }
            }
        }
        .padding(14)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }

    // MARK: - Insights Panel

    private func insightsPanel(for m: DailyMetrics) -> some View {
        let score = Int(metric.score(from: m).rounded())
        let state = metric.state(from: m)
        let result = MetricInsightGenerator.generate(for: metric, metrics: m, sleepGoal: sleepGoal)
        let acrNote = metric == .recovery ? MetricInsightGenerator.acrDescription(history: history) : nil

        return VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(Color.somaYellow)
                Text("\(metric.title) Score: \(score) — \(state.label)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }

            // ACR sub-row for recovery (2.3)
            if let acr = acrNote {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                        .foregroundColor(Color.somaOrange)
                    Text(acr)
                        .font(.caption)
                        .foregroundColor(Color.somaOrange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background(Color.somaOrange.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if !result.observations.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Observations")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.somaGray)
                        .textCase(.uppercase)
                    ForEach(result.observations, id: \.self) { obs in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(state.color)
                                .frame(width: 5, height: 5)
                                .padding(.top, 6)
                            Text(obs)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if !result.actions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Suggested Actions")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.somaGray)
                        .textCase(.uppercase)
                    ForEach(result.actions, id: \.self) { action in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(Color.somaBlue)
                                .frame(width: 5, height: 5)
                                .padding(.top, 6)
                            Text(action)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.somaYellow.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.somaYellow.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statPill(label: "Avg", value: avgScore)
            statPill(label: "Peak", value: peakScore)
            statPill(label: "Low", value: lowScore)
        }
        .padding(.horizontal)
    }

    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Text(label)
                .font(.caption2)
                .foregroundColor(Color.somaGray)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Sleep Regularity Dashboard (3.2)

    /// All sleep metrics from the past 30 days (independent of the range picker — regularity is a long-term metric).
    private var last30History: [DailyMetrics] { viewModel.loadHistory(days: 30) }

    // MARK: Sleep Regularity Index

    private var sleepRegularityIndex: Double? {
        let times = last30History.compactMap { $0.sleepStartTime }
        guard times.count >= 5 else { return nil }

        let cal = Calendar.current
        // Convert sleep start times to minutes-since-noon (normalises across midnight).
        // Using noon as pivot: PM times are positive, AM times (next day) get +24h offset.
        let minutesFromNoon: [Double] = times.map { t in
            let comps = cal.dateComponents([.hour, .minute], from: t)
            var min = Double((comps.hour ?? 0) * 60 + (comps.minute ?? 0))
            // Times before 10 AM are almost certainly "after midnight" — shift +24h.
            if min < 10 * 60 { min += 24 * 60 }
            // Pivot around noon (720 min) so signed distance is meaningful.
            return min - 12 * 60
        }

        let sorted = minutesFromNoon.sorted()
        let median = sorted[sorted.count / 2]

        let within30 = minutesFromNoon.filter { abs($0 - median) <= 30 }.count
        return Double(within30) / Double(minutesFromNoon.count) * 100
    }

    private var sleepRegularityPanel: some View {
        let sri = sleepRegularityIndex
        let accentColor = sleepRegularityColor(sri)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(accentColor)
                Text("Sleep Regularity")
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            HStack(alignment: .bottom, spacing: 4) {
                if let s = sri {
                    Text("\(Int(s.rounded()))%")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(accentColor)
                } else {
                    Text("--")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Text("nights within 30 min of your median bedtime")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 6)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(accentColor.opacity(0.12))
                    Capsule().fill(accentColor)
                        .frame(width: geo.size.width * min(1, (sri ?? 0) / 100))
                        .animation(.easeOut(duration: 1.0), value: sri)
                }
            }
            .frame(height: 8)

            Text(sleepRegularityCaption(sri))
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }

    private func sleepRegularityColor(_ sri: Double?) -> Color {
        guard let s = sri else { return Color.somaGray }
        if s >= 80 { return Color.somaGreen }
        if s >= 60 { return Color.somaYellow }
        return Color.somaOrange
    }

    private func sleepRegularityCaption(_ sri: Double?) -> String {
        guard let s = sri else { return "Need at least 5 nights of data to compute regularity." }
        if s >= 80 { return "Excellent — consistent sleep timing strengthens your circadian rhythm and improves deep-sleep architecture." }
        if s >= 60 { return "Good — minor variation in your sleep schedule. Keeping bedtime within 30 min on weekends has the biggest impact." }
        return "High variability in sleep timing can suppress melatonin and reduce sleep quality. Aim for a fixed bedtime ± 30 min."
    }

    // MARK: 30-Day Sleep Debt Chart

    private var sleepDebtData: [(Date, Double)] {
        last30History.compactMap { m -> (Date, Double)? in
            guard let actual = m.sleepDurationHours else { return nil }
            let goal = m.sleepNeedHours ?? sleepGoal
            return (m.date, max(0, goal - actual))
        }
        .sorted { $0.0 < $1.0 }
    }

    private var sleepDebtChart: some View {
        let data = sleepDebtData
        let totalDebt = data.map { $0.1 }.reduce(0, +)
        let maxDebt = data.map { $0.1 }.max() ?? 1
        let accentColor = Color.somaBlue

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "zzz")
                    .foregroundColor(accentColor)
                Text("30-Day Sleep Debt")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatHoursShort(totalDebt))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(totalDebt > 7 ? Color.somaOrange : accentColor)
                    Text("cumulative debt")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if data.isEmpty {
                Text("No sleep data available for the past 30 days.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                Chart(data, id: \.0) { date, debt in
                    BarMark(
                        x: .value("Date", date, unit: .day),
                        y: .value("Debt (h)", debt)
                    )
                    .foregroundStyle(debtBarColor(debt, max: maxDebt).gradient)
                    .cornerRadius(3)
                }
                .chartYScale(domain: 0...(max(maxDebt + 0.5, 2.0)))
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { val in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = val.as(Double.self) {
                                Text("\(String(format: "%.0f", v))h")
                                    .font(.system(size: 10))
                            }
                        }
                    }
                }
                .frame(height: 140)

                Text("Daily sleep debt = your personalised sleep need minus actual sleep. Zero is ideal.")
                    .font(.caption)
                    .foregroundColor(Color.somaGray)
            }
        }
        .padding(14)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }

    private func debtBarColor(_ debt: Double, max maxDebt: Double) -> Color {
        if debt <= 0.25 { return Color.somaGreen }
        if debt <= 1.0  { return Color.somaYellow }
        return Color.somaOrange
    }

    private func formatHoursShort(_ h: Double) -> String {
        let total = Int((h * 60).rounded())
        let hrs = total / 60; let mins = total % 60
        if hrs == 0  { return "\(mins)m" }
        if mins == 0 { return "\(hrs)h" }
        return "\(hrs)h \(mins)m"
    }

    // MARK: GitHub-Style Sleep Score Calendar Grid

    /// Builds a 6-week (42-cell) grid aligned to calendar weeks.
    /// Each row is a week starting on Sunday. Cells outside [today-41d, today] are empty.
    private var calendarGridData: [Date?] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // Find the Sunday that starts the week containing (today - 41 days).
        guard let earliest = cal.date(byAdding: .day, value: -41, to: today) else { return [] }
        let weekdayOfEarliest = cal.component(.weekday, from: earliest) // 1=Sun
        let offsetToSunday = weekdayOfEarliest - 1
        guard let gridStart = cal.date(byAdding: .day, value: -offsetToSunday, to: earliest) else { return [] }

        // 6 rows × 7 columns = 42 cells
        return (0..<42).map { offset -> Date? in
            guard let date = cal.date(byAdding: .day, value: offset, to: gridStart) else { return nil }
            if date > today { return nil }                            // future: empty
            let daysAgo = cal.dateComponents([.day], from: date, to: today).day ?? 99
            if daysAgo > 41 { return nil }                           // before window: empty
            return date
        }
    }

    private var sleepCalendarGrid: some View {
        let cells     = calendarGridData                             // 42 elements, nil = empty
        let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let accentColor = DashboardMetric.sleep.accentColor
        let cal       = Calendar.current
        let history   = viewModel.loadHistory(days: 45)             // 6 weeks needs up to 45 days

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundColor(accentColor)
                Text("Sleep Score Calendar")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                // Legend
                HStack(spacing: 6) {
                    ForEach(["None", "Low", "Mid", "High"], id: \.self) { label in
                        HStack(spacing: 3) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(calendarLegendColor(label))
                                .frame(width: 10, height: 10)
                            Text(label)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Day-of-week header
            HStack(spacing: 4) {
                ForEach(dayLabels, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // 6 rows × 7 columns
            VStack(spacing: 4) {
                ForEach(0..<6, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { col in
                            let idx = row * 7 + col
                            if idx < cells.count, let date = cells[idx] {
                                let entry = history.first { cal.isDate($0.date, inSameDayAs: date) }
                                let score: Double? = {
                                    guard let m = entry else { return nil }
                                    if m.sleepScore > 5 { return m.sleepScore }
                                    // Fall back to a duration-based proxy so cells show even when
                                    // the full score wasn't computed (e.g. older backfilled data).
                                    if let h = m.sleepDurationHours, h > 0.5 {
                                        let goal = m.sleepNeedHours ?? 7.5
                                        return min(100, max(5, h / goal * 75))
                                    }
                                    return m.sleepScore > 0 ? m.sleepScore : nil
                                }()
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(calendarCellColor(score))
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay(
                                        Group {
                                            if let s = score {
                                                Text("\(Int(s.rounded()))")
                                                    .font(.system(size: 8, weight: .semibold))
                                                    .foregroundColor(.white.opacity(0.9))
                                            }
                                        }
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(Color.secondary.opacity(0.05))
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                }
            }

            Text("Each cell shows your sleep score for that night. Last 6 weeks, aligned to calendar weeks.")
                .font(.caption)
                .foregroundColor(Color.somaGray)
        }
        .padding(14)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }

    private func calendarCellColor(_ score: Double?) -> Color {
        guard let s = score else { return Color.secondary.opacity(0.12) }
        if s >= 75 { return Color.somaGreen }
        if s >= 50 { return Color.somaBlue }
        if s >= 25 { return Color.somaOrange }
        return Color.somaRed
    }

    private func calendarLegendColor(_ label: String) -> Color {
        switch label {
        case "High":    return Color.somaGreen
        case "Mid":     return Color.somaBlue
        case "Low":     return Color.somaOrange
        default:        return Color.secondary.opacity(0.12)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private var tooltipView: some View {
        if let date = selectedDate {
            let nearest = history.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
            if let m = nearest {
                let score = Int(metric.score(from: m).rounded())
                let state = metric.state(from: m)
                let dateStr = m.date.formatted(.dateTime.month(.abbreviated).day())
                (
                    Text("\(dateStr) · \(score) — ")
                    + Text(state.label).foregroundColor(state.color)
                )
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.somaCardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
    }

    private func isSelected(_ date: Date) -> Bool {
        guard let sel = selectedDate else { return false }
        return Calendar.current.isDate(date, inSameDayAs: sel)
    }

    private var avgScore: String {
        guard !history.isEmpty else { return "--" }
        let avg = history.map { metric.score(from: $0) }.reduce(0, +) / Double(history.count)
        return String(format: "%.0f", avg)
    }

    private var peakScore: String {
        guard !history.isEmpty else { return "--" }
        return String(format: "%.0f", history.map { metric.score(from: $0) }.max() ?? 0)
    }

    private var lowScore: String {
        guard !history.isEmpty else { return "--" }
        return String(format: "%.0f", history.map { metric.score(from: $0) }.min() ?? 0)
    }

    private var axisDayStride: Int {
        switch selectedRange {
        case .week:      return 1
        case .twoWeeks:  return 2
        case .month:     return 5
        case .sixMonths: return 20
        case .year:      return 45
        }
    }

    private var axisDayFormat: Date.FormatStyle {
        switch selectedRange {
        case .week, .twoWeeks, .month:
            return .dateTime.month(.abbreviated).day()
        case .sixMonths, .year:
            return .dateTime.month(.abbreviated).year(.twoDigits)
        }
    }
}
