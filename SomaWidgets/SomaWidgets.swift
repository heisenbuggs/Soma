//
//  SomaWidgets.swift
//  SomaWidgets
//
//  Created by Prasuk Jain on 17/03/2026.
//

import WidgetKit
import SwiftUI

// MARK: - Widget snapshot (mirrored from Soma app)
struct WidgetMetricsSnapshot: Codable {
    let recoveryScore: Double
    let strainScore: Double
    let sleepScore: Double
    let stressScore: Double
    let date: Date
}

// MARK: - ColorState (mirrored from Soma app)
enum ColorState {
    case green(label: String)
    case lightGreen(label: String)
    case yellow(label: String)
    case red(label: String)
    case blue(label: String)
    case orange(label: String)
    case gray(label: String)

    var color: Color {
        switch self {
        case .green:      return Color(hex: "00C853")
        case .lightGreen: return Color(hex: "69F0AE")
        case .yellow:     return Color(hex: "FFD600")
        case .red:        return Color(hex: "FF1744")
        case .blue:       return Color(hex: "2979FF")
        case .orange:     return Color(hex: "FF9100")
        case .gray:       return Color(hex: "8E8E93")
        }
    }

    var label: String {
        switch self {
        case .green(let l), .lightGreen(let l), .yellow(let l),
             .red(let l), .blue(let l), .orange(let l), .gray(let l):
            return l
        }
    }

    static func recovery(score: Double) -> ColorState {
        switch score {
        case 85...100: return .green(label: "Excellent")
        case 70..<85:  return .lightGreen(label: "Good")
        case 50..<70:  return .yellow(label: "Moderate")
        case 30..<50:  return .orange(label: "Low")
        default:       return .red(label: "Very Low")
        }
    }

    static func strain(score: Double) -> ColorState {
        switch score {
        case 80...100: return .red(label: "Very High")
        case 60..<80:  return .orange(label: "High")
        case 40..<60:  return .yellow(label: "Moderate")
        case 20..<40:  return .lightGreen(label: "Light")
        default:       return .green(label: "Minimal")
        }
    }

    static func sleep(score: Double) -> ColorState {
        switch score {
        case 90...100: return .green(label: "Excellent")
        case 75..<90:  return .lightGreen(label: "Good")
        case 60..<75:  return .yellow(label: "Fair")
        case 40..<60:  return .orange(label: "Poor")
        default:       return .red(label: "Very Poor")
        }
    }

