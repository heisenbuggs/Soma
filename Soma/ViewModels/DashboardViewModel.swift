import Foundation
import Combine
import HealthKit

@MainActor
final class DashboardViewModel: ObservableObject {

    @Published var todayMetrics: DailyMetrics = .empty
    @Published var sparklineData: [String: [Double]] = [:]  // "recovery", "strain", "sleep", "stress"
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isBaselineBuilding = false
    @Published var coachingTips: [String] = []
    @Published var bedtimeTarget: Date?
    @Published var lastRefreshed: Date?

    private let healthKit: HealthDataProviding
    private let store: MetricsStore
    private let checkInStore: CheckInStore
    private let settings: UserSettings
    private var refreshTask: Task<Void, Never>?

    private let minRefreshInterval: TimeInterval = 5 * 60  // 5 minutes

    init(healthKit: HealthDataProviding, store: MetricsStore, checkInStore: CheckInStore, settings: UserSettings) {
        self.healthKit = healthKit
        self.store = store
        self.checkInStore = checkInStore
        self.settings = settings
    }

    // MARK: - Load

    func loadCached() {
        if let cached = store.load(for: Date()) {
            todayMetrics = cached
            updateSparklines()
            updateCoachingTips()
        }
    }

    func refresh(force: Bool = false) {
        // Debounce
        if !force, let last = lastRefreshed,
           Date().timeIntervalSince(last) < minRefreshInterval {
            return
        }

        refreshTask?.cancel()
        refreshTask = Task {
            await fetchAllMetrics()
        }
    }

    // MARK: - Fetch

    private func fetchAllMetrics() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let today = Date()

