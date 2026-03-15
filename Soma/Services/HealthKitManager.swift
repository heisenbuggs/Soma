import Foundation
import HealthKit

// MARK: - Protocol for testability

protocol HealthDataProviding {
    func requestAuthorization() async throws
    func fetchHRV(for date: Date) async throws -> [Double]
    func fetchHRVHistory(days: Int) async throws -> [(Date, Double)]
    func fetchRestingHR(for date: Date) async throws -> Double?
    func fetchRestingHRHistory(days: Int) async throws -> [(Date, Double)]
    func fetchHeartRateSamples(for date: Date) async throws -> [(Date, Double)]
    func fetchSleepAnalysis(for date: Date) async throws -> SleepData
    func fetchSleepingHR(from start: Date, to end: Date) async throws -> Double?
    func fetchSleepingHRV(from start: Date, to end: Date) async throws -> Double?
    func fetchActiveEnergy(for date: Date) async throws -> Double
    func fetchSteps(for date: Date) async throws -> Double
    func fetchVO2Max() async throws -> Double?
    func fetchRespiratoryRate(for date: Date) async throws -> Double?
    func fetchWorkouts(for date: Date) async throws -> [HKWorkout]
    func fetchSleepGoal() async throws -> Double?
    func writeBehavioralData(_ checkIn: DailyCheckIn) async throws
}

// MARK: - HealthKitManager

final class HealthKitManager: ObservableObject, HealthDataProviding {
    let healthStore = HKHealthStore()

    @Published var isAuthorized = false
    @Published var authorizationDenied = false
    @Published var healthKitAvailable = HKHealthStore.isHealthDataAvailable()

