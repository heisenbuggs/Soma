import SwiftUI

struct MetricCardView: View {
    let title: String
    let score: Double
    let maxScore: Double
    let state: ColorState
    let sparklineValues: [Double]
    var weekDelta: Double? = nil

    @State private var appeared = false

    private var progress: Double {
        guard maxScore > 0 else { return 0 }
        return score / maxScore
    }

    private var isExcellent: Bool {
        state.label == "Excellent" || state.label == "Minimal"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Header
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
                Text(state.label)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(state.color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(state.color.opacity(0.15))
                    .clipShape(Capsule())
            }

            // Score + Ring + Delta
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RingView(progress: appeared ? progress : 0, color: state.color, lineWidth: 6)
                        .animation(.spring(response: 1.0, dampingFraction: 0.7), value: appeared)
                    Text(scoreText)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.5), value: score)
                }
                .frame(width: 64, height: 64)
                .shadow(color: isExcellent ? state.color.opacity(0.4) : .clear, radius: 10, x: 0, y: 0)

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
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(state.color.opacity(0.35), lineWidth: 1)
        )
        .scaleEffect(appeared ? 1 : 0.92)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }

    private var scoreText: String {
        if score.isNaN || score.isInfinite { return "--" }
        return "\(Int(score.rounded()))"
    }

    private func trendColor(_ delta: Double) -> Color {
        delta > 0 ? Color.somaGreen : Color.somaOrange
    }
}

#Preview("Excellent") {
    MetricCardView(
        title: "Recovery",
        score: 88,
        maxScore: 100,
        state: .green(label: "Excellent"),
        sparklineValues: [60, 65, 72, 80, 75, 70, 88],
        weekDelta: 8
    )
    .frame(width: 180)
    .padding()
    .background(Color.black)
}

#Preview("Good") {
    MetricCardView(
        title: "Sleep",
        score: 76,
        maxScore: 100,
        state: .lightGreen(label: "Good"),
        sparklineValues: [60, 65, 72, 80, 75, 70, 76]
    )
    .frame(width: 180)
    .padding()
    .background(Color.black)
}
