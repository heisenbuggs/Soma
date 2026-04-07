import Foundation
import WidgetKit

// MARK: - Widget snapshot (mirrored in SomaWidgets.swift)

/// Direction a score is trending vs. the prior 6-day average.
enum TrendDirection: String, Codable {
    case up, flat, down
}

struct WidgetMetricsSnapshot: Codable {
    let recoveryScore: Double
    let strainScore: Double
    let sleepScore: Double
    let stressScore: Double
    let date: Date
    // Trend arrows — optional so existing snapshots decode without these keys.
    var recoveryTrend: TrendDirection? = nil
    var strainTrend: TrendDirection? = nil
    var sleepTrend: TrendDirection? = nil
    var stressTrend: TrendDirection? = nil
    /// Short label for today's training guidance level, e.g. "Active Recovery", "Hard".
    var trainingLevelLabel: String? = nil
}

// MARK: - MetricsStore (UserDefaults + Codable)

final class MetricsStore: ObservableObject {
    private let key        = "storedDailyMetrics"
    private let widgetKey  = "WidgetMetricsSnapshot"
    private let maxDays    = 1825  // 5 years — retain full history for trends
    private let calendar   = Calendar.current
    private let appGroupID = "group.com.prasjain.Soma"

    // Prefer App Group store so widgets can read the same data.
    // Fall back to standard UserDefaults if the group isn't configured yet (simulator/unit tests).
    private var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    @Published var cachedMetrics: [DailyMetrics] = []

    init() {
        cachedMetrics = loadAll()
        purgeOldRecords()
    }

    // MARK: - Save

    func save(_ metrics: DailyMetrics) {
        var all = loadAll()
        if let index = all.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: metrics.date) }) {
            all[index] = metrics
        } else {
            all.append(metrics)
        }
        all.sort { $0.date < $1.date }
        persist(all)
        cachedMetrics = all
        persistWidgetSnapshot(metrics, history: all)
    }

    // MARK: - Load

    func load(for date: Date) -> DailyMetrics? {
        loadAll().first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func loadAll() -> [DailyMetrics] {
        guard let data    = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([DailyMetrics].self, from: data)
        else { return [] }
        return decoded
    }

    func loadLast(_ days: Int) -> [DailyMetrics] {
        let cutoff = calendar.date(byAdding: .day, value: -days, to: Date())!
        return loadAll().filter { $0.date >= cutoff }
    }

    // MARK: - Purge

    func purgeOldRecords() {
        let cutoff = calendar.date(byAdding: .day, value: -maxDays, to: Date())!
        let all    = loadAll().filter { $0.date >= cutoff }
        persist(all)
        cachedMetrics = all
    }

    func resetAll() {
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: widgetKey)
        cachedMetrics = []
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Private

    private func persist(_ metrics: [DailyMetrics]) {
        if let data = try? JSONEncoder().encode(metrics) {
            defaults.set(data, forKey: key)
        }
    }

    /// Writes today's training guidance level label into the existing widget snapshot.
    /// Call this after `save(_:)` once training guidance has been computed.
    func setWidgetTrainingLabel(_ label: String) {
        guard let data = defaults.data(forKey: widgetKey),
              var snapshot = try? JSONDecoder().decode(WidgetMetricsSnapshot.self, from: data)
        else { return }
        snapshot.trainingLevelLabel = label
        if let newData = try? JSONEncoder().encode(snapshot) {
            defaults.set(newData, forKey: widgetKey)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Writes a lightweight snapshot so widgets can display scores without HealthKit access.
    /// Includes 7-day trend directions computed from stored history.
    private func persistWidgetSnapshot(_ metrics: DailyMetrics, history: [DailyMetrics]) {
        let recent = history.sorted { $0.date < $1.date }.suffix(7)
        let snapshot = WidgetMetricsSnapshot(
            recoveryScore: metrics.recoveryScore,
            strainScore:   metrics.strainScore,
            sleepScore:    metrics.sleepScore,
            stressScore:   metrics.stressScore,
            date:          metrics.date,
            recoveryTrend: trend(for: recent.map { $0.recoveryScore }),
            strainTrend:   trend(for: recent.map { $0.strainScore }),
            sleepTrend:    trend(for: recent.map { $0.sleepScore }),
            stressTrend:   trend(for: recent.map { $0.stressScore })
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: widgetKey)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Returns trend direction by comparing the last value against the prior 6-day average.
    /// Threshold of ±2 points avoids noise on stable scores.
    private func trend(for values: [Double]) -> TrendDirection? {
        guard values.count >= 2 else { return nil }
        let prior = Array(values.dropLast())
        let avg   = prior.reduce(0, +) / Double(prior.count)
        let delta = (values.last ?? 0) - avg
        if delta > 2  { return .up }
        if delta < -2 { return .down }
        return .flat
    }
}
