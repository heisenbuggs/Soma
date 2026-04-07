import SwiftUI

struct MetricCardView: View {
    let title: String
    let score: Double
    let maxScore: Double
    let state: ColorState
    let sparklineValues: [Double]
    /// Change vs. the prior 6-day average. Positive = improving, negative = declining.
    var weekDelta: Double? = nil

    private var progress: Double {
        guard maxScore > 0 else { return 0 }
        return score / maxScore
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(Color(hex: "8E8E93"))
                Spacer()
                Text(state.label)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(state.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(state.color.opacity(0.15))
                    .clipShape(Capsule())
            }

            // Score + Ring + trend indicator
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RingView(progress: progress, color: state.color, lineWidth: 6)
                    Text(scoreText)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .frame(width: 64, height: 64)

                if let delta = weekDelta, !delta.isNaN, abs(delta) >= 1 {
                    VStack(spacing: 2) {
                        Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(trendColor(delta))
                        Text(String(format: "%+.0f", delta))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(trendColor(delta))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(trendColor(delta).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                Spacer()
            }

            // Sparkline
            SparklineView(values: sparklineValues, color: state.color)
                .frame(height: 32)
        }
        .padding(14)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var scoreText: String {
        if score.isNaN || score.isInfinite {
            return "--"
        }
        return "\(Int(score.rounded()))"
    }

    private func trendColor(_ delta: Double) -> Color {
        // For stress and strain, up is bad; for recovery and sleep, up is good.
        // The card doesn't know its metric type, so use a neutral scheme:
        // positive delta = green, negative = orange.
        delta > 0 ? Color(hex: "00C853") : Color(hex: "FF9100")
    }
}

#Preview("With trend up") {
    MetricCardView(
        title: "Recovery",
        score: 78,
        maxScore: 100,
        state: .green(label: "Recovered"),
        sparklineValues: [60, 65, 72, 80, 75, 70, 78],
        weekDelta: 8
    )
    .frame(width: 180)
    .background(Color.black)
}

#Preview {
    MetricCardView(
        title: "Recovery",
        score: 78,
        maxScore: 100,
        state: .green(label: "Recovered"),
        sparklineValues: [60, 65, 72, 80, 75, 70, 78]
    )
    .frame(width: 180)
    .background(Color.black)
}
