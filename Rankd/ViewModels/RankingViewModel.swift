import Foundation
import SwiftUI
import SwiftData

@Observable
class RankingViewModel {
    var searchQuery = ""
    var searchResults: [TMDBSearchResult] = []
    var isSearching = false
    var searchError: String?
    
    private var searchTask: Task<Void, Never>?
    
    func search() {
        searchTask?.cancel()
        
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        searchError = nil
        
        searchTask = Task {
            do {
                try await Task.sleep(nanoseconds: 400_000_000) // Debounce 400ms
                
                guard !Task.isCancelled else { return }
                
                let results = try await TMDBService.shared.searchMulti(query: searchQuery)
                
                await MainActor.run {
                    self.searchResults = results
                    self.isSearching = false
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.searchError = error.localizedDescription
                        self.isSearching = false
                    }
                }
            }
        }
    }
    
    func clearSearch() {
        searchQuery = ""
        searchResults = []
        searchError = nil
    }
}

// MARK: - Comparison Logic
extension RankingViewModel {
    /// Find two items that need comparison within a tier
    func findPairToCompare(items: [RankedItem], tier: Tier) -> (RankedItem, RankedItem)? {
        let tierItems = items.filter { $0.tier == tier }
            .sorted { $0.comparisonCount < $1.comparisonCount }
        
        guard tierItems.count >= 2 else { return nil }
        
        // Prioritize items with fewer comparisons
        let first = tierItems[0]
        let second = tierItems.first { $0.id != first.id } ?? tierItems[1]
        
        return (first, second)
    }
    
    /// Find any pair that needs comparison across all tiers
    func findAnyPairToCompare(items: [RankedItem]) -> (RankedItem, RankedItem)? {
        // Try each tier in order
        for tier in Tier.allCases {
            if let pair = findPairToCompare(items: items, tier: tier) {
                return pair
            }
        }
        return nil
    }
    
    /// Process a comparison result
    func processComparison(winner: RankedItem, loser: RankedItem, context: ModelContext) {
        // Increment comparison counts
        winner.comparisonCount += 1
        loser.comparisonCount += 1
        
        // Update ranks - winner moves up, loser moves down
        if winner.rank > loser.rank {
            // Winner was ranked lower (higher number), swap
            let temp = winner.rank
            winner.rank = loser.rank
            loser.rank = temp
        }
        
        // Save changes
        try? context.save()
    }

}
