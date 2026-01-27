import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var rankedItems: [RankedItem]
    @Query private var watchlistItems: [WatchlistItem]
    @State private var viewModel = RankingViewModel()
    @State private var selectedResult: TMDBSearchResult?
    @State private var showAddSheet = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Search movies & TV shows...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .onChange(of: viewModel.searchQuery) { _, _ in
                            viewModel.search()
                        }
                    
                    if !viewModel.searchQuery.isEmpty {
                        Button {
                            viewModel.clearSearch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                
                // Results
                if viewModel.isSearching {
                    Spacer()
                    ProgressView("Searching...")
                    Spacer()
                } else if let error = viewModel.searchError {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(error)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "film")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No results found")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else if viewModel.searchQuery.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        Text("Search for movies or TV shows")
                            .foregroundStyle(.secondary)
                        Text("Add to rankings or watchlist")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                } else {
                    List(viewModel.searchResults) { result in
                        SearchResultRow(
                            result: result,
                            status: itemStatus(result)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if itemStatus(result) == .notAdded {
                                selectedResult = result
                                showAddSheet = true
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Add")
            .sheet(isPresented: $showAddSheet) {
                if let result = selectedResult {
                    AddItemSheet(result: result) { action in
                        handleAddAction(result: result, action: action)
                        showAddSheet = false
                        selectedResult = nil
                    }
                    .presentationDetents([.medium])
                }
            }
        }
    }
    
    private func itemStatus(_ result: TMDBSearchResult) -> ItemStatus {
        if rankedItems.contains(where: { $0.tmdbId == result.id }) {
            return .ranked
        }
        if watchlistItems.contains(where: { $0.tmdbId == result.id }) {
            return .watchlist
        }
        return .notAdded
    }
    
    private func handleAddAction(result: TMDBSearchResult, action: AddAction) {
        switch action {
        case .rank(let tier):
            addToRankings(result: result, tier: tier)
        case .watchlist:
            addToWatchlist(result: result)
        }
        viewModel.clearSearch()
    }
    
    private func addToRankings(result: TMDBSearchResult, tier: Tier) {
        let item = RankedItem(
            tmdbId: result.id,
            title: result.displayTitle,
            overview: result.overview ?? "",
            posterPath: result.posterPath,
            releaseDate: result.displayDate,
            mediaType: result.resolvedMediaType,
            tier: tier
        )
        
        // Set initial rank to be last in tier
        let tierCount = rankedItems.filter { $0.tier == tier }.count
        item.rank = tierCount + 1
        
        modelContext.insert(item)
        try? modelContext.save()
    }
    
    private func addToWatchlist(result: TMDBSearchResult) {
        let item = WatchlistItem(
            tmdbId: result.id,
            title: result.displayTitle,
            overview: result.overview ?? "",
            posterPath: result.posterPath,
            releaseDate: result.displayDate,
            mediaType: result.resolvedMediaType
        )
        
        modelContext.insert(item)
        try? modelContext.save()
    }
}

// MARK: - Item Status
enum ItemStatus {
    case notAdded
    case ranked
    case watchlist
}

// MARK: - Add Action
enum AddAction {
    case rank(Tier)
    case watchlist
}

// MARK: - Search Result Row
struct SearchResultRow: View {
    let result: TMDBSearchResult
    let status: ItemStatus
    
    var body: some View {
        HStack(spacing: 12) {
            // Poster
            AsyncImage(url: result.posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: result.resolvedMediaType == .movie ? "film" : "tv")
                            .foregroundStyle(.tertiary)
                    }
            }
            .frame(width: 50, height: 75)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(result.displayTitle)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    if let year = result.displayYear {
                        Text(year)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(result.resolvedMediaType == .movie ? "Movie" : "TV")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(Capsule())
                    
                    if let rating = result.voteAverage, rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.caption)
                        }
                    }
                }
            }
            
            Spacer()
            
            statusIcon
        }
        .opacity(status == .notAdded ? 1 : 0.5)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .notAdded:
            Image(systemName: "plus.circle")
                .foregroundStyle(.orange)
        case .ranked:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .watchlist:
            Image(systemName: "bookmark.fill")
                .foregroundStyle(.blue)
        }
    }
}

// MARK: - Add Item Sheet
struct AddItemSheet: View {
    let result: TMDBSearchResult
    let onSelect: (AddAction) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Movie info
                HStack(spacing: 16) {
                    AsyncImage(url: result.posterURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(.quaternary)
                    }
                    .frame(width: 80, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.displayTitle)
                            .font(.title2.bold())
                            .lineLimit(2)
                        
                        if let year = result.displayYear {
                            Text(year)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Options
                VStack(spacing: 16) {
                    // Watchlist option
                    Button {
                        onSelect(.watchlist)
                    } label: {
                        HStack {
                            Image(systemName: "bookmark")
                            Text("Add to Watchlist")
                                .fontWeight(.semibold)
                            Spacer()
                            Text("Haven't seen it")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    Text("Or rank it:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // Tier buttons
                    ForEach(Tier.allCases, id: \.self) { tier in
                        Button {
                            onSelect(.rank(tier))
                        } label: {
                            HStack {
                                Text(tier.emoji)
                                Text(tier.rawValue)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(tierColor(tier).opacity(0.15))
                            .foregroundStyle(tierColor(tier))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func tierColor(_ tier: Tier) -> Color {
        switch tier {
        case .good: return .green
        case .medium: return .yellow
        case .bad: return .red
        }
    }
}

#Preview {
    SearchView()
        .modelContainer(for: [RankedItem.self, WatchlistItem.self], inMemory: true)
}
