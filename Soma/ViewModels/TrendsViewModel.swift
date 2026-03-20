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
