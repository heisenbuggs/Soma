import SwiftUI

@main
struct SomaApp: App {
    @StateObject private var healthKitManager = HealthKitManager()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init() {
        BackgroundTaskManager.shared.registerTasks()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !healthKitManager.healthKitAvailable {
                    notAvailableView
                } else if hasCompletedOnboarding {
                    MainTabView(healthKitManager: healthKitManager)
                        .task {
                            _ = await NotificationScheduler.shared.requestPermission()
                            BackgroundTaskManager.shared.scheduleInsightRefresh()
                        }
                } else {
                    OnboardingView()
                        .environmentObject(healthKitManager)
                }
            }
            // Respects system appearance (light / dark)
        }
    }

    private var notAvailableView: some View {
        ZStack {
            Color.somaBackground.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "heart.slash.fill")
                    .font(.system(size: 56))
                    .foregroundColor(Color(hex: "FF1744"))
                Text("HealthKit Not Available")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("This app requires an iPhone with Apple Health.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }
}
