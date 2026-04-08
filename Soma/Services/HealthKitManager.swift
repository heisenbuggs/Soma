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
    func fetchVO2MaxHistory(days: Int) async throws -> [(Date, Double)]
    func fetchRespiratoryRate(for date: Date) async throws -> Double?
    func fetchWorkouts(for date: Date) async throws -> [HKWorkout]
    func fetchSleepGoal() async throws -> Double?
    func fetchBloodOxygen(for date: Date) async throws -> Double?
    func fetchExerciseMinutes(for date: Date) async throws -> Double?
    func writeBehavioralData(_ checkIn: DailyCheckIn) async throws
    func fetchEarliestDataDate() async -> Date?
    // Priority 2/3 data sources
    func fetchWristTemperature(for date: Date) async throws -> Double?
    func fetchStandHours(for date: Date) async throws -> Int
    func fetchWalkingHRAverage(for date: Date) async throws -> Double?
    func fetchMindfulMinutes(for date: Date) async throws -> Double
}

// MARK: - HealthKitManager

final class HealthKitManager: ObservableObject, HealthDataProviding {
    let healthStore = HKHealthStore()

    @Published var isAuthorized = false
    @Published var authorizationDenied = false
    @Published var healthKitAvailable = HKHealthStore.isHealthDataAvailable()

