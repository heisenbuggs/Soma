import Foundation

// MARK: - InsightCache
//
// Persists computed insight results to UserDefaults so the app never
// recomputes them on every launch. Cache validity is checked against
// the date of the most-recent stored metrics and check-in.

final class InsightCache {

    static let shared = InsightCache()

    // MARK: - Storage Keys

    private let physioKey      = "cachedPhysioInsights_v2"
    private let behaviorKey    = "cachedBehaviorInsights_v2"
    private let physioMetaKey  = "physioInsightsCachedAt_v2"
    private let behaviorMetaKey = "behaviorInsightsCachedAt_v2"

    private let defaults = UserDefaults.standard
    private let calendar = Calendar.current

    private init() {}

    // MARK: - Physiological Insights

    func savePhysio(_ insights: [Insight]) {
        guard let data = try? JSONEncoder().encode(insights) else { return }
        defaults.set(data, forKey: physioKey)
        defaults.set(Date(), forKey: physioMetaKey)
    }

    func loadPhysio() -> [Insight]? {
        guard let data = defaults.data(forKey: physioKey) else { return nil }
        return try? JSONDecoder().decode([Insight].self, from: data)
    }

    var physioCachedAt: Date? {
        defaults.object(forKey: physioMetaKey) as? Date
    }

    /// Returns true when the physio cache should be regenerated.
    ///
    /// The cache is considered stale when:
    /// - No cache exists yet
    /// - The cache was built on a different calendar day
    /// - The most-recent stored metrics were saved after the cache was built
    func isPhysioStale(latestMetricsDate: Date?) -> Bool {
        guard let cachedAt = physioCachedAt else { return true }
        guard calendar.isDateInToday(cachedAt) else { return true }
        if let metricsDate = latestMetricsDate, metricsDate > cachedAt { return true }
        return false
    }

    // MARK: - Behavior Insights

    func saveBehavior(_ insights: [BehaviorInsight]) {
        guard let data = try? JSONEncoder().encode(insights) else { return }
        defaults.set(data, forKey: behaviorKey)
        defaults.set(Date(), forKey: behaviorMetaKey)
    }

    func loadBehavior() -> [BehaviorInsight]? {
        guard let data = defaults.data(forKey: behaviorKey) else { return nil }
        return try? JSONDecoder().decode([BehaviorInsight].self, from: data)
    }

    var behaviorCachedAt: Date? {
        defaults.object(forKey: behaviorMetaKey) as? Date
    }

    /// Returns true when the behavior cache should be regenerated.
    ///
    /// The cache is stale when:
    /// - No cache exists yet
    /// - A new check-in was submitted after the cache was built
    func isBehaviorStale(latestCheckInDate: Date?) -> Bool {
        guard let cachedAt = behaviorCachedAt else { return true }
        if let checkInDate = latestCheckInDate, checkInDate > cachedAt { return true }
        return false
    }

    // MARK: - Cache Invalidation

    /// Call this after saving new daily metrics so the physio cache is
    /// regenerated on the next `generateInsights()` call.
    func invalidatePhysio() {
        defaults.removeObject(forKey: physioMetaKey)
    }

    /// Call this after a new check-in is submitted.
    func invalidateBehavior() {
        defaults.removeObject(forKey: behaviorMetaKey)
    }

    /// Wipes all cached insight data (e.g. after a full data reset).
    func invalidateAll() {
        defaults.removeObject(forKey: physioKey)
        defaults.removeObject(forKey: behaviorKey)
        defaults.removeObject(forKey: physioMetaKey)
        defaults.removeObject(forKey: behaviorMetaKey)
    }
}
