import SwiftUI
import SwiftData

struct SearchView: View {
    @Query private var rankedItems: [RankedItem]
    @Query private var watchlistItems: [WatchlistItem]
    @State private var viewModel = RankingViewModel()
    
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
                        NavigationLink(destination: MediaDetailView(
                            tmdbId: result.id,
                            mediaType: result.resolvedMediaType
                        )) {
                            SearchResultRow(
                                result: result,
                                status: itemStatus(result)
                            )
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
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
    
}

// MARK: - Item Status
enum ItemStatus {
    case notAdded
    case ranked
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

#Preview {
    SearchView()
        .modelContainer(for: [RankedItem.self, WatchlistItem.self], inMemory: true)
}
