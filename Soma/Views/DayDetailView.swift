import SwiftUI

struct DayDetailView: View {
    @StateObject private var viewModel: DayDetailViewModel

    init(metrics: DailyMetrics, checkInStore: CheckInStore) {
        _viewModel = StateObject(wrappedValue: DayDetailViewModel(metrics: metrics, checkInStore: checkInStore))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                dateHeader
                scoresGrid
                sleepSection
                sleepStagesSection
                vitalsSection
                workoutsSection
                strainSection
                if viewModel.checkIn != nil {
                    checkInSection
                }
                if !viewModel.physiologicalInsights.isEmpty {
                    insightsSection
                }
                if let record = viewModel.notificationRecord {
                    notificationSection(record)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color.somaBackground.ignoresSafeArea())
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        VStack(spacing: 2) {
            Text(viewModel.formattedDayOfWeek)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Text(viewModel.formattedMonthDay)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Scores Grid

    private var scoresGrid: some View {
        let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: cols, spacing: 12) {
            scoreCard("Recovery", viewModel.metrics.recoveryScore, viewModel.metrics.recoveryState)
            scoreCard("Strain",   viewModel.metrics.strainScore,   viewModel.metrics.strainState)
            scoreCard("Sleep",    viewModel.metrics.sleepScore,    viewModel.metrics.sleepState)
            scoreCard("Stress",   viewModel.metrics.stressScore,   viewModel.metrics.stressState)
        }
    }

    private func scoreCard(_ title: String, _ value: Double, _ state: ColorState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(Int(value.rounded()))")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Text(state.label)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(state.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(state.color.opacity(0.15))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Sleep Summary

    private var sleepSection: some View {
        detailCard(title: "Sleep Summary", icon: "moon.zzz.fill", iconColor: Color.somaBlue) {
            VStack(alignment: .leading, spacing: 10) {
                infoRow(label: "Duration", value: viewModel.sleepSummaryLine)
                if let start = viewModel.sleepStartFormatted, let end = viewModel.sleepEndFormatted {
                    infoRow(label: "Window", value: "\(start) – \(end)")
                }
                if let interruptions = viewModel.sleepInterruptionLine {
                    infoRow(label: "Interruptions", value: interruptions)
                }
                if let sc = viewModel.sleepConsistencyFormatted {
                    infoRow(label: "Consistency", value: sc)
                }
                if let nap = viewModel.napFormatted {
                    infoRow(label: "Nap", value: nap)
                }
            }
        }
    }

    // MARK: - Sleep Stages

    @ViewBuilder
    private var sleepStagesSection: some View {
        let hasStages = viewModel.deepSleepFormatted != nil
            || viewModel.remSleepFormatted != nil
            || viewModel.coreSleepFormatted != nil
            || viewModel.sleepingHRFormatted != nil
            || viewModel.sleepingHRVFormatted != nil

        if hasStages {
            detailCard(title: "Sleep Stages & Quality", icon: "waveform.path.ecg", iconColor: Color.somaBlue) {
                VStack(alignment: .leading, spacing: 10) {
                    if let deep = viewModel.deepSleepFormatted {
                        infoRow(label: "Deep Sleep", value: deep)
                    }
                    if let rem = viewModel.remSleepFormatted {
                        infoRow(label: "REM Sleep", value: rem)
                    }
                    if let core = viewModel.coreSleepFormatted {
                        infoRow(label: "Core Sleep", value: core)
                    }
                    if viewModel.deepSleepFormatted != nil || viewModel.remSleepFormatted != nil {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.12))
                            .frame(height: 1)
                    }
                    if let sHRV = viewModel.sleepingHRVFormatted {
                        infoRow(label: "Sleeping HRV", value: sHRV)
                    }
                    if let sHR = viewModel.sleepingHRFormatted {
                        infoRow(label: "Sleeping HR", value: sHR)
                    }
                }
            }
        }
    }

    // MARK: - Vitals

