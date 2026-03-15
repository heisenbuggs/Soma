import Foundation

struct Insight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let priority: InsightPriority
}

enum InsightPriority: Int, Comparable {
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

    private let store: MetricsStore
    private let checkInStore: CheckInStore

    init(store: MetricsStore, checkInStore: CheckInStore) {
        self.store = store
        self.checkInStore = checkInStore
    }

    func generateInsights() {
        generatePhysiologicalInsights()
        generateBehaviorInsights()
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

        // Sleep vs need
        if let actual = today.sleepDurationHours, let need = today.sleepNeedHours, actual < need - 1 {
            let diff = String(format: "%.1f", need - actual)
            let needStr = String(format: "%.1f", need)
            results.append(Insight(
                icon: "bed.double.fill",
                title: "Sleep Deficit",
                description: "You slept \(diff)h less than your sleep need of \(needStr)h.",
                priority: .medium
            ))
        }

        // Excellent sleep
        if today.sleepScore >= 85 {
            results.append(Insight(
                icon: "moon.stars.fill",
                title: "Excellent Sleep",
                description: "Excellent sleep quality last night.",
                priority: .low
            ))
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

        insights = results.sorted { $0.priority < $1.priority }.prefix(5).map { $0 }
    }

    // MARK: - Behavioral Insights (Behavior Intelligence Engine)

    private func generateBehaviorInsights() {
        let checkIns = checkInStore.loadAll()
        let metrics  = store.loadAll()
        behaviorInsights = BehaviorEngine.generateInsights(checkIns: checkIns, metrics: metrics)
    }
}
