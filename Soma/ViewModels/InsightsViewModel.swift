import Foundation

struct Insight: Identifiable, Codable {
    let id: UUID
    let icon: String
    let title: String
    let description: String
    let priority: InsightPriority
    let date: Date

    init(icon: String, title: String, description: String, priority: InsightPriority, date: Date = Date()) {
        self.id = UUID()
        self.icon = icon
        self.title = title
        self.description = description
        self.priority = priority
        self.date = date
    }
}

enum InsightPriority: Int, Comparable, Codable {
    case high = 0   // red
    case medium = 1 // yellow
    case low = 2    // green

    static func < (lhs: InsightPriority, rhs: InsightPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var colorStateName: String {
        switch self {
        case .high:   return "red"
        case .medium: return "yellow"
        case .low:    return "green"
        }
    }
}

@MainActor
final class InsightsViewModel: ObservableObject {

    @Published var insights: [Insight] = []
    @Published var behaviorInsights: [BehaviorInsight] = []
    @Published var trainingGuidance: DailyTrainingGuidance?

    private let store: MetricsStore
    private let checkInStore: CheckInStore

    init(store: MetricsStore, checkInStore: CheckInStore) {
        self.store = store
        self.checkInStore = checkInStore
    }

    /// Loads insights from cache if fresh, or recomputes if stale.
    /// - Parameter forceRefresh: When true, always recomputes regardless of cache state.
    func generateInsights(forceRefresh: Bool = false) {
        let latestMetrics = store.load(for: Date())
        let latestCheckIn = checkInStore.loadAll().max { $0.date < $1.date }?.date

        let physioStale   = forceRefresh || InsightCache.shared.isPhysioStale(latestMetricsDate: latestMetrics?.date)
        let behaviorStale = forceRefresh || InsightCache.shared.isBehaviorStale(latestCheckInDate: latestCheckIn)

        // Load cached results first so the UI is never blank while recomputing
        if !physioStale, let cached = InsightCache.shared.loadPhysio() {
            insights = cached
        } else {
            generatePhysiologicalInsights()
        }

        if !behaviorStale, let cached = InsightCache.shared.loadBehavior() {
            behaviorInsights = cached
        } else {
            generateBehaviorInsights()
        }

        // Training guidance is always recomputed from stored data (fast, no HealthKit).
        if let today = latestMetrics {
            trainingGuidance = computeGuidance(for: today)
        }
    }

    private func computeGuidance(for metrics: DailyMetrics) -> DailyTrainingGuidance {
        let last30  = store.loadLast(30)
        let history = store.loadLast(28)

        let hrvHist     = BaselineCalculator.extractHistory(from: last30, \.hrvAverage)
        let rhrHist     = BaselineCalculator.extractHistory(from: last30, \.restingHR)
        let hrvBaseline = BaselineCalculator.computeHRVBaseline(from: hrvHist)
        let rhrBaseline = BaselineCalculator.computeRHRBaseline(from: rhrHist)

        let sleepGoalStored = UserDefaults.standard.double(forKey: UserDefaultsKeys.baselineSleepHours)
        let sleepGoal = sleepGoalStored > 0 ? sleepGoalStored : 7.0

        let strainLoadHistory = store.loadLast(StrainCalculator.rollingCapacityDays).compactMap { $0.strainLoad }
        let isCalibrating = StrainCalculator.isCalibrating(loadHistory: strainLoadHistory)

        return TrainingGuidanceEngine.generate(
            metrics: metrics,
            history: history,
            hrvBaseline: hrvBaseline,
            rhrBaseline: rhrBaseline,
            sleepGoal: sleepGoal,
            isCalibrating: isCalibrating
        )
    }

    // MARK: - Physiological Insights

