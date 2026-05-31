import Foundation

/// Soma Age — estimates a user's *biological* age from long-term Apple Health / Apple
/// Watch trends, in the spirit of WHOOP Age / the NTNU Fitness Age.
///
/// The estimate is the chronological age plus the sum of signed "year offsets" from five
/// categories — Sleep, Recovery, Cardiovascular Fitness, Activity, and Consistency — so the
/// breakdown is fully explainable (e.g. "Cardiovascular Fitness: −3.1 years"). VO₂ max is
/// the dominant driver: it is the best-validated biomarker of fitness and longevity and
/// declines at a well-characterised ~0.4 ml/kg/min per year, so it maps almost directly to
/// years. Every other metric applies a smaller, bounded offset, and the final figure is
/// clamped to a credible range.
///
/// Reference norms here are male (the app currently targets men); female curves can be
/// added behind a `sex` axis later.
///
/// Not yet wired (no data pipeline today): Heart-Rate Recovery, Body Weight / Body Fat /
/// BMI, Blood Pressure. The `Input` is structured so these slot in without reshaping the model.
struct SomaAgeCalculator {

    // MARK: - Calibration requirements

    static let calibrationDays   = 21
    static let minSleepNights    = 14
    static let minRecoveryDays   = 10

    // MARK: - Types

    enum Category: String, CaseIterable {
        case sleep          = "Sleep"
        case recovery       = "Recovery"
        case cardiovascular = "Cardiovascular Fitness"
        case activity       = "Activity"
        case consistency    = "Consistency"
    }

    enum Confidence: String { case low = "Low", medium = "Medium", high = "High" }

    struct CalibrationStatus: Equatable {
        let isCalibrated: Bool
        let progress: Double        // 0–1 across all requirements
        let daysRemaining: Int
        let dataQuality: Double      // 0–100
        let daysOfData: Int
        let sleepNights: Int
        let recoveryDays: Int
    }

    struct CategoryContribution: Equatable {
        let category: Category
        let years: Double           // signed; + = makes you older
    }

    struct Driver: Equatable {
        let title: String
        let years: Double           // signed
        var isPositive: Bool { years < 0 }   // younger = good
    }

    struct Opportunity: Equatable {
        let metric: String
        let currentValue: Double
        let targetValue: Double
        let unit: String
        let potentialYears: Double  // negative = reduction in biological age
        let confidence: Confidence
    }

    struct Result: Equatable {
        let biologicalAge: Double
        let chronologicalAge: Int
        let delta: Double           // biological − chronological (negative = younger)
        let contributions: [CategoryContribution]
        let positiveDrivers: [Driver]
        let negativeDrivers: [Driver]
        let opportunities: [Opportunity]   // ranked, best first
        let confidence: Confidence
    }

    struct Input {
        var chronologicalAge: Int

        // Recovery
        var hrv: Double?                    // ms (SDNN; overnight preferred)
        var restingHR: Double?              // bpm
        var respiratoryRate: Double?        // breaths/min

        // Sleep
        var sleepDurationHours: Double?
        var sleepDebtHours: Double?
        var sleepEfficiency: Double?        // 0–100 (% of in-bed time asleep)

        // Cardiovascular
        var vo2Max: Double?                 // ml/kg/min

        // Activity
        var dailySteps: Double?
        var exerciseMinutesPerWeek: Double?
        var strainScore: Double?            // 0–100 average

        // Consistency (0–100 regularity scores)
        var sleepConsistency: Double?
        var recoveryConsistency: Double?
        var activityConsistency: Double?

        // Calibration inputs
        var daysOfData: Int
        var sleepNights: Int
        var recoveryDays: Int

