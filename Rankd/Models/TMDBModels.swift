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

// MARK: - Movie Detail
struct TMDBMovieDetail: Codable {
    let id: Int
    let title: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let runtime: Int?
    let voteAverage: Double?
    let voteCount: Int?
    let genres: [TMDBGenre]
    let credits: TMDBCredits?
    let tagline: String?
    let status: String?
    let budget: Int?
    let revenue: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, title, overview, runtime, genres, credits, tagline, status, budget, revenue
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
    }
    
    var year: String? {
        guard let date = releaseDate, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }
    
    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "\(Config.tmdbImageBaseURL)/w500\(path)")
    }
    
    var backdropURL: URL? {
        guard let path = backdropPath else { return nil }
        return URL(string: "\(Config.tmdbImageBaseURL)/w780\(path)")
    }
    
    var runtimeFormatted: String? {
        guard let runtime = runtime, runtime > 0 else { return nil }
        let hours = runtime / 60
        let minutes = runtime % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    var director: TMDBCrewMember? {
        credits?.crew.first { $0.job == "Director" }
    }
}

// MARK: - TV Detail
struct TMDBTVDetail: Codable {
    let id: Int
    let name: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let firstAirDate: String?
    let lastAirDate: String?
    let voteAverage: Double?
    let voteCount: Int?
    let genres: [TMDBGenre]
    let credits: TMDBCredits?
    let tagline: String?
    let status: String?
    let numberOfSeasons: Int?
    let numberOfEpisodes: Int?
    let episodeRunTime: [Int]?
    let createdBy: [TMDBCreator]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview, genres, credits, tagline, status
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case firstAirDate = "first_air_date"
        case lastAirDate = "last_air_date"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case numberOfSeasons = "number_of_seasons"
        case numberOfEpisodes = "number_of_episodes"
        case episodeRunTime = "episode_run_time"
        case createdBy = "created_by"
    }
    
    var year: String? {
        guard let date = firstAirDate, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }
    
    var yearRange: String? {
        guard let startYear = year else { return nil }
        if status == "Ended" || status == "Canceled", let endDate = lastAirDate, endDate.count >= 4 {
            let endYear = String(endDate.prefix(4))
            if startYear != endYear {
                return "\(startYear)–\(endYear)"
            }
        }
        return status == "Ended" ? startYear : "\(startYear)–"
    }
    
    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "\(Config.tmdbImageBaseURL)/w500\(path)")
    }
    
    var backdropURL: URL? {
        guard let path = backdropPath else { return nil }
        return URL(string: "\(Config.tmdbImageBaseURL)/w780\(path)")
    }
    
    var episodeRuntimeFormatted: String? {
        guard let runtimes = episodeRunTime, let avg = runtimes.first, avg > 0 else { return nil }
        return "\(avg)m per episode"
    }
}

// MARK: - Credits
struct TMDBCredits: Codable {
    let cast: [TMDBCastMember]
    let crew: [TMDBCrewMember]
}

struct TMDBCastMember: Codable, Identifiable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?
    let order: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, name, character, order
        case profilePath = "profile_path"
    }
    
    var profileURL: URL? {
        guard let path = profilePath else { return nil }
        return URL(string: "\(Config.tmdbImageBaseURL)/w185\(path)")
    }
}

struct TMDBCrewMember: Codable, Identifiable {
    let id: Int
    let name: String
    let job: String?
    let department: String?
    let profilePath: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, job, department
        case profilePath = "profile_path"
    }
    
    var profileURL: URL? {
        guard let path = profilePath else { return nil }
        return URL(string: "\(Config.tmdbImageBaseURL)/w185\(path)")
    }
}

struct TMDBCreator: Codable, Identifiable {
    let id: Int
    let name: String
    let profilePath: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case profilePath = "profile_path"
    }
}
