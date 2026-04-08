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

    // MARK: - Illness Arc (3.1)
    /// True when wrist temperature has exceeded +0.5°C for 2+ consecutive nights.
    @Published var illnessArcActive: Bool = false
    /// How many consecutive nights of elevated temperature have been detected.
    @Published var illnessArcDays: Int = 0

    // MARK: - Weekly Summary (3.4)
    @Published var weeklySummary: WeeklySummaryEngine.WeeklySummary?

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
            let recentHistory = store.loadLast(7)
            let (arcActive, arcDays) = detectIllnessArc(from: recentHistory, today: cached)
            illnessArcActive = arcActive
            illnessArcDays   = arcDays
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
            var metrics = try await fetchAndComputeMetrics(for: Date())

            // 3.1 — Illness arc detection: must run before computeGuidance so the
            // guidance override (forced Rest) can read illnessArcActive.
            let recentHistory = store.loadLast(7)
            let (arcActive, arcDays) = detectIllnessArc(from: recentHistory, today: metrics)
            illnessArcActive = arcActive
            illnessArcDays   = arcDays

            // Compute guidance (reads illnessArcActive for illness override).
            let guidance = computeGuidance(for: metrics)

            // 3.3 — Persist readiness score so it can be trended and shown in the hero ring.
            metrics.readinessScore = guidance.readinessScore

            store.save(metrics)
            todayMetrics = metrics
            lastRefreshed = Date()
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastRefreshedTimestamp")

            InsightCache.shared.invalidatePhysio()

            bedtimeTarget = SleepCalculator.bedtimeTarget(
                wakeTime: settings.wakeTime,
                sleepNeed: metrics.sleepNeedHours ?? settings.sleepGoalHours
            )

            trainingGuidance = guidance
            store.setWidgetTrainingLabel(guidance.activityLevel.shortTitle)

            NotificationScheduler.shared.scheduleRecoveryNotification(metrics: metrics, guidance: guidance, settings: settings)

            // 3.4 — Weekly narrative: generate and schedule every Monday.
            generateAndScheduleWeeklySummaryIfNeeded(metrics: metrics)

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
        // Priority 2 data sources
        async let standHoursFetch      = healthKit.fetchStandHours(for: date)
        async let walkingHRFetch       = healthKit.fetchWalkingHRAverage(for: date)
        async let mindfulMinutesFetch  = healthKit.fetchMindfulMinutes(for: date)
        async let wristTempFetch       = healthKit.fetchWristTemperature(for: date)

        let (hrvValues, rhrValue, hrData, sleepData, activeCalories, stepCount,
             vo2Max, respRateVal, bloodOxygen, exerciseMinutes, hrvHist, rhrHist,
             standHoursVal, walkingHRVal, mindfulMinsVal) = try await (
                hrv, rhr, hrSamples, sleepFetch, calories, steps, vo2, respRate,
                bloodOx, exerciseMin, hrvHistory, rhrHistory,
                standHoursFetch, walkingHRFetch, mindfulMinutesFetch
             )
        let wristTempVal = try? await wristTempFetch

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
        // Use sleeping HRV for recovery — it's measured overnight and stays stable after waking.
        // Falls back to daytime HRV average only if no sleep window was detected.
        let recoveryHRV = sleepingHRV ?? todayHRV

        // ACR: compute before recovery so penalty can feed into RecoveryCalculator
        let acrHistory = store.loadLast(28)
        let acr = TrainingGuidanceEngine.acrRatio(history: acrHistory)

        let recoveryScore = RecoveryCalculator.calculate(input: RecoveryInput(
            todayHRV: recoveryHRV,
            hrvBaseline: hrvBaseline,
            todayRestingHR: rhrValue,
            rhrBaseline: rhrBaseline,
            sleepScore: sleepScore,
            yesterdayStrain: yesterdayStrain_0_21,
            acr: acr
        ))

        // Daytime stress (8AM – 8PM) + mindful minutes bonus
        // If HealthKit has no mindful session data but the manual Check-In shows "Meditated",
        // use a conservative 15-min proxy so the feedback loop closes even without a mindfulness app.
        let todayCheckIn = checkInStore.loadAll().first {
            Calendar.current.isDateInToday($0.date) || Calendar.current.isDateInYesterday($0.date)
        }
        let effectiveMindfulMins: Double? = {
            if mindfulMinsVal > 0 { return mindfulMinsVal }
            if todayCheckIn?.meditated == true { return 15 }
            return nil
        }()
        let daytimeSamples = StressCalculator.filterDaytime(hrData, on: date)
        let stressScore = StressCalculator.calculate(
            daytimeHRV: todayHRV,
            daytimeAvgHR: StressCalculator.average(daytimeSamples),
            hrvBaseline: hrvBaseline,
            rhrBaseline: rhrBaseline,
            mindfulMinutes: effectiveMindfulMins
        )

        // Evening stress (8PM – 11PM) — HR elevation only since HRV isn't windowed separately
        let eveningSamples   = StressCalculator.filterEvening(hrData, on: date)
        let eveningStressScore = StressCalculator.calculateEveningStress(
            eveningAvgHR: StressCalculator.average(eveningSamples),
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

        // Sleep consistency score — stddev of sleep start/end times across prior 7 stored days
        let consistencyWindow = last30
            .filter { Calendar.current.startOfDay(for: $0.date) < Calendar.current.startOfDay(for: date) }
            .sorted { $0.date < $1.date }
            .suffix(7)
        let sleepConsistencyScore = SleepConsistencyCalculator.calculate(
            startTimes: Array(consistencyWindow).map { $0.sleepStartTime },
            endTimes:   Array(consistencyWindow).map { $0.sleepEndTime }
        )

        // Per-workout HR zone breakdown (2.4)
        let workoutZoneDetails: [WorkoutZoneBreakdown]? = strainResult.details.isEmpty ? nil :
            strainResult.details.map { d in
                WorkoutZoneBreakdown(
                    activityName: d.activityName,
                    totalStrain: d.strain,
                    z1Minutes: d.zoneMinutes[.zone1] ?? 0,
                    z2Minutes: d.zoneMinutes[.zone2] ?? 0,
                    z3Minutes: d.zoneMinutes[.zone3] ?? 0,
                    z4Minutes: d.zoneMinutes[.zone4] ?? 0,
                    z5Minutes: d.zoneMinutes[.zone5] ?? 0
                )
            }

        // Movement score (2.5): stand hours + steps + walking HR efficiency
        let movementScore = MovementScoreCalculator.calculate(
            standHours:       standHoursVal > 0 ? standHoursVal : nil,
            stepCount:        stepCount > 0 ? stepCount : nil,
            walkingHRAverage: walkingHRVal
        )

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
            napEndTime: sleepData.napEndTime,
            wristTempDeviation: wristTempVal,
            standHours: standHoursVal > 0 ? standHoursVal : nil,
            walkingHRAverage: walkingHRVal,
            mindfulMinutes: mindfulMinsVal > 0 ? mindfulMinsVal : nil,
            sleepConsistencyScore: sleepConsistencyScore,
            eveningStressScore: eveningStressScore,
            workoutZoneDetails: workoutZoneDetails,
            movementScore: movementScore
        )
    }

    // MARK: - Illness Arc Detection (3.1)

    /// Returns whether an illness arc is active and how many consecutive elevated-temperature nights.
    /// An arc starts when wristTempDeviation > +0.5°C for 2 or more consecutive nights (most recent first).
    private func detectIllnessArc(from history: [DailyMetrics], today: DailyMetrics) -> (active: Bool, days: Int) {
        let all = (history + [today]).sorted { $0.date < $1.date }
        var consecutive = 0
        for m in all.reversed() {
            if let temp = m.wristTempDeviation, temp > 0.5 {
                consecutive += 1
            } else {
                break
            }
        }
        return (consecutive >= 2, consecutive)
    }

    // MARK: - Weekly Summary (3.4)

    private func generateAndScheduleWeeklySummaryIfNeeded(metrics: DailyMetrics) {
        // Only generate on Mondays (weekday = 2 in Gregorian calendar).
        let weekday = Calendar.current.component(.weekday, from: Date())
        guard weekday == 2 else { return }

        // Avoid regenerating if already done today.
        let key = "weeklySummaryGenerated"
        let todayKey = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        if UserDefaults.standard.double(forKey: key) == todayKey { return }

        let last7 = store.loadLast(7)
        let checkIns = checkInStore.loadAll()
        let last30 = store.loadLast(30)
        let hrvHist = BaselineCalculator.extractHistory(from: last30, \.hrvAverage)
        let rhrHist = BaselineCalculator.extractHistory(from: last30, \.restingHR)
        let hrvBaseline = BaselineCalculator.computeHRVBaseline(from: hrvHist)
        let rhrBaseline = BaselineCalculator.computeRHRBaseline(from: rhrHist)

        guard let summary = WeeklySummaryEngine.generate(
            metrics: last7,
            checkIns: checkIns,
            hrvBaseline: hrvBaseline,
            rhrBaseline: rhrBaseline
        ) else { return }

        weeklySummary = summary
        UserDefaults.standard.set(todayKey, forKey: key)
        NotificationScheduler.shared.scheduleWeeklyNarrative(summary: summary, settings: settings)
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

        var guidance = TrainingGuidanceEngine.generate(
            metrics: metrics,
            history: history,
            hrvBaseline: hrvBaseline,
            rhrBaseline: rhrBaseline,
            sleepGoal: sleepGoal,
            isCalibrating: isCalibrating
        )

        // 3.1 — Illness arc override: force Rest, disable all strain targets.
        if illnessArcActive {
            let illnessExplanation = "Elevated wrist temperature detected for \(illnessArcDays) consecutive night\(illnessArcDays == 1 ? "" : "s"). All strain targets are disabled — your body needs rest and recovery above all else right now."
            guidance = DailyTrainingGuidance(
                date: metrics.date,
                readinessScore: guidance.readinessScore,
                activityLevel: .rest,
                targetStrainMin: 0,
                targetStrainMax: 0,
                suggestedWorkouts: ["Rest", "Short walk", "Stretching", "Meditation"],
                fatigueFlags: ["Illness Arc"],
                factors: guidance.factors,
                explanation: illnessExplanation
            )
        }

        return guidance
    }

    // MARK: - Historical Backfill

    /// Called once on app launch. Backfills missing historical data needed for trends and calendar views.
    /// Focuses on the past 45 days for calendar grid, then fills longer history if completely empty.
    /// Runs silently in the background — does not affect isLoading or errorMessage.
    func backfillHistoricalDataIfNeeded() {
        Task {
            await backfillRecentMissingData()
            // Only do full backfill if store is completely empty
            if store.loadAll().isEmpty {
                await backfillMetrics()
            }
        }
    }
    
    /// Backfills any missing data in the past 45 days to ensure calendar and trends work properly
    private func backfillRecentMissingData() async {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        
        // Don't backfill data before Apple Health data is available
        guard let earliestHealthDate = await healthKit.fetchEarliestDataDate() else {
            print("⚠️ No Apple Health data available - skipping backfill")
            return 
        }
        
        let earliestDate = cal.startOfDay(for: earliestHealthDate)
        print("📅 Backfilling data from \(earliestDate) to today")
        
        // Check last 45 days for gaps, but respect earliest available date
        for dayOffset in -45...(-1) {
            guard let date = cal.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            
            // Skip if date is before Apple Health data availability
            if date < earliestDate {
                print("⏸️ Skipping \(date) - before Apple Health data availability (\(earliestDate))")
                continue
            }
            
            // Skip if we already have data for this date
            if store.load(for: date) != nil { continue }
            
            print("🔍 Attempting to backfill data for \(date)")
            
            // Try to fetch and compute metrics for this missing date
            if let metrics = try? await fetchAndComputeMetrics(for: date) {
                // More strict data validation - require at least one primary health metric from Apple Health
                // Don't save metrics that only have calculated/default values (like sleep need, strain scores, etc.)
                let hasPrimaryHealthData = (metrics.hrvAverage != nil && metrics.hrvAverage! > 0)
                    || (metrics.restingHR != nil && metrics.restingHR! > 0)
                    || (metrics.sleepDurationHours != nil && metrics.sleepDurationHours! > 0.1) // At least 6 minutes of sleep
                    || (metrics.activeCalories != nil && metrics.activeCalories! > 10) // At least 10 calories
                    || (metrics.stepCount != nil && metrics.stepCount! > 100) // At least 100 steps
                
                // Additional check: if we only have sleep need but no actual sleep, it's likely a default calculation
                let onlyHasCalculatedValues = metrics.sleepNeedHours != nil 
                    && metrics.sleepDurationHours == nil 
                    && metrics.hrvAverage == nil 
                    && metrics.restingHR == nil
                    && (metrics.activeCalories ?? 0) <= 10
                    && (metrics.stepCount ?? 0) <= 100
                
                let hasHealthData = hasPrimaryHealthData && !onlyHasCalculatedValues
                
                print("📊 Metrics summary for \(date):")
                print("  HRV: \(metrics.hrvAverage?.description ?? "nil")")
                print("  RHR: \(metrics.restingHR?.description ?? "nil")")
                print("  Sleep: \(metrics.sleepDurationHours?.description ?? "nil")h")
                print("  Calories: \(metrics.activeCalories?.description ?? "nil")")
                print("  Steps: \(metrics.stepCount?.description ?? "nil")")
                print("  Has valid data: \(hasHealthData)")
                
                if hasHealthData {
                    print("✅ Saved metrics for \(date)")
                    store.save(metrics)
                } else {
                    print("❌ No meaningful health data found for \(date)")
                }
            } else {
                print("❌ Failed to fetch metrics for \(date)")
            }
            
            // Small delay to prevent overwhelming HealthKit
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        // Update UI after backfill
        await MainActor.run {
            updateSparklines()
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
