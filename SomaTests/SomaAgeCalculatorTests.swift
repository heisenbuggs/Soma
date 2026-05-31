import XCTest
@testable import Soma

final class SomaAgeCalculatorTests: XCTestCase {

    private func input(
        age: Int = 40,
        hrv: Double? = nil, rhr: Double? = nil, rr: Double? = nil,
        duration: Double? = nil, debt: Double? = nil, efficiency: Double? = nil,
        vo2: Double? = nil,
        steps: Double? = nil, exercise: Double? = nil, strain: Double? = nil,
        sleepConsistency: Double? = nil, recoveryConsistency: Double? = nil, activityConsistency: Double? = nil,
        days: Int = 30, nights: Int = 20, recoveryDays: Int = 20
    ) -> SomaAgeCalculator.Input {
        SomaAgeCalculator.Input(
            chronologicalAge: age,
            hrv: hrv, restingHR: rhr, respiratoryRate: rr,
            sleepDurationHours: duration, sleepDebtHours: debt, sleepEfficiency: efficiency,
            vo2Max: vo2,
            dailySteps: steps, exerciseMinutesPerWeek: exercise, strainScore: strain,
            sleepConsistency: sleepConsistency, recoveryConsistency: recoveryConsistency, activityConsistency: activityConsistency,
            daysOfData: days, sleepNights: nights, recoveryDays: recoveryDays
        )
    }

    // MARK: - Calibration

    func test_calibration_requiresAllThreeThresholds() {
        // 21 days but too few sleep nights → not calibrated.
        let c1 = SomaAgeCalculator.calibrationStatus(daysOfData: 21, sleepNights: 10, recoveryDays: 12)
        XCTAssertFalse(c1.isCalibrated)
        // All thresholds met → calibrated.
        let c2 = SomaAgeCalculator.calibrationStatus(daysOfData: 21, sleepNights: 14, recoveryDays: 10)
        XCTAssertTrue(c2.isCalibrated)
    }

    func test_calibration_progressAndDaysRemaining() {
        let c = SomaAgeCalculator.calibrationStatus(daysOfData: 14, sleepNights: 14, recoveryDays: 10)
        XCTAssertEqual(c.daysRemaining, 7)
        XCTAssertGreaterThan(c.progress, 0.7)   // 2 of 3 fully met, days at 14/21
        XCTAssertGreaterThan(c.dataQuality, 0)
    }

    func test_calculate_nilWhileCalibrating() {
        XCTAssertNil(SomaAgeCalculator.calculate(input: input(vo2: 45, days: 10, nights: 5, recoveryDays: 4)))
    }

    // MARK: - Directionality

    func test_fitPerson_isYounger() {
        let r = SomaAgeCalculator.calculate(input: input(
            age: 40, hrv: 70, rhr: 50, rr: 13,
            duration: 7.75, debt: 0, efficiency: 95,
            vo2: 52, steps: 12000, exercise: 250, strain: 55,
            sleepConsistency: 90, recoveryConsistency: 85, activityConsistency: 85
        ))!
        XCTAssertLessThan(r.biologicalAge, 40)
        XCTAssertLessThan(r.delta, 0)
    }

    func test_unfitPerson_isOlder() {
        let r = SomaAgeCalculator.calculate(input: input(
            age: 40, hrv: 25, rhr: 80, rr: 18,
            duration: 5.0, debt: 3, efficiency: 70,
            vo2: 30, steps: 2000, exercise: 20, strain: 10,
            sleepConsistency: 30, recoveryConsistency: 35, activityConsistency: 35
        ))!
        XCTAssertGreaterThan(r.biologicalAge, 40)
        XCTAssertGreaterThan(r.delta, 0)
    }

    func test_averagePerson_nearChronological() {
        let r = SomaAgeCalculator.calculate(input: input(
            age: 40,
            hrv: SomaAgeCalculator.expectedHRV(age: 40), rhr: 58, rr: 14,
            duration: 7.75, debt: 0, efficiency: 90,
            vo2: SomaAgeCalculator.expectedVO2Max(age: 40),
            steps: 8000, exercise: 150, strain: 35,
            sleepConsistency: 70, recoveryConsistency: 70, activityConsistency: 70
        ))!
        // Sleep duration & debt give a small "younger" nudge even at reference points.
        XCTAssertEqual(r.biologicalAge, 40, accuracy: 2.0)
    }

    // MARK: - Category breakdown

    func test_contributions_alwaysFiveCategories() {
        let r = SomaAgeCalculator.calculate(input: input(vo2: 45))!
        XCTAssertEqual(Set(r.contributions.map { $0.category }), Set(SomaAgeCalculator.Category.allCases))
    }

