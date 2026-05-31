import XCTest
@testable import Soma

final class MovementScoreCalculatorTests: XCTestCase {

    func test_allNil_returnsNil() {
        XCTAssertNil(MovementScoreCalculator.calculate(
            standHours: nil, stepCount: nil, walkingHRAverage: nil
        ))
    }

    func test_allComponentsPerfect_returns100() {
        let score = MovementScoreCalculator.calculate(
            standHours: 12, stepCount: 8_000, walkingHRAverage: 60
        )
        XCTAssertEqual(score!, 100, accuracy: 0.01)
    }

    // Regression: a perfect steps + stand day with no walking-HR data must score
    // 100 (renormalized), not the old 75 cap.
    func test_missingWalkingHR_renormalizes_notCappedAt75() {
        let score = MovementScoreCalculator.calculate(
            standHours: 12, stepCount: 8_000, walkingHRAverage: nil
        )
        XCTAssertEqual(score!, 100, accuracy: 0.01)
    }

    func test_singleComponent_usesItsOwnScore() {
        // Only steps present at half the 8k goal → 50, regardless of step weight.
        let score = MovementScoreCalculator.calculate(
            standHours: nil, stepCount: 4_000, walkingHRAverage: nil
        )
        XCTAssertEqual(score!, 50, accuracy: 0.01)
    }

    func test_twoComponents_weightedRatio() {
        // Stand 12h → 100 (weight .40), steps 4k → 50 (weight .35).
        // (0.40*100 + 0.35*50) / (0.40 + 0.35) = 57.5/0.75 = 76.666…
        let score = MovementScoreCalculator.calculate(
            standHours: 12, stepCount: 4_000, walkingHRAverage: nil
        )
        XCTAssertEqual(score!, (0.40 * 100 + 0.35 * 50) / 0.75, accuracy: 0.01)
    }

    func test_clampedToBounds() {
        // Over-goal steps still clamp the component to 100, not above.
        let score = MovementScoreCalculator.calculate(
            standHours: nil, stepCount: 25_000, walkingHRAverage: nil
        )
        XCTAssertEqual(score!, 100, accuracy: 0.01)
    }
}
