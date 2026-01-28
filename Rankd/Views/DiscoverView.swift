import SwiftUI
import SwiftData

struct DiscoverView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var rankedItems: [RankedItem]
    @Query private var watchlistItems: [WatchlistItem]
    
    @State private var trending: [TMDBSearchResult] = []
    @State private var popularMovies: [TMDBSearchResult] = []
    @State private var popularTV: [TMDBSearchResult] = []
    @State private var topRatedMovies: [TMDBSearchResult] = []
    @State private var topRatedTV: [TMDBSearchResult] = []
    @State private var genres: [TMDBGenre] = []
    
    @State private var isLoading = true
    @State private var error: String?
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading...")
                } else if let error = error {
                    errorView(error)
                } else {
                    scrollContent
                }
            }
            .navigationTitle("Discover")
            .refreshable {
                await loadContent()
            }
            .task {
                await loadContent()
            }
        }
    }
    
    private var scrollContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
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
            .padding(.vertical)
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Try Again") {
                Task { await loadContent() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private func loadContent() async {
        isLoading = error != nil
        error = nil
        
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
    
    private func selectItem(_ result: TMDBSearchResult) {
        selectedResult = result
        showAddSheet = true
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

// MARK: - Quick Add Sheet
struct QuickAddSheet: View {
    let result: TMDBSearchResult
    let status: ItemStatus
    let onWatchlist: () -> Void
    let onRank: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Movie info header
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
                        
                        HStack {
                            if let year = result.displayYear {
                                Text(year)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Text(result.resolvedMediaType == .movie ? "Movie" : "TV")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary)
                                .clipShape(Capsule())
                        }
                        
                        if let rating = result.voteAverage, rating > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                Text(String(format: "%.1f", rating))
                            }
                            .font(.subheadline)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                if status != .notAdded {
                    // Already added message
                    HStack {
                        Image(systemName: status == .ranked ? "checkmark.circle.fill" : "bookmark.fill")
                            .foregroundStyle(status == .ranked ? .green : .blue)
                        Text(status == .ranked ? "Already in your rankings" : "Already in your watchlist")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                } else {
                    // Action buttons
                    VStack(spacing: 16) {
                        Text("Have you seen it?")
                            .font(.headline)
                        
                        // Watchlist option
                        Button(action: onWatchlist) {
                            HStack {
                                Image(systemName: "bookmark")
                                VStack(alignment: .leading) {
                                    Text("Not yet")
                                        .fontWeight(.semibold)
                                    Text("Add to Watchlist")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // Rank option
                        Button(action: onRank) {
                            HStack {
                                Image(systemName: "list.number")
                                VStack(alignment: .leading) {
                                    Text("Yes! Rank it")
                                        .fontWeight(.semibold)
                                    Text("Compare to find its place")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Discover Section
struct DiscoverSection: View {
    let title: String
    let items: [TMDBSearchResult]
    let itemStatus: (TMDBSearchResult) -> ItemStatus
    
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
