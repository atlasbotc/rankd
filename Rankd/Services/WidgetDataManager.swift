import Foundation
import WidgetKit

/// Manages shared data between the main app and widget extension via App Groups.
/// Widget runs in a separate process — this bridges the gap using UserDefaults.
enum WidgetDataManager {
    
    static let suiteName = "group.com.rankd.shared"
    static let topItemsKey = "widget_top_items"
    
    /// Lightweight struct for widget display — no SwiftData dependency.
    struct WidgetItem: Codable, Identifiable {
        let id: String       // UUID string
        let title: String
        let score: Double
        let tier: String     // "Good", "Medium", "Bad"
        let posterURL: String?
        let rank: Int
    }
    
    /// Update shared UserDefaults with top ranked items.
    /// Call this whenever rankings change (after save in ComparisonFlowView, etc.)
    static func updateSharedData(items: [WidgetItem]) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(items) {
            defaults.set(data, forKey: topItemsKey)
        }
        
        // Tell WidgetKit to refresh
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// Read top items from shared UserDefaults (used by widget).
    static func loadSharedData() -> [WidgetItem] {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: topItemsKey) else {
            return []
        }
        
        let decoder = JSONDecoder()
        return (try? decoder.decode([WidgetItem].self, from: data)) ?? []
    }
}
