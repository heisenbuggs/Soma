import XCTest
@testable import Soma

@MainActor
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

    func test_content_lowRecovery_titleSaysLow() {
        // Title vocabulary comes from ColorState.recovery: 25–44 → "Low".
        let metrics = makeMetrics(recovery: 25, sleep: 50)
        let (title, _) = NotificationScheduler.content(for: metrics)
        XCTAssertTrue(title.lowercased().contains("low"))
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

    // ColorState.recovery boundaries: 45 (Low→Moderate) and 65 (Moderate→Good).

    func test_content_boundary_65IsGood() {
        let (title, _) = NotificationScheduler.content(for: makeMetrics(recovery: 65, sleep: 80))
        XCTAssertTrue(title.contains("Good"))
    }

    func test_content_boundary_64IsModerate() {
        let (title, _) = NotificationScheduler.content(for: makeMetrics(recovery: 64, sleep: 70))
        XCTAssertTrue(title.lowercased().contains("moderate"))
    }

    func test_content_boundary_44IsLow() {
        let (title, _) = NotificationScheduler.content(for: makeMetrics(recovery: 44, sleep: 55))
        XCTAssertTrue(title.contains("Low"))
    }

    func test_content_boundary_45IsModerate() {
        let (title, _) = NotificationScheduler.content(for: makeMetrics(recovery: 45, sleep: 65))
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
