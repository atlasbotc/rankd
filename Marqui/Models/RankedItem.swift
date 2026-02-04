import Foundation
import SwiftData

enum Tier: String, Codable, CaseIterable {
    case good = "Good"
    case medium = "Medium"
    case bad = "Bad"
}

enum MediaType: String, Codable {
    case movie
    case tv
}

@Model
final class RankedItem {
    var id: UUID = UUID()
    @Attribute(.unique) var tmdbId: Int = 0
    var title: String = ""
    var overview: String = ""
    var posterPath: String?
    var releaseDate: String?
    var mediaType: MediaType = .movie
    var tier: Tier = .medium
    var rank: Int = Int.max // Lower = better (1 = best)
    var dateAdded: Date = Date()
    var comparisonCount: Int = 0
    var review: String?
    var genreIds: [Int] = []
    var genreNames: [String] = []
    var runtimeMinutes: Int = 0
    var isFavorite: Bool = false
    
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
        self.tmdbId = tmdbId
        self.title = title
        self.overview = overview
        self.posterPath = posterPath
        self.releaseDate = releaseDate
        self.mediaType = mediaType
        self.tier = tier
        self.review = review
    }
    
    /// Calculate auto-score (1.0–10.0) based on tier and rank position within that tier.
    /// Requires all ranked items of the same media type to determine position.
    static func calculateScore(for item: RankedItem, allItems: [RankedItem]) -> Double {
        let tierItems = allItems
            .filter { $0.tier == item.tier && $0.mediaType == item.mediaType }
            .sorted { $0.rank < $1.rank }
        
        let count = tierItems.count
        guard count > 0 else { return 1.0 }
        
        let (top, bottom): (Double, Double) = {
            switch item.tier {
            case .good:   return (10.0, 7.0)
            case .medium: return (6.9, 4.0)
            case .bad:    return (3.9, 1.0)
            }
        }()
        
        guard count > 1,
              let index = tierItems.firstIndex(where: { $0.id == item.id })
        else {
            return top // single item gets top of range
        }
        
        let score = top - (top - bottom) * Double(index) / Double(count - 1)
        return (score * 10).rounded() / 10 // round to 1 decimal
    }
    
    /// Calculate all scores in a single O(n) pass by pre-grouping items by tier and media type.
    static func calculateAllScores(for items: [RankedItem]) -> [UUID: Double] {
        // Group by (tier, mediaType)
        var grouped: [String: [RankedItem]] = [:]
        for item in items {
            let key = "\(item.tier.rawValue)-\(item.mediaType.rawValue)"
            grouped[key, default: []].append(item)
        }
        // Sort each group by rank
        for key in grouped.keys {
            grouped[key]?.sort { $0.rank < $1.rank }
        }
        
        var scores: [UUID: Double] = [:]
        for (_, tierItems) in grouped {
            let count = tierItems.count
            guard count > 0, let firstItem = tierItems.first else { continue }
            
            let (top, bottom): (Double, Double) = {
                switch firstItem.tier {
                case .good:   return (10.0, 7.0)
                case .medium: return (6.9, 4.0)
                case .bad:    return (3.9, 1.0)
                }
            }()
            
            if count == 1 {
                scores[tierItems[0].id] = top
            } else {
                for (index, item) in tierItems.enumerated() {
                    let score = top - (top - bottom) * Double(index) / Double(count - 1)
                    scores[item.id] = (score * 10).rounded() / 10
                }
            }
        }
        return scores
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
