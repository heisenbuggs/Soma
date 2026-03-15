import WidgetKit
import SwiftUI

// MARK: - Shared snapshot model (mirrors WidgetMetricsSnapshot in MetricsStore)

struct SomaWidgetMetrics: Codable {
    let recoveryScore: Double
    let strainScore: Double
    let sleepScore: Double
    let stressScore: Double
    let date: Date

    static let placeholder = SomaWidgetMetrics(
        recoveryScore: 74, strainScore: 12,
        sleepScore: 82, stressScore: 30,
        date: Date()
    )
}

// MARK: - Timeline Entry

struct SomaWidgetEntry: TimelineEntry {
    let date: Date
    let metrics: SomaWidgetMetrics?
}

// MARK: - Timeline Provider

struct SomaWidgetProvider: TimelineProvider {

    private let appGroupID = "group.com.soma.app"
    private let widgetKey  = "widgetMetrics"

    func placeholder(in context: Context) -> SomaWidgetEntry {
        SomaWidgetEntry(date: Date(), metrics: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SomaWidgetEntry) -> Void) {
        completion(SomaWidgetEntry(date: Date(), metrics: loadMetrics()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SomaWidgetEntry>) -> Void) {
        let entry = SomaWidgetEntry(date: Date(), metrics: loadMetrics())
        // Refresh next morning at 8 AM
        let nextUpdate = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: 8, minute: 0),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(3600 * 8)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadMetrics() -> SomaWidgetMetrics? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: widgetKey),
              let metrics = try? JSONDecoder().decode(SomaWidgetMetrics.self, from: data)
        else { return nil }
        return metrics
    }
}

// MARK: - Widget

struct SomaWidget: Widget {
    let kind = "SomaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SomaWidgetProvider()) { entry in
            SomaWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Soma Scores")
        .description("Today's Recovery, Strain, Sleep, and Stress at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Bundle

@main
struct SomaWidgetBundle: WidgetBundle {
    var body: some Widget {
        SomaWidget()
    }
}
