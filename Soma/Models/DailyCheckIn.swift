import Foundation

struct DailyCheckIn: Identifiable, Codable {
    let id: UUID
    var date: Date

    // Alcohol
    var alcoholConsumed: Bool
    var alcoholUnits: Int       // 0=none, 1=1-2 drinks, 2=3-4, 3=5+

    // Stimulants / nutrition timing
    var caffeineAfter5PM: Bool
    var lateMealBeforeBed: Bool  // meal within 2h of bed

    // Pre-sleep habits
    var screenBeforeBed: Bool    // screen use 1h before bed
    var lateWorkout: Bool        // workout within 2h of bed

    // Stress (1–5)
    var stressLevel: Int         // 1 = very low, 5 = very high

    // Recovery practices
    var meditated: Bool
    var stretched: Bool
    var coldExposure: Bool

    init(id: UUID = UUID(), date: Date = Date()) {
        self.id = id
        self.date = date
        self.alcoholConsumed = false
        self.alcoholUnits = 0
        self.caffeineAfter5PM = false
        self.lateMealBeforeBed = false
        self.screenBeforeBed = false
        self.lateWorkout = false
        self.stressLevel = 3
        self.meditated = false
        self.stretched = false
        self.coldExposure = false
    }
}
