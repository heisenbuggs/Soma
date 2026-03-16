import Foundation

// MARK: - NotificationRecord

struct NotificationRecord: Codable, Identifiable {
    let id: UUID
    let title: String
    let body: String
    let timestamp: Date

    init(id: UUID = UUID(), title: String, body: String, timestamp: Date = Date()) {
        self.id = id
        self.title = title
        self.body = body
        self.timestamp = timestamp
    }
}

// MARK: - NotificationStore

final class NotificationStore {

    static let shared = NotificationStore()

    private let key = "storedNotificationHistory"
    private let retentionDays = 14
    private let calendar = Calendar.current

    private init() {}

    // MARK: - Save

    func save(_ record: NotificationRecord) {
        var all = loadAll()
        // Replace any existing record for the same calendar day so repeated
        // app refreshes don't accumulate duplicates in the history.
        let recordDay = calendar.startOfDay(for: record.timestamp)
        all.removeAll { calendar.startOfDay(for: $0.timestamp) == recordDay }
        all.append(record)
        persist(purged(all))
    }

    // MARK: - Load

    func loadAll() -> [NotificationRecord] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([NotificationRecord].self, from: data)
        else { return [] }
        return purged(decoded)
    }

    /// Returns notifications grouped by calendar day, newest day first.
    func groupedByDate() -> [(date: Date, records: [NotificationRecord])] {
        let all = loadAll().sorted { $0.timestamp > $1.timestamp }
        var groups: [Date: [NotificationRecord]] = [:]
        for record in all {
            let day = calendar.startOfDay(for: record.timestamp)
            groups[day, default: []].append(record)
        }
        return groups.sorted { $0.key > $1.key }.map { (date: $0.key, records: $0.value) }
    }

    // MARK: - Private

    private func purged(_ records: [NotificationRecord]) -> [NotificationRecord] {
        let cutoff = calendar.date(byAdding: .day, value: -retentionDays, to: Date())!
        return records.filter { $0.timestamp >= cutoff }
    }

    private func persist(_ records: [NotificationRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
