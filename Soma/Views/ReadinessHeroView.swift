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
            case 80...100: return "Peak Performance — Go All In"
            case 65..<80:  return "Strong Day — Train Hard"
            case 45..<65:  return "Moderate Day — Steady Training"
            case 25..<45:  return "Low Readiness — Go Light"
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
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(Color.somaGray)
                }

                // Centered ring
                ZStack {
                    // Dark track (full circle — shows the unfilled portion)
                    Circle()
                        .stroke(Color(white: 0.12), lineWidth: 16)
                        .frame(width: 130, height: 130)

                    // Full spectrum gradient ring — always drawn; clipped to score length
                    Circle()
                        .trim(from: 0, to: min(1, readinessScore / 100))
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