        init(chronologicalAge: Int,
             hrv: Double? = nil, restingHR: Double? = nil, respiratoryRate: Double? = nil,
             sleepDurationHours: Double? = nil, sleepDebtHours: Double? = nil, sleepEfficiency: Double? = nil,
             vo2Max: Double? = nil,
             dailySteps: Double? = nil, exerciseMinutesPerWeek: Double? = nil, strainScore: Double? = nil,
             sleepConsistency: Double? = nil, recoveryConsistency: Double? = nil, activityConsistency: Double? = nil,
             daysOfData: Int = 0, sleepNights: Int = 0, recoveryDays: Int = 0) {
            self.chronologicalAge = chronologicalAge
            self.hrv = hrv; self.restingHR = restingHR; self.respiratoryRate = respiratoryRate
            self.sleepDurationHours = sleepDurationHours; self.sleepDebtHours = sleepDebtHours; self.sleepEfficiency = sleepEfficiency
            self.vo2Max = vo2Max
            self.dailySteps = dailySteps; self.exerciseMinutesPerWeek = exerciseMinutesPerWeek; self.strainScore = strainScore
            self.sleepConsistency = sleepConsistency; self.recoveryConsistency = recoveryConsistency; self.activityConsistency = activityConsistency
            self.daysOfData = daysOfData; self.sleepNights = sleepNights; self.recoveryDays = recoveryDays
        }
    }

    // MARK: - Calibration

    static func calibrationStatus(daysOfData: Int, sleepNights: Int, recoveryDays: Int) -> CalibrationStatus {
        let dayProg      = min(1.0, Double(daysOfData)   / Double(calibrationDays))
        let sleepProg    = min(1.0, Double(sleepNights)  / Double(minSleepNights))
        let recoveryProg = min(1.0, Double(recoveryDays) / Double(minRecoveryDays))
        let progress = (dayProg + sleepProg + recoveryProg) / 3.0

        let isCalibrated = daysOfData >= calibrationDays
            && sleepNights >= minSleepNights
            && recoveryDays >= minRecoveryDays

        // Data quality reflects how complete the record is, weighted toward sleep/recovery.
        let dataQuality = (dayProg * 0.4 + sleepProg * 0.35 + recoveryProg * 0.25) * 100

        return CalibrationStatus(
            isCalibrated: isCalibrated,
            progress: progress,
            daysRemaining: max(0, calibrationDays - daysOfData),
            dataQuality: round1(dataQuality),
            daysOfData: daysOfData,
            sleepNights: sleepNights,
            recoveryDays: recoveryDays
        )
    }

    // MARK: - Reference curves (male)

    /// Population-average VO₂ max for age (ml/kg/min). ~0.4/yr decline from ~50 at age 20.
    static func expectedVO2Max(age: Int) -> Double {
        clamp(50.0 - 0.40 * Double(age - 20), 20, 55)
    }

    /// Population-average HRV (SDNN, ms) for age.
    static func expectedHRV(age: Int) -> Double {
        clamp(60.0 - 0.45 * Double(age - 20), 20, 70)
    }

    // MARK: - Per-metric year offsets (negative = younger)

    static func vo2Offset(_ vo2: Double, age: Int) -> Double {
        clamp((expectedVO2Max(age: age) - vo2) / 0.40, -12, 12)
    }
    static func restingHROffset(_ rhr: Double) -> Double {
        clamp((rhr - 58.0) * 0.25, -5, 5)
    }
    static func hrvOffset(_ hrv: Double, age: Int) -> Double {
        clamp((expectedHRV(age: age) - hrv) / 4.0, -4, 4)
    }
    static func respiratoryOffset(_ rr: Double) -> Double {
        clamp((rr - 14.0) * 0.6, -2, 3)
    }
    static func sleepDurationOffset(_ hours: Double) -> Double {
        let deviation = abs(hours - 7.75)
        return deviation <= 0.75 ? -0.8 : clamp((deviation - 0.75) * 1.2, 0, 4)
    }
    static func sleepDebtOffset(_ debt: Double) -> Double {
        clamp(debt * 0.5, 0, 4)
    }
    static func sleepEfficiencyOffset(_ eff: Double) -> Double {
        clamp((90.0 - eff) * 0.06, -1.5, 3)
    }
    static func stepsOffset(_ steps: Double) -> Double {
        clamp((8000.0 - steps) / 2500.0, -3, 3)
    }
    static func exerciseOffset(_ minutesPerWeek: Double) -> Double {
        clamp((150.0 - minutesPerWeek) / 60.0, -2, 3)
    }
    static func strainOffset(_ strain: Double) -> Double {
        clamp((35.0 - strain) / 25.0, -1.5, 1.5)
    }
    static func consistencyOffset(_ score: Double, scale: Double) -> Double {
        clamp((70.0 - score) * 0.04 * scale, -2 * scale, 3 * scale)
    }

