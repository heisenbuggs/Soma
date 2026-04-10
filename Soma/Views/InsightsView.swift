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

    // MARK: - Insights List

    private var insightsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Physiological insights — split by priority
                let high   = viewModel.insights.filter { $0.priority == .high }
                let medium = viewModel.insights.filter { $0.priority == .medium }
                let low    = viewModel.insights.filter { $0.priority == .low }

                if !high.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("Needs Attention", count: high.count, color: Color.somaRed)
                        ForEach(high) { insightCard($0) }
                    }
                }

                if !medium.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("Watch Today", count: medium.count, color: Color.somaYellow)
                        ForEach(medium) { insightCard($0) }
                    }
                }

                if !low.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("Looking Good", count: low.count, color: Color.somaGreen)
                        ForEach(low) { insightCard($0) }
                    }
                }

                // Behavioral intelligence
                if !viewModel.behaviorInsights.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("Your Patterns", count: viewModel.behaviorInsights.prefix(6).count, color: Color.somaPurple)
                        ForEach(viewModel.behaviorInsights.prefix(6)) { behaviorInsightCard($0) }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, count: Int? = nil, color: Color = Color.somaGray) -> some View {
        HStack(spacing: 8) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
                .tracking(0.5)
            if let count {
                Text("\(count)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Physiological Insight Card

    private func insightCard(_ insight: Insight) -> some View {
        let accent = priorityColor(insight.priority)
        return HStack(spacing: 0) {
            Rectangle()
                .fill(accent)
                .frame(width: 4)

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: insight.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(insight.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(insight.date, format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Text(insight.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(accent.opacity(insight.priority == .high ? 0.3 : 0), lineWidth: 1)
        )
    }

    // MARK: - Behavior Insight Card

    private func behaviorInsightCard(_ insight: BehaviorInsight) -> some View {
        let accent: Color = insight.isNegativeImpact ? Color.somaRed : Color.somaGreen
        return HStack(spacing: 0) {
            Rectangle()
                .fill(accent)
                .frame(width: 4)

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: insight.isNegativeImpact ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(insight.behaviorName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(insight.occurrences) observations")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Text(insight.impactDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.somaGreen.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: "sparkles")
                    .font(.system(size: 44))
                    .foregroundColor(Color.somaGreen)
            }
            VStack(spacing: 8) {
                Text("All Clear")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("No notable insights for today.\nYour metrics are in good shape.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Helpers

    private func priorityColor(_ priority: InsightPriority) -> Color {
        switch priority {
        case .high:   return Color.somaRed
        case .medium: return Color.somaYellow
        case .low:    return Color.somaGreen
        }
    }
}
