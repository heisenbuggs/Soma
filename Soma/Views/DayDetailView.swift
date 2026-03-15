import SwiftUI

struct DayDetailView: View {
    @StateObject private var viewModel: DayDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(metrics: DailyMetrics, checkInStore: CheckInStore) {
        _viewModel = StateObject(wrappedValue: DayDetailViewModel(metrics: metrics, checkInStore: checkInStore))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    dateHeader
                    scoresGrid
                    sleepSection
                    strainSection
                    if viewModel.checkIn != nil {
                        checkInSection
                    }
                    insightSection
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color.somaBackground.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(hex: "2979FF"))
                }
            }
        }
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
            scoreCard(title: "Recovery",
                      value: viewModel.metrics.recoveryScore,
                      max: 100,
                      state: viewModel.metrics.recoveryState)
            scoreCard(title: "Strain",
                      value: viewModel.metrics.strainScore,
                      max: 100,
                      state: viewModel.metrics.strainState)
            scoreCard(title: "Sleep",
                      value: viewModel.metrics.sleepScore,
                      max: 100,
                      state: viewModel.metrics.sleepState)
            scoreCard(title: "Stress",
                      value: viewModel.metrics.stressScore,
                      max: 100,
                      state: viewModel.metrics.stressState)
        }
    }

    private func scoreCard(title: String, value: Double, max: Double, state: ColorState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(value.rounded()))")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("/\(Int(max))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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

    // MARK: - Sleep Section

    private var sleepSection: some View {
        detailCard(title: "Sleep Summary", icon: "moon.zzz.fill", iconColor: Color(hex: "2979FF")) {
            VStack(alignment: .leading, spacing: 10) {
                infoRow(label: "Duration", value: viewModel.sleepSummaryLine)
                if let interruptions = viewModel.sleepInterruptionLine {
                    infoRow(label: "Interruptions", value: interruptions)
                }
                if let sHRV = viewModel.metrics.sleepingHRV {
                    infoRow(label: "Sleeping HRV", value: String(format: "%.0f ms", sHRV))
                }
                if let sHR = viewModel.metrics.sleepingHR {
                    infoRow(label: "Sleeping HR", value: String(format: "%.0f bpm", sHR))
                }
            }
        }
    }

    // MARK: - Strain Section

    private var strainSection: some View {
        detailCard(title: "Strain Breakdown", icon: "flame.fill", iconColor: Color(hex: "FF9100")) {
            VStack(alignment: .leading, spacing: 10) {
                infoRow(label: "Total Strain",
                        value: String(format: "%.0f / 100", viewModel.metrics.strainScore))
                if viewModel.hasWorkoutBreakdown {
                    infoRow(label: "Workout Strain",  value: viewModel.workoutStrainText)
                    infoRow(label: "Incidental Strain", value: viewModel.incidentalStrainText)
                }
                if let cal = viewModel.metrics.activeCalories {
                    infoRow(label: "Active Calories", value: "\(Int(cal)) kcal")
                }
                if let steps = viewModel.metrics.stepCount {
                    let stepsStr = steps >= 1000
                        ? String(format: "%.1fk", steps / 1000)
                        : "\(Int(steps))"
                    infoRow(label: "Steps", value: stepsStr)
                }
            }
        }
    }

    // MARK: - Check-In Section

    private var checkInSection: some View {
        detailCard(title: "Yesterday's Check-In", icon: "checkmark.circle.fill", iconColor: Color(hex: "00C853")) {
            guard let ci = viewModel.checkIn else { return AnyView(EmptyView()) }
            return AnyView(
                VStack(alignment: .leading, spacing: 10) {
                    if ci.alcoholConsumed {
                        flagRow(label: "Alcohol", isOn: true, color: Color(hex: "FF1744"))
                    }
                    if ci.caffeineAfter5PM {
                        flagRow(label: "Late Caffeine", isOn: true, color: Color(hex: "FFD600"))
                    }
                    if ci.lateMealBeforeBed {
                        flagRow(label: "Late Meal", isOn: true, color: Color(hex: "FF9100"))
                    }
                    if ci.screenBeforeBed {
                        flagRow(label: "Screen Before Bed", isOn: true, color: Color(hex: "FF9100"))
                    }
                    if ci.meditated {
                        flagRow(label: "Meditated", isOn: true, color: Color(hex: "00C853"))
                    }
                    if ci.stretched {
                        flagRow(label: "Stretched", isOn: true, color: Color(hex: "00C853"))
                    }
                    infoRow(label: "Stress", value: viewModel.checkInStressLabel)
                }
            )
        }
    }

    // MARK: - Insight Section

    private var insightSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(Color(hex: "FFD600"))
                Text("Insight")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            Text(viewModel.coachingInsight)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "FFD600").opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color(hex: "FFD600").opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Reusable Components

    private func detailCard<C: View>(title: String, icon: String, iconColor: Color,
                                     @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            content()
        }
        .padding(14)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }

    private func flagRow(label: String, isOn: Bool, color: Color) -> some View {
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
}
