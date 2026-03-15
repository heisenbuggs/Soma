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
    @Published var errorMessage: String?
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

        // Load stored metrics for chart data
        metricHistory = store.loadLast(selectedRange.days)

        do {
            let fetchDays = max(selectedRange.days, 30)
            let (hrv, rhr) = try await (
                healthKit.fetchHRVHistory(days: fetchDays),
                healthKit.fetchRestingHRHistory(days: fetchDays)
            )

            let filteredHRV = hrv.filter { entry in
                let cutoff = Calendar.current.date(byAdding: .day, value: -selectedRange.days, to: Date())!
                return entry.0 >= cutoff
            }
            let filteredRHR = rhr.filter { entry in
                let cutoff = Calendar.current.date(byAdding: .day, value: -selectedRange.days, to: Date())!
                return entry.0 >= cutoff
            }

            hrvHistory = filteredHRV
            rhrHistory = filteredRHR
            hrvBaseline = BaselineCalculator.computeHRVBaseline(from: hrv)
            rhrBaseline = BaselineCalculator.computeRHRBaseline(from: rhr)

        } catch {
            errorMessage = error.localizedDescription
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
