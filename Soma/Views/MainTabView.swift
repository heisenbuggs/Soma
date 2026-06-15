import SwiftUI

extension Notification.Name {
    static let openCheckIn = Notification.Name("openCheckIn")
}

struct MainTabView: View {
    private let healthKitManager: HealthKitManager

    @StateObject private var store:         MetricsStore
    @StateObject private var checkInStore:  CheckInStore
    @StateObject private var settings:      UserSettings
    @StateObject private var dashboardVM:   DashboardViewModel
    @StateObject private var trendsVM:      TrendsViewModel
    @StateObject private var insightsVM:    InsightsViewModel
    
    @State private var showCheckInFromShortcut = false
    @State private var selectedTab = 2

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
        TabView(selection: $selectedTab) {
            VitalsView(viewModel: dashboardVM)
            .tabItem {
                Label("Vitals", systemImage: "waveform.path.ecg")
            }
            .tag(0)

            TrendsRedesignView(viewModel: trendsVM)
            .tabItem {
                Label("Trends", systemImage: "chart.xyaxis.line")
            }
            .tag(1)

            TodayView(
                viewModel: dashboardVM,
                insightsVM: insightsVM,
                checkInStore: checkInStore,
                healthKit: healthKitManager
            )
            .tabItem {
                Label("Today", systemImage: "circle.hexagongrid.fill")
            }
            .tag(2)

            CoachView(viewModel: dashboardVM, insightsVM: insightsVM)
            .tabItem {
                Label("Coach", systemImage: "brain.head.profile")
            }
            .tag(3)

            NotificationsView()
            .tabItem {
                Label("Alerts", systemImage: "bell.fill")
            }
            .tag(4)
        }
        .tint(Color.somaBlue)
        .preferredColorScheme(.dark)
        .onAppear {
            // Premium dark-first chrome: jet-black, translucent tab bar.
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.black
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
            // Initialize notification schedules on app launch
            NotificationScheduler.shared.updateAllSchedules(settings: settings)
            
            // Listen for Siri shortcut to open check-in
            NotificationCenter.default.addObserver(
                forName: .openCheckIn,
                object: nil,
                queue: .main
            ) { _ in
                showCheckInFromShortcut = true
            }
        }
        .sheet(isPresented: $showCheckInFromShortcut) {
            CheckInView(viewModel: CheckInViewModel(
                checkInStore: checkInStore,
                healthKit: healthKitManager
            ))
        }
    }
}

#if DEBUG
#Preview {
    MainTabView(healthKitManager: HealthKitManager())
}
#endif
