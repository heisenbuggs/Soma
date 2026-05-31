import XCTest
@testable import Soma

final class MenstrualCycleCalculatorTests: XCTestCase {

    private let cal = Calendar.current
    private func day(_ offset: Int, from ref: Date) -> Date {
        cal.date(byAdding: .day, value: offset, to: ref)!
    }

    // MARK: - Phase estimation

    func test_noHistory_returnsNil() {
        XCTAssertNil(MenstrualCycleCalculator.cycleInfo(periodStartDates: [], asOf: Date()))
    }

    func test_menstrualPhase_firstDay() {
        let ref = cal.startOfDay(for: Date())
        let starts = [day(-56, from: ref), day(-28, from: ref), ref]
        let info = MenstrualCycleCalculator.cycleInfo(periodStartDates: starts, asOf: ref)!
        XCTAssertEqual(info.phase, .menstrual)
        XCTAssertEqual(info.cycleDay, 1)
        XCTAssertEqual(info.cycleLength, 28)
    }

    func test_follicularPhase() {
        let ref = cal.startOfDay(for: Date())
        let starts = [day(-37, from: ref), day(-9, from: ref)]   // cycleDay 10
        let info = MenstrualCycleCalculator.cycleInfo(periodStartDates: starts, asOf: ref)!
        XCTAssertEqual(info.phase, .follicular)
    }

    func test_ovulatoryPhase() {
        let ref = cal.startOfDay(for: Date())
        let starts = [day(-41, from: ref), day(-13, from: ref)]  // cycleDay 14
        let info = MenstrualCycleCalculator.cycleInfo(periodStartDates: starts, asOf: ref)!
        XCTAssertEqual(info.phase, .ovulatory)
    }

    func test_lutealPhase() {
        let ref = cal.startOfDay(for: Date())
        let starts = [day(-50, from: ref), day(-22, from: ref)]  // cycleDay 23
        let info = MenstrualCycleCalculator.cycleInfo(periodStartDates: starts, asOf: ref)!
        XCTAssertEqual(info.phase, .luteal)
    }

    func test_staleData_returnsNil() {
        let ref = cal.startOfDay(for: Date())
        let starts = [day(-88, from: ref), day(-60, from: ref)]  // > cycleLength + 15
        XCTAssertNil(MenstrualCycleCalculator.cycleInfo(periodStartDates: starts, asOf: ref))
    }

    // MARK: - Recovery adjustment

    func test_recoveryAdjustment_zeroOutsideLuteal() {
        let follicular = MenstrualCycleCalculator.CycleInfo(phase: .follicular, cycleDay: 10, cycleLength: 28)
        XCTAssertEqual(MenstrualCycleCalculator.recoveryAdjustment(for: follicular), 0)
        XCTAssertEqual(MenstrualCycleCalculator.recoveryAdjustment(for: nil), 0)
    }

    func test_recoveryAdjustment_peaksLateLuteal() {
        // Day 28 of a 28-day cycle → 0 days until period → full adjustment.
        let lastDay = MenstrualCycleCalculator.CycleInfo(phase: .luteal, cycleDay: 28, cycleLength: 28)
        XCTAssertEqual(MenstrualCycleCalculator.recoveryAdjustment(for: lastDay),
                       MenstrualCycleCalculator.maxRecoveryAdjustment, accuracy: 0.001)
        // Early luteal (10 days out) → no adjustment yet.
        let early = MenstrualCycleCalculator.CycleInfo(phase: .luteal, cycleDay: 18, cycleLength: 28)
        XCTAssertEqual(MenstrualCycleCalculator.recoveryAdjustment(for: early), 0, accuracy: 0.001)
        // 5 days out → small positive, below the max.
        let fiveOut = MenstrualCycleCalculator.CycleInfo(phase: .luteal, cycleDay: 23, cycleLength: 28)
        let adj = MenstrualCycleCalculator.recoveryAdjustment(for: fiveOut)
        XCTAssertGreaterThan(adj, 0)
        XCTAssertLessThan(adj, MenstrualCycleCalculator.maxRecoveryAdjustment)
    }
}
