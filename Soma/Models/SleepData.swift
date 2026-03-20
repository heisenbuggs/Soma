import Foundation

struct SleepData {
    var totalDuration: TimeInterval     // seconds (deep + rem + core)
    var deepSleepDuration: TimeInterval
    var remSleepDuration: TimeInterval
    var coreSleepDuration: TimeInterval
    var awakeDuration: TimeInterval
    var inBedDuration: TimeInterval
    var sleepStartTime: Date?           // night sleep only (excludes daytime naps)
    var sleepEndTime: Date?             // night sleep only (excludes daytime naps)
    var interruptionCount: Int          // number of distinct awake segments during sleep

    // Daytime nap data (10 AM – 8 PM on the target date)
    var napDurationSeconds: TimeInterval
    var napStartTime: Date?
    var napEndTime: Date?

    init(
        totalDuration: TimeInterval,
        deepSleepDuration: TimeInterval,
        remSleepDuration: TimeInterval,
        coreSleepDuration: TimeInterval,
        awakeDuration: TimeInterval,
        inBedDuration: TimeInterval,
        sleepStartTime: Date?,
        sleepEndTime: Date?,
        interruptionCount: Int,
        napDurationSeconds: TimeInterval = 0,
        napStartTime: Date? = nil,
        napEndTime: Date? = nil
    ) {
        self.totalDuration = totalDuration
        self.deepSleepDuration = deepSleepDuration
        self.remSleepDuration = remSleepDuration
        self.coreSleepDuration = coreSleepDuration
        self.awakeDuration = awakeDuration
        self.inBedDuration = inBedDuration
        self.sleepStartTime = sleepStartTime
        self.sleepEndTime = sleepEndTime
        self.interruptionCount = interruptionCount
        self.napDurationSeconds = napDurationSeconds
        self.napStartTime = napStartTime
        self.napEndTime = napEndTime
    }

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
            interruptionCount: 0,
            napDurationSeconds: 0,
            napStartTime: nil,
            napEndTime: nil
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
