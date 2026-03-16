import SwiftUI

struct MetricCardView: View {
    let title: String
    let score: Double
    let maxScore: Double
    let state: ColorState
    let sparklineValues: [Double]

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

            // Score + Ring
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RingView(progress: progress, color: state.color, lineWidth: 6)
                    Text(scoreText)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .frame(width: 64, height: 64)

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
