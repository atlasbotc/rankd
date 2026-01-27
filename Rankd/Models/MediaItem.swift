import Foundation
import SwiftData

enum MediaType: String, Codable {
    case movie
    case tvShow
}

enum Tier: String, Codable, CaseIterable {
    case good = "Good"
    case medium = "Medium"
    case bad = "Bad"
    
    var color: String {
        switch self {
        case .good: return "green"
        case .medium: return "yellow"
        case .bad: return "red"
        }
    }
}

@Model
final class MediaItem {
    var id: UUID
    var tmdbId: Int
    var title: String
    var posterPath: String?
    var overview: String
    var mediaType: MediaType
    var tier: Tier
    var rank: Int // Lower = better within tier
    var addedAt: Date
    
    init(tmdbId: Int, title: String, posterPath: String?, overview: String, mediaType: MediaType, tier: Tier) {
        self.id = UUID()
        self.tmdbId = tmdbId
        self.title = title
        self.posterPath = posterPath
        self.overview = overview
        self.mediaType = mediaType
        self.tier = tier
        self.rank = 0
        self.addedAt = Date()
    }
    
    var posterURL: URL? {
        guard let posterPath = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }
}
