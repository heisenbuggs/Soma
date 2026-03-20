import Foundation
import Combine
import HealthKit

@MainActor
final class DashboardViewModel: ObservableObject {

    @Published var todayMetrics: DailyMetrics = .empty
    @Published var trainingGuidance: DailyTrainingGuidance?
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

    // Refresh interval: 1 hour when cache is enabled, 5 minutes when disabled.
    private var refreshInterval: TimeInterval {
        settings.cacheEnabled ? 60 * 60 : 5 * 60
    }

    var cacheEnabled: Bool { settings.cacheEnabled }
    var maxHR: Double { settings.maxHeartRate ?? StrainCalculator.estimatedMaxHR(age: settings.age) }

    init(healthKit: HealthDataProviding, store: MetricsStore, checkInStore: CheckInStore, settings: UserSettings) {
        self.healthKit = healthKit
        self.store = store
        self.checkInStore = checkInStore
        self.settings = settings
        // Restore lastRefreshed across app launches so the cache interval is respected.
        let ts = UserDefaults.standard.double(forKey: "lastRefreshedTimestamp")
        if ts > 0 { lastRefreshed = Date(timeIntervalSince1970: ts) }
    }

    // MARK: - Load

    func loadCached() {
        if let cached = store.load(for: Date()) {
            todayMetrics = cached
            trainingGuidance = computeGuidance(for: cached)
            updateSparklines()
            updateCoachingTips()
        }
        backfillHistoricalDataIfNeeded()
    }

    @discardableResult
    func refresh(force: Bool = false) -> Task<Void, Never>? {
        // Always fetch if there is no data for today yet.
        let noDataToday = store.load(for: Date()) == nil
        // Respect cache interval unless forced or there is no today's data.
        if !force, !noDataToday, let last = lastRefreshed,
           Date().timeIntervalSince(last) < refreshInterval {
            return nil
        }

        refreshTask?.cancel()
        refreshTask = Task {
            await fetchAllMetrics()
        }
        return refreshTask
    }

    // MARK: - Fetch

    private func fetchAllMetrics() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let metrics = try await fetchAndComputeMetrics(for: Date())

            store.save(metrics)
            todayMetrics = metrics
            lastRefreshed = Date()
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastRefreshedTimestamp")

            InsightCache.shared.invalidatePhysio()

            bedtimeTarget = SleepCalculator.bedtimeTarget(
                wakeTime: settings.wakeTime,
                sleepNeed: metrics.sleepNeedHours ?? settings.sleepGoalHours
            )

            let guidance = computeGuidance(for: metrics)
            trainingGuidance = guidance

            NotificationScheduler.shared.scheduleRecoveryNotification(metrics: metrics, guidance: guidance, settings: settings)

