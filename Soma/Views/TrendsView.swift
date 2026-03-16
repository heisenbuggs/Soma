import SwiftUI
import Charts

struct TrendsView: View {
    @ObservedObject var viewModel: TrendsViewModel

    // Live drag state — clears when finger lifts (chartXSelection behaviour)
    @State private var dragDate: Date?
    // Pinned state — only ever set to non-nil, persists after finger lifts
    @State private var pinnedDate: Date?

    // Nearest pinned metrics (used for day-detail sheet & tooltips)
    private var pinnedMetrics: DailyMetrics? {
        guard let date = pinnedDate else { return nil }
        return viewModel.metricHistory.min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.somaBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        Picker("Range", selection: $viewModel.selectedRange) {
                            ForEach(TrendsViewModel.TimeRange.allCases, id: \.self) {
                                Text($0.rawValue).tag($0)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .onChange(of: viewModel.selectedRange) {
                            pinnedDate = nil
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
                            ayurvedicSleepChart

                            // Persistent day-detail card
                            if let m = pinnedMetrics {
                                dayDetailCard(m)
                            }
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
        // Swipeable sheet when user taps a data point
        .sheet(item: $viewModel.selectedMetrics) { initial in
            DayDetailPageView(
                allMetrics: viewModel.metricHistory,
                initial: initial,
                checkInStore: CheckInStore()
            )
        }
    }

    // MARK: - Selection helpers

    /// Call this from every chart's chartXSelection onChange
    private func onDragChanged(_ date: Date?) {
        dragDate = date
        if let date {
            pinnedDate = date
            viewModel.selectDate(date)
        }
    }

    private func isSelected(_ date: Date) -> Bool {
        guard let pinned = pinnedDate else { return false }
        let cal = Calendar.current
        return cal.isDate(date, inSameDayAs: pinned)
    }

    // MARK: - HRV Chart

    private var hrvChart: some View {
        chartSection(title: "HRV", unit: "ms", tooltip: hrvTooltip) {
            Chart {
                ForEach(viewModel.hrvHistory, id: \.0) { date, value in
                    LineMark(x: .value("Date", date), y: .value("HRV", value))
                        .foregroundStyle(Color(hex: "00C853"))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", date), y: .value("HRV", value))
                        .foregroundStyle(Color(hex: "00C853"))
                        .symbolSize(isNearPinned(date, in: viewModel.hrvHistory.map(\.0)) ? 80 : 30)
                }
                if let baseline = viewModel.hrvBaseline {
                    RuleMark(y: .value("Baseline", baseline))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Color(hex: "8E8E93"))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Baseline").font(.caption2).foregroundColor(Color(hex: "8E8E93"))
                        }
                }
                if let sel = pinnedDate {
                    RuleMark(x: .value("Selected", sel))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
            }
            .frame(height: 180)
            .chartXAxis { chartXAxis() }
            .chartYAxis { AxisMarks(position: .leading) }
            .chartXSelection(value: $dragDate)
            .onChange(of: dragDate) { _, d in onDragChanged(d) }
        }
    }

    // MARK: - RHR Chart

    private var rhrChart: some View {
        chartSection(title: "Resting Heart Rate", unit: "bpm", tooltip: rhrTooltip) {
            Chart {
                ForEach(viewModel.rhrHistory, id: \.0) { date, value in
                    LineMark(x: .value("Date", date), y: .value("RHR", value))
                        .foregroundStyle(Color(hex: "FF1744"))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", date), y: .value("RHR", value))
                        .foregroundStyle(Color(hex: "FF1744"))
                        .symbolSize(isNearPinned(date, in: viewModel.rhrHistory.map(\.0)) ? 80 : 30)
                }
                if let baseline = viewModel.rhrBaseline {
                    RuleMark(y: .value("Baseline", baseline))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Color(hex: "8E8E93"))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Baseline").font(.caption2).foregroundColor(Color(hex: "8E8E93"))
                        }
                }
                if let sel = pinnedDate {
                    RuleMark(x: .value("Selected", sel))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
            }
            .frame(height: 180)
            .chartXAxis { chartXAxis() }
            .chartYAxis { AxisMarks(position: .leading) }
            .chartXSelection(value: $dragDate)
            .onChange(of: dragDate) { _, d in onDragChanged(d) }
        }
    }

    // MARK: - Strain Chart

    private var strainChart: some View {
        chartSection(title: "Strain History", unit: "/100", tooltip: strainTooltip) {
            Chart(viewModel.metricHistory) { metrics in
                BarMark(
                    x: .value("Date", metrics.date, unit: .day),
                    y: .value("Strain", metrics.strainScore)
                )
                .foregroundStyle(strainColor(metrics.strainScore))
                .cornerRadius(4)
                .opacity(pinnedDate == nil || isSelected(metrics.date) ? 1.0 : 0.45)
            }
            .frame(height: 180)
            .chartYScale(domain: 0...100)
            .chartXAxis { chartXAxis() }
            .chartYAxis { AxisMarks(position: .leading) }
            .chartXSelection(value: $dragDate)
            .onChange(of: dragDate) { _, d in onDragChanged(d) }
        }
    }

    // MARK: - Sleep Chart

    private var sleepChart: some View {
        chartSection(title: "Sleep Duration", unit: "h min", tooltip: sleepTooltip) {
            Chart {
                ForEach(viewModel.metricHistory) { metrics in
                    BarMark(
                        x: .value("Date", metrics.date, unit: .day),
                        y: .value("Sleep", metrics.sleepDurationHours ?? 0)
                    )
                    .foregroundStyle(Color(hex: "2979FF"))
                    .cornerRadius(4)
                    .opacity(pinnedDate == nil || isSelected(metrics.date) ? 1.0 : 0.45)
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
            .chartXSelection(value: $dragDate)
            .onChange(of: dragDate) { _, d in onDragChanged(d) }
        }
    }

    // MARK: - Recovery Chart

    private var recoveryChart: some View {
        chartSection(title: "Recovery Trend", unit: "/100", tooltip: recoveryTooltip) {
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
                // PointMark ensures single data points are always visible
                PointMark(
                    x: .value("Date", metrics.date, unit: .day),
                    y: .value("Recovery", metrics.recoveryScore)
                )
                .foregroundStyle(recoveryAreaColor(metrics.recoveryScore))
                .symbolSize(isSelected(metrics.date) ? 80 : 30)

                if let sel = pinnedDate {
                    RuleMark(x: .value("Selected", sel, unit: .day))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
            }
            .frame(height: 180)
            .chartYScale(domain: 0...100)
            .chartXAxis { chartXAxis() }
            .chartYAxis { AxisMarks(position: .leading) }
            .chartXSelection(value: $dragDate)
            .onChange(of: dragDate) { _, d in onDragChanged(d) }
        }
    }

    // MARK: - Ayurvedic Sleep Chart

    private var ayurvedicSleepData: [(Date, Double)] {
        viewModel.metricHistory.compactMap { m in
            guard let pts = m.ayurvedicSleepPoints else { return nil }
            return (m.date, pts)
        }
    }

    private var ayurvedicSleepChart: some View {
        chartSection(title: "Ayurvedic Sleep Score", unit: "/ 10", tooltip: ayurvedicSleepTooltip) {
            Chart {
                ForEach(ayurvedicSleepData, id: \.0) { date, value in
                    LineMark(x: .value("Date", date), y: .value("Score", value))
                        .foregroundStyle(Color(hex: "00C853"))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", date), y: .value("Score", value))
                        .foregroundStyle(Color(hex: "00C853"))
                        .symbolSize(isNearPinned(date, in: ayurvedicSleepData.map(\.0)) ? 80 : 30)
                }
                if let sel = pinnedDate {
                    RuleMark(x: .value("Selected", sel))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
            }
            .frame(height: 180)
            .chartYScale(domain: 0...10)
            .chartXAxis { chartXAxis() }
            .chartYAxis { AxisMarks(position: .leading) }
            .chartXSelection(value: $dragDate)
            .onChange(of: dragDate) { _, d in onDragChanged(d) }
        }
    }

    private var ayurvedicSleepTooltip: String? {
        guard let pinned = pinnedDate else { return nil }
        let nearest = ayurvedicSleepData.min { abs($0.0.timeIntervalSince(pinned)) < abs($1.0.timeIntervalSince(pinned)) }
        return nearest.map { String(format: "%.1f / 10", $0.1) }
    }

    // MARK: - Inline Day Detail Card

    private func dayDetailCard(_ m: DailyMetrics) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(formatter.string(from: m.date))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
                Button {
                    viewModel.selectedMetrics = m
                } label: {
                    Text("Full Detail")
                        .font(.caption)
                        .foregroundColor(Color(hex: "2979FF"))
                }
                Button {
                    withAnimation { pinnedDate = nil; viewModel.selectDate(nil) }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(hex: "8E8E93"))
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                                GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                dayStatPill("Recovery", value: "\(Int(m.recoveryScore))", color: m.recoveryState.color)
                dayStatPill("Sleep", value: "\(Int(m.sleepScore))", color: m.sleepState.color)
                dayStatPill("Strain", value: "\(Int(m.strainScore))", color: m.strainState.color)
                dayStatPill("Stress", value: "\(Int(m.stressScore))", color: m.stressState.color)
            }

            // Navigation arrows
            HStack {
                Button { navigateDay(-1) } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Prev")
                    }
                    .font(.caption)
                    .foregroundColor(canNavigate(-1) ? Color(hex: "2979FF") : Color(hex: "8E8E93"))
                }
                .disabled(!canNavigate(-1))

                Spacer()

                Text("Swipe ← → to navigate")
                    .font(.caption2)
                    .foregroundColor(Color(hex: "8E8E93"))

                Spacer()

                Button { navigateDay(1) } label: {
                    HStack(spacing: 4) {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption)
                    .foregroundColor(canNavigate(1) ? Color(hex: "2979FF") : Color(hex: "8E8E93"))
                }
                .disabled(!canNavigate(1))
            }
        }
        .padding(14)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(hex: "2979FF").opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
        .gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { val in
                    if val.translation.width < -30 { navigateDay(1) }
                    else if val.translation.width > 30 { navigateDay(-1) }
                }
        )
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func dayStatPill(_ label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(Color(hex: "8E8E93"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.somaCardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func navigateDay(_ direction: Int) {
        guard let pinned = pinnedDate else { return }
        let sorted = viewModel.metricHistory.sorted { $0.date < $1.date }
        guard let currentIdx = sorted.firstIndex(where: {
            Calendar.current.isDate($0.date, inSameDayAs: pinned)
        }) else { return }
        let nextIdx = currentIdx + direction
        guard sorted.indices.contains(nextIdx) else { return }
        let newDate = sorted[nextIdx].date
        withAnimation(.easeInOut(duration: 0.2)) {
            pinnedDate = newDate
            viewModel.selectDate(newDate)
        }
    }

    private func canNavigate(_ direction: Int) -> Bool {
        guard let pinned = pinnedDate else { return false }
        let sorted = viewModel.metricHistory.sorted { $0.date < $1.date }
        guard let currentIdx = sorted.firstIndex(where: {
            Calendar.current.isDate($0.date, inSameDayAs: pinned)
        }) else { return false }
        return sorted.indices.contains(currentIdx + direction)
    }

    // MARK: - Tooltip value lookups

    private var hrvTooltip: String? {
        guard let pinned = pinnedDate else { return nil }
        let nearest = viewModel.hrvHistory.min { abs($0.0.timeIntervalSince(pinned)) < abs($1.0.timeIntervalSince(pinned)) }
        return nearest.map { String(format: "%.0f ms", $0.1) }
    }

    private var rhrTooltip: String? {
        guard let pinned = pinnedDate else { return nil }
        let nearest = viewModel.rhrHistory.min { abs($0.0.timeIntervalSince(pinned)) < abs($1.0.timeIntervalSince(pinned)) }
        return nearest.map { String(format: "%.0f bpm", $0.1) }
    }

    private var strainTooltip: String? {
        pinnedMetrics.map { String(format: "%.0f", $0.strainScore) }
    }

    private var sleepTooltip: String? {
        guard let h = pinnedMetrics?.sleepDurationHours else { return nil }
        let totalMinutes = Int(h * 60)
        let hrs = totalMinutes / 60; let mins = totalMinutes % 60
        return mins == 0 ? "\(hrs)h" : "\(hrs)h \(mins)m"
    }

    private var recoveryTooltip: String? {
        pinnedMetrics.map { String(format: "%.0f", $0.recoveryScore) }
    }

    // MARK: - Helpers

    /// Returns true if `date` is the nearest point to the pinned date
    private func isNearPinned(_ date: Date, in dates: [Date]) -> Bool {
        guard let pinned = pinnedDate else { return false }
        guard let nearest = dates.min(by: { abs($0.timeIntervalSince(pinned)) < abs($1.timeIntervalSince(pinned)) }) else { return false }
        return Calendar.current.isDate(date, inSameDayAs: nearest)
    }

    private func chartXAxis() -> some AxisContent {
        AxisMarks(values: .stride(by: .day, count: axisDayStride)) { _ in
            AxisGridLine()
            AxisTick()
            AxisValueLabel(format: axisDayFormat)
        }
    }

    private var axisDayStride: Int {
        switch viewModel.selectedRange {
        case .week:      return 1
        case .twoWeeks:  return 2
        case .month:     return 5
        case .sixMonths: return 20
        case .year:      return 45
        }
    }

    private var axisDayFormat: Date.FormatStyle {
        switch viewModel.selectedRange {
        case .week, .twoWeeks, .month:
            return .dateTime.month(.abbreviated).day()
        case .sixMonths, .year:
            return .dateTime.month(.abbreviated).year(.twoDigits)
        }
    }

    private func chartSection<C: View>(
        title: String,
        unit: String,
        tooltip: String?,
        @ViewBuilder content: () -> C
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                if let val = tooltip {
                    Text(val)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.somaCardElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(Color(hex: "8E8E93"))
                }
            }
            content()
        }
        .padding(14)
        .background(Color.somaCard)
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
