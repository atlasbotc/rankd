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
        (try? JSONDecoder().decode([String].self, from: Data(recentSearchesData.utf8))) ?? []
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
                HStack(spacing: RankdSpacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(RankdColors.textTertiary)
                    
                    TextField("Search movies & TV shows...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .foregroundStyle(RankdColors.textPrimary)
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
                
                // Content
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
                    // No results state
                    Spacer()
                    VStack(spacing: RankdSpacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(RankdColors.textQuaternary)
                        
                        Text("No results for \"\(viewModel.searchQuery)\"")
                            .font(RankdTypography.headingMedium)
                            .foregroundStyle(RankdColors.textPrimary)
                            .multilineTextAlignment(.center)
                        
                        Text("Try searching with different keywords\nor check the spelling.")
                            .font(RankdTypography.bodyMedium)
                            .foregroundStyle(RankdColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .padding(RankdSpacing.lg)
                    Spacer()
                } else if viewModel.searchQuery.isEmpty {
                    // Empty state: recent searches + trending
                    ScrollView {
                        VStack(alignment: .leading, spacing: RankdSpacing.lg) {
                            // Recent searches section
                            if !recentSearches.isEmpty {
                                recentSearchesSection
                            }
                            
                            // Trending section
                            trendingSection
                        }
                        .padding(.top, RankdSpacing.xs)
                        .padding(.bottom, RankdSpacing.xl)
                    }
                    .scrollIndicators(.hidden)
                } else {
                    // Search results
                    searchResultsList
                }
            }
            .background(RankdColors.background)
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
        VStack(alignment: .leading, spacing: RankdSpacing.xs) {
            HStack {
                Text("Recent")
                    .font(RankdTypography.headingSmall)
                    .foregroundStyle(RankdColors.textPrimary)
                
                Spacer()
                
                Button {
                    withAnimation(RankdMotion.normal) {
                        clearAllRecentSearches()
                    }
                } label: {
                    Text("Clear All")
                        .font(RankdTypography.labelMedium)
                        .foregroundStyle(RankdColors.brand)
                }
            }
            .padding(.horizontal, RankdSpacing.md)
            
            VStack(spacing: 0) {
                ForEach(recentSearches, id: \.self) { query in
                    Button {
                        executeSearch(query)
                    } label: {
                        HStack(spacing: RankdSpacing.sm) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(RankdTypography.bodyMedium)
                                .foregroundStyle(RankdColors.textTertiary)
                            
                            Text(query)
                                .font(RankdTypography.bodyMedium)
                                .foregroundStyle(RankdColors.textPrimary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Button {
                                withAnimation(RankdMotion.normal) {
                                    removeRecentSearch(query)
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(RankdTypography.caption)
                                    .foregroundStyle(RankdColors.textTertiary)
                                    .frame(width: 28, height: 28)
                            }
                        }
                        .padding(.horizontal, RankdSpacing.md)
                        .padding(.vertical, RankdSpacing.sm)
                    }
                    .buttonStyle(.plain)
                    
                    if query != recentSearches.last {
                        Divider()
                            .background(RankdColors.divider)
                            .padding(.leading, RankdSpacing.md + RankdSpacing.sm + 20) // Indent past icon
                    }
                }
            }
        }
    }
    
    // MARK: - Trending Section
    
    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: RankdSpacing.xs) {
            HStack(spacing: RankdSpacing.xs) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(RankdColors.warning)
                    .font(RankdTypography.headingSmall)
                
                Text("Trending Now")
                    .font(RankdTypography.headingSmall)
                    .foregroundStyle(RankdColors.textPrimary)
            }
            .padding(.horizontal, RankdSpacing.md)
            
            if isTrendingLoading {
                VStack {
                    ProgressView()
                        .tint(RankdColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, RankdSpacing.xl)
            } else if trendingResults.isEmpty {
                Text("Unable to load trending content.")
                    .font(RankdTypography.bodyMedium)
                    .foregroundStyle(RankdColors.textTertiary)
                    .padding(.horizontal, RankdSpacing.md)
                    .padding(.vertical, RankdSpacing.lg)
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
            .listRowBackground(RankdColors.background)
            .listRowInsets(EdgeInsets(
                top: RankdSpacing.xs,
                leading: RankdSpacing.md,
                bottom: RankdSpacing.xs,
                trailing: RankdSpacing.md
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
        HStack(spacing: RankdSpacing.sm) {
            // Poster thumbnail
            CachedPosterImage(
                url: result.posterURL,
                width: RankdPoster.thumbWidth,
                height: RankdPoster.thumbHeight,
                cornerRadius: RankdRadius.sm,
                placeholderIcon: result.resolvedMediaType == .movie ? "film" : "tv"
            )
            
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
                    
                    // Media type badge
                    Text(result.resolvedMediaType == .movie ? "Movie" : "TV")
                        .font(RankdTypography.labelSmall)
                        .foregroundStyle(RankdColors.brand)
                        .padding(.horizontal, RankdSpacing.xxs + 2)
                        .padding(.vertical, 2)
                        .background(RankdColors.brandSubtle)
                        .clipShape(RoundedRectangle(cornerRadius: RankdRadius.sm / 2))
                    
                    // TMDB rating
                    if let rating = result.voteAverage, rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(RankdColors.warning)
                            Text(String(format: "%.1f", rating))
                                .font(RankdTypography.labelSmall)
                                .foregroundStyle(RankdColors.textSecondary)
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
                .fill(RankdColors.tierGood)
                .frame(width: 8, height: 8)
        case .watchlist:
            Circle()
                .fill(RankdColors.brand)
                .frame(width: 8, height: 8)
        }
    }
}

// MARK: - Trending Row

struct TrendingRow: View {
    let result: TMDBSearchResult
    
    var body: some View {
        HStack(spacing: RankdSpacing.sm) {
            // Poster thumbnail
            CachedPosterImage(
                url: result.posterURL,
                width: RankdPoster.thumbWidth,
                height: RankdPoster.thumbHeight,
                cornerRadius: RankdRadius.sm,
                placeholderIcon: result.resolvedMediaType == .movie ? "film" : "tv"
            )
            
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
                    
                    // Media type badge
                    Text(result.resolvedMediaType == .movie ? "Movie" : "TV")
                        .font(RankdTypography.labelSmall)
                        .foregroundStyle(RankdColors.brand)
                        .padding(.horizontal, RankdSpacing.xxs + 2)
                        .padding(.vertical, 2)
                        .background(RankdColors.brandSubtle)
                        .clipShape(RoundedRectangle(cornerRadius: RankdRadius.sm / 2))
                    
                    // TMDB rating
                    if let rating = result.voteAverage, rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(RankdColors.warning)
                            Text(String(format: "%.1f", rating))
                                .font(RankdTypography.labelSmall)
                                .foregroundStyle(RankdColors.textSecondary)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, RankdSpacing.md)
        .padding(.vertical, RankdSpacing.xs)
    }
}

// MARK: - Search Suggestion Flow (kept for potential future use)

private struct SearchSuggestionFlow: View {
    let suggestions: [String]
    let onTap: (String) -> Void
    
    var body: some View {
        WrappingHStack(alignment: .center, spacing: RankdSpacing.xs) {
            ForEach(suggestions, id: \.self) { title in
                Button {
                    onTap(title)
                } label: {
                    Text(title)
                        .font(RankdTypography.labelMedium)
                        .foregroundStyle(RankdColors.textSecondary)
                        .padding(.horizontal, RankdSpacing.sm)
                        .padding(.vertical, RankdSpacing.xs)
                        .background(RankdColors.surfaceSecondary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct WrappingHStack: Layout {
    var alignment: Alignment = .center
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }
    
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }
        
        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

#Preview {
    SearchView()
        .modelContainer(for: [RankedItem.self, WatchlistItem.self], inMemory: true)
}
