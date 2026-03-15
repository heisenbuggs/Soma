import SwiftUI

struct AyurvedicSleepDetailView: View {
    let score: Double
    let sleepStart: Date?
    let sleepEnd: Date?
    let eveningDate: Date

    @Environment(\.dismiss) private var dismiss

    private var scoreColor: Color {
        Color(hex: AyurvedicSleepCalculator.guidanceHex(for: score))
    }

    private var breakdown: [AyurvedicSleepCalculator.WindowBreakdown] {
        guard let s = sleepStart, let e = sleepEnd else { return [] }
        return AyurvedicSleepCalculator.breakdown(start: s, end: e, eveningDate: eveningDate)
    }

    private var tip: String? {
        guard let s = sleepStart, let e = sleepEnd else { return nil }
        return AyurvedicSleepCalculator.improvementTip(
            sleepStart: s, sleepEnd: e, currentScore: score, eveningDate: eveningDate
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.somaBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        scoreCard
                        timelineCard
                        if !breakdown.isEmpty { breakdownCard }
                        if let tip { tipCard(tip) }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Ayurvedic Sleep Points")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(hex: "2979FF"))
                }
            }
        }
    }

    // MARK: - Score Card

    private var scoreCard: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", score))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(scoreColor)
                Text("/ 10")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            Text(AyurvedicSleepCalculator.guidanceText(for: score))
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

    // MARK: - Timeline Card

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Timeline")
                .font(.headline)
                .foregroundColor(.primary)

            SleepTimelineView(sleepStart: sleepStart, sleepEnd: sleepEnd, eveningDate: eveningDate)
                .frame(height: 72)
        }
        .padding(14)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Breakdown Card

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Window Breakdown")
                .font(.headline)
                .foregroundColor(.primary)

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
                .foregroundColor(Color(hex: "FFD600"))
                .font(.body)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "FFD600").opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color(hex: "FFD600").opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func windowColor(index: Int) -> Color {
        switch index {
        case 0: return Color(hex: "00C853")
        case 1: return Color(hex: "2979FF")
        case 2: return Color(hex: "FFD600")
        default: return Color(hex: "FF9100")
        }
    }
}

// MARK: - Sleep Timeline View

struct SleepTimelineView: View {
    let sleepStart: Date?
    let sleepEnd: Date?
    let eveningDate: Date

    // Timeline spans 5 PM → 8 AM (15 hours total display window)
    private let displayHours: Double = 15
    private let timelineStartOffset: Double = -4 // hours before 9 PM = 5 PM

    private var windows: [(fraction: ClosedRange<Double>, color: Color, label: String)] {
        [
            (0.0...4/displayHours,  Color(hex: "8E8E93").opacity(0.3), ""),           // 5–9 PM (pre-window)
            (4/displayHours...7/displayHours,  Color(hex: "00C853"),   "2 pts"),      // 9 PM–12 AM (3 h)
            (7/displayHours...10/displayHours, Color(hex: "2979FF"),   "1 pt"),       // 12–3 AM  (3 h)
            (10/displayHours...13/displayHours, Color(hex: "FFD600"),  "0.5"),        // 3–6 AM   (3 h)
            (13/displayHours...1.0,             Color(hex: "FF9100"),  "0.25"),       // 6–8 AM   (2 h)
        ]
    }

    // Convert a wall-clock Date to a 0–1 fraction along the display timeline
    private func fraction(for date: Date) -> Double {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: eveningDate)
        comps.hour = 17; comps.minute = 0; comps.second = 0
        let timelineStart = cal.date(from: comps)!
        let totalSeconds = displayHours * 3600
        let offset = date.timeIntervalSince(timelineStart)
        return max(0, min(1, offset / totalSeconds))
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background window segments
                    HStack(spacing: 0) {
                        ForEach(windows.indices, id: \.self) { i in
                            let w = windows[i]
                            let width = (w.fraction.upperBound - w.fraction.lowerBound) * geo.size.width
                            Rectangle()
                                .fill(w.color.opacity(0.25))
                                .frame(width: width)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    // Window dividers
                    ForEach([4, 7, 10, 13], id: \.self) { hour in
                        let x = (Double(hour) / displayHours) * geo.size.width
                        Rectangle()
                            .fill(Color.secondary.opacity(0.25))
                            .frame(width: 1)
                            .offset(x: x)
                    }

                    // User sleep bar
                    if let start = sleepStart, let end = sleepEnd {
                        let startF = fraction(for: start)
                        let endF   = fraction(for: end)
                        let barX   = startF * geo.size.width
                        let barW   = max(4, (endF - startF) * geo.size.width)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(hex: "2979FF").opacity(0.85))
                            .frame(width: barW)
                            .offset(x: barX)
                    }
                }
                .frame(height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }
            .frame(height: 40)

            // Time labels
            HStack(spacing: 0) {
                Spacer().frame(width: (4 / displayHours) * UIScreen.main.bounds.width - 32)
                ForEach(["9 PM", "12 AM", "3 AM", "6 AM", "8 AM"], id: \.self) { label in
                    Text(label)
                        .font(.caption2)
                        .foregroundColor(Color(hex: "8E8E93"))
                    if label != "8 AM" {
                        Spacer()
                    }
                }
            }

            // Window weight labels
            HStack(spacing: 0) {
                Spacer().frame(width: (4 / displayHours) * UIScreen.main.bounds.width - 32)
                ForEach(["2pts/h", "1pt/h", "0.5pt/h", "0.25pt/h"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "8E8E93").opacity(0.7))
                    if label != "0.25pt/h" {
                        Spacer()
                    }
                }
            }
        }
    }
}
