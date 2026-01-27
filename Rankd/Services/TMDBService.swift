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
}
