import SwiftUI

struct MainTabView: View {
    private let healthKitManager: HealthKitManager

    @StateObject private var store:         MetricsStore
    @StateObject private var checkInStore:  CheckInStore
    @StateObject private var settings:      UserSettings
    @StateObject private var dashboardVM:   DashboardViewModel
    @StateObject private var trendsVM:      TrendsViewModel
    @StateObject private var insightsVM:    InsightsViewModel

    init(healthKitManager: HealthKitManager) {
        self.healthKitManager = healthKitManager
        let store        = MetricsStore()
        let checkInStore = CheckInStore()
        let settings     = UserSettings()
        _store        = StateObject(wrappedValue: store)
        _checkInStore = StateObject(wrappedValue: checkInStore)
        _settings     = StateObject(wrappedValue: settings)
        _dashboardVM  = StateObject(wrappedValue: DashboardViewModel(
            healthKit: healthKitManager,
            store: store,
            checkInStore: checkInStore,
            settings: settings
        ))
        _trendsVM  = StateObject(wrappedValue: TrendsViewModel(
            healthKit: healthKitManager,
            store: store
        ))
        _insightsVM = StateObject(wrappedValue: InsightsViewModel(
            store: store,
            checkInStore: checkInStore
        ))
    }

    var body: some View {
        TabView {
            DashboardView(
                viewModel: dashboardVM,
                checkInStore: checkInStore,
                healthKit: healthKitManager
            )
            .tabItem {
                Label("Dashboard", systemImage: "heart.text.square.fill")
            }

            TrendsView(viewModel: trendsVM)
            .tabItem {
                Label("Trends", systemImage: "chart.xyaxis.line")
            }

            InsightsView(viewModel: insightsVM)
            .tabItem {
                Label("Insights", systemImage: "brain.head.profile")
            }
        }
        .tint(Color(hex: "2979FF"))
    }
}
