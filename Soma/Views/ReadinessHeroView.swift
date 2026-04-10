import SwiftUI

struct ReadinessHeroView: View {
    let readinessScore: Double
    let recoveryScore: Double
    let sleepScore: Double
    let hrvScore: Double?
    let rhrScore: Double?

    private var state: ColorState { ColorState.recovery(score: readinessScore) }
    private var accent: Color { state.color }

    private var headline: String {
        switch readinessScore {
            case 85...100: return "Peak Performance — Go All In"
            case 65..<85:  return "Strong Day — Train Hard"
            case 45..<65:  return "Moderate Day — Steady Training"
            case 30..<45:  return "Low Readiness — Go Light"
            default:       return "Recovery First — Rest Up"
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── Top section ───────────────────────────────────────────────
            VStack(spacing: 16) {

                // Header row
                HStack {
                    Text("Today's Readiness")
                        .font(.caption)
                        .foregroundColor(Color.somaGray)
                    Spacer()
                    Text(state.label)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(accent.opacity(0.15))
                        .clipShape(Capsule())
                }

                // Centered ring
                ZStack {
                    // Track
                    Circle()
                        .stroke(accent.opacity(0.12), lineWidth: 16)
                        .frame(width: 130, height: 130)

                    // Progress arc
                    Circle()
                        .trim(from: 0, to: min(1, readinessScore / 100))
                        .stroke(
                            AngularGradient(
                                colors: [accent.opacity(0.5), accent],
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(270)
                            ),
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .frame(width: 130, height: 130)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 1.2), value: readinessScore)

                    // Score
                    VStack(spacing: 1) {
                        Text("\(Int(readinessScore.rounded()))")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                        Text("READINESS")
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                            .tracking(1.5)
                    }
                }

                // Headline below ring
                Text(headline)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 20)

            // ── Divider ───────────────────────────────────────────────────
            Rectangle()
                .fill(Color.secondary.opacity(0.12))
                .frame(height: 1)

            // ── Bottom metric row ─────────────────────────────────────────
            HStack(spacing: 0) {
                metricCell(
                    label: "Recovery",
                    score: recoveryScore,
                    color: ColorState.recovery(score: recoveryScore).color
                )
                verticalDivider
                metricCell(
                    label: "Sleep",
                    score: sleepScore,
                    color: Color.somaBlue
                )
                if let hrv = hrvScore {
                    verticalDivider
                    metricCell(label: "HRV", score: hrv, color: Color.somaPurple)
                }
                if let rhr = rhrScore {
                    verticalDivider
                    metricCell(label: "RHR", score: rhr, color: Color.somaOrange)
                }
            }
            .padding(.vertical, 14)
        }
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(accent.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Metric Cell

    private func metricCell(label: String, score: Double, color: Color) -> some View {
        VStack(spacing: 3) {
            Text("\(Int(score.rounded()))")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(Color.somaGray)
        }
        .frame(maxWidth: .infinity)
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.12))
            .frame(width: 1, height: 36)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ZStack {
        Color(hex: "121212").ignoresSafeArea()
        VStack(spacing: 16) {
            ReadinessHeroView(
                readinessScore: 50,
                recoveryScore: 81,
                sleepScore: 75,
                hrvScore: 88,
                rhrScore: 72
            )
            ReadinessHeroView(
                readinessScore: 88,
                recoveryScore: 90,
                sleepScore: 85,
                hrvScore: nil,
                rhrScore: nil
            )
        }
        .padding()
    }
}
#endif
