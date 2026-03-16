import Foundation

struct DailyMetrics: Identifiable, Codable {
    let id: UUID
    let date: Date

    // Scores
    var recoveryScore: Double      // 0–100
    var strainScore: Double        // 0–100
    var sleepScore: Double         // 0–100
    var stressScore: Double        // 0–100

    // Raw strain load (weighted zone-minutes, used for capacity model)
    var strainLoad: Double?

    // Raw values
    var hrvAverage: Double?        // ms (daytime)
    var restingHR: Double?         // bpm
    var sleepDurationHours: Double?
    var sleepNeedHours: Double?
    var activeCalories: Double?
    var stepCount: Double?
    var vo2Max: Double?
    var respiratoryRate: Double?

    // Sleeping-window signals (used in sleep score)
    var sleepingHR: Double?        // avg HR during sleep window (bpm)
    var sleepingHRV: Double?       // avg HRV during sleep window (ms)
    var sleepInterruptions: Int?   // number of awake segments

    // Workout-aware strain breakdown
    var workoutStrain: Double?     // strain attributed to HKWorkout sessions
    var incidentalStrain: Double?  // remaining strain from non-workout HR elevation
    var workoutMinutes: Double?    // total workout duration in minutes

    // Ayurvedic sleep timing
    var sleepStartTime: Date?
    var sleepEndTime: Date?
    var ayurvedicSleepPoints: Double?

    init(
        id: UUID = UUID(),
        date: Date,
        recoveryScore: Double = 0,
        strainScore: Double = 0,
        sleepScore: Double = 0,
        stressScore: Double = 0,
        hrvAverage: Double? = nil,
        restingHR: Double? = nil,
        sleepDurationHours: Double? = nil,
        sleepNeedHours: Double? = nil,
        activeCalories: Double? = nil,
        stepCount: Double? = nil,
        vo2Max: Double? = nil,
        respiratoryRate: Double? = nil,
        sleepingHR: Double? = nil,
        sleepingHRV: Double? = nil,
        sleepInterruptions: Int? = nil,
        strainLoad: Double? = nil,
        workoutStrain: Double? = nil,
        incidentalStrain: Double? = nil,
        workoutMinutes: Double? = nil,
        sleepStartTime: Date? = nil,
        sleepEndTime: Date? = nil,
        ayurvedicSleepPoints: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.recoveryScore = recoveryScore
        self.strainScore = strainScore
        self.sleepScore = sleepScore
        self.stressScore = stressScore
        self.hrvAverage = hrvAverage
        self.restingHR = restingHR
        self.sleepDurationHours = sleepDurationHours
        self.sleepNeedHours = sleepNeedHours
        self.activeCalories = activeCalories
        self.stepCount = stepCount
        self.vo2Max = vo2Max
        self.respiratoryRate = respiratoryRate
        self.sleepingHR = sleepingHR
        self.sleepingHRV = sleepingHRV
        self.sleepInterruptions = sleepInterruptions
        self.strainLoad = strainLoad
        self.workoutStrain = workoutStrain
        self.incidentalStrain = incidentalStrain
        self.workoutMinutes = workoutMinutes
        self.sleepStartTime = sleepStartTime
        self.sleepEndTime = sleepEndTime
        self.ayurvedicSleepPoints = ayurvedicSleepPoints
    }
}

extension DailyMetrics {
    static var empty: DailyMetrics {
        DailyMetrics(date: Date())
    }

    var recoveryState: ColorState {
        ColorState.recovery(score: recoveryScore)
    }

    var strainState: ColorState {
        ColorState.strain(score: strainScore)
    }

    var sleepState: ColorState {
        ColorState.sleep(score: sleepScore)
    }

    var stressState: ColorState {
        ColorState.stress(score: stressScore)
    }
}
