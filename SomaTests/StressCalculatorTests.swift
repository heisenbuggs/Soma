import XCTest
@testable import Soma

final class StressCalculatorTests: XCTestCase {

    // MARK: - Score Bounds

    func test_calculate_allNil_returns0() {
        let score = StressCalculator.calculate(
            daytimeHRV: nil,
            daytimeAvgHR: nil,
            hrvBaseline: nil,
            rhrBaseline: nil
        )
        XCTAssertEqual(score, 0)
    }

    func test_calculate_perfectHRV_noElevatedHR_lowStress() {
        // HRV equals baseline → suppression = 0
        // HR equals rhrBaseline → elevation = 0
        let score = StressCalculator.calculate(
            daytimeHRV: 60,
            daytimeAvgHR: 70,
            hrvBaseline: 60,
            rhrBaseline: 70
        )
        XCTAssertEqual(score, 0, accuracy: 0.01)
    }

    func test_calculate_zeroHRV_highStress() {
        // HRV = 0, baseline = 60 → suppression = 1.0
        // HR slightly elevated
        let score = StressCalculator.calculate(
            daytimeHRV: 0,
            daytimeAvgHR: 80,
            hrvBaseline: 60,
            rhrBaseline: 60
        )
        // suppression = 1.0, elevation = (80-60)/60 ≈ 0.333
        // stress = (0.6*1.0 + 0.4*0.333) * 100 = (0.6 + 0.133)*100 ≈ 73.3
        XCTAssertGreaterThan(score, 60)
        XCTAssertLessThanOrEqual(score, 100)
    }

    func test_calculate_hrv_aboveBaseline_noStress() {
        // HRV above baseline → suppression = max(0, ...) = 0
        let score = StressCalculator.calculate(
            daytimeHRV: 80,
            daytimeAvgHR: 65,
            hrvBaseline: 60,
            rhrBaseline: 65
        )
        XCTAssertEqual(score, 0, accuracy: 0.01)
    }

    func test_calculate_clampedTo100() {
        let score = StressCalculator.calculate(
            daytimeHRV: 0,
            daytimeAvgHR: 200,
            hrvBaseline: 60,
            rhrBaseline: 60
        )
        XCTAssertLessThanOrEqual(score, 100)
        XCTAssertGreaterThanOrEqual(score, 0)
    }

    func test_calculate_moderate_stress() {
        // HRV 15% below baseline
        // HR 10% above baseline
        let score = StressCalculator.calculate(
            daytimeHRV: 51,    // 15% below 60
            daytimeAvgHR: 77,  // 10% above 70
            hrvBaseline: 60,
            rhrBaseline: 70
        )
        // suppression = max(0, 1 - 51/60) ≈ 0.15
        // elevation = max(0, (77-70)/70) ≈ 0.1
        // stress = (0.6*0.15 + 0.4*0.1)*100 = (0.09 + 0.04)*100 = 13
        XCTAssertEqual(score, 13, accuracy: 1.0)
        XCTAssertLessThan(score, 31)  // should be low/green range
    }

    // MARK: - Daytime Filter

    func test_filterDaytime_removesNightSamples() {
        let date = Calendar.current.startOfDay(for: Date())
        let nightTime = Calendar.current.date(bySettingHour: 2, minute: 0, second: 0, of: date)!
        let dayTime = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: date)!
        let eveningTime = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: date)!
        let lateNight = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: date)!

        let samples: [(Date, Double)] = [
            (nightTime, 75),
            (dayTime, 80),
            (eveningTime, 78),
            (lateNight, 72)
        ]

        let filtered = StressCalculator.filterDaytime(samples, on: date)
        XCTAssertEqual(filtered.count, 2)
        XCTAssertEqual(filtered[0].1, 80)
        XCTAssertEqual(filtered[1].1, 78)
    }

    func test_filterDaytime_emptyOnNight() {
        let date = Calendar.current.startOfDay(for: Date())
        let nightTime = Calendar.current.date(bySettingHour: 3, minute: 0, second: 0, of: date)!
        let filtered = StressCalculator.filterDaytime([(nightTime, 70)], on: date)
        XCTAssertTrue(filtered.isEmpty)
    }

    // MARK: - Average

    func test_average_emptyReturnsNil() {
        XCTAssertNil(StressCalculator.average([]))
    }

    func test_average_singleValue() {
        XCTAssertEqual(StressCalculator.average([(Date(), 75)]), 75)
    }

    func test_average_multipleValues() {
        let samples: [(Date, Double)] = [(Date(), 70), (Date(), 80), (Date(), 90)]
        XCTAssertEqual(StressCalculator.average(samples)!, 80, accuracy: 0.01)
    }
}
