import Foundation
import SwiftData

enum WatchlistPriority: Int, Codable, CaseIterable, Comparable {
    case high = 0
    case normal = 1
    case low = 2
    
    static func < (lhs: WatchlistPriority, rhs: WatchlistPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    var label: String {
        switch self {
        case .high: return "High"
        case .normal: return "Normal"
        case .low: return "Low"
        }
    }
    
    var iconName: String {
        switch self {
        case .high: return "exclamationmark.circle.fill"
        case .normal: return "minus.circle"
        case .low: return "arrow.down.circle"
        }
    }
}

@Model
final class WatchlistItem {
    var id: UUID = UUID()
    var tmdbId: Int = 0
    var title: String = ""
    var overview: String = ""
    var posterPath: String?
    var releaseDate: String?
    var mediaType: MediaType = .movie
    var dateAdded: Date = Date()
    var notes: String?
    var priorityRaw: Int = 1
    
    var priority: WatchlistPriority {
        get { WatchlistPriority(rawValue: priorityRaw) ?? .normal }
        set { priorityRaw = newValue.rawValue }
    }
    
    init(
        tmdbId: Int,
        title: String,
        overview: String = "",
        posterPath: String? = nil,
        releaseDate: String? = nil,
        mediaType: MediaType,
        priority: WatchlistPriority = .normal
    ) {
        self.tmdbId = tmdbId
        self.title = title
        self.overview = overview
        self.posterPath = posterPath
        self.releaseDate = releaseDate
        self.mediaType = mediaType
        self.priorityRaw = priority.rawValue
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
