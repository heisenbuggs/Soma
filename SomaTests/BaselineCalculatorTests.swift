import XCTest
@testable import Soma

final class BaselineCalculatorTests: XCTestCase {

    // MARK: - HRV Baseline

    func test_computeHRVBaseline_returnsNilForEmptyHistory() {
        XCTAssertNil(BaselineCalculator.computeHRVBaseline(from: []))
    }

    func test_computeHRVBaseline_returnsMeanOfValues() {
        let history = makeDateValuePairs([50, 60, 70])
        let baseline = BaselineCalculator.computeHRVBaseline(from: history)
        XCTAssertEqual(baseline, 60, accuracy: 0.01)
    }

    func test_computeHRVBaseline_singleValue() {
        let history = makeDateValuePairs([42.5])
        XCTAssertEqual(BaselineCalculator.computeHRVBaseline(from: history), 42.5, accuracy: 0.01)
    }

    // MARK: - RHR Baseline

    func test_computeRHRBaseline_returnsNilForEmptyHistory() {
        XCTAssertNil(BaselineCalculator.computeRHRBaseline(from: []))
    }

    func test_computeRHRBaseline_returnsMean() {
        let history = makeDateValuePairs([58, 62, 60])
        let baseline = BaselineCalculator.computeRHRBaseline(from: history)
        XCTAssertEqual(baseline!, 60.0, accuracy: 0.01)
    }

    // MARK: - Enough Data

    func test_hasEnoughData_trueWhen7Plus() {
        let history = makeDateValuePairs(Array(repeating: 50.0, count: 7))
        XCTAssertTrue(BaselineCalculator.hasEnoughData(history))
    }

    func test_hasEnoughData_falseWhenLessThan7() {
        let history = makeDateValuePairs(Array(repeating: 50.0, count: 6))
        XCTAssertFalse(BaselineCalculator.hasEnoughData(history))
    }

    // MARK: - Normalize Ratio

    func test_normalizeRatio_midRange() {
        // value=1.0, low=0.5, high=1.5 → 50
        let result = BaselineCalculator.normalizeRatio(1.0, low: 0.5, high: 1.5)
        XCTAssertEqual(result, 50.0, accuracy: 0.01)
    }

    func test_normalizeRatio_atLow_returns0() {
        let result = BaselineCalculator.normalizeRatio(0.5, low: 0.5, high: 1.5)
        XCTAssertEqual(result, 0.0, accuracy: 0.01)
    }

    func test_normalizeRatio_atHigh_returns100() {
        let result = BaselineCalculator.normalizeRatio(1.5, low: 0.5, high: 1.5)
        XCTAssertEqual(result, 100.0, accuracy: 0.01)
    }

    func test_normalizeRatio_clampsAboveHigh() {
        let result = BaselineCalculator.normalizeRatio(2.0, low: 0.5, high: 1.5)
        XCTAssertEqual(result, 100.0, accuracy: 0.01)
    }

    func test_normalizeRatio_clampsBelowLow() {
        let result = BaselineCalculator.normalizeRatio(0.0, low: 0.5, high: 1.5)
        XCTAssertEqual(result, 0.0, accuracy: 0.01)
    }

    // MARK: - Clamp

    func test_clamp_withinRange() {
        XCTAssertEqual(BaselineCalculator.clamp(50, min: 0, max: 100), 50)
    }

    func test_clamp_belowMin() {
        XCTAssertEqual(BaselineCalculator.clamp(-10, min: 0, max: 100), 0)
    }

    func test_clamp_aboveMax() {
        XCTAssertEqual(BaselineCalculator.clamp(150, min: 0, max: 100), 100)
    }

    // MARK: - Helpers

    private func makeDateValuePairs(_ values: [Double]) -> [(Date, Double)] {
        values.enumerated().map { i, v in
            (Calendar.current.date(byAdding: .day, value: -i, to: Date())!, v)
        }
    }
}