    static func stress(score: Double) -> ColorState {
        switch score {
        case 0...30:  return .green(label: "Low")
        case 31...60: return .yellow(label: "Moderate")
        default:      return .red(label: "High")
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255,
                            (int >> 8) * 17,
                            (int >> 4 & 0xF) * 17,
                            (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255,
                            int >> 16,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24,
                            int >> 16 & 0xFF,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Timeline Provider
struct SomaProvider: AppIntentTimelineProvider {
    private let appGroupID = "group.com.prasjain.Soma"
    private let widgetKey = "WidgetMetricsSnapshot"
    
    private var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
    
    private func loadWidgetSnapshot() -> WidgetMetricsSnapshot? {
        guard let data = defaults.data(forKey: widgetKey),
              let snapshot = try? JSONDecoder().decode(WidgetMetricsSnapshot.self, from: data)
        else { return nil }
        return snapshot
    }
    
    func placeholder(in context: Context) -> SomaEntry {
        SomaEntry(
            date: Date(),
            configuration: ConfigurationAppIntent(),
            metrics: WidgetMetricsSnapshot(
                recoveryScore: 75,
                strainScore: 45,
                sleepScore: 82,
                stressScore: 25,
                date: Date()
            )
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SomaEntry {
        let metrics = loadWidgetSnapshot() ?? WidgetMetricsSnapshot(
            recoveryScore: 75,
            strainScore: 45,
            sleepScore: 82,
            stressScore: 25,
            date: Date()
        )
        
        return SomaEntry(
            date: Date(),
            configuration: configuration,
            metrics: metrics
        )
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SomaEntry> {
        let metrics = loadWidgetSnapshot()
        
        let entry = SomaEntry(
            date: Date(),
            configuration: configuration,
            metrics: metrics
        )
        
        // Refresh every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

// MARK: - Timeline Entry
struct SomaEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let metrics: WidgetMetricsSnapshot?
}

// MARK: - Widget Views
struct SomaWidgetEntryView: View {
    var entry: SomaEntry
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        Group {
            if let metrics = entry.metrics {
                switch widgetFamily {
                case .systemSmall:
                    SmallWidgetView(metrics: metrics)
                case .systemMedium:
                    MediumWidgetView(metrics: metrics)
                case .systemLarge:
                    LargeWidgetView(metrics: metrics)
                default:
                    SmallWidgetView(metrics: metrics)
                }
            } else {
                NoDataView()
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Small Widget (2x2)
struct SmallWidgetView: View {
    let metrics: WidgetMetricsSnapshot
    
    var recoveryState: ColorState {
        ColorState.recovery(score: metrics.recoveryScore)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Recovery")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            HStack {
                Text("\(Int(metrics.recoveryScore))")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(recoveryState.color)
                Spacer()
            }
            
            HStack {
                Text(recoveryState.label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            Spacer()
            
            // Other metrics summary
            HStack(spacing: 8) {
                MetricDot(score: metrics.strainScore, color: ColorState.strain(score: metrics.strainScore).color)
                MetricDot(score: metrics.sleepScore, color: ColorState.sleep(score: metrics.sleepScore).color)
                MetricDot(score: metrics.stressScore, color: ColorState.stress(score: metrics.stressScore).color)
                Spacer()
            }
        }
        .padding(12)
    }
}

// MARK: - Medium Widget (4x2)
struct MediumWidgetView: View {
    let metrics: WidgetMetricsSnapshot
    
    var body: some View {
        HStack(spacing: 12) {
            MetricCard(
                title: "Recovery",
                score: metrics.recoveryScore,
                colorState: ColorState.recovery(score: metrics.recoveryScore)
            )
            
            MetricCard(
                title: "Strain",
                score: metrics.strainScore,
                colorState: ColorState.strain(score: metrics.strainScore)
            )
            
            MetricCard(
                title: "Sleep",
                score: metrics.sleepScore,
                colorState: ColorState.sleep(score: metrics.sleepScore)
            )
            
            MetricCard(
                title: "Stress",
                score: metrics.stressScore,
                colorState: ColorState.stress(score: metrics.stressScore)
            )
        }
        .padding(12)
    }
}

// MARK: - Large Widget (4x4)
struct LargeWidgetView: View {
    let metrics: WidgetMetricsSnapshot
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Soma")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Text(metrics.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                MetricCard(
                    title: "Recovery",
                    score: metrics.recoveryScore,
                    colorState: ColorState.recovery(score: metrics.recoveryScore),
                    showLabel: true
                )
                
                MetricCard(
                    title: "Strain",
                    score: metrics.strainScore,
                    colorState: ColorState.strain(score: metrics.strainScore),
                    showLabel: true
                )
            }
            
            HStack(spacing: 12) {
                MetricCard(
                    title: "Sleep",
                    score: metrics.sleepScore,
                    colorState: ColorState.sleep(score: metrics.sleepScore),
                    showLabel: true
                )
                
                MetricCard(
                    title: "Stress",
                    score: metrics.stressScore,
                    colorState: ColorState.stress(score: metrics.stressScore),
                    showLabel: true
                )
            }
        }
        .padding(16)
    }
}

// MARK: - Helper Views
struct MetricCard: View {
    let title: String
    let score: Double
    let colorState: ColorState
    let showLabel: Bool
    
    init(title: String, score: Double, colorState: ColorState, showLabel: Bool = false) {
        self.title = title
        self.score = score
        self.colorState = colorState
        self.showLabel = showLabel
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("\(Int(score))")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(colorState.color)
            
            if showLabel {
                Text(colorState.label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct MetricDot: View {
    let score: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(Int(score))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct NoDataView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Soma")
                .font(.title3)
                .fontWeight(.medium)
            Text("Open app to sync")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Widget
struct SomaWidgets: Widget {
    let kind: String = "SomaWidgets"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: SomaProvider()) { entry in
            SomaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Soma Metrics")
        .description("View your recovery, strain, sleep, and stress scores at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Previews
#Preview(as: .systemSmall) {
    SomaWidgets()
} timeline: {
    SomaEntry(
        date: .now,
        configuration: ConfigurationAppIntent(),
        metrics: WidgetMetricsSnapshot(
            recoveryScore: 85,
            strainScore: 45,
            sleepScore: 78,
            stressScore: 32,
            date: .now
        )
    )
}

#Preview(as: .systemMedium) {
    SomaWidgets()
} timeline: {
    SomaEntry(
        date: .now,
        configuration: ConfigurationAppIntent(),
        metrics: WidgetMetricsSnapshot(
            recoveryScore: 72,
            strainScore: 60,
            sleepScore: 85,
            stressScore: 25,
            date: .now
        )
    )
}
