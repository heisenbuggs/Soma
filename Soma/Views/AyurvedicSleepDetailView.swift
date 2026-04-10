import SwiftUI
import Charts

struct AyurvedicSleepDetailView: View {
    let score: Double
    let sleepStart: Date?
    let sleepEnd: Date?
    let eveningDate: Date
    let history: [DailyMetrics]
    let napDurationMinutes: Double?
    let napStartTime: Date?
    let napEndTime: Date?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedRange: TrendsViewModel.TimeRange = .twoWeeks
    @State private var selectedDate: Date?

    // MARK: - Date Navigation

    private var sortedNavigableDates: [Date] {
        let histDates = history.compactMap { m -> Date? in
            guard m.ayurvedicSleepPoints != nil else { return nil }
            return Calendar.current.startOfDay(for: m.date)
        }
        let today = Calendar.current.startOfDay(for: Date())
        return Array(Set(histDates + [today])).sorted()
    }

    private var currentNavDate: Date {
        if let sel = selectedDate,
           let nearest = history.min(by: { abs($0.date.timeIntervalSince(sel)) < abs($1.date.timeIntervalSince(sel)) }) {
            return Calendar.current.startOfDay(for: nearest.date)
        }
        return Calendar.current.startOfDay(for: Date())
    }

    private var currentNavIndex: Int {
        sortedNavigableDates.firstIndex { Calendar.current.isDate($0, inSameDayAs: currentNavDate) }
            ?? sortedNavigableDates.count - 1
    }

    private func navigateDate(_ direction: Int) {
        let newIdx = currentNavIndex + direction
        guard sortedNavigableDates.indices.contains(newIdx) else { return }
        let newDate = sortedNavigableDates[newIdx]
        if Calendar.current.isDateInToday(newDate) {
            selectedDate = nil
        } else {
            selectedDate = newDate
        }
    }

    private var dateNavLabel: String {
        if let m = displayedMetrics {
            if Calendar.current.isDateInToday(m.date) { return "Today" }
            return m.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        }
        return "Today"
    }

    // MARK: - Selected-date helpers
    // When the user taps a date in the history chart, these drive the timeline/breakdown cards.

    private var displayedMetrics: DailyMetrics? {
        guard let sel = selectedDate else { return nil }
        return history.min { abs($0.date.timeIntervalSince(sel)) < abs($1.date.timeIntervalSince(sel)) }
    }

    private var displayedScore: Double {
        displayedMetrics?.ayurvedicSleepPoints ?? score
    }

    private var displayedSleepStart: Date? {
        displayedMetrics?.sleepStartTime ?? sleepStart
    }

    private var displayedSleepEnd: Date? {
        displayedMetrics?.sleepEndTime ?? sleepEnd
    }

    private var displayedEveningDate: Date {
        guard let m = displayedMetrics else { return eveningDate }
        return Calendar.current.date(byAdding: .day, value: -1, to: m.date) ?? eveningDate
    }

    private var displayedDateLabel: String? {
        guard let m = displayedMetrics else { return nil }
        return Calendar.current.isDateInToday(m.date) ? nil : m.date.formatted(.dateTime.month(.abbreviated).day())
    }

    private var scoreColor: Color {
        Color(hex: AyurvedicSleepCalculator.guidanceHex(for: displayedScore))
    }

    private var breakdown: [AyurvedicSleepCalculator.WindowBreakdown] {
        guard let s = displayedSleepStart, let e = displayedSleepEnd else { return [] }
        return AyurvedicSleepCalculator.breakdown(start: s, end: e, eveningDate: displayedEveningDate)
    }

    private var tip: String? {
        guard let s = displayedSleepStart, let e = displayedSleepEnd else { return nil }
        return AyurvedicSleepCalculator.improvementTip(
            sleepStart: s, sleepEnd: e, currentScore: displayedScore, eveningDate: displayedEveningDate
        )
    }

    private var chartData: [(Date, Double)] {
        let cutoff = Calendar.current.date(
            byAdding: .day, value: -selectedRange.days, to: Date()
        )!
        return history
            .filter { $0.date >= cutoff }
            .compactMap { m in
                guard let pts = m.ayurvedicSleepPoints else { return nil }
                return (m.date, pts)
            }
            .sorted { $0.0 < $1.0 }
    }

