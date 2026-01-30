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
            .background(RankdColors.background)
            .navigationTitle("Watchlist")
            .refreshable {}
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
        VStack(spacing: RankdSpacing.sm) {
            Spacer()
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 50))
                .foregroundStyle(RankdColors.textQuaternary)
            Text("Watchlist empty")
                .font(RankdTypography.headingMedium)
                .foregroundStyle(RankdColors.textPrimary)
            Text("Search for movies & shows to add")
                .font(RankdTypography.bodySmall)
                .foregroundStyle(RankdColors.textTertiary)
            Spacer()
        }
    }
    
    private var watchlist: some View {
        List {
            ForEach(items) { item in
                WatchlistRow(item: item)
                    .listRowBackground(RankdColors.background)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            itemToDelete = item
                            showDeleteConfirmation = true
                            HapticManager.notification(.warning)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                        .tint(RankdColors.error)
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
                        .tint(RankdColors.success)
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
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
        HStack(spacing: RankdSpacing.sm) {
            // Poster
            AsyncImage(url: item.posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: RankdRadius.sm)
                    .fill(RankdColors.surfaceSecondary)
                    .overlay {
                        Image(systemName: item.mediaType == .movie ? "film" : "tv")
                            .foregroundStyle(RankdColors.textQuaternary)
                    }
            }
            .frame(width: RankdPoster.thumbWidth, height: RankdPoster.thumbHeight)
            .clipShape(RoundedRectangle(cornerRadius: RankdRadius.sm))
            
            // Info
            VStack(alignment: .leading, spacing: RankdSpacing.xxs) {
                Text(item.title)
                    .font(RankdTypography.headingSmall)
                    .foregroundStyle(RankdColors.textPrimary)
                    .lineLimit(2)
                
                HStack(spacing: RankdSpacing.xs) {
                    if let year = item.year {
                        Text(year)
                            .font(RankdTypography.labelSmall)
                            .foregroundStyle(RankdColors.textTertiary)
                    }
                    
                    Text(item.mediaType == .movie ? "Movie" : "TV")
                        .font(RankdTypography.labelSmall)
                        .foregroundStyle(RankdColors.textTertiary)
                }
                
                Text("Added \(item.dateAdded.formatted(.relative(presentation: .named)))")
                    .font(RankdTypography.caption)
                    .foregroundStyle(RankdColors.textTertiary)
            }
            
            Spacer()
        }
        .padding(.vertical, RankdSpacing.xxs)
    }
}

#Preview {
    WatchlistView()
        .modelContainer(for: WatchlistItem.self, inMemory: true)
}
