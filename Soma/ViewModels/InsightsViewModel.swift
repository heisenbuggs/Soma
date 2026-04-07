import Foundation

struct Insight: Identifiable, Codable {
    let id: UUID
    let icon: String
    let title: String
    let description: String
    let priority: InsightPriority
    let date: Date

    init(icon: String, title: String, description: String, priority: InsightPriority, date: Date = Date()) {
        self.id = UUID()
        self.icon = icon
        self.title = title
        self.description = description
        self.priority = priority
        self.date = date
    }
}

enum InsightPriority: Int, Comparable, Codable {
    case high = 0   // red
    case medium = 1 // yellow
    case low = 2    // green

    static func < (lhs: InsightPriority, rhs: InsightPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var colorStateName: String {
        switch self {
        case .high:   return "red"
        case .medium: return "yellow"
        case .low:    return "green"
        }
    }
}

@MainActor
final class InsightsViewModel: ObservableObject {

    @Published var insights: [Insight] = []
    @Published var behaviorInsights: [BehaviorInsight] = []
    @Published var trainingGuidance: DailyTrainingGuidance?

    private let store: MetricsStore
    private let checkInStore: CheckInStore

    init(store: MetricsStore, checkInStore: CheckInStore) {
        self.store = store
        self.checkInStore = checkInStore
    }

    /// Loads insights from cache if fresh, or recomputes if stale.
    /// - Parameter forceRefresh: When true, always recomputes regardless of cache state.
    func generateInsights(forceRefresh: Bool = false) {
        let latestMetrics = store.load(for: Date())
        let latestCheckIn = checkInStore.loadAll().max { $0.date < $1.date }?.date

        let physioStale   = forceRefresh || InsightCache.shared.isPhysioStale(latestMetricsDate: latestMetrics?.date)
        let behaviorStale = forceRefresh || InsightCache.shared.isBehaviorStale(latestCheckInDate: latestCheckIn)

        // Load cached results first so the UI is never blank while recomputing
        if !physioStale, let cached = InsightCache.shared.loadPhysio() {
            insights = cached
        } else {
            generatePhysiologicalInsights()
        }

        if !behaviorStale, let cached = InsightCache.shared.loadBehavior() {
            behaviorInsights = cached
        } else {
            generateBehaviorInsights()
        }

        // Training guidance is always recomputed from stored data (fast, no HealthKit).
        if let today = latestMetrics {
            trainingGuidance = computeGuidance(for: today)
        }
    }

