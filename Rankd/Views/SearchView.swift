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
                HStack(spacing: RankdSpacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(RankdColors.textTertiary)
                    
                    TextField("Search movies & TV shows...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .foregroundStyle(RankdColors.textPrimary)
                        .onChange(of: viewModel.searchQuery) { _, _ in
                            viewModel.search()
                        }
                    
                    if !viewModel.searchQuery.isEmpty {
                        Button {
                            viewModel.clearSearch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(RankdColors.textTertiary)
                        }
                    }
                }
                .padding(RankdSpacing.sm)
                .frame(minHeight: 44)
                .background(RankdColors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: RankdRadius.md))
                .padding(.horizontal, RankdSpacing.md)
                .padding(.vertical, RankdSpacing.xs)
                
                // Results
                if viewModel.isSearching {
                    Spacer()
                    ProgressView("Searching...")
                        .tint(RankdColors.textTertiary)
                        .foregroundStyle(RankdColors.textSecondary)
                    Spacer()
                } else if let error = viewModel.searchError {
                    Spacer()
                    VStack(spacing: RankdSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(RankdTypography.displayMedium)
                            .foregroundStyle(RankdColors.textTertiary)
                        Text(error)
                            .font(RankdTypography.bodyMedium)
                            .foregroundStyle(RankdColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(RankdSpacing.md)
                    Spacer()
                } else if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty {
                    Spacer()
                    VStack(spacing: RankdSpacing.sm) {
                        Image(systemName: "film")
                            .font(RankdTypography.displayMedium)
                            .foregroundStyle(RankdColors.textQuaternary)
                        Text("No results found")
                            .font(RankdTypography.bodyMedium)
                            .foregroundStyle(RankdColors.textSecondary)
                    }
                    Spacer()
                } else if viewModel.searchQuery.isEmpty {
                    Spacer()
                    VStack(spacing: RankdSpacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundStyle(RankdColors.textQuaternary)
                        Text("Search for movies or TV shows")
                            .font(RankdTypography.bodyMedium)
                            .foregroundStyle(RankdColors.textSecondary)
                        Text("Add to rankings or watchlist")
                            .font(RankdTypography.caption)
                            .foregroundStyle(RankdColors.textTertiary)
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
                        .listRowBackground(RankdColors.background)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(RankdColors.background)
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
        HStack(spacing: RankdSpacing.sm) {
            // Poster
            AsyncImage(url: result.posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: RankdRadius.sm)
                    .fill(RankdColors.surfaceSecondary)
                    .overlay {
                        Image(systemName: result.resolvedMediaType == .movie ? "film" : "tv")
                            .foregroundStyle(RankdColors.textQuaternary)
                    }
            }
            .frame(width: RankdPoster.thumbWidth, height: RankdPoster.thumbHeight)
            .clipShape(RoundedRectangle(cornerRadius: RankdRadius.sm))
            
            // Info
            VStack(alignment: .leading, spacing: RankdSpacing.xxs) {
                Text(result.displayTitle)
                    .font(RankdTypography.headingSmall)
                    .foregroundStyle(RankdColors.textPrimary)
                    .lineLimit(2)
                
                HStack(spacing: RankdSpacing.xs) {
                    if let year = result.displayYear {
                        Text(year)
                            .font(RankdTypography.labelSmall)
                            .foregroundStyle(RankdColors.textTertiary)
                    }
                    
                    Text(result.resolvedMediaType == .movie ? "Movie" : "TV")
                        .font(RankdTypography.labelSmall)
                        .foregroundStyle(RankdColors.textTertiary)
                }
            }
            
            Spacer()
            
            // Status indicator
            statusIndicator
        }
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        switch status {
        case .notAdded:
            EmptyView()
        case .ranked:
            Circle()
                .fill(RankdColors.tierGood)
                .frame(width: 8, height: 8)
        case .watchlist:
            Circle()
                .fill(Color(red: 0.3, green: 0.5, blue: 0.9))
                .frame(width: 8, height: 8)
        }
    }
}

#Preview {
    SearchView()
        .modelContainer(for: [RankedItem.self, WatchlistItem.self], inMemory: true)
}
