import Foundation
import SwiftData

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
    
    var emoji: String {
        switch self {
        case .good: return "🟢"
        case .medium: return "🟡"
        case .bad: return "🔴"
        }
    }
}

enum MediaType: String, Codable {
    case movie
    case tv
}

@Model
final class RankedItem {
    var id: UUID
    var tmdbId: Int
    var title: String
    var overview: String
    var posterPath: String?
    var releaseDate: String?
    var mediaType: MediaType
    var tier: Tier
    var rank: Int // Lower = better (1 = best)
    var dateAdded: Date
    var comparisonCount: Int
    var review: String?
    var genreIds: [Int] = []
    var genreNames: [String] = []
    var runtimeMinutes: Int = 0
    
    init(
        tmdbId: Int,
        title: String,
        overview: String = "",
        posterPath: String? = nil,
        releaseDate: String? = nil,
        mediaType: MediaType,
        tier: Tier,
        review: String? = nil
    ) {
        self.id = UUID()
        self.tmdbId = tmdbId
        self.title = title
        self.overview = overview
        self.posterPath = posterPath
        self.releaseDate = releaseDate
        self.mediaType = mediaType
        self.tier = tier
        self.rank = Int.max // New items start at bottom until compared
        self.dateAdded = Date()
        self.comparisonCount = 0
        self.review = review
    }
    
    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "\(Config.tmdbImageBaseURL)/w500\(path)")
    }
    
    var year: String? {
        guard let date = releaseDate, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }
}
