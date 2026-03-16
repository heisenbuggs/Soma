import SwiftUI

struct NotificationsView: View {

    @State private var groups: [(date: Date, records: [NotificationRecord])] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color.somaBackground.ignoresSafeArea()

                if groups.isEmpty {
                    emptyState
                } else {
                    notificationList
                }
            }
            .navigationTitle("Notifications")
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
                            .foregroundColor(Color(hex: "8E8E93"))
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
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: "2979FF"))
                .frame(width: 4)
                .padding(.vertical, 8)

            HStack(spacing: 12) {
                Image(systemName: "bell.fill")
                    .font(.title3)
                    .foregroundColor(Color(hex: "2979FF"))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(record.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(record.body)
                        .font(.caption)
                        .foregroundColor(Color(hex: "8E8E93"))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(record.timestamp, format: .dateTime.hour().minute())
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

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "8E8E93"))
            Text("No Notifications")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            Text("Notifications from the past 14 days will appear here.")
                .font(.subheadline)
                .foregroundColor(Color(hex: "8E8E93"))
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
