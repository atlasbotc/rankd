import SwiftUI
import SwiftData

struct MediaDetailView: View {
    let tmdbId: Int
    let mediaType: MediaType
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @Query private var rankedItems: [RankedItem]
    @Query private var watchlistItems: [WatchlistItem]
    
    @State private var movieDetail: TMDBMovieDetail?
    @State private var tvDetail: TMDBTVDetail?
    @State private var isLoading = true
    @State private var error: String?
    @State private var synopsisExpanded = false
    
    @State private var showComparisonFlow = false
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
        .background(RankdColors.background)
        .scrollIndicators(.hidden)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await loadDetails()
        }
        .fullScreenCover(isPresented: $showComparisonFlow) {
            if let result = searchResult {
                ComparisonFlowView(newItem: result)
            }
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
            VStack(alignment: .leading, spacing: RankdSpacing.md) {
                // Poster overlay
                HStack(alignment: .bottom, spacing: RankdSpacing.md) {
                    AsyncImage(url: detail.posterURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: RankdPoster.cornerRadius)
                            .fill(RankdColors.surfaceSecondary)
                    }
                    .frame(width: 80, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: RankdPoster.cornerRadius))
                    .shadow(color: RankdShadow.elevated, radius: RankdShadow.elevatedRadius, y: RankdShadow.elevatedY)
                    .offset(y: -40)
                    
                    Spacer()
                }
                .padding(.horizontal, RankdSpacing.md)
                
                // Title
                Text(detail.title)
                    .font(RankdTypography.displayMedium)
                    .foregroundStyle(RankdColors.textPrimary)
                    .padding(.horizontal, RankdSpacing.md)
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
                        .padding(.horizontal, RankdSpacing.md)
                        .offset(y: -8)
                }
                
                // Action buttons (Rank / Watchlist / Add to List)
                actionButtonsSection
                    .padding(.horizontal, RankdSpacing.md)
                
                // Trailer button
                if let trailerURL = detail.trailerURL {
                    trailerButton(url: trailerURL)
                        .padding(.horizontal, RankdSpacing.md)
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
            .padding(.bottom, RankdSpacing.xxl)
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
            VStack(alignment: .leading, spacing: RankdSpacing.md) {
                // Poster overlay
                HStack(alignment: .bottom, spacing: RankdSpacing.md) {
                    AsyncImage(url: detail.posterURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: RankdPoster.cornerRadius)
                            .fill(RankdColors.surfaceSecondary)
                    }
                    .frame(width: 80, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: RankdPoster.cornerRadius))
                    .shadow(color: RankdShadow.elevated, radius: RankdShadow.elevatedRadius, y: RankdShadow.elevatedY)
                    .offset(y: -40)
                    
                    Spacer()
                }
                .padding(.horizontal, RankdSpacing.md)
                
                // Title
                Text(detail.name)
                    .font(RankdTypography.displayMedium)
                    .foregroundStyle(RankdColors.textPrimary)
                    .padding(.horizontal, RankdSpacing.md)
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
                        .padding(.horizontal, RankdSpacing.md)
                        .offset(y: -8)
                }
                
                // Action buttons
                actionButtonsSection
                    .padding(.horizontal, RankdSpacing.md)
                
                // Trailer button
                if let trailerURL = detail.trailerURL {
                    trailerButton(url: trailerURL)
                        .padding(.horizontal, RankdSpacing.md)
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
            .padding(.bottom, RankdSpacing.xxl)
        }
    }
    
    // MARK: - Shared Components
    
    private func backdropHero(backdropURL: URL?, posterURL: URL?) -> some View {
        ZStack(alignment: .bottom) {
            if let backdropURL = backdropURL {
                AsyncImage(url: backdropURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(RankdColors.surfacePrimary)
                        .shimmer()
                }
                .frame(height: 300)
                .clipped()
            } else if let posterURL = posterURL {
                AsyncImage(url: posterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: 30)
                } placeholder: {
                    Rectangle()
                        .fill(RankdColors.surfacePrimary)
                        .shimmer()
                }
                .frame(height: 300)
                .clipped()
            } else {
                Rectangle()
                    .fill(RankdColors.surfacePrimary)
                    .frame(height: 300)
            }
            
            // Gradient overlay
            LinearGradient(
                colors: [
                    .clear,
                    RankdColors.background.opacity(0.6),
                    RankdColors.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 300)
        }
        .frame(height: 300)
    }
    
    private func metadataRow(year: String?, runtime: String?, rating: Double?) -> some View {
        HStack(spacing: RankdSpacing.xs) {
            if let year = year {
                Text(year)
            }
            if let runtime = runtime {
                Text("·")
                Text(runtime)
            }
            if let rating = rating, rating > 0 {
                Text("·")
                HStack(spacing: RankdSpacing.xxs) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(RankdColors.tierMedium)
                    Text(String(format: "%.1f", rating))
                }
            }
        }
        .font(RankdTypography.bodySmall)
        .foregroundStyle(RankdColors.textSecondary)
        .padding(.horizontal, RankdSpacing.md)
    }
    
    private func tvMetadataRow(_ detail: TMDBTVDetail) -> some View {
        HStack(spacing: RankdSpacing.xs) {
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
                HStack(spacing: RankdSpacing.xxs) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(RankdColors.tierMedium)
                    Text(String(format: "%.1f", rating))
                }
            }
        }
        .font(RankdTypography.bodySmall)
        .foregroundStyle(RankdColors.textSecondary)
        .padding(.horizontal, RankdSpacing.md)
    }
    
    private func rankBadge(_ ranked: RankedItem) -> some View {
        let score = RankedItem.calculateScore(for: ranked, allItems: rankedItems)
        
        return VStack(alignment: .leading, spacing: RankdSpacing.xs) {
            HStack(spacing: RankdSpacing.xs) {
                Circle()
                    .fill(RankdColors.tierColor(ranked.tier))
                    .frame(width: 8, height: 8)
                
                Text("#\(ranked.rank) in \(ranked.mediaType == .movie ? "Movies" : "TV Shows")")
                    .font(RankdTypography.labelMedium)
                    .foregroundStyle(RankdColors.textSecondary)
            }
            
            ScoreDisplay(score: score, tier: ranked.tier)
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: RankdSpacing.xs) {
            if !isRanked {
                // Primary: Rank It
                Button {
                    showComparisonFlow = true
                } label: {
                    Text("Rank It")
                        .font(RankdTypography.labelLarge)
                        .foregroundStyle(RankdColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(RankdColors.brand)
                        .clipShape(RoundedRectangle(cornerRadius: RankdRadius.md))
                }
                
                // Secondary: Watchlist
                Button {
                    if isInWatchlist {
                        removeFromWatchlist()
                    } else {
                        addToWatchlist()
                    }
                } label: {
                    HStack(spacing: RankdSpacing.xs) {
                        Image(systemName: isInWatchlist ? "bookmark.fill" : "bookmark")
                        Text(isInWatchlist ? "In Watchlist" : "Watchlist")
                    }
                    .font(RankdTypography.labelLarge)
                    .foregroundStyle(RankdColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(RankdColors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: RankdRadius.md))
                }
            }
            
            // Tertiary: Add to List
            Button {
                showAddToList = true
            } label: {
                Text("Add to List")
                    .font(RankdTypography.labelLarge)
                    .foregroundStyle(RankdColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
        }
    }
    
    private func trailerButton(url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack(spacing: RankdSpacing.xs) {
                Image(systemName: "play.fill")
                    .font(.system(size: 12))
                Text("Watch Trailer")
            }
            .font(RankdTypography.labelLarge)
            .foregroundStyle(RankdColors.brand)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(RankdColors.brandSubtle)
            .clipShape(RoundedRectangle(cornerRadius: RankdRadius.md))
        }
        .buttonStyle(RankdPressStyle())
    }
    
    private func genrePills(_ genres: [TMDBGenre]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: RankdSpacing.xs) {
                ForEach(genres) { genre in
                    Text(genre.name)
                        .font(RankdTypography.labelSmall)
                        .foregroundStyle(RankdColors.textSecondary)
                        .padding(.horizontal, RankdSpacing.sm)
                        .padding(.vertical, RankdSpacing.xxs)
                        .background(RankdColors.surfaceSecondary)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, RankdSpacing.md)
        }
    }
    
    private func synopsisSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: RankdSpacing.xs) {
            Text("Synopsis")
                .font(RankdTypography.headingSmall)
                .foregroundStyle(RankdColors.textPrimary)
            
            Text(text)
                .font(RankdTypography.bodyMedium)
                .foregroundStyle(RankdColors.textSecondary)
                .lineLimit(synopsisExpanded ? nil : 3)
                .lineSpacing(4)
            
            if !synopsisExpanded && text.count > 150 {
                Button {
                    withAnimation(RankdMotion.normal) {
                        synopsisExpanded = true
                    }
                } label: {
                    Text("Read more")
                        .font(RankdTypography.labelMedium)
                        .foregroundStyle(RankdColors.brand)
                }
                .padding(.top, RankdSpacing.xxs)
            }
        }
        .padding(.horizontal, RankdSpacing.md)
        .padding(.top, RankdSpacing.lg)
    }
    
    // MARK: - Where to Watch
    
    private func watchProvidersSection(_ providers: [TMDBWatchProvider], watchLink: URL?) -> some View {
        VStack(alignment: .leading, spacing: RankdSpacing.sm) {
            Text("Where to Watch")
                .font(RankdTypography.headingSmall)
                .foregroundStyle(RankdColors.textPrimary)
                .padding(.horizontal, RankdSpacing.md)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: RankdSpacing.sm) {
                    ForEach(providers) { provider in
                        VStack(spacing: RankdSpacing.xxs) {
                            AsyncImage(url: provider.logoURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: RankdRadius.sm)
                                    .fill(RankdColors.surfaceSecondary)
                            }
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: RankdRadius.sm))
                            
                            Text(provider.providerName)
                                .font(RankdTypography.caption)
                                .foregroundStyle(RankdColors.textTertiary)
                                .lineLimit(1)
                        }
                        .frame(width: 64)
                    }
                }
                .padding(.horizontal, RankdSpacing.md)
            }
            
            if let watchLink = watchLink {
                Button {
                    openURL(watchLink)
                } label: {
                    Text("View all options on TMDB")
                        .font(RankdTypography.caption)
                        .foregroundStyle(RankdColors.brand)
                }
                .padding(.horizontal, RankdSpacing.md)
                .padding(.top, RankdSpacing.xxs)
            }
        }
        .padding(.top, RankdSpacing.lg)
    }
    
    // MARK: - Cast & Crew
    
    private func castSection(_ cast: [TMDBCastMember]) -> some View {
        VStack(alignment: .leading, spacing: RankdSpacing.sm) {
            Text("Cast")
                .font(RankdTypography.headingSmall)
                .foregroundStyle(RankdColors.textPrimary)
                .padding(.horizontal, RankdSpacing.md)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: RankdSpacing.md) {
                    ForEach(cast) { member in
                        VStack(spacing: RankdSpacing.xs) {
                            AsyncImage(url: member.profileURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(RankdColors.surfaceSecondary)
                                    .overlay {
                                        Image(systemName: "person.fill")
                                            .font(RankdTypography.bodySmall)
                                            .foregroundStyle(RankdColors.textTertiary)
                                    }
                            }
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                            
                            Text(member.name)
                                .font(RankdTypography.labelSmall)
                                .foregroundStyle(RankdColors.textPrimary)
                                .lineLimit(1)
                            
                            if let character = member.character {
                                Text(character)
                                    .font(RankdTypography.caption)
                                    .foregroundStyle(RankdColors.textTertiary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(width: 72)
                    }
                }
                .padding(.horizontal, RankdSpacing.md)
            }
        }
        .padding(.top, RankdSpacing.lg)
    }
    
    private func crewSection(_ crew: [TMDBCrewMember]) -> some View {
        VStack(alignment: .leading, spacing: RankdSpacing.sm) {
            Text("Crew")
                .font(RankdTypography.headingSmall)
                .foregroundStyle(RankdColors.textPrimary)
                .padding(.horizontal, RankdSpacing.md)
            
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: RankdSpacing.sm
            ) {
                ForEach(crew) { member in
                    VStack(alignment: .leading, spacing: RankdSpacing.xxs) {
                        Text(member.name)
                            .font(RankdTypography.labelMedium)
                            .foregroundStyle(RankdColors.textPrimary)
                        if let job = member.job {
                            Text(job)
                                .font(RankdTypography.caption)
                                .foregroundStyle(RankdColors.textTertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, RankdSpacing.md)
        }
        .padding(.top, RankdSpacing.lg)
    }
    
    // MARK: - Similar Titles
    
    private func similarTitlesSection(_ titles: [TMDBSearchResult]) -> some View {
        VStack(alignment: .leading, spacing: RankdSpacing.sm) {
            Text("You Might Also Like")
                .font(RankdTypography.headingSmall)
                .foregroundStyle(RankdColors.textPrimary)
                .padding(.horizontal, RankdSpacing.md)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: RankdSpacing.sm) {
                    ForEach(Array(titles.prefix(15))) { item in
                        NavigationLink {
                            MediaDetailView(
                                tmdbId: item.id,
                                mediaType: item.resolvedMediaType
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: RankdSpacing.xs) {
                                AsyncImage(url: item.posterURL) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: RankdPoster.cornerRadius)
                                        .fill(RankdColors.surfaceSecondary)
                                }
                                .frame(width: RankdPoster.standardWidth, height: RankdPoster.standardHeight)
                                .clipShape(RoundedRectangle(cornerRadius: RankdPoster.cornerRadius))
                                
                                Text(item.displayTitle)
                                    .font(RankdTypography.labelSmall)
                                    .foregroundStyle(RankdColors.textPrimary)
                                    .lineLimit(1)
                                
                                if let rating = item.voteAverage, rating > 0 {
                                    HStack(spacing: RankdSpacing.xxs) {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 9))
                                            .foregroundStyle(RankdColors.tierMedium)
                                        Text(String(format: "%.1f", rating))
                                            .font(RankdTypography.caption)
                                            .foregroundStyle(RankdColors.textTertiary)
                                    }
                                }
                            }
                            .frame(width: RankdPoster.standardWidth)
                        }
                        .buttonStyle(RankdPressStyle())
                    }
                }
                .padding(.horizontal, RankdSpacing.md)
            }
        }
        .padding(.top, RankdSpacing.lg)
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: RankdSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(RankdColors.textTertiary)
            
            Text(message)
                .font(RankdTypography.bodyMedium)
                .multilineTextAlignment(.center)
                .foregroundStyle(RankdColors.textSecondary)
        }
        .padding(RankdSpacing.lg)
        .padding(.top, RankdSpacing.xxl)
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
            try? modelContext.save()
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
        try? modelContext.save()
        HapticManager.impact(.light)
    }
    
    // MARK: - Skeleton Loading
    
    private var mediaDetailSkeleton: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Backdrop placeholder
            Rectangle()
                .fill(RankdColors.surfacePrimary)
                .frame(height: 300)
                .shimmer()
            
            VStack(alignment: .leading, spacing: RankdSpacing.md) {
                // Poster placeholder
                RoundedRectangle(cornerRadius: RankdPoster.cornerRadius)
                    .fill(RankdColors.surfaceSecondary)
                    .frame(width: 80, height: 120)
                    .offset(y: -40)
                    .shimmer()
                    .padding(.horizontal, RankdSpacing.md)
                
                // Title placeholder
                RoundedRectangle(cornerRadius: RankdRadius.sm)
                    .fill(RankdColors.surfaceSecondary)
                    .frame(width: 220, height: 28)
                    .shimmer()
                    .padding(.horizontal, RankdSpacing.md)
                    .offset(y: -24)
                
                // Metadata placeholder
                RoundedRectangle(cornerRadius: RankdRadius.sm)
                    .fill(RankdColors.surfaceSecondary)
                    .frame(width: 160, height: 14)
                    .shimmer()
                    .padding(.horizontal, RankdSpacing.md)
                    .offset(y: -16)
                
                // Synopsis placeholder
                VStack(alignment: .leading, spacing: RankdSpacing.xs) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: RankdRadius.sm)
                            .fill(RankdColors.surfaceSecondary)
                            .frame(height: 14)
                            .shimmer()
                    }
                    RoundedRectangle(cornerRadius: RankdRadius.sm)
                        .fill(RankdColors.surfaceSecondary)
                        .frame(width: 200, height: 14)
                        .shimmer()
                }
                .padding(.horizontal, RankdSpacing.md)
            }
            .padding(.bottom, RankdSpacing.xxl)
        }
    }
}

#Preview {
    NavigationStack {
        MediaDetailView(tmdbId: 550, mediaType: .movie)
    }
    .modelContainer(for: [RankedItem.self, WatchlistItem.self, CustomList.self, CustomListItem.self], inMemory: true)
}
