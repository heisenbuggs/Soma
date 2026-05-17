#if DEBUG
import SwiftUI
import HealthKit

// MARK: - Mock HealthDataProviding

final class PreviewHealthKit: HealthDataProviding {
    func requestAuthorization() async throws {}
    func fetchHRV(for date: Date) async throws -> [Double] { [42, 44, 48, 45, 46, 43, 47] }
    func fetchHRVHistory(days: Int) async throws -> [(Date, Double)] {
        (0..<min(days, 30)).map { i in
            (Calendar.current.date(byAdding: .day, value: -i, to: Date())!, [38, 42, 45, 48, 44, 52, 46, 50, 41, 47][i % 10])
        }
    }
    func fetchRestingHR(for date: Date) async throws -> Double? { 58 }
    func fetchRestingHRHistory(days: Int) async throws -> [(Date, Double)] {
        (0..<min(days, 30)).map { i in
            (Calendar.current.date(byAdding: .day, value: -i, to: Date())!, [56, 58, 60, 57, 59, 55, 61, 58, 57, 60][i % 10])
        }
    }
    func fetchHeartRateSamples(for date: Date) async throws -> [(Date, Double)] { [] }
    func fetchSleepAnalysis(for date: Date) async throws -> SleepData { .empty }
    func fetchSleepingHR(from start: Date, to end: Date) async throws -> Double? { 52 }
    func fetchSleepingHRV(from start: Date, to end: Date) async throws -> Double? { 44 }
    func fetchActiveEnergy(for date: Date) async throws -> Double { 420 }
    func fetchSteps(for date: Date) async throws -> Double { 8_500 }
    func fetchVO2Max() async throws -> Double? { 45.2 }
    func fetchVO2MaxHistory(days: Int) async throws -> [(Date, Double)] { [] }
    func fetchRespiratoryRate(for date: Date) async throws -> Double? { 14.5 }
    func fetchWorkouts(for date: Date) async throws -> [HKWorkout] { [] }
    func fetchSleepGoal() async throws -> Double? { 8.0 }
    func fetchBloodOxygen(for date: Date) async throws -> Double? { 98.5 }
    func fetchExerciseMinutes(for date: Date) async throws -> Double? { 45 }
    func writeBehavioralData(_ checkIn: DailyCheckIn) async throws {}
    func fetchEarliestDataDate() async -> Date? { Calendar.current.date(byAdding: .day, value: -90, to: Date()) }
    func fetchWristTemperature(for date: Date) async throws -> Double? { 0.1 }
    func fetchStandHours(for date: Date) async throws -> Int { 10 }
    func fetchWalkingHRAverage(for date: Date) async throws -> Double? { 88 }
    func fetchMindfulMinutes(for date: Date) async throws -> Double { 10 }
}

// MARK: - Mock DailyMetrics

extension DailyMetrics {
    static func mock(
        daysAgo: Int = 0,
        recovery: Double = 72,
        sleep: Double = 68,
        strain: Double = 45,
        stress: Double = 28,
        readiness: Double = 70
    ) -> DailyMetrics {
        let cal = Calendar.current
        let base = cal.date(byAdding: .day, value: -daysAgo, to: Date())!
        return DailyMetrics(
            date: base,
            recoveryScore: recovery,
            strainScore: strain,
            sleepScore: sleep,
            stressScore: stress,
            hrvAverage: 48,
            restingHR: 58,
            sleepDurationHours: 7.2,
            sleepNeedHours: 8.0,
            activeCalories: 420,
            stepCount: 8_500,
            vo2Max: 45.2,
            respiratoryRate: 14.5,
            bloodOxygen: 98.5,
            exerciseMinutes: 45,
            sleepingHR: 52,
            sleepingHRV: 44,
            sleepInterruptions: 2,
            deepSleepMinutes: 82,
            remSleepMinutes: 94,
            coreSleepMinutes: 256,
            sleepStartTime: cal.date(bySettingHour: 23, minute: 0, second: 0, of: base),
            sleepEndTime: cal.date(bySettingHour: 7, minute: 0, second: 0, of: base),
            readinessScore: readiness
        )
    }

    static var mockHistory: [DailyMetrics] {
        let recoveries: [Double] = [72, 65, 80, 58, 74, 88, 62, 70, 78, 55, 83, 67, 76, 90]
        let sleeps:     [Double] = [68, 72, 60, 75, 65, 80, 70, 58, 74, 66, 78, 62, 71, 85]
        let strains:    [Double] = [45, 62, 30, 55, 48, 70, 38, 52, 44, 60, 35, 58, 42, 65]
        let stresses:   [Double] = [28, 35, 22, 40, 30, 18, 45, 25, 32, 20, 38, 27, 33, 15]
        return (0..<14).map { i in
            .mock(daysAgo: i, recovery: recoveries[i], sleep: sleeps[i],
                  strain: strains[i], stress: stresses[i], readiness: recoveries[i] * 0.9)
        }
    }
}

// MARK: - Mock DailyTrainingGuidance

extension DailyTrainingGuidance {
    static var mock: DailyTrainingGuidance {
        DailyTrainingGuidance(
            date: Date(),
            readinessScore: 72,
            activityLevel: .hard,
            targetStrainMin: 40,
            targetStrainMax: 60,
            suggestedWorkouts: ["Zone 2 Run", "Strength Training", "Mobility Work"],
            fatigueFlags: [],
            factors: ReadinessFactors(
                recoveryScore: 78,
                sleepScore: 71,
                hrvRatio: 1.05,
                rhrDelta: -1,
                sleepDebtHours: 0.5,
                yesterdayStrain: 42,
                acrRatio: 1.1,
                vo2Max: 45.2,
                fitnessMultiplier: 1.0
            ),
            explanation: "HRV is above baseline and sleep debt is minimal. A hard training day is well supported."
        )
    }

    static var mockLow: DailyTrainingGuidance {
        DailyTrainingGuidance(
            date: Date(),
            readinessScore: 32,
            activityLevel: .light,
            targetStrainMin: 10,
            targetStrainMax: 25,
            suggestedWorkouts: ["Easy Walk", "Yoga", "Stretching"],
            fatigueFlags: ["High sleep debt", "HRV below baseline"],
            factors: ReadinessFactors(
                recoveryScore: 38,
                sleepScore: 45,
                hrvRatio: 0.88,
                rhrDelta: 4,
                sleepDebtHours: 2.5,
                yesterdayStrain: 78,
                acrRatio: 0.72,
                vo2Max: 44.8,
                fitnessMultiplier: 0.9
            ),
            explanation: "Sleep debt is elevated and HRV is suppressed. Prioritise rest today."
        )
    }
}

// MARK: - Preview ViewModels

extension DashboardViewModel {
    static var preview: DashboardViewModel {
        DashboardViewModel(
            healthKit: PreviewHealthKit(),
            store: MetricsStore(),
            checkInStore: CheckInStore(),
            settings: UserSettings()
        )
    }
}

#endif