    private var vitalsSection: some View {
        detailCard(title: "Vitals", icon: "heart.text.square.fill", iconColor: Color.somaRed) {
            VStack(alignment: .leading, spacing: 10) {
                if let hrv = viewModel.hrvFormatted {
                    infoRow(label: "HRV", value: hrv)
                }
                if let rhr = viewModel.restingHRFormatted {
                    infoRow(label: "Resting HR", value: rhr)
                }
                if let whr = viewModel.walkingHRFormatted {
                    infoRow(label: "Walking HR Avg", value: whr)
                }
                if let spo2 = viewModel.spo2Formatted {
                    infoRow(label: "Blood Oxygen", value: spo2)
                }
                if let rr = viewModel.respiratoryRateFormatted {
                    infoRow(label: "Respiratory Rate", value: rr)
                }
                if let wt = viewModel.wristTempFormatted {
                    infoRow(label: "Wrist Temp Δ", value: wt)
                }
                if let es = viewModel.eveningStressFormatted {
                    infoRow(label: "Evening Stress", value: es)
                }
                if let vo2 = viewModel.vo2TrendFormatted {
                    infoRow(label: "VO2 Max Trend", value: vo2)
                }
                if let mindful = viewModel.mindfulMinutesFormatted {
                    infoRow(label: "Mindful Minutes", value: mindful)
                }
            }
        }
    }

    // MARK: - Workouts

    @ViewBuilder
    private var workoutsSection: some View {
        if let workouts = viewModel.metrics.workoutZoneDetails, !workouts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("WORKOUTS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(Color.somaOrange)
                        .tracking(0.5)
                    Text("\(workouts.count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(Color.somaOrange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.somaOrange.opacity(0.15))
                        .clipShape(Capsule())
                }
                ForEach(workouts) { workout in
                    WorkoutDetailCard(workout: workout)
                }
            }
        }
    }

    // MARK: - Strain / Activity

    private var strainSection: some View {
        detailCard(title: "Activity", icon: "flame.fill", iconColor: Color.somaOrange) {
            VStack(alignment: .leading, spacing: 10) {
                infoRow(label: "Strain Score", value: String(format: "%.0f / 100", viewModel.metrics.strainScore))
                if viewModel.hasWorkoutBreakdown {
                    infoRow(label: "Workout Strain", value: viewModel.workoutStrainText)
                    infoRow(label: "Incidental Strain", value: viewModel.incidentalStrainText)
                }
                if let steps = viewModel.stepsFormatted {
                    infoRow(label: "Steps", value: steps)
                }
                if let cal = viewModel.activeCalFormatted {
                    infoRow(label: "Active Calories", value: cal)
                }
                if let stand = viewModel.standHoursFormatted {
                    infoRow(label: "Stand Hours", value: stand)
                }
            }
        }
    }

    // MARK: - Check-In

    private var checkInSection: some View {
        detailCard(title: "Yesterday's Check-In", icon: "checkmark.circle.fill", iconColor: Color.somaGreen) {
            guard let ci = viewModel.checkIn else { return AnyView(EmptyView()) }
            return AnyView(
                VStack(alignment: .leading, spacing: 10) {
                    if ci.alcoholConsumed    { flagRow(label: "Alcohol consumed",   color: Color.somaRed) }
                    if ci.caffeineAfter5PM   { flagRow(label: "Late Caffeine",       color: Color.somaYellow) }
                    if ci.lateMealBeforeBed  { flagRow(label: "Late Meal",           color: Color.somaOrange) }
                    if ci.screenBeforeBed    { flagRow(label: "Screen Before Bed",   color: Color.somaOrange) }
                    if ci.lateWorkout        { flagRow(label: "Late Workout",        color: Color.somaOrange) }
                    if ci.meditated          { flagRow(label: "Meditated",           color: Color.somaGreen) }
                    if ci.stretched          { flagRow(label: "Stretched",           color: Color.somaGreen) }
                    if ci.coldExposure       { flagRow(label: "Cold Exposure",       color: Color.somaBlue) }
                    infoRow(label: "Stress Level", value: viewModel.checkInStressLabel)
                }
            )
        }
    }

    // MARK: - Physiological Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(Color.somaYellow)
                    .font(.body)
                Text("Day's Insights")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(viewModel.physiologicalInsights.enumerated()), id: \.offset) { _, tip in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Color.somaYellow)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                        Text(tip)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.somaYellow.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.somaYellow.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Notification

    private func notificationSection(_ record: NotificationRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bell.fill")
                    .foregroundColor(Color.somaPurple)
                    .font(.body)
                Text("Notification Sent")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
                Text(timeStr(record.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(record.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            Text(record.body)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.somaPurple.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.somaPurple.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Reusable Components

    private func detailCard<C: View>(title: String, icon: String, iconColor: Color,
                                     @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            Rectangle()
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 1)
            content()
        }
        .padding(16)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }

    private func flagRow(label: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
        }
    }

    private func timeStr(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }
}

