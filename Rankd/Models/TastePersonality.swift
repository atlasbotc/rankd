import Foundation
import SwiftUI

// MARK: - Taste Personality Engine

/// Analyzes ranked items to determine a user's taste archetype and DNA stats.
struct TastePersonality {
    
    // MARK: - Archetype
    
    enum Archetype: String, Codable {
        case cinephile = "The Cinephile"
        case bingeWatcher = "The Binge Watcher"
        case blockbusterFan = "The Blockbuster Fan"
        case critic = "The Critic"
        case enthusiast = "The Enthusiast"
        case eclectic = "The Eclectic"
        case nostalgist = "The Nostalgist"
        case trendsetter = "The Trendsetter"
        case horrorBuff = "The Horror Buff"
        case comedyLover = "The Comedy Lover"
        case dramaQueen = "The Drama Queen"
        case gettingStarted = "Getting Started"
        
        var icon: String {
            switch self {
            case .cinephile: return "film.stack"
            case .bingeWatcher: return "play.tv"
            case .blockbusterFan: return "bolt.fill"
            case .critic: return "eye.trianglebadge.exclamationmark"
            case .enthusiast: return "heart.fill"
            case .eclectic: return "paintpalette"
            case .nostalgist: return "clock.arrow.circlepath"
            case .trendsetter: return "sparkles"
            case .horrorBuff: return "theatermasks"
            case .comedyLover: return "face.smiling"
            case .dramaQueen: return "theatermasks.fill"
            case .gettingStarted: return "questionmark.circle"
            }
        }
        
        var description: String {
            switch self {
            case .cinephile:
                return "You gravitate toward cinema as art. Dramas, indie gems, and thoughtful storytelling define your taste."
            case .bingeWatcher:
                return "Series are your world. You love character arcs that unfold over seasons, not just hours."
            case .blockbusterFan:
                return "Big screen, big action, big fun. You live for the spectacle and never apologize for it."
            case .critic:
                return "High standards, refined taste. You don't hand out praise easily — and that makes your favorites mean more."
            case .enthusiast:
                return "You find joy in almost everything you watch. Your enthusiasm is contagious and your green tier is stacked."
            case .eclectic:
                return "No genre can contain you. Your taste spans everything — a true omnivore of film and TV."
            case .nostalgist:
                return "The classics never get old for you. You appreciate the foundations that built modern entertainment."
            case .trendsetter:
                return "Always watching what's new. You're plugged into the cultural conversation and ranking what matters now."
            case .horrorBuff:
                return "You thrive in the dark. Horror isn't just a genre to you — it's a way of life."
            case .comedyLover:
                return "Laughter is the best medicine, and your rankings prove it. Comedy runs through your veins."
            case .dramaQueen:
                return "Emotional depth is everything. You're drawn to stories that make you feel deeply."
            case .gettingStarted:
                return "Rank more titles to discover your taste personality."
            }
        }
    }
    
    // MARK: - Taste DNA
    
    struct TasteDNA {
        let topGenres: [(name: String, percentage: Int)]  // Top 3
        let averageScore: Double                           // 1.0–3.0 scale
        let pickinessPercent: Int                          // % red tier
        let favoriteDecade: String?                        // e.g. "2010s"
        let movieCount: Int
        let tvCount: Int
    }
    
    // MARK: - Result
    
    struct Result {
        let archetype: Archetype
        let dataPoints: [String]   // 2-3 supporting facts
        let dna: TasteDNA
    }
    
    // MARK: - Compute
    
