import Foundation
import Combine

@MainActor
final class TrendsViewModel: ObservableObject {

    enum TimeRange: String, CaseIterable {
        case week      = "7D"
        case twoWeeks  = "14D"
        case month     = "1M"
        case sixMonths = "6M"
        case year      = "1Y"

        var days: Int {
            switch self {
            case .week:      return 7
            case .twoWeeks:  return 14
            case .month:     return 30
            case .sixMonths: return 180
            case .year:      return 365
            }
        }
    }

    @Published var selectedRange: TimeRange = .twoWeeks
    @Published var metricHistory: [DailyMetrics] = []
    @Published var hrvHistory: [(Date, Double)] = []
    @Published var rhrHistory: [(Date, Double)] = []
    @Published var vo2MaxHistory: [(Date, Double)] = []
    @Published var vo2MaxTrend: Double? = nil   // slope in ml/kg/min per 30 days (nil < 3 pts)
    @Published var hrvBaseline: Double?
    @Published var rhrBaseline: Double?
    @Published var isLoading = false
    @Published var selectedDataPoint: DailyMetrics?
    @Published var selectedMetrics: DailyMetrics?

    private let healthKit: HealthDataProviding
    private let store: MetricsStore

    init(healthKit: HealthDataProviding, store: MetricsStore) {
        self.healthKit = healthKit
        self.store = store
    }

    func load() {
        Task {
            await fetchTrendData()
        }
    }

    private func fetchTrendData() async {
        isLoading = true
        defer { isLoading = false }

        let fetchDays = max(selectedRange.days, 30)
        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedRange.days, to: Date())!

        // Load stored metrics for chart data
        metricHistory = store.loadLast(selectedRange.days)
        let storedHistory = store.loadLast(fetchDays)

        // HRV — try HealthKit first; fall back to stored DailyMetrics if empty or unavailable.
        let allHRV = (try? await healthKit.fetchHRVHistory(days: fetchDays)) ?? []
        let filteredHRV = allHRV.filter { $0.0 >= cutoff }
        if !filteredHRV.isEmpty {
            hrvHistory = filteredHRV
            hrvBaseline = BaselineCalculator.computeHRVBaseline(from: allHRV)
        } else {
            let stored = storedHistory.compactMap { m -> (Date, Double)? in
                guard let v = m.hrvAverage else { return nil }
                return (m.date, v)
            }
            hrvHistory = stored.filter { $0.0 >= cutoff }
            hrvBaseline = BaselineCalculator.computeHRVBaseline(from: stored)
        }

        // RHR — same pattern.
        let allRHR = (try? await healthKit.fetchRestingHRHistory(days: fetchDays)) ?? []
        let filteredRHR = allRHR.filter { $0.0 >= cutoff }
        if !filteredRHR.isEmpty {
            rhrHistory = filteredRHR
            rhrBaseline = BaselineCalculator.computeRHRBaseline(from: allRHR)
        } else {
            let stored = storedHistory.compactMap { m -> (Date, Double)? in
                guard let v = m.restingHR else { return nil }
                return (m.date, v)
            }
            rhrHistory = stored.filter { $0.0 >= cutoff }
            rhrBaseline = BaselineCalculator.computeRHRBaseline(from: stored)
        }

        // VO2 Max — use 90-day history regardless of selected range for stable trend line.
        let vo2Days = max(selectedRange.days, 90)
        let allVO2 = (try? await healthKit.fetchVO2MaxHistory(days: vo2Days)) ?? []
        let filteredVO2 = allVO2.filter { $0.0 >= cutoff }
        if !filteredVO2.isEmpty {
            vo2MaxHistory = filteredVO2
        } else {
            // Fall back to stored vo2Max snapshots
            let stored = storedHistory.compactMap { m -> (Date, Double)? in
                guard let v = m.vo2Max else { return nil }
                return (m.date, v)
            }
            vo2MaxHistory = stored.filter { $0.0 >= cutoff }
        }
        vo2MaxTrend = linearSlope(allVO2.isEmpty ? vo2MaxHistory : allVO2)
            .map { $0 * 30 }   // convert per-day slope → per-30-day slope
    }

    /// Simple ordinary-least-squares slope over (day-index, value) pairs.
    private func linearSlope(_ points: [(Date, Double)]) -> Double? {
        guard points.count >= 3 else { return nil }
        let n = Double(points.count)
        let origin = points[0].0
        let xs = points.map { $0.0.timeIntervalSince(origin) / 86_400 }
        let ys = points.map { $0.1 }
        let sumX  = xs.reduce(0, +)
        let sumY  = ys.reduce(0, +)
        let sumXY = zip(xs, ys).map { $0 * $1 }.reduce(0, +)
        let sumX2 = xs.map { $0 * $0 }.reduce(0, +)
        let denom = n * sumX2 - sumX * sumX
        guard denom != 0 else { return nil }
        return (n * sumXY - sumX * sumY) / denom
    }

    func rangeChanged() {
        load()
    }

    /// Called when the user taps a chart point. Finds the nearest stored day.
    func selectDate(_ date: Date?) {
        guard let date else {
            selectedMetrics = nil
            return
        }
        selectedMetrics = metricHistory.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })
    }
}
