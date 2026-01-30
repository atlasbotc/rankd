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
    @Environment(\.modelContext) private var modelContext
    @Query private var rankedItems: [RankedItem]
    @Query private var watchlistItems: [WatchlistItem]
    
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
            .navigationTitle("Discover")
            .refreshable {
                await loadAllContent()
            }
            .task {
                await loadAllContent()
            }
        }
    }
    
    // MARK: - Scroll Content
    
    private var scrollContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                
                // MARK: New User Welcome
                if !hasRankedItems {
                    welcomeHeader
                }
                
                // MARK: Personalized Sections
                if hasRankedItems {
                    personalizedContent
                }
                
                // MARK: Generic Sections
                genericContent
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Welcome Header
    
    private var welcomeHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            
            Text("Personalized For You")
                .font(.title3.bold())
            
            Text("Start ranking movies and shows to unlock recommendations tailored to your taste.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.orange.opacity(0.08))
                .padding(.horizontal)
        )
    }
    
    // MARK: - Personalized Content
    
    private var personalizedContent: some View {
        Group {
            if isPersonalizedLoading {
                // Shimmer placeholder while personalized content loads
                personalizedLoadingPlaceholder
            } else {
                // "Because you loved [Title]" sections
                ForEach(becauseYouLoved) { section in
                    DiscoverSection(
                        title: section.title,
                        items: section.items,
                        itemStatus: itemStatus
                    )
                }
                
                // "More [Genre] for you" sections
                ForEach(genreRecommendations) { section in
                    DiscoverSection(
                        title: "More \(section.genre.name) for you",
                        items: section.items,
                        itemStatus: itemStatus
                    )
                }
                
                // "You Haven't Seen These Yet"
                if !hiddenGems.isEmpty {
                    DiscoverSection(
                        title: "💎 You Haven't Seen These Yet",
                        items: hiddenGems,
                        itemStatus: itemStatus
                    )
                }
                
                // Divider between personalized and generic
                if !becauseYouLoved.isEmpty || !genreRecommendations.isEmpty || !hiddenGems.isEmpty {
                    sectionDivider
                }
            }
        }
    }
    
    // MARK: - Loading Placeholder
    
    private var personalizedLoadingPlaceholder: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 12) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.quaternary)
                        .frame(width: 200, height: 20)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<5, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.quaternary)
                                    .frame(width: 120, height: 180)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .redacted(reason: .placeholder)
    }
    
    // MARK: - Section Divider
    
    private var sectionDivider: some View {
        HStack(spacing: 12) {
            VStack { Divider() }
            Text("Explore")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            VStack { Divider() }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    // MARK: - Generic Content
    
    private var genericContent: some View {
        Group {
            // Trending
            if !trending.isEmpty {
                DiscoverSection(
                    title: "🔥 Trending This Week",
                    items: trending,
                    itemStatus: itemStatus
                )
            }
            
            // Popular Movies
            if !popularMovies.isEmpty {
                DiscoverSection(
                    title: "🎬 Popular Movies",
                    items: popularMovies,
                    itemStatus: itemStatus
                )
            }
            
            // Popular TV
            if !popularTV.isEmpty {
                DiscoverSection(
                    title: "📺 Popular TV Shows",
                    items: popularTV,
                    itemStatus: itemStatus
                )
            }
            
            // Top Rated Movies
            if !topRatedMovies.isEmpty {
                DiscoverSection(
                    title: "⭐ Top Rated Movies",
                    items: topRatedMovies,
                    itemStatus: itemStatus
                )
            }
            
            // Top Rated TV
            if !topRatedTV.isEmpty {
                DiscoverSection(
                    title: "🏆 Top Rated TV",
                    items: topRatedTV,
                    itemStatus: itemStatus
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
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(0..<3, id: \.self) { sectionIndex in
                    VStack(alignment: .leading, spacing: 12) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: 200, height: 24)
                            .shimmer()
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(0..<5, id: \.self) { _ in
                                    VStack(alignment: .leading, spacing: 6) {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.secondary.opacity(0.15))
                                            .frame(width: 120, height: 180)
                                            .shimmer()
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.secondary.opacity(0.15))
                                            .frame(width: 100, height: 12)
                                            .shimmer()
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Try Again") {
                Task { await loadAllContent() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    // MARK: - Data Loading
    
    private func loadAllContent() async {
        isLoading = error != nil
        error = nil
        
        // Load generic content first (fast), then personalized in parallel
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
        
        // Capture excluded IDs snapshot to filter results
        let excluded = excludedIds
        
        // Run all personalized fetches in parallel
        async let lovedTask = loadBecauseYouLoved(excluded: excluded)
        async let genreTask = loadGenreRecommendations(excluded: excluded)
        
        let (lovedSections, genreSections) = await (lovedTask, genreTask)
        
        becauseYouLoved = lovedSections
        genreRecommendations = genreSections
        
        // Build "Hidden Gems" from all recommendation results
        buildHiddenGems(from: lovedSections, genres: genreSections, excluded: excluded)
        
        isPersonalizedLoading = false
    }
    
    // MARK: - "Because you loved [Title]"
    
    private func loadBecauseYouLoved(excluded: Set<Int>) async -> [RecommendationSection] {
        // Pick up to 3 top green-tier items
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
                        print("Error loading recommendations for \(item.title): \(error)")
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
        // Fetch details for top 5 ranked items to discover genre IDs
        let topRanked = Array(
            rankedItems
                .sorted { $0.rank < $1.rank }
                .prefix(5)
        )
        
        guard !topRanked.isEmpty else { return [] }
        
        // Aggregate genre IDs from TMDB detail endpoints
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
        
        // Pick top 2 most frequent genres
        let topGenres = genreCounts.values
            .sorted { $0.count > $1.count }
            .prefix(2)
            .map { $0.genre }
        
        guard !topGenres.isEmpty else { return [] }
        
        // Fetch discover content for each top genre
        var recommendations: [GenreRecommendation] = []
        
        await withTaskGroup(of: GenreRecommendation?.self) { group in
            for genre in topGenres {
                group.addTask {
                    do {
                        // Fetch both movies and TV for the genre, combine
                        async let moviesTask = TMDBService.shared.discoverMovies(genreId: genre.id)
                        async let tvTask = TMDBService.shared.discoverTV(genreId: genre.id)
                        
                        let (movies, tv) = try await (moviesTask, tvTask)
                        
                        // Interleave movies and TV, filter excluded
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
                        print("Error loading genre recommendations for \(genre.name): \(error)")
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
    
    // MARK: - "You Haven't Seen These Yet"
    
    private func buildHiddenGems(
        from lovedSections: [RecommendationSection],
        genres: [GenreRecommendation],
        excluded: Set<Int>
    ) {
        // Collect all recommendation results
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
        
        // Filter to highly-rated items (>7.5)
        let gems = allResults
            .filter { ($0.voteAverage ?? 0) > 7.5 }
            .sorted { ($0.voteAverage ?? 0) > ($1.voteAverage ?? 0) }
        
        hiddenGems = Array(gems.prefix(15))
    }
    
    // MARK: - Item Status
    
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

// MARK: - Discover Section
struct DiscoverSection: View {
    let title: String
    let items: [TMDBSearchResult]
    let itemStatus: (TMDBSearchResult) -> ItemStatus
    @State private var appeared = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.bold())
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(items) { item in
                        DiscoverCard(item: item, status: itemStatus(item))
                    }
                }
                .padding(.horizontal)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
    }
}

// MARK: - Discover Card
struct DiscoverCard: View {
    let item: TMDBSearchResult
    let status: ItemStatus
    
    var body: some View {
        NavigationLink(destination: MediaDetailView(tmdbId: item.id, mediaType: item.resolvedMediaType)) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: item.posterURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(.quaternary)
                            .overlay {
                                Image(systemName: item.resolvedMediaType == .movie ? "film" : "tv")
                                    .font(.title)
                                    .foregroundStyle(.tertiary)
                            }
                    }
                    .frame(width: 120, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Status badge
                    if status != .notAdded {
                        statusBadge
                            .padding(6)
                    }
                }
                
                Text(item.displayTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .frame(width: 120, alignment: .leading)
                    .foregroundStyle(.primary)
                
                HStack(spacing: 4) {
                    if let year = item.displayYear {
                        Text(year)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let rating = item.voteAverage, rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .opacity(status == .notAdded ? 1 : 0.7)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        Group {
            switch status {
            case .ranked:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .watchlist:
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(.blue)
            case .notAdded:
                EmptyView()
            }
        }
        .font(.title3)
        .background(Circle().fill(.ultraThinMaterial).padding(-4))
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
        VStack(alignment: .leading, spacing: 12) {
            Text("🎭 Browse by Genre")
                .font(.title2.bold())
                .padding(.horizontal)
            
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(genres) { genre in
                    NavigationLink(destination: GenreDetailView(genre: genre)) {
                        Text(genre.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Genre Detail View
struct GenreDetailView: View {
    let genre: TMDBGenre
    
    @Query private var rankedItems: [RankedItem]
    @Query private var watchlistItems: [WatchlistItem]
    
    @State private var movies: [TMDBSearchResult] = []
    @State private var tvShows: [TMDBSearchResult] = []
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                if !movies.isEmpty {
                    DiscoverSection(
                        title: "Movies",
                        items: movies,
                        itemStatus: itemStatus
                    )
                }
                
                if !tvShows.isEmpty {
                    DiscoverSection(
                        title: "TV Shows",
                        items: tvShows,
                        itemStatus: itemStatus
                    )
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(genre.name)
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .task {
            await loadContent()
        }
    }
    
    private func loadContent() async {
        do {
            async let moviesTask = TMDBService.shared.discoverMovies(genreId: genre.id)
            async let tvTask = TMDBService.shared.discoverTV(genreId: genre.id)
            
            let (m, t) = try await (moviesTask, tvTask)
            movies = m
            tvShows = t
        } catch {
            print("Error loading genre content: \(error)")
        }
        isLoading = false
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

#Preview {
    DiscoverView()
        .modelContainer(for: [RankedItem.self, WatchlistItem.self], inMemory: true)
}
