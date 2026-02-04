import Foundation
import SwiftData

@Model
final class CustomList {
    var id: UUID = UUID()
    var name: String = ""
    var listDescription: String = ""
    var emoji: String = "📋"
    @Relationship(deleteRule: .cascade, inverse: \CustomListItem.list)
    var items: [CustomListItem]? = []
    var dateCreated: Date = Date()
    var dateModified: Date = Date()
    
    init(
        name: String,
        listDescription: String = "",
        emoji: String = "📋"
    ) {
        self.name = name
        self.listDescription = listDescription
        self.emoji = emoji
    }
    
    /// Items sorted by position
    var sortedItems: [CustomListItem] {
        (items ?? []).sorted { $0.position < $1.position }
    }
    
    /// Next available position
    var nextPosition: Int {
        ((items ?? []).map(\.position).max() ?? 0) + 1
    }
    
    /// Check if a TMDB item is already in this list
    func contains(tmdbId: Int) -> Bool {
        (items ?? []).contains { $0.tmdbId == tmdbId }
    }
    
    /// Convenience: unwrapped items count
    var itemCount: Int {
        (items ?? []).count
    }
}

@Model
final class CustomListItem {
    var id: UUID = UUID()
    var tmdbId: Int = 0
    var title: String = ""
    var posterPath: String?
    var releaseDate: String?
    var mediaType: MediaType = .movie
    var position: Int = 0
    var note: String?
    var list: CustomList?
    var dateAdded: Date = Date()
    
    init(
        tmdbId: Int,
        title: String,
        posterPath: String? = nil,
        releaseDate: String? = nil,
        mediaType: MediaType,
        position: Int,
        note: String? = nil
    ) {
        self.tmdbId = tmdbId
        self.title = title
        self.posterPath = posterPath
        self.releaseDate = releaseDate
        self.mediaType = mediaType
        self.position = position
        self.note = note
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
