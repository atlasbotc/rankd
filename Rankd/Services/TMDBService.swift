import Foundation

enum TMDBError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case invalidAPIKey
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .invalidAPIKey:
            return "Invalid TMDB API key. Please add your key to Config.swift"
        }
    }
}

actor TMDBService {
    static let shared = TMDBService()
    
    private init() {}
    
    func searchMulti(query: String) async throws -> [TMDBSearchResult] {
        guard !query.isEmpty else { return [] }
        
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw TMDBError.invalidURL
        }
        
        let urlString = "\(Config.tmdbBaseURL)/search/multi?api_key=\(Config.tmdbApiKey)&query=\(encodedQuery)&include_adult=false"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                throw TMDBError.invalidAPIKey
            }
            
            let searchResponse = try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
            
            // Filter to only movies and TV shows
            return searchResponse.results.filter { result in
                result.mediaType == "movie" || result.mediaType == "tv"
            }
        } catch let error as TMDBError {
            throw error
        } catch let error as DecodingError {
            throw TMDBError.decodingError(error)
        } catch {
            throw TMDBError.networkError(error)
        }
    }
    
    func searchMovies(query: String) async throws -> [TMDBSearchResult] {
        guard !query.isEmpty else { return [] }
        
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw TMDBError.invalidURL
        }
        
        let urlString = "\(Config.tmdbBaseURL)/search/movie?api_key=\(Config.tmdbApiKey)&query=\(encodedQuery)"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let searchResponse = try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
            return searchResponse.results
        } catch let error as DecodingError {
            throw TMDBError.decodingError(error)
        } catch {
            throw TMDBError.networkError(error)
        }
    }
    
    func searchTVShows(query: String) async throws -> [TMDBSearchResult] {
        guard !query.isEmpty else { return [] }
        
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw TMDBError.invalidURL
        }
        
        let urlString = "\(Config.tmdbBaseURL)/search/tv?api_key=\(Config.tmdbApiKey)&query=\(encodedQuery)"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let searchResponse = try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
            return searchResponse.results
        } catch let error as DecodingError {
            throw TMDBError.decodingError(error)
        } catch {
            throw TMDBError.networkError(error)
        }
    }
    
    // MARK: - Discovery Endpoints
    
    func getTrending(mediaType: String = "all", timeWindow: String = "week") async throws -> [TMDBSearchResult] {
        let urlString = "\(Config.tmdbBaseURL)/trending/\(mediaType)/\(timeWindow)?api_key=\(Config.tmdbApiKey)"
        return try await fetchResults(from: urlString)
    }
    
    func getPopularMovies(page: Int = 1) async throws -> [TMDBSearchResult] {
        let urlString = "\(Config.tmdbBaseURL)/movie/popular?api_key=\(Config.tmdbApiKey)&page=\(page)"
        return try await fetchResults(from: urlString, defaultMediaType: "movie")
    }
    
    func getPopularTV(page: Int = 1) async throws -> [TMDBSearchResult] {
        let urlString = "\(Config.tmdbBaseURL)/tv/popular?api_key=\(Config.tmdbApiKey)&page=\(page)"
        return try await fetchResults(from: urlString, defaultMediaType: "tv")
    }
    
    func getTopRatedMovies(page: Int = 1) async throws -> [TMDBSearchResult] {
        let urlString = "\(Config.tmdbBaseURL)/movie/top_rated?api_key=\(Config.tmdbApiKey)&page=\(page)"
        return try await fetchResults(from: urlString, defaultMediaType: "movie")
    }
    
    func getTopRatedTV(page: Int = 1) async throws -> [TMDBSearchResult] {
        let urlString = "\(Config.tmdbBaseURL)/tv/top_rated?api_key=\(Config.tmdbApiKey)&page=\(page)"
        return try await fetchResults(from: urlString, defaultMediaType: "tv")
    }
    
    func getNowPlayingMovies(page: Int = 1) async throws -> [TMDBSearchResult] {
        let urlString = "\(Config.tmdbBaseURL)/movie/now_playing?api_key=\(Config.tmdbApiKey)&page=\(page)"
        return try await fetchResults(from: urlString, defaultMediaType: "movie")
    }
    
    func getMovieGenres() async throws -> [TMDBGenre] {
        let urlString = "\(Config.tmdbBaseURL)/genre/movie/list?api_key=\(Config.tmdbApiKey)"
        guard let url = URL(string: urlString) else { throw TMDBError.invalidURL }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBGenreResponse.self, from: data)
        return response.genres
    }
    
    func getTVGenres() async throws -> [TMDBGenre] {
        let urlString = "\(Config.tmdbBaseURL)/genre/tv/list?api_key=\(Config.tmdbApiKey)"
        guard let url = URL(string: urlString) else { throw TMDBError.invalidURL }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBGenreResponse.self, from: data)
        return response.genres
    }
    
    func discoverMovies(genreId: Int, page: Int = 1) async throws -> [TMDBSearchResult] {
        let urlString = "\(Config.tmdbBaseURL)/discover/movie?api_key=\(Config.tmdbApiKey)&with_genres=\(genreId)&sort_by=popularity.desc&page=\(page)"
        return try await fetchResults(from: urlString, defaultMediaType: "movie")
    }
    
    func discoverTV(genreId: Int, page: Int = 1) async throws -> [TMDBSearchResult] {
        let urlString = "\(Config.tmdbBaseURL)/discover/tv?api_key=\(Config.tmdbApiKey)&with_genres=\(genreId)&sort_by=popularity.desc&page=\(page)"
        return try await fetchResults(from: urlString, defaultMediaType: "tv")
    }
    
    // MARK: - Helper
    
    private func fetchResults(from urlString: String, defaultMediaType: String? = nil) async throws -> [TMDBSearchResult] {
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                throw TMDBError.invalidAPIKey
            }
            
            let searchResponse = try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
            
            // If no media_type in response, apply default
            if let mediaType = defaultMediaType {
                return searchResponse.results.map { result in
                    var mutable = result
                    if mutable.mediaType == nil {
                        mutable = TMDBSearchResult(
                            id: result.id,
                            title: result.title,
                            name: result.name,
                            overview: result.overview,
                            posterPath: result.posterPath,
                            releaseDate: result.releaseDate,
                            firstAirDate: result.firstAirDate,
                            mediaType: mediaType,
                            voteAverage: result.voteAverage
                        )
                    }
                    return mutable
                }
            }
            
            return searchResponse.results.filter { result in
                result.mediaType == "movie" || result.mediaType == "tv"
            }
        } catch let error as TMDBError {
            throw error
        } catch let error as DecodingError {
            throw TMDBError.decodingError(error)
        } catch {
            throw TMDBError.networkError(error)
        }
    }
}
