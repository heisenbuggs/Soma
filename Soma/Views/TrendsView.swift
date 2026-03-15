import SwiftUI
import Charts

struct TrendsView: View {
    @ObservedObject var viewModel: TrendsViewModel
    @State private var selectedPoint: DailyMetrics?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Range picker
                        Picker("Range", selection: $viewModel.selectedRange) {
                            ForEach(TrendsViewModel.TimeRange.allCases, id: \.self) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .onChange(of: viewModel.selectedRange) { _ in
                            viewModel.rangeChanged()
                        }

                        if viewModel.isLoading {
                            ProgressView().tint(.white).padding()
                        } else {
                            hrvChart
                            rhrChart
                            strainChart
                            sleepChart
                            recoveryChart
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Trends")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear { viewModel.load() }
    }

    // MARK: - HRV Chart

    private var hrvChart: some View {
        chartSection(title: "HRV", unit: "ms") {
            Chart {
                ForEach(viewModel.hrvHistory, id: \.0) { date, value in
                    LineMark(x: .value("Date", date), y: .value("HRV", value))
                        .foregroundStyle(Color(hex: "00C853"))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", date), y: .value("HRV", value))
                        .foregroundStyle(Color(hex: "00C853"))
                        .symbolSize(30)
                }
                if let baseline = viewModel.hrvBaseline {
                    RuleMark(y: .value("Baseline", baseline))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Color(hex: "8E8E93"))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Baseline").font(.caption2).foregroundColor(Color(hex: "8E8E93"))
                        }
                }
            }
            .frame(height: 180)
            .chartXAxis { chartXAxis() }
            .chartYAxis { AxisMarks(position: .leading) }
        }
    }

    // MARK: - RHR Chart

    private var rhrChart: some View {
        chartSection(title: "Resting Heart Rate", unit: "bpm") {
            Chart {
                ForEach(viewModel.rhrHistory, id: \.0) { date, value in
                    LineMark(x: .value("Date", date), y: .value("RHR", value))
                        .foregroundStyle(Color(hex: "FF1744"))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", date), y: .value("RHR", value))
                        .foregroundStyle(Color(hex: "FF1744"))
                        .symbolSize(30)
                }
                if let baseline = viewModel.rhrBaseline {
                    RuleMark(y: .value("Baseline", baseline))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Color(hex: "8E8E93"))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Baseline").font(.caption2).foregroundColor(Color(hex: "8E8E93"))
                        }
                }
            }
            .frame(height: 180)
            .chartXAxis { chartXAxis() }
            .chartYAxis { AxisMarks(position: .leading) }
        }
    }

    // MARK: - Strain Chart

    private var strainChart: some View {
        chartSection(title: "Strain History", unit: "/21") {
            Chart(viewModel.metricHistory) { metrics in
                BarMark(
                    x: .value("Date", metrics.date, unit: .day),
                    y: .value("Strain", metrics.strainScore)
                )
                .foregroundStyle(strainColor(metrics.strainScore))
                .cornerRadius(4)
            }
            .frame(height: 180)
            .chartYScale(domain: 0...21)
            .chartXAxis { chartXAxis() }
            .chartYAxis { AxisMarks(position: .leading) }
        }
    }

    // MARK: - Sleep Chart

    private var sleepChart: some View {
        chartSection(title: "Sleep Duration", unit: "hours") {
            Chart {
                ForEach(viewModel.metricHistory) { metrics in
                    BarMark(
                        x: .value("Date", metrics.date, unit: .day),
                        y: .value("Sleep", metrics.sleepDurationHours ?? 0)
                    )
                    .foregroundStyle(Color(hex: "2979FF"))
                    .cornerRadius(4)
                }
                ForEach(viewModel.metricHistory) { metrics in
                    if let need = metrics.sleepNeedHours {
                        LineMark(
                            x: .value("Date", metrics.date, unit: .day),
                            y: .value("Need", need)
                        )
                        .foregroundStyle(Color(hex: "FFD600"))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    }
                }
            }
            .frame(height: 180)
            .chartXAxis { chartXAxis() }
            .chartYAxis { AxisMarks(position: .leading) }
        }
    }

    // MARK: - Recovery Chart

    private var recoveryChart: some View {
        chartSection(title: "Recovery Trend", unit: "/100") {
            Chart(viewModel.metricHistory) { metrics in
                AreaMark(
                    x: .value("Date", metrics.date, unit: .day),
                    y: .value("Recovery", metrics.recoveryScore)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [recoveryAreaColor(metrics.recoveryScore).opacity(0.4),
                                 recoveryAreaColor(metrics.recoveryScore).opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                LineMark(
                    x: .value("Date", metrics.date, unit: .day),
                    y: .value("Recovery", metrics.recoveryScore)
                )
                .foregroundStyle(recoveryAreaColor(metrics.recoveryScore))
                .interpolationMethod(.catmullRom)
            }
            .frame(height: 180)
            .chartYScale(domain: 0...100)
            .chartXAxis { chartXAxis() }
            .chartYAxis { AxisMarks(position: .leading) }
        }
    }

    // MARK: - Helpers

    @ChartContentBuilder
    private func chartXAxis() -> some AxisContent {
        AxisMarks(values: .stride(by: .day, count: axisDayStride)) { value in
            AxisGridLine()
            AxisTick()
            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
        }
    }

    private var axisDayStride: Int {
        switch viewModel.selectedRange {
        case .week: return 1
        case .twoWeeks: return 2
        case .month: return 5
        }
    }

    private func chartSection<C: View>(title: String, unit: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text(unit)
                    .font(.caption)
                    .foregroundColor(Color(hex: "8E8E93"))
            }
            content()
        }
        .padding(14)
        .background(Color(hex: "1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }

    private func strainColor(_ score: Double) -> Color {
        ColorState.strain(score: score).color
    }

    private func recoveryAreaColor(_ score: Double) -> Color {
        ColorState.recovery(score: score).color
    }
}
