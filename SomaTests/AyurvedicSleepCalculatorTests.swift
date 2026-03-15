import XCTest
@testable import Soma

final class AyurvedicSleepCalculatorTests: XCTestCase {

    // Reference evening: any fixed date at 9 PM local
    private let evening: Date = {
        var comps = DateComponents()
        comps.year = 2025; comps.month = 1; comps.day = 15
        comps.hour = 0; comps.minute = 0; comps.second = 0
        return Calendar.current.date(from: comps)!
    }()

    private func date(hour: Int, minute: Int = 0, nextDay: Bool = false) -> Date {
        let day = nextDay ? 16 : 15
        var comps = DateComponents()
        comps.year = 2025; comps.month = 1; comps.day = day
        comps.hour = hour; comps.minute = minute; comps.second = 0
        return Calendar.current.date(from: comps)!
    }

    // MARK: - Edge cases

    func test_noIntervals_returnsZero() {
        let score = AyurvedicSleepCalculator.calculate(intervals: [], eveningDate: evening)
        XCTAssertEqual(score, 0)
    }

    func test_fullOptimalWindow_returns10() {
        // 9 PM to 8 AM = full coverage = max score
        let start = date(hour: 21)
        let end   = date(hour: 8, nextDay: true)
        let score = AyurvedicSleepCalculator.calculate(intervals: [(start, end)], eveningDate: evening)
        XCTAssertEqual(score, 10.0, accuracy: 0.1)
    }

    // MARK: - PRD example: 10:30 PM – 6:30 AM

    func test_prdExample() {
        // 10:30 PM – 12 AM  → 1.5h × 2   = 3.0
        // 12 AM  – 3 AM     → 3h   × 1   = 3.0
        // 3 AM   – 6 AM     → 3h   × 0.5 = 1.5
        // 6 AM   – 6:30 AM  → 0.5h × 0.25 = 0.125
        // raw = 7.625 / 8 × 10 = 9.5 (rounded to 1 dp)
        let start = date(hour: 22, minute: 30)
        let end   = date(hour: 6,  minute: 30, nextDay: true)
        let score = AyurvedicSleepCalculator.calculate(intervals: [(start, end)], eveningDate: evening)
        XCTAssertEqual(score, 9.5, accuracy: 0.1)
    }

    // MARK: - Window boundary precision

    func test_onlyFirstWindow_9pmTo12am() {
        let start = date(hour: 21)
        let end   = date(hour: 0, nextDay: true) // midnight
        let score = AyurvedicSleepCalculator.calculate(intervals: [(start, end)], eveningDate: evening)
        // 3h × 2 = 6 raw → 6/8 × 10 = 7.5
        XCTAssertEqual(score, 7.5, accuracy: 0.1)
    }

    func test_onlyAfter6AM_lowestScore() {
        // 6 AM – 8 AM: 2h × 0.25 = 0.5 raw → 0.5/8 × 10 = 0.625 ≈ 0.6
        let start = date(hour: 6,  nextDay: true)
        let end   = date(hour: 8,  nextDay: true)
        let score = AyurvedicSleepCalculator.calculate(intervals: [(start, end)], eveningDate: evening)
        XCTAssertEqual(score, 0.6, accuracy: 0.1)
    }

    func test_sleepAfter8AM_noAdditionalPoints() {
        // Sleep 7 AM – 10 AM: only 7–8 AM counts (1h × 0.25), 8–10 AM = 0
        let start = date(hour: 7, nextDay: true)
        let end   = date(hour: 10, nextDay: true)
        let score1 = AyurvedicSleepCalculator.calculate(intervals: [(start, end)], eveningDate: evening)

        let end2  = date(hour: 8, nextDay: true) // same but stops at 8 AM
        let score2 = AyurvedicSleepCalculator.calculate(intervals: [(start, end2)], eveningDate: evening)

        XCTAssertEqual(score1, score2, accuracy: 0.01)
    }

    // MARK: - Before 9 PM (applies 9 PM window weight)

    func test_sleepBefore9PM_earnsTwoPointsPerHour() {
        // 8 PM – 9 PM: 1h × 2 = 2 raw (early sleep still scores at 2 pts/hr)
        let start = date(hour: 20)
        let end   = date(hour: 21)
        let score = AyurvedicSleepCalculator.calculate(intervals: [(start, end)], eveningDate: evening)
        XCTAssertGreaterThan(score, 0)
        // 2 raw / 8 × 10 = 2.5
        XCTAssertEqual(score, 2.5, accuracy: 0.1)
    }

    // MARK: - Fragmented sleep

    func test_fragmentedSleep_sumsSegments() {
        // Segment 1: 10 PM – 12 AM → 2h × 2 = 4 raw
        // Segment 2: 1 AM – 3 AM   → 2h × 1 = 2 raw
        // Total raw = 6 → 6/8 × 10 = 7.5
        let intervals: [(start: Date, end: Date)] = [
            (date(hour: 22),                date(hour: 0,  nextDay: true)),
            (date(hour: 1, nextDay: true),  date(hour: 3,  nextDay: true)),
        ]
        let score = AyurvedicSleepCalculator.calculate(intervals: intervals, eveningDate: evening)
        XCTAssertEqual(score, 7.5, accuracy: 0.1)
    }

    // MARK: - Score clamping

    func test_scoreAlwaysClamped0To10() {
        // Extreme early sleep that shouldn't exceed 10
        let start = date(hour: 18)
        let end   = date(hour: 8, nextDay: true)
        let score = AyurvedicSleepCalculator.calculate(intervals: [(start, end)], eveningDate: evening)
        XCTAssertLessThanOrEqual(score, 10.0)
        XCTAssertGreaterThanOrEqual(score, 0.0)
    }

    // MARK: - Guidance text

    func test_guidanceText_excellent() {
        XCTAssertEqual(AyurvedicSleepCalculator.guidanceText(for: 8.5), "Excellent circadian sleep")
    }

    func test_guidanceText_good() {
        XCTAssertEqual(AyurvedicSleepCalculator.guidanceText(for: 7.0), "Good alignment")
    }

    func test_guidanceText_late() {
        XCTAssertEqual(AyurvedicSleepCalculator.guidanceText(for: 5.0), "Late sleep pattern")
    }

    func test_guidanceText_very_late() {
        XCTAssertEqual(AyurvedicSleepCalculator.guidanceText(for: 2.0), "Very late sleep pattern")
    }

    // MARK: - Improvement tip

    func test_improvementTip_nilWhenScoreIsHigh() {
        let start = date(hour: 21)
        let end   = date(hour: 6, nextDay: true)
        let score = AyurvedicSleepCalculator.calculate(intervals: [(start, end)], eveningDate: evening)
        // Score is high (9 PM start) — tip should be nil
        if score >= 8.0 {
            let tip = AyurvedicSleepCalculator.improvementTip(
                sleepStart: start, sleepEnd: end, currentScore: score, eveningDate: evening)
            XCTAssertNil(tip)
        }
    }

    func test_improvementTip_presentForLateStart() {
        // Sleep at 2 AM — clearly late
        let start = date(hour: 2, nextDay: true)
        let end   = date(hour: 9, nextDay: true)
        let score = AyurvedicSleepCalculator.calculate(intervals: [(start, end)], eveningDate: evening)
        let tip = AyurvedicSleepCalculator.improvementTip(
            sleepStart: start, sleepEnd: end, currentScore: score, eveningDate: evening)
        XCTAssertNotNil(tip)
    }
}
