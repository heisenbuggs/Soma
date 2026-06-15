import SwiftUI

// MARK: - COACH TAB
// "What habits affect my health?" — behavioral intelligence + longevity.
// Biggest Lever → Behavioral Correlations → Weekly Focus → Soma Age → Sleep Timing.

struct CoachView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @ObservedObject var insightsVM: InsightsViewModel

    @State private var showSomaAge = false
    @State private var showAyurvedic = false

    private var metrics: DailyMetrics { viewModel.todayMetrics }

    var body: some View {
        NavigationStack {
            ZStack {
                SomaGradient.canvas(tint: .somaPurple)
                ScrollView {
                    VStack(spacing: Space.lg) {
                        biggestLeverSection
                        somaAgeModule
                        correlationsSection
                        weeklyFocusSection
                        sleepTimingSection
                        Color.clear.frame(height: 12)
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.top, Space.sm)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showSomaAge) {
                SomaAgeDetailView(
                    result: viewModel.somaAge,
                    calibration: viewModel.somaAgeCalibration,
                    chronologicalAge: viewModel.chronologicalAge,
                    trend: viewModel.somaAgeTrend()
                )
            }
            .sheet(isPresented: $showAyurvedic) {
                AyurvedicSleepDetailView(
                    score: metrics.ayurvedicSleepPoints ?? 0,
                    sleepStart: metrics.sleepStartTime,
                    sleepEnd: metrics.sleepEndTime,
                    eveningDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
                    history: viewModel.loadHistory(days: 365),
                    napDurationMinutes: metrics.napDurationMinutes,
                    napStartTime: metrics.napStartTime,
                    napEndTime: metrics.napEndTime
                )
            }
        }
        .onAppear { insightsVM.generateInsights() }
    }

    // MARK: Biggest Lever

    private var biggestLeverSection: some View {
        let lever = biggestLever()
        return VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(title: "Today's Biggest Lever")
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: lever.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(lever.color)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(lever.color.opacity(0.16)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lever.title)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(lever.subtitle)
                            .font(.footnote)
                            .foregroundStyle(Color.somaTextSecondary)
                    }
                    Spacer(minLength: 0)
                }
                Text(lever.detail)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.somaTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let action = lever.action {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle.fill").foregroundStyle(lever.color)
                        Text(action).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    }
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .premiumCard(cornerRadius: Radius.lg, glow: lever.color)
        }
    }

    // MARK: Soma Age module

    private var somaAgeModule: some View {
        Button { Haptics.tap(); showSomaAge = true } label: {
            VStack(alignment: .leading, spacing: Space.md) {
                HStack {
                    Text("SOMA AGE").eyebrow()
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption2.weight(.bold)).foregroundStyle(Color.somaTextTertiary)
                }
                if let r = viewModel.somaAge {
                    HStack(alignment: .lastTextBaseline, spacing: 10) {
                        Text(SomaAgeFormat.age(r.biologicalAge))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(SomaAgeFormat.deltaColor(r.delta))
                        Text("yrs").font(.system(size: 16, weight: .medium)).foregroundStyle(Color.somaTextTertiary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Chronological").font(.caption2).foregroundStyle(Color.somaTextTertiary)
                            Text("\(viewModel.chronologicalAge)").font(.system(size: 20, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                        }
                    }
                    Text(SomaAgeFormat.deltaPhrase(r.delta))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(SomaAgeFormat.deltaColor(r.delta))
                    if let driver = r.positiveDrivers.first ?? r.negativeDrivers.first {
                        Divider().overlay(Color.somaHairline)
                        HStack(spacing: 8) {
                            Image(systemName: driver.isPositive ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                .foregroundStyle(driver.isPositive ? Color.somaGreen : Color.somaOrange)
                            Text(driver.title).font(.footnote).foregroundStyle(Color.somaTextSecondary)
                            Spacer()
                            Text(String(format: "%+.1f yr", driver.years))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(driver.isPositive ? Color.somaGreen : Color.somaOrange)
                        }
                    }
                } else {
                    // Calibrating — mirror the Vitals status widget: keep the widget's
                    // normal value layout, flag it with the shared CALIBRATING pill, and
                    // show the chronological age as the reference while the score builds.
                    let c = viewModel.somaAgeCalibration
                    HStack(alignment: .lastTextBaseline, spacing: 10) {
                        Text("—")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.somaTextTertiary)
                        Text("yrs").font(.system(size: 16, weight: .medium)).foregroundStyle(Color.somaTextTertiary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Chronological").font(.caption2).foregroundStyle(Color.somaTextTertiary)
                            Text("\(viewModel.chronologicalAge)").font(.system(size: 20, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                        }
                    }
                    CalibratingTag(daysLeft: c.daysRemaining)
                    Text("Building your biological age — keep wearing your watch for \(c.daysRemaining) more day\(c.daysRemaining == 1 ? "" : "s") to unlock it.")
                        .font(.footnote).foregroundStyle(Color.somaTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .premiumCard(cornerRadius: Radius.lg)
        }
        .buttonStyle(.plain)
    }

    // MARK: Correlations

    private var correlationsSection: some View {
        let insights = insightsVM.behaviorInsights.sorted { abs($0.delta) > abs($1.delta) }
        return VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(title: "Behavioral Correlations",
                          subtitle: insights.isEmpty ? nil : "From your logged check-ins")
            if insights.isEmpty {
                Text("Log daily check-ins for ~2 weeks to reveal which habits move your recovery, sleep, and HRV.")
                    .font(.footnote).foregroundStyle(Color.somaTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .premiumCard(cornerRadius: Radius.md, padding: 14)
            } else {
                ForEach(insights.prefix(6)) { insight in
                    correlationRow(insight)
                }
            }
        }
    }

    private func correlationRow(_ i: BehaviorInsight) -> some View {
        let good = !i.isNegativeImpact
        let color: Color = good ? .somaGreen : .somaRed
        let unit: String = {
            switch i.metricName {
            case "HRV", "Sleeping HRV": return "ms"
            case "Sleeping HR":          return "bpm"
            default:                      return "pts"
            }
        }()
        let absVal = abs(i.delta)
        let valStr = (absVal >= 1 ? String(format: "%.0f", absVal) : String(format: "%.1f", absVal))
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(i.behaviorName).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Text("\(i.metricName) · \(i.occurrences) days observed")
                    .font(.caption).foregroundStyle(Color.somaTextTertiary)
            }
            Spacer()
            Text("\(i.delta > 0 ? "+" : "−")\(valStr) \(unit)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(color.opacity(0.14)))
        }
        .accentCard(color, cornerRadius: Radius.md, padding: 14)
    }

    // MARK: Weekly Focus

    private var weeklyFocusSection: some View {
        let focus = weeklyFocus()
        return VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(title: "This Week's Focus")
            HStack(spacing: 14) {
                Image(systemName: focus.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(SomaGradient.accentFill(.somaPurple)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(focus.title).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text(focus.detail).font(.footnote).foregroundStyle(Color.somaTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .premiumCard(cornerRadius: Radius.lg, glow: .somaPurple)
        }
    }

    // MARK: Sleep Timing (Ayurvedic, connected to outcomes)

    private var sleepTimingSection: some View {
        let score = metrics.ayurvedicSleepPoints ?? 0
        let accent = Color(hex: AyurvedicSleepCalculator.guidanceHex(for: score))
        return Button { Haptics.tap(); showAyurvedic = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(accent.opacity(0.16)))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Sleep Timing").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    Text(AyurvedicSleepCalculator.guidanceText(for: score))
                        .font(.footnote).foregroundStyle(Color.somaTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let bedtime = viewModel.bedtimeTarget {
                        Text("Recommended bedtime · \(bedtime.formatted(date: .omitted, time: .shortened))")
                            .font(.caption).foregroundStyle(accent)
                    }
                }
                Spacer(minLength: 0)
                Text(String(format: "%.1f", score))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accentCard(accent, cornerRadius: Radius.lg)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Derivations

    private struct Lever { let icon: String; let title: String; let subtitle: String; let detail: String; let action: String?; let color: Color }

    private func biggestLever() -> Lever {
        // Prefer the strongest harmful behavior correlation.
        if let worst = insightsVM.behaviorInsights
            .filter({ $0.isNegativeImpact })
            .max(by: { abs($0.delta) < abs($1.delta) }) {
            return Lever(
                icon: "exclamationmark.triangle.fill",
                title: worst.behaviorName,
                subtitle: "Most impactful habit",
                detail: worst.impactDescription,
                action: "Cut this back and watch your \(worst.metricName.lowercased()) recover.",
                color: .somaRed)
        }
        // Otherwise lean on sleep consistency.
        if let c = metrics.sleepConsistencyScore, c < 70 {
            let bedtime = viewModel.bedtimeTarget?.formatted(date: .omitted, time: .shortened) ?? "a fixed time"
            return Lever(
                icon: "clock.arrow.2.circlepath",
                title: "Sleep Consistency",
                subtitle: "Your highest-leverage change",
                detail: "Your bed and wake times vary night to night (consistency \(Int(c))/100). A steady schedule is the single biggest driver of recovery.",
                action: "Aim for bed by \(bedtime) every night this week.",
                color: .somaBlue)
        }
        // Default positive reinforcement.
        if let best = insightsVM.behaviorInsights.filter({ !$0.isNegativeImpact }).max(by: { abs($0.delta) < abs($1.delta) }) {
            return Lever(icon: "checkmark.seal.fill", title: best.behaviorName,
                         subtitle: "Keep this up", detail: best.impactDescription,
                         action: "This habit is working — protect it.", color: .somaGreen)
        }
        return Lever(icon: "sparkles", title: "Building Your Profile",
                     subtitle: "Keep logging",
                     detail: "Log a few more daily check-ins and Soma will surface the one habit that moves your numbers most.",
                     action: nil, color: .somaPurple)
    }

    private struct Focus { let icon: String; let title: String; let detail: String }
    private func weeklyFocus() -> Focus {
        if let c = metrics.sleepConsistencyScore, c < 70 {
            return Focus(icon: "bed.double.fill", title: "Improve sleep consistency",
                         detail: "Hold bedtime within a 30-minute window all week. Potential readiness gain: +5 to +8 points.")
        }
        if let worst = insightsVM.behaviorInsights.filter({ $0.isNegativeImpact }).max(by: { abs($0.delta) < abs($1.delta) }) {
            return Focus(icon: "minus.circle.fill", title: "Reduce \(worst.behaviorName.lowercased())",
                         detail: "Your data links it to lower \(worst.metricName.lowercased()). Skip it 5 of 7 nights this week.")
        }
        return Focus(icon: "figure.run", title: "Protect your routine",
                     detail: "Your habits are trending well. Keep training, sleeping, and recovering on schedule.")
    }
}