    let readTypes: Set<HKObjectType> = [
        HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.heartRate),
        HKCategoryType(.sleepAnalysis),
        HKQuantityType(.respiratoryRate),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.vo2Max),
        HKQuantityType(.stepCount),
        HKWorkoutType.workoutType()
    ]

    let writeTypes: Set<HKSampleType> = []

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
        await MainActor.run { self.isAuthorized = true }
    }

    // MARK: - HRV

    func fetchHRV(for date: Date) async throws -> [Double] {
        let predicate = dayPredicate(for: date)
        let type = HKQuantityType(.heartRateVariabilitySDNN)
        let samples = try await fetchSamples(type: type, predicate: predicate)
        return samples.compactMap { ($0 as? HKQuantitySample)?.quantity.doubleValue(for: .secondUnit(with: .milli)) }
    }

    func fetchHRVHistory(days: Int) async throws -> [(Date, Double)] {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let type = HKQuantityType(.heartRateVariabilitySDNN)
        let samples = try await fetchSamples(type: type, predicate: predicate)
        return groupByDay(samples: samples.compactMap { $0 as? HKQuantitySample },
                          unit: .secondUnit(with: .milli))
    }

    // MARK: - Resting Heart Rate

    func fetchRestingHR(for date: Date) async throws -> Double? {
        let predicate = dayPredicate(for: date)
        let type = HKQuantityType(.restingHeartRate)
        let unit = HKUnit.count().unitDivided(by: .minute())
        return try await fetchStatisticsAverage(type: type, predicate: predicate, unit: unit)
    }

    func fetchRestingHRHistory(days: Int) async throws -> [(Date, Double)] {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let type = HKQuantityType(.restingHeartRate)
        let unit = HKUnit.count().unitDivided(by: .minute())
        let samples = try await fetchSamples(type: type, predicate: predicate)
        return groupByDay(samples: samples.compactMap { $0 as? HKQuantitySample }, unit: unit)
    }

    // MARK: - Heart Rate Samples

    func fetchHeartRateSamples(for date: Date) async throws -> [(Date, Double)] {
        let predicate = dayPredicate(for: date)
        let type = HKQuantityType(.heartRate)
        let unit = HKUnit.count().unitDivided(by: .minute())
        let samples = try await fetchSamples(type: type, predicate: predicate)
        return samples.compactMap { sample -> (Date, Double)? in
            guard let qty = sample as? HKQuantitySample else { return nil }
            return (qty.startDate, qty.quantity.doubleValue(for: unit))
        }
    }

    // MARK: - Sleep

    func fetchSleepAnalysis(for date: Date) async throws -> SleepData {
        // Sleep window: previous noon to current noon (captures overnight sleep)
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        let sleepWindowStart = cal.date(byAdding: .hour, value: -12, to: startOfDay)!
        let sleepWindowEnd = cal.date(byAdding: .hour, value: 12, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(withStart: sleepWindowStart,
                                                    end: sleepWindowEnd,
                                                    options: .strictStartDate)
        let type = HKCategoryType(.sleepAnalysis)
        let samples = try await fetchSamples(type: type, predicate: predicate)
        return parseSleepSamples(samples.compactMap { $0 as? HKCategorySample })
    }

    private func parseSleepSamples(_ samples: [HKCategorySample]) -> SleepData {
        var deep: TimeInterval = 0
        var rem: TimeInterval = 0
        var core: TimeInterval = 0
        var awake: TimeInterval = 0
        var inBed: TimeInterval = 0
        var startTime: Date?
        var endTime: Date?

        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { continue }
            switch value {
            case .asleepDeep:
                deep += duration
            case .asleepREM:
                rem += duration
            case .asleepCore, .asleepUnspecified:
                core += duration
            case .awake:
                awake += duration
            case .inBed:
                inBed += duration
            @unknown default:
                break
            }
            if startTime == nil || sample.startDate < startTime! {
                startTime = sample.startDate
            }
            if endTime == nil || sample.endDate > endTime! {
                endTime = sample.endDate
            }
        }

        // Count distinct awake segments (interruptions) that occur between sleep stages
        let awakeSamples = samples.filter {
            HKCategoryValueSleepAnalysis(rawValue: $0.value) == .awake
        }.sorted { $0.startDate < $1.startDate }
        let interruptionCount = awakeSamples.count

        let total = deep + rem + core
        return SleepData(
            totalDuration: total,
            deepSleepDuration: deep,
            remSleepDuration: rem,
            coreSleepDuration: core,
            awakeDuration: awake,
            inBedDuration: inBed,
            sleepStartTime: startTime,
            sleepEndTime: endTime,
            interruptionCount: interruptionCount
        )
    }

    // MARK: - Sleeping Window HR / HRV

    /// Average heart rate during the sleep window (used in sleep score).
    func fetchSleepingHR(from start: Date, to end: Date) async throws -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let type = HKQuantityType(.heartRate)
        let unit = HKUnit.count().unitDivided(by: .minute())
        return try await fetchStatisticsAverage(type: type, predicate: predicate, unit: unit)
    }

    /// Average HRV during the sleep window (used in sleep score).
    func fetchSleepingHRV(from start: Date, to end: Date) async throws -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let type = HKQuantityType(.heartRateVariabilitySDNN)
        return try await fetchStatisticsAverage(type: type, predicate: predicate, unit: .secondUnit(with: .milli))
    }

    // MARK: - Active Energy

    func fetchActiveEnergy(for date: Date) async throws -> Double {
        let predicate = dayPredicate(for: date)
        let type = HKQuantityType(.activeEnergyBurned)
        return try await fetchStatisticsSum(type: type, predicate: predicate, unit: .kilocalorie()) ?? 0
    }

    // MARK: - Steps

    func fetchSteps(for date: Date) async throws -> Double {
        let predicate = dayPredicate(for: date)
        let type = HKQuantityType(.stepCount)
        return try await fetchStatisticsSum(type: type, predicate: predicate, unit: .count()) ?? 0
    }

    // MARK: - VO2 Max

    func fetchVO2Max() async throws -> Double? {
        let type = HKQuantityType(.vo2Max)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: results ?? [])
                }
            }
            healthStore.execute(query)
        }
        guard let sample = samples.first as? HKQuantitySample else { return nil }
        let unit = HKUnit(from: "ml/kg*min")
        return sample.quantity.doubleValue(for: unit)
    }

    // MARK: - Respiratory Rate

    func fetchRespiratoryRate(for date: Date) async throws -> Double? {
        let predicate = dayPredicate(for: date)
        let type = HKQuantityType(.respiratoryRate)
        let unit = HKUnit.count().unitDivided(by: .minute())
        return try await fetchStatisticsAverage(type: type, predicate: predicate, unit: unit)
    }

    // MARK: - Sleep Goal

    /// Apple Health does not expose the user's sleep goal to third-party apps via HealthKit.
    /// Returns nil so the caller falls back to the in-app setting (default 7.5h).
    func fetchSleepGoal() async throws -> Double? {
        return nil
    }

    // MARK: - Workouts

    func fetchWorkouts(for date: Date) async throws -> [HKWorkout] {
        let predicate = dayPredicate(for: date)
        let type = HKWorkoutType.workoutType()
        let samples = try await fetchSamples(type: type, predicate: predicate)
        return samples.compactMap { $0 as? HKWorkout }
    }

    // MARK: - Helpers

    private func dayPredicate(for date: Date) -> NSPredicate {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        return HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    }

    private func fetchSamples(type: HKSampleType, predicate: NSPredicate) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: results ?? [])
                }
            }
            healthStore.execute(query)
        }
    }

    private func fetchStatisticsAverage(type: HKQuantityType,
                                        predicate: NSPredicate,
                                        unit: HKUnit) async throws -> Double? {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, stats, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let value = stats?.averageQuantity()?.doubleValue(for: unit)
                    continuation.resume(returning: value)
                }
            }
            healthStore.execute(query)
        }
    }

    private func fetchStatisticsSum(type: HKQuantityType,
                                    predicate: NSPredicate,
                                    unit: HKUnit) async throws -> Double? {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let value = stats?.sumQuantity()?.doubleValue(for: unit)
                    continuation.resume(returning: value)
                }
            }
            healthStore.execute(query)
        }
    }

    private func groupByDay(samples: [HKQuantitySample], unit: HKUnit) -> [(Date, Double)] {
        let cal = Calendar.current
        var groups: [Date: [Double]] = [:]
        for sample in samples {
            let day = cal.startOfDay(for: sample.startDate)
            groups[day, default: []].append(sample.quantity.doubleValue(for: unit))
        }
        return groups.sorted { $0.key < $1.key }.map { (day, values) in
            (day, values.reduce(0, +) / Double(values.count))
        }
    }

    // MARK: - Write Behavioral Data

    /// Optionally writes behavioral check-in data to Apple Health.
    /// No-op: dietary quantity identifiers (alcohol, caffeine) are not available
    /// via the modern HealthKit subscript API on the current SDK target.
    func writeBehavioralData(_ checkIn: DailyCheckIn) async throws {
        // Check-in data is stored locally in CheckInStore; HealthKit write is skipped.
    }
}

