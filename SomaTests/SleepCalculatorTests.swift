import XCTest
@testable import Soma

final class SleepCalculatorTests: XCTestCase {

    // MARK: - Sleep Score
    // Formula: 0.40×duration + 0.30×deep + 0.20×rem + 0.10×core
    // Optimal targets: deep=20%, rem=22%, core=50% of total sleep

    func test_calculateScore_optimalStages_fullDuration_is100() {
        // All stages exactly at optimal, full duration met
        let total = 8.0 * 3600
        let sleep = SleepData(
            totalDuration: total,
            deepSleepDuration: total * 0.20,   // exactly 20%
            remSleepDuration:  total * 0.22,   // exactly 22%
            coreSleepDuration: total * 0.50,   // exactly 50%
            awakeDuration: 0,
            inBedDuration: 0,
            sleepStartTime: nil,
            sleepEndTime: nil
        )
        // duration=100, deep=100, rem=100, core=100 → final=100
        let score = SleepCalculator.calculateScore(sleep: sleep, sleepNeed: 8)
        XCTAssertEqual(score, 100, accuracy: 0.01)
    }

    func test_calculateScore_noSleep_returns0() {
        let score = SleepCalculator.calculateScore(sleep: .empty, sleepNeed: 8)
        XCTAssertEqual(score, 0)
    }

    func test_calculateScore_exampleFromSpec() {
        // T=7.5h, D=1.4h, R=1.7h, C=4.4h, N=8h
        let sleep = SleepData(
            totalDuration: 7.5 * 3600,
            deepSleepDuration: 1.4 * 3600,
            remSleepDuration:  1.7 * 3600,
            coreSleepDuration: 4.4 * 3600,
            awakeDuration: 0,
            inBedDuration: 0,
            sleepStartTime: nil,
            sleepEndTime: nil
        )
        // durationScore = 7.5/8*100 = 93.75
        // deepScore  = (1.4/7.5)/0.20*100 = 93.33  (18.67% / 20%)
        // remScore   = min(100, (1.7/7.5)/0.22*100) = min(100, 103.0) = 100
        // coreScore  = min(100, (4.4/7.5)/0.50*100) = min(100, 117.3) = 100
        // final = 0.4*93.75 + 0.3*93.33 + 0.2*100 + 0.1*100 ≈ 95.5
        let score = SleepCalculator.calculateScore(sleep: sleep, sleepNeed: 8)
        XCTAssertEqual(score, 95.5, accuracy: 0.5)
    }

    func test_calculateScore_halfDuration_optimalStages() {
        // T=4h, optimal stage ratios, N=8h
        let total = 4.0 * 3600
        let sleep = SleepData(
            totalDuration: total,
            deepSleepDuration: total * 0.20,
            remSleepDuration:  total * 0.22,
            coreSleepDuration: total * 0.50,
            awakeDuration: 0,
            inBedDuration: 0,
            sleepStartTime: nil,
            sleepEndTime: nil
        )
        // durationScore=50, deep=100, rem=100, core=100
        // final = 0.4*50 + 0.3*100 + 0.2*100 + 0.1*100 = 20+30+20+10 = 80
        let score = SleepCalculator.calculateScore(sleep: sleep, sleepNeed: 8)
        XCTAssertEqual(score, 80, accuracy: 0.01)
    }

    func test_calculateScore_noDeepOrREM_allCore() {
        // T=8h, D=0, R=0, C=8h, N=8h
        let total = 8.0 * 3600
        let sleep = SleepData(
            totalDuration: total,
            deepSleepDuration: 0,
            remSleepDuration:  0,
            coreSleepDuration: total,
            awakeDuration: 0,
            inBedDuration: 0,
            sleepStartTime: nil,
            sleepEndTime: nil
        )
        // durationScore=100, deep=0, rem=0
        // coreScore = min(100, (1.0/0.50)*100) = 100
        // final = 0.4*100 + 0.3*0 + 0.2*0 + 0.1*100 = 40+10 = 50
        let score = SleepCalculator.calculateScore(sleep: sleep, sleepNeed: 8)
        XCTAssertEqual(score, 50, accuracy: 0.01)
    }

