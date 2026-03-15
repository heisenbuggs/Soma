import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager

    @StateObject private var store       = MetricsStore()
    @StateObject private var checkInStore = CheckInStore()
    @StateObject private var settings    = UserSettings()

    private var healthKit: HealthDataProviding { healthKitManager }

    var body: some View {
        TabView {
            DashboardView(
                viewModel: DashboardViewModel(
                    healthKit: healthKit,
                    store: store,
                    checkInStore: checkInStore,
                    settings: settings
                ),
                checkInStore: checkInStore,
                healthKit: healthKit
            )
            .tabItem {
                Label("Dashboard", systemImage: "heart.text.square.fill")
            }

            TrendsView(
                viewModel: TrendsViewModel(healthKit: healthKit, store: store)
            )
            .tabItem {
                Label("Trends", systemImage: "chart.xyaxis.line")
            }

            InsightsView(
                viewModel: InsightsViewModel(store: store, checkInStore: checkInStore)
            )
            .tabItem {
                Label("Insights", systemImage: "brain.head.profile")
            }
        }
        .tint(Color(hex: "2979FF"))
        .preferredColorScheme(.dark)
    }
}
