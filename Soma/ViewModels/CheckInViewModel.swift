import Foundation
import Combine

@MainActor
final class CheckInViewModel: ObservableObject {

    @Published var draft: DailyCheckIn = DailyCheckIn()
    @Published var isSaving = false
    @Published var didSave = false

    private let checkInStore: CheckInStore
    private let healthKit: HealthDataProviding

    init(checkInStore: CheckInStore, healthKit: HealthDataProviding) {
        self.checkInStore = checkInStore
        self.healthKit = healthKit
        // Pre-fill with yesterday's existing check-in if any (since we ask "How was yesterday?")
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        draft = checkInStore.load(for: yesterday) ?? DailyCheckIn()
    }

    func save() {
        isSaving = true
        Task {
            // Store yesterday's date since we're asking "How was yesterday?"
            // This ensures BehaviorEngine correlates behaviors with today's metrics correctly
            draft.date = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
            checkInStore.save(draft)
            // Behavior insights are now stale — invalidate cache so they regenerate
            InsightCache.shared.invalidateBehavior()
            // Best-effort write behavioral signals to Apple Health
            try? await healthKit.writeBehavioralData(draft)
            isSaving = false
            didSave = true
        }
    }
}
