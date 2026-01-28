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
    @discardableResult
    func backfillMissingData(items: [RankedItem], modelContext: ModelContext) async -> Int {
        guard !isRunning else { return 0 }
        isRunning = true
        defer { isRunning = false }
        
        let itemsNeedingBackfill = items.filter { $0.genreNames.isEmpty }
        var updatedCount = 0
        
        for item in itemsNeedingBackfill {
            do {
                if item.mediaType == .movie {
                    if let details = try? await TMDBService.shared.getMovieDetails(id: item.tmdbId) {
                        await MainActor.run {
                            item.genreIds = details.genres.map { $0.id }
                            item.genreNames = details.genres.map { $0.name }
                            item.runtimeMinutes = details.runtime ?? 0
                        }
                        updatedCount += 1
                    }
                } else {
                    if let details = try? await TMDBService.shared.getTVDetails(id: item.tmdbId) {
                        await MainActor.run {
                            item.genreIds = details.genres.map { $0.id }
                            item.genreNames = details.genres.map { $0.name }
                            item.runtimeMinutes = details.episodeRunTime?.first ?? 0
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
                try? modelContext.save()
            }
        }
        
        return updatedCount
    }
}
