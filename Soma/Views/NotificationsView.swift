import SwiftUI

struct NotificationsView: View {

    @State private var groups: [(date: Date, records: [NotificationRecord])] = []

    var body: some View {
        NavigationStack {
            ZStack {
                SomaGradient.canvas(tint: .somaPurple)

                if groups.isEmpty {
                    emptyState
                } else {
                    notificationList
                }
            }
            .navigationTitle("Alerts")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear { groups = NotificationStore.shared.groupedByDate() }
    }

    // MARK: - List

    private var notificationList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(groups, id: \.date) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(sectionTitle(for: group.date))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.somaGray)
                            .textCase(.uppercase)

                        ForEach(group.records) { record in
                            notificationCard(record)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    private func notificationCard(_ record: NotificationRecord) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.somaBlue)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.somaBlue.opacity(0.16)))

            VStack(alignment: .leading, spacing: 4) {
                Text(record.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(record.body)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.somaTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(record.timestamp, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(Color.somaTextTertiary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accentCard(Color.somaBlue, cornerRadius: Radius.md, padding: 14)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 48))
                .foregroundColor(Color.somaGray)
            Text("No Notifications")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            Text("Notifications from the past 14 days will appear here.")
                .font(.subheadline)
                .foregroundColor(Color.somaGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Helpers

    private func sectionTitle(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

#if DEBUG
#Preview {
    NotificationsView()
}
#endif
