import Foundation
import SwiftData

enum ActivityType: String, Codable {
    case ranked
    case reRanked
    case addedToWatchlist
    case createdList
    case addedToList
    
    var icon: String {
        switch self {
        case .ranked:           return "star.fill"
        case .reRanked:         return "arrow.up.arrow.down"
        case .addedToWatchlist: return "bookmark.fill"
        case .createdList:      return "list.bullet"
        case .addedToList:      return "plus.rectangle.on.folder"
        }
    }
    
    var verb: String {
        switch self {
        case .ranked:           return "ranked"
        case .reRanked:         return "re-ranked"
        case .addedToWatchlist: return "added to watchlist"
        case .createdList:      return "created list"
        case .addedToList:      return "added to list"
        }
    }
}

@Model
final class Activity {
    var id: UUID = UUID()
    var userId: UUID
    var activityTypeRaw: String = ActivityType.ranked.rawValue
    var mediaTitle: String = ""
    var mediaTMDBId: Int = 0
    var mediaTypeRaw: String = MediaType.movie.rawValue
    var timestamp: Date = Date()
    var metadata: String?
    
    var activityType: ActivityType {
        get { ActivityType(rawValue: activityTypeRaw) ?? .ranked }
        set { activityTypeRaw = newValue.rawValue }
    }
    
    var mediaType: MediaType {
        get { MediaType(rawValue: mediaTypeRaw) ?? .movie }
        set { mediaTypeRaw = newValue.rawValue }
    }
    
    init(
        userId: UUID,
        activityType: ActivityType,
        mediaTitle: String,
        mediaTMDBId: Int,
        mediaType: MediaType,
        metadata: String? = nil
    ) {
        self.userId = userId
        self.activityTypeRaw = activityType.rawValue
        self.mediaTitle = mediaTitle
        self.mediaTMDBId = mediaTMDBId
        self.mediaTypeRaw = mediaType.rawValue
        self.metadata = metadata
    }
    
    /// Parse metadata JSON to get specific values
    var parsedMetadata: [String: String] {
        guard let data = metadata?.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return dict.mapValues { "\($0)" }
    }
    
    /// Human-readable description of the activity
    var displayText: String {
        switch activityType {
        case .ranked:
            let score = parsedMetadata["score"] ?? ""
            let scoreText = score.isEmpty ? "" : " \(score)"
            return "ranked \(mediaTitle)\(scoreText)"
        case .reRanked:
            let score = parsedMetadata["score"] ?? ""
            let scoreText = score.isEmpty ? "" : " \(score)"
            return "re-ranked \(mediaTitle)\(scoreText)"
        case .addedToWatchlist:
            return "added \(mediaTitle) to watchlist"
        case .createdList:
            let listName = parsedMetadata["listName"] ?? ""
            return "created list \"\(listName)\""
        case .addedToList:
            let listName = parsedMetadata["listName"] ?? ""
            return "added \(mediaTitle) to \"\(listName)\""
        }
    }
    
    /// Relative timestamp string
    var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}