// MARK: - Workout Activity Display Names

extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .running:               return "Running"
        case .cycling:               return "Cycling"
        case .swimming:              return "Swimming"
        case .walking:               return "Walking"
        case .hiking:                return "Hiking"
        case .highIntensityIntervalTraining: return "HIIT"
        case .traditionalStrengthTraining:   return "Strength Training"
        case .functionalStrengthTraining:    return "Functional Strength"
        case .yoga:                  return "Yoga"
        case .rowing:                return "Rowing"
        case .elliptical:            return "Elliptical"
        case .stairClimbing:         return "Stair Climbing"
        case .crossTraining:         return "Cross Training"
        case .pilates:               return "Pilates"
        case .dance:                 return "Dance"
        case .boxing:                return "Boxing"
        case .soccer:                return "Soccer"
        case .basketball:            return "Basketball"
        case .tennis:                return "Tennis"
        case .golf:                  return "Golf"
        case .downhillSkiing:        return "Skiing"
        case .snowboarding:          return "Snowboarding"
        case .surfingSports:         return "Surfing"
        case .martialArts:           return "Martial Arts"
        case .other:                 return "Workout"
        default:                     return "Workout"
        }
    }
}

// MARK: - Errors

enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationDenied
    case dataUnavailable

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device."
        case .authorizationDenied:
            return "Health data access was denied."
        case .dataUnavailable:
            return "No health data available."
        }
    }
}
