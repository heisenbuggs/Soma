import SwiftUI

// MARK: - VITALS TAB
// "What is happening physiologically?" — health monitoring.
// Vitals score → per-metric rows (current / baseline / deviation / 7-day trend)
// → Health Monitor (fused anomaly signals).

struct VitalsView: View {
    @ObservedObject var viewModel: DashboardViewModel

    private var metrics: DailyMetrics { viewModel.todayMetrics }

    var body: some View {
        NavigationStack {
            ZStack {
                SomaGradient.canvas(tint: .somaBlue)
                ScrollView {
                    VStack(spacing: Space.lg) {
                        vitalsScoreCard
                        metricsSection
                        healthMonitorSection
                        Color.clear.frame(height: 12)
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.top, Space.sm)
                }
                .scrollIndicators(.hidden)
                .refreshable { await viewModel.refresh(force: true)?.value }
            }
            .navigationTitle("Vitals")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: Vitals Score

    /// Number of calibration days still needed before the baseline-relative vitals
    /// score is fully trustworthy. The baseline needs `minDaysRequired` (7) days of
    /// data; we count distinct days that carry a core vital (HRV or resting HR).
    private var calibrationDaysLeft: Int {
        let history = viewModel.loadHistory(days: 30)
        let daysWithData = history.filter { $0.hrvAverage != nil || $0.restingHR != nil }.count
        return max(0, BaselineCalculator.minDaysRequired - daysWithData)
    }

    private var vitalsScoreCard: some View {
        let score = vitalsScore()
        let state = vitalsState(score)
        let daysLeft = calibrationDaysLeft
        return HStack(spacing: Space.lg) {
            ReadinessRing(score: score, title: "VITALS", stateLabel: state.label,
                          color: state.color, size: 130, lineWidth: 12)
            VStack(alignment: .leading, spacing: 6) {
                Text("VITALS STATUS").eyebrow()
                Text(state.label)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                // While the baseline is still building, the score is shown but flagged
                // as calibrating with the number of days remaining.
                if daysLeft > 0 {
                    CalibratingTag(daysLeft: daysLeft)
                }
                Text(daysLeft > 0 ? calibratingSummary(daysLeft: daysLeft) : vitalsSummary(score))
                    .font(.system(size: 13))
                    .foregroundStyle(Color.somaTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .premiumCard(cornerRadius: Radius.xl, glow: state.color)
    }

    private func calibratingSummary(daysLeft: Int) -> String {
        "Building your personal baseline — keep wearing your watch for \(daysLeft) more day\(daysLeft == 1 ? "" : "s") to fully calibrate this score."
    }

    // MARK: Metrics

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(title: "Metrics", subtitle: "Versus your personal baseline")
            VStack(spacing: 12) {
                ForEach(vitals()) { vital in
                    VitalRow(vital: vital)
                }
            }
        }
    }

    // MARK: Health Monitor

    private var healthMonitorSection: some View {
        let signals = healthSignals()
        return VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(title: "Health Monitor", subtitle: "Combined physiological signals")
            if signals.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.title3).foregroundStyle(Color.somaGreen)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("All clear").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                        Text("No physiological anomalies detected today.")
                            .font(.footnote).foregroundStyle(Color.somaTextSecondary)
                    }
                    Spacer()
                }
                .premiumCard(cornerRadius: Radius.md, padding: 14, glow: .somaGreen)
            } else {
                ForEach(signals) { s in
                    AlertRow(icon: s.icon, title: s.title, detail: s.detail, color: s.color)
                }
            }
        }
    }

    // MARK: - Vital model

    struct Vital: Identifiable {
        let id = UUID()
        let icon: String
        let name: String
        let valueText: String
        let unit: String
        let baselineText: String
        let deviationText: String
        let color: Color
        let trend: SignalTrend
        let history: [Double]
    }

    private func vitals() -> [Vital] {
        let history = viewModel.loadHistory(days: 30)
        func hist(_ kp: KeyPath<DailyMetrics, Double?>) -> [Double] {
            history.suffix(7).compactMap { $0[keyPath: kp] }
        }

        var out: [Vital] = []

        // HRV
        let hrvBase = BaselineCalculator.computeHRVBaseline(from: BaselineCalculator.extractHistory(from: history, \.hrvAverage))
        out.append(buildVital(
            icon: "waveform.path.ecg", name: "HRV", value: metrics.hrvAverage, unit: "ms",
            baseline: hrvBase, higherIsBetter: true, color: .somaPurple,
            history: hist(\.hrvAverage), fmt: { String(format: "%.0f", $0) }))

        // Resting HR
        let rhrBase = BaselineCalculator.computeRHRBaseline(from: BaselineCalculator.extractHistory(from: history, \.restingHR))
        out.append(buildVital(
            icon: "heart.fill", name: "Resting Heart Rate", value: metrics.restingHR, unit: "bpm",
            baseline: rhrBase, higherIsBetter: false, color: .somaOrange,
            history: hist(\.restingHR), fmt: { String(format: "%.0f", $0) }))

        // Respiratory rate
        let rrBase = BaselineCalculator.computeBaseline(from: BaselineCalculator.extractHistory(from: history, \.respiratoryRate))
        out.append(buildVital(
            icon: "lungs.fill", name: "Respiratory Rate", value: metrics.respiratoryRate, unit: "br/min",
            baseline: rrBase, higherIsBetter: false, color: .somaBlue,
            history: hist(\.respiratoryRate), fmt: { String(format: "%.1f", $0) }))

        // SpO2
        let spo2Base = BaselineCalculator.computeBaseline(from: BaselineCalculator.extractHistory(from: history, \.bloodOxygen))
        out.append(buildVital(
            icon: "drop.fill", name: "Blood Oxygen", value: metrics.bloodOxygen, unit: "%",
            baseline: spo2Base, higherIsBetter: true, color: .somaLightGreen,
            history: hist(\.bloodOxygen), fmt: { String(format: "%.0f", $0) }))

        // Wrist temperature (already a deviation from baseline)
        if let t = metrics.wristTempDeviation {
            let warm = t > 0.4
            out.append(Vital(
                icon: "thermometer.medium", name: "Wrist Temperature",
                valueText: String(format: "%+.1f", t), unit: "°C",
                baselineText: "Baseline 0.0 °C",
                deviationText: warm ? "Elevated" : "Normal range",
                color: warm ? .somaRed : .somaGreen,
                trend: warm ? .up : .flat,
                history: hist(\.wristTempDeviation)))
        }

        return out
    }

    private func buildVital(icon: String, name: String, value: Double?, unit: String,
                            baseline: Double?, higherIsBetter: Bool, color: Color,
                            history: [Double], fmt: (Double) -> String) -> Vital {
        let dev = deviation(value: value, baseline: baseline, higherIsBetter: higherIsBetter)
        return Vital(
            icon: icon, name: name,
            valueText: value.map(fmt) ?? "—", unit: unit,
            baselineText: baseline.map { "Baseline \(fmt($0)) \(unit)" } ?? "Building baseline",
            deviationText: dev.text,
            color: dev.healthy ? color : dev.color,
            trend: dev.trend,
            history: history)
    }

    // MARK: - Derivations

    private struct Dev { let text: String; let trend: SignalTrend; let healthy: Bool; let color: Color }
    private func deviation(value: Double?, baseline: Double?, higherIsBetter: Bool) -> Dev {
        guard let v = value, let b = baseline, b > 0 else {
            return Dev(text: "—", trend: .flat, healthy: true, color: .somaGray)
        }
        let pct = (v / b - 1.0) * 100
        if abs(pct) < 4 { return Dev(text: "On baseline", trend: .flat, healthy: true, color: .somaGreen) }
        let above = pct > 0
        let good = higherIsBetter ? above : !above
        let word = above ? "above" : "below"
        return Dev(text: "\(abs(Int(pct)))% \(word)",
                   trend: above ? .up : .down,
                   healthy: good,
                   color: good ? .somaGreen : .somaOrange)
    }

    /// Penalty-based 0–100 composite of how close today's vitals sit to healthy.
    private func vitalsScore() -> Double {
        let history = viewModel.loadHistory(days: 30)
        var score = 100.0
        if let hrv = metrics.hrvAverage,
           let base = BaselineCalculator.computeHRVBaseline(from: BaselineCalculator.extractHistory(from: history, \.hrvAverage)), base > 0 {
            let drop = max(0, (1 - hrv / base)) * 100
            score -= min(25, drop * 0.6)
        }
        if let rhr = metrics.restingHR,
           let base = BaselineCalculator.computeRHRBaseline(from: BaselineCalculator.extractHistory(from: history, \.restingHR)), base > 0 {
            score -= min(20, max(0, rhr - base) * 2.5)
        }
        if let rr = metrics.respiratoryRate, rr > 18 { score -= min(15, (rr - 18) * 4) }
        if let spo2 = metrics.bloodOxygen, spo2 < 95 { score -= min(20, (95 - spo2) * 5) }
        if let t = metrics.wristTempDeviation, t > 0.4 { score -= min(20, (t - 0.4) * 25) }
        return max(0, min(100, score))
    }

    private func vitalsState(_ s: Double) -> ColorState {
        switch s {
        case 85...100: return .green(label: "Excellent")
        case 70..<85:  return .lightGreen(label: "Healthy")
        case 50..<70:  return .yellow(label: "Watch")
        case 30..<50:  return .orange(label: "Caution")
        default:        return .red(label: "Needs Attention")
        }
    }

    private func vitalsSummary(_ s: Double) -> String {
        switch s {
        case 85...100: return "Your vitals are stable and within your normal ranges."
        case 70..<85:  return "Mostly stable with a minor deviation worth watching."
        case 50..<70:  return "One or more vitals drifted from baseline — monitor today."
        default:        return "Multiple vitals are out of range. Prioritize rest and recovery."
        }
    }

    // MARK: - Health Monitor fusion

    struct HealthSignal: Identifiable { let id = UUID(); let icon: String; let title: String; let detail: String; let color: Color }

    private func healthSignals() -> [HealthSignal] {
        let history = viewModel.loadHistory(days: 30)
        var out: [HealthSignal] = []

        let rhrBase = BaselineCalculator.computeRHRBaseline(from: BaselineCalculator.extractHistory(from: history, \.restingHR))
        let hrvBase = BaselineCalculator.computeHRVBaseline(from: BaselineCalculator.extractHistory(from: history, \.hrvAverage))

        // Illness risk: temp + RHR + resp rate all pointing up
        var illnessHits = 0
        if let t = metrics.wristTempDeviation, t > 0.4 { illnessHits += 1 }
        if let rhr = metrics.restingHR, let b = rhrBase, rhr > b + 3 { illnessHits += 1 }
        if let rr = metrics.respiratoryRate, rr > 18 { illnessHits += 1 }
        if illnessHits >= 2 {
            out.append(HealthSignal(
                icon: "cross.case.fill", title: "Potential Illness Risk",
                detail: "\(illnessHits) of 3 illness markers (temperature, resting HR, respiratory rate) are elevated together. Rest, hydrate, and avoid hard training.",
                color: .somaRed))
        }

        // Recovery suppression: low HRV + elevated RHR
        if let hrv = metrics.hrvAverage, let hb = hrvBase, hb > 0, hrv < hb * 0.85,
           let rhr = metrics.restingHR, let rb = rhrBase, rhr > rb + 2 {
            out.append(HealthSignal(
                icon: "arrow.down.heart.fill", title: "Recovery Suppression",
                detail: "HRV is depressed and resting HR is elevated — your autonomic system hasn't fully recovered. Keep strain low today.",
                color: .somaOrange))
        }

        // Stress overload: high stress + high evening stress
        if metrics.stressScore > 60 || (metrics.eveningStressScore ?? 0) > 55 {
            out.append(HealthSignal(
                icon: "bolt.heart.fill", title: "Stress Overload",
                detail: "Autonomic arousal is elevated. Box breathing (4-4-4-4), a short walk, or 10 minutes of mindfulness can bring it down before bed.",
                color: .somaYellow))
        }

        return out
    }
}

// MARK: - Vital Row

private struct VitalRow: View {
    let vital: VitalsView.Vital

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: vital.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(vital.color)
                .frame(width: 40, height: 40)
                .background(Circle().fill(vital.color.opacity(0.16)))

            VStack(alignment: .leading, spacing: 3) {
                Text(vital.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(vital.baselineText)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.somaTextTertiary)
            }

            Spacer(minLength: 8)

            if vital.history.count >= 2 {
                MiniSparkline(values: vital.history, color: vital.color)
                    .frame(width: 54, height: 26)
            }

            VStack(alignment: .trailing, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(vital.valueText)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(vital.unit)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.somaTextTertiary)
                }
                HStack(spacing: 3) {
                    Image(systemName: vital.trend.icon).font(.system(size: 9, weight: .bold))
                    Text(vital.deviationText).font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(vital.color)
            }
        }
        .accentCard(vital.color, cornerRadius: Radius.md, padding: 14)
    }
}
