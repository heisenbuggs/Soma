import SwiftUI
import Charts

struct TrendsView: View {
    @ObservedObject var viewModel: TrendsViewModel

    // Live drag state — clears when finger lifts (chartXSelection behaviour)
    @State private var dragDate: Date?
    // Pinned state — only ever set to non-nil, persists after finger lifts
    @State private var pinnedDate: Date?
    // Controls the full-detail sheet (opened by long press)
    @State private var showDetailSheet = false

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
                        // Time range selector (consistent with other views)
                        Picker("Range", selection: $viewModel.selectedRange) {
                            ForEach(TrendsViewModel.TimeRange.allCases, id: \.self) {
                                Text($0.rawValue).tag($0)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .onChange(of: viewModel.selectedRange) { _, _ in
                            pinnedDate = nil
                            showDetailSheet = false
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
                            if !viewModel.vo2MaxHistory.isEmpty {
                                vo2MaxChart
                            }

                            // Persistent day-detail card
                            if let m = pinnedMetrics {
                                dayDetailCard(m)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .navigationTitle("Trends")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear { viewModel.load() }
        .onChange(of: viewModel.isLoading) { _, loading in
            guard !loading, pinnedDate == nil else { return }
            let history = viewModel.metricHistory
            guard !history.isEmpty else { return }
            let today = Calendar.current.startOfDay(for: Date())
            if let m = history.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
                pinnedDate = m.date
            } else {
                pinnedDate = history.max(by: { $0.date < $1.date })?.date
            }
        }
        // Full-detail sheet — opened by long press on any chart
        .sheet(isPresented: $showDetailSheet) {
            if let m = pinnedMetrics {
                DayDetailPageView(
                    allMetrics: viewModel.metricHistory,
                    initial: m,
                    checkInStore: CheckInStore()
                )
            }
        }
    }

    // MARK: - Selection helpers

    /// Call this from every chart's chartXSelection onChange.
    /// Touch only pins the date for inline tooltip — sheet opens via long press.
    private func onDragChanged(_ date: Date?) {
        // Disable animations during drag to prevent the chart "dancing" effect
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            dragDate = date
            if let date { pinnedDate = date }
        }
    }

    private func isSelected(_ date: Date) -> Bool {
        guard let pinned = pinnedDate else { return false }
        let cal = Calendar.current
        return cal.isDate(date, inSameDayAs: pinned)
    }

    // MARK: - HRV Chart

    private var hrvChart: some View {
        let baseline = viewModel.hrvBaseline
        return chartSection(title: "HRV", unit: "ms", tooltip: hrvTooltip) {
            Chart {
                ForEach(viewModel.hrvHistory, id: \.0) { date, value in
                    // Mark illness-risk days (HRV < 75% of baseline) in red
                    let isLow = baseline.map { value < $0 * 0.75 } ?? false
                    LineMark(x: .value("Date", date), y: .value("HRV", value))
                        .foregroundStyle(Color(hex: "00C853"))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", date), y: .value("HRV", value))
                        .foregroundStyle(isLow ? Color(hex: "FF1744") : Color(hex: "00C853"))
                        .symbolSize(isLow ? 50 : 30)
                        .annotation(position: .top, spacing: 2) {
                            if isLow {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(Color(hex: "FF1744"))
                            }
                        }
                }
                if let b = baseline {
                    RuleMark(y: .value("Baseline", b))
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
                let hasWorkout = (metrics.workoutMinutes ?? 0) > 0
                BarMark(
                    x: .value("Date", metrics.date, unit: .day),
                    y: .value("Strain", metrics.strainScore)
                )
                .foregroundStyle(strainColor(metrics.strainScore))
                .cornerRadius(4)
                .opacity(pinnedDate == nil || isSelected(metrics.date) ? 1.0 : 0.45)
                // Workout days get a small white dot marker at the bar top
                .annotation(position: .top, alignment: .center, spacing: 1) {
                    if hasWorkout {
                        Circle()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: 4, height: 4)
                    }
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
        // Personal-best day — only annotate if we have enough data to be meaningful
        let bestDay = viewModel.metricHistory.count >= 4
            ? viewModel.metricHistory.max(by: { $0.recoveryScore < $1.recoveryScore })
            : nil

        return chartSection(title: "Recovery Trend", unit: "/100", tooltip: recoveryTooltip) {
            Chart(viewModel.metricHistory) { metrics in
                let isBest = bestDay.map { Calendar.current.isDate(metrics.date, inSameDayAs: $0.date) } ?? false
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
                PointMark(
                    x: .value("Date", metrics.date, unit: .day),
                    y: .value("Recovery", metrics.recoveryScore)
                )
                .foregroundStyle(isBest ? Color(hex: "FFD600") : recoveryAreaColor(metrics.recoveryScore))
                .symbolSize(isBest ? 100 : 30)
                // Gold star above the personal-best point
                .annotation(position: .top, spacing: 2) {
                    if isBest {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "FFD600"))
                    }
                }

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

    // MARK: - VO2 Max Chart (2.2)

    private var vo2MaxChart: some View {
        let trendLabel: String? = viewModel.vo2MaxTrend.map { slope in
            let formatted = String(format: "%+.2f", slope)
            return slope > 0.1 ? "Improving \(formatted)/30d"
                 : slope < -0.1 ? "Declining \(formatted)/30d"
                 : "Stable \(formatted)/30d"
        }
        return chartSection(title: "VO2 Max", unit: "ml/kg/min", tooltip: vo2MaxTooltip) {
            VStack(alignment: .leading, spacing: 4) {
                if let label = trendLabel {
                    HStack(spacing: 4) {
                        Image(systemName: (viewModel.vo2MaxTrend ?? 0) >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2)
                            .foregroundColor((viewModel.vo2MaxTrend ?? 0) >= 0 ? Color(hex: "00C853") : Color(hex: "FF9100"))
                        Text(label)
                            .font(.caption2)
                            .foregroundColor((viewModel.vo2MaxTrend ?? 0) >= 0 ? Color(hex: "00C853") : Color(hex: "FF9100"))
                    }
                }
                Chart {
                    ForEach(viewModel.vo2MaxHistory, id: \.0) { date, value in
                        LineMark(x: .value("Date", date), y: .value("VO2", value))
                            .foregroundStyle(Color(hex: "2979FF"))
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Date", date), y: .value("VO2", value))
                            .foregroundStyle(Color(hex: "2979FF"))
                            .symbolSize(30)
                    }
                    // Linear trend overlay
                    if let slope = viewModel.vo2MaxTrend, let first = viewModel.vo2MaxHistory.first,
                       let last = viewModel.vo2MaxHistory.last {
                        let firstAvg = viewModel.vo2MaxHistory.prefix(3).map(\.1).reduce(0, +) / 3
                        let trendStart = firstAvg
                        let days = last.0.timeIntervalSince(first.0) / 86_400
                        let trendEnd = trendStart + slope * (days / 30)
                        LineMark(x: .value("Date", first.0), y: .value("Trend", trendStart))
                            .foregroundStyle(Color(hex: "FFD600").opacity(0.7))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        LineMark(x: .value("Date", last.0), y: .value("Trend", trendEnd))
                            .foregroundStyle(Color(hex: "FFD600").opacity(0.7))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
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
    }

    private var vo2MaxTooltip: String? {
        guard let pinned = pinnedDate else { return nil }
        guard let entry = viewModel.vo2MaxHistory.min(by: { abs($0.0.timeIntervalSince(pinned)) < abs($1.0.timeIntervalSince(pinned)) }) else { return nil }
        let dateStr = entry.0.formatted(.dateTime.month(.abbreviated).day())
        return "\(dateStr) · \(String(format: "%.1f ml/kg/min", entry.1))"
    }

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
                        .symbolSize(30)
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
        guard let entry = ayurvedicSleepData.min(by: { abs($0.0.timeIntervalSince(pinned)) < abs($1.0.timeIntervalSince(pinned)) }) else { return nil }
        let dateStr = entry.0.formatted(.dateTime.month(.abbreviated).day())
        let label = AyurvedicSleepCalculator.guidanceText(for: entry.1)
        return "\(dateStr) · \(String(format: "%.1f", entry.1)) — \(label)"
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
                    showDetailSheet = true
                } label: {
                    Text("Full Detail")
                        .font(.caption)
                        .foregroundColor(Color(hex: "2979FF"))
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
        guard let entry = nearest else { return nil }
        let dateStr = entry.0.formatted(.dateTime.month(.abbreviated).day())
        return "\(dateStr) · \(String(format: "%.0f ms", entry.1))"
    }

    private var rhrTooltip: String? {
        guard let pinned = pinnedDate else { return nil }
        let nearest = viewModel.rhrHistory.min { abs($0.0.timeIntervalSince(pinned)) < abs($1.0.timeIntervalSince(pinned)) }
        guard let entry = nearest else { return nil }
        let dateStr = entry.0.formatted(.dateTime.month(.abbreviated).day())
        return "\(dateStr) · \(String(format: "%.0f bpm", entry.1))"
    }

    private var strainTooltip: String? {
        guard let m = pinnedMetrics else { return nil }
        let score = Int(m.strainScore.rounded())
        let label = ColorState.strain(score: m.strainScore).label
        let dateStr = m.date.formatted(.dateTime.month(.abbreviated).day())
        return "\(dateStr) · \(score) — \(label)"
    }

    private var sleepTooltip: String? {
        guard let m = pinnedMetrics, let h = m.sleepDurationHours else { return nil }
        let totalMinutes = Int(h * 60)
        let hrs = totalMinutes / 60; let mins = totalMinutes % 60
        let durStr = mins == 0 ? "\(hrs)h" : "\(hrs)h \(mins)m"
        let scoreLabel = ColorState.sleep(score: m.sleepScore).label
        let dateStr = m.date.formatted(.dateTime.month(.abbreviated).day())
        return "\(dateStr) · \(durStr) — \(scoreLabel)"
    }

    private var recoveryTooltip: String? {
        guard let m = pinnedMetrics else { return nil }
        let score = Int(m.recoveryScore.rounded())
        let label = ColorState.recovery(score: m.recoveryScore).label
        let dateStr = m.date.formatted(.dateTime.month(.abbreviated).day())
        return "\(dateStr) · \(score) — \(label)"
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
        .onLongPressGesture(minimumDuration: 0.5) {
            if pinnedDate != nil {
                showDetailSheet = true
            }
        }
    }

    private func strainColor(_ score: Double) -> Color {
        ColorState.strain(score: score).color
    }

    private func recoveryAreaColor(_ score: Double) -> Color {
        ColorState.recovery(score: score).color
    }
}
