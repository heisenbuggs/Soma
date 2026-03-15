import XCTest
@testable import Soma

final class SleepCalculatorTests: XCTestCase {

    // MARK: - Sleep Score
    // Formula: 0.30×duration + 0.30×stage + 0.15×sleepingHRV + 0.15×sleepingHR + 0.10×interruptions
    // Stage mix:  0.40×deep + 0.40×rem + 0.20×core
    // Optimal targets: deep=20%, rem=22%, core=50% of total sleep

    func test_calculateScore_allOptimal_is100() {
        // All stages at optimal, full duration, ideal sleeping HRV/HR, no interruptions
        let total = 8.0 * 3600
        let sleep = SleepData(
            totalDuration: total,
            deepSleepDuration: total * 0.20,
            remSleepDuration:  total * 0.22,
            coreSleepDuration: total * 0.50,
            awakeDuration: 0,
            inBedDuration: 0,
            sleepStartTime: nil,
            sleepEndTime: nil,
            interruptionCount: 0
        )
        // sleepingHRV/baseline = 78/60 = 1.3 → HRV score = 100
        // sleepingHR/baseline  = 42/60 = 0.7 → HR score  = 100
        let score = SleepCalculator.calculateScore(
            sleep: sleep, sleepNeed: 8,
            sleepingHRV: 78, sleepingHR: 42,
            hrvBaseline: 60, sleepingHRBaseline: 60
        )
        XCTAssertEqual(score, 100, accuracy: 0.01)
    }

    func test_calculateScore_nilHRVHR_defaultsToNeutral() {
        // With nil HRV/HR, those components default to 50 (neutral)
        let total = 8.0 * 3600
        let sleep = SleepData(
            totalDuration: total,
            deepSleepDuration: total * 0.20,
            remSleepDuration:  total * 0.22,
            coreSleepDuration: total * 0.50,
            awakeDuration: 0,
            inBedDuration: 0,
            sleepStartTime: nil,
            sleepEndTime: nil,
            interruptionCount: 0
        )
        // durationScore=100, stageScore=100, hrvScore=50, hrScore=50, interruptionScore=100
        // 0.30*100 + 0.30*100 + 0.15*50 + 0.15*50 + 0.10*100 = 30+30+7.5+7.5+10 = 85
        let score = SleepCalculator.calculateScore(sleep: sleep, sleepNeed: 8)
        XCTAssertEqual(score, 85, accuracy: 0.01)
    }

    func test_calculateScore_noSleep_returns0() {
        let score = SleepCalculator.calculateScore(sleep: .empty, sleepNeed: 8)
        XCTAssertEqual(score, 0)
    }

    func test_calculateScore_exampleFromSpec() {
        // T=7.5h, D=1.4h, R=1.7h, C=4.4h, N=8h, no interruptions, nil HRV/HR
        let sleep = SleepData(
            totalDuration: 7.5 * 3600,
            deepSleepDuration: 1.4 * 3600,
            remSleepDuration:  1.7 * 3600,
            coreSleepDuration: 4.4 * 3600,
            awakeDuration: 0,
            inBedDuration: 0,
            sleepStartTime: nil,
            sleepEndTime: nil,
            interruptionCount: 0
        )
        // durationScore = 7.5/8*100 = 93.75
        // deepScore  = (1.4/7.5)/0.20*100 = 93.33
        // remScore   = min(100, (1.7/7.5)/0.22*100) = 100
        // coreScore  = min(100, (4.4/7.5)/0.50*100) = 100
        // stageScore = 0.40*93.33 + 0.40*100 + 0.20*100 = 97.33
        // hrvScore = 50, hrScore = 50, interruptionScore = 100
        // final = 0.30*93.75 + 0.30*97.33 + 0.15*50 + 0.15*50 + 0.10*100 ≈ 82.3
        let score = SleepCalculator.calculateScore(sleep: sleep, sleepNeed: 8)
        XCTAssertEqual(score, 82.3, accuracy: 0.5)
    }

