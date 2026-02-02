import SwiftUI
import SwiftData

// MARK: - Personalized Recommendation Data

struct RecommendationSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [TMDBSearchResult]
}

struct GenreRecommendation: Identifiable {
    let id = UUID()
    let genre: TMDBGenre
    let items: [TMDBSearchResult]
}

struct DiscoverView: View {
    @Query private var rankedItems: [RankedItem]
    @Query private var watchlistItems: [WatchlistItem]
    @Query(sort: \CustomList.dateModified, order: .reverse) private var customLists: [CustomList]
    
    // Generic sections
    @State private var trending: [TMDBSearchResult] = []
    @State private var popularMovies: [TMDBSearchResult] = []
    @State private var popularTV: [TMDBSearchResult] = []
    @State private var topRatedMovies: [TMDBSearchResult] = []
    @State private var topRatedTV: [TMDBSearchResult] = []
    @State private var genres: [TMDBGenre] = []
    
    // Personalized sections
    @State private var becauseYouLoved: [RecommendationSection] = []
    @State private var genreRecommendations: [GenreRecommendation] = []
    @State private var hiddenGems: [TMDBSearchResult] = []
    
    @State private var isLoading = true
    @State private var isPersonalizedLoading = true
    @State private var error: String?
    @State private var lastGenericLoadTime: Date?
    
    /// Cache TTL for generic content (trending, popular, etc.) — 5 minutes
    private let genericCacheTTL: TimeInterval = 5 * 60
    
    private var hasRankedItems: Bool {
        !rankedItems.isEmpty
    }
    
    private var greenTierItems: [RankedItem] {
        rankedItems
            .filter { $0.tier == .good }
            .sorted { $0.rank < $1.rank }
    }
    
