import Foundation
#if os(iOS)
import BackgroundTasks
#endif

// MARK: - BackgroundTaskManager
//
// Registers and schedules BGTaskScheduler tasks so the insight cache
// can be refreshed while the app is in the background.
//
// Usage:
//   1. Call `registerTasks()` once at app launch (before the first
//      runloop tick — i.e., inside the App init or WindowGroup body).
//   2. Call `scheduleInsightRefresh()` after the user completes
//      onboarding and whenever the app moves to the background.

final class BackgroundTaskManager {

    static let shared = BackgroundTaskManager()

    // Must match BGTaskSchedulerPermittedIdentifiers in Info.plist
    static let insightRefreshIdentifier = "com.soma.insight-refresh"

    // Refresh at most once per hour in the background
    private let minimumRefreshInterval: TimeInterval = 60 * 60

    private init() {}

    // MARK: - Registration

    /// Register all background task handlers.
    /// Must be called during app initialization before the first runloop tick.
    func registerTasks() {
        #if os(iOS)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskManager.insightRefreshIdentifier,
            using: nil
        ) { task in
            self.handleInsightRefresh(task: task as! BGAppRefreshTask)
        }
        #endif
    }

    // MARK: - Scheduling

    /// Schedule (or reschedule) the next background insight refresh.
    /// Safe to call multiple times — BGTaskScheduler replaces any pending
    /// request with the same identifier.
    func scheduleInsightRefresh() {
        #if os(iOS)
        let request = BGAppRefreshTaskRequest(
            identifier: BackgroundTaskManager.insightRefreshIdentifier
        )
        request.earliestBeginDate = Date(timeIntervalSinceNow: minimumRefreshInterval)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // BGTaskScheduler.Error.notPermitted is expected in the
            // Simulator and when the app hasn't been backgrounded yet.
            // No action required.
        }
        #endif
    }

    // MARK: - Task Handler

    #if os(iOS)
    private func handleInsightRefresh(task: BGAppRefreshTask) {
        // Reschedule immediately so we get the next window
        scheduleInsightRefresh()

        // Cancel the background work if the system asks us to stop
        let refreshTask = Task {
            await performInsightRefresh()
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            refreshTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
    #endif

    // MARK: - Background Refresh Work

    @MainActor
    private func performInsightRefresh() async {
        let store       = MetricsStore()
        let checkInStore = CheckInStore()
        let vm          = InsightsViewModel(store: store, checkInStore: checkInStore)
        vm.generateInsights(forceRefresh: true)
    }
}
