import Foundation

/// Per-workout HR zone breakdown, stored as part of DailyMetrics.
/// Used to render a stacked zone bar chart in the Strain detail view.
struct WorkoutZoneBreakdown: Codable, Identifiable {
    var id: UUID = UUID()
    let activityName: String
    let totalStrain: Double
    var startTime: Date? = nil
    var durationMinutes: Double = 0
    var calories: Double? = nil
    var z1Minutes: Double = 0   // Zone 1 (Warm Up / ≤60% MaxHR)
    var z2Minutes: Double = 0   // Zone 2 (Fat Burn / 60–70%)
    var z3Minutes: Double = 0   // Zone 3 (Aerobic / 70–80%)
    var z4Minutes: Double = 0   // Zone 4 (Anaerobic / 80–90%)
    var z5Minutes: Double = 0   // Zone 5 (Max / >90%)

    var totalZoneMinutes: Double { z1Minutes + z2Minutes + z3Minutes + z4Minutes + z5Minutes }
    var activeZoneMinutes: Double { z2Minutes + z3Minutes + z4Minutes + z5Minutes }
}

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
    var bloodOxygen: Double?       // % SpO2 saturation
    var exerciseMinutes: Double?   // minutes of moderate-vigorous activity

    // Sleeping-window signals (used in sleep score)
    var sleepingHR: Double?        // avg HR during sleep window (bpm)
    var sleepingHRV: Double?       // avg HRV during sleep window (ms)
    var sleepInterruptions: Int?   // number of awake segments

    // Sleep stage durations (minutes) — night sleep only, excludes naps
    var deepSleepMinutes: Double?
    var remSleepMinutes: Double?
    var coreSleepMinutes: Double?

    // Workout-aware strain breakdown
    var workoutStrain: Double?     // strain attributed to HKWorkout sessions
    var incidentalStrain: Double?  // remaining strain from non-workout HR elevation
    var workoutMinutes: Double?    // total workout duration in minutes

    // Ayurvedic sleep timing
    var sleepStartTime: Date?
    var sleepEndTime: Date?
    var ayurvedicSleepPoints: Double?

    // Daytime nap data
    var napDurationMinutes: Double?
    var napStartTime: Date?
    var napEndTime: Date?

    // MARK: - New fields (Priority 2/3 features)

    /// Nightly wrist temperature deviation from personal baseline (°C). Apple Watch Series 8+ / Ultra only.
    /// Positive = above baseline (illness signal). Nil on unsupported hardware or older iOS.
    var wristTempDeviation: Double?

    /// Number of Apple Stand hours credited for the day (0–24). Measures incidental movement quality.
    var standHours: Int?

    /// Average heart rate during casual walking (bpm). Lower values indicate better cardiovascular efficiency.
    var walkingHRAverage: Double?

    /// Total mindful session minutes logged via the Mindfulness app or compatible apps.
    var mindfulMinutes: Double?

    /// Sleep consistency score (0–100): how stable bedtime and wake time are over the past 7 nights.
    /// Computed from standard deviation of sleep start/end times across the rolling window.
    var sleepConsistencyScore: Double?

    /// Evening stress score (0–100), computed from HR and HRV samples in the 8 PM – 11 PM window.
    /// Complements the daytime stress score (8 AM – 8 PM) to capture pre-sleep autonomic state.
    var eveningStressScore: Double?

    /// First-class stored readiness score (0–100). Promotes readiness from a derived training-guidance
    /// value to a persistent metric that can be trended, charted, and shown in widgets.
    var readinessScore: Double?

    /// VO2 Max trend: slope in ml/kg/min per 30-day period derived from rolling history.
    /// Positive = fitness improving, negative = declining.
    var vo2MaxTrend: Double?

    /// Per-workout HR zone breakdown for the day. Nil when no workouts were logged.
    var workoutZoneDetails: [WorkoutZoneBreakdown]?

    /// Combined movement quality score (0–100): step count + stand hours + walking HR efficiency.
    var movementScore: Double?

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
        bloodOxygen: Double? = nil,
        exerciseMinutes: Double? = nil,
        sleepingHR: Double? = nil,
        sleepingHRV: Double? = nil,
        sleepInterruptions: Int? = nil,
        deepSleepMinutes: Double? = nil,
        remSleepMinutes: Double? = nil,
        coreSleepMinutes: Double? = nil,
        strainLoad: Double? = nil,
        workoutStrain: Double? = nil,
        incidentalStrain: Double? = nil,
        workoutMinutes: Double? = nil,
        sleepStartTime: Date? = nil,
        sleepEndTime: Date? = nil,
        ayurvedicSleepPoints: Double? = nil,
        napDurationMinutes: Double? = nil,
        napStartTime: Date? = nil,
        napEndTime: Date? = nil,
        wristTempDeviation: Double? = nil,
        standHours: Int? = nil,
        walkingHRAverage: Double? = nil,
        mindfulMinutes: Double? = nil,
        sleepConsistencyScore: Double? = nil,
        eveningStressScore: Double? = nil,
        readinessScore: Double? = nil,
        vo2MaxTrend: Double? = nil,
        workoutZoneDetails: [WorkoutZoneBreakdown]? = nil,
        movementScore: Double? = nil
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
        self.bloodOxygen = bloodOxygen
        self.exerciseMinutes = exerciseMinutes
        self.sleepingHR = sleepingHR
        self.sleepingHRV = sleepingHRV
        self.sleepInterruptions = sleepInterruptions
        self.deepSleepMinutes = deepSleepMinutes
        self.remSleepMinutes = remSleepMinutes
        self.coreSleepMinutes = coreSleepMinutes
        self.strainLoad = strainLoad
        self.workoutStrain = workoutStrain
        self.incidentalStrain = incidentalStrain
        self.workoutMinutes = workoutMinutes
        self.sleepStartTime = sleepStartTime
        self.sleepEndTime = sleepEndTime
        self.ayurvedicSleepPoints = ayurvedicSleepPoints
        self.napDurationMinutes = napDurationMinutes
        self.napStartTime = napStartTime
        self.napEndTime = napEndTime
        self.wristTempDeviation = wristTempDeviation
        self.standHours = standHours
        self.walkingHRAverage = walkingHRAverage
        self.mindfulMinutes = mindfulMinutes
        self.sleepConsistencyScore = sleepConsistencyScore
        self.eveningStressScore = eveningStressScore
        self.readinessScore = readinessScore
        self.vo2MaxTrend = vo2MaxTrend
        self.workoutZoneDetails = workoutZoneDetails
        self.movementScore = movementScore
    }
}

extension DailyMetrics {
    static var empty: DailyMetrics {
        DailyMetrics(date: Date())
    }

    var recoveryState: ColorState {
        ColorState.recovery(score: recoveryScore.rounded())
    }

    var strainState: ColorState {
        ColorState.strain(score: strainScore.rounded())
    }

    var sleepState: ColorState {
        ColorState.sleep(score: sleepScore.rounded())
    }

    var stressState: ColorState {
        ColorState.stress(score: stressScore.rounded())
    }
}
