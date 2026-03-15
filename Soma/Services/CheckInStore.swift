import Foundation

final class CheckInStore: ObservableObject {
    private let key = "dailyCheckIns"
    private let calendar = Calendar.current

    @Published var todayCheckIn: DailyCheckIn?
    @Published var allCheckIns: [DailyCheckIn] = []

    init() {
        allCheckIns = loadAll()
        todayCheckIn = load(for: Date())
    }

    // MARK: - Save

    func save(_ checkIn: DailyCheckIn) {
        var all = loadAll()
        if let idx = all.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: checkIn.date) }) {
            all[idx] = checkIn
        } else {
            all.append(checkIn)
        }
        all.sort { $0.date < $1.date }
        persist(all)
        allCheckIns = all
        if calendar.isDateInToday(checkIn.date) {
            todayCheckIn = checkIn
        }
    }

    // MARK: - Load

    func load(for date: Date) -> DailyCheckIn? {
        loadAll().first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func loadAll() -> [DailyCheckIn] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([DailyCheckIn].self, from: data)
        else { return [] }
        return decoded.sorted { $0.date < $1.date }
    }

    func hasCompletedToday() -> Bool {
        todayCheckIn != nil
    }

    // MARK: - Delete

    func deleteAll() {
        UserDefaults.standard.removeObject(forKey: key)
        allCheckIns = []
        todayCheckIn = nil
    }

    // MARK: - Private

    private func persist(_ checkIns: [DailyCheckIn]) {
        if let data = try? JSONEncoder().encode(checkIns) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
