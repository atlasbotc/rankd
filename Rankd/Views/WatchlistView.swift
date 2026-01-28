import SwiftUI
import SwiftData

struct WatchlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WatchlistItem.dateAdded, order: .reverse) private var items: [WatchlistItem]
    @Query private var rankedItems: [RankedItem]
    
    @State private var itemToRank: WatchlistItem?
    @State private var showComparisonFlow = false
    @State private var itemToDelete: WatchlistItem?
    @State private var showDeleteConfirmation = false
    @State private var searchResultToRank: TMDBSearchResult?
    
var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyState
                } else {
                    watchlist
                }
            }
            .navigationTitle("Watchlist")
            .alert("Remove from Watchlist?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    if let item = itemToDelete {
                        deleteItem(item)
                    }
                }
            } message: {
                if let item = itemToDelete {
                    Text("Remove \"\(item.title)\" from your watchlist?")
                }
            }
            .fullScreenCover(isPresented: $showComparisonFlow) {
                if let result = searchResultToRank {
                    ComparisonFlowView(newItem: result)
                }
            }
            .onChange(of: showComparisonFlow) { _, isShowing in
                if !isShowing {
                    // Check if item was actually ranked, then remove from watchlist
                    if let item = itemToRank,
                       rankedItems.contains(where: { $0.tmdbId == item.tmdbId }) {
                        modelContext.delete(item)
                        try? modelContext.save()
                    }
                    itemToRank = nil
                    searchResultToRank = nil
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text("Watchlist empty")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Search for movies & shows to add")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }
    
    private var watchlist: some View {
        List {
            ForEach(items) { item in
                WatchlistRow(item: item)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            itemToDelete = item
                            showDeleteConfirmation = true
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            itemToRank = item
                            searchResultToRank = TMDBSearchResult(
                                id: item.tmdbId,
                                title: item.mediaType == .movie ? item.title : nil,
                                name: item.mediaType == .tv ? item.title : nil,
                                overview: item.overview,
                                posterPath: item.posterPath,
                                releaseDate: item.mediaType == .movie ? item.releaseDate : nil,
                                firstAirDate: item.mediaType == .tv ? item.releaseDate : nil,
                                mediaType: item.mediaType.rawValue,
                                voteAverage: nil
                            )
                            showComparisonFlow = true
                        } label: {
                            Label("Watched", systemImage: "checkmark.circle")
                        }
                        .tint(.green)
                    }
            }
        }
        .listStyle(.plain)
    }
    
    private func deleteItem(_ item: WatchlistItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }
}

// MARK: - Watchlist Row
struct WatchlistRow: View {
    let item: WatchlistItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Poster
            AsyncImage(url: item.posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: item.mediaType == .movie ? "film" : "tv")
                            .foregroundStyle(.tertiary)
                    }
            }
            .frame(width: 50, height: 75)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    if let year = item.year {
                        Text(year)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(item.mediaType == .movie ? "Movie" : "TV")
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
                
                Text("Added \(item.dateAdded.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            // Swipe hint
            VStack(spacing: 4) {
                Image(systemName: "hand.point.left.fill")
                    .font(.caption)
                    .foregroundStyle(.green.opacity(0.5))
                Text("Swipe")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    WatchlistView()
        .modelContainer(for: WatchlistItem.self, inMemory: true)
}