    /// Set of TMDB IDs the user has already ranked or watchlisted
    private var excludedIds: Set<Int> {
        let ranked = Set(rankedItems.map { $0.tmdbId })
        let watchlisted = Set(watchlistItems.map { $0.tmdbId })
        return ranked.union(watchlisted)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    discoverSkeleton
                } else if let error = error {
                    errorView(error)
                } else {
                    scrollContent
                }
            }
            .background(RankdColors.background)
            .toolbarBackground(RankdColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationTitle("Discover")
            .refreshable {
                await loadAllContent(forceRefresh: true)
                HapticManager.impact(.light)
            }
            .task {
                await loadAllContent()
            }
        }
    }
    
    // MARK: - Scroll Content
    
    private var scrollContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                
                // MARK: New User Welcome
                if !hasRankedItems {
                    welcomeHeader
                        .padding(.top, RankdSpacing.lg)
                }
                
                // MARK: Personalized Sections
                if hasRankedItems {
                    personalizedContent
                        .padding(.top, RankdSpacing.lg)
                }
                
                // MARK: Your Lists
                if !customLists.isEmpty {
                    discoverListsSection
                        .padding(.top, RankdSpacing.lg)
                }
                
                // MARK: Generic Sections
                genericContent
                    .padding(.top, RankdSpacing.lg)
            }
            .padding(.bottom, RankdSpacing.xl)
        }
        .scrollIndicators(.hidden)
        .background(RankdColors.background)
    }
    
    // MARK: - Your Lists on Discover
    
    private var discoverListsSection: some View {
        VStack(alignment: .leading, spacing: RankdSpacing.sm) {
            HStack {
                Text("YOUR LISTS")
                    .font(RankdTypography.sectionLabel)
                    .tracking(1.5)
                    .foregroundStyle(RankdColors.textTertiary)
                Spacer()
                NavigationLink {
                    ListsView()
                } label: {
                    Text("See All")
                        .font(RankdTypography.labelMedium)
                        .foregroundStyle(RankdColors.brand)
                }
            }
            .padding(.horizontal, RankdSpacing.md)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: RankdSpacing.sm) {
                    ForEach(customLists.prefix(6)) { list in
                        NavigationLink(destination: ListDetailView(list: list)) {
                            ListPreviewCard(list: list)
                        }
                        .buttonStyle(RankdPressStyle())
                    }
                }
                .padding(.horizontal, RankdSpacing.md)
            }
        }
    }
    
    // MARK: - Welcome Header
    
    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: RankdSpacing.sm) {
            Text("Welcome to Marqui")
                .font(RankdTypography.headingLarge)
                .foregroundStyle(RankdColors.textPrimary)
            
            Text("Start ranking movies and shows to unlock recommendations tailored to your taste.")
                .font(RankdTypography.bodyMedium)
                .foregroundStyle(RankdColors.textSecondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RankdSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: RankdRadius.lg)
                .fill(RankdColors.surfacePrimary)
        )
        .padding(.horizontal, RankdSpacing.md)
    }
    
    // MARK: - Personalized Content
    
    private var personalizedContent: some View {
        Group {
            if isPersonalizedLoading {
                personalizedLoadingPlaceholder
            } else {
                VStack(alignment: .leading, spacing: RankdSpacing.lg) {
                    // "Because you loved [Title]" sections
                    ForEach(becauseYouLoved) { section in
                        DiscoverSection(
                            title: section.title,
                            items: section.items
                        )
                    }
                    
                    // "More [Genre] for you" sections
                    ForEach(genreRecommendations) { section in
                        DiscoverSection(
                            title: "More \(section.genre.name) For You",
                            items: section.items
                        )
                    }
                    
                    // Hidden gems
                    if !hiddenGems.isEmpty {
                        DiscoverSection(
                            title: "Hidden Gems",
                            items: hiddenGems
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Loading Placeholder
    
    private var personalizedLoadingPlaceholder: some View {
        VStack(alignment: .leading, spacing: RankdSpacing.lg) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(alignment: .leading, spacing: RankdSpacing.sm) {
                    RoundedRectangle(cornerRadius: RankdRadius.sm)
                        .fill(RankdColors.surfaceSecondary)
                        .frame(width: 200, height: 20)
                        .shimmer()
                        .padding(.horizontal, RankdSpacing.md)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: RankdSpacing.sm) {
                            ForEach(0..<5, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: RankdPoster.cornerRadius)
                                    .fill(RankdColors.surfaceSecondary)
                                    .frame(width: RankdPoster.standardWidth, height: RankdPoster.standardHeight)
                                    .shimmer()
                            }
                        }
                        .padding(.horizontal, RankdSpacing.md)
                    }
                }
            }
        }
    }
    
    // MARK: - Generic Content
    
    private var genericContent: some View {
        VStack(alignment: .leading, spacing: RankdSpacing.lg) {
            // Trending (skip first since it's the hero)
            if trending.count > 1 {
                DiscoverSection(
                    title: "Trending",
                    items: Array(trending.dropFirst())
                )
            }
            
            // Popular Movies
            if !popularMovies.isEmpty {
                DiscoverSection(
                    title: "Popular Movies",
                    items: popularMovies
                )
            }
            
            // Popular TV
            if !popularTV.isEmpty {
                DiscoverSection(
                    title: "Popular TV Shows",
                    items: popularTV
                )
            }
            
            // Top Rated Movies
            if !topRatedMovies.isEmpty {
                DiscoverSection(
                    title: "Top Rated Movies",
                    items: topRatedMovies
                )
            }
            
            // Top Rated TV
            if !topRatedTV.isEmpty {
                DiscoverSection(
                    title: "Top Rated TV",
                    items: topRatedTV
                )
            }
            
            // Genres
            if !genres.isEmpty {
                GenreGrid(genres: genres)
            }
        }
    }
    
    // MARK: - Skeleton Loading
    
    private var discoverSkeleton: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero skeleton
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 0)
                        .fill(RankdColors.surfacePrimary)
                        .shimmer()
                        .frame(height: geo.size.height * 0.55)
                }
                .frame(height: 400) // fallback height
                
                VStack(alignment: .leading, spacing: RankdSpacing.lg) {
                    ForEach(0..<3, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: RankdSpacing.sm) {
                            RoundedRectangle(cornerRadius: RankdRadius.sm)
                                .fill(RankdColors.surfaceSecondary)
                                .frame(width: 180, height: 22)
                                .shimmer()
                                .padding(.horizontal, RankdSpacing.md)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: RankdSpacing.sm) {
                                    ForEach(0..<5, id: \.self) { _ in
                                        VStack(alignment: .leading, spacing: RankdSpacing.xs) {
                                            RoundedRectangle(cornerRadius: RankdPoster.cornerRadius)
                                                .fill(RankdColors.surfaceSecondary)
                                                .frame(width: RankdPoster.standardWidth, height: RankdPoster.standardHeight)
                                                .shimmer()
                                            RoundedRectangle(cornerRadius: RankdRadius.sm)
                                                .fill(RankdColors.surfaceSecondary)
                                                .frame(width: 100, height: 12)
                                                .shimmer()
                                        }
                                    }
                                }
                                .padding(.horizontal, RankdSpacing.md)
                            }
                        }
                    }
                }
                .padding(.top, RankdSpacing.lg)
            }
        }
        .scrollIndicators(.hidden)
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: RankdSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(RankdColors.textTertiary)
            
            Text("Something went wrong")
                .font(RankdTypography.headingMedium)
                .foregroundStyle(RankdColors.textPrimary)
            
            Text(message)
                .font(RankdTypography.bodyMedium)
                .multilineTextAlignment(.center)
                .foregroundStyle(RankdColors.textSecondary)
            
            Button {
                Task { await loadAllContent(forceRefresh: true) }
            } label: {
                Text("Try Again")
                    .font(RankdTypography.labelLarge)
                    .foregroundStyle(.white)
                    .padding(.horizontal, RankdSpacing.lg)
                    .frame(height: 48)
                    .background(
                        LinearGradient(
                            colors: [RankdColors.gradientStart, RankdColors.gradientEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: RankdColors.brand.opacity(0.4), radius: 8, y: 4)
            }
            .padding(.top, RankdSpacing.xs)
        }
        .padding(RankdSpacing.lg)
    }
    
    // MARK: - Data Loading
    
    private func loadAllContent(forceRefresh: Bool = false) async {
        if forceRefresh {
            lastGenericLoadTime = nil
        }
        isLoading = error != nil
        error = nil
        
        async let genericTask: () = loadGenericContent()
        async let personalizedTask: () = loadPersonalizedContent()
        
        _ = await (genericTask, personalizedTask)
    }
    
    private func loadGenericContent() async {
        // Skip re-fetch if cache is still fresh
        if let lastLoad = lastGenericLoadTime,
           Date().timeIntervalSince(lastLoad) < genericCacheTTL,
           !trending.isEmpty {
            isLoading = false
            return
        }
        
        do {
            async let trendingTask = TMDBService.shared.getTrending()
            async let popularMoviesTask = TMDBService.shared.getPopularMovies()
            async let popularTVTask = TMDBService.shared.getPopularTV()
            async let topRatedMoviesTask = TMDBService.shared.getTopRatedMovies()
            async let topRatedTVTask = TMDBService.shared.getTopRatedTV()
            async let genresTask = TMDBService.shared.getMovieGenres()
            
            let (t, pm, ptv, trm, trtv, g) = try await (
                trendingTask,
                popularMoviesTask,
                popularTVTask,
                topRatedMoviesTask,
                topRatedTVTask,
                genresTask
            )
            
            trending = t
            popularMovies = pm
            popularTV = ptv
            topRatedMovies = trm
            topRatedTV = trtv
            genres = g
            lastGenericLoadTime = Date()
            
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func loadPersonalizedContent() async {
        guard hasRankedItems else {
            isPersonalizedLoading = false
            return
        }
        
        isPersonalizedLoading = true
        
        let excluded = excludedIds
        
        async let lovedTask = loadBecauseYouLoved(excluded: excluded)
        async let genreTask = loadGenreRecommendations(excluded: excluded)
        
        let (lovedSections, genreSections) = await (lovedTask, genreTask)
        
        becauseYouLoved = lovedSections
        genreRecommendations = genreSections
        
        buildHiddenGems(from: lovedSections, genres: genreSections, excluded: excluded)
        
        isPersonalizedLoading = false
    }
    
    // MARK: - "Because you loved [Title]"
    
    private func loadBecauseYouLoved(excluded: Set<Int>) async -> [RecommendationSection] {
        let topItems = Array(greenTierItems.prefix(3))
        guard !topItems.isEmpty else { return [] }
        
        var sections: [RecommendationSection] = []
        
        await withTaskGroup(of: RecommendationSection?.self) { group in
            for item in topItems {
                group.addTask {
                    do {
                        let results: [TMDBSearchResult]
                        if item.mediaType == .movie {
                            results = try await TMDBService.shared.getMovieRecommendations(movieId: item.tmdbId)
                        } else {
                            results = try await TMDBService.shared.getTVRecommendations(tvId: item.tmdbId)
                        }
                        
                        let filtered = results.filter { !excluded.contains($0.id) }
                        guard !filtered.isEmpty else { return nil }
                        
                        return RecommendationSection(
                            title: "Because you loved \(item.title)",
                            items: Array(filtered.prefix(15))
                        )
                    } catch {
                        return nil
                    }
                }
            }
            
            for await section in group {
                if let section = section {
                    sections.append(section)
                }
            }
        }
        
        return sections
    }
    
    // MARK: - "More [Genre] for you"
    
    private func loadGenreRecommendations(excluded: Set<Int>) async -> [GenreRecommendation] {
        let topRanked = Array(
            rankedItems
                .sorted { $0.rank < $1.rank }
                .prefix(5)
        )
        
        guard !topRanked.isEmpty else { return [] }
        
        var genreCounts: [Int: (count: Int, genre: TMDBGenre)] = [:]
        
        await withTaskGroup(of: [TMDBGenre].self) { group in
            for item in topRanked {
                group.addTask {
                    do {
                        if item.mediaType == .movie {
                            let detail = try await TMDBService.shared.getMovieDetails(id: item.tmdbId)
                            return detail.genres
                        } else {
                            let detail = try await TMDBService.shared.getTVDetails(id: item.tmdbId)
                            return detail.genres
                        }
                    } catch {
                        return []
                    }
                }
            }
            
            for await fetchedGenres in group {
                for genre in fetchedGenres {
                    if let existing = genreCounts[genre.id] {
                        genreCounts[genre.id] = (existing.count + 1, genre)
                    } else {
                        genreCounts[genre.id] = (1, genre)
                    }
                }
            }
        }
        
        let topGenres = genreCounts.values
            .sorted { $0.count > $1.count }
            .prefix(2)
            .map { $0.genre }
        
        guard !topGenres.isEmpty else { return [] }
        
        var recommendations: [GenreRecommendation] = []
        
        await withTaskGroup(of: GenreRecommendation?.self) { group in
            for genre in topGenres {
                group.addTask {
                    do {
                        async let moviesTask = TMDBService.shared.discoverMovies(genreId: genre.id)
                        async let tvTask = TMDBService.shared.discoverTV(genreId: genre.id)
                        
                        let (movies, tv) = try await (moviesTask, tvTask)
                        
                        var combined: [TMDBSearchResult] = []
                        let maxCount = max(movies.count, tv.count)
                        for i in 0..<maxCount {
                            if i < movies.count && !excluded.contains(movies[i].id) {
                                combined.append(movies[i])
                            }
                            if i < tv.count && !excluded.contains(tv[i].id) {
                                combined.append(tv[i])
                            }
                        }
                        
                        guard !combined.isEmpty else { return nil }
                        
                        return GenreRecommendation(
                            genre: genre,
                            items: Array(combined.prefix(15))
                        )
                    } catch {
                        return nil
                    }
                }
            }
            
            for await rec in group {
                if let rec = rec {
                    recommendations.append(rec)
                }
            }
        }
        
        return recommendations
    }
    
    // MARK: - Hidden Gems
    
    private func buildHiddenGems(
        from lovedSections: [RecommendationSection],
        genres: [GenreRecommendation],
        excluded: Set<Int>
    ) {
        var allResults: [TMDBSearchResult] = []
        var seenIds = Set<Int>()
        
        for section in lovedSections {
            for item in section.items {
                if !seenIds.contains(item.id) && !excluded.contains(item.id) {
                    allResults.append(item)
                    seenIds.insert(item.id)
                }
            }
        }
        
        for section in genres {
            for item in section.items {
                if !seenIds.contains(item.id) && !excluded.contains(item.id) {
                    allResults.append(item)
                    seenIds.insert(item.id)
                }
            }
        }
        
        let gems = allResults
            .filter { ($0.voteAverage ?? 0) > 7.5 }
            .sorted { ($0.voteAverage ?? 0) > ($1.voteAverage ?? 0) }
        
        hiddenGems = Array(gems.prefix(15))
    }
    
}

// MARK: - Discover Section

struct DiscoverSection: View {
    let title: String
    let items: [TMDBSearchResult]
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(alignment: .leading, spacing: RankdSpacing.sm) {
            // Section header — tracked uppercase
            HStack {
                Text(title.uppercased())
                    .font(RankdTypography.sectionLabel)
                    .tracking(1.5)
                    .foregroundStyle(RankdColors.textTertiary)
                
                Spacer()
                
                Text("See all")
                    .font(RankdTypography.labelMedium)
                    .foregroundStyle(RankdColors.brand)
            }
            .padding(.horizontal, RankdSpacing.md)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: RankdSpacing.sm) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        DiscoverCard(item: item)
                            .onAppear {
                                prefetchAhead(from: index)
                            }
                    }
                }
                .padding(.horizontal, RankdSpacing.md)
            }
        }
        .opacity(reduceMotion ? 1 : (appeared ? 1 : 0))
        .offset(y: reduceMotion ? 0 : (appeared ? 0 : 12))
        .onAppear {
            guard !reduceMotion else {
                appeared = true
                return
            }
            withAnimation(RankdMotion.normal) {
                appeared = true
            }
        }
    }
    
    /// Prefetch the next 4 poster images beyond the currently appearing index.
    private func prefetchAhead(from index: Int) {
        let start = index + 1
        let end = min(start + 4, items.count)
        guard start < end else { return }
        let urls = items[start..<end].map(\.posterURL)
        ImagePrefetcher.prefetch(urls: urls)
    }
}

