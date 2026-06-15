import SwiftUI

// MARK: - Soma V2 Premium Components
// The shared building blocks every redesigned screen composes from.

// MARK: - Readiness Ring (hero)

/// A large, glowing gradient ring with a count-up number. State-hued so the
/// color *is* the health signal (PRD principle 4).
struct ReadinessRing: View {
    let score: Double          // 0–100
    let title: String          // e.g. "READINESS"
    let stateLabel: String     // e.g. "GOOD"
    let color: Color
    var size: CGFloat = 220
    var lineWidth: CGFloat = 18

    @State private var animatedTrim: Double = 0
    @State private var shown: Double = 0

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: lineWidth)

            // Soft outer glow
            Circle()
                .trim(from: 0, to: animatedTrim)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .blur(radius: 18)
                .opacity(0.55)

            // Gradient arc — flat round caps, no separate pointer dot.
            Circle()
                .trim(from: 0, to: animatedTrim)
                .stroke(SomaGradient.arc(color),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Center label — `.tracking` adds trailing space after the last glyph,
            // which shifts the visible text left of center; nudge x by tracking/2 to
            // optically re-center. Labels are clamped to one scalable line.
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: max(10, size * 0.075), weight: .semibold, design: .rounded))
                    .tracking(1.5)
                    .offset(x: 0.75)
                    .foregroundStyle(Color.somaTextTertiary)
                    .frame(maxWidth: size * 0.74)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("\(Int(shown.rounded()))")
                    .font(.system(size: size * 0.30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: shown))
                    .monospacedDigit()
                Text(stateLabel.uppercased())
                    .font(.system(size: max(11, size * 0.085), weight: .heavy, design: .rounded))
                    .tracking(1.5)
                    .offset(x: 0.75)
                    .foregroundStyle(color)
                    .frame(maxWidth: size * 0.74)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(width: size, height: size)
        .onAppear { animate() }
        .onChange(of: score) { _, _ in animate() }
    }

    private func animate() {
        animatedTrim = 0
        shown = 0
        withAnimation(.easeOut(duration: 1.1)) {
            animatedTrim = min(1, max(0, score / 100))
        }
        withAnimation(.easeOut(duration: 1.0)) {
            shown = score
        }
    }
}

// MARK: - Calibrating Tag

/// Small amber pill that flags a score as still building its personal baseline.
/// Shared by every widget that surfaces a score before calibration completes
/// (Vitals status, Soma Age, …) so the treatment is identical everywhere.
struct CalibratingTag: View {
    let daysLeft: Int

    private var label: String {
        daysLeft > 0
            ? "CALIBRATING · \(daysLeft) DAY\(daysLeft == 1 ? "" : "S") LEFT"
            : "CALIBRATING"
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "hourglass")
                .font(.system(size: 10, weight: .bold))
            Text(label)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(0.6)
        }
        .foregroundStyle(Color.somaYellow)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.somaYellow.opacity(0.16)))
        .overlay(Capsule().strokeBorder(Color.somaYellow.opacity(0.35), lineWidth: 1))
    }
}

// MARK: - State Pill

struct StatePill: View {
    let text: String
    let color: Color
    var filled: Bool = false

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .tracking(0.6)
            .foregroundStyle(filled ? Color.black : color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(filled ? AnyShapeStyle(color) : AnyShapeStyle(color.opacity(0.16)))
            )
            .overlay(
                Capsule().strokeBorder(color.opacity(filled ? 0 : 0.35), lineWidth: 1)
            )
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Color.somaTextSecondary)
                }
            }
            Spacer()
            if let action, let actionLabel {
                Button(action: action) {
                    HStack(spacing: 3) {
                        Text(actionLabel)
                        Image(systemName: "chevron.right").font(.caption2.weight(.bold))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.somaBlue)
                }
            }
        }
    }
}

// MARK: - Trend direction (UI arrow for signal tiles / vitals)

enum SignalTrend {
    case up, down, flat

    var icon: String {
        switch self {
        case .up:   return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .flat: return "arrow.right"
        }
    }
}

// MARK: - Signal Tile (Key Signals on Today)

struct SignalTile: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    var baseline: String? = nil
    var deviationText: String? = nil
    var color: Color
    var trend: SignalTrend = .flat

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(color.opacity(0.16)))
                Spacer()
                Image(systemName: trend.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.somaTextTertiary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.somaTextSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.somaTextTertiary)
                    }
                }
            }

            if let deviationText {
                Text(deviationText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color)
            } else if let baseline {
                StatePill(text: baseline, color: color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accentCard(color, cornerRadius: Radius.md, padding: 14)
    }
}

// MARK: - Deviation bar (Vitals)

/// Horizontal track showing where `value` sits relative to a healthy band
/// centered on `baseline`. Purely visual; the caller computes the fraction.
struct DeviationBar: View {
    let fraction: Double   // 0…1 position of the marker
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 6)
                Capsule()
                    .fill(LinearGradient(colors: [color.opacity(0.5), color],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(6, geo.size.width * fraction), height: 6)
                Circle()
                    .fill(.white)
                    .frame(width: 11, height: 11)
                    .shadow(color: color.opacity(0.8), radius: 5)
                    .offset(x: max(0, min(geo.size.width - 11, geo.size.width * fraction - 5.5)))
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 12)
    }
}

// MARK: - Alert Row (Alert Center / Health Monitor)

struct AlertRow: View {
    let icon: String
    let title: String
    let detail: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.16))
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.somaTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .premiumCard(cornerRadius: Radius.md, padding: 14, glow: color)
    }
}

// MARK: - Mini sparkline

struct MiniSparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            if values.count >= 2,
               let lo = values.min(), let hi = values.max() {
                let span = max(hi - lo, 0.0001)
                let stepX = geo.size.width / CGFloat(values.count - 1)
                let pts = values.enumerated().map { i, v in
                    CGPoint(x: CGFloat(i) * stepX,
                            y: geo.size.height * (1 - CGFloat((v - lo) / span)))
                }
                ZStack {
                    // fill
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: geo.size.height))
                        pts.forEach { p.addLine(to: $0) }
                        p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [color.opacity(0.28), .clear],
                                         startPoint: .top, endPoint: .bottom))
                    // line
                    Path { p in
                        p.move(to: pts[0])
                        pts.dropFirst().forEach { p.addLine(to: $0) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }
}
