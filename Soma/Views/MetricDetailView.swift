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

// MARK: - MetricDetailView

struct MetricDetailView: View {
    let metric: DashboardMetric
    let viewModel: DashboardViewModel

    @State private var selectedRange: TrendsViewModel.TimeRange = .week
    @State private var selectedDate: Date?
    @Environment(\.dismiss) private var dismiss

    private var history: [DailyMetrics] {
        viewModel.loadHistory(days: selectedRange.days)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.somaBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        rangePicker
                        scoreChart
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
                if let val = selectedValue {
                    Text(val)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.somaCardElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
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
                .foregroundStyle(metric.accentColor)
                .symbolSize(25)

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
            .chartXSelection(value: $selectedDate)
            .frame(height: 220)
        }
        .padding(14)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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

    private var selectedValue: String? {
        guard let date = selectedDate else { return nil }
        let nearest = history.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
        return nearest.map { String(format: "%.0f", metric.score(from: $0)) }
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
