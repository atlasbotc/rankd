import Foundation
import SwiftData

/// Centralizes rank-shifting logic used when inserting or deleting ranked items.
struct RankingService {

    /// After deleting an item, shift all items with a higher rank down by 1.
    /// Call this **after** `modelContext.delete(item)` + save.
    ///
    /// - Parameters:
    ///   - deletedId: The UUID of the item that was deleted (to exclude from query results that may still include it).
    ///   - deletedRank: The rank the deleted item held.
    ///   - mediaType: The media type to scope the shift to.
    ///   - allItems: All ranked items (typically from `@Query`).
    ///   - context: The model context to save after shifting.
    static func shiftRanksAfterDeletion(
        excludingId deletedId: UUID,
        deletedRank: Int,
        mediaType: MediaType,
        in allItems: [RankedItem],
        context: ModelContext
    ) {
        let itemsToShift = allItems.filter {
            $0.id != deletedId && $0.mediaType == mediaType && $0.rank > deletedRank
        }
        for item in itemsToShift {
            item.rank -= 1
        }
        try? context.save()
    }

    /// Shift existing items down to make room, then set the new item's rank.
    ///
    /// - Parameters:
    ///   - rank: The desired rank for the new item.
    ///   - existingItems: Items already in the list (same media type, sorted by rank).
    ///   - context: The model context to save after shifting.
    static func insertAtRank(
        _ rank: Int,
        shifting existingItems: [RankedItem],
        context: ModelContext
    ) {
        for item in existingItems where item.rank >= rank {
            item.rank += 1
        }
        try? context.save()
    }
}