    func test_calculateScore_belowOptimalAllStages() {
        // T=6h, D=10%, R=10%, C=30% — all below optimal, full duration missed
        let total = 6.0 * 3600
        let sleep = SleepData(
            totalDuration: total,
            deepSleepDuration: total * 0.10,   // 10% vs 20% optimal → score 50
            remSleepDuration:  total * 0.10,   // 10% vs 22% optimal → score ~45.5
            coreSleepDuration: total * 0.30,   // 30% vs 50% optimal → score 60
            awakeDuration: 0,
            inBedDuration: 0,
            sleepStartTime: nil,
            sleepEndTime: nil
        )
        let score = SleepCalculator.calculateScore(sleep: sleep, sleepNeed: 8)
        // durationScore = 6/8*100 = 75
        // deepScore  = 0.10/0.20*100 = 50
        // remScore   = 0.10/0.22*100 ≈ 45.45
        // coreScore  = 0.30/0.50*100 = 60
        // final = 0.4*75 + 0.3*50 + 0.2*45.45 + 0.1*60 = 30+15+9.09+6 ≈ 60.1
        XCTAssertEqual(score, 60.1, accuracy: 0.5)
    }

    func test_calculateScore_clamped0To100() {
        // Extreme oversleeping with perfect stages — should cap at 100
        let total = 20.0 * 3600
        let sleep = SleepData(
            totalDuration: total,
            deepSleepDuration: total * 0.20,
            remSleepDuration:  total * 0.22,
            coreSleepDuration: total * 0.50,
            awakeDuration: 0,
            inBedDuration: 0,
            sleepStartTime: nil,
            sleepEndTime: nil
        )
        let score = SleepCalculator.calculateScore(sleep: sleep, sleepNeed: 8)
        XCTAssertLessThanOrEqual(score, 100)
        XCTAssertGreaterThanOrEqual(score, 0)
    }

    // MARK: - Sleep Need

    func test_calculateSleepNeed_baseline_noDebt_noStrain() {
        let need = SleepCalculator.calculateSleepNeed(
            baselineSleep: 8.0,
            last7DaysNeedVsActual: [],
            yesterdayStrain: 0
        )
        XCTAssertEqual(need, 8.0, accuracy: 0.01)
    }

    func test_calculateSleepNeed_maxStrainAdds1Hour() {
        let need = SleepCalculator.calculateSleepNeed(
            baselineSleep: 8.0,
            last7DaysNeedVsActual: [],
            yesterdayStrain: 21
        )
        XCTAssertEqual(need, 9.0, accuracy: 0.01)
    }

    func test_calculateSleepNeed_clampedToMinMax() {
        // Minimum
        let low = SleepCalculator.calculateSleepNeed(
            baselineSleep: 5.0,
            last7DaysNeedVsActual: [],
            yesterdayStrain: 0
        )
        XCTAssertEqual(low, 7.0, accuracy: 0.01)

        // Maximum
        let high = SleepCalculator.calculateSleepNeed(
            baselineSleep: 12.0,
            last7DaysNeedVsActual: Array(repeating: (8.0, 4.0), count: 7),
            yesterdayStrain: 21
        )
        XCTAssertEqual(high, 12.0, accuracy: 0.01)
    }

    func test_calculateSleepNeed_debtAdded() {
        // 7 days with 1h deficit each night
        let pairs = Array(repeating: (8.0, 7.0), count: 7)
        let need = SleepCalculator.calculateSleepNeed(
            baselineSleep: 8.0,
            last7DaysNeedVsActual: pairs,
            yesterdayStrain: 0
        )
        // debt per night = 1.0, need = 8 + 1 = 9
        XCTAssertEqual(need, 9.0, accuracy: 0.01)
    }

    func test_calculateSleepNeed_debtCappedAt2PerNight() {
        // 7 days with 5h deficit each night (capped at 2h per night)
        let pairs = Array(repeating: (12.0, 7.0), count: 7) // 5h deficit but capped at 2h
        let need = SleepCalculator.calculateSleepNeed(
            baselineSleep: 8.0,
            last7DaysNeedVsActual: pairs,
            yesterdayStrain: 0
        )
        // debt per night capped at 2, need = 8 + 2 = 10
        XCTAssertEqual(need, 10.0, accuracy: 0.01)
    }

    // MARK: - Sleep Debt

    func test_computeSleepDebt_noDebt() {
        let pairs = [(8.0, 8.0), (8.0, 9.0), (8.0, 8.5)]
        let debt = SleepCalculator.computeSleepDebt(needVsActual: pairs)
        XCTAssertEqual(debt, 0.0, accuracy: 0.01)
    }

    func test_computeSleepDebt_accumulated() {
        let pairs = [(8.0, 6.0), (8.0, 7.0), (8.0, 8.0)]
        let debt = SleepCalculator.computeSleepDebt(needVsActual: pairs)
        // 2 + 1 + 0 = 3
        XCTAssertEqual(debt, 3.0, accuracy: 0.01)
    }
}