    private func computeGuidance(for metrics: DailyMetrics) -> DailyTrainingGuidance {
        let last30  = store.loadLast(30)
        let history = store.loadLast(28)

        let hrvHist     = BaselineCalculator.extractHistory(from: last30, \.hrvAverage)
        let rhrHist     = BaselineCalculator.extractHistory(from: last30, \.restingHR)
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

    // MARK: - Physiological Insights

    private func generatePhysiologicalInsights() {
        guard let today = store.load(for: Date()) else {
            insights = []
            return
        }

        let last7 = store.loadLast(7)
        let hrvHistory = BaselineCalculator.extractHistory(from: last7, \.hrvAverage)
        let hrvBaseline = BaselineCalculator.computeHRVBaseline(from: hrvHistory)

        var results: [Insight] = []

        // HRV vs baseline
        if let hrv = today.hrvAverage, let base = hrvBaseline, base > 0 {
            let ratio = hrv / base
            if ratio < 0.85 {
                let pct = Int((1.0 - ratio) * 100)
                results.append(Insight(
                    icon: "waveform.path.ecg",
                    title: "HRV Below Baseline",
                    description: "Your HRV is \(pct)% below baseline. Consider light activity or rest today.",
                    priority: .high
                ))
            } else if ratio > 1.10 {
                results.append(Insight(
                    icon: "heart.fill",
                    title: "HRV Elevated",
                    description: "Your HRV is elevated — your body is well recovered.",
                    priority: .low
                ))
            }
        }

        // Sleep interruptions
        if let interruptions = today.sleepInterruptions, interruptions >= 3 {
            results.append(Insight(
                icon: "moon.zzz.fill",
                title: "Fragmented Sleep",
                description: "Your sleep was interrupted \(interruptions) times. A consistent bedtime helps.",
                priority: .medium
            ))
        }

        // Sleep vs goal — compare against user-configured sleep goal (not computed need)
        let sleepGoalHours = UserDefaults.standard.double(forKey: "baselineSleepHours")
        let sleepGoal = sleepGoalHours > 0 ? sleepGoalHours : 7.0
        if let actual = today.sleepDurationHours {
            if actual >= sleepGoal {
                results.append(Insight(
                    icon: "moon.stars.fill",
                    title: "Sleep Goal Met",
                    description: "You met your sleep goal.",
                    priority: .low
                ))
            } else {
                let debtMinutes = Int((sleepGoal - actual) * 60)
                let debtHrs = debtMinutes / 60
                let debtMins = debtMinutes % 60
                let debtStr = debtMins == 0 ? "\(debtHrs)h" : "\(debtHrs)h \(debtMins)m"
                results.append(Insight(
                    icon: "bed.double.fill",
                    title: "Sleep Deficit",
                    description: "You slept \(debtStr) less than your sleep goal.",
                    priority: .medium
                ))
            }
        }

        // High strain streak
        if store.loadLast(3).filter({ $0.strainScore > 18 }).count >= 2 {
            results.append(Insight(
                icon: "flame.fill",
                title: "High Strain Streak",
                description: "High strain for multiple days — consider a recovery day.",
                priority: .high
            ))
        }

        // Low recovery
        if today.recoveryScore < 34 {
            results.append(Insight(
                icon: "arrow.down.heart.fill",
                title: "Low Recovery",
                description: "Low recovery. Prioritize rest, hydration, and sleep tonight.",
                priority: .high
            ))
        }

        // Elevated resting HR
        if let rhr = today.restingHR {
            let rhrHistory = BaselineCalculator.extractHistory(from: last7, \.restingHR)
            if let base = BaselineCalculator.computeRHRBaseline(from: rhrHistory), rhr > base + 3 {
                results.append(Insight(
                    icon: "heart.slash.fill",
                    title: "Elevated Resting HR",
                    description: "Resting heart rate is elevated — possible sign of fatigue or illness.",
                    priority: .medium
                ))
            }
        }

        // Wrist temperature illness signal (2.1) — Series 8+/Ultra only, iOS 17+
        if let tempDev = today.wristTempDeviation, tempDev > 0.5 {
            let formatted = String(format: "+%.1f°C", tempDev)
            results.append(Insight(
                icon: "thermometer.medium",
                title: "Elevated Wrist Temp",
                description: "Sleeping wrist temperature is \(formatted) above your baseline — a possible early illness signal. Consider rest and hydration.",
                priority: .high
            ))
        }

        // High stress
        if today.stressScore > 60 {
            results.append(Insight(
                icon: "brain.head.profile",
                title: "Elevated Stress",
                description: "Stress indicators are elevated. Consider breathing exercises or downtime.",
                priority: .medium
            ))
        }

        // Sleep debt
        let needVsActual: [(Double, Double)] = last7.compactMap { m in
            guard let actual = m.sleepDurationHours, let need = m.sleepNeedHours else { return nil }
            return (need, actual)
        }
        let totalDebt = SleepCalculator.computeSleepDebt(needVsActual: needVsActual)
        if totalDebt > 3 {
            results.append(Insight(
                icon: "zzz",
                title: "Sleep Debt",
                description: "You have \(String(format: "%.1f", totalDebt))h of accumulated sleep debt. Aim for early bedtime.",
                priority: .medium
            ))
        }

        let sorted = results.sorted { $0.priority < $1.priority }.prefix(5).map { $0 }
        insights = sorted
        InsightCache.shared.savePhysio(sorted)
    }

    // MARK: - Behavioral Insights (Behavior Intelligence Engine)

    private func generateBehaviorInsights() {
        let checkIns = checkInStore.loadAll()
        let metrics  = store.loadAll()
        let generated = BehaviorEngine.generateInsights(checkIns: checkIns, metrics: metrics)
        behaviorInsights = generated
        InsightCache.shared.saveBehavior(generated)
    }
}