    func test_cardiovascular_reflectsVO2() {
        let strong = SomaAgeCalculator.calculate(input: input(age: 40, vo2: 52))!
        let weak   = SomaAgeCalculator.calculate(input: input(age: 40, vo2: 32))!
        let strongCardio = strong.contributions.first { $0.category == .cardiovascular }!.years
        let weakCardio   = weak.contributions.first { $0.category == .cardiovascular }!.years
        XCTAssertLessThan(strongCardio, 0)       // fit → younger
        XCTAssertGreaterThan(weakCardio, 0)      // unfit → older
    }

    // MARK: - Drivers

    func test_drivers_splitPositiveNegative() {
        let r = SomaAgeCalculator.calculate(input: input(
            age: 40, hrv: 70, rhr: 80, duration: 5.0, vo2: 52
        ))!
        XCTAssertTrue(r.positiveDrivers.contains { $0.title.contains("VO₂ Max") })   // strong
        XCTAssertTrue(r.negativeDrivers.contains { $0.title.contains("Resting HR") }) // poor
        XCTAssertTrue(r.positiveDrivers.allSatisfy { $0.years < 0 })
        XCTAssertTrue(r.negativeDrivers.allSatisfy { $0.years > 0 })
    }

    // MARK: - Opportunities (simulation engine)

    func test_opportunities_rankedByImpact() {
        let r = SomaAgeCalculator.calculate(input: input(
            age: 40, hrv: 34, rhr: 71,
            duration: 4.2, debt: 2,
            vo2: 38, steps: 4000, exercise: 60,
            sleepConsistency: 50
        ))!
        XCTAssertFalse(r.opportunities.isEmpty)
        // Sorted ascending (most negative / biggest reduction first).
        let ys = r.opportunities.map { $0.potentialYears }
        XCTAssertEqual(ys, ys.sorted())
        // Every opportunity is an actual improvement.
        XCTAssertTrue(r.opportunities.allSatisfy { $0.potentialYears < 0 })
        // Short sleep should be the top opportunity here.
        XCTAssertEqual(r.opportunities.first?.metric, "Sleep Duration")
    }

    func test_opportunities_emptyWhenAlreadyHealthy() {
        let r = SomaAgeCalculator.calculate(input: input(
            age: 40, hrv: 60, rhr: 55, duration: 7.5, debt: 0,
            vo2: 50, steps: 11000, exercise: 200, sleepConsistency: 90
        ))!
        XCTAssertTrue(r.opportunities.isEmpty)
    }

    // MARK: - Confidence

    func test_confidence_scalesWithData() {
        let high = SomaAgeCalculator.calculate(input: input(vo2: 45, days: 95, nights: 80, recoveryDays: 80))!
        XCTAssertEqual(high.confidence, .high)
        let low = SomaAgeCalculator.calculate(input: input(vo2: 45, days: 22, nights: 14, recoveryDays: 10))!
        XCTAssertEqual(low.confidence, .low)
    }

    // MARK: - Clamping

    func test_biologicalAge_clampedToCredibleFloor() {
        let r = SomaAgeCalculator.calculate(input: input(
            age: 40, hrv: 200, rhr: 35, duration: 7.75, vo2: 90,
            steps: 30000, exercise: 600, sleepConsistency: 100
        ))!
        XCTAssertGreaterThanOrEqual(r.biologicalAge, 25)   // 40 − 15 floor
    }

    // MARK: - Notifications

    func test_notification_dropIsPositive() {
        let msg = SomaAgeNotification.weeklyChangeMessage(previous: 27.0, current: 26.6)
        XCTAssertTrue(msg!.contains("dropped by 0.4 years"))
    }

    func test_notification_riseNamesDriver() {
        let msg = SomaAgeNotification.weeklyChangeMessage(previous: 26.0, current: 26.3, topNegativeDriver: "Poor Sleep Duration")
        XCTAssertTrue(msg!.contains("rose by 0.3 years"))
        XCTAssertTrue(msg!.contains("poor sleep duration"))
    }

    func test_notification_negligibleChangeIsNil() {
        XCTAssertNil(SomaAgeNotification.weeklyChangeMessage(previous: 26.0, current: 26.05))
    }

    func test_milestone_crossingNewYear() {
        // Was 4.6 younger, now 5.1 younger → crosses the "5 years younger" milestone.
        let msg = SomaAgeNotification.milestoneMessage(delta: -5.1, previousDelta: -4.6)
        XCTAssertEqual(msg, "Milestone: you're now 5 years younger biologically than your actual age.")
    }

    func test_milestone_noCrossing_returnsNil() {
        XCTAssertNil(SomaAgeNotification.milestoneMessage(delta: -5.3, previousDelta: -5.1))  // still 5
        XCTAssertNil(SomaAgeNotification.milestoneMessage(delta: 2.0, previousDelta: 1.0))     // older
    }
}
