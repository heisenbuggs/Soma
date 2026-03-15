import XCTest
@testable import Soma

final class StrainCalculatorTests: XCTestCase {

    private let restingHR: Double = 55
    private let maxHR: Double = 185

    // MARK: - Empty samples

    func test_calculate_emptySamples_returns0() {
        let score = StrainCalculator.calculate(samples: [], restingHR: restingHR, maxHR: maxHR)
        XCTAssertEqual(score, 0)
    }

    func test_calculate_singleSample_returns0() {
        let samples = [(Date(), 80.0)]
        let score = StrainCalculator.calculate(samples: samples, restingHR: restingHR, maxHR: maxHR)
        XCTAssertEqual(score, 0)
    }

    // MARK: - Zone classification

    func test_zone_lowIntensity_isZone1() {
        // HR barely above resting = zone1
        let zone = HeartRateZone.zone(for: 60, restingHR: 55, maxHR: 185)
        XCTAssertEqual(zone, .zone1)
    }

    func test_zone_highIntensity_isZone5() {
        // HR near max = zone5
        let zone = HeartRateZone.zone(for: 180, restingHR: 55, maxHR: 185)
        XCTAssertEqual(zone, .zone5)
    }

    func test_zone_zone3() {
        // intensity = 0.75 → zone3
        let reserve = 185.0 - 55
        let hr = 55 + reserve * 0.75
        let zone = HeartRateZone.zone(for: hr, restingHR: 55, maxHR: 185)
        XCTAssertEqual(zone, .zone3)
    }

    // MARK: - Score bounds

    func test_calculate_lightActivity_lowStrain() {
        let samples = makeConstantHRSamples(hr: 100, durationMinutes: 30, restingHR: restingHR, maxHR: maxHR)
        let score = StrainCalculator.calculate(samples: samples, restingHR: restingHR, maxHR: maxHR)
        XCTAssertGreaterThan(score, 0)
        XCTAssertLessThan(score, 10)
    }

    func test_calculate_heavyActivity_highStrain() {
        // 90 minutes at zone 4/5 HR
        let samples = makeConstantHRSamples(hr: 170, durationMinutes: 90, restingHR: restingHR, maxHR: maxHR)
        let score = StrainCalculator.calculate(samples: samples, restingHR: restingHR, maxHR: maxHR)
        XCTAssertGreaterThan(score, 10)
        XCTAssertLessThanOrEqual(score, 21)
    }

    func test_calculate_alwaysClamped0To21() {
        // Extreme case
        let samples = makeConstantHRSamples(hr: 200, durationMinutes: 600, restingHR: restingHR, maxHR: maxHR)
        let score = StrainCalculator.calculate(samples: samples, restingHR: restingHR, maxHR: maxHR)
        XCTAssertGreaterThanOrEqual(score, 0)
        XCTAssertLessThanOrEqual(score, 21)
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

    private func makeConstantHRSamples(
        hr: Double,
        durationMinutes: Int,
        restingHR: Double,
        maxHR: Double
    ) -> [(Date, Double)] {
        let base = Date()
        return (0...durationMinutes).map { i in
            (Calendar.current.date(byAdding: .minute, value: i, to: base)!, hr)
        }
    }
}
