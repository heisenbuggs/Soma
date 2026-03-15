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
                    Text(insight.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(insight.description)
                        .font(.caption)
                        .foregroundColor(Color(hex: "8E8E93"))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(12)
        }
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
