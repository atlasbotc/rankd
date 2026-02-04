import Foundation

// MARK: - Match Result

enum TMDBMatchResult {
    case matched(TMDBSearchResult)
    case ambiguous([TMDBSearchResult])
    case notFound
}

struct MatchedEntry: Identifiable {
    let id = UUID()
    let entry: LetterboxdEntry
    let result: TMDBMatchResult
    
    var tmdbResult: TMDBSearchResult? {
        if case .matched(let r) = result { return r }
        return nil
    }
    
    var isMatched: Bool {
        if case .matched = result { return true }
        return false
    }
}

// MARK: - Progress

struct MatchProgress {
    var total: Int
    var processed: Int
    var matched: Int
    var notFound: Int
    
    var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(processed) / Double(total)
    }
}

// MARK: - TMDB Matcher

actor TMDBMatcher {
    private let batchSize = 10
    private let batchDelayNanoseconds: UInt64 = 500_000_000 // 0.5 seconds
    
    /// Match an array of Letterboxd entries against TMDB.
    /// Calls `onProgress` on the main actor after each batch.
    func match(
        entries: [LetterboxdEntry],
        onProgress: @MainActor @Sendable (MatchProgress) -> Void
    ) async -> [MatchedEntry] {
        var results: [MatchedEntry] = []
        var progress = MatchProgress(total: entries.count, processed: 0, matched: 0, notFound: 0)
        
        let batches = stride(from: 0, to: entries.count, by: batchSize).map {
            Array(entries[$0..<min($0 + batchSize, entries.count)])
        }
        
        for batch in batches {
            // Process each entry in the batch concurrently
            let batchResults = await withTaskGroup(of: MatchedEntry.self, returning: [MatchedEntry].self) { group in
                for entry in batch {
                    group.addTask {
                        let result = await self.matchSingle(entry: entry)
                        return MatchedEntry(entry: entry, result: result)
                    }
                }
                
                var collected: [MatchedEntry] = []
                for await result in group {
                    collected.append(result)
                }
                return collected
            }
            
            results.append(contentsOf: batchResults)
            
            progress.processed += batchResults.count
            progress.matched += batchResults.filter(\.isMatched).count
            progress.notFound += batchResults.filter { !$0.isMatched }.count
            
            await onProgress(progress)
            
            // Rate limit: wait between batches
            if progress.processed < entries.count {
                try? await Task.sleep(nanoseconds: batchDelayNanoseconds)
            }
        }
        
        return results
    }
    
    // MARK: - Single Entry Matching
    
    private func matchSingle(entry: LetterboxdEntry) async -> TMDBMatchResult {
        do {
            let searchResults = try await TMDBService.shared.searchMovies(query: entry.name)
            
            guard !searchResults.isEmpty else {
                return .notFound
            }
            
            // Filter by year if available
            if let entryYear = entry.year {
                let yearMatches = searchResults.filter { result in
                    guard let resultDate = result.releaseDate, resultDate.count >= 4 else {
                        return false
                    }
                    let resultYear = String(resultDate.prefix(4))
                    return resultYear == entryYear
                }
                
                if yearMatches.count == 1 {
                    return .matched(yearMatches[0])
                }
                
                if yearMatches.count > 1 {
                    // Try exact title match among year-matched results
                    let exactMatch = yearMatches.first { result in
                        result.displayTitle.lowercased() == entry.name.lowercased()
                    }
                    if let exact = exactMatch {
                        return .matched(exact)
                    }
                    // Take the first (most popular) result for the right year
                    return .matched(yearMatches[0])
                }
                
                // No year match — try year ±1 (release dates can differ by region)
                let fuzzyYearMatches = searchResults.filter { result in
                    guard let resultDate = result.releaseDate, resultDate.count >= 4,
                          let resultYearInt = Int(String(resultDate.prefix(4))),
                          let entryYearInt = Int(entryYear) else {
                        return false
                    }
                    return abs(resultYearInt - entryYearInt) <= 1
                }
                
                if let best = fuzzyYearMatches.first {
                    return .matched(best)
                }
            }
            
            // No year or no year match — try exact title match
            let exactTitleMatch = searchResults.first { result in
                result.displayTitle.lowercased() == entry.name.lowercased()
            }
            if let exact = exactTitleMatch {
                return .matched(exact)
            }
            
            // Fall back to first result if reasonably close
            if searchResults.count == 1 {
                return .matched(searchResults[0])
            }
            
            // Multiple results, no year to disambiguate — take first (highest popularity)
            return .matched(searchResults[0])
            
        } catch {
            return .notFound
        }
    }
}