    var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRate),
            HKCategoryType(.sleepAnalysis),
            HKQuantityType(.respiratoryRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.vo2Max),
            HKQuantityType(.stepCount),
            HKQuantityType(.oxygenSaturation),
            HKQuantityType(.appleExerciseTime),
            HKWorkoutType.workoutType(),
            // Priority 2/3 additions
            HKQuantityType(.walkingHeartRateAverage),
            HKCategoryType(.appleStandHour),
            HKCategoryType(.mindfulSession),
        ]
        if #available(iOS 17, *) {
            types.insert(HKQuantityType(.appleSleepingWristTemperature))
        }
        return types
    }

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
        // Sleep window: previous day 8 PM to current day 8 PM.
        // Rule: any sleep/nap that starts before 8 PM counts as that same calendar day;
        // anything after 8 PM counts as the next day (overnight into tomorrow).
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        let sleepWindowStart = cal.date(byAdding: .hour, value: -4, to: startOfDay)!   // yesterday 8 PM
        let sleepWindowEnd   = cal.date(byAdding: .hour, value: 20, to: startOfDay)!   // today 8 PM
        let predicate = HKQuery.predicateForSamples(withStart: sleepWindowStart,
                                                    end: sleepWindowEnd,
                                                    options: .strictStartDate)
        let type = HKCategoryType(.sleepAnalysis)
        let samples = try await fetchSamples(type: type, predicate: predicate)
        return parseSleepSamples(samples.compactMap { $0 as? HKCategorySample }, targetDate: date)
    }

    private func parseSleepSamples(_ samples: [HKCategorySample], targetDate: Date) -> SleepData {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: targetDate)
        // Daytime nap window: 10 AM – 8 PM on the target date
        let napWindowStart = cal.date(bySettingHour: 10, minute: 0, second: 0, of: startOfDay)!
        let napWindowEnd   = cal.date(bySettingHour: 20, minute: 0, second: 0, of: startOfDay)!

        // Separate tracking for night sleep and naps
        var nightDeep: TimeInterval = 0
        var nightRem: TimeInterval = 0
        var nightCore: TimeInterval = 0
        var nightAwake: TimeInterval = 0
        var nightInBed: TimeInterval = 0
        
        var napDeep: TimeInterval = 0
        var napRem: TimeInterval = 0
        var napCore: TimeInterval = 0

        // Night sleep bounds (excludes daytime naps)
        var nightStart: Date?
        var nightEnd: Date?

        // Nap tracking - separate from night sleep
        var napDuration: TimeInterval = 0
        var napStart: Date?
        var napEnd: Date?

        let sleepStages: Set<HKCategoryValueSleepAnalysis> = [.asleepDeep, .asleepREM, .asleepCore, .asleepUnspecified]

        // Group samples into sleep sessions to better handle multiple sessions
        let sleepSessions = groupSamplesIntoSessions(samples)
        
        for (sessionIndex, session) in sleepSessions.enumerated() {
            let sessionStart = session.startDate
            let sessionEnd = session.endDate
            
            // Classify entire session as nap if it starts and ends within nap window
            // This prevents morning sleep sessions (like 07:41-09:07) from being classified as naps
            let isNapSession = sessionStart >= napWindowStart && sessionEnd <= napWindowEnd
            
            #if DEBUG
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            print("  Processing session \(sessionIndex + 1): \(formatter.string(from: sessionStart))-\(formatter.string(from: sessionEnd)) -> \(isNapSession ? "NAP" : "NIGHT SLEEP")")
            #endif
            
            var sessionNightSleep: TimeInterval = 0
            var sessionNapSleep: TimeInterval = 0
            
            for sample in session.samples {
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { continue }

                switch value {
                case .asleepDeep:
                    if isNapSession {
                        napDeep += duration
                        sessionNapSleep += duration
                    } else {
                        nightDeep += duration
                        sessionNightSleep += duration
                    }
                case .asleepREM:
                    if isNapSession {
                        napRem += duration
                        sessionNapSleep += duration
                    } else {
                        nightRem += duration
                        sessionNightSleep += duration
                    }
                case .asleepCore, .asleepUnspecified:
                    if isNapSession {
                        napCore += duration
                        sessionNapSleep += duration
                    } else {
                        nightCore += duration
                        sessionNightSleep += duration
                    }
                case .awake:
                    if !isNapSession {
                        nightAwake += duration
                    }
                case .inBed:
                    if !isNapSession {
                        nightInBed += duration
                    }
                @unknown default:
                    break
                }
            }
            
            #if DEBUG
            if sessionNightSleep > 0 {
                print("    Night sleep contribution: \(String(format: "%.2f", sessionNightSleep / 3600.0))h (\(String(format: "%.0f", sessionNightSleep / 60.0))min)")
            }
            if sessionNapSleep > 0 {
                print("    Nap sleep contribution: \(String(format: "%.2f", sessionNapSleep / 3600.0))h (\(String(format: "%.0f", sessionNapSleep / 60.0))min)")
            }
            #endif
            
            // Track session bounds
            if isNapSession && sessionNapSleep > 0 {
                if napStart == nil || sessionStart < napStart! { napStart = sessionStart }
                if napEnd == nil || sessionEnd > napEnd! { napEnd = sessionEnd }
            } else if !isNapSession && sessionNightSleep > 0 {
                if nightStart == nil || sessionStart < nightStart! { nightStart = sessionStart }
                if nightEnd == nil || sessionEnd > nightEnd! { nightEnd = sessionEnd }
            }
        }

        // Count interruptions only during night sleep
        let nightAwakeSamples = samples.filter { sample in
            let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
            let isInNapWindow = sample.startDate >= napWindowStart && sample.endDate <= napWindowEnd
            return value == .awake && !isInNapWindow
        }.sorted { $0.startDate < $1.startDate }
        let interruptionCount = nightAwakeSamples.count

        // Total night sleep duration (this is what gets reported as main sleep)
        let totalNightSleep = nightDeep + nightRem + nightCore
        // Total nap duration
        let totalNapSleep = napDeep + napRem + napCore
        
        #if DEBUG
        // Debug logging to validate sleep calculations
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: targetDate)
        
        print("💤 Sleep Data Summary for \(dateStr):")
        print("  Night Sleep Total: \(String(format: "%.2f", totalNightSleep / 3600.0))h (\(String(format: "%.0f", totalNightSleep / 60.0))min)")
        print("    Deep: \(String(format: "%.0f", nightDeep / 60.0))min, REM: \(String(format: "%.0f", nightRem / 60.0))min, Core: \(String(format: "%.0f", nightCore / 60.0))min")
        if totalNapSleep > 0 {
            print("  Nap Sleep Total: \(String(format: "%.2f", totalNapSleep / 3600.0))h (\(String(format: "%.0f", totalNapSleep / 60.0))min)")
        }
        if let start = nightStart, let end = nightEnd {
            formatter.dateFormat = "HH:mm"
            print("  Night Period: \(formatter.string(from: start)) - \(formatter.string(from: end))")
        }
        print("  Interruptions: \(interruptionCount)")
        
        // Show expected vs actual for debugging
        if totalNightSleep > 0 {
            let expectedMinutes = totalNightSleep / 60.0
            let reportedHours = totalNightSleep / 3600.0
            print("  Expected in UI: \(String(format: "%.0f", expectedMinutes))min or \(String(format: "%.2f", reportedHours))h")
        }
        #endif
        
        return SleepData(
            totalDuration: totalNightSleep, // Only night sleep counts toward main sleep score
            deepSleepDuration: nightDeep,
            remSleepDuration: nightRem,
            coreSleepDuration: nightCore,
            awakeDuration: nightAwake,
            inBedDuration: nightInBed,
            sleepStartTime: nightStart,
            sleepEndTime: nightEnd,
            interruptionCount: interruptionCount,
            napDurationSeconds: totalNapSleep, // Separate nap tracking
            napStartTime: napStart,
            napEndTime: napEnd
        )
    }
    
    // MARK: - Sleep Session Grouping
    
    private struct SleepSession {
        let startDate: Date
        let endDate: Date
        let samples: [HKCategorySample]
    }
    
    /// Groups sleep samples into discrete sessions based on temporal proximity
    /// This helps distinguish between separate sleep periods (night + morning + afternoon)
    private func groupSamplesIntoSessions(_ samples: [HKCategorySample]) -> [SleepSession] {
        guard !samples.isEmpty else { return [] }
        
        let sortedSamples = samples.sorted { $0.startDate < $1.startDate }
        var sessions: [SleepSession] = []
        var currentSessionSamples: [HKCategorySample] = []
        
        let maxGapBetweenSessions: TimeInterval = 4 * 3600 // 4 hours gap indicates new session
        
        for sample in sortedSamples {
            if let lastSample = currentSessionSamples.last {
                let gap = sample.startDate.timeIntervalSince(lastSample.endDate)
                if gap > maxGapBetweenSessions {
                    // End current session and start new one
                    if !currentSessionSamples.isEmpty {
                        let sessionStart = currentSessionSamples.first!.startDate
                        let sessionEnd = currentSessionSamples.last!.endDate
                        sessions.append(SleepSession(
                            startDate: sessionStart,
                            endDate: sessionEnd,
                            samples: currentSessionSamples
                        ))
                    }
                    currentSessionSamples = [sample]
                } else {
                    currentSessionSamples.append(sample)
                }
            } else {
                currentSessionSamples.append(sample)
            }
        }
        
        // Add final session
        if !currentSessionSamples.isEmpty {
            let sessionStart = currentSessionSamples.first!.startDate
            let sessionEnd = currentSessionSamples.last!.endDate
            sessions.append(SleepSession(
                startDate: sessionStart,
                endDate: sessionEnd,
                samples: currentSessionSamples
            ))
        }
        
        #if DEBUG
        // Debug logging to help validate sleep session detection
        if !sessions.isEmpty {
            print("🛏️ Sleep Analysis Debug - Detected \(sessions.count) session(s):")
            for (index, session) in sessions.enumerated() {
                let duration = session.endDate.timeIntervalSince(session.startDate) / 3600.0
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                print("  Session \(index + 1): \(formatter.string(from: session.startDate)) - \(formatter.string(from: session.endDate)) (\(String(format: "%.2f", duration))h)")
                
                let sleepStages = session.samples.filter { 
                    let value = HKCategoryValueSleepAnalysis(rawValue: $0.value)
                    return [.asleepDeep, .asleepREM, .asleepCore, .asleepUnspecified].contains(value ?? .inBed)
                }
                let totalSleep = sleepStages.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                print("    Sleep duration: \(String(format: "%.2f", totalSleep / 3600.0))h (\(String(format: "%.0f", totalSleep / 60.0))min)")
                
                // Debug individual sleep stages
                var stageBreakdown: [String: TimeInterval] = [:]
                for sample in session.samples {
                    guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { continue }
                    let duration = sample.endDate.timeIntervalSince(sample.startDate)
                    let key = "\(value)"
                    stageBreakdown[key, default: 0] += duration
                }
                for (stage, duration) in stageBreakdown {
                    print("      \(stage): \(String(format: "%.0f", duration / 60.0))min")
                }
            }
        }
        #endif
        
        return sessions
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
                    let nsErr = error as NSError
                    // errorNoData means no samples for this predicate — treat as empty, not a failure.
                    if nsErr.domain == HKErrorDomain && nsErr.code == HKError.Code.errorNoData.rawValue {
                        continuation.resume(returning: [])
                    } else {
                        continuation.resume(throwing: error)
                    }
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
                    let nsErr = error as NSError
                    // errorNoData (11) means no samples matched — return nil, not an error.
                    if nsErr.domain == HKErrorDomain && nsErr.code == HKError.Code.errorNoData.rawValue {
                        continuation.resume(returning: nil)
                    } else {
                        continuation.resume(throwing: error)
                    }
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
                    let nsErr = error as NSError
                    // errorNoData (11) means no samples matched — return nil, not an error.
                    if nsErr.domain == HKErrorDomain && nsErr.code == HKError.Code.errorNoData.rawValue {
                        continuation.resume(returning: nil)
                    } else {
                        continuation.resume(throwing: error)
                    }
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

    // MARK: - Earliest Data Date

    /// Returns the start date of the oldest heart rate sample in HealthKit.
    /// Used to determine how far back a historical backfill should reach.
    func fetchEarliestDataDate() async -> Date? {
        let type = HKQuantityType(.heartRate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let samples = try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, results, error in
                if let error = error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: results ?? []) }
            }
            healthStore.execute(query)
        }
        return samples?.first?.startDate
    }

    // MARK: - Blood Oxygen (SpO2)

    /// Fetches average blood oxygen saturation for the given date.
    /// Returns percentage (e.g., 95.5 for 95.5% oxygen saturation).
    func fetchBloodOxygen(for date: Date) async throws -> Double? {
        let type = HKQuantityType(.oxygenSaturation)
        let predicate = dayPredicate(for: date)
        
        let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (results as? [HKQuantitySample]) ?? [])
                }
            }
            healthStore.execute(query)
        }
        
        guard !samples.isEmpty else { return nil }
        
        // Convert to percentage (HealthKit stores as fraction 0.0-1.0)
        let percentages = samples.map { $0.quantity.doubleValue(for: .percent()) * 100.0 }
        return percentages.reduce(0, +) / Double(percentages.count)
    }

    // MARK: - Exercise Minutes

    /// Fetches Apple Exercise Time minutes for the given date.
    /// This represents minutes of moderate-to-vigorous activity that count toward your Exercise ring.
    func fetchExerciseMinutes(for date: Date) async throws -> Double? {
        let type = HKQuantityType(.appleExerciseTime)
        let predicate = dayPredicate(for: date)
        
        let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (results as? [HKQuantitySample]) ?? [])
                }
            }
            healthStore.execute(query)
        }
        
        guard !samples.isEmpty else { return nil }
        
        // Sum all exercise time samples for the day
        let totalMinutes = samples.reduce(0.0) { sum, sample in
            sum + sample.quantity.doubleValue(for: .minute())
        }
        
        return totalMinutes > 0 ? totalMinutes : nil
    }

    // MARK: - VO2 Max History

    /// Fetches VO2 Max samples over the last `days` days, grouped by calendar day.
    /// Used to compute a rolling trend slope (ml/kg/min per month).
    func fetchVO2MaxHistory(days: Int) async throws -> [(Date, Double)] {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let type = HKQuantityType(.vo2Max)
        let unit = HKUnit(from: "ml/kg*min")
        let samples = try await fetchSamples(type: type, predicate: predicate)
        return groupByDay(samples: samples.compactMap { $0 as? HKQuantitySample }, unit: unit)
    }

    // MARK: - Wrist Temperature (Apple Watch Series 8+ / Ultra, requires iOS 17+)

    /// Returns the nightly sleeping wrist temperature deviation from the user's personal baseline (°C).
    /// Apple Watch computes and stores this automatically each night. Nil on unsupported hardware.
    func fetchWristTemperature(for date: Date) async throws -> Double? {
        guard #available(iOS 17, *) else { return nil }
        let type = HKQuantityType(.appleSleepingWristTemperature)
        let predicate = dayPredicate(for: date)
        return try await fetchStatisticsAverage(type: type, predicate: predicate, unit: .degreeCelsius())
    }

    // MARK: - Stand Hours

    /// Returns the number of Apple Stand hours credited on the given date (0–24).
    /// Each hour where the watch detected at least 1 minute of standing/movement counts.
    func fetchStandHours(for date: Date) async throws -> Int {
        let predicate = dayPredicate(for: date)
        let type = HKCategoryType(.appleStandHour)
        let samples = try await fetchSamples(type: type, predicate: predicate)
        return samples.compactMap { $0 as? HKCategorySample }
            .filter { $0.value == HKCategoryValueAppleStandHour.stood.rawValue }
            .count
    }

    // MARK: - Walking Heart Rate Average

    /// Returns the average heart rate during casual, low-exertion walking for the given date.
    /// Lower values indicate better cardiovascular efficiency.
    func fetchWalkingHRAverage(for date: Date) async throws -> Double? {
        let predicate = dayPredicate(for: date)
        let type = HKQuantityType(.walkingHeartRateAverage)
        let unit = HKUnit.count().unitDivided(by: .minute())
        return try await fetchStatisticsAverage(type: type, predicate: predicate, unit: unit)
    }

    // MARK: - Mindful Minutes

    /// Returns the total number of mindful session minutes on the given date,
    /// summed across all sessions from the Mindfulness app or compatible third-party apps.
    func fetchMindfulMinutes(for date: Date) async throws -> Double {
        let predicate = dayPredicate(for: date)
        let type = HKCategoryType(.mindfulSession)
        let samples = try await fetchSamples(type: type, predicate: predicate)
        let totalSeconds = samples.compactMap { $0 as? HKCategorySample }
            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        return totalSeconds / 60.0
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
