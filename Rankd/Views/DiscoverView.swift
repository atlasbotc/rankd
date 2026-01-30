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
                await loadAllContent()
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
    }
    
    // MARK: - Your Lists on Discover
    
    private var discoverListsSection: some View {
        VStack(alignment: .leading, spacing: RankdSpacing.sm) {
            HStack {
                Text("Your Lists")
                    .font(RankdTypography.headingMedium)
                    .foregroundStyle(RankdColors.textPrimary)
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
            Text("Welcome to Rankd")
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
                RoundedRectangle(cornerRadius: 0)
                    .fill(RankdColors.surfacePrimary)
                    .frame(height: UIScreen.main.bounds.height * 0.55)
                    .shimmer()
                
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
                Task { await loadAllContent() }
            } label: {
                Text("Try Again")
                    .font(RankdTypography.labelLarge)
                    .foregroundStyle(RankdColors.textPrimary)
                    .padding(.horizontal, RankdSpacing.lg)
                    .frame(height: 48)
                    .background(RankdColors.brand)
                    .clipShape(RoundedRectangle(cornerRadius: RankdRadius.md))
            }
            .padding(.top, RankdSpacing.xs)
        }
        .padding(RankdSpacing.lg)
    }
    
    // MARK: - Data Loading
    
    private func loadAllContent() async {
        isLoading = error != nil
        error = nil
        
        async let genericTask: () = loadGenericContent()
        async let personalizedTask: () = loadPersonalizedContent()
        
        _ = await (genericTask, personalizedTask)
    }
    
    private func loadGenericContent() async {
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: RankdSpacing.sm) {
            // Section header
            HStack {
                Text(title)
                    .font(RankdTypography.headingMedium)
                    .foregroundStyle(RankdColors.textPrimary)
                
                Spacer()
                
                Text("See all")
                    .font(RankdTypography.labelMedium)
                    .foregroundStyle(RankdColors.textTertiary)
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
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
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
            Text("Browse by Genre")
                .font(RankdTypography.headingMedium)
                .foregroundStyle(RankdColors.textPrimary)
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
    
    // Pagination state
    @State private var popularMoviesPage = 1
    @State private var topRatedMoviesPage = 1
    @State private var popularTVPage = 1
    @State private var topRatedTVPage = 1
    @State private var isLoadingMore = false
    
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
                
                // MARK: Top Rated Movies Grid
                if !topRatedMovies.isEmpty {
                    genreGridSection(
                        title: "Top Rated Movies",
                        items: topRatedMovies
                    )
                }
                
                // MARK: Popular TV Shows
                if !popularTV.isEmpty {
                    DiscoverSection(
                        title: "Popular TV Shows",
                        items: popularTV
                    )
                }
                
                // MARK: Top Rated TV Grid
                if !topRatedTV.isEmpty {
                    genreGridSection(
                        title: "Top Rated TV Shows",
                        items: topRatedTV
                    )
                }
                
                // Infinite scroll trigger
                if !isLoading {
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
                            .foregroundStyle(RankdColors.textPrimary)
                            .padding(.horizontal, RankdSpacing.lg)
                            .padding(.vertical, RankdSpacing.sm)
                            .background(RankdColors.brand)
                            .clipShape(Capsule())
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
            // Load 2 pages each for popular, 1 page for top rated initially
            async let popularMovies1 = TMDBService.shared.discoverMovies(genreId: genre.id, page: 1)
            async let popularMovies2 = TMDBService.shared.discoverMovies(genreId: genre.id, page: 2)
            async let topRatedMoviesTask = TMDBService.shared.discoverTopRatedMovies(genreId: genre.id, page: 1)
            async let popularTV1 = TMDBService.shared.discoverTV(genreId: genre.id, page: 1)
            async let popularTV2 = TMDBService.shared.discoverTV(genreId: genre.id, page: 2)
            async let topRatedTVTask = TMDBService.shared.discoverTopRatedTV(genreId: genre.id, page: 1)
            
            let (pm1, pm2, trm, ptv1, ptv2, trtv) = try await (
                popularMovies1, popularMovies2,
                topRatedMoviesTask,
                popularTV1, popularTV2,
                topRatedTVTask
            )
            
            popularMovies = pm1 + pm2
            topRatedMovies = trm
            popularTV = ptv1 + ptv2
            topRatedTV = trtv
            
            // Pick hero: highest-rated item with a backdrop from top rated movies or TV
            let allTopRated = (trm + trtv).filter { $0.backdropPath != nil }
            heroItem = allTopRated.max(by: { ($0.voteAverage ?? 0) < ($1.voteAverage ?? 0) })
            
            // If no backdrop found in top rated, try popular
            if heroItem == nil {
                let allPopular = (pm1 + ptv1).filter { $0.backdropPath != nil }
                heroItem = allPopular.first
            }
            
            popularMoviesPage = 2
            topRatedMoviesPage = 1
            popularTVPage = 2
            topRatedTVPage = 1
        } catch {
            // Network errors handled gracefully — UI shows last state
        }
        isLoading = false
    }
    
    private func loadMoreContent() async {
        guard !isLoadingMore else { return }
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
            
            popularMovies += mpm.filter { !existingMovieIds.contains($0.id) }
            topRatedMovies += mtrm.filter { !existingTopMovieIds.contains($0.id) }
            popularTV += mptv.filter { !existingTVIds.contains($0.id) }
            topRatedTV += mtrtv.filter { !existingTopTVIds.contains($0.id) }
            
            popularMoviesPage = nextPopularMoviesPage
            topRatedMoviesPage = nextTopRatedMoviesPage
            popularTVPage = nextPopularTVPage
            topRatedTVPage = nextTopRatedTVPage
        } catch {
            // Network errors handled gracefully — UI shows last state
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
