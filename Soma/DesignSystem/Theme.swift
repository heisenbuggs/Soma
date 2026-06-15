import SwiftUI
import UIKit

// MARK: - Soma V2 Design System
// A premium, dark-first visual language. Jet-black canvas, charcoal gradient
// cards, vivid state colors, soft glows, and calm motion. Everything here is
// purely presentational — no data, no business logic.

// MARK: - Surfaces & Ink

extension Color {
    /// Jet-black app canvas. The redesign is dark-first (see `MainTabView`).
    static let somaInk = Color.black

    /// Slightly lifted black used behind grouped content / under cards.
    static let somaInkRaised = Color(hex: "0A0A0B")

    /// Card gradient — top (catches the light) and bottom (sinks into the canvas).
    static let somaCardTop    = Color(hex: "1C1C1F")
    static let somaCardBottom = Color(hex: "121214")

    /// Elevated card (sheets, expanded rows).
    static let somaCardRaisedTop    = Color(hex: "242428")
    static let somaCardRaisedBottom = Color(hex: "171719")

    /// Hairline stroke that gives cards a crisp, glassy top edge.
    static let somaHairline = Color.white.opacity(0.07)

    /// Text tiers on black.
    static let somaTextPrimary   = Color.white
    static let somaTextSecondary = Color.white.opacity(0.62)
    static let somaTextTertiary  = Color.white.opacity(0.38)
}

// MARK: - Gradients

enum SomaGradient {
    /// Default premium card fill.
    static let card = LinearGradient(
        colors: [.somaCardTop, .somaCardBottom],
        startPoint: .top, endPoint: .bottom
    )

    static let cardRaised = LinearGradient(
        colors: [.somaCardRaisedTop, .somaCardRaisedBottom],
        startPoint: .top, endPoint: .bottom
    )

    /// The whole-screen backdrop: jet black with a faint radial lift at the top
    /// so the hero ring feels lit from above.
    static func canvas(tint: Color) -> some View {
        ZStack {
            Color.somaInk
            RadialGradient(
                colors: [tint.opacity(0.16), .clear],
                center: .init(x: 0.5, y: 0.0),
                startRadius: 0, endRadius: 520
            )
            .blendMode(.plusLighter)
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }

    /// A smooth two-stop sweep in a single hue — used for rings and progress.
    static func arc(_ color: Color) -> AngularGradient {
        AngularGradient(
            gradient: Gradient(stops: [
                .init(color: color.opacity(0.55), location: 0.0),
                .init(color: color,               location: 0.55),
                .init(color: color.opacity(0.95), location: 1.0)
            ]),
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }

    /// Subtle accent wash for tinted chips / left edges.
    static func accentFill(_ color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.22), color.opacity(0.06)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}

// MARK: - Radii & Spacing tokens

enum Radius {
    static let sm: CGFloat = 12
    static let md: CGFloat = 18
    static let lg: CGFloat = 24
    static let xl: CGFloat = 30
}

enum Space {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 22
    static let xl: CGFloat = 32
}

// MARK: - Premium Card

struct PremiumCardModifier: ViewModifier {
    var cornerRadius: CGFloat = Radius.lg
    var padding: CGFloat = Space.md
    var raised: Bool = false
    /// When set, paints a soft colored glow under the card and tints the top edge.
    var glow: Color? = nil

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(raised ? SomaGradient.cardRaised : SomaGradient.card)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                (glow ?? .white).opacity(glow == nil ? 0.10 : 0.30),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: (glow ?? .black).opacity(glow == nil ? 0.45 : 0.28),
                    radius: glow == nil ? 18 : 26, x: 0, y: glow == nil ? 10 : 14)
    }
}

extension View {
    /// Standard premium card surface.
    func premiumCard(cornerRadius: CGFloat = Radius.lg,
                     padding: CGFloat = Space.md,
                     raised: Bool = false,
                     glow: Color? = nil) -> some View {
        modifier(PremiumCardModifier(cornerRadius: cornerRadius,
                                     padding: padding,
                                     raised: raised,
                                     glow: glow))
    }

    /// A colored left edge — the preferred way to signal state without painting
    /// the whole card (PRD: "dark cards with colored accents").
    func accentEdge(_ color: Color, cornerRadius: CGFloat = Radius.lg) -> some View {
        overlay(alignment: .leading) {
            Capsule()
                .fill(color)
                .frame(width: 4)
                .padding(.vertical, 12)
                .padding(.leading, 6)
                .shadow(color: color.opacity(0.6), radius: 6, x: 0, y: 0)
        }
    }

    /// Premium card with a colored left edge AND consistent breathing room between
    /// that edge and the content. Use this everywhere an accent-edged card is needed
    /// so the bar-to-content gap is identical across the whole app.
    func accentCard(_ color: Color,
                    cornerRadius: CGFloat = Radius.lg,
                    padding: CGFloat = Space.md,
                    glow: Color? = nil) -> some View {
        self
            .padding(.leading, 12)
            .premiumCard(cornerRadius: cornerRadius, padding: padding, glow: glow)
            .accentEdge(color, cornerRadius: cornerRadius)
    }
}

// MARK: - Haptics

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
    static func select() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Reusable text helpers

extension Text {
    /// Eyebrow / overline label — small, tracked, secondary.
    func eyebrow() -> some View {
        self.font(.system(size: 11, weight: .semibold, design: .rounded))
            .tracking(1.4)
            .foregroundStyle(Color.somaTextSecondary)
    }
}
