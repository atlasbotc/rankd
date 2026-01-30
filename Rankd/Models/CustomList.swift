import Foundation
import SwiftData

@Model
final class CustomList {
    var id: UUID
    var name: String
    var listDescription: String
    var emoji: String
    @Relationship(deleteRule: .cascade, inverse: \CustomListItem.list)
    var items: [CustomListItem]
    var dateCreated: Date
    var dateModified: Date
    
    init(
        name: String,
        listDescription: String = "",
        emoji: String = "📋"
    ) {
        self.id = UUID()
        self.name = name
        self.listDescription = listDescription
        self.emoji = emoji
        self.items = []
        self.dateCreated = Date()
        self.dateModified = Date()
    }
    
    /// Items sorted by position
    var sortedItems: [CustomListItem] {
        items.sorted { $0.position < $1.position }
    }
    
    /// Next available position
    var nextPosition: Int {
        (items.map(\.position).max() ?? 0) + 1
    }
    
    /// Check if a TMDB item is already in this list
    func contains(tmdbId: Int) -> Bool {
        items.contains { $0.tmdbId == tmdbId }
    }
}

@Model
final class CustomListItem {
    var id: UUID
    var tmdbId: Int
    var title: String
    var posterPath: String?
    var releaseDate: String?
    var mediaType: MediaType
    var position: Int
    var note: String?
    var list: CustomList?
    var dateAdded: Date
    
    init(
        tmdbId: Int,
        title: String,
        posterPath: String? = nil,
        releaseDate: String? = nil,
        mediaType: MediaType,
        position: Int,
        note: String? = nil
    ) {
        self.id = UUID()
        self.tmdbId = tmdbId
        self.title = title
        self.posterPath = posterPath
        self.releaseDate = releaseDate
        self.mediaType = mediaType
        self.position = position
        self.note = note
        self.dateAdded = Date()
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
