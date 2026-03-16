import Foundation

enum HeartRateZone: Int, CaseIterable {
    case zone1 = 1  // 50–60% MaxHR
    case zone2 = 2  // 60–70% MaxHR
    case zone3 = 3  // 70–80% MaxHR
    case zone4 = 4  // 80–90% MaxHR
    case zone5 = 5  // 90–100% MaxHR

    var weight: Double {
        switch self {
        case .zone1: return 0  // recovery — no strain contribution
        case .zone2: return 1
        case .zone3: return 2
        case .zone4: return 3
        case .zone5: return 4
        }
    }

    var label: String {
        switch self {
        case .zone1: return "Zone 1 (Warm Up)"
        case .zone2: return "Zone 2 (Fat Burn)"
        case .zone3: return "Zone 3 (Aerobic)"
        case .zone4: return "Zone 4 (Anaerobic)"
        case .zone5: return "Zone 5 (Max)"
        }
    }

    /// Classify a heart rate into a zone using MaxHR percentage thresholds.
    /// Zones: Z1=50–60%, Z2=60–70%, Z3=70–80%, Z4=80–90%, Z5=90–100%.
    /// HR below 50% MaxHR is passive physiology; callers should skip it before calling this.
    static func zone(for heartRate: Double, maxHR: Double) -> HeartRateZone {
        guard maxHR > 0 else { return .zone1 }
        let pct = heartRate / maxHR
        switch pct {
        case ..<0.6:    return .zone1
        case 0.6..<0.7: return .zone2
        case 0.7..<0.8: return .zone3
        case 0.8..<0.9: return .zone4
        default:        return .zone5
        }
    }
}