    // MARK: - Calculation

    /// Returns the Soma Age result, or nil while still calibrating.
    static func calculate(input: Input) -> Result? {
        let calibration = calibrationStatus(
            daysOfData: input.daysOfData,
            sleepNights: input.sleepNights,
            recoveryDays: input.recoveryDays
        )
        guard calibration.isCalibrated else { return nil }

        let age = input.chronologicalAge
        let chrono = Double(age)

        // Collect (category, driver title, years) for every present metric.
        var items: [(category: Category, title: String, years: Double)] = []
        func add(_ category: Category, _ base: String, _ years: Double) {
            items.append((category, label(base, years), years))
        }

        if let v = input.vo2Max, v > 0            { add(.cardiovascular, "VO₂ Max", vo2Offset(v, age: age)) }
        if let r = input.restingHR, r > 0         { add(.recovery, "Resting HR", restingHROffset(r)) }
        if let h = input.hrv, h > 0               { add(.recovery, "HRV", hrvOffset(h, age: age)) }
        if let rr = input.respiratoryRate, rr > 0 { add(.recovery, "Respiratory Rate", respiratoryOffset(rr)) }
        if let d = input.sleepDurationHours, d > 0 { add(.sleep, "Sleep Duration", sleepDurationOffset(d)) }
        if let debt = input.sleepDebtHours        { add(.sleep, "Sleep Debt", sleepDebtOffset(debt)) }
        if let e = input.sleepEfficiency, e > 0   { add(.sleep, "Sleep Efficiency", sleepEfficiencyOffset(e)) }
        if let s = input.dailySteps, s >= 0       { add(.activity, "Daily Steps", stepsOffset(s)) }
        if let ex = input.exerciseMinutesPerWeek, ex >= 0 { add(.activity, "Exercise", exerciseOffset(ex)) }
        if let st = input.strainScore, st >= 0    { add(.activity, "Activity Load", strainOffset(st)) }
        if let c = input.sleepConsistency         { add(.consistency, "Sleep Schedule", consistencyOffset(c, scale: 1.0)) }
        if let c = input.recoveryConsistency      { add(.consistency, "Recovery Consistency", consistencyOffset(c, scale: 0.75)) }
        if let c = input.activityConsistency      { add(.consistency, "Activity Consistency", consistencyOffset(c, scale: 0.75)) }

        let totalOffset = items.reduce(0) { $0 + $1.years }
        let bioAge = clamp(clamp(chrono + totalOffset, chrono - 15, chrono + 20), 18, 99)

        // Per-category contributions (always emit all five, even if zero).
        let contributions = Category.allCases.map { cat in
            CategoryContribution(
                category: cat,
                years: round1(items.filter { $0.category == cat }.reduce(0) { $0 + $1.years })
            )
        }

        let drivers = items
            .map { Driver(title: $0.title, years: round1($0.years)) }
            .sorted { abs($0.years) > abs($1.years) }
        let positives = drivers.filter { $0.years <= -0.3 }
        let negatives = drivers.filter { $0.years >= 0.3 }

        let confidence = confidenceLevel(calibration: calibration)
        let opportunities = buildOpportunities(input: input, confidence: confidence)

        return Result(
            biologicalAge: round1(bioAge),
            chronologicalAge: age,
            delta: round1(bioAge - chrono),
            contributions: contributions,
            positiveDrivers: positives,
            negativeDrivers: negatives,
            opportunities: opportunities,
            confidence: confidence
        )
    }

    // MARK: - Impact Simulation Engine

