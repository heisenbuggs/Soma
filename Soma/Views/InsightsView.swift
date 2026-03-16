import SwiftUI

struct InsightsView: View {
    @ObservedObject var viewModel: InsightsViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color.somaBackground.ignoresSafeArea()

                if viewModel.insights.isEmpty && viewModel.behaviorInsights.isEmpty {
                    emptyState
                } else {
                    insightsList
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear { viewModel.generateInsights() }
    }

    private var insightsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Daily Training Guidance
                if let guidance = viewModel.trainingGuidance {
                    sectionHeader("Daily Guidance")
                    guidanceCard(guidance)
                }

                // Physiological insights
                if !viewModel.insights.isEmpty {
                    sectionHeader("Today")
                    ForEach(viewModel.insights) { insight in
                        insightCard(insight)
                    }
                }

                // Behavioral intelligence insights
                if !viewModel.behaviorInsights.isEmpty {
                    sectionHeader("Your Patterns")
                    ForEach(viewModel.behaviorInsights.prefix(6)) { insight in
                        behaviorInsightCard(insight)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(Color(hex: "8E8E93"))
            .padding(.top, 4)
    }

    private func behaviorInsightCard(_ insight: BehaviorInsight) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(insight.isNegativeImpact ? Color(hex: "FF1744") : Color(hex: "00C853"))
                .frame(width: 4)
                .padding(.vertical, 8)

            HStack(spacing: 12) {
                Image(systemName: insight.isNegativeImpact ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundColor(insight.isNegativeImpact ? Color(hex: "FF1744") : Color(hex: "00C853"))
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.behaviorName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(insight.impactDescription)
                        .font(.caption)
                        .foregroundColor(Color(hex: "8E8E93"))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Based on \(insight.occurrences) observations")
                        .font(.caption2)
                        .foregroundColor(Color(hex: "8E8E93").opacity(0.7))
                }
                Spacer()
            }
            .padding(12)
        }
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func insightCard(_ insight: Insight) -> some View {
        HStack(spacing: 0) {
            // Priority indicator bar
            RoundedRectangle(cornerRadius: 3)
                .fill(priorityColor(insight.priority))
                .frame(width: 4)
                .padding(.vertical, 8)

            HStack(spacing: 12) {
                Image(systemName: insight.icon)
                    .font(.title2)
                    .foregroundColor(priorityColor(insight.priority))
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(insight.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(insight.date, format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                            .foregroundColor(Color(hex: "8E8E93"))
                    }
                    Text(insight.description)
                        .font(.caption)
                        .foregroundColor(Color(hex: "8E8E93"))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
        }
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func guidanceCard(_ guidance: DailyTrainingGuidance) -> some View {
        let accent = Color(hex: guidance.activityLevel.colorHex)
        return VStack(alignment: .leading, spacing: 12) {
            // Level + readiness
            HStack(spacing: 10) {
                Image(systemName: guidance.activityLevel.icon)
                    .font(.title3)
                    .foregroundColor(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(guidance.activityLevel.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(accent)
                    Text("Strain target: \(guidance.targetStrainMin)–\(guidance.targetStrainMax)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Readiness")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(Int(guidance.readinessScore.rounded()))")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(accent)
                }
            }

            // Suggested workouts
            if !guidance.suggestedWorkouts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(guidance.suggestedWorkouts, id: \.self) { workout in
                            Text(workout)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(accent.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // Explanation
            if !guidance.explanation.isEmpty {
                Text(guidance.explanation)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Fatigue flags
            if !guidance.fatigueFlags.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(Color(hex: "FFD600"))
                    Text(guidance.fatigueFlags.joined(separator: " · "))
                        .font(.caption2)
                        .foregroundColor(Color(hex: "FFD600"))
                }
            }
        }
        .padding(14)
        .background(accent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(accent.opacity(0.25), lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "00C853"))
            Text("All Looking Good")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            Text("No notable insights for today. Keep up the great work!")
                .font(.subheadline)
                .foregroundColor(Color(hex: "8E8E93"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func priorityColor(_ priority: InsightPriority) -> Color {
        switch priority {
        case .high:   return Color(hex: "FF1744")
        case .medium: return Color(hex: "FFD600")
        case .low:    return Color(hex: "00C853")
        }
    }
}
