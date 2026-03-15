import SwiftUI

enum ColorState {
    case green(label: String)
    case yellow(label: String)
    case red(label: String)
    case blue(label: String)
    case orange(label: String)
    case gray(label: String)

    var color: Color {
        switch self {
        case .green:  return Color(hex: "00C853")
        case .yellow: return Color(hex: "FFD600")
        case .red:    return Color(hex: "FF1744")
        case .blue:   return Color(hex: "2979FF")
        case .orange: return Color(hex: "FF9100")
        case .gray:   return Color(hex: "8E8E93")
        }
    }

    var label: String {
        switch self {
        case .green(let l), .yellow(let l), .red(let l),
             .blue(let l), .orange(let l), .gray(let l):
            return l
        }
    }

    static func recovery(score: Double) -> ColorState {
        switch score {
        case 67...100: return .green(label: "Recovered")
        case 34..<67:  return .yellow(label: "Moderate")
        default:       return .red(label: "Low")
        }
    }

    static func strain(score: Double) -> ColorState {
        switch score {
        case 0..<10:  return .blue(label: "Light")
        case 10..<14: return .green(label: "Moderate")
        case 14..<18: return .orange(label: "High")
        default:      return .red(label: "Overreaching")
        }
    }

    static func sleep(score: Double) -> ColorState {
        switch score {
        case 90...100: return .green(label: "Excellent")
        case 75..<90:  return .green(label: "Good")
        case 60..<75:  return .yellow(label: "Moderate")
        default:       return .red(label: "Poor")
        }
    }

    static func stress(score: Double) -> ColorState {
        switch score {
        case 0...30:  return .green(label: "Low")
        case 31...60: return .yellow(label: "Moderate")
        default:      return .red(label: "High")
        }
    }
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