    private var selectedValue: String? {
        guard let date = selectedDate else { return nil }
        let nearest = chartData.min { abs($0.0.timeIntervalSince(date)) < abs($1.0.timeIntervalSince(date)) }
        return nearest.map { String(format: "%.1f / 10", $0.1) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.somaBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        // Date navigation
                        HStack {
                            Button { navigateDate(-1) } label: {
                                Image(systemName: "chevron.left.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(currentNavIndex > 0 ? Color.somaBlue : Color.somaGray.opacity(0.4))
                            }
                            .disabled(currentNavIndex <= 0)

                            Spacer()
                            VStack(spacing: 2) {
                                Text(dateNavLabel)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Text("Tap chart to jump to a date")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()

                            Button { navigateDate(1) } label: {
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(currentNavIndex < sortedNavigableDates.count - 1 ? Color.somaBlue : Color.somaGray.opacity(0.4))
                            }
                            .disabled(currentNavIndex >= sortedNavigableDates.count - 1)
                        }
                        .padding(.horizontal)

                        scoreCard
                        timelineCard
                        if !breakdown.isEmpty { breakdownCard }
                        if let tip { tipCard(tip) }
                        if let mins = napDurationMinutes { napCard(minutes: mins) }
                        historyChart
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Ayurvedic Sleep Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color.somaBlue)
                }
            }
        }
    }

    // MARK: - Score Card

    private var scoreCard: some View {
        VStack(spacing: 6) {
            if let label = displayedDateLabel {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", displayedScore))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(scoreColor)
                Text("/ 10")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            Text(AyurvedicSleepCalculator.guidanceText(for: displayedScore))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(scoreColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(scoreColor.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - History Chart

    private var historyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Range picker
            Picker("Range", selection: $selectedRange) {
                ForEach(TrendsViewModel.TimeRange.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedRange) { _, _ in selectedDate = nil }

            // Chart header
            HStack {
                Text("Score Trend")
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

            if chartData.isEmpty {
                Text("No history available for this range.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                Chart {
                    ForEach(chartData, id: \.0) { date, value in
                        LineMark(x: .value("Date", date), y: .value("Score", value))
                            .foregroundStyle(scoreColor)
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Date", date), y: .value("Score", value))
                            .foregroundStyle(scoreColor)
                            .symbolSize(25)
                        AreaMark(x: .value("Date", date), y: .value("Score", value))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [scoreColor.opacity(0.3), scoreColor.opacity(0)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                    }
                    if let sel = selectedDate {
                        RuleMark(x: .value("Selected", sel))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                    }
                }
                .chartYScale(domain: 0...10)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: axisDayStride)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: axisDayFormat)
                    }
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .chartXSelection(value: $selectedDate)
                .frame(height: 200)
            }
        }
        .padding(14)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Timeline Card

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sleep Timeline")
                    .font(.headline)
                    .foregroundColor(.primary)
                if let label = displayedDateLabel {
                    Spacer()
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            SleepTimelineView(sleepStart: displayedSleepStart, sleepEnd: displayedSleepEnd, eveningDate: displayedEveningDate)
                .frame(height: 72)
        }
        .padding(14)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Breakdown Card

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Window Breakdown")
                    .font(.headline)
                    .foregroundColor(.primary)
                if let label = displayedDateLabel {
                    Spacer()
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            ForEach(breakdown.indices, id: \.self) { i in
                let w = breakdown[i]
                if w.hoursSlept > 0 {
                    HStack {
                        Circle()
                            .fill(windowColor(index: i))
                            .frame(width: 8, height: 8)
                        Text(w.label)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(String(format: "%.1fh × %.2g", w.hoursSlept, w.pointsPerHour))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "= %.2f pts", w.earned))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .frame(width: 70, alignment: .trailing)
                    }
                    if i < breakdown.count - 1 {
                        Divider()
                    }
                }
            }

            Divider()
            HStack {
                Text("Total")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
                Text(String(format: "%.2f / %.0f pts", breakdown.map(\.earned).reduce(0, +), AyurvedicSleepCalculator.maxRawPoints))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(scoreColor)
            }
        }
        .padding(14)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Tip Card

    private func tipCard(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(Color.somaYellow)
                .font(.body)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.somaYellow.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.somaYellow.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Nap Card

    private func napCard(minutes: Double) -> some View {
        let hours = Int(minutes) / 60
        let mins  = Int(minutes) % 60
        let durationStr = hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"

        let (icon, message): (String, String) = {
            if let start = napStartTime {
                let hour = Calendar.current.component(.hour, from: start)
                if hour >= 16 { // after 4 PM
                    return ("exclamationmark.triangle.fill",
                            "Late nap detected (\(durationStr)). This could delay your nighttime sleep timing.")
                }
            }
            if minutes > 60 {
                return ("moon.zzz",
                        "Long daytime nap detected (\(durationStr)). This may reduce sleep pressure and delay nighttime sleep.")
            }
            return ("moon.zzz",
                    "Short nap detected (\(durationStr)). This may help recovery without affecting night sleep.")
        }()

        let accentColor = minutes > 60 || (napStartTime.map { Calendar.current.component(.hour, from: $0) >= 16 } ?? false)
            ? Color.somaOrange
            : Color(hex: "5C6BC0")

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(accentColor)
                Text("Daytime Sleep")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Not included in Ayurvedic score — scored on night sleep only.")
                .font(.caption)
                .foregroundColor(Color.somaGray)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(accentColor.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func windowColor(index: Int) -> Color {
        // Dark green → light green, matching the timeline band
        switch index {
        case 0: return Color(hex: "27642A")           // Before midnight — dark green
        case 1: return Color(hex: "388E3C")           // 12–3 AM — medium green
        case 2: return Color(hex: "49B84E")           // 3–6 AM — mid-light green
        case 3: return Color(hex: "73C877")
        case 4: return Color(hex: "9DD9A0")  // 6–8 AM — light green
        default: return Color(hex: "9DD9A0")
        }
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

// MARK: - Sleep Timeline View

struct SleepTimelineView: View {
    let sleepStart: Date?
    let sleepEnd: Date?
    let eveningDate: Date

    // Timeline: 9 PM → 8 AM only (11 hours)
    private let displayHours: Double = 11

    // Window boundary fractions (9PM=0, midnight=3/11, 3AM=6/11, 6AM=9/11, 8AM=1)
    private let windowFractions: [Double] = [0, 3.0/11.0, 6.0/11.0, 9.0/11.0, 1.0]
    private let windowColors: [Color] = [
        Color(hex: "27642A"),  // 9 PM–midnight — dark green
        Color(hex: "388E3C"),  // midnight–3 AM — medium green
        Color(hex: "49B84E"),  // 3–6 AM — mid-light green
        Color(hex: "9DD9A0"),  // 6–8 AM — light green
    ]
    private let timeLabels   = ["9 PM", "12 AM", "3 AM", "6 AM", "8 AM"]
    private let weightLabels = ["2 pts/h", "1 pt/h", "0.5 pt/h", "0.25 pt/h"]

    // Fraction of date along the 9 PM → 8 AM axis
    private func fraction(for date: Date) -> Double {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: eveningDate)
        comps.hour = 21; comps.minute = 0; comps.second = 0
        let start = cal.date(from: comps)!
        return max(0, min(1, date.timeIntervalSince(start) / (displayHours * 3600)))
    }

    var body: some View {
        VStack(spacing: 4) {
            // Colored band
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Four window segments
                    HStack(spacing: 0) {
                        ForEach(0..<4, id: \.self) { i in
                            windowColors[i].opacity(0.65)
                                .frame(width: (windowFractions[i + 1] - windowFractions[i]) * geo.size.width)
                        }
                    }

                    // Dividers at midnight, 3 AM, 6 AM
                    ForEach(1..<4, id: \.self) { i in
                        Rectangle()
                            .fill(Color.black.opacity(0.18))
                            .frame(width: 1)
                            .offset(x: windowFractions[i] * geo.size.width)
                    }

                    // Sleep start/end markers — purple vertical lines
                    if let s = sleepStart, let e = sleepEnd {
                        let sf = fraction(for: s)
                        let ef = fraction(for: e)
                        // Start line
                        Rectangle()
                            .fill(Color.somaPurple)
                            .frame(width: 2)
                            .offset(x: sf * geo.size.width)
                        // End line
                        Rectangle()
                            .fill(Color.somaPurple)
                            .frame(width: 2)
                            .offset(x: ef * geo.size.width)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
                )
            }
            .frame(height: 40)

            // Time labels — leading edge of each window segment + trailing "8 AM"
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { i in
                        HStack(spacing: 0) {
                            Text(timeLabels[i])
                                .font(.caption2)
                                .foregroundColor(Color.somaGray)
                            Spacer()
                        }
                        .frame(width: (windowFractions[i + 1] - windowFractions[i]) * geo.size.width)
                    }
                    Text(timeLabels[4])
                        .font(.caption2)
                        .foregroundColor(Color.somaGray)
                }
            }
            .frame(height: 14)

            // Weight labels centered in each window
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { i in
                        Text(weightLabels[i])
                            .font(.system(size: 9))
                            .foregroundColor(Color.somaGray.opacity(0.7))
                            .frame(width: (windowFractions[i + 1] - windowFractions[i]) * geo.size.width)
                    }
                }
            }
            .frame(height: 12)
        }
    }
}
