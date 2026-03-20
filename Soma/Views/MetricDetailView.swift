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
        case .recovery: return Color(hex: "00C853")
        case .sleep:    return Color(hex: "2979FF")
        case .strain:   return Color(hex: "FF9100")
        case .stress:   return Color(hex: "FFD600")
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
        let stored = UserDefaults.standard.double(forKey: "baselineSleepHours")
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
                        }
                        if let m = selectedMetrics {
                            insightsPanel(for: m)
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
                        .foregroundColor(Color(hex: "2979FF"))
                }
            }
            .task {
                if metric == .stress || metric == .strain {
                    let date = history.max { $0.date < $1.date }?.date ?? Date()
                    intradayDate = date
                    intradayHRData = await viewModel.fetchIntradayHR(for: date)
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
                Text("No heart rate data available for today.")
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
                    .foregroundColor(Color(hex: "8E8E93"))
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
                Text("No heart rate data available for today.")
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
                    .foregroundColor(Color(hex: "8E8E93"))
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

        return VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(Color(hex: "FFD600"))
                Text("\(metric.title) Score: \(score) — \(state.label)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }

            if !result.observations.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Observations")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "8E8E93"))
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
                        .foregroundColor(Color(hex: "8E8E93"))
                        .textCase(.uppercase)
                    ForEach(result.actions, id: \.self) { action in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(Color(hex: "2979FF"))
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
        .background(Color(hex: "FFD600").opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(hex: "FFD600").opacity(0.2), lineWidth: 1)
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
                .foregroundColor(Color(hex: "8E8E93"))
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
