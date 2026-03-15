import SwiftUI

@main
struct SomaApp: App {
    @StateObject private var healthKitManager = HealthKitManager()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if !healthKitManager.healthKitAvailable {
                    notAvailableView
                } else if hasCompletedOnboarding {
                    MainTabView()
                        .environmentObject(healthKitManager)
                } else {
                    OnboardingView()
                        .environmentObject(healthKitManager)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private var notAvailableView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "heart.slash.fill")
                    .font(.system(size: 56))
                    .foregroundColor(Color(hex: "FF1744"))
                Text("HealthKit Not Available")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("This app requires an iPhone with Apple Health.")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "8E8E93"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }
}
