import Foundation

enum HeartRateZone: Int, CaseIterable {
    case zone1 = 1  // 50–60% HR reserve
    case zone2 = 2  // 60–70%
    case zone3 = 3  // 70–80%
    case zone4 = 4  // 80–90%
    case zone5 = 5  // 90–100%

    var weight: Double { Double(rawValue) }

    var label: String {
        switch self {
        case .zone1: return "Zone 1 (Warm Up)"
        case .zone2: return "Zone 2 (Fat Burn)"
        case .zone3: return "Zone 3 (Aerobic)"
        case .zone4: return "Zone 4 (Anaerobic)"
        case .zone5: return "Zone 5 (Max)"
        }
    }

    static func zone(for heartRate: Double, restingHR: Double, maxHR: Double) -> HeartRateZone {
        let reserve = maxHR - restingHR
        guard reserve > 0 else { return .zone1 }
        let intensity = (heartRate - restingHR) / reserve
        switch intensity {
        case ..<0.6:   return .zone1
        case 0.6..<0.7: return .zone2
        case 0.7..<0.8: return .zone3
        case 0.8..<0.9: return .zone4
        default:        return .zone5
        }
    }
}
