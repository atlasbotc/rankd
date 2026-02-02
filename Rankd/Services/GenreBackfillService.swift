import Foundation
import SwiftData

/// Service to backfill genre and runtime data for ranked items missing that metadata.
/// Rate-limited to avoid hammering the TMDB API.
actor GenreBackfillService {
    static let shared = GenreBackfillService()
    
    private var isRunning = false
    private let delayBetweenRequests: UInt64 = 300_000_000 // 300ms
    
    private init() {}
    
    /// Backfills genre and runtime data for items that are missing it.
    /// Processes items one at a time with a delay between requests.
    /// Returns the number of items updated.
    ///
    /// Accepts `PersistentIdentifier`s to avoid passing SwiftData model objects
    /// across actor isolation boundaries. Items are re-fetched on the MainActor.
    @discardableResult
    func backfillMissingData(itemIDs: [PersistentIdentifier], modelContext: ModelContext) async -> Int {
        guard !isRunning else { return 0 }
        isRunning = true
        defer { isRunning = false }
        
        // Re-fetch items on MainActor and collect those needing backfill
        let workItems: [(PersistentIdentifier, Int, MediaType)] = await MainActor.run {
            itemIDs.compactMap { id in
                guard let item = modelContext.model(for: id) as? RankedItem,
                      item.genreNames.isEmpty else { return nil }
                return (id, item.tmdbId, item.mediaType)
            }
        }
        
        var updatedCount = 0
        
        for (itemID, tmdbId, mediaType) in workItems {
            do {
                if mediaType == .movie {
                    if let details = try? await TMDBService.shared.getMovieDetails(id: tmdbId) {
                        await MainActor.run {
                            if let item = modelContext.model(for: itemID) as? RankedItem {
                                item.genreIds = details.genres.map { $0.id }
                                item.genreNames = details.genres.map { $0.name }
                                item.runtimeMinutes = details.runtime ?? 0
                            }
                        }
                        updatedCount += 1
                    }
                } else {
                    if let details = try? await TMDBService.shared.getTVDetails(id: tmdbId) {
                        await MainActor.run {
                            if let item = modelContext.model(for: itemID) as? RankedItem {
                                item.genreIds = details.genres.map { $0.id }
                                item.genreNames = details.genres.map { $0.name }
                                item.runtimeMinutes = details.episodeRunTime?.first ?? 0
                            }
                        }
                        updatedCount += 1
                    }
                }
                
                // Rate limit
                try await Task.sleep(nanoseconds: delayBetweenRequests)
            } catch {
                // If we hit an error (e.g., rate limit), stop early
                break
            }
        }
        
        // Save all changes at once
        if updatedCount > 0 {
            await MainActor.run {
                modelContext.safeSave()
            }
        }
        
        return updatedCount
    }
}
