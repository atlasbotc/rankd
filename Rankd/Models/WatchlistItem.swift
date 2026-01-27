import Foundation
import SwiftData

@Model
final class WatchlistItem {
    var id: UUID
    var tmdbId: Int
    var title: String
    var overview: String
    var posterPath: String?
    var releaseDate: String?
    var mediaType: MediaType
    var dateAdded: Date
    var notes: String?
    
    init(
        tmdbId: Int,
        title: String,
        overview: String = "",
        posterPath: String? = nil,
        releaseDate: String? = nil,
        mediaType: MediaType
    ) {
        self.id = UUID()
        self.tmdbId = tmdbId
        self.title = title
        self.overview = overview
        self.posterPath = posterPath
        self.releaseDate = releaseDate
        self.mediaType = mediaType
        self.dateAdded = Date()
        self.notes = nil
    }
    
    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "\(Config.tmdbImageBaseURL)/w500\(path)")
    }
    
    var year: String? {
        guard let date = releaseDate, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }
    
    /// Convert to a RankedItem when user has watched it
    func toRankedItem(tier: Tier) -> RankedItem {
        return RankedItem(
            tmdbId: tmdbId,
            title: title,
            overview: overview,
            posterPath: posterPath,
            releaseDate: releaseDate,
            mediaType: mediaType,
            tier: tier
        )
    }
}