        do {
            // Fetch all parallel data
            async let hrv        = healthKit.fetchHRV(for: today)
            async let rhr        = healthKit.fetchRestingHR(for: today)
            async let hrSamples  = healthKit.fetchHeartRateSamples(for: today)
            async let sleepFetch = healthKit.fetchSleepAnalysis(for: today)
            async let calories   = healthKit.fetchActiveEnergy(for: today)
            async let steps      = healthKit.fetchSteps(for: today)
            async let vo2        = healthKit.fetchVO2Max()
            async let respRate   = healthKit.fetchRespiratoryRate(for: today)
            async let hrvHistory = healthKit.fetchHRVHistory(days: 30)
            async let rhrHistory = healthKit.fetchRestingHRHistory(days: 30)

            let (hrvValues, rhrValue, hrData, sleepData, activeCalories, stepCount,
                 vo2Max, respRateVal, hrvHist, rhrHist) = try await (
                    hrv, rhr, hrSamples, sleepFetch, calories, steps, vo2, respRate,
                    hrvHistory, rhrHistory
                 )

            // Fetch workouts independently so a failure here doesn't zero out all scores
            let fetchedWorkouts = (try? await healthKit.fetchWorkouts(for: today)) ?? []

            // Fetch sleeping-window signals (sequential — need sleep window first)
            var sleepingHR:  Double? = nil
            var sleepingHRV: Double? = nil
            if let start = sleepData.sleepStartTime, let end = sleepData.sleepEndTime {
                async let sHR  = healthKit.fetchSleepingHR(from: start, to: end)
                async let sHRV = healthKit.fetchSleepingHRV(from: start, to: end)
                (sleepingHR, sleepingHRV) = try await (sHR, sHRV)
            }

            // Baselines
            let hrvBaseline = BaselineCalculator.computeHRVBaseline(from: hrvHist)
            let rhrBaseline = BaselineCalculator.computeRHRBaseline(from: rhrHist)
            let last30 = store.loadLast(30)
            let sleepingHRHistory = BaselineCalculator.extractHistory(from: last30, \.sleepingHR)
            let sleepingHRBaseline = BaselineCalculator.computeBaseline(from: sleepingHRHistory)
            isBaselineBuilding = !BaselineCalculator.hasEnoughData(hrvHist)

            // Yesterday
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
            let yesterdayStrain = store.load(for: yesterday)?.strainScore ?? 0

            // Sleep goal: use HealthKit value (user's goal set in Health app),
            // fall back to the in-app baseline setting if not configured.
            let sleepGoal = (try? await healthKit.fetchSleepGoal()) ?? settings.sleepGoalHours

            // Sleep need: 3-day rolling debt window only — debt resets after 3 days.
            let last3 = store.loadLast(3)
            let recentActuals: [(Double, Double)] = last3.compactMap { m in
                guard let a = m.sleepDurationHours else { return nil }
                return (sleepGoal, a)
            }
            let sleepNeed = SleepCalculator.calculateSleepNeed(
                baselineSleep: sleepGoal,
                recentNeedVsActual: recentActuals,
                yesterdayStrain: yesterdayStrain
            )

            // Sleep score (5-component)
            let sleepScore = SleepCalculator.calculateScore(
                sleep: sleepData,
                sleepNeed: sleepNeed,
                sleepingHRV: sleepingHRV,
                sleepingHR: sleepingHR,
                hrvBaseline: hrvBaseline,
                sleepingHRBaseline: sleepingHRBaseline
            )

            // Workouts → workout-aware strain + workout minutes
            let workoutIntervals = fetchedWorkouts.map { w in
                StrainCalculator.WorkoutInterval(
                    start: w.startDate,
                    end: w.endDate,
                    activityName: w.workoutActivityType.displayName
                )
            }
            let workoutMinutes = fetchedWorkouts.isEmpty ? nil
                : fetchedWorkouts.reduce(0.0) { $0 + $1.duration / 60.0 }
            let maxHR = settings.maxHeartRate ?? StrainCalculator.estimatedMaxHR(age: settings.age)
            let strainResult = StrainCalculator.calculateWorkoutAware(
                workoutIntervals: workoutIntervals,
                allSamples: hrData,
                maxHR: maxHR
            )

            // Capacity model: use stored strainLoad history for rolling 14-day average.
            // Falls back to estimatedCalibrationCapacity (350) during the first 7 days.
            let strainLoadHistory = store.loadLast(StrainCalculator.rollingCapacityDays)
                .compactMap { $0.strainLoad }
            let strainCapacity = StrainCalculator.capacity(fromLoads: strainLoadHistory)
            let strainScore = StrainCalculator.score(load: strainResult.total, capacity: strainCapacity)

            // Recovery (weights: 40/25/25/10)
            let todayHRV = hrvValues.isEmpty ? nil : hrvValues.reduce(0, +) / Double(hrvValues.count)
            let recoveryScore = RecoveryCalculator.calculate(input: RecoveryInput(
                todayHRV: todayHRV,
                hrvBaseline: hrvBaseline,
                todayRestingHR: rhrValue,
                rhrBaseline: rhrBaseline,
                sleepScore: sleepScore,
                yesterdayStrain: yesterdayStrain
            ))

            // Stress
            let daytimeSamples = StressCalculator.filterDaytime(hrData, on: today)
            let stressScore = StressCalculator.calculate(
                daytimeHRV: todayHRV,
                daytimeAvgHR: StressCalculator.average(daytimeSamples),
                hrvBaseline: hrvBaseline,
                rhrBaseline: rhrBaseline
            )

            // Ayurvedic sleep points — anchor to the evening of the prior calendar day
            let eveningDate = Calendar.current.date(byAdding: .day, value: -1, to: today)!
            let ayurvedicPoints: Double? = {
                guard let start = sleepData.sleepStartTime, let end = sleepData.sleepEndTime else { return nil }
                return AyurvedicSleepCalculator.calculate(
                    intervals: [(start: start, end: end)],
                    eveningDate: eveningDate
                )
            }()

            let metrics = DailyMetrics(
                date: today,
                recoveryScore: recoveryScore,
                strainScore: strainScore,
                sleepScore: sleepScore,
                stressScore: stressScore,
                hrvAverage: todayHRV,
                restingHR: rhrValue,
                sleepDurationHours: sleepData.totalDurationHours,
                sleepNeedHours: sleepNeed,
                activeCalories: activeCalories,
                stepCount: stepCount,
                vo2Max: vo2Max,
                respiratoryRate: respRateVal,
                sleepingHR: sleepingHR,
                sleepingHRV: sleepingHRV,
                sleepInterruptions: sleepData.interruptionCount,
                strainLoad: strainResult.total,
                workoutStrain: strainResult.workoutStrain,
                incidentalStrain: strainResult.incidentalStrain,
                workoutMinutes: workoutMinutes,
                sleepStartTime: sleepData.sleepStartTime,
                sleepEndTime: sleepData.sleepEndTime,
                ayurvedicSleepPoints: ayurvedicPoints
            )

            store.save(metrics)
            todayMetrics = metrics
            lastRefreshed = Date()

            // New metrics invalidate the physio insight cache so the next
            // Insights tab visit regenerates with fresh data.
            InsightCache.shared.invalidatePhysio()

            // Bedtime recommendation
            bedtimeTarget = SleepCalculator.bedtimeTarget(
                wakeTime: settings.wakeTime,
                sleepNeed: sleepNeed
            )

            // Push notification
            NotificationScheduler.shared.scheduleRecoveryNotification(metrics: metrics)

            updateSparklines()
            updateCoachingTips()

        } catch {
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - History

    func loadHistory(days: Int) -> [DailyMetrics] {
        store.loadLast(days)
    }

    // MARK: - Sparklines

    private func updateSparklines() {
        let recent = store.loadLast(7)
        sparklineData["recovery"] = recent.map { $0.recoveryScore }
        sparklineData["strain"]   = recent.map { $0.strainScore }
        sparklineData["sleep"]    = recent.map { $0.sleepScore }
        sparklineData["stress"]   = recent.map { $0.stressScore }
    }

    // MARK: - Coaching Tips

    private func updateCoachingTips() {
        let checkIns = checkInStore.loadAll()
        let metrics  = store.loadAll()
        let insights = BehaviorEngine.generateInsights(checkIns: checkIns, metrics: metrics)
        coachingTips = BehaviorEngine.coachingTips(
            todayMetrics: todayMetrics,
            recentCheckIns: Array(checkIns.suffix(7)),
            insights: insights
        )
    }
}
