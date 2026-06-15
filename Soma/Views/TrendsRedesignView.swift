import SwiftUI
import Charts

// MARK: - TRENDS TAB
// "Am I improving?" — long-term progress.
// Metric selector → large interactive chart → summary stats.

struct TrendsRedesignView: View {
    @ObservedObject var viewModel: TrendsViewModel

    enum Metric: String, CaseIterable, Identifiable {
        case recovery = "Recovery"
        case sleep    = "Sleep"
        case hrv      = "HRV"
        case stress   = "Stress"
        case strain   = "Strain"
        case somaAge  = "Soma Age"
        var id: String { rawValue }

        var color: Color {
            switch self {
            case .recovery: return .somaGreen
            case .sleep:    return .somaBlue
            case .hrv:      return .somaPurple
            case .stress:   return .somaYellow
            case .strain:   return .somaOrange
            case .somaAge:  return .somaLightGreen
            }
        }
        var unit: String { self == .hrv ? "ms" : (self == .somaAge ? "yrs" : "") }
        func value(_ m: DailyMetrics) -> Double? {
            switch self {
            case .recovery: return m.recoveryScore > 0 ? m.recoveryScore : nil
            case .sleep:    return m.sleepScore > 0 ? m.sleepScore : nil
            case .hrv:      return m.hrvAverage
            case .stress:   return m.stressScore > 0 ? m.stressScore : nil
            case .strain:   return m.strainScore > 0 ? m.strainScore : nil
            case .somaAge:  return m.somaAge
            }
        }
    }

    @State private var metric: Metric = .recovery

    var body: some View {
        NavigationStack {
            ZStack {
                SomaGradient.canvas(tint: metric.color)
                ScrollView {
                    VStack(spacing: Space.lg) {
                        metricSelector
                        chartCard
                        statsGrid
                        Color.clear.frame(height: 12)
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.top, Space.sm)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Trends")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear { viewModel.load() }
    }

    // MARK: Metric selector

    private var metricSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Metric.allCases) { m in
                    let on = m == metric
                    Button {
                        Haptics.select()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { metric = m }
                    } label: {
                        Text(m.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(on ? .black : Color.somaTextSecondary)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(
                                Capsule().fill(on ? AnyShapeStyle(m.color) : AnyShapeStyle(Color.white.opacity(0.06)))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: Chart

    private var series: [(date: Date, value: Double)] {
        viewModel.metricHistory
            .compactMap { m in metric.value(m).map { (m.date, $0) } }
            .sorted { $0.date < $1.date }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(metric.rawValue.uppercased()).eyebrow()
                    if let last = series.last {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(fmt(last.value))
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            if !metric.unit.isEmpty {
                                Text(metric.unit).font(.system(size: 13)).foregroundStyle(Color.somaTextTertiary)
                            }
                        }
                    } else {
                        Text("—").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    }
                }
                Spacer()
                rangePicker
            }

            if series.count >= 2 {
                chart.frame(height: 200)
            } else {
                Text("Not enough data yet for this range.")
                    .font(.footnote).foregroundStyle(Color.somaTextSecondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .premiumCard(cornerRadius: Radius.lg)
    }

    private var rangePicker: some View {
        Menu {
            ForEach(TrendsViewModel.TimeRange.allCases, id: \.self) { r in
                Button(r.rawValue) {
                    Haptics.select()
                    viewModel.selectedRange = r
                    viewModel.rangeChanged()
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.selectedRange.rawValue).font(.system(size: 13, weight: .semibold))
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(Color.white.opacity(0.08)))
        }
    }

    private var chart: some View {
        let pts = series
        let values = pts.map(\.value)
        let lo = (values.min() ?? 0)
        let hi = (values.max() ?? 1)
        let pad = max((hi - lo) * 0.15, 1)
        return Chart {
            ForEach(pts, id: \.date) { p in
                AreaMark(x: .value("Date", p.date), y: .value(metric.rawValue, p.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(
                        colors: [metric.color.opacity(0.35), metric.color.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Date", p.date), y: .value(metric.rawValue, p.value))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .foregroundStyle(metric.color)
            }
            if let avg = average {
                RuleMark(y: .value("Average", avg))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color.somaTextTertiary)
            }
        }
        .chartYScale(domain: (lo - pad)...(hi + pad))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                AxisValueLabel().foregroundStyle(Color.somaTextTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                AxisValueLabel().foregroundStyle(Color.somaTextTertiary)
            }
        }
    }

    // MARK: Stats

    private var statsGrid: some View {
        let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: cols, spacing: 12) {
            stat("Average", average.map(fmt) ?? "—")
            stat("Best", best.map(fmt) ?? "—")
            stat("Worst", worst.map(fmt) ?? "—")
            stat("Change", changeText)
            stat("Range", series.isEmpty ? "—" : "\(series.count) days")
            stat("Latest", series.last.map { fmt($0.value) } ?? "—")
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text(label).font(.caption2).foregroundStyle(Color.somaTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .premiumCard(cornerRadius: Radius.md, padding: 4)
    }

    // MARK: - Derived stats

    private var average: Double? {
        let v = series.map(\.value); return v.isEmpty ? nil : v.reduce(0, +) / Double(v.count)
    }
    private var best: Double? {
        // For Soma Age and Stress, lower is better.
        (metric == .stress || metric == .somaAge) ? series.map(\.value).min() : series.map(\.value).max()
    }
    private var worst: Double? {
        (metric == .stress || metric == .somaAge) ? series.map(\.value).max() : series.map(\.value).min()
    }
    private var changeText: String {
        guard let first = series.first?.value, let last = series.last?.value else { return "—" }
        let d = last - first
        return "\(d >= 0 ? "+" : "")\(fmt(d))"
    }
    private func fmt(_ v: Double) -> String {
        metric == .hrv || metric == .somaAge ? String(format: "%.1f", v) : String(format: "%.0f", v)
    }
}
