import Foundation

/// Handles exporting user data as CSV or JSON files.
enum ExportService {
    
    // MARK: - Date Formatter
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    
    // MARK: - CSV Escaping
    
    /// Escapes a field for CSV: wraps in quotes if it contains commas, quotes, or newlines.
    private static func escapeCSV(_ value: String) -> String {
        let needsQuoting = value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r")
        if needsQuoting {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
    
    // MARK: - Rankings CSV
    
    /// Creates a CSV file of ranked items in the temp directory.
    /// Columns: Rank, Title, Media Type, Tier, Score, Genre, Year, Date Ranked
    static func exportRankingsCSV(items: [RankedItem]) -> URL {
        let sorted = items.sorted { $0.rank < $1.rank }
        
        var lines = ["Rank,Title,Media Type,Tier,Score,Genre,Year,Date Ranked"]
        
        for item in sorted {
            let score = RankedItem.calculateScore(for: item, allItems: items)
            let genre = item.genreNames.joined(separator: "; ")
            let year = item.year ?? ""
            let date = dateFormatter.string(from: item.dateAdded)
            let mediaType = item.mediaType == .movie ? "Movie" : "TV"
            
            let row = [
                "\(item.rank)",
                escapeCSV(item.title),
                mediaType,
                item.tier.rawValue,
                String(format: "%.1f", score),
                escapeCSV(genre),
                year,
                date
            ].joined(separator: ",")
            
            lines.append(row)
        }
        
        let csv = lines.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rankd_rankings.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    // MARK: - Watchlist CSV
    
    /// Creates a CSV file of watchlist items in the temp directory.
    /// Columns: Title, Media Type, Priority, Date Added
    static func exportWatchlistCSV(items: [WatchlistItem]) -> URL {
        let sorted = items.sorted { $0.dateAdded > $1.dateAdded }
        
        var lines = ["Title,Media Type,Priority,Date Added"]
        
        for item in sorted {
            let mediaType = item.mediaType == .movie ? "Movie" : "TV"
            let date = dateFormatter.string(from: item.dateAdded)
            
            let row = [
                escapeCSV(item.title),
                mediaType,
                item.priority.label,
                date
            ].joined(separator: ",")
            
            lines.append(row)
        }
        
        let csv = lines.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rankd_watchlist.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    // MARK: - Full JSON Export
    
    /// Creates a pretty-printed JSON file with all ranked and watchlist data.
    static func exportAllJSON(ranked: [RankedItem], watchlist: [WatchlistItem]) -> URL {
        let rankedDicts: [[String: Any]] = ranked.sorted { $0.rank < $1.rank }.map { item in
            let score = RankedItem.calculateScore(for: item, allItems: ranked)
            var dict: [String: Any] = [
                "rank": item.rank,
                "title": item.title,
                "tmdbId": item.tmdbId,
                "mediaType": item.mediaType == .movie ? "movie" : "tv",
                "tier": item.tier.rawValue,
                "score": round(score * 10) / 10,
                "dateAdded": dateFormatter.string(from: item.dateAdded),
                "genreNames": item.genreNames
            ]
            if let year = item.year { dict["year"] = year }
            if let review = item.review, !review.isEmpty { dict["review"] = review }
            if let posterPath = item.posterPath { dict["posterPath"] = posterPath }
            if !item.overview.isEmpty { dict["overview"] = item.overview }
            if item.runtimeMinutes > 0 { dict["runtimeMinutes"] = item.runtimeMinutes }
            return dict
        }
        
        let watchlistDicts: [[String: Any]] = watchlist.sorted { $0.dateAdded > $1.dateAdded }.map { item in
            var dict: [String: Any] = [
                "title": item.title,
                "tmdbId": item.tmdbId,
                "mediaType": item.mediaType == .movie ? "movie" : "tv",
                "priority": item.priority.label,
                "dateAdded": dateFormatter.string(from: item.dateAdded)
            ]
            if let year = item.year { dict["year"] = year }
            if let notes = item.notes, !notes.isEmpty { dict["notes"] = notes }
            if let posterPath = item.posterPath { dict["posterPath"] = posterPath }
            if !item.overview.isEmpty { dict["overview"] = item.overview }
            return dict
        }
        
        let exportData: [String: Any] = [
            "exportDate": dateFormatter.string(from: Date()),
            "app": "Rankd",
            "rankings": rankedDicts,
            "watchlist": watchlistDicts
        ]
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rankd_export.json")
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted, .sortedKeys]) {
            try? jsonData.write(to: url)
        }
        
        return url
    }
}