// MARK: - Discover Card

struct DiscoverCard: View {
    let item: TMDBSearchResult
    
    private var accessibilityDescription: String {
        var parts = [item.displayTitle]
        if let year = item.displayYear {
            parts.append(year)
        }
        if let rating = item.voteAverage, rating > 0 {
            parts.append("Rating \(String(format: "%.1f", rating))")
        }
        return parts.joined(separator: ", ")
    }
    
    var body: some View {
        NavigationLink(destination: MediaDetailView(tmdbId: item.id, mediaType: item.resolvedMediaType)) {
            VStack(alignment: .leading, spacing: RankdSpacing.xs) {
                ZStack(alignment: .topTrailing) {
                    CachedPosterImage(
                        url: item.posterURL,
                        width: RankdPoster.standardWidth,
                        height: RankdPoster.standardHeight,
                        placeholderIcon: item.resolvedMediaType == .movie ? "film" : "tv"
                    )
                    .shadow(color: RankdShadow.card, radius: RankdShadow.cardRadius, y: RankdShadow.cardY)
                    
                    // Rating badge
                    if let rating = item.voteAverage, rating > 0 {
                        RatingBadge(rating: rating)
                            .padding(RankdSpacing.xxs)
                    }
                }
                
                Text(item.displayTitle)
                    .font(RankdTypography.labelMedium)
                    .foregroundStyle(RankdColors.textPrimary)
                    .lineLimit(2)
                    .frame(width: RankdPoster.standardWidth, alignment: .leading)
                
                if let year = item.displayYear {
                    Text(year)
                        .font(RankdTypography.caption)
                        .foregroundStyle(RankdColors.textTertiary)
                }
            }
        }
        .buttonStyle(RankdPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }
}

// MARK: - Rating Badge

struct RatingBadge: View {
    let rating: Double
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "star.fill")
                .font(.system(size: 8, weight: .bold))
            Text(String(format: "%.1f", rating))
                .font(RankdTypography.caption)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, RankdSpacing.xxs + 2)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.7))
        )
        .accessibilityLabel("Rating \(String(format: "%.1f", rating)) out of 10")
    }
}

