import SwiftUI

/// A paged sheet wrapping DayDetailView so the user can swipe between days.
struct DayDetailPageView: View {
    let allMetrics: [DailyMetrics]
    let checkInStore: CheckInStore
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex: Int

    private var sorted: [DailyMetrics] {
        allMetrics.sorted { $0.date < $1.date }
    }

    init(allMetrics: [DailyMetrics], initial: DailyMetrics, checkInStore: CheckInStore) {
        self.allMetrics = allMetrics
        self.checkInStore = checkInStore
        let sorted = allMetrics.sorted { $0.date < $1.date }
        let idx = sorted.firstIndex { Calendar.current.isDate($0.date, inSameDayAs: initial.date) } ?? 0
        _currentIndex = State(initialValue: idx)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.somaBackground.ignoresSafeArea()

                if sorted.isEmpty {
                    Text("No data available")
                        .foregroundColor(.secondary)
                } else {
                    TabView(selection: $currentIndex) {
                        ForEach(sorted.indices, id: \.self) { idx in
                            DayDetailView(metrics: sorted[idx], checkInStore: checkInStore)
                                .tag(idx)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle(pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 16) {
                        Button {
                            guard currentIndex > 0 else { return }
                            withAnimation { currentIndex -= 1 }
                        } label: {
                            Image(systemName: "chevron.left")
                                .foregroundColor(currentIndex > 0 ? Color(hex: "2979FF") : Color(hex: "8E8E93"))
                        }
                        .disabled(currentIndex == 0)

                        Button {
                            guard currentIndex < sorted.count - 1 else { return }
                            withAnimation { currentIndex += 1 }
                        } label: {
                            Image(systemName: "chevron.right")
                                .foregroundColor(currentIndex < sorted.count - 1 ? Color(hex: "2979FF") : Color(hex: "8E8E93"))
                        }
                        .disabled(currentIndex >= sorted.count - 1)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(hex: "2979FF"))
                }
            }
        }
    }

    private var pageTitle: String {
        guard sorted.indices.contains(currentIndex) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: sorted[currentIndex].date)
    }
}
