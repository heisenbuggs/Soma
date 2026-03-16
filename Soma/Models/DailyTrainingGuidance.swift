import Foundation

// MARK: - Activity Level

enum ActivityLevel: Int, Codable, CaseIterable {
    case rest     = 1
    case light    = 2
    case moderate = 3
    case hard     = 4
    case peak     = 5

    var title: String {
        switch self {
        case .rest:     return "Rest Day"
        case .light:    return "Light Activity"
        case .moderate: return "Moderate Training"
        case .hard:     return "Hard Training"
        case .peak:     return "Peak Training"
        }
    }

    var shortTitle: String {
        switch self {
        case .rest:     return "Rest"
        case .light:    return "Light"
        case .moderate: return "Moderate"
        case .hard:     return "Hard"
        case .peak:     return "Peak"
        }
    }

    /// Hex color per PRD: Rest=Red, Light=Yellow, Moderate=Blue, Hard=Green, Peak=Purple
    var colorHex: String {
        switch self {
        case .rest:     return "FF1744"
        case .light:    return "FFD600"
        case .moderate: return "2979FF"
        case .hard:     return "00C853"
        case .peak:     return "AA00FF"
        }
    }

    var icon: String {
        switch self {
        case .rest:     return "bed.double.fill"
        case .light:    return "figure.walk"
        case .moderate: return "figure.run"
        case .hard:     return "bolt.fill"
        case .peak:     return "flame.fill"
        }
    }

    /// Base target strain range before VO2Max multiplier is applied.
    var baseTargetStrainMin: Int {
        switch self {
        case .rest:     return 0
        case .light:    return 10
        case .moderate: return 25
        case .hard:     return 40
        case .peak:     return 60
        }
    }

    var baseTargetStrainMax: Int {
        switch self {
        case .rest:     return 20
        case .light:    return 30
        case .moderate: return 45
        case .hard:     return 70
        case .peak:     return 90
        }
    }
}

// MARK: - Readiness Factors

/// The individual physiological inputs that drove the readiness score.
struct ReadinessFactors: Codable {
    let recoveryScore: Double
    let sleepScore: Double
    let hrvRatio: Double?        // HRV today / HRV baseline (nil if no baseline)
    let rhrDelta: Double?        // RHR today − RHR baseline (nil if no baseline)
    let sleepDebtHours: Double   // sleepGoal − lastNightSleep, floored at 0
    let yesterdayStrain: Double
    let acrRatio: Double?        // 7-day avg strain / 28-day avg strain
    let vo2Max: Double?
    let fitnessMultiplier: Double
}

// MARK: - DailyTrainingGuidance

struct DailyTrainingGuidance: Codable, Identifiable {
    let id: UUID
    let date: Date
    let readinessScore: Double      // 0–100
    let activityLevel: ActivityLevel
    let targetStrainMin: Int        // adjusted for VO2Max multiplier + ACR cap
    let targetStrainMax: Int
    let suggestedWorkouts: [String]
    let fatigueFlags: [String]      // e.g. "Cardio/Legs", "Accumulated Training Load"
    let factors: ReadinessFactors
    let explanation: String         // human-readable summary of why this level was chosen

    init(
        id: UUID = UUID(),
        date: Date,
        readinessScore: Double,
        activityLevel: ActivityLevel,
        targetStrainMin: Int,
        targetStrainMax: Int,
        suggestedWorkouts: [String],
        fatigueFlags: [String],
        factors: ReadinessFactors,
        explanation: String
    ) {
        self.id = id
        self.date = date
        self.readinessScore = readinessScore
        self.activityLevel = activityLevel
        self.targetStrainMin = targetStrainMin
        self.targetStrainMax = targetStrainMax
        self.suggestedWorkouts = suggestedWorkouts
        self.fatigueFlags = fatigueFlags
        self.factors = factors
        self.explanation = explanation
    }
}
