import XCTest
@testable import Soma

final class NotificationSchedulerTests: XCTestCase {

    // MARK: - Notification Content

    func test_content_highRecovery_titlContainsScore() {
        let metrics = makeMetrics(recovery: 80, sleep: 85)
        let (title, body) = NotificationScheduler.content(for: metrics)
        XCTAssertTrue(title.contains("80"),  "Title should contain the recovery score")
        XCTAssertFalse(title.isEmpty)
        XCTAssertFalse(body.isEmpty)
    }

    func test_content_moderateRecovery_titleSaysModerate() {
        let metrics = makeMetrics(recovery: 55, sleep: 70)
        let (title, _) = NotificationScheduler.content(for: metrics)
        XCTAssertTrue(title.lowercased().contains("moderate"))
    }

    func test_content_lowRecovery_titleSaysRest() {
        let metrics = makeMetrics(recovery: 25, sleep: 50)
        let (title, _) = NotificationScheduler.content(for: metrics)
        XCTAssertTrue(title.lowercased().contains("rest"))
    }

    func test_content_lowRecovery_bodyIncludesSleepDuration() {
        var metrics = makeMetrics(recovery: 25, sleep: 50)
        metrics = DailyMetrics(
            date: Date(),
            recoveryScore: 25, strainScore: 5, sleepScore: 50, stressScore: 40,
            sleepDurationHours: 5.5
        )
        let (_, body) = NotificationScheduler.content(for: metrics)
        XCTAssertTrue(body.contains("5.5h"), "Body should mention sleep duration when available")
    }

    func test_content_moderateRecovery_bodyIncludesSleepingHR() {
        let metrics = DailyMetrics(
            date: Date(),
            recoveryScore: 50, strainScore: 10, sleepScore: 65, stressScore: 35,
            sleepingHR: 62
        )
        let (_, body) = NotificationScheduler.content(for: metrics)
        XCTAssertTrue(body.contains("62"), "Body should mention sleeping HR when available")
    }

    func test_content_highRecovery_strongSleepNote() {
        let metrics = DailyMetrics(
            date: Date(),
            recoveryScore: 82, strainScore: 8, sleepScore: 85, stressScore: 20
        )
        let (_, body) = NotificationScheduler.content(for: metrics)
        XCTAssertFalse(body.isEmpty)
    }

    func test_content_scoresBoundary_67IsHigh() {
        let metricsHigh = makeMetrics(recovery: 67, sleep: 80)
        let (title, _) = NotificationScheduler.content(for: metricsHigh)
        XCTAssertFalse(title.lowercased().contains("moderate"))
    }

    func test_content_scoresBoundary_66IsModerate() {
        let metricsModerate = makeMetrics(recovery: 66, sleep: 70)
        let (title, _) = NotificationScheduler.content(for: metricsModerate)
        XCTAssertTrue(title.lowercased().contains("moderate"))
    }

    func test_content_scoresBoundary_33IsLow() {
        let metricsLow = makeMetrics(recovery: 33, sleep: 55)
        let (title, _) = NotificationScheduler.content(for: metricsLow)
        XCTAssertTrue(title.lowercased().contains("rest"))
    }

    func test_content_scoresBoundary_34IsModerate() {
        let metricsModerate = makeMetrics(recovery: 34, sleep: 65)
        let (title, _) = NotificationScheduler.content(for: metricsModerate)
        XCTAssertTrue(title.lowercased().contains("moderate"))
    }

    // MARK: - Helpers

    private func makeMetrics(recovery: Double, sleep: Double) -> DailyMetrics {
        DailyMetrics(
            date: Date(),
            recoveryScore: recovery,
            strainScore: 10,
            sleepScore: sleep,
            stressScore: 30
        )
    }
}
