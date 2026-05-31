import XCTest
@testable import Soma

final class RecoveryCalculatorTests: XCTestCase {

    // MARK: - Score Clamping

    func test_calculate_clampedTo100() {
        let input = RecoveryInput(
            todayHRV: 100,       // well above baseline
            hrvBaseline: 50,
            todayRestingHR: 40,  // well below baseline
            rhrBaseline: 70,
            sleepScore: 100,
            yesterdayStrain: 0
        )
        let score = RecoveryCalculator.calculate(input: input)
        XCTAssertLessThanOrEqual(score, 100)
        XCTAssertGreaterThanOrEqual(score, 0)
    }

    func test_calculate_clampedTo0() {
        let input = RecoveryInput(
            todayHRV: 10,        // well below baseline
            hrvBaseline: 80,
            todayRestingHR: 100, // well above baseline
            rhrBaseline: 55,
            sleepScore: 0,
            yesterdayStrain: 21
        )
        let score = RecoveryCalculator.calculate(input: input)
        XCTAssertGreaterThanOrEqual(score, 0)
        XCTAssertLessThanOrEqual(score, 100)
    }

    // MARK: - With nil baselines

    func test_calculate_nilBaseline_fallsBackTo50() {
        let input = RecoveryInput(
            todayHRV: nil,
            hrvBaseline: nil,
            todayRestingHR: nil,
            rhrBaseline: nil,
            sleepScore: 80,
            yesterdayStrain: 10
        )
        let score = RecoveryCalculator.calculate(input: input)
        // HRV and RHR both fallback to 50, sleep=80, strain=~52.4
        // 0.40*50 + 0.25*50 + 0.25*80 + 0.10*(1-10/21)*100
        // = 20 + 12.5 + 20 + ~5.24 = ~57.74
        XCTAssertGreaterThan(score, 40)
        XCTAssertLessThan(score, 70)
    }

    // MARK: - Green range recovery

    func test_calculate_highRecovery_isInGreenRange() {
        let input = RecoveryInput(
            todayHRV: 70,
            hrvBaseline: 60,
            todayRestingHR: 55,
            rhrBaseline: 62,
            sleepScore: 90,
            yesterdayStrain: 5
        )
        let score = RecoveryCalculator.calculate(input: input)
        XCTAssertGreaterThanOrEqual(score, 67, "Expected green recovery range")
    }

    // MARK: - Personal z-score HRV path

    func test_calculate_zScorePath_higherHRVRaisesRecovery() {
        let history = [48.0, 52, 50, 49, 51, 50, 52]   // personal baseline ~50
        func score(todayHRV: Double) -> Double {
            RecoveryCalculator.calculate(input: RecoveryInput(
                todayHRV: todayHRV,
                hrvBaseline: 50,
                todayRestingHR: nil,
                rhrBaseline: nil,
                sleepScore: 50,
                yesterdayStrain: 0,
                hrvHistory: history
            ))
        }
        // HRV well above the personal norm should yield higher recovery than at-baseline.
        XCTAssertGreaterThan(score(todayHRV: 75), score(todayHRV: 50))
        XCTAssertLessThan(score(todayHRV: 32), score(todayHRV: 50))
    }

    // MARK: - Recovery adjustment (e.g. menstrual cycle compensation)

    func test_calculate_recoveryAdjustment_raisesScore() {
        func score(adjustment: Double) -> Double {
            RecoveryCalculator.calculate(input: RecoveryInput(
                todayHRV: 50,
                hrvBaseline: 55,        // slightly suppressed (luteal-like)
                todayRestingHR: 62,
                rhrBaseline: 58,        // slightly elevated (luteal-like)
                sleepScore: 60,
                yesterdayStrain: 8,
                recoveryAdjustment: adjustment
            ))
        }
        let withoutAdj = score(adjustment: 0)
        let withAdj    = score(adjustment: 6)
        XCTAssertEqual(withAdj, min(100, withoutAdj + 6), accuracy: 0.001)
    }

    // MARK: - Training recommendation

    func test_recommendation_greenRecovery() {
        let rec = RecoveryCalculator.trainingRecommendation(
            recovery: 80,
            last3DayStrainAvg: 10,
            sleepDebtHours: 0
        )
        XCTAssertTrue(rec.contains("Peak day"))
    }

    func test_recommendation_yellowHighRecovery() {
        let rec = RecoveryCalculator.trainingRecommendation(
            recovery: 55,
            last3DayStrainAvg: 8,
            sleepDebtHours: 0
        )
        XCTAssertTrue(rec.contains("Moderate day"))
    }

    func test_recommendation_yellowLowRecovery() {
        let rec = RecoveryCalculator.trainingRecommendation(
            recovery: 40,
            last3DayStrainAvg: 8,
            sleepDebtHours: 0
        )
        XCTAssertTrue(rec.contains("Easy day"))
    }

    func test_recommendation_redRecovery() {
        let rec = RecoveryCalculator.trainingRecommendation(
            recovery: 20,
            last3DayStrainAvg: 8,
            sleepDebtHours: 0
        )
        XCTAssertTrue(rec.contains("Rest day"))
    }

    func test_recommendation_appendsDeloadWarning() {
        let rec = RecoveryCalculator.trainingRecommendation(
            recovery: 80,
            last3DayStrainAvg: 16,
            sleepDebtHours: 0
        )
        XCTAssertTrue(rec.contains("deload"))
    }

    func test_recommendation_appendsSleepDebtWarning() {
        let rec = RecoveryCalculator.trainingRecommendation(
            recovery: 80,
            last3DayStrainAvg: 10,
            sleepDebtHours: 3
        )
        XCTAssertTrue(rec.contains("Sleep debt"))
    }

    func test_recommendation_bothWarnings() {
        let rec = RecoveryCalculator.trainingRecommendation(
            recovery: 80,
            last3DayStrainAvg: 16,
            sleepDebtHours: 3
        )
        XCTAssertTrue(rec.contains("deload"))
        XCTAssertTrue(rec.contains("Sleep debt"))
    }
}
