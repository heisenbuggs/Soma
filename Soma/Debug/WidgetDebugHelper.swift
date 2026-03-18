import Foundation
import WidgetKit

// MARK: - Widget Debug Helper

struct WidgetDebugHelper {
    
    /// Call this from your main app to verify widget data is being written
    static func debugWidgetSnapshot() {
        let store = MetricsStore()
        
        // Check if we have today's metrics
        if let todayMetrics = store.load(for: Date()) {
            print("✅ Widget Debug: Today's metrics found")
            print("   Recovery: \(todayMetrics.recoveryScore)")
            print("   Strain: \(todayMetrics.strainScore)")
            print("   Sleep: \(todayMetrics.sleepScore)")
            print("   Stress: \(todayMetrics.stressScore)")
        } else {
            print("❌ Widget Debug: No metrics found for today")
        }
        
        // Check App Group access
        if let groupDefaults = UserDefaults(suiteName: "group.com.prasjain.Soma") {
            print("✅ Widget Debug: App Group accessible")
            
            // Check if widget snapshot exists
            if let data = groupDefaults.data(forKey: "WidgetMetricsSnapshot") {
                print("✅ Widget Debug: Widget snapshot data found (\(data.count) bytes)")
                
                // Try to decode it
                if let snapshot = try? JSONDecoder().decode(WidgetMetricsSnapshot.self, from: data) {
                    print("✅ Widget Debug: Snapshot decoded successfully")
                    print("   Recovery: \(snapshot.recoveryScore)")
                    print("   Date: \(snapshot.date)")
                } else {
                    print("❌ Widget Debug: Failed to decode snapshot")
                }
            } else {
                print("❌ Widget Debug: No widget snapshot data found")
                
                // Create test snapshot
                let testSnapshot = WidgetMetricsSnapshot(
                    recoveryScore: 75,
                    strainScore: 40,
                    sleepScore: 80,
                    stressScore: 25,
                    date: Date()
                )
                
                if let encoded = try? JSONEncoder().encode(testSnapshot) {
                    groupDefaults.set(encoded, forKey: "WidgetMetricsSnapshot")
                    print("✅ Widget Debug: Created test snapshot")
                    
                    // Reload widget timelines
                    WidgetCenter.shared.reloadAllTimelines()
                    print("✅ Widget Debug: Reloaded widget timelines")
                }
            }
        } else {
            print("❌ Widget Debug: Cannot access App Group - check entitlements")
        }
    }
    
    /// Call this to force widget refresh
    static func forceWidgetRefresh() {
        WidgetCenter.shared.reloadAllTimelines()
        print("✅ Widget Debug: Forced widget timeline reload")
    }
    
    /// Call this to get widget info
    static func getWidgetInfo(completion: @escaping ([String]) -> Void) {
        WidgetCenter.shared.getCurrentConfigurations { result in
            switch result {
            case .success(let configurations):
                let info = configurations.map { config in
                    "Widget: \(config.kind), Family: \(config.family.description)"
                }
                print("✅ Widget Debug: Found \(configurations.count) widget configurations")
                completion(info)
                
            case .failure(let error):
                print("❌ Widget Debug: Failed to get configurations: \(error)")
                completion(["Error: \(error.localizedDescription)"])
            }
        }
    }
}

// MARK: - WidgetFamily Extension

extension WidgetFamily {
    var description: String {
        switch self {
        case .systemSmall: return "Small"
        case .systemMedium: return "Medium"
        case .systemLarge: return "Large"
        case .accessoryCircular: return "Lock Circular"
        case .accessoryRectangular: return "Lock Rectangular"
        case .accessoryInline: return "Lock Inline"
        default: return "Unknown"
        }
    }
}

#if DEBUG
// MARK: - Debug Menu Extension

extension WidgetDebugHelper {
    
    /// Add this to your debug menu or settings
    static func runAllDebugChecks() {
        print("\n🔍 Running Widget Debug Checks...")
        print("=====================================")
        
        debugWidgetSnapshot()
        
        getWidgetInfo { configurations in
            for config in configurations {
                print("📱 \(config)")
            }
            
            if configurations.isEmpty {
                print("❌ No widgets currently configured")
                print("💡 Try adding widgets manually: Long press home screen → + → search 'Soma'")
            }
        }
        
        print("=====================================\n")
    }
}
#endif