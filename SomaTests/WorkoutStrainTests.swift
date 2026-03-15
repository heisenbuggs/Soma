import XCTest
@testable import Soma

final class WorkoutStrainTests: XCTestCase {

    // MARK: - Helpers

    private let restingHR: Double = 60
    private let maxHR: Double = 190

    private func makeSamples(bpm: Double, durationMinutes: Double, startingAt base: Date = Date()) -> [(Date, Double)] {
        // Two samples defining an interval of durationMinutes at constant bpm
        return [
            (base, bpm),
            (base.addingTimeInterval(durationMinutes * 60), bpm)
        ]
    }

    private func makeInterval(startOffset: TimeInterval, duration: TimeInterval,
                               name: String = "Running") -> StrainCalculator.WorkoutInterval {
        let base = Date(timeIntervalSince1970: 0)
        return StrainCalculator.WorkoutInterval(
            start: base.addingTimeInterval(startOffset),
            end:   base.addingTimeInterval(startOffset + duration),
            activityName: name
        )
    }

    // MARK: - calculateWorkoutAware: no workout → all incidental

    func test_noWorkouts_allStrainIsIncidental() {
        let base = Date(timeIntervalSince1970: 0)
        let samples: [(Date, Double)] = [
            (base, 130),
            (base.addingTimeInterval(1800), 130) // 30 min at zone-3 HR
        ]
        let result = StrainCalculator.calculateWorkoutAware(
            workoutIntervals: [],
            allSamples: samples,
            restingHR: restingHR,
            maxHR: maxHR
        )
        XCTAssertEqual(result.total, result.incidentalStrain, accuracy: 0.01)
        XCTAssertEqual(result.workoutStrain, 0, accuracy: 0.01)
        XCTAssertTrue(result.details.isEmpty)
    }

    // MARK: - calculateWorkoutAware: workout covers all samples → all workout strain

    func test_workoutCoversAllSamples_allIsWorkoutStrain() {
        let base = Date(timeIntervalSince1970: 1000)
        let samples: [(Date, Double)] = [
            (base, 155),
            (base.addingTimeInterval(3600), 155) // 60 min at high HR
        ]
        let interval = StrainCalculator.WorkoutInterval(
            start: base.addingTimeInterval(-60),
            end:   base.addingTimeInterval(3660),
            activityName: "Running"
        )
        let result = StrainCalculator.calculateWorkoutAware(
            workoutIntervals: [interval],
            allSamples: samples,
            restingHR: restingHR,
            maxHR: maxHR
        )
        XCTAssertGreaterThan(result.workoutStrain, 0)
        XCTAssertEqual(result.incidentalStrain, 0, accuracy: 0.01)
        XCTAssertFalse(result.details.isEmpty)
        XCTAssertEqual(result.details.first?.activityName, "Running")
    }

    // MARK: - calculateWorkoutAware: mixed workout + incidental

    func test_partialWorkout_splitsStrainCorrectly() {
        let base = Date(timeIntervalSince1970: 0)
        // 60 min total: first 30 min in workout, second 30 min incidental
        let allSamples: [(Date, Double)] = [
            (base,                              150),
            (base.addingTimeInterval(1800),     150),  // end of workout
            (base.addingTimeInterval(1800),      80),  // start of incidental
            (base.addingTimeInterval(3600),      80)
        ]
        let interval = StrainCalculator.WorkoutInterval(
            start: base,
            end:   base.addingTimeInterval(1800),
            activityName: "Cycling"
        )
        let result = StrainCalculator.calculateWorkoutAware(
            workoutIntervals: [interval],
            allSamples: allSamples,
            restingHR: restingHR,
            maxHR: maxHR
        )
        // Workout samples at 150 bpm → higher strain contribution
        XCTAssertGreaterThan(result.workoutStrain, result.incidentalStrain,
                             "Workout at 150 bpm should exceed incidental at 80 bpm")
        XCTAssertGreaterThan(result.total, 0)
    }

    // MARK: - calculateWorkoutAware: empty samples → all zeros

    func test_emptySamples_returnsZero() {
        let result = StrainCalculator.calculateWorkoutAware(
            workoutIntervals: [makeInterval(startOffset: 0, duration: 3600)],
            allSamples: [],
            restingHR: restingHR,
            maxHR: maxHR
        )
        XCTAssertEqual(result.total, 0)
        XCTAssertEqual(result.workoutStrain, 0)
        XCTAssertEqual(result.incidentalStrain, 0)
    }

    // MARK: - calculateWorkoutAware: multiple workouts produce multiple details

    func test_multipleWorkouts_multipleDetails() {
        let base = Date(timeIntervalSince1970: 0)
        let samples: [(Date, Double)] = [
            (base, 155),
            (base.addingTimeInterval(1800), 155),
            (base.addingTimeInterval(7200), 145),
            (base.addingTimeInterval(9000), 145)
        ]
        let intervals = [
            StrainCalculator.WorkoutInterval(
                start: base, end: base.addingTimeInterval(1800), activityName: "Running"),
            StrainCalculator.WorkoutInterval(
                start: base.addingTimeInterval(7200), end: base.addingTimeInterval(9000), activityName: "Cycling")
        ]
        let result = StrainCalculator.calculateWorkoutAware(
            workoutIntervals: intervals, allSamples: samples, restingHR: restingHR, maxHR: maxHR
        )
        XCTAssertEqual(result.details.count, 2)
        let names = result.details.map { $0.activityName }
        XCTAssertTrue(names.contains("Running"))
        XCTAssertTrue(names.contains("Cycling"))
    }

    // MARK: - WorkoutInterval struct

    func test_workoutInterval_properties() {
        let start = Date(timeIntervalSince1970: 1000)
        let end   = Date(timeIntervalSince1970: 4600)
        let interval = StrainCalculator.WorkoutInterval(start: start, end: end, activityName: "HIIT")
        XCTAssertEqual(interval.start, start)
        XCTAssertEqual(interval.end,   end)
        XCTAssertEqual(interval.activityName, "HIIT")
    }
}