    private func generatePhysiologicalInsights() {
        guard let today = store.load(for: Date()) else {
            insights = []
            return
        }

        let last7 = store.loadLast(7)
        let hrvHistory     = BaselineCalculator.extractHistory(from: last7, \.hrvAverage)
        let rhrHistory     = BaselineCalculator.extractHistory(from: last7, \.restingHR)
        let sleepHRHistory = BaselineCalculator.extractHistory(from: last7, \.sleepingHR)
        let sleepHRVHistory = BaselineCalculator.extractHistory(from: last7, \.sleepingHRV)
        let walkingHRHistory = BaselineCalculator.extractHistory(from: last7, \.walkingHRAverage)
        let hrvBaseline    = BaselineCalculator.computeHRVBaseline(from: hrvHistory)
        let rhrBaseline    = BaselineCalculator.computeRHRBaseline(from: rhrHistory)
        let sleepHRBaseline  = BaselineCalculator.computeBaseline(from: sleepHRHistory)
        let sleepHRVBaseline = BaselineCalculator.computeBaseline(from: sleepHRVHistory)
        let walkingHRBaseline = BaselineCalculator.computeBaseline(from: walkingHRHistory)

        var results: [Insight] = []

        // MARK: HRV
        if let hrv = today.hrvAverage, let base = hrvBaseline, base > 0 {
            let ratio = hrv / base
            if ratio < 0.85 {
                let pct = Int((1.0 - ratio) * 100)
                results.append(Insight(
                    icon: "waveform.path.ecg",
                    title: "HRV Below Baseline",
                    description: "Your HRV is \(pct)% below baseline. Consider light activity or rest today.",
                    priority: .high
                ))
            } else if ratio > 1.10 {
                results.append(Insight(
                    icon: "heart.fill",
                    title: "HRV Elevated",
                    description: "Your HRV is above baseline — your body is primed and well recovered.",
                    priority: .low
                ))
            }
        }

        // MARK: Sleeping HR
        if let shr = today.sleepingHR, let base = sleepHRBaseline, base > 0, shr > base + 5 {
            results.append(Insight(
                icon: "heart.circle.fill",
                title: "Elevated Sleeping HR",
                description: "Your heart rate during sleep was \(Int(shr)) bpm — \(Int(shr - base)) above your usual. Alcohol, late meals, or stress can raise it.",
                priority: .medium
            ))
        }

        // MARK: Sleeping HRV
        if let shRV = today.sleepingHRV, let base = sleepHRVBaseline, base > 0 {
            let ratio = shRV / base
            if ratio < 0.80 {
                let pct = Int((1.0 - ratio) * 100)
                results.append(Insight(
                    icon: "waveform.path.ecg",
                    title: "Low Sleeping HRV",
                    description: "Sleeping HRV is \(pct)% below your norm — your autonomic system was stressed during sleep.",
                    priority: .medium
                ))
            }
        }

        // MARK: Sleep stages — deep, REM, core
        // Optimal targets from SleepCalculator: deep ≥20%, REM ≥22%, core ≥50% of total sleep
        if let deep = today.deepSleepMinutes,
           let rem  = today.remSleepMinutes,
           let core = today.coreSleepMinutes {
            let total = deep + rem + core
            if total > 0 {
                let deepPct = deep / total
                let remPct  = rem  / total

                if deep < 40 {
                    // Critically low deep sleep — flag regardless of percentage
                    results.append(Insight(
                        icon: "moon.fill",
                        title: "Very Low Deep Sleep",
                        description: "Only \(Int(deep)) min of deep sleep recorded. Deep sleep drives physical repair and memory consolidation — aim for at least 60 min. Avoid late night food/alcohol and late exercise.",
                        priority: .high
                    ))
                } else if deepPct < 0.13 {
                    let pct = Int(deepPct * 100)
                    results.append(Insight(
                        icon: "moon.fill",
                        title: "Low Deep Sleep",
                        description: "Deep sleep was \(Int(deep)) min (\(pct)% of total). The target is ≥20%. Consistent bedtimes, cooler room temperature, and avoiding late night food/alcohol help increase deep sleep.",
                        priority: .medium
                    ))
                } else if deepPct >= 0.20 {
                    results.append(Insight(
                        icon: "moon.stars.fill",
                        title: "Excellent Deep Sleep",
                        description: "Deep sleep was \(Int(deep)) min (\(Int(deepPct * 100))% of total) — above the optimal threshold. Your body got strong physical recovery overnight.",
                        priority: .low
                    ))
                }

                if rem < 60 {
                    results.append(Insight(
                        icon: "brain",
                        title: "Low REM Sleep",
                        description: "REM sleep was only \(Int(rem)) min. REM drives emotional regulation and memory — aim for 90+ min. Alcohol, cannabis, and fragmented sleep suppress REM.",
                        priority: .medium
                    ))
                } else if remPct >= 0.22 {
                    results.append(Insight(
                        icon: "brain.fill",
                        title: "Strong REM Sleep",
                        description: "REM sleep was \(Int(rem)) min (\(Int(remPct * 100))% of total) — right on target. Cognitive performance and emotional regulation should feel sharp today.",
                        priority: .low
                    ))
                }

                // Core sleep too low may indicate disrupted light sleep architecture
                if core < 120 && total > 240 {
                    results.append(Insight(
                        icon: "bed.double",
                        title: "Low Core Sleep",
                        description: "Core (light) sleep was only \(Int(core)) min — less than expected for your total sleep time. This can indicate frequent awakenings or data gaps.",
                        priority: .medium
                    ))
                }
            }
        }

        // MARK: Sleep interruptions
        if let interruptions = today.sleepInterruptions, interruptions >= 3 {
            results.append(Insight(
                icon: "moon.zzz.fill",
                title: "Fragmented Sleep",
                description: "Your sleep was interrupted \(interruptions) times. A consistent bedtime and limiting fluids before bed help.",
                priority: .medium
            ))
        }

        // MARK: Sleep vs goal
        let sleepGoalHours = UserDefaults.standard.double(forKey: UserDefaultsKeys.baselineSleepHours)
        let sleepGoal = sleepGoalHours > 0 ? sleepGoalHours : 7.0
        if let actual = today.sleepDurationHours {
            if actual >= sleepGoal {
                results.append(Insight(
                    icon: "moon.stars.fill",
                    title: "Sleep Goal Met",
                    description: "You hit your \(String(format: "%.0f", sleepGoal))h sleep goal. Consistent sleep fuels recovery.",
                    priority: .low
                ))
            } else {
                let debtMinutes = Int((sleepGoal - actual) * 60)
                let debtHrs = debtMinutes / 60; let debtMins = debtMinutes % 60
                let debtStr = debtMins == 0 ? "\(debtHrs)h" : "\(debtHrs)h \(debtMins)m"
                results.append(Insight(
                    icon: "bed.double.fill",
                    title: "Sleep Deficit",
                    description: "You slept \(debtStr) less than your goal. Aim for an earlier bedtime tonight.",
                    priority: .medium
                ))
            }
        }

        // MARK: Sleep consistency
        if let consistency = today.sleepConsistencyScore, consistency < 45 {
            results.append(Insight(
                icon: "clock.arrow.2.circlepath",
                title: "Irregular Sleep Schedule",
                description: "Your sleep/wake times vary significantly (consistency \(Int(consistency))/100). A fixed schedule is one of the highest-leverage sleep improvements.",
                priority: .medium
            ))
        }

        // MARK: Ayurvedic sleep timing
        if let ayur = today.ayurvedicSleepPoints, ayur < 4 {
            results.append(Insight(
                icon: "moon.stars",
                title: "Poor Sleep Timing",
                description: "Ayurvedic sleep score is \(String(format: "%.1f", ayur))/10 — your bedtime or wake time drifted far from the restorative window. Aim to sleep before 10 PM.",
                priority: .medium
            ))
        }

        // MARK: Nap duration
        if let nap = today.napDurationMinutes {
            if nap > 80 {
                results.append(Insight(
                    icon: "moon.haze.fill",
                    title: "Long Nap Warning",
                    description: "Your nap was \(Int(nap)) min. Naps over 80 min can cause sleep inertia and delay tonight's sleep onset. Aim for 30–60 min.",
                    priority: .medium
                ))
            } else if nap >= 30 && nap <= 60 {
                results.append(Insight(
                    icon: "moon.haze",
                    title: "Perfect Power Nap",
                    description: "A \(Int(nap))-minute nap boosts alertness and helps consolidate recovery without disrupting tonight's sleep.",
                    priority: .low
                ))
            }
        }

        // MARK: High strain streak
        if store.loadLast(3).filter({ $0.strainScore > 18 }).count >= 2 {
            results.append(Insight(
                icon: "flame.fill",
                title: "High Strain Streak",
                description: "High strain for multiple consecutive days. A lighter day will help your body absorb the training.",
                priority: .high
            ))
        }

        // MARK: Recovery streak
        if last7.filter({ $0.recoveryScore >= 70 }).count >= 3 {
            results.append(Insight(
                icon: "star.fill",
                title: "Great Recovery Streak",
                description: "You've had \(last7.filter({ $0.recoveryScore >= 70 }).count) high-recovery days this week. Your body is primed — a quality training session will pay off.",
                priority: .low
            ))
        }

        // MARK: Low recovery
        if today.recoveryScore < 34 {
            results.append(Insight(
                icon: "arrow.down.heart.fill",
                title: "Low Recovery",
                description: "Recovery is in the red. Prioritize rest, hydration, and an early bedtime tonight.",
                priority: .high
            ))
        }

        // MARK: Elevated resting HR
        if let rhr = today.restingHR, let base = rhrBaseline, rhr > base + 3 {
            results.append(Insight(
                icon: "heart.slash.fill",
                title: "Elevated Resting HR",
                description: "Resting HR is \(Int(rhr - base)) bpm above your baseline — a common sign of incomplete recovery, dehydration, or early illness.",
                priority: .medium
            ))
        }

        // MARK: Walking HR efficiency
        if let whr = today.walkingHRAverage, let base = walkingHRBaseline, base > 0, whr > base + 8 {
            results.append(Insight(
                icon: "figure.walk",
                title: "Walking HR Elevated",
                description: "Your heart is working harder than usual on routine movement (\(Int(whr)) vs \(Int(base)) bpm typical). A lighter day is warranted.",
                priority: .medium
            ))
        } else if let whr = today.walkingHRAverage, let base = walkingHRBaseline, base > 0, whr < base - 5 {
            results.append(Insight(
                icon: "figure.walk",
                title: "Cardiovascular Efficiency Up",
                description: "Your walking HR is \(Int(base - whr)) bpm below your norm — a sign of improving cardiovascular fitness.",
                priority: .low
            ))
        }

        // MARK: Stand hours — only surfaced after 8 PM (day is effectively over)
        let currentHour = Calendar.current.component(.hour, from: Date())
        if let stand = today.standHours, stand < 6, currentHour >= 20 {
            results.append(Insight(
                icon: "figure.stand",
                title: "Low Movement Day",
                description: "You only stood for \(stand)h today. Prolonged sitting blunts recovery — aim for at least 10 stand hours.",
                priority: .medium
            ))
        }

        // MARK: Blood oxygen
        if let spo2 = today.bloodOxygen, spo2 < 95 {
            results.append(Insight(
                icon: "drop.circle.fill",
                title: "Low Blood Oxygen",
                description: "SpO2 is \(String(format: "%.1f", spo2))% — below the healthy threshold. Avoid intense exercise. Persistent low readings warrant medical attention.",
                priority: .high
            ))
        }

        // MARK: Respiratory rate — only flag at rest (skip if workout logged today)
        let hadWorkoutToday = (today.workoutMinutes ?? 0) > 0
        if let rr = today.respiratoryRate, rr > 20, !hadWorkoutToday {
            results.append(Insight(
                icon: "lungs.fill",
                title: "Elevated Respiratory Rate",
                description: "Resting respiratory rate is \(String(format: "%.1f", rr)) br/min — above the healthy threshold of 20. Can indicate stress, illness, or poor sleep quality.",
                priority: .medium
            ))
        }

        // MARK: Evening stress
        if let es = today.eveningStressScore, es > 55 {
            results.append(Insight(
                icon: "moon.and.stars.fill",
                title: "High Pre-Sleep Stress",
                description: "Your autonomic activity was elevated between 8–11 PM (score \(Int(es))/100). High pre-sleep arousal shortens deep sleep — try light stretching or breathwork.",
                priority: .medium
            ))
        }

        // MARK: VO2 Max trend
        if let trend = today.vo2MaxTrend {
            if trend < -0.5 {
                results.append(Insight(
                    icon: "lungs",
                    title: "VO2 Max Declining",
                    description: "Aerobic fitness is trending down (\(String(format: "%.1f", trend)) ml/kg/min per 30d). Adding 2–3 zone 2 cardio sessions per week can reverse this.",
                    priority: .medium
                ))
            } else if trend > 0.5 {
                results.append(Insight(
                    icon: "lungs.fill",
                    title: "VO2 Max Improving",
                    description: "Aerobic fitness is trending up (\(String(format: "+%.1f", trend)) ml/kg/min per 30d). Your training is paying off — keep going.",
                    priority: .low
                ))
            }
        }

        // MARK: Mindful minutes
        if let mins = today.mindfulMinutes, mins >= 10 {
            results.append(Insight(
                icon: "brain.head.profile",
                title: "Mindfulness Logged",
                description: "You completed \(Int(mins)) min of mindfulness today — this directly lowers sympathetic tone and supports HRV recovery.",
                priority: .low
            ))
        }

        // MARK: Wrist temperature
        // Requires 7 days of stored metrics (baseline established) AND at least 2 prior
        // nights with wrist temp readings. Apple Watch needs multiple nights to calibrate
        // its own baseline, so early readings are unreliable.
        let priorNightsWithWristTemp = last7
            .filter { !Calendar.current.isDateInToday($0.date) }
            .compactMap { $0.wristTempDeviation }
        if let tempDev = today.wristTempDeviation, tempDev > 0.5,
           last7.count >= 7,
           priorNightsWithWristTemp.count >= 2 {
            let formatted = String(format: "+%.1f°C", tempDev)
            results.append(Insight(
                icon: "thermometer.medium",
                title: "Elevated Wrist Temp",
                description: "Sleeping wrist temperature is \(formatted) above your baseline — a possible early illness signal. Consider rest and hydration.",
                priority: .high
            ))
        }

        // MARK: High stress
        if today.stressScore > 60 {
            results.append(Insight(
                icon: "brain.head.profile",
                title: "Elevated Stress",
                description: "Stress indicators are elevated. Box breathing (4-4-4-4) or a 10-minute walk can help bring it down.",
                priority: .medium
            ))
        }

        // MARK: Sleep debt
        let needVsActual: [(Double, Double)] = last7.compactMap { m in
            guard let actual = m.sleepDurationHours, let need = m.sleepNeedHours else { return nil }
            return (need, actual)
        }
        let totalDebt = SleepCalculator.computeSleepDebt(needVsActual: needVsActual)
        if totalDebt > 3 {
            results.append(Insight(
                icon: "zzz",
                title: "Sleep Debt",
                description: "You've accumulated \(String(format: "%.1f", totalDebt))h of sleep debt this week. Each night 30 min earlier chips away at it.",
                priority: .medium
            ))
        }

        let sorted = results.sorted { $0.priority < $1.priority }.prefix(8).map { $0 }
        insights = sorted
        InsightCache.shared.savePhysio(sorted)
    }

    // MARK: - Behavioral Insights (Behavior Intelligence Engine)

    private func generateBehaviorInsights() {
        let checkIns = checkInStore.loadAll()
        let metrics  = store.loadAll()
        let generated = BehaviorEngine.generateInsights(checkIns: checkIns, metrics: metrics)
        behaviorInsights = generated
        InsightCache.shared.saveBehavior(generated)
    }
}
