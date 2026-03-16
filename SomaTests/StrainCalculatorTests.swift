import XCTest
@testable import Soma

final class StrainCalculatorTests: XCTestCase {

    private let maxHR: Double = 185

    // MARK: - Empty / single samples

    func test_calculate_emptySamples_returns0() {
        let load = StrainCalculator.calculate(samples: [], maxHR: maxHR)
        XCTAssertEqual(load, 0)
    }

    func test_calculate_singleSample_returns0() {
        let samples = [(Date(), 80.0)]
        let load = StrainCalculator.calculate(samples: samples, maxHR: maxHR)
        XCTAssertEqual(load, 0)
    }

    // MARK: - Zone classification (MaxHR percentage thresholds)

    func test_zone_belowZone2_isZone1() {
        // 54% of maxHR → below 60% → zone1
        let zone = HeartRateZone.zone(for: 100, maxHR: 185)
        XCTAssertEqual(zone, .zone1)
    }

    func test_zone_highIntensity_isZone5() {
        // 97% of maxHR → zone5
        let zone = HeartRateZone.zone(for: 180, maxHR: 185)
        XCTAssertEqual(zone, .zone5)
    }

    func test_zone_zone3() {
        // 75% of maxHR → zone3 (70–80%)
        let hr = 185.0 * 0.75
        let zone = HeartRateZone.zone(for: hr, maxHR: 185)
        XCTAssertEqual(zone, .zone3)
    }

    func test_zone_zone2_boundary() {
        // Exactly 60% → zone2
        let zone = HeartRateZone.zone(for: 185 * 0.60, maxHR: 185)
        XCTAssertEqual(zone, .zone2)
    }

    func test_zone_zone4_boundary() {
        // Exactly 80% → zone4
        let zone = HeartRateZone.zone(for: 185 * 0.80, maxHR: 185)
        XCTAssertEqual(zone, .zone4)
    }

    // MARK: - Load values

    func test_calculate_zone1Activity_correctLoad() {
        // 30 min at 100 bpm (zone1, weight 0) → load = 0 (Zone 1 is recovery, no strain)
        let samples = makeConstantHRSamples(hr: 100, durationMinutes: 30)
        let load = StrainCalculator.calculate(samples: samples, maxHR: maxHR)
        XCTAssertEqual(load, 0.0, accuracy: 0.01)
    }

    func test_calculate_zone5Activity_correctLoad() {
        // 90 min at 170 bpm (91.9% of 185 → zone5, weight 4) → load = 90 × 4 = 360
        // Samples are 1-minute apart so the 1-minute gap cap has no effect here.
        let samples = makeConstantHRSamples(hr: 170, durationMinutes: 90)
        let load = StrainCalculator.calculate(samples: samples, maxHR: maxHR)
        XCTAssertEqual(load, 360.0, accuracy: 1.0)
    }

    // MARK: - Score function

    func test_score_lightActivity_lowScore() {
        let load = 30.0
        let score = StrainCalculator.score(load: load, capacity: 350)
        XCTAssertGreaterThan(score, 0)
        XCTAssertLessThan(score, 20)
    }

    func test_score_heavyActivity_highScore() {
        let load = 450.0
        let score = StrainCalculator.score(load: load, capacity: 350)
        XCTAssertEqual(score, 100, accuracy: 0.01)
    }

    func test_score_alwaysClamped0To100() {
        let samples = makeConstantHRSamples(hr: 200, durationMinutes: 600)
        let load = StrainCalculator.calculate(samples: samples, maxHR: maxHR)
        let score = StrainCalculator.score(load: load, capacity: 350)
        XCTAssertGreaterThanOrEqual(score, 0)
        XCTAssertLessThanOrEqual(score, 100)
    }

    func test_score_zeroCapacity_returns0() {
        XCTAssertEqual(StrainCalculator.score(load: 100, capacity: 0), 0)
    }

    // MARK: - Capacity model

    func test_capacity_duringCalibration_returns500() {
        let history = [Double](repeating: 200, count: 5)  // only 5 days
        XCTAssertEqual(StrainCalculator.capacity(fromLoads: history), 500)
    }

    func test_capacity_afterCalibration_returnsAverage() {
        let history = [Double](repeating: 400, count: 10)
        XCTAssertEqual(StrainCalculator.capacity(fromLoads: history), 400, accuracy: 0.01)
    }

    func test_isCalibrating_trueWhenFewDays() {
        XCTAssertTrue(StrainCalculator.isCalibrating(loadHistory: [100, 200, 300]))
    }

    func test_isCalibrating_falseAfterSevenDays() {
        let history = [Double](repeating: 300, count: 7)
        XCTAssertFalse(StrainCalculator.isCalibrating(loadHistory: history))
    }

    // MARK: - Gap capping

    func test_calculate_largeGapCappedToOneMinute() {
        // Two samples 60 minutes apart at zone-4 HR (weight 3).
        // Without capping: load = 60 × 3 = 180.
        // With capping:    load = 1 × 3 = 3.
        let base = Date(timeIntervalSince1970: 0)
        let samples: [(Date, Double)] = [
            (base, 155),
            (base.addingTimeInterval(3600), 155)  // 60-min gap
        ]
        let load = StrainCalculator.calculate(samples: samples, maxHR: maxHR)
        XCTAssertEqual(load, 3.0, accuracy: 0.01)
    }

    func test_calculate_passiveHRSkipped() {
        // HR at 45% of maxHR (< 50% threshold) — should contribute zero load.
        let hr = maxHR * 0.45
        let samples = makeConstantHRSamples(hr: hr, durationMinutes: 30)
        let load = StrainCalculator.calculate(samples: samples, maxHR: maxHR)
        XCTAssertEqual(load, 0.0)
    }

    // MARK: - Max HR estimation

    func test_estimatedMaxHR_30YearOld() {
        XCTAssertEqual(StrainCalculator.estimatedMaxHR(age: 30), 190)
    }

    func test_estimatedMaxHR_formula() {
        for age in [20, 35, 45, 60] {
            XCTAssertEqual(StrainCalculator.estimatedMaxHR(age: age), Double(220 - age))
        }
    }

    // MARK: - Helpers

    private func makeConstantHRSamples(hr: Double, durationMinutes: Int) -> [(Date, Double)] {
        let base = Date()
        return (0...durationMinutes).map { i in
            (Calendar.current.date(byAdding: .minute, value: i, to: base)!, hr)
        }
    }
}