            updateSparklines()
            updateCoachingTips()

        } catch {
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Fetches all HealthKit data for `date` and computes a full `DailyMetrics` snapshot.
    /// Pure computation — no UI side effects. Used by both the live refresh and backfill.
    private func fetchAndComputeMetrics(for date: Date) async throws -> DailyMetrics {
        // Fetch all parallel data
        async let hrv        = healthKit.fetchHRV(for: date)
        async let rhr        = healthKit.fetchRestingHR(for: date)
        async let hrSamples  = healthKit.fetchHeartRateSamples(for: date)
        async let sleepFetch = healthKit.fetchSleepAnalysis(for: date)
        async let calories   = healthKit.fetchActiveEnergy(for: date)
        async let steps      = healthKit.fetchSteps(for: date)
        async let vo2        = healthKit.fetchVO2Max()
        async let respRate   = healthKit.fetchRespiratoryRate(for: date)
        async let bloodOx    = healthKit.fetchBloodOxygen(for: date)
        async let exerciseMin = healthKit.fetchExerciseMinutes(for: date)
        async let hrvHistory = healthKit.fetchHRVHistory(days: 30)
        async let rhrHistory = healthKit.fetchRestingHRHistory(days: 30)

        let (hrvValues, rhrValue, hrData, sleepData, activeCalories, stepCount,
             vo2Max, respRateVal, bloodOxygen, exerciseMinutes, hrvHist, rhrHist) = try await (
                hrv, rhr, hrSamples, sleepFetch, calories, steps, vo2, respRate,
                bloodOx, exerciseMin, hrvHistory, rhrHistory
             )

        // Fetch workouts independently so a failure here doesn't zero out all scores
        let fetchedWorkouts = (try? await healthKit.fetchWorkouts(for: date)) ?? []

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

        // Previous day
        let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        let yesterdayStrainScore = store.load(for: previousDay)?.strainScore ?? 0
        
        // Convert strain score (0-100) to 0-21 scale expected by health calculators
        // RecoveryCalculator and SleepCalculator expect 0-21 range for proper scaling
        let yesterdayStrain_0_21 = (yesterdayStrainScore / 100.0) * 21.0

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
            yesterdayStrain: yesterdayStrain_0_21
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
        // Falls back to estimatedCalibrationCapacity (500) during the first 7 days.
        let strainLoadHistory = store.loadLast(StrainCalculator.rollingCapacityDays)
            .compactMap { $0.strainLoad }
        let strainCapacity = StrainCalculator.capacity(fromLoads: strainLoadHistory)
        let strainScore = StrainCalculator.score(load: strainResult.total, capacity: strainCapacity)

        let todayHRV = hrvValues.isEmpty ? nil : hrvValues.reduce(0, +) / Double(hrvValues.count)
        let recoveryScore = RecoveryCalculator.calculate(input: RecoveryInput(
            todayHRV: todayHRV,
            hrvBaseline: hrvBaseline,
            todayRestingHR: rhrValue,
            rhrBaseline: rhrBaseline,
            sleepScore: sleepScore,
            yesterdayStrain: yesterdayStrain_0_21
        ))

        // Stress
        let daytimeSamples = StressCalculator.filterDaytime(hrData, on: date)
        let stressScore = StressCalculator.calculate(
            daytimeHRV: todayHRV,
            daytimeAvgHR: StressCalculator.average(daytimeSamples),
            hrvBaseline: hrvBaseline,
            rhrBaseline: rhrBaseline
        )

        // Ayurvedic sleep points — anchor to the evening of the prior calendar day
        let eveningDate = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        let ayurvedicPoints: Double? = {
            guard let start = sleepData.sleepStartTime, let end = sleepData.sleepEndTime else { return nil }
            return AyurvedicSleepCalculator.calculate(
                intervals: [(start: start, end: end)],
                eveningDate: eveningDate
            )
        }()

        return DailyMetrics(
            date: date,
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
            bloodOxygen: bloodOxygen,
            exerciseMinutes: exerciseMinutes,
            sleepingHR: sleepingHR,
            sleepingHRV: sleepingHRV,
            sleepInterruptions: sleepData.interruptionCount,
            strainLoad: strainResult.total,
            workoutStrain: strainResult.workoutStrain,
            incidentalStrain: strainResult.incidentalStrain,
            workoutMinutes: workoutMinutes,
            sleepStartTime: sleepData.sleepStartTime,
            sleepEndTime: sleepData.sleepEndTime,
            ayurvedicSleepPoints: ayurvedicPoints,
            napDurationMinutes: sleepData.napDurationSeconds > 0 ? sleepData.napDurationSeconds / 60.0 : nil,
            napStartTime: sleepData.napStartTime,
            napEndTime: sleepData.napEndTime
        )
    }

    // MARK: - Training Guidance

    private func computeGuidance(for metrics: DailyMetrics) -> DailyTrainingGuidance {
        let last30 = store.loadLast(30)
        let history = store.loadLast(28)

        let hrvHist = BaselineCalculator.extractHistory(from: last30, \.hrvAverage)
        let rhrHist = BaselineCalculator.extractHistory(from: last30, \.restingHR)
        let hrvBaseline = BaselineCalculator.computeHRVBaseline(from: hrvHist)
        let rhrBaseline = BaselineCalculator.computeRHRBaseline(from: rhrHist)

        let sleepGoalStored = UserDefaults.standard.double(forKey: "baselineSleepHours")
        let sleepGoal = sleepGoalStored > 0 ? sleepGoalStored : 7.0

        let strainLoadHistory = store.loadLast(StrainCalculator.rollingCapacityDays).compactMap { $0.strainLoad }
        let isCalibrating = StrainCalculator.isCalibrating(loadHistory: strainLoadHistory)

        return TrainingGuidanceEngine.generate(
            metrics: metrics,
            history: history,
            hrvBaseline: hrvBaseline,
            rhrBaseline: rhrBaseline,
            sleepGoal: sleepGoal,
            isCalibrating: isCalibrating
        )
    }

    // MARK: - Historical Backfill

    /// Called once on app launch. If the store is empty (fresh install or reset),
    /// fetches and computes metrics for the past 90 days from HealthKit history.
    /// Runs silently in the background — does not affect isLoading or errorMessage.
    func backfillHistoricalDataIfNeeded() {
        guard store.loadAll().isEmpty else { return }
        Task {
            await backfillMetrics()
        }
    }

    private func backfillMetrics() async {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // Ask HealthKit for the oldest heart rate sample — that's effectively
        // when the user first wore Apple Watch. Fall back to 1 year if unavailable.
        let earliestDate: Date
        if let first = await healthKit.fetchEarliestDataDate() {
            earliestDate = cal.startOfDay(for: first)
        } else {
            earliestDate = cal.date(byAdding: .day, value: -365, to: today)!
        }

        let totalDays = cal.dateComponents([.day], from: earliestDate, to: today).day ?? 365

        // Go oldest-first so rolling averages (capacity, sleep need) build correctly
        // as each day's stored metrics become available to the next day's computation.
        for dayOffset in stride(from: -totalDays, through: -1, by: 1) {
            guard let date = cal.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            guard store.load(for: date) == nil else { continue }

            if let metrics = try? await fetchAndComputeMetrics(for: date) {
                // Skip days with no HealthKit data at all (before Apple Watch was set up).
                let hasData = metrics.hrvAverage != nil
                    || metrics.restingHR != nil
                    || (metrics.sleepDurationHours ?? 0) > 0
                    || (metrics.activeCalories ?? 0) > 0
                    || (metrics.stepCount ?? 0) > 0
                if hasData {
                    store.save(metrics)
                }
            }
        }

        updateSparklines()
        updateCoachingTips()
    }

    // MARK: - Intraday HR

    /// Returns raw heart-rate samples for a given date, used for the intraday stress chart.
    func fetchIntradayHR(for date: Date) async -> [(Date, Double)] {
        (try? await healthKit.fetchHeartRateSamples(for: date)) ?? []
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