    func test_calculateScore_halfDuration_optimalStages() {
        // T=4h, optimal stage ratios, N=8h, no interruptions, nil HRV/HR
        let total = 4.0 * 3600
        let sleep = SleepData(
            totalDuration: total,
            deepSleepDuration: total * 0.20,
            remSleepDuration:  total * 0.22,
            coreSleepDuration: total * 0.50,
            awakeDuration: 0,
            inBedDuration: 0,
            sleepStartTime: nil,
            sleepEndTime: nil,
            interruptionCount: 0
        )
        // durationScore=50, stageScore=100, hrv=50, hr=50, interruption=100
        // 0.30*50 + 0.30*100 + 0.15*50 + 0.15*50 + 0.10*100 = 15+30+7.5+7.5+10 = 70
        let score = SleepCalculator.calculateScore(sleep: sleep, sleepNeed: 8)
        XCTAssertEqual(score, 70, accuracy: 0.01)
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
            sleepEndTime: nil,
            interruptionCount: 0
        )
        // durationScore=100, deep=0, rem=0, coreScore=100 → stageScore=0.20*100=20
        // hrv=50, hr=50, interruption=100
        // 0.30*100 + 0.30*20 + 0.15*50 + 0.15*50 + 0.10*100 = 30+6+7.5+7.5+10 = 61
        let score = SleepCalculator.calculateScore(sleep: sleep, sleepNeed: 8)
        XCTAssertEqual(score, 61, accuracy: 0.01)
    }

    func test_calculateScore_belowOptimalAllStages() {
        // T=6h, D=10%, R=10%, C=30% — all below optimal
        let total = 6.0 * 3600
        let sleep = SleepData(
            totalDuration: total,
            deepSleepDuration: total * 0.10,   // 10% vs 20% optimal → score 50
            remSleepDuration:  total * 0.10,   // 10% vs 22% optimal → score ~45.5
            coreSleepDuration: total * 0.30,   // 30% vs 50% optimal → score 60
            awakeDuration: 0,
            inBedDuration: 0,
            sleepStartTime: nil,
            sleepEndTime: nil,
            interruptionCount: 0
        )
        // durationScore = 75
        // stageScore = 0.40*50 + 0.40*45.45 + 0.20*60 = 20+18.18+12 = 50.18
        // hrv=50, hr=50, interruption=100
        // 0.30*75 + 0.30*50.18 + 0.15*50 + 0.15*50 + 0.10*100 = 22.5+15.05+7.5+7.5+10 ≈ 62.6
        let score = SleepCalculator.calculateScore(sleep: sleep, sleepNeed: 8)
        XCTAssertEqual(score, 62.6, accuracy: 0.5)
    }

    func test_calculateScore_clamped0To100() {
        let total = 20.0 * 3600
        let sleep = SleepData(
            totalDuration: total,
            deepSleepDuration: total * 0.20,
            remSleepDuration:  total * 0.22,
            coreSleepDuration: total * 0.50,
            awakeDuration: 0,
            inBedDuration: 0,
            sleepStartTime: nil,
            sleepEndTime: nil,
            interruptionCount: 0
        )
        let score = SleepCalculator.calculateScore(sleep: sleep, sleepNeed: 8)
        XCTAssertLessThanOrEqual(score, 100)
        XCTAssertGreaterThanOrEqual(score, 0)
    }

    // MARK: - Sleeping HRV Sub-component

    func test_computeSleepingHRVScore_atBaseline_is50() {
        let score = SleepCalculator.computeSleepingHRVScore(sleepingHRV: 60, baseline: 60)
        XCTAssertEqual(score, 50, accuracy: 0.1)
    }

    func test_computeSleepingHRVScore_aboveBaseline_isHigh() {
        // HRV 30% above baseline → ratio=1.3 → score=100
        let score = SleepCalculator.computeSleepingHRVScore(sleepingHRV: 78, baseline: 60)
        XCTAssertEqual(score, 100, accuracy: 0.1)
    }

    func test_computeSleepingHRVScore_belowBaseline_isLow() {
        // HRV 30% below baseline → ratio=0.7 → score=0
        let score = SleepCalculator.computeSleepingHRVScore(sleepingHRV: 42, baseline: 60)
        XCTAssertEqual(score, 0, accuracy: 0.1)
    }

    func test_computeSleepingHRVScore_nilData_returns50() {
        let score = SleepCalculator.computeSleepingHRVScore(sleepingHRV: nil, baseline: nil)
        XCTAssertEqual(score, 50)
    }

    // MARK: - Sleeping HR Sub-component

    func test_computeSleepingHRScore_atBaseline_is50() {
        let score = SleepCalculator.computeSleepingHRScore(sleepingHR: 60, baseline: 60)
        XCTAssertEqual(score, 50, accuracy: 0.1)
    }

    func test_computeSleepingHRScore_belowBaseline_isHigh() {
        // HR 30% below baseline → ratio=0.7 → score=100 (lower is better)
        let score = SleepCalculator.computeSleepingHRScore(sleepingHR: 42, baseline: 60)
        XCTAssertEqual(score, 100, accuracy: 0.1)
    }

    func test_computeSleepingHRScore_aboveBaseline_isLow() {
        // HR 30% above baseline → ratio=1.3 → score=0
        let score = SleepCalculator.computeSleepingHRScore(sleepingHR: 78, baseline: 60)
        XCTAssertEqual(score, 0, accuracy: 0.1)
    }

    func test_computeSleepingHRScore_nilData_returns50() {
        let score = SleepCalculator.computeSleepingHRScore(sleepingHR: nil, baseline: nil)
        XCTAssertEqual(score, 50)
    }

    // MARK: - Interruption Sub-component

    func test_computeInterruptionScore_noInterruptions_is100() {
        XCTAssertEqual(SleepCalculator.computeInterruptionScore(count: 0), 100)
    }

    func test_computeInterruptionScore_oneInterruption_is85() {
        XCTAssertEqual(SleepCalculator.computeInterruptionScore(count: 1), 85)
    }

    func test_computeInterruptionScore_sevenInterruptions_isZero() {
        // 7 * 15 = 105, clamped to 0
        XCTAssertEqual(SleepCalculator.computeInterruptionScore(count: 7), 0)
    }

    func test_calculateScore_withInterruptions_reducesScore() {
        let total = 8.0 * 3600
        let sleep0 = SleepData(
            totalDuration: total, deepSleepDuration: total * 0.20,
            remSleepDuration: total * 0.22, coreSleepDuration: total * 0.50,
            awakeDuration: 0, inBedDuration: 0,
            sleepStartTime: nil, sleepEndTime: nil, interruptionCount: 0
        )
        let sleep4 = SleepData(
            totalDuration: total, deepSleepDuration: total * 0.20,
            remSleepDuration: total * 0.22, coreSleepDuration: total * 0.50,
            awakeDuration: 0, inBedDuration: 0,
            sleepStartTime: nil, sleepEndTime: nil, interruptionCount: 4
        )
        let scoreClean = SleepCalculator.calculateScore(sleep: sleep0, sleepNeed: 8)
        let scoreInterrupted = SleepCalculator.calculateScore(sleep: sleep4, sleepNeed: 8)
        XCTAssertGreaterThan(scoreClean, scoreInterrupted)
        // 4 interruptions → interruptionScore = max(0, 100-60) = 40
        // Difference = 0.10*(100-40) = 6
        XCTAssertEqual(scoreClean - scoreInterrupted, 6, accuracy: 0.1)
    }

    // MARK: - Sleep Need

    func test_calculateSleepNeed_baseline_noDebt_noStrain() {
        let need = SleepCalculator.calculateSleepNeed(
            baselineSleep: 8.0,
            recentNeedVsActual: [],
            yesterdayStrain: 0
        )
        XCTAssertEqual(need, 8.0, accuracy: 0.01)
    }

    func test_calculateSleepNeed_maxStrainAddsHalfHour() {
        // Max strain (21) adds up to 0.5h
        let need = SleepCalculator.calculateSleepNeed(
            baselineSleep: 8.0,
            recentNeedVsActual: [],
            yesterdayStrain: 21
        )
        XCTAssertEqual(need, 8.5, accuracy: 0.01)
    }

    func test_calculateSleepNeed_clampedToMinMax() {
        let low = SleepCalculator.calculateSleepNeed(
            baselineSleep: 5.0,
            recentNeedVsActual: [],
            yesterdayStrain: 0
        )
        XCTAssertEqual(low, 7.0, accuracy: 0.01)

        // Max clamp is 9.5h regardless of extreme inputs
        let high = SleepCalculator.calculateSleepNeed(
            baselineSleep: 12.0,
            recentNeedVsActual: Array(repeating: (8.0, 4.0), count: 7),
            yesterdayStrain: 21
        )
        XCTAssertEqual(high, 9.5, accuracy: 0.01)
    }

    func test_calculateSleepNeed_debtAdded() {
        // 1h short each night vs baseline → debtPerNight = 1h (at per-night cap)
        let pairs = Array(repeating: (8.0, 7.0), count: 7)
        let need = SleepCalculator.calculateSleepNeed(
            baselineSleep: 8.0,
            recentNeedVsActual: pairs,
            yesterdayStrain: 0
        )
        XCTAssertEqual(need, 9.0, accuracy: 0.01)
    }

    func test_calculateSleepNeed_largeDeficit_uncapped() {
        // 4h sleep vs 8h goal = 4h deficit per night, no per-night cap
        let pairs = Array(repeating: (8.0, 4.0), count: 3)
        let need = SleepCalculator.calculateSleepNeed(
            baselineSleep: 8.0,
            recentNeedVsActual: pairs,
            yesterdayStrain: 0
        )
        // debtPerNight = 4h → need = 8+4 = 12 → clamped to 9.5
        XCTAssertEqual(need, 9.5, accuracy: 0.01)
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
        XCTAssertEqual(debt, 3.0, accuracy: 0.01)
    }
}
