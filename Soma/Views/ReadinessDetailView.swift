import SwiftUI
import Charts

struct ReadinessDetailView: View {
    let guidance: DailyTrainingGuidance
    let viewModel: DashboardViewModel

    @State private var selectedRange: TrendsViewModel.TimeRange = .week
    @Environment(\.dismiss) private var dismiss

    private var factors: ReadinessFactors { guidance.factors }
    private var score: Double { guidance.readinessScore }
    private var state: ColorState { ColorState.recovery(score: score) }

    private var history: [DailyMetrics] {
        viewModel.loadHistory(days: selectedRange.days)
    }

    /// Historical readiness scores for the trend chart.
    /// Falls back to a weighted composite from recoveryScore + sleepScore when
    /// the stored readinessScore field is nil (older data before it was persisted).
    private var readinessTrend: [(Date, Double)] {
        history
            .map { m -> (Date, Double) in
                let r = m.readinessScore ?? (m.recoveryScore * 0.6 + m.sleepScore * 0.4)
                return (m.date, r)
            }
            .sorted { $0.0 < $1.0 }
    }

    // Compute each component's point contribution for the breakdown card
    private var hasHRV: Bool { factors.hrvRatio != nil }
    private var recoveryWeight: Double { hasHRV ? 0.5 : 0.6 }
    private var sleepWeight:    Double { hasHRV ? 0.3 : 0.4 }

    private var recoveryContrib: Double { factors.recoveryScore * recoveryWeight }
    private var sleepContrib:    Double { factors.sleepScore    * sleepWeight }
    private var hrvContrib:      Double { (factors.hrvRatio ?? 0) * 100.0 * 0.2 }
    private var baseScore:       Double { recoveryContrib + sleepContrib + (hasHRV ? hrvContrib : 0) }

