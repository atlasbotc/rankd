import Foundation
import SwiftData

/// Logs user activities for the activity feed.
/// Call these methods from existing save flows to automatically track actions.
struct ActivityLogger {
    
    /// Log that the user ranked an item
    static func logRanked(
        item: RankedItem,
        score: Double,
        context: ModelContext
    ) {
        let metadata = encodeMetadata([
            "score": String(format: "%.1f", score),
            "tier": item.tier.rawValue
        ])
        
        let activity = Activity(
            userId: currentUserId(context: context),
            activityType: .ranked,
            mediaTitle: item.title,
            mediaTMDBId: item.tmdbId,
            mediaType: item.mediaType,
            metadata: metadata
        )
        context.insert(activity)
    }
    
    /// Log that the user re-ranked an item (e.g. after comparison)
    static func logReRanked(
        item: RankedItem,
        newScore: Double,
        context: ModelContext
    ) {
        let metadata = encodeMetadata([
            "score": String(format: "%.1f", newScore),
            "tier": item.tier.rawValue
        ])
        
        let activity = Activity(
            userId: currentUserId(context: context),
            activityType: .reRanked,
            mediaTitle: item.title,
            mediaTMDBId: item.tmdbId,
            mediaType: item.mediaType,
            metadata: metadata
        )
        context.insert(activity)
    }
    
    /// Log that the user added an item to their watchlist
    static func logAddedToWatchlist(
        item: WatchlistItem,
        context: ModelContext
    ) {
        let activity = Activity(
            userId: currentUserId(context: context),
            activityType: .addedToWatchlist,
            mediaTitle: item.title,
            mediaTMDBId: item.tmdbId,
            mediaType: item.mediaType
        )
        context.insert(activity)
    }
    
    /// Log that the user created a new list
    static func logCreatedList(
        list: CustomList,
        context: ModelContext
    ) {
        let metadata = encodeMetadata([
            "listName": list.name,
            "emoji": list.emoji
        ])
        
        let activity = Activity(
            userId: currentUserId(context: context),
            activityType: .createdList,
            mediaTitle: "",
            mediaTMDBId: 0,
            mediaType: .movie, // placeholder for non-media activities
            metadata: metadata
        )
        context.insert(activity)
    }
    
    /// Log that the user added an item to a list
    static func logAddedToList(
        item: CustomListItem,
        list: CustomList,
        context: ModelContext
    ) {
        let metadata = encodeMetadata([
            "listName": list.name,
            "listEmoji": list.emoji
        ])
        
        let activity = Activity(
            userId: currentUserId(context: context),
            activityType: .addedToList,
            mediaTitle: item.title,
            mediaTMDBId: item.tmdbId,
            mediaType: item.mediaType,
            metadata: metadata
        )
        context.insert(activity)
    }
    
    // MARK: - Helpers
    
    /// Get the current user's ID, or a default UUID for local-only mode
    private static func currentUserId(context: ModelContext) -> UUID {
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.isCurrentUser == true }
        )
        if let profile = try? context.fetch(descriptor).first {
            return profile.id
        }
        // Default local user ID when no profile exists yet
        return UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    }
    
    private static func encodeMetadata(_ dict: [String: String]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8)
        else { return nil }
        return str
    }
}
