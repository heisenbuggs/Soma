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
        // Pre-fill with today's existing check-in if any
        draft = checkInStore.load(for: Date()) ?? DailyCheckIn()
    }

    func save() {
        isSaving = true
        Task {
            draft.date = Date()
            checkInStore.save(draft)
            // Best-effort write behavioral signals to Apple Health
            try? await healthKit.writeBehavioralData(draft)
            isSaving = false
            didSave = true
        }
    }
}
