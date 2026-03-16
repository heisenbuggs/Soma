import SwiftUI

enum ColorState {
    case green(label: String)
    case lightGreen(label: String)
    case yellow(label: String)
    case red(label: String)
    case blue(label: String)
    case orange(label: String)
    case gray(label: String)

    var color: Color {
        switch self {
        case .green:      return Color(hex: "00C853")
        case .lightGreen: return Color(hex: "69F0AE")
        case .yellow:     return Color(hex: "FFD600")
        case .red:        return Color(hex: "FF1744")
        case .blue:       return Color(hex: "2979FF")
        case .orange:     return Color(hex: "FF9100")
        case .gray:       return Color(hex: "8E8E93")
        }
    }

    var label: String {
        switch self {
        case .green(let l), .lightGreen(let l), .yellow(let l),
             .red(let l), .blue(let l), .orange(let l), .gray(let l):
            return l
        }
    }

    // MARK: - Recovery
    // 85–100 Excellent | 70–84 Good | 50–69 Moderate | 30–49 Low | 0–29 Very Low

    static func recovery(score: Double) -> ColorState {
        switch score {
        case 85...100: return .green(label: "Excellent")
        case 70..<85:  return .lightGreen(label: "Good")
        case 50..<70:  return .yellow(label: "Moderate")
        case 30..<50:  return .orange(label: "Low")
        default:       return .red(label: "Very Low")
        }
    }

    // MARK: - Strain
    // 80–100 Very High | 60–79 High | 40–59 Moderate | 20–39 Light | 0–19 Minimal

    static func strain(score: Double) -> ColorState {
        switch score {
        case 80...100: return .red(label: "Very High")
        case 60..<80:  return .orange(label: "High")
        case 40..<60:  return .yellow(label: "Moderate")
        case 20..<40:  return .lightGreen(label: "Light")
        default:       return .blue(label: "Minimal")
        }
    }

    // MARK: - Sleep
    // 90–100 Excellent | 75–89 Good | 60–74 Fair | 40–59 Poor | 0–39 Very Poor

    static func sleep(score: Double) -> ColorState {
        switch score {
        case 90...100: return .green(label: "Excellent")
        case 75..<90:  return .lightGreen(label: "Good")
        case 60..<75:  return .yellow(label: "Fair")
        case 40..<60:  return .orange(label: "Poor")
        default:       return .red(label: "Very Poor")
        }
    }

    // MARK: - Stress
    // 0–30 Low | 31–60 Moderate | 61–100 High

    static func stress(score: Double) -> ColorState {
        switch score {
        case 0...30:  return .green(label: "Low")
        case 31...60: return .yellow(label: "Moderate")
        default:      return .red(label: "High")
        }
    }
}

// MARK: - Semantic Adaptive Colors

extension Color {
    /// App background — white in light mode, black in dark mode.
    static var somaBackground: Color { Color(.systemBackground) }
    /// Card / grouped content background — light grey / dark grey.
    static var somaCard: Color { Color(.secondarySystemBackground) }
    /// Elevated card surface.
    static var somaCardElevated: Color { Color(.tertiarySystemBackground) }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255,
                            (int >> 8) * 17,
                            (int >> 4 & 0xF) * 17,
                            (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255,
                            int >> 16,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24,
                            int >> 16 & 0xFF,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
