import SwiftUI
import Charts

// MARK: - Shared formatting

enum SomaAgeFormat {
    static func age(_ value: Double) -> String { String(format: "%.1f", value) }

    /// "3.6 years younger" / "5.8 years older" / "on track".
    static func deltaPhrase(_ delta: Double) -> String {
        let abs = Swift.abs(delta)
        if abs < 0.1 { return "On track with your age" }
        let yr = String(format: "%.1f", abs)
        return delta < 0 ? "\(yr) years younger" : "\(yr) years older"
    }

    static func deltaColor(_ delta: Double) -> Color {
        if delta < -0.1 { return .somaGreen }
        if delta >  0.1 { return .somaRed }
        return .somaYellow
    }

    static func years(_ value: Double) -> String {
        let sign = value > 0 ? "+" : (value < 0 ? "−" : "")
        return "\(sign)\(String(format: "%.1f", Swift.abs(value))) yr"
    }
}

// MARK: - Detail View

struct SomaAgeDetailView: View {
    let result: SomaAgeCalculator.Result?
    let calibration: SomaAgeCalculator.CalibrationStatus
    let chronologicalAge: Int
    let trend: [(date: Date, age: Double)]

    @Environment(\.dismiss) private var dismiss
    @State private var range: TrendRange = .ninety

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let result {
                        header(result)
                        if trend.count >= 2 { trendCard }
                        breakdownCard(result)
                        driversCard(result)
                        if !result.opportunities.isEmpty { opportunitiesCard(result) }
                        confidenceCard(result)
                    } else {
                        calibratingCard
                    }
                    disclaimer
                }
                .padding()
            }
            .background(Color.somaBackground.ignoresSafeArea())
            .navigationTitle("Soma Age")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Header

    private func header(_ result: SomaAgeCalculator.Result) -> some View {
        VStack(spacing: 6) {
            Text("Biological Age")
                .font(.subheadline).foregroundColor(.secondary)
            Text(SomaAgeFormat.age(result.biologicalAge))
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundColor(SomaAgeFormat.deltaColor(result.delta))
            Text("years")
                .font(.caption).foregroundColor(.secondary)
            Text(SomaAgeFormat.deltaPhrase(result.delta))
                .font(.headline)
                .foregroundColor(SomaAgeFormat.deltaColor(result.delta))
            Text("Chronological age: \(result.chronologicalAge)")
                .font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Trend

    enum TrendRange: String, CaseIterable, Identifiable {
        case thirty = "30D", ninety = "90D", sixMonths = "6M", year = "1Y"
        var id: String { rawValue }
        var days: Int {
            switch self {
            case .thirty: return 30
            case .ninety: return 90
            case .sixMonths: return 182
            case .year: return 365
            }
        }
    }

    private var filteredTrend: [(date: Date, age: Double)] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -range.days, to: Date()) else { return trend }
        return trend.filter { $0.date >= cutoff }
    }

    private var trendCard: some View {
        card {
            HStack {
                Text("Trend").font(.headline)
                Spacer()
                Picker("Range", selection: $range) {
                    ForEach(TrendRange.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            let data = filteredTrend
            if data.count >= 2 {
                Chart(data, id: \.date) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Soma Age", point.age))
                        .foregroundStyle(Color.somaBlue)
                        .interpolationMethod(.catmullRom)
                    AreaMark(x: .value("Date", point.date), y: .value("Soma Age", point.age))
                        .foregroundStyle(Color.somaBlue.opacity(0.12))
                        .interpolationMethod(.catmullRom)
                }
                .frame(height: 160)
                .chartYScale(domain: .automatic(includesZero: false))
            } else {
                Text("Not enough data in this range yet.")
                    .font(.caption).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Category breakdown

    private func breakdownCard(_ result: SomaAgeCalculator.Result) -> some View {
        card {
            Text("Age Breakdown").font(.headline)
            Text("How each area moves your biological age.")
                .font(.caption).foregroundColor(.secondary)
            let maxMag = max(0.5, result.contributions.map { Swift.abs($0.years) }.max() ?? 0.5)
            ForEach(result.contributions, id: \.category) { c in
                HStack(spacing: 10) {
                    Text(c.category.rawValue)
                        .font(.subheadline)
                        .frame(width: 130, alignment: .leading)
                    contributionBar(years: c.years, maxMag: maxMag)
                    Text(SomaAgeFormat.years(c.years))
                        .font(.caption).monospacedDigit()
                        .foregroundColor(c.years <= 0 ? .somaGreen : .somaRed)
                        .frame(width: 56, alignment: .trailing)
                }
            }
        }
    }

    private func contributionBar(years: Double, maxMag: Double) -> some View {
        GeometryReader { geo in
            let half = geo.size.width / 2
            let frac = Swift.min(1.0, Swift.abs(years) / maxMag)
            let barW = half * frac
            ZStack(alignment: .center) {
                Rectangle().fill(Color.somaGray.opacity(0.15)).frame(height: 8)
                Rectangle().fill(Color.somaGray.opacity(0.3)).frame(width: 1)
                Rectangle()
                    .fill(years <= 0 ? Color.somaGreen : Color.somaRed)
                    .frame(width: barW, height: 8)
                    .offset(x: years <= 0 ? -barW / 2 : barW / 2)
            }
        }
        .frame(height: 12)
    }

    // MARK: - Drivers

    private func driversCard(_ result: SomaAgeCalculator.Result) -> some View {
        card {
            Text("Health Drivers").font(.headline)
            if !result.positiveDrivers.isEmpty {
                Text("Working for you").font(.caption).foregroundColor(.somaGreen)
                ForEach(result.positiveDrivers, id: \.title) { d in
                    driverRow(d.title, d.years, positive: true)
                }
            }
            if !result.negativeDrivers.isEmpty {
                Text("Holding you back").font(.caption).foregroundColor(.somaRed)
                    .padding(.top, 4)
                ForEach(result.negativeDrivers, id: \.title) { d in
                    driverRow(d.title, d.years, positive: false)
                }
            }
            if result.positiveDrivers.isEmpty && result.negativeDrivers.isEmpty {
                Text("No standout drivers yet.").font(.caption).foregroundColor(.secondary)
            }
        }
    }

    private func driverRow(_ title: String, _ years: Double, positive: Bool) -> some View {
        HStack {
            Image(systemName: positive ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .foregroundColor(positive ? .somaGreen : .somaRed)
            Text(title).font(.subheadline)
            Spacer()
            Text(SomaAgeFormat.years(years))
                .font(.caption).monospacedDigit()
                .foregroundColor(positive ? .somaGreen : .somaRed)
        }
    }

    // MARK: - Opportunities

    private func opportunitiesCard(_ result: SomaAgeCalculator.Result) -> some View {
        card {
            Text("Top Opportunities").font(.headline)
            Text("The fastest ways to lower your Soma Age.")
                .font(.caption).foregroundColor(.secondary)
            ForEach(Array(result.opportunities.prefix(3).enumerated()), id: \.offset) { _, opp in
                opportunityRow(opp)
            }
        }
    }

    private func opportunityRow(_ opp: SomaAgeCalculator.Opportunity) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(opp.metric).font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text(SomaAgeFormat.years(opp.potentialYears))
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundColor(.somaGreen)
            }
            HStack {
                Text("Now: \(format(opp.currentValue)) \(opp.unit)")
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
                Image(systemName: "arrow.right").font(.caption2).foregroundColor(.somaGray)
                Spacer()
                Text("Target: \(format(opp.targetValue)) \(opp.unit)")
                    .font(.caption).foregroundColor(.primary)
            }
        }
        .padding(.vertical, 6)
        .overlay(Divider(), alignment: .bottom)
    }

    private func format(_ v: Double) -> String {
        v >= 100 ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }

    // MARK: - Confidence

    private func confidenceCard(_ result: SomaAgeCalculator.Result) -> some View {
        card {
            HStack {
                Text("Confidence").font(.headline)
                Spacer()
                Text(result.confidence.rawValue)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(confidenceColor(result.confidence))
            }
            Text("Based on \(calibration.daysOfData) days of data, \(calibration.sleepNights) sleep nights, and \(Int(calibration.dataQuality))% data completeness.")
                .font(.caption).foregroundColor(.secondary)
        }
    }

    private func confidenceColor(_ c: SomaAgeCalculator.Confidence) -> Color {
        switch c {
        case .high: return .somaGreen
        case .medium: return .somaYellow
        case .low: return .somaOrange
        }
    }

    // MARK: - Calibrating

    private var calibratingCard: some View {
        card {
            HStack {
                Image(systemName: "hourglass")
                    .foregroundColor(.somaBlue)
                Text("Calibrating").font(.headline)
            }
            Text("We need 21 days of data — including 14 nights of sleep and 10 days of recovery — before estimating your Soma Age.")
                .font(.subheadline).foregroundColor(.secondary)

            ProgressView(value: calibration.progress)
                .tint(.somaBlue)
            Text("\(Int(calibration.progress * 100))% calibrated · \(calibration.daysRemaining) days remaining")
                .font(.caption).foregroundColor(.secondary)

            VStack(spacing: 6) {
                requirementRow("Days of data", calibration.daysOfData, SomaAgeCalculator.calibrationDays)
                requirementRow("Sleep nights", calibration.sleepNights, SomaAgeCalculator.minSleepNights)
                requirementRow("Recovery days", calibration.recoveryDays, SomaAgeCalculator.minRecoveryDays)
            }
            .padding(.top, 4)

            Text("Data quality: \(Int(calibration.dataQuality))%")
                .font(.caption).foregroundColor(.secondary)
        }
    }

    private func requirementRow(_ label: String, _ have: Int, _ need: Int) -> some View {
        HStack {
            Image(systemName: have >= need ? "checkmark.circle.fill" : "circle")
                .foregroundColor(have >= need ? .somaGreen : .somaGray)
            Text(label).font(.subheadline)
            Spacer()
            Text("\(min(have, need)) / \(need)")
                .font(.caption).monospacedDigit().foregroundColor(.secondary)
        }
    }

    private var disclaimer: some View {
        Text("Soma Age is an estimate of physiological age based on long-term health trends. It is not a medical diagnosis.")
            .font(.caption2).foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }

    // MARK: - Card container

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.somaCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
