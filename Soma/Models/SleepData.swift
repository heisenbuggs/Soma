import Foundation

struct SleepData {
    var totalDuration: TimeInterval     // seconds (deep + rem + core)
    var deepSleepDuration: TimeInterval
    var remSleepDuration: TimeInterval
    var coreSleepDuration: TimeInterval
    var awakeDuration: TimeInterval
    var inBedDuration: TimeInterval
    var sleepStartTime: Date?
    var sleepEndTime: Date?
    var interruptionCount: Int          // number of distinct awake segments during sleep

    static var empty: SleepData {
        SleepData(
            totalDuration: 0,
            deepSleepDuration: 0,
            remSleepDuration: 0,
            coreSleepDuration: 0,
            awakeDuration: 0,
            inBedDuration: 0,
            sleepStartTime: nil,
            sleepEndTime: nil,
            interruptionCount: 0
        )
    }

    var totalDurationHours: Double {
        totalDuration / 3600
    }

    var deepPercentage: Double {
        guard totalDuration > 0 else { return 0 }
        return deepSleepDuration / totalDuration
    }

    var remPercentage: Double {
        guard totalDuration > 0 else { return 0 }
        return remSleepDuration / totalDuration
    }

    var corePercentage: Double {
        guard totalDuration > 0 else { return 0 }
        return coreSleepDuration / totalDuration
    }
}