// MARK: - Genre Grid

struct GenreGrid: View {
    let genres: [TMDBGenre]
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: RankdSpacing.sm) {
            Text("BROWSE BY GENRE")
                .font(RankdTypography.sectionLabel)
                .tracking(1.5)
                .foregroundStyle(RankdColors.textTertiary)
                .padding(.horizontal, RankdSpacing.md)
            
            LazyVGrid(columns: columns, spacing: RankdSpacing.xs) {
                ForEach(genres) { genre in
                    NavigationLink(destination: GenreDetailView(genre: genre)) {
                        Text(genre.name)
                            .font(RankdTypography.labelMedium)
                            .foregroundStyle(RankdColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, RankdSpacing.sm)
                            .background(RankdColors.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: RankdRadius.sm))
                    }
                }
            }
            .padding(.horizontal, RankdSpacing.md)
        }
    }
}

// MARK: - Genre Detail View

struct GenreDetailView: View {
    let genre: TMDBGenre
    
    @Query private var rankedItems: [RankedItem]
    @Query private var watchlistItems: [WatchlistItem]
    
    @State private var popularMovies: [TMDBSearchResult] = []
    @State private var topRatedMovies: [TMDBSearchResult] = []
    @State private var popularTV: [TMDBSearchResult] = []
    @State private var topRatedTV: [TMDBSearchResult] = []
    @State private var heroItem: TMDBSearchResult?
    @State private var isLoading = true
    