// MARK: - WorkoutDetailCard

struct WorkoutDetailCard: View {
    let workout: WorkoutZoneBreakdown

    private var zoneData: [(zone: String, color: Color, minutes: Double)] {
        [
            ("Z1", Color.somaGray, workout.z1Minutes),
            ("Z2", Color.somaGreen, workout.z2Minutes),
            ("Z3", Color.somaYellow, workout.z3Minutes),
            ("Z4", Color.somaOrange, workout.z4Minutes),
            ("Z5", Color.somaRed, workout.z5Minutes),
        ].filter { $0.minutes > 0 }
    }

    private var totalMinutes: Double {
        workout.durationMinutes > 0 ? workout.durationMinutes : workout.totalZoneMinutes
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.somaOrange.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: activityIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.somaOrange)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(workout.activityName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    if let start = workout.startTime {
                        Text(timeRange(start: start, durationMinutes: totalMinutes))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(String(format: "%.0f", workout.totalStrain))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(Color.somaOrange)
                    Text("strain")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Quick stats
            HStack(spacing: 0) {
                wStatPill(label: "Duration", value: formatMins(totalMinutes))
                if let cal = workout.calories {
                    Divider().frame(height: 28)
                    wStatPill(label: "Calories", value: "\(Int(cal)) kcal")
                }
                Divider().frame(height: 28)
                wStatPill(label: "Active Zones", value: formatMins(workout.activeZoneMinutes))
            }
            .background(Color.somaCardElevated)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // Zone bar + legend
            if !zoneData.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Heart Rate Zones")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            ForEach(zoneData, id: \.zone) { entry in
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(entry.color)
                                    .frame(width: max(4, geo.size.width * (entry.minutes / max(totalMinutes, 1))))
                            }
                        }
                    }
                    .frame(height: 10)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                    let allZones: [(String, Color, Double)] = [
                        ("Z1 Warm Up",    Color.somaGray, workout.z1Minutes),
                        ("Z2 Fat Burn",   Color.somaGreen, workout.z2Minutes),
                        ("Z3 Aerobic",    Color.somaYellow, workout.z3Minutes),
                        ("Z4 Anaerobic",  Color.somaOrange, workout.z4Minutes),
                        ("Z5 Max",        Color.somaRed, workout.z5Minutes),
                    ]
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 5) {
                        ForEach(allZones.filter { $0.2 > 0 }, id: \.0) { name, color, mins in
                            HStack(spacing: 6) {
                                Circle().fill(color).frame(width: 7, height: 7)
                                Text(name).font(.caption2).foregroundColor(.secondary)
                                Spacer()
                                Text(formatMins(mins)).font(.caption2).fontWeight(.semibold).foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.somaOrange.opacity(0.2), lineWidth: 1)
        )
    }

    private var activityIcon: String {
        let n = workout.activityName.lowercased()
        if n.contains("run")                             { return "figure.run" }
        if n.contains("walk")                            { return "figure.walk" }
        if n.contains("cycl") || n.contains("bike")     { return "figure.outdoor.cycle" }
        if n.contains("swim")                            { return "figure.pool.swim" }
        if n.contains("yoga")                            { return "figure.yoga" }
        if n.contains("strength") || n.contains("weight"){ return "dumbbell.fill" }
        if n.contains("hiit") || n.contains("interval") { return "bolt.heart.fill" }
        if n.contains("climb")                           { return "figure.climbing" }
        if n.contains("row")                             { return "figure.rowing" }
        if n.contains("hike")                            { return "figure.hiking" }
        if n.contains("dance")                           { return "figure.dance" }
        if n.contains("tennis") || n.contains("badminton"){ return "figure.tennis" }
        if n.contains("basketball")                      { return "figure.basketball" }
        if n.contains("soccer") || n.contains("football"){ return "soccerball" }
        return "flame.fill"
    }

    private func formatMins(_ mins: Double) -> String {
        let total = Int(mins.rounded())
        let h = total / 60; let m = total % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    private func timeRange(start: Date, durationMinutes: Double) -> String {
        let end = start.addingTimeInterval(durationMinutes * 60)
        let f = DateFormatter(); f.timeStyle = .short
        return "\(f.string(from: start)) – \(f.string(from: end))"
    }

    private func wStatPill(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.primary)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