    static func analyze(items: [RankedItem]) -> Result {
        let total = items.count
        let movieItems = items.filter { $0.mediaType == .movie }
        let tvItems = items.filter { $0.mediaType == .tv }
        let goodItems = items.filter { $0.tier == .good }
        let badItems = items.filter { $0.tier == .bad }
        let mediumItems = items.filter { $0.tier == .medium }
        
        // Genre counts
        let genreCounts = computeGenreCounts(items: items)
        let topGenres: [(name: String, percentage: Int)] = {
            let withGenres = items.filter { !$0.genreNames.isEmpty }.count
            guard withGenres > 0 else { return [] }
            return Array(genreCounts.prefix(3).map { genre in
                (name: genre.name, percentage: Int(round(Double(genre.count) / Double(withGenres) * 100)))
            })
        }()
        
        // Average score (simple 1-3 scale: good=3, medium=2, bad=1)
        let avgScore: Double = total > 0
            ? Double(goodItems.count * 3 + mediumItems.count * 2 + badItems.count) / Double(total)
            : 0.0
        
        // Pickiness
        let pickinessPercent = total > 0 ? Int(round(Double(badItems.count) / Double(total) * 100)) : 0
        
        // Favorite decade
        let decades = computeDecades(items: items)
        let favoriteDecade = decades.first?.decade
        
        // Decade analysis for archetype
        let currentYear = Calendar.current.component(.year, from: Date())
        let pre2010Count = countItemsBeforeYear(2010, items: items)
        let recentCount = countItemsAfterYear(currentYear - 2, items: items)
        let itemsWithYear = items.filter { yearFromItem($0) != nil }.count
        
        let dna = TasteDNA(
            topGenres: topGenres,
            averageScore: avgScore,
            pickinessPercent: pickinessPercent,
            favoriteDecade: favoriteDecade,
            movieCount: movieItems.count,
            tvCount: tvItems.count
        )
        
        // Not enough data
        guard total >= 5 else {
            return Result(
                archetype: .gettingStarted,
                dataPoints: ["Rank \(5 - total) more to unlock your personality"],
                dna: dna
            )
        }
        
        var dataPoints: [String] = []
        
        // --- Archetype determination (priority order) ---
        
        // 1. The Critic — very selective with green, lots of red/yellow
        let greenPercent = Double(goodItems.count) / Double(total)
        let redPercent = Double(badItems.count) / Double(total)
        let yellowPercent = Double(mediumItems.count) / Double(total)
        
        if greenPercent < 0.25 && (redPercent + yellowPercent) > 0.6 {
            dataPoints.append("Only \(Int(greenPercent * 100))% of your items are green tier")
            dataPoints.append("\(Int((redPercent + yellowPercent) * 100))% rated yellow or red")
            if let top = topGenres.first {
                dataPoints.append("Top genre: \(top.name) (\(top.percentage)%)")
            }
            return Result(archetype: .critic, dataPoints: dataPoints, dna: dna)
        }
        
        // 2. The Enthusiast — most items green
        if greenPercent > 0.7 {
            dataPoints.append("\(Int(greenPercent * 100))% of your items are green tier")
            dataPoints.append("\(goodItems.count) items you love out of \(total)")
            if let top = topGenres.first {
                dataPoints.append("Favorite genre: \(top.name)")
            }
            return Result(archetype: .enthusiast, dataPoints: dataPoints, dna: dna)
        }
        
        // 3. The Binge Watcher — mostly TV
        let tvPercent = Double(tvItems.count) / Double(total)
        if tvPercent > 0.65 {
            dataPoints.append("\(tvItems.count) TV shows vs \(movieItems.count) movies")
            dataPoints.append("\(Int(tvPercent * 100))% of your rankings are TV")
            if let top = topGenres.first {
                dataPoints.append("Top genre: \(top.name)")
            }
            return Result(archetype: .bingeWatcher, dataPoints: dataPoints, dna: dna)
        }
        
        // 4. Genre-dominant archetypes (need >40% of one genre)
        let dominantGenre = genreCounts.first
        let withGenres = items.filter { !$0.genreNames.isEmpty }.count
        if let dominant = dominantGenre, withGenres > 0 {
            let dominancePercent = Double(dominant.count) / Double(withGenres)
            
            if dominancePercent > 0.40 {
                let genreName = dominant.name.lowercased()
                
                // Horror Buff
                if genreName == "horror" {
                    dataPoints.append("\(Int(dominancePercent * 100))% of your items are Horror")
                    dataPoints.append("\(dominant.count) horror titles ranked")
                    dataPoints.append("\(movieItems.count) movies, \(tvItems.count) TV shows")
                    return Result(archetype: .horrorBuff, dataPoints: dataPoints, dna: dna)
                }
                
                // Comedy Lover
                if genreName == "comedy" {
                    dataPoints.append("\(Int(dominancePercent * 100))% of your items are Comedy")
                    dataPoints.append("\(dominant.count) comedies ranked")
                    if let fav = favoriteDecade { dataPoints.append("Favorite decade: \(fav)") }
                    return Result(archetype: .comedyLover, dataPoints: dataPoints, dna: dna)
                }
                
                // Drama Queen
                if genreName == "drama" {
                    dataPoints.append("\(Int(dominancePercent * 100))% of your items are Drama")
                    dataPoints.append("\(dominant.count) dramas ranked")
                    dataPoints.append("Average score: \(String(format: "%.1f", avgScore))/3.0")
                    return Result(archetype: .dramaQueen, dataPoints: dataPoints, dna: dna)
                }
                
                // Blockbuster Fan (action/adventure/sci-fi dominant)
                if ["action", "adventure", "science fiction"].contains(genreName) {
                    dataPoints.append("\(Int(dominancePercent * 100))% action/adventure/sci-fi")
                    dataPoints.append("\(dominant.count) blockbuster titles")
                    dataPoints.append("\(movieItems.count) movies ranked")
                    return Result(archetype: .blockbusterFan, dataPoints: dataPoints, dna: dna)
                }
            }
            
            // Also check combined action/adventure/sci-fi
            let blockbusterGenres = ["Action", "Adventure", "Science Fiction"]
            let blockbusterCount = genreCounts.filter { blockbusterGenres.contains($0.name) }.reduce(0) { $0 + $1.count }
            if withGenres > 0 && Double(blockbusterCount) / Double(withGenres) > 0.45 {
                let pct = Int(round(Double(blockbusterCount) / Double(withGenres) * 100))
                dataPoints.append("\(pct)% action, adventure, or sci-fi")
                dataPoints.append("\(blockbusterCount) blockbuster titles ranked")
                dataPoints.append("\(movieItems.count) movies, \(tvItems.count) TV shows")
                return Result(archetype: .blockbusterFan, dataPoints: dataPoints, dna: dna)
            }
        }
        
        // 5. Nostalgist — majority pre-2010
        if itemsWithYear > 0 && Double(pre2010Count) / Double(itemsWithYear) > 0.6 {
            let pct = Int(round(Double(pre2010Count) / Double(itemsWithYear) * 100))
            dataPoints.append("\(pct)% of your items are from before 2010")
            if let fav = favoriteDecade { dataPoints.append("Favorite decade: \(fav)") }
            dataPoints.append("\(pre2010Count) classic titles ranked")
            return Result(archetype: .nostalgist, dataPoints: dataPoints, dna: dna)
        }
        
        // 6. Trendsetter — mostly recent (last 2 years)
        if itemsWithYear > 0 && Double(recentCount) / Double(itemsWithYear) > 0.5 {
            let pct = Int(round(Double(recentCount) / Double(itemsWithYear) * 100))
            dataPoints.append("\(pct)% of your items are from the last 2 years")
            dataPoints.append("\(recentCount) recent releases ranked")
            if let top = topGenres.first { dataPoints.append("Top genre: \(top.name)") }
            return Result(archetype: .trendsetter, dataPoints: dataPoints, dna: dna)
        }
        
        // 7. Cinephile — mostly movies + drama/indie leaning
        let moviePercent = Double(movieItems.count) / Double(total)
        let dramaGenres = ["Drama", "History", "War", "Documentary"]
        let cinephileGenreCount = genreCounts.filter { dramaGenres.contains($0.name) }.reduce(0) { $0 + $1.count }
        if moviePercent > 0.7 && withGenres > 0 && Double(cinephileGenreCount) / Double(withGenres) > 0.3 {
            let pct = Int(round(Double(cinephileGenreCount) / Double(withGenres) * 100))
            dataPoints.append("\(movieItems.count) movies vs \(tvItems.count) TV shows")
            dataPoints.append("\(pct)% drama, history, or documentary")
            dataPoints.append("Average score: \(String(format: "%.1f", avgScore))/3.0")
            return Result(archetype: .cinephile, dataPoints: dataPoints, dna: dna)
        }
        
        // 8. Eclectic — fallback for diverse taste
        let genreSpread = genreCounts.count
        dataPoints.append("\(genreSpread) different genres ranked")
        dataPoints.append("\(movieItems.count) movies, \(tvItems.count) TV shows")
        if let fav = favoriteDecade { dataPoints.append("Favorite decade: \(fav)") }
        return Result(archetype: .eclectic, dataPoints: dataPoints, dna: dna)
    }
    
    // MARK: - Helpers
    
    private static func computeGenreCounts(items: [RankedItem]) -> [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for item in items where !item.genreNames.isEmpty {
            for genre in item.genreNames {
                counts[genre, default: 0] += 1
            }
        }
        return counts.map { (name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    private static func computeDecades(items: [RankedItem]) -> [(decade: String, count: Int)] {
        var decadeCounts: [String: Int] = [:]
        for item in items {
            guard let year = yearFromItem(item) else { continue }
            let decadeStart = (year / 10) * 10
            decadeCounts["\(decadeStart)s", default: 0] += 1
        }
        return decadeCounts.map { (decade: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    private static func yearFromItem(_ item: RankedItem) -> Int? {
        guard let date = item.releaseDate, date.count >= 4 else { return nil }
        return Int(date.prefix(4))
    }
    
    private static func countItemsBeforeYear(_ year: Int, items: [RankedItem]) -> Int {
        items.filter { item in
            guard let y = yearFromItem(item) else { return false }
            return y < year
        }.count
    }
    
    private static func countItemsAfterYear(_ year: Int, items: [RankedItem]) -> Int {
        items.filter { item in
            guard let y = yearFromItem(item) else { return false }
            return y >= year
        }.count
    }
}