    /// For each improvable metric, simulates moving it to a healthy target and reports the
    /// resulting biological-age reduction. Ranked best-first.
    static func buildOpportunities(input: Input, confidence: Confidence) -> [Opportunity] {
        let age = input.chronologicalAge
        var opps: [Opportunity] = []

        func add(_ metric: String, _ current: Double, _ target: Double, _ unit: String,
                 _ currentOffset: Double, _ targetOffset: Double) {
            let potential = round1(targetOffset - currentOffset)   // negative = reduction
            // Only surface opportunities worth at least ~0.3 years — avoids noise from
            // metrics that are already near-optimal.
            guard potential <= -0.3 else { return }
            opps.append(Opportunity(metric: metric, currentValue: round1(current),
                                    targetValue: round1(target), unit: unit,
                                    potentialYears: potential, confidence: confidence))
        }

        // Note: VO₂ Max is intentionally NOT an opportunity — it is an *outcome* of the
        // activity levers below and improves slowly, so it can't be "moved to target."

        if let d = input.sleepDurationHours, d > 0, abs(d - 7.5) > 0.5 {
            add("Sleep Duration", d, 7.5, "h", sleepDurationOffset(d), sleepDurationOffset(7.5))
        }
        if let h = input.hrv, h > 0, h < 50 {
            // A realistic near-term lift, capped at a healthy 55 ms.
            let target = min(h + 12, 55)
            add("HRV", h, target, "ms", hrvOffset(h, age: age), hrvOffset(target, age: age))
        }
        if let r = input.restingHR, r > 58 {
            add("Resting HR", r, 58, "bpm", restingHROffset(r), restingHROffset(58))
        }
        if let debt = input.sleepDebtHours, debt > 0.5 {
            add("Sleep Debt", debt, 0, "h", sleepDebtOffset(debt), sleepDebtOffset(0))
        }
        if let s = input.dailySteps, s < 9000 {
            add("Daily Steps", s, 9000, "steps", stepsOffset(s), stepsOffset(9000))
        }
        if let ex = input.exerciseMinutesPerWeek, ex < 150 {
            add("Exercise", ex, 150, "min/wk", exerciseOffset(ex), exerciseOffset(150))
        }
        if let c = input.sleepConsistency, c < 85 {
            add("Sleep Schedule", c, 85, "pts", consistencyOffset(c, scale: 1.0), consistencyOffset(85, scale: 1.0))
        }

        return opps.sorted { $0.potentialYears < $1.potentialYears }
    }

    // MARK: - Confidence

    static func confidenceLevel(calibration: CalibrationStatus) -> Confidence {
        if calibration.daysOfData >= 90 && calibration.dataQuality >= 90 { return .high }
        if calibration.daysOfData >= 45 && calibration.dataQuality >= 75 { return .medium }
        return .low
    }

    // MARK: - Private

    private static func label(_ base: String, _ offset: Double) -> String {
        if offset <= -0.3 { return "Strong \(base)" }
        if offset >=  0.3 { return "Poor \(base)" }
        return base
    }

    private static func round1(_ v: Double) -> Double { (v * 10).rounded() / 10 }

    private static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        Swift.max(lo, Swift.min(hi, v))
    }
}

// MARK: - Notifications

/// Builds the Soma Age notification copy described in the PRD (positive / negative /
/// milestone). Pure string logic so it's trivially testable and can be scheduled from
/// the existing weekly cadence.
enum SomaAgeNotification {

    /// Week-over-week change message, or nil when the change is negligible (< 0.1 yr).
    static func weeklyChangeMessage(previous: Double, current: Double, topNegativeDriver: String? = nil) -> String? {
        let delta = current - previous
        guard abs(delta) >= 0.1 else { return nil }
        let yr = String(format: "%.1f", abs(delta))
        if delta < 0 {
            return "Your Soma Age dropped by \(yr) years this week. Keep it up."
        }
        if let driver = topNegativeDriver {
            return "Your Soma Age rose by \(yr) years this week, driven by \(driver.lowercased())."
        }
        return "Your Soma Age rose by \(yr) years this week."
    }

    /// Milestone message when the user crosses a new whole-year "younger" threshold.
    /// `delta`/`previousDelta` are biological − chronological (negative = younger).
    static func milestoneMessage(delta: Double, previousDelta: Double) -> String? {
        guard delta < 0 else { return nil }
        let yearsYounger = Int(floor(-delta))
        let prevYounger  = Int(floor(-Swift.min(previousDelta, 0)))
        guard yearsYounger > prevYounger, yearsYounger >= 1 else { return nil }
        let s = yearsYounger == 1 ? "year" : "years"
        return "Milestone: you're now \(yearsYounger) \(s) younger biologically than your actual age."
    }
}
