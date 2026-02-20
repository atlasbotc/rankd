import SwiftUI
import SwiftData

struct SearchView: View {
    @Query private var rankedItems: [RankedItem]
    @Query private var watchlistItems: [WatchlistItem]
    @State private var viewModel = RankingViewModel()
    @State private var trendingResults: [TMDBSearchResult] = []
    @State private var isTrendingLoading = false
    @AppStorage("recentSearches") private var recentSearchesData: String = "[]"
    
    private var recentSearches: [String] {
        do {
            return try JSONDecoder().decode([String].self, from: Data(recentSearchesData.utf8))
        } catch {
            print("⚠️ Failed to decode recentSearches, resetting: \(error)")
            // Schedule reset on next run loop to avoid modifying state during view update
            DispatchQueue.main.async { [self] in
                self.recentSearchesData = "[]"
            }
            return []
        }
    }
    
    private func saveRecentSearches(_ searches: [String]) {
        if let data = try? JSONEncoder().encode(searches),
           let str = String(data: data, encoding: .utf8) {
            recentSearchesData = str
        }
    }
    
    private func addRecentSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var searches = recentSearches
        searches.removeAll { $0.lowercased() == trimmed.lowercased() }
        searches.insert(trimmed, at: 0)
        if searches.count > 10 {
            searches = Array(searches.prefix(10))
        }
        saveRecentSearches(searches)
    }
    
    private func removeRecentSearch(_ query: String) {
        var searches = recentSearches
        searches.removeAll { $0 == query }
        saveRecentSearches(searches)
    }
    
    private func clearAllRecentSearches() {
        saveRecentSearches([])
    }
    
    private func executeSearch(_ query: String) {
        viewModel.searchQuery = query
        addRecentSearch(query)
        viewModel.search()
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: MarquiSpacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(MarquiColors.textTertiary)
                    
                    TextField("Search movies & TV shows...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .foregroundStyle(MarquiColors.textPrimary)
                        .onSubmit {
                            addRecentSearch(viewModel.searchQuery)
                        }
                        .onChange(of: viewModel.searchQuery) { _, newValue in
                            viewModel.search()
                            // Save to recents when search completes (after debounce triggers results)
                        }
                    
                    if !viewModel.searchQuery.isEmpty {
                        Button {
                            viewModel.clearSearch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(MarquiColors.textTertiary)
                        }
                    }
                }
                .padding(MarquiSpacing.sm)
                .frame(minHeight: 44)
                .background(MarquiColors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: MarquiRadius.md))
                .padding(.horizontal, MarquiSpacing.md)
                .padding(.vertical, MarquiSpacing.xs)
                
                // Content
                if viewModel.isSearching {
                    Spacer()
                    ProgressView("Searching...")
                        .tint(MarquiColors.textTertiary)
                        .foregroundStyle(MarquiColors.textSecondary)
                    Spacer()
                } else if let error = viewModel.searchError {
                    Spacer()
                    VStack(spacing: MarquiSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(MarquiTypography.displayMedium)
                            .foregroundStyle(MarquiColors.textTertiary)
                        Text(error)
                            .font(MarquiTypography.bodyMedium)
                            .foregroundStyle(MarquiColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(MarquiSpacing.md)
                    Spacer()
                } else if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty {
                    // No results state
                    Spacer()
                    VStack(spacing: MarquiSpacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(MarquiColors.textQuaternary)
                        
                        Text("No results for \"\(viewModel.searchQuery)\"")
                            .font(MarquiTypography.headingMedium)
                            .foregroundStyle(MarquiColors.textPrimary)
                            .multilineTextAlignment(.center)
                        
                        Text("Try searching with different keywords\nor check the spelling.")
                            .font(MarquiTypography.bodyMedium)
                            .foregroundStyle(MarquiColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .padding(MarquiSpacing.lg)
                    Spacer()
                } else if viewModel.searchQuery.isEmpty {
                    // Empty state: recent searches + trending
                    ScrollView {
                        VStack(alignment: .leading, spacing: MarquiSpacing.lg) {
                            // Recent searches section
                            if !recentSearches.isEmpty {
                                recentSearchesSection
                            }
                            
                            // Trending section
                            trendingSection
                        }
                        .padding(.top, MarquiSpacing.xs)
                        .padding(.bottom, MarquiSpacing.xl)
                    }
                    .scrollIndicators(.hidden)
                } else {
                    // Search results
                    searchResultsList
                }
            }
            .background(MarquiColors.background)
            .navigationTitle("Search")
            .task {
                await loadTrending()
            }
            .onChange(of: viewModel.searchResults) { _, newResults in
                // Save to recent when results come in
                if !newResults.isEmpty && !viewModel.searchQuery.isEmpty {
                    addRecentSearch(viewModel.searchQuery)
                }
            }
        }
    }
    
    // MARK: - Recent Searches Section
    
    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: MarquiSpacing.xs) {
            HStack {
                Text("Recent")
                    .font(MarquiTypography.headingSmall)
                    .foregroundStyle(MarquiColors.textPrimary)
                
                Spacer()
                
                Button {
                    withAnimation(MarquiMotion.normal) {
                        clearAllRecentSearches()
                    }
                } label: {
                    Text("Clear All")
                        .font(MarquiTypography.labelMedium)
                        .foregroundStyle(MarquiColors.brand)
                }
            }
            .padding(.horizontal, MarquiSpacing.md)
            
            VStack(spacing: 0) {
                ForEach(recentSearches, id: \.self) { query in
                    Button {
                        executeSearch(query)
                    } label: {
                        HStack(spacing: MarquiSpacing.sm) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(MarquiTypography.bodyMedium)
                                .foregroundStyle(MarquiColors.textTertiary)
                            
                            Text(query)
                                .font(MarquiTypography.bodyMedium)
                                .foregroundStyle(MarquiColors.textPrimary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Button {
                                withAnimation(MarquiMotion.normal) {
                                    removeRecentSearch(query)
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(MarquiTypography.caption)
                                    .foregroundStyle(MarquiColors.textTertiary)
                                    .frame(width: 28, height: 28)
                            }
                        }
                        .padding(.horizontal, MarquiSpacing.md)
                        .padding(.vertical, MarquiSpacing.sm)
                    }
                    .buttonStyle(.plain)
                    
                    if query != recentSearches.last {
                        Divider()
                            .background(MarquiColors.divider)
                            .padding(.leading, MarquiSpacing.md + MarquiSpacing.sm + 20) // Indent past icon
                    }
                }
            }
        }
    }
    
    // MARK: - Trending Section
    
    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: MarquiSpacing.xs) {
            HStack(spacing: MarquiSpacing.xs) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(MarquiColors.warning)
                    .font(MarquiTypography.headingSmall)
                
                Text("Trending Now")
                    .font(MarquiTypography.headingSmall)
                    .foregroundStyle(MarquiColors.textPrimary)
            }
            .padding(.horizontal, MarquiSpacing.md)
            
            if isTrendingLoading {
                VStack {
                    ProgressView()
                        .tint(MarquiColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, MarquiSpacing.xl)
            } else if trendingResults.isEmpty {
                Text("Unable to load trending content.")
                    .font(MarquiTypography.bodyMedium)
                    .foregroundStyle(MarquiColors.textTertiary)
                    .padding(.horizontal, MarquiSpacing.md)
                    .padding(.vertical, MarquiSpacing.lg)
            } else {
                VStack(spacing: 0) {
                    ForEach(trendingResults.prefix(15)) { result in
                        NavigationLink(destination: MediaDetailView(
                            tmdbId: result.id,
                            mediaType: result.resolvedMediaType
                        )) {
                            TrendingRow(result: result)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    // MARK: - Search Results List
    
    private var searchResultsList: some View {
        List(viewModel.searchResults) { result in
            NavigationLink(destination: MediaDetailView(
                tmdbId: result.id,
                mediaType: result.resolvedMediaType
            )) {
                EnhancedSearchResultRow(
                    result: result,
                    status: itemStatus(result)
                )
            }
            .listRowBackground(MarquiColors.background)
            .listRowInsets(EdgeInsets(
                top: MarquiSpacing.xs,
                leading: MarquiSpacing.md,
                bottom: MarquiSpacing.xs,
                trailing: MarquiSpacing.md
            ))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Helpers
    
    private func loadTrending() async {
        guard trendingResults.isEmpty else { return }
        isTrendingLoading = true
        do {
            let results = try await TMDBService.shared.getTrending(mediaType: "all", timeWindow: "day")
            await MainActor.run {
                trendingResults = results
                isTrendingLoading = false
            }
        } catch {
            await MainActor.run {
                isTrendingLoading = false
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
}

// MARK: - Item Status
enum ItemStatus {
    case notAdded
    case ranked
    case watchlist
}

// MARK: - Enhanced Search Result Row

struct EnhancedSearchResultRow: View {
    let result: TMDBSearchResult
    let status: ItemStatus
    
    var body: some View {
        HStack(spacing: MarquiSpacing.sm) {
            // Poster thumbnail
            CachedPosterImage(
                url: result.posterURL,
                width: MarquiPoster.thumbWidth,
                height: MarquiPoster.thumbHeight,
                cornerRadius: MarquiRadius.sm,
                placeholderIcon: result.resolvedMediaType == .movie ? "film" : "tv"
            )
            
            // Info
            VStack(alignment: .leading, spacing: MarquiSpacing.xxs) {
                Text(result.displayTitle)
                    .font(MarquiTypography.headingSmall)
                    .foregroundStyle(MarquiColors.textPrimary)
                    .lineLimit(2)
                
                HStack(spacing: MarquiSpacing.xs) {
                    if let year = result.displayYear {
                        Text(year)
                            .font(MarquiTypography.labelSmall)
                            .foregroundStyle(MarquiColors.textTertiary)
                    }
                    
                    // Media type badge
                    Text(result.resolvedMediaType == .movie ? "Movie" : "TV")
                        .font(MarquiTypography.labelSmall)
                        .foregroundStyle(MarquiColors.brand)
                        .padding(.horizontal, MarquiSpacing.xxs + 2)
                        .padding(.vertical, 2)
                        .background(MarquiColors.brandSubtle)
                        .clipShape(RoundedRectangle(cornerRadius: MarquiRadius.sm / 2))
                    
                    // TMDB rating
                    if let rating = result.voteAverage, rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(MarquiColors.warning)
                            Text(String(format: "%.1f", rating))
                                .font(MarquiTypography.labelSmall)
                                .foregroundStyle(MarquiColors.textSecondary)
                        }
                    }
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
                .fill(MarquiColors.tierGood)
                .frame(width: 8, height: 8)
        case .watchlist:
            Circle()
                .fill(MarquiColors.brand)
                .frame(width: 8, height: 8)
        }
    }
}

// MARK: - Trending Row

struct TrendingRow: View {
    let result: TMDBSearchResult
    
    var body: some View {
        HStack(spacing: MarquiSpacing.sm) {
            // Poster thumbnail
            CachedPosterImage(
                url: result.posterURL,
                width: MarquiPoster.thumbWidth,
                height: MarquiPoster.thumbHeight,
                cornerRadius: MarquiRadius.sm,
                placeholderIcon: result.resolvedMediaType == .movie ? "film" : "tv"
            )
            
            // Info
            VStack(alignment: .leading, spacing: MarquiSpacing.xxs) {
                Text(result.displayTitle)
                    .font(MarquiTypography.headingSmall)
                    .foregroundStyle(MarquiColors.textPrimary)
                    .lineLimit(2)
                
                HStack(spacing: MarquiSpacing.xs) {
                    if let year = result.displayYear {
                        Text(year)
                            .font(MarquiTypography.labelSmall)
                            .foregroundStyle(MarquiColors.textTertiary)
                    }
                    
                    // Media type badge
                    Text(result.resolvedMediaType == .movie ? "Movie" : "TV")
                        .font(MarquiTypography.labelSmall)
                        .foregroundStyle(MarquiColors.brand)
                        .padding(.horizontal, MarquiSpacing.xxs + 2)
                        .padding(.vertical, 2)
                        .background(MarquiColors.brandSubtle)
                        .clipShape(RoundedRectangle(cornerRadius: MarquiRadius.sm / 2))
                    
                    // TMDB rating
                    if let rating = result.voteAverage, rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(MarquiColors.warning)
                            Text(String(format: "%.1f", rating))
                                .font(MarquiTypography.labelSmall)
                                .foregroundStyle(MarquiColors.textSecondary)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, MarquiSpacing.md)
        .padding(.vertical, MarquiSpacing.xs)
    }
}

#Preview {
    SearchView()
        .modelContainer(for: [RankedItem.self, WatchlistItem.self], inMemory: true)
}