    // Lazy section loading — track which sections have loaded
    @State private var loadedPopularMovies = false
    @State private var loadedTopRatedMovies = false
    @State private var loadedPopularTV = false
    @State private var loadedTopRatedTV = false
    
    // Pagination state
    @State private var popularMoviesPage = 1
    @State private var topRatedMoviesPage = 1
    @State private var popularTVPage = 1
    @State private var topRatedTVPage = 1
    @State private var isLoadingMore = false
    @State private var hasMoreContent = true
    
    private let gridColumns = [
        GridItem(.flexible(), spacing: RankdSpacing.sm),
        GridItem(.flexible(), spacing: RankdSpacing.sm)
    ]
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: RankdSpacing.lg) {
                // MARK: Hero Banner
                if let hero = heroItem {
                    genreHeroBanner(hero)
                }
                
                // MARK: Popular Movies
                if !popularMovies.isEmpty {
                    DiscoverSection(
                        title: "Popular Movies",
                        items: popularMovies
                    )
                }
                
                // MARK: Top Rated Movies Grid (lazy)
                if !topRatedMovies.isEmpty {
                    genreGridSection(
                        title: "Top Rated Movies",
                        items: topRatedMovies
                    )
                } else if !loadedTopRatedMovies {
                    Color.clear.frame(height: 1).onAppear {
                        Task { await loadSectionIfNeeded("topRatedMovies") }
                    }
                }
                
                // MARK: Popular TV Shows (lazy)
                if !popularTV.isEmpty {
                    DiscoverSection(
                        title: "Popular TV Shows",
                        items: popularTV
                    )
                } else if !loadedPopularTV {
                    Color.clear.frame(height: 1).onAppear {
                        Task { await loadSectionIfNeeded("popularTV") }
                    }
                }
                
                // MARK: Top Rated TV Grid (lazy)
                if !topRatedTV.isEmpty {
                    genreGridSection(
                        title: "Top Rated TV Shows",
                        items: topRatedTV
                    )
                } else if !loadedTopRatedTV {
                    Color.clear.frame(height: 1).onAppear {
                        Task { await loadSectionIfNeeded("topRatedTV") }
                    }
                }
                
                // Infinite scroll trigger
                if !isLoading && hasMoreContent {
                    Color.clear
                        .frame(height: 1)
                        .onAppear {
                            Task { await loadMoreContent() }
                        }
                    
                    if isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(RankdColors.textTertiary)
                            Spacer()
                        }
                        .padding(RankdSpacing.md)
                    }
                }
            }
            .padding(.bottom, RankdSpacing.xl)
        }
        .scrollIndicators(.hidden)
        .background(RankdColors.background)
        .navigationTitle(genre.name)
        .overlay {
            if isLoading {
                genreDetailSkeleton
            }
        }
        .task {
            await loadInitialContent()
        }
    }
    
    // MARK: - Hero Banner
    
    private func genreHeroBanner(_ item: TMDBSearchResult) -> some View {
        NavigationLink(destination: MediaDetailView(tmdbId: item.id, mediaType: item.resolvedMediaType)) {
            GeometryReader { geo in
                ZStack(alignment: .bottomLeading) {
                    if let backdropURL = item.backdropURL {
                        CachedAsyncImage(url: backdropURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                        } placeholder: {
                            Rectangle()
                                .fill(RankdColors.surfacePrimary)
                                .shimmer()
                        }
                    } else if let posterURL = item.posterURL {
                        CachedAsyncImage(url: posterURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                                .blur(radius: 20)
                        } placeholder: {
                            Rectangle()
                                .fill(RankdColors.surfacePrimary)
                                .shimmer()
                        }
                    } else {
                        Rectangle()
                            .fill(RankdColors.surfacePrimary)
                    }
                    
                    // Gradient overlay
                    LinearGradient(
                        colors: [
                            .clear,
                            RankdColors.background.opacity(0.3),
                            RankdColors.background.opacity(0.8),
                            RankdColors.background
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    // Content
                    VStack(alignment: .leading, spacing: RankdSpacing.sm) {
                        // Rating badge
                        if let rating = item.voteAverage, rating > 0 {
                            HStack(spacing: RankdSpacing.xxs) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(RankdColors.warning)
                                Text(String(format: "%.1f", rating))
                                    .font(RankdTypography.labelLarge)
                                    .foregroundStyle(RankdColors.textPrimary)
                            }
                        }
                        
                        Text(item.displayTitle)
                            .font(RankdTypography.displayLarge)
                            .foregroundStyle(RankdColors.textPrimary)
                            .lineLimit(2)
                        
                        HStack(spacing: RankdSpacing.xs) {
                            if let year = item.displayYear {
                                Text(year)
                            }
                            if item.resolvedMediaType == .tv {
                                Text("TV Series")
                            }
                        }
                        .font(RankdTypography.bodySmall)
                        .foregroundStyle(RankdColors.textSecondary)
                        
                        if let overview = item.overview, !overview.isEmpty {
                            Text(overview)
                                .font(RankdTypography.bodySmall)
                                .foregroundStyle(RankdColors.textSecondary)
                                .lineLimit(2)
                        }
                        
                        Text("Rank It")
                            .font(RankdTypography.labelLarge)
                            .foregroundStyle(.white)
                            .padding(.horizontal, RankdSpacing.lg)
                            .padding(.vertical, RankdSpacing.sm)
                            .background(
                                LinearGradient(
                                    colors: [RankdColors.gradientStart, RankdColors.gradientEnd],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: RankdColors.brand.opacity(0.4), radius: 8, y: 4)
                            .padding(.top, RankdSpacing.xxs)
                    }
                    .padding(.horizontal, RankdSpacing.md)
                    .padding(.bottom, RankdSpacing.lg)
                }
            }
            .frame(height: 320)
        }
        .buttonStyle(RankdPressStyle())
    }
    
    // MARK: - Grid Section
    
    private func genreGridSection(title: String, items: [TMDBSearchResult]) -> some View {
        VStack(alignment: .leading, spacing: RankdSpacing.sm) {
            Text(title)
                .font(RankdTypography.headingMedium)
                .foregroundStyle(RankdColors.textPrimary)
                .padding(.horizontal, RankdSpacing.md)
            
            LazyVGrid(columns: gridColumns, spacing: RankdSpacing.sm) {
                ForEach(items) { item in
                    GenreGridCard(item: item)
                }
            }
            .padding(.horizontal, RankdSpacing.md)
        }
    }
    
    // MARK: - Skeleton Loading
    
    private var genreDetailSkeleton: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero skeleton
                Rectangle()
                    .fill(RankdColors.surfacePrimary)
                    .frame(height: 320)
                    .shimmer()
                
                VStack(alignment: .leading, spacing: RankdSpacing.lg) {
                    ForEach(0..<2, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: RankdSpacing.sm) {
                            RoundedRectangle(cornerRadius: RankdRadius.sm)
                                .fill(RankdColors.surfaceSecondary)
                                .frame(width: 180, height: 22)
                                .shimmer()
                                .padding(.horizontal, RankdSpacing.md)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: RankdSpacing.sm) {
                                    ForEach(0..<5, id: \.self) { _ in
                                        RoundedRectangle(cornerRadius: RankdPoster.cornerRadius)
                                            .fill(RankdColors.surfaceSecondary)
                                            .frame(width: RankdPoster.standardWidth, height: RankdPoster.standardHeight)
                                            .shimmer()
                                    }
                                }
                                .padding(.horizontal, RankdSpacing.md)
                            }
                        }
                    }
                }
                .padding(.top, RankdSpacing.lg)
            }
        }
        .scrollIndicators(.hidden)
        .background(RankdColors.background)
    }
    
    // MARK: - Data Loading
    
    private func loadInitialContent() async {
        do {
            // Load only popular movies initially (2 pages) — other sections load on-demand
            async let popularMovies1 = TMDBService.shared.discoverMovies(genreId: genre.id, page: 1)
            async let popularMovies2 = TMDBService.shared.discoverMovies(genreId: genre.id, page: 2)
            
            let (pm1, pm2) = try await (popularMovies1, popularMovies2)
            
            popularMovies = pm1 + pm2
            loadedPopularMovies = true
            popularMoviesPage = 2
            
            // Pick hero from popular movies
            heroItem = pm1.filter { $0.backdropPath != nil }.first
        } catch {
            // Network errors handled gracefully — UI shows last state
        }
        isLoading = false
    }
    
    /// Load a section on-demand when it first becomes visible.
    private func loadSectionIfNeeded(_ section: String) async {
        switch section {
        case "topRatedMovies":
            guard !loadedTopRatedMovies else { return }
            loadedTopRatedMovies = true
            if let results = try? await TMDBService.shared.discoverTopRatedMovies(genreId: genre.id, page: 1) {
                topRatedMovies = results
                topRatedMoviesPage = 1
                // Update hero if we got a better one
                if heroItem == nil, let best = results.filter({ $0.backdropPath != nil }).max(by: { ($0.voteAverage ?? 0) < ($1.voteAverage ?? 0) }) {
                    heroItem = best
                }
            }
        case "popularTV":
            guard !loadedPopularTV else { return }
            loadedPopularTV = true
            do {
                async let ptv1 = TMDBService.shared.discoverTV(genreId: genre.id, page: 1)
                async let ptv2 = TMDBService.shared.discoverTV(genreId: genre.id, page: 2)
                let (p1, p2) = try await (ptv1, ptv2)
                popularTV = p1 + p2
                popularTVPage = 2
            } catch { }
        case "topRatedTV":
            guard !loadedTopRatedTV else { return }
            loadedTopRatedTV = true
            if let results = try? await TMDBService.shared.discoverTopRatedTV(genreId: genre.id, page: 1) {
                topRatedTV = results
                topRatedTVPage = 1
            }
        default:
            break
        }
    }
    
    private func loadMoreContent() async {
        guard !isLoadingMore, hasMoreContent else { return }
        isLoadingMore = true
        
        do {
            let nextPopularMoviesPage = popularMoviesPage + 1
            let nextTopRatedMoviesPage = topRatedMoviesPage + 1
            let nextPopularTVPage = popularTVPage + 1
            let nextTopRatedTVPage = topRatedTVPage + 1
            
            async let morePopularMovies = TMDBService.shared.discoverMovies(genreId: genre.id, page: nextPopularMoviesPage)
            async let moreTopRatedMovies = TMDBService.shared.discoverTopRatedMovies(genreId: genre.id, page: nextTopRatedMoviesPage)
            async let morePopularTV = TMDBService.shared.discoverTV(genreId: genre.id, page: nextPopularTVPage)
            async let moreTopRatedTV = TMDBService.shared.discoverTopRatedTV(genreId: genre.id, page: nextTopRatedTVPage)
            
            let (mpm, mtrm, mptv, mtrtv) = try await (morePopularMovies, moreTopRatedMovies, morePopularTV, moreTopRatedTV)
            
            // Deduplicate by ID
            let existingMovieIds = Set(popularMovies.map(\.id))
            let existingTopMovieIds = Set(topRatedMovies.map(\.id))
            let existingTVIds = Set(popularTV.map(\.id))
            let existingTopTVIds = Set(topRatedTV.map(\.id))
            
            let newPopMovies = mpm.filter { !existingMovieIds.contains($0.id) }
            let newTopMovies = mtrm.filter { !existingTopMovieIds.contains($0.id) }
            let newPopTV = mptv.filter { !existingTVIds.contains($0.id) }
            let newTopTV = mtrtv.filter { !existingTopTVIds.contains($0.id) }
            
            // Stop infinite scroll if all pages returned empty/duplicate results
            if newPopMovies.isEmpty && newTopMovies.isEmpty && newPopTV.isEmpty && newTopTV.isEmpty {
                hasMoreContent = false
            }
            
            popularMovies += newPopMovies
            topRatedMovies += newTopMovies
            popularTV += newPopTV
            topRatedTV += newTopTV
            
            popularMoviesPage = nextPopularMoviesPage
            topRatedMoviesPage = nextTopRatedMoviesPage
            popularTVPage = nextPopularTVPage
            topRatedTVPage = nextTopRatedTVPage
        } catch {
            // Network errors handled gracefully — UI shows last state
            hasMoreContent = false
        }
        
        isLoadingMore = false
    }
}

