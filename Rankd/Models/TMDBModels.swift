import Foundation

// MARK: - Search Response
struct TMDBSearchResponse: Codable {
    let page: Int
    let results: [TMDBSearchResult]
    let totalPages: Int
    let totalResults: Int
    
    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

// MARK: - Search Result
struct TMDBSearchResult: Codable, Identifiable {
    let id: Int
    let title: String?
    let name: String? // For TV shows
    let overview: String?
    let posterPath: String?
    let releaseDate: String?
    let firstAirDate: String? // For TV shows
    let mediaType: String?
    let voteAverage: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, title, name, overview
        case posterPath = "poster_path"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case mediaType = "media_type"
        case voteAverage = "vote_average"
    }
    
    init(id: Int, title: String?, name: String?, overview: String?, posterPath: String?, releaseDate: String?, firstAirDate: String?, mediaType: String?, voteAverage: Double?) {
        self.id = id
        self.title = title
        self.name = name
        self.overview = overview
        self.posterPath = posterPath
        self.releaseDate = releaseDate
        self.firstAirDate = firstAirDate
        self.mediaType = mediaType
        self.voteAverage = voteAverage
    }
    
    var displayTitle: String {
        title ?? name ?? "Unknown"
    }
    
    var displayDate: String? {
        releaseDate ?? firstAirDate
    }
    
    var displayYear: String? {
        guard let date = displayDate, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }
    
    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "\(Config.tmdbImageBaseURL)/w500\(path)")
    }
    
    var resolvedMediaType: MediaType {
        if mediaType == "tv" || name != nil && title == nil {
            return .tv
        }
        return .movie
    }
}

// MARK: - Genre
struct TMDBGenre: Codable, Identifiable {
    let id: Int
    let name: String
}

struct TMDBGenreResponse: Codable {
    let genres: [TMDBGenre]
}
