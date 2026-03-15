import XCTest
@testable import Soma

final class BedtimeTests: XCTestCase {

    // MARK: - bedtimeTarget

    func test_bedtime_8hNeed_6_30wakeTime() {
        // Wake 6:30 AM, need 8h, latency 12 min → bed at 10:18 PM
        let wake = makeTime(hour: 6, minute: 30)
        let bedtime = SleepCalculator.bedtimeTarget(wakeTime: wake, sleepNeed: 8.0, latencyMinutes: 12)
        let comps = Calendar.current.dateComponents([.hour, .minute], from: bedtime)
        // 6:30 - 8h12m = 22:18 = 10:18 PM
        XCTAssertEqual(comps.hour,   22)
        XCTAssertEqual(comps.minute, 18)
    }

    func test_bedtime_9hNeed_7amWakeTime() {
        // Wake 7:00 AM, need 9h, latency 12 min → bed at 9:48 PM
        let wake = makeTime(hour: 7, minute: 0)
        let bedtime = SleepCalculator.bedtimeTarget(wakeTime: wake, sleepNeed: 9.0, latencyMinutes: 12)
        let comps = Calendar.current.dateComponents([.hour, .minute], from: bedtime)
        // 7:00 - 9h12m = 21:48 = 9:48 PM
        XCTAssertEqual(comps.hour,   21)
        XCTAssertEqual(comps.minute, 48)
    }

    func test_bedtime_defaultLatency() {
        let wake = makeTime(hour: 6, minute: 0)
        let withDefault  = SleepCalculator.bedtimeTarget(wakeTime: wake, sleepNeed: 8.0)
        let withExplicit = SleepCalculator.bedtimeTarget(wakeTime: wake, sleepNeed: 8.0, latencyMinutes: 12)
        XCTAssertEqual(withDefault.timeIntervalSince1970,
                       withExplicit.timeIntervalSince1970,
                       accuracy: 1)
    }

    func test_bedtime_zerLatency() {
        // Wake 6:00 AM, need 8h, latency 0 → bed at 10:00 PM
        let wake = makeTime(hour: 6, minute: 0)
        let bedtime = SleepCalculator.bedtimeTarget(wakeTime: wake, sleepNeed: 8.0, latencyMinutes: 0)
        let comps = Calendar.current.dateComponents([.hour, .minute], from: bedtime)
        XCTAssertEqual(comps.hour,   22)
        XCTAssertEqual(comps.minute, 0)
    }

    func test_bedtime_fractionalNeed() {
        // Wake 6:30 AM, need 7.5h, latency 12 min → bed at 10:48 PM
        let wake = makeTime(hour: 6, minute: 30)
        let bedtime = SleepCalculator.bedtimeTarget(wakeTime: wake, sleepNeed: 7.5, latencyMinutes: 12)
        let comps = Calendar.current.dateComponents([.hour, .minute], from: bedtime)
        // 6:30 - 7h42m = 22:48 = 10:48 PM
        XCTAssertEqual(comps.hour,   22)
        XCTAssertEqual(comps.minute, 48)
    }

    // MARK: - Helpers

    private func makeTime(hour: Int, minute: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour   = hour
        comps.minute = minute
        comps.second = 0
        return Calendar.current.date(from: comps)!
    }
}
