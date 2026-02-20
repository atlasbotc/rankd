import SwiftUI
import SwiftData

struct MediaDetailView: View {
    let tmdbId: Int
    let mediaType: MediaType
    
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @Query private var rankedItems: [RankedItem]
    @Query private var watchlistItems: [WatchlistItem]
    
    @State private var movieDetail: TMDBMovieDetail?
    @State private var tvDetail: TMDBTVDetail?
    @State private var isLoading = true
    @State private var error: String?
    @State private var synopsisExpanded = false
    
    @State private var comparisonFlowItem: TMDBSearchResult?
    @State private var showAddToList = false
    
    private var isRanked: Bool {
        rankedItems.contains { $0.tmdbId == tmdbId }
    }
    
    private var isInWatchlist: Bool {
        watchlistItems.contains { $0.tmdbId == tmdbId }
    }
    
    private var rankedItem: RankedItem? {
        rankedItems.first { $0.tmdbId == tmdbId }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if isLoading {
                    mediaDetailSkeleton
                } else if let error = error {
                    errorView(error)
                } else if mediaType == .movie, let detail = movieDetail {
                    movieContent(detail)
                } else if mediaType == .tv, let detail = tvDetail {
                    tvContent(detail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(MarquiColors.background)
        .scrollIndicators(.hidden)
        .clipped()
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await loadDetails()
        }
        .fullScreenCover(item: $comparisonFlowItem) { result in
            ComparisonFlowView(newItem: result)
        }
        .sheet(isPresented: $showAddToList) {
            if let result = searchResult {
                AddToListSheet(
                    tmdbId: result.id,
                    title: result.displayTitle,
                    posterPath: result.posterPath,
                    releaseDate: result.displayDate,
                    mediaType: result.resolvedMediaType
                )
            }
        }
    }
    
    // MARK: - Movie Content
    
    private func movieContent(_ detail: TMDBMovieDetail) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Backdrop hero
            backdropHero(
                backdropURL: detail.backdropURL,
                posterURL: detail.posterURL
            )
            
            // Poster overlay + title area
            VStack(alignment: .leading, spacing: MarquiSpacing.md) {
                // Poster overlay
                HStack(alignment: .bottom, spacing: MarquiSpacing.md) {
                    CachedPosterImage(
                        url: detail.posterURL,
                        width: 80,
                        height: 120
                    )
                    .shadow(color: MarquiShadow.elevated, radius: MarquiShadow.elevatedRadius, y: MarquiShadow.elevatedY)
                    .offset(y: -40)
                    
                    Spacer()
                }
                .padding(.horizontal, MarquiSpacing.md)
                
                // Title
                Text(detail.title)
                    .font(MarquiTypography.displayMedium)
                    .foregroundStyle(MarquiColors.textPrimary)
                    .padding(.horizontal, MarquiSpacing.md)
                    .offset(y: -24)
                
                // Metadata row (year, runtime, rating)
                metadataRow(
                    year: detail.year,
                    runtime: detail.runtimeFormatted,
                    rating: detail.voteAverage
                )
                .offset(y: -16)
                
                // Genres
                if !detail.genres.isEmpty {
                    genrePills(detail.genres)
                        .offset(y: -12)
                }
                
                // User rank badge
                if let ranked = rankedItem {
                    rankBadge(ranked)
                        .padding(.horizontal, MarquiSpacing.md)
                        .offset(y: -8)
                }
                
                // Action buttons (Rank / Watchlist / Add to List)
                actionButtonsSection
                    .padding(.horizontal, MarquiSpacing.md)
                
                // Trailer button
                if let trailerURL = detail.trailerURL {
                    trailerButton(url: trailerURL)
                        .padding(.horizontal, MarquiSpacing.md)
                }
                
                // Synopsis
                if let overview = detail.overview, !overview.isEmpty {
                    synopsisSection(overview)
                }
                
                // Where to Watch
                if let providers = detail.usStreamingProviders, !providers.isEmpty {
                    watchProvidersSection(providers, watchLink: detail.usWatchLink)
                }
                
                // Cast & Crew
                if let credits = detail.credits, !credits.cast.isEmpty {
                    castSection(Array(credits.cast.prefix(15)))
                }
                
                // Crew
                if let credits = detail.credits {
                    let keyCrews = credits.crew.filter {
                        ["Director", "Writer", "Screenplay", "Producer", "Director of Photography", "Composer"].contains($0.job ?? "")
                    }
                    if !keyCrews.isEmpty {
                        crewSection(Array(keyCrews.prefix(8)))
                    }
                }
                
                // Similar Titles
                if !detail.recommendedTitles.isEmpty {
                    similarTitlesSection(detail.recommendedTitles)
                }
            }
            .padding(.bottom, MarquiSpacing.xxl)
        }
    }
    
    // MARK: - TV Content
    
    private func tvContent(_ detail: TMDBTVDetail) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Backdrop hero
            backdropHero(
                backdropURL: detail.backdropURL,
                posterURL: detail.posterURL
            )
            
            // Poster overlay + title area
            VStack(alignment: .leading, spacing: MarquiSpacing.md) {
                // Poster overlay
                HStack(alignment: .bottom, spacing: MarquiSpacing.md) {
                    CachedPosterImage(
                        url: detail.posterURL,
                        width: 80,
                        height: 120
                    )
                    .shadow(color: MarquiShadow.elevated, radius: MarquiShadow.elevatedRadius, y: MarquiShadow.elevatedY)
                    .offset(y: -40)
                    
                    Spacer()
                }
                .padding(.horizontal, MarquiSpacing.md)
                
                // Title
                Text(detail.name)
                    .font(MarquiTypography.displayMedium)
                    .foregroundStyle(MarquiColors.textPrimary)
                    .padding(.horizontal, MarquiSpacing.md)
                    .offset(y: -24)
                
                // Metadata row
                tvMetadataRow(detail)
                    .offset(y: -16)
                
                // Genres
                if !detail.genres.isEmpty {
                    genrePills(detail.genres)
                        .offset(y: -12)
                }
                
                // User rank badge
                if let ranked = rankedItem {
                    rankBadge(ranked)
                        .padding(.horizontal, MarquiSpacing.md)
                        .offset(y: -8)
                }
                
                // Action buttons
                actionButtonsSection
                    .padding(.horizontal, MarquiSpacing.md)
                
                // Trailer button
                if let trailerURL = detail.trailerURL {
                    trailerButton(url: trailerURL)
                        .padding(.horizontal, MarquiSpacing.md)
                }
                
                // Synopsis
                if let overview = detail.overview, !overview.isEmpty {
                    synopsisSection(overview)
                }
                
                // Where to Watch
                if let providers = detail.usStreamingProviders, !providers.isEmpty {
                    watchProvidersSection(providers, watchLink: detail.usWatchLink)
                }
                
                // Cast
                if let credits = detail.credits, !credits.cast.isEmpty {
                    castSection(Array(credits.cast.prefix(15)))
                }
                
                // Similar Titles
                if !detail.recommendedTitles.isEmpty {
                    similarTitlesSection(detail.recommendedTitles)
                }
            }
            .padding(.bottom, MarquiSpacing.xxl)
        }
    }
    
    // MARK: - Shared Components
    
    private func backdropHero(backdropURL: URL?, posterURL: URL?) -> some View {
        ZStack(alignment: .bottom) {
            if let backdropURL = backdropURL {
                CachedAsyncImage(url: backdropURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(MarquiColors.surfacePrimary)
                        .shimmer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .clipped()
            } else if let posterURL = posterURL {
                CachedAsyncImage(url: posterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: 30)
                } placeholder: {
                    Rectangle()
                        .fill(MarquiColors.surfacePrimary)
                        .shimmer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .clipped()
            } else {
                Rectangle()
                    .fill(MarquiColors.surfacePrimary)
                    .frame(height: 300)
            }
            
            // Gradient overlay
            LinearGradient(
                colors: [
                    .clear,
                    MarquiColors.background.opacity(0.6),
                    MarquiColors.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 300)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .clipped()
    }
    
    private func metadataRow(year: String?, runtime: String?, rating: Double?) -> some View {
        HStack(spacing: MarquiSpacing.xs) {
            if let year = year {
                Text(year)
            }
            if let runtime = runtime {
                Text("·")
                Text(runtime)
            }
            if let rating = rating, rating > 0 {
                Text("·")
                HStack(spacing: MarquiSpacing.xxs) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(MarquiColors.tierMedium)
                    Text(String(format: "%.1f", rating))
                }
            }
        }
        .font(MarquiTypography.bodySmall)
        .foregroundStyle(MarquiColors.textSecondary)
        .padding(.horizontal, MarquiSpacing.md)
    }
    
    private func tvMetadataRow(_ detail: TMDBTVDetail) -> some View {
        HStack(spacing: MarquiSpacing.xs) {
            if let yearRange = detail.yearRange {
                Text(yearRange)
            }
            if let seasons = detail.numberOfSeasons {
                Text("·")
                Text("\(seasons) season\(seasons == 1 ? "" : "s")")
            }
            if let runtime = detail.episodeRuntimeFormatted {
                Text("·")
                Text(runtime)
            }
            if let rating = detail.voteAverage, rating > 0 {
                Text("·")
                HStack(spacing: MarquiSpacing.xxs) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(MarquiColors.tierMedium)
                    Text(String(format: "%.1f", rating))
                }
            }
        }
        .font(MarquiTypography.bodySmall)
        .foregroundStyle(MarquiColors.textSecondary)
        .padding(.horizontal, MarquiSpacing.md)
    }
    
    private func rankBadge(_ ranked: RankedItem) -> some View {
        let score = RankedItem.calculateScore(for: ranked, allItems: rankedItems)
        
        return VStack(alignment: .leading, spacing: MarquiSpacing.xs) {
            HStack(spacing: MarquiSpacing.xs) {
                Circle()
                    .fill(MarquiColors.tierColor(ranked.tier))
                    .frame(width: 8, height: 8)
                
                Text("#\(ranked.rank) in \(ranked.mediaType == .movie ? "Movies" : "TV Shows")")
                    .font(MarquiTypography.labelMedium)
                    .foregroundStyle(MarquiColors.textSecondary)
                
                Spacer()
                
                // Favorite heart toggle
                Button {
                    withAnimation(MarquiMotion.fast) {
                        ranked.isFavorite.toggle()
                    }
                    modelContext.safeSave()
                    HapticManager.impact(.light)
                } label: {
                    Image(systemName: ranked.isFavorite ? "heart.fill" : "heart")
                        .font(MarquiTypography.headingSmall)
                        .foregroundStyle(ranked.isFavorite ? MarquiColors.tierBad : MarquiColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            
            ScoreDisplay(score: score, tier: ranked.tier)
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: MarquiSpacing.xs) {
            if !isRanked {
                // Primary: Rank It
                Button {
                    comparisonFlowItem = searchResult
                } label: {
                    Text("Rank It")
                        .font(MarquiTypography.labelLarge)
                        .foregroundStyle(MarquiColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(MarquiColors.brand)
                        .clipShape(RoundedRectangle(cornerRadius: MarquiRadius.md))
                }
                
                // Secondary: Watchlist
                Button {
                    if isInWatchlist {
                        removeFromWatchlist()
                    } else {
                        addToWatchlist()
                    }
                } label: {
                    HStack(spacing: MarquiSpacing.xs) {
                        Image(systemName: isInWatchlist ? "bookmark.fill" : "bookmark")
                        Text(isInWatchlist ? "In Watchlist" : "Watchlist")
                    }
                    .font(MarquiTypography.labelLarge)
                    .foregroundStyle(MarquiColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(MarquiColors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: MarquiRadius.md))
                }
            }
            
            // Tertiary: Add to List
            Button {
                showAddToList = true
            } label: {
                Text("Add to List")
                    .font(MarquiTypography.labelLarge)
                    .foregroundStyle(MarquiColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
        }
    }
    
    private func trailerButton(url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack(spacing: MarquiSpacing.xs) {
                Image(systemName: "play.fill")
                    .font(.system(size: 12))
                Text("Watch Trailer")
            }
            .font(MarquiTypography.labelLarge)
            .foregroundStyle(MarquiColors.brand)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(MarquiColors.brandSubtle)
            .clipShape(RoundedRectangle(cornerRadius: MarquiRadius.md))
        }
        .buttonStyle(MarquiPressStyle())
    }
    
    private func genrePills(_ genres: [TMDBGenre]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MarquiSpacing.xs) {
                ForEach(genres) { genre in
                    Text(genre.name)
                        .font(MarquiTypography.labelSmall)
                        .foregroundStyle(MarquiColors.textSecondary)
                        .padding(.horizontal, MarquiSpacing.sm)
                        .padding(.vertical, MarquiSpacing.xxs)
                        .background(MarquiColors.surfaceSecondary)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, MarquiSpacing.md)
        }
    }
    
    private func synopsisSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: MarquiSpacing.xs) {
            Text("Synopsis")
                .font(MarquiTypography.headingSmall)
                .foregroundStyle(MarquiColors.textPrimary)
            
            Text(text)
                .font(MarquiTypography.bodyMedium)
                .foregroundStyle(MarquiColors.textSecondary)
                .lineLimit(synopsisExpanded ? nil : 3)
                .lineSpacing(4)
            
            if !synopsisExpanded && text.count > 150 {
                Button {
                    withAnimation(MarquiMotion.normal) {
                        synopsisExpanded = true
                    }
                } label: {
                    Text("Read more")
                        .font(MarquiTypography.labelMedium)
                        .foregroundStyle(MarquiColors.brand)
                }
                .padding(.top, MarquiSpacing.xxs)
            }
        }
        .padding(.horizontal, MarquiSpacing.md)
        .padding(.top, MarquiSpacing.lg)
    }
    
    // MARK: - Where to Watch
    
    private func watchProvidersSection(_ providers: [TMDBWatchProvider], watchLink: URL?) -> some View {
        VStack(alignment: .leading, spacing: MarquiSpacing.sm) {
            Text("Where to Watch")
                .font(MarquiTypography.headingSmall)
                .foregroundStyle(MarquiColors.textPrimary)
                .padding(.horizontal, MarquiSpacing.md)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: MarquiSpacing.sm) {
                    ForEach(providers) { provider in
                        VStack(spacing: MarquiSpacing.xxs) {
                            CachedPosterImage(
                                url: provider.logoURL,
                                width: 48,
                                height: 48,
                                cornerRadius: MarquiRadius.sm,
                                placeholderIcon: "play.tv"
                            )
                            
                            Text(provider.providerName)
                                .font(MarquiTypography.caption)
                                .foregroundStyle(MarquiColors.textTertiary)
                                .lineLimit(1)
                        }
                        .frame(width: 64)
                    }
                }
                .padding(.horizontal, MarquiSpacing.md)
            }
            
            if let watchLink = watchLink {
                Button {
                    openURL(watchLink)
                } label: {
                    Text("View all options on TMDB")
                        .font(MarquiTypography.caption)
                        .foregroundStyle(MarquiColors.brand)
                }
                .padding(.horizontal, MarquiSpacing.md)
                .padding(.top, MarquiSpacing.xxs)
            }
        }
        .padding(.top, MarquiSpacing.lg)
    }
    
    // MARK: - Cast & Crew
    
    private func castSection(_ cast: [TMDBCastMember]) -> some View {
        VStack(alignment: .leading, spacing: MarquiSpacing.sm) {
            Text("Cast")
                .font(MarquiTypography.headingSmall)
                .foregroundStyle(MarquiColors.textPrimary)
                .padding(.horizontal, MarquiSpacing.md)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: MarquiSpacing.md) {
                    ForEach(cast) { member in
                        VStack(spacing: MarquiSpacing.xs) {
                            CachedAsyncImage(url: member.profileURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(MarquiColors.surfaceSecondary)
                                    .overlay {
                                        Image(systemName: "person.fill")
                                            .font(MarquiTypography.bodySmall)
                                            .foregroundStyle(MarquiColors.textTertiary)
                                    }
                                    .shimmer()
                            }
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                            
                            Text(member.name)
                                .font(MarquiTypography.labelSmall)
                                .foregroundStyle(MarquiColors.textPrimary)
                                .lineLimit(1)
                            
                            if let character = member.character {
                                Text(character)
                                    .font(MarquiTypography.caption)
                                    .foregroundStyle(MarquiColors.textTertiary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(width: 72)
                    }
                }
                .padding(.horizontal, MarquiSpacing.md)
            }
        }
        .padding(.top, MarquiSpacing.lg)
    }
    
    private func crewSection(_ crew: [TMDBCrewMember]) -> some View {
        VStack(alignment: .leading, spacing: MarquiSpacing.sm) {
            Text("Crew")
                .font(MarquiTypography.headingSmall)
                .foregroundStyle(MarquiColors.textPrimary)
                .padding(.horizontal, MarquiSpacing.md)
            
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: MarquiSpacing.sm
            ) {
                ForEach(crew) { member in
                    VStack(alignment: .leading, spacing: MarquiSpacing.xxs) {
                        Text(member.name)
                            .font(MarquiTypography.labelMedium)
                            .foregroundStyle(MarquiColors.textPrimary)
                        if let job = member.job {
                            Text(job)
                                .font(MarquiTypography.caption)
                                .foregroundStyle(MarquiColors.textTertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, MarquiSpacing.md)
        }
        .padding(.top, MarquiSpacing.lg)
    }
    
    // MARK: - Similar Titles
    
    private func similarTitlesSection(_ titles: [TMDBSearchResult]) -> some View {
        VStack(alignment: .leading, spacing: MarquiSpacing.sm) {
            Text("You Might Also Like")
                .font(MarquiTypography.headingSmall)
                .foregroundStyle(MarquiColors.textPrimary)
                .padding(.horizontal, MarquiSpacing.md)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: MarquiSpacing.sm) {
                    ForEach(Array(titles.prefix(15))) { item in
                        NavigationLink {
                            MediaDetailView(
                                tmdbId: item.id,
                                mediaType: item.resolvedMediaType
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: MarquiSpacing.xs) {
                                CachedPosterImage(
                                    url: item.posterURL,
                                    width: MarquiPoster.standardWidth,
                                    height: MarquiPoster.standardHeight,
                                    placeholderIcon: item.resolvedMediaType == .movie ? "film" : "tv"
                                )
                                
                                Text(item.displayTitle)
                                    .font(MarquiTypography.labelSmall)
                                    .foregroundStyle(MarquiColors.textPrimary)
                                    .lineLimit(1)
                                
                                if let rating = item.voteAverage, rating > 0 {
                                    HStack(spacing: MarquiSpacing.xxs) {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 9))
                                            .foregroundStyle(MarquiColors.tierMedium)
                                        Text(String(format: "%.1f", rating))
                                            .font(MarquiTypography.caption)
                                            .foregroundStyle(MarquiColors.textTertiary)
                                    }
                                }
                            }
                            .frame(width: MarquiPoster.standardWidth)
                        }
                        .buttonStyle(MarquiPressStyle())
                    }
                }
                .padding(.horizontal, MarquiSpacing.md)
            }
        }
        .padding(.top, MarquiSpacing.lg)
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: MarquiSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(MarquiColors.textTertiary)
            
            Text(message)
                .font(MarquiTypography.bodyMedium)
                .multilineTextAlignment(.center)
                .foregroundStyle(MarquiColors.textSecondary)
        }
        .padding(MarquiSpacing.lg)
        .padding(.top, MarquiSpacing.xxl)
    }
    
    // MARK: - Data
    
    private var searchResult: TMDBSearchResult? {
        if let movie = movieDetail {
            return TMDBSearchResult(
                id: movie.id,
                title: movie.title,
                name: nil,
                overview: movie.overview,
                posterPath: movie.posterPath,
                releaseDate: movie.releaseDate,
                firstAirDate: nil,
                mediaType: "movie",
                voteAverage: movie.voteAverage,
                backdropPath: movie.backdropPath
            )
        } else if let tv = tvDetail {
            return TMDBSearchResult(
                id: tv.id,
                title: nil,
                name: tv.name,
                overview: tv.overview,
                posterPath: tv.posterPath,
                releaseDate: nil,
                firstAirDate: tv.firstAirDate,
                mediaType: "tv",
                voteAverage: tv.voteAverage,
                backdropPath: tv.backdropPath
            )
        }
        return nil
    }
    
    private func loadDetails() async {
        do {
            if mediaType == .movie {
                movieDetail = try await TMDBService.shared.getMovieDetails(id: tmdbId)
            } else {
                tvDetail = try await TMDBService.shared.getTVDetails(id: tmdbId)
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    private func removeFromWatchlist() {
        if let item = watchlistItems.first(where: { $0.tmdbId == tmdbId }) {
            modelContext.delete(item)
            modelContext.safeSave()
        }
    }
    
    private func addToWatchlist() {
        guard let result = searchResult else { return }
        let item = WatchlistItem(
            tmdbId: result.id,
            title: result.displayTitle,
            overview: result.overview ?? "",
            posterPath: result.posterPath,
            releaseDate: result.displayDate,
            mediaType: result.resolvedMediaType
        )
        modelContext.insert(item)
        ActivityLogger.logAddedToWatchlist(item: item, context: modelContext)
        modelContext.safeSave()
        HapticManager.impact(.light)
    }
    
    // MARK: - Skeleton Loading
    
    private var mediaDetailSkeleton: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Backdrop placeholder
            Rectangle()
                .fill(MarquiColors.surfacePrimary)
                .frame(height: 300)
                .shimmer()
            
            VStack(alignment: .leading, spacing: MarquiSpacing.md) {
                // Poster placeholder
                RoundedRectangle(cornerRadius: MarquiPoster.cornerRadius)
                    .fill(MarquiColors.surfaceSecondary)
                    .frame(width: 80, height: 120)
                    .offset(y: -40)
                    .shimmer()
                    .padding(.horizontal, MarquiSpacing.md)
                
                // Title placeholder
                RoundedRectangle(cornerRadius: MarquiRadius.sm)
                    .fill(MarquiColors.surfaceSecondary)
                    .frame(width: 220, height: 28)
                    .shimmer()
                    .padding(.horizontal, MarquiSpacing.md)
                    .offset(y: -24)
                
                // Metadata placeholder
                RoundedRectangle(cornerRadius: MarquiRadius.sm)
                    .fill(MarquiColors.surfaceSecondary)
                    .frame(width: 160, height: 14)
                    .shimmer()
                    .padding(.horizontal, MarquiSpacing.md)
                    .offset(y: -16)
                
                // Synopsis placeholder
                VStack(alignment: .leading, spacing: MarquiSpacing.xs) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: MarquiRadius.sm)
                            .fill(MarquiColors.surfaceSecondary)
                            .frame(height: 14)
                            .shimmer()
                    }
                    RoundedRectangle(cornerRadius: MarquiRadius.sm)
                        .fill(MarquiColors.surfaceSecondary)
                        .frame(width: 200, height: 14)
                        .shimmer()
                }
                .padding(.horizontal, MarquiSpacing.md)
            }
            .padding(.bottom, MarquiSpacing.xxl)
        }
    }
}

#Preview {
    NavigationStack {
        MediaDetailView(tmdbId: 550, mediaType: .movie)
    }
    .modelContainer(for: [RankedItem.self, WatchlistItem.self, CustomList.self, CustomListItem.self], inMemory: true)
}
