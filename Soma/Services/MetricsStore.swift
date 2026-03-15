import Foundation

// MARK: - MetricsStore (UserDefaults + Codable)

final class MetricsStore: ObservableObject {
    private let key = "storedDailyMetrics"
    private let maxDays = 90
    private let calendar = Calendar.current

    @Published var cachedMetrics: [DailyMetrics] = []

    init() {
        cachedMetrics = loadAll()
        purgeOldRecords()
    }

    // MARK: - Save

    func save(_ metrics: DailyMetrics) {
        var all = loadAll()
        // Replace existing entry for same day or append
        if let index = all.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: metrics.date) }) {
            all[index] = metrics
        } else {
            all.append(metrics)
        }
        // Keep sorted
        all.sort { $0.date < $1.date }
        persist(all)
        cachedMetrics = all
    }

    // MARK: - Load

    func load(for date: Date) -> DailyMetrics? {
        loadAll().first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func loadAll() -> [DailyMetrics] {
        guard let data = UserDefaults.standard.data(forKey: key),
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
        var all = loadAll().filter { $0.date >= cutoff }
        persist(all)
        cachedMetrics = all
    }

    func resetAll() {
        UserDefaults.standard.removeObject(forKey: key)
        cachedMetrics = []
    }

    // MARK: - Private

    private func persist(_ metrics: [DailyMetrics]) {
        if let data = try? JSONEncoder().encode(metrics) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
