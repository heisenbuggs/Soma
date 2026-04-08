import SwiftUI

// MARK: - ReadinessHeroView
//
// Full-width ring that promotes readiness to the top-level hero KPI.
// The large outer ring shows the composite readiness score (0–100).
// Four smaller component arcs below surface the individual inputs.

struct ReadinessHeroView: View {
    let readinessScore: Double
    let recoveryScore: Double
    let sleepScore: Double
    /// HRV ratio normalised to 0–100 (nil when no baseline yet).
    let hrvScore: Double?
    /// RHR score normalised to 0–100 (nil when no baseline yet).
    let rhrScore: Double?

    // MARK: - Derived

    private var headline: String {
        switch readinessScore {
        case 85...100: return "Good to Push Hard"
        case 65..<85:  return "Ready to Train"
        case 45..<65:  return "Train Smart Today"
        case 30..<45:  return "Take It Easy"
        default:       return "Rest and Recover Today"
        }
    }

    private var ringColor: Color {
        switch readinessScore {
        case 67...100: return Color(hex: "00C853")
        case 34..<67:  return Color(hex: "FFD600")
        default:       return Color(hex: "FF1744")
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            // Large readiness ring
            ZStack {
                // Track
                Circle()
                    .stroke(ringColor.opacity(0.12), lineWidth: 20)
                    .frame(width: 168, height: 168)

                // Progress arc
                Circle()
                    .trim(from: 0, to: min(1, readinessScore / 100))
                    .stroke(
                        AngularGradient(
                            colors: [ringColor.opacity(0.6), ringColor],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 168, height: 168)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.2), value: readinessScore)

                // Centre label
                VStack(spacing: 2) {
                    Text("\(Int(readinessScore.rounded()))")
                        .font(.system(size: 50, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                    Text("READINESS")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .tracking(1.5)
                }
            }

            // Headline
            Text(headline)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            // Component score arcs
            HStack(spacing: 0) {
                componentCell(label: "Recovery", score: recoveryScore, color: Color(hex: "00C853"))
                separator
                componentCell(label: "Sleep", score: sleepScore, color: Color(hex: "2979FF"))
                if let hrv = hrvScore {
                    separator
                    componentCell(label: "HRV", score: hrv, color: Color(hex: "9C27B0"))
                }
                if let rhr = rhrScore {
                    separator
                    componentCell(label: "RHR", score: rhr, color: Color(hex: "FF9100"))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .padding(20)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(ringColor.opacity(0.22), lineWidth: 1)
        )
    }

    // MARK: - Component Cell

    private func componentCell(label: String, score: Double, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 5)
                    .frame(width: 38, height: 38)
                Circle()
                    .trim(from: 0, to: min(1, score / 100))
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 38, height: 38)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.0), value: score)
                Text("\(Int(score.rounded()))")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.15))
            .frame(width: 1, height: 44)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ZStack {
        Color(hex: "121212").ignoresSafeArea()
        VStack(spacing: 20) {
            ReadinessHeroView(
                readinessScore: 78,
                recoveryScore: 82,
                sleepScore: 71,
                hrvScore: 91,
                rhrScore: 68
            )
            ReadinessHeroView(
                readinessScore: 35,
                recoveryScore: 38,
                sleepScore: 41,
                hrvScore: nil,
                rhrScore: nil
            )
        }
        .padding()
    }
}
#endif
