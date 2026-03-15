import Foundation
import WidgetKit

// MARK: - Widget snapshot (mirrored in SomaWidgets.swift)

struct WidgetMetricsSnapshot: Codable {
    let recoveryScore: Double
    let strainScore: Double
    let sleepScore: Double
    let stressScore: Double
    let date: Date
}

// MARK: - MetricsStore (UserDefaults + Codable)

final class MetricsStore: ObservableObject {
    private let key        = "storedDailyMetrics"
    private let widgetKey  = "widgetMetrics"
    private let maxDays    = 90
    private let calendar   = Calendar.current
    private let appGroupID = "group.com.soma.app"

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
        persistWidgetSnapshot(metrics)
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

    /// Writes a lightweight snapshot so widgets can display scores without HealthKit access.
    private func persistWidgetSnapshot(_ metrics: DailyMetrics) {
        let snapshot = WidgetMetricsSnapshot(
            recoveryScore: metrics.recoveryScore,
            strainScore:   metrics.strainScore,
            sleepScore:    metrics.sleepScore,
            stressScore:   metrics.stressScore,
            date:          metrics.date
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: widgetKey)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