// MARK: - Genre Grid Card

struct GenreGridCard: View {
    let item: TMDBSearchResult
    
    var body: some View {
        NavigationLink(destination: MediaDetailView(tmdbId: item.id, mediaType: item.resolvedMediaType)) {
            HStack(spacing: RankdSpacing.sm) {
                // Poster
                ZStack(alignment: .topTrailing) {
                    CachedPosterImage(
                        url: item.posterURL,
                        width: 80,
                        height: 120,
                        cornerRadius: RankdRadius.sm,
                        placeholderIcon: item.resolvedMediaType == .movie ? "film" : "tv"
                    )
                }
                
                // Info
                VStack(alignment: .leading, spacing: RankdSpacing.xxs) {
                    Text(item.displayTitle)
                        .font(RankdTypography.labelLarge)
                        .foregroundStyle(RankdColors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if let year = item.displayYear {
                        Text(year)
                            .font(RankdTypography.caption)
                            .foregroundStyle(RankdColors.textTertiary)
                    }
                    
                    if let rating = item.voteAverage, rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(RankdColors.warning)
                            Text(String(format: "%.1f", rating))
                                .font(RankdTypography.labelSmall)
                                .foregroundStyle(RankdColors.textSecondary)
                        }
                        .padding(.top, RankdSpacing.xxs)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, RankdSpacing.xs)
                
                Spacer()
            }
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: RankdRadius.md)
                    .fill(RankdColors.surfacePrimary)
            )
            .clipShape(RoundedRectangle(cornerRadius: RankdRadius.md))
            .shadow(color: RankdShadow.card, radius: RankdShadow.cardRadius / 2, y: RankdShadow.cardY / 2)
        }
        .buttonStyle(RankdPressStyle())
    }
}

#Preview {
    DiscoverView()
        .modelContainer(for: [RankedItem.self, WatchlistItem.self], inMemory: true)
}