    private var totalPenalty: Int {
        var p = 0
        if factors.sleepDebtHours > 1.0       { p -= 10 }
        if (factors.rhrDelta ?? 0) > 5        { p -= 10 }
        if factors.yesterdayStrain > 80        { p -= 10 }
        return p
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.somaBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        if viewModel.isBaselineBuilding {
                            baselineBanner
                        }
                        scoreRingCard
                        breakdownCard
                        if totalPenalty < 0 { penaltiesCard }
                        signalsCard
                        trendCard
                        trainingCard
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Readiness")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color.somaBlue)
                }
            }
        }
    }

    // MARK: - Score Ring Card

    private var scoreRingCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(white: 0.12), lineWidth: 20)
                    .frame(width: 170, height: 170)

                Circle()
                    .trim(from: 0, to: min(1, score / 100))
                    .stroke(
                        AngularGradient(
                            // With rotationEffect(-90°) + startAngle(-90°):
                            //   arc trim t  →  gradient location 0.25 + t
                            //   score 50%   →  location 0.75  = yellow  (key constraint)
                            // Band widths: red 0-30 (30%), orange 30-50 (20%),
                            //              yellow 50-65 (15%), light green 65-75 (10%), green 75-100
                            stops: [
                                // Wrap region — visible for scores 75-100%
                                // score 75 → location 1.00 (light green), score 80 → 0.05 (green)
                                .init(color: Color.somaLightGreen, location: 0.00), // score ~75
                                .init(color: Color.somaLightGreen, location: 0.03), // score ~78
                                .init(color: Color.somaGreen,      location: 0.05), // score 80
                                .init(color: Color.somaGreen,      location: 0.22), // score ~97
                                // Red zone — scores 0–25
                                .init(color: Color.somaRed,        location: 0.25), // score 0
                                .init(color: Color.somaRed,        location: 0.45), // score 20
                                // Orange zone — scores 25–45
                                .init(color: Color.somaOrange,     location: 0.50), // score 25
                                .init(color: Color.somaOrange,     location: 0.65), // score 40
                                // Yellow zone — scores 45–65
                                .init(color: Color.somaYellow,     location: 0.70), // score 45
                                .init(color: Color.somaYellow,     location: 0.85), // score 60
                                // Light green zone — scores 65–80
                                .init(color: Color.somaLightGreen, location: 0.90), // score 65
                                .init(color: Color.somaLightGreen, location: 1.00), // score 75
                            ],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 170, height: 170)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.2), value: score)

                VStack(spacing: 2) {
                    Text("\(Int(score.rounded()))")
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                    Text("READINESS")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .tracking(1.5)
                }
            }

            Text(headline)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            Text(state.label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(state.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(state.color.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }

    private var headline: String {
        switch score {
        case 80...100: return "Peak Performance — Go All In"
        case 65..<80:  return "Strong Day — Train Hard"
        case 45..<65:  return "Moderate Day — Steady Training"
        case 25..<45:  return "Low Readiness — Go Light"
        default:       return "Recovery First — Rest Up"
        }
    }

    // MARK: - Score Breakdown Card

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(icon: "function", title: "How Your Score Was Built", color: Color.somaBlue)

            componentRow(
                icon: "heart.fill",
                label: "Recovery Score",
                value: String(format: "%.0f / 100", factors.recoveryScore),
                weight: String(format: "%.0f%% weight", recoveryWeight * 100),
                contribution: recoveryContrib,
                color: ColorState.recovery(score: factors.recoveryScore).color
            )

            Divider()

            componentRow(
                icon: "moon.zzz.fill",
                label: "Sleep Score",
                value: String(format: "%.0f / 100", factors.sleepScore),
                weight: String(format: "%.0f%% weight", sleepWeight * 100),
                contribution: sleepContrib,
                color: Color.somaBlue
            )

            if let ratio = factors.hrvRatio {
                Divider()
                componentRow(
                    icon: "waveform.path.ecg",
                    label: "HRV Ratio",
                    value: String(format: "%.2f×", ratio),
                    weight: "20% weight",
                    contribution: ratio * 100.0 * 0.2,
                    color: Color.somaPurple
                )
            } else {
                Divider()
                HStack(spacing: 12) {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(Color.somaGray)
                        .frame(width: 20)
                    Text("HRV baseline not yet built — weight redistributed to Recovery & Sleep")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            HStack {
                Text("Base Score")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
                Text(String(format: "%.1f", baseScore))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }

            if totalPenalty < 0 {
                HStack {
                    Text("Penalties")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(totalPenalty) pts")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.somaRed)
                }

                HStack {
                    Text("Final Score")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(String(format: "%.0f", max(0, baseScore + Double(totalPenalty))))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(state.color)
                }
            }
        }
        .padding(14)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }

    private func componentRow(icon: String, label: String, value: String, weight: String, contribution: Double, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Text(value + " · " + weight)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(String(format: "+%.1f pts", contribution))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }

    // MARK: - Penalties Card

    private var penaltiesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "minus.circle.fill", title: "Penalties Applied", color: Color.somaOrange)

            if factors.sleepDebtHours > 1.0 {
                penaltyRow(
                    icon: "zzz",
                    label: "Sleep debt over 1 hour",
                    detail: String(format: "%.1fh owed tonight", factors.sleepDebtHours),
                    points: -10
                )
            }

            if let delta = factors.rhrDelta, delta > 5 {
                penaltyRow(
                    icon: "heart.slash.fill",
                    label: "Resting HR elevated",
                    detail: String(format: "+%.0f bpm above your baseline", delta),
                    points: -10
                )
            }

            if factors.yesterdayStrain > 80 {
                penaltyRow(
                    icon: "flame.fill",
                    label: "Very high strain yesterday",
                    detail: String(format: "%.0f/100 — body still absorbing load", factors.yesterdayStrain),
                    points: -10
                )
            }
        }
        .padding(14)
        .background(Color.somaOrange.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.somaOrange.opacity(0.25), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    private func penaltyRow(icon: String, label: String, detail: String, points: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color.somaOrange)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("\(points) pts")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(Color.somaRed)
        }
    }

    // MARK: - Key Signals Card

    private var signalsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(icon: "waveform.path.ecg.rectangle.fill", title: "Key Signals", color: Color.somaPurple)

            if let ratio = factors.hrvRatio {
                let pct = Int((ratio - 1.0) * 100)
                let color: Color = ratio >= 1.0 ? .somaGreen : ratio > 0.85 ? .somaYellow : .somaRed
                let note = ratio < 0.85
                    ? "Significantly suppressed — largest driver of today's low readiness"
                    : ratio > 1.10 ? "Above baseline — well recovered"
                    : "Within normal range — neutral"
                signalRow(icon: "waveform.path.ecg", label: "HRV vs Baseline",
                          value: String(format: "%@%d%%", pct >= 0 ? "+" : "", pct), note: note, color: color)
                Divider()
            }

            if let delta = factors.rhrDelta {
                let color: Color = delta <= 0 ? .somaGreen : delta <= 5 ? .somaYellow : .somaRed
                let note = delta > 5 ? "Elevated — -10 pt penalty applied"
                         : delta < -3 ? "Below baseline — a positive sign"
                         : "Near baseline — no penalty"
                signalRow(icon: "heart.fill", label: "Resting HR vs Baseline",
                          value: String(format: "%@%.0f bpm", delta >= 0 ? "+" : "", delta), note: note, color: color)
                Divider()
            }

            let debtColor: Color = factors.sleepDebtHours <= 0.25 ? .somaGreen
                                 : factors.sleepDebtHours <= 1.0  ? .somaYellow : .somaOrange
            let debtNote = factors.sleepDebtHours > 1.0 ? "Over 1h threshold — -10 pt penalty applied"
                         : factors.sleepDebtHours > 0.25 ? "Minor debt — no penalty"
                         : "No debt — good"
            signalRow(icon: "bed.double.fill", label: "Sleep Debt",
                      value: String(format: "%.1fh", factors.sleepDebtHours), note: debtNote, color: debtColor)
            Divider()

            let strainColor: Color = factors.yesterdayStrain <= 50 ? .somaGreen
                                   : factors.yesterdayStrain <= 80 ? .somaYellow : .somaRed
            let strainNote = factors.yesterdayStrain > 80 ? "Very high — -10 pt penalty applied"
                           : factors.yesterdayStrain > 50 ? "Moderate-high — no penalty"
                           : "Low — no impact on readiness"
            signalRow(icon: "flame.fill", label: "Yesterday's Strain",
                      value: String(format: "%.0f / 100", factors.yesterdayStrain),
                      note: strainNote, color: strainColor)

            if let acr = factors.acrRatio {
                Divider()
                let acrColor: Color = acr > 1.3 ? .somaOrange : acr < 0.8 ? .somaBlue : .somaGreen
                let acrNote = acr > 1.3 ? "Training spike (>1.3) — activity capped to Light"
                            : acr < 0.8 ? "Training load has been low recently"
                            : "Load is well balanced (0.8–1.3)"
                signalRow(icon: "chart.line.uptrend.xyaxis", label: "Training Load (ACR)",
                          value: String(format: "%.2f", acr), note: acrNote, color: acrColor)
            }
        }
        .padding(14)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }

    private func signalRow(icon: String, label: String, value: String, note: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Text(note)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }

    // MARK: - Trend Chart

    private var trendCard: some View {
        let data = readinessTrend
        let accent = Color.somaPurple

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(icon: "chart.line.uptrend.xyaxis", title: "Readiness Trend", color: accent)
                Spacer()
                Picker("Range", selection: $selectedRange) {
                    ForEach([TrendsViewModel.TimeRange.week, .twoWeeks, .month], id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 156)
            }

            Chart(data, id: \.0) { date, val in
                AreaMark(
                    x: .value("Date", date, unit: .day),
                    y: .value("Readiness", val)
                )
                .foregroundStyle(LinearGradient(
                    colors: [accent.opacity(0.30), accent.opacity(0)],
                    startPoint: .top, endPoint: .bottom
                ))
                LineMark(
                    x: .value("Date", date, unit: .day),
                    y: .value("Readiness", val)
                )
                .foregroundStyle(accent)
                .interpolationMethod(.catmullRom)
                PointMark(
                    x: .value("Date", date, unit: .day),
                    y: .value("Readiness", val)
                )
                .foregroundStyle(accent)
                .symbolSize(22)
            }
            .chartYScale(domain: 0...100)
            .chartXAxis {
                let stride = selectedRange == .week ? 1 : selectedRange == .twoWeeks ? 2 : 5
                AxisMarks(values: .stride(by: .day, count: stride)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 190)
        }
        .padding(14)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }

    // MARK: - Training Guidance Card (matches Dashboard)

    private var trainingCard: some View {
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
                    Text("\(Int(score.rounded()))")
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
                        ForEach(guidance.suggestedWorkouts, id: \.self) { w in
                            Text(w)
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
        .padding(.horizontal)
    }

    // MARK: - Baseline Banner

    private var baselineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.badge.fill")
                .foregroundColor(Color.somaYellow)
            Text("Building baseline — scores improve after 7 days of Apple Watch data.")
                .font(.caption)
                .foregroundColor(Color.somaYellow)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.somaYellow.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal)
    }

    // MARK: - Shared Helpers

    private func sectionHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
        }
    }
}

#if DEBUG
#Preview("Strong Day") {
    NavigationStack {
        ReadinessDetailView(guidance: .mock, viewModel: .preview)
    }
}

#Preview("Low Readiness") {
    NavigationStack {
        ReadinessDetailView(guidance: .mockLow, viewModel: .preview)
    }
}
#endif
