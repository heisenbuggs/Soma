import SwiftUI
import WidgetKit

// MARK: - Entry View (dispatches by widget family)

struct SomaWidgetEntryView: View {
    var entry: SomaWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:  SmallWidgetView(metrics: entry.metrics)
        case .systemMedium: MediumWidgetView(metrics: entry.metrics)
        default:            LargeWidgetView(metrics: entry.metrics)
        }
    }
}

// MARK: - Small Widget (Recovery only)

struct SmallWidgetView: View {
    let metrics: SomaWidgetMetrics?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.caption2)
                    .foregroundStyle(Color(hex: "00C853"))
                Text("SOMA")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let m = metrics {
                Text("\(Int(m.recoveryScore.rounded()))")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(recoveryColor(m.recoveryScore))
                Text(recoveryLabel(m.recoveryScore))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text("Recovery")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("--")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("Open Soma")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Medium Widget (All 4 scores)

struct MediumWidgetView: View {
    let metrics: SomaWidgetMetrics?

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(Color(hex: "00C853"))
                    Text("SOMA")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)

                if let m = metrics {
                    scoreRow(label: "Recovery", value: m.recoveryScore, max: 100,
                             color: recoveryColor(m.recoveryScore))
                    scoreRow(label: "Strain",   value: m.strainScore,   max: 21,
                             color: strainColor(m.strainScore))
                    scoreRow(label: "Sleep",    value: m.sleepScore,    max: 100,
                             color: sleepColor(m.sleepScore))
                    scoreRow(label: "Stress",   value: m.stressScore,   max: 100,
                             color: stressColor(m.stressScore))
                } else {
                    Text("Open Soma to load scores")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func scoreRow(label: String, value: Double, max: Double, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Text("\(Int(value.rounded()))")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text("/\(Int(max))")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: - Large Widget (All scores + insight)

struct LargeWidgetView: View {
    let metrics: SomaWidgetMetrics?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: "00C853"))
                Text("Soma")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                Spacer()
            }

            if let m = metrics {
                let cols = [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: cols, spacing: 10) {
                    largeScoreCard(label: "Recovery", value: m.recoveryScore, max: 100,
                                   color: recoveryColor(m.recoveryScore))
                    largeScoreCard(label: "Strain",   value: m.strainScore,   max: 21,
                                   color: strainColor(m.strainScore))
                    largeScoreCard(label: "Sleep",    value: m.sleepScore,    max: 100,
                                   color: sleepColor(m.sleepScore))
                    largeScoreCard(label: "Stress",   value: m.stressScore,   max: 100,
                                   color: stressColor(m.stressScore))
                }

                Divider()

                Text(insightText(for: m))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Spacer()
                Text("Open Soma to load your scores")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func largeScoreCard(label: String, value: Double, max: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(Int(value.rounded()))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
                Text("/\(Int(max))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func insightText(for m: SomaWidgetMetrics) -> String {
        switch m.recoveryScore {
        case 67...100: return "You're well recovered. Today is a good day to push intensity."
        case 34..<67:  return "Moderate recovery today — keep strain balanced."
        default:       return "Low recovery. Consider a rest day and prioritise sleep tonight."
        }
    }
}

// MARK: - Score Color Helpers

private func recoveryColor(_ score: Double) -> Color {
    score >= 67 ? Color(hex: "00C853") : score >= 34 ? Color(hex: "FFD600") : Color(hex: "FF1744")
}
private func recoveryLabel(_ score: Double) -> String {
    score >= 67 ? "Recovered" : score >= 34 ? "Moderate" : "Low"
}
private func strainColor(_ score: Double) -> Color {
    score < 10 ? Color(hex: "2979FF") : score < 14 ? Color(hex: "00C853") : score < 18 ? Color(hex: "FF9100") : Color(hex: "FF1744")
}
private func sleepColor(_ score: Double) -> Color {
    score >= 75 ? Color(hex: "00C853") : score >= 60 ? Color(hex: "FFD600") : Color(hex: "FF1744")
}
private func stressColor(_ score: Double) -> Color {
    score <= 33 ? Color(hex: "00C853") : score <= 66 ? Color(hex: "FFD600") : Color(hex: "FF1744")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
