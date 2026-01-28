import SwiftUI
import SwiftData

struct MediaDetailView: View {
    let tmdbId: Int
    let mediaType: MediaType
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var rankedItems: [RankedItem]
    @Query private var watchlistItems: [WatchlistItem]
    
    @State private var movieDetail: TMDBMovieDetail?
    @State private var tvDetail: TMDBTVDetail?
    @State private var isLoading = true
    @State private var error: String?
    
    @State private var showAddSheet = false
    @State private var showComparisonFlow = false
    
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
                ProgressView()
                    .padding(.top, 100)
            } else if let error = error {
                errorView(error)
            } else if mediaType == .movie, let detail = movieDetail {
                movieContent(detail)
            } else if mediaType == .tv, let detail = tvDetail {
                tvContent(detail)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetails()
        }
        .sheet(isPresented: $showAddSheet) {
            if let result = searchResult {
                QuickAddSheet(
                    result: result,
                    status: itemStatus,
                    onWatchlist: {
                        addToWatchlist()
                        showAddSheet = false
                    },
                    onRank: {
                        showAddSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showComparisonFlow = true
                        }
                    }
                )
                .presentationDetents([.medium])
            }
        }
        .fullScreenCover(isPresented: $showComparisonFlow) {
            if let result = searchResult {
                ComparisonFlowView(newItem: result)
            }
        }
    }
    
    // MARK: - Movie Content
    
    private func movieContent(_ detail: TMDBMovieDetail) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Backdrop
            if let backdropURL = detail.backdropURL {
                AsyncImage(url: backdropURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(.quaternary)
                }
                .frame(height: 200)
                .clipped()
            }
            
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(alignment: .top, spacing: 16) {
                    AsyncImage(url: detail.posterURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(.quaternary)
                    }
                    .frame(width: 100, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 4)
                    .offset(y: -40)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(detail.title)
                            .font(.title2.bold())
                        
                        // Quick info
                        HStack(spacing: 12) {
                            if let year = detail.year {
                                Label(year, systemImage: "calendar")
                            }
                            if let runtime = detail.runtimeFormatted {
                                Label(runtime, systemImage: "clock")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        
                        // Rating
                        if let rating = detail.voteAverage, rating > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                Text(String(format: "%.1f", rating))
                                    .fontWeight(.semibold)
                                if let count = detail.voteCount {
                                    Text("(\(count.formatted()))")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .font(.subheadline)
                        }
                        
                        // User's ranking
                        if let ranked = rankedItem {
                            HStack {
                                Text(ranked.tier.emoji)
                                Text("#\(ranked.rank)")
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.orange.opacity(0.2))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal)
                
                // Action buttons
                if !isRanked {
                    actionButtons
                }
                
                // Director
                if let director = detail.director {
                    InfoRow(label: "Directed by", value: director.name)
                }
                
                // Genres
                if !detail.genres.isEmpty {
                    GenreTagsView(genres: detail.genres)
                }
                
                // Tagline
                if let tagline = detail.tagline, !tagline.isEmpty {
                    Text("\"\(tagline)\"")
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
                
                // Overview
                if let overview = detail.overview, !overview.isEmpty {
                    SectionView(title: "Synopsis") {
                        Text(overview)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Cast
                if let credits = detail.credits, !credits.cast.isEmpty {
                    CastSection(cast: Array(credits.cast.prefix(10)))
                }
                
                // Crew
                if let credits = detail.credits {
                    let keyCrews = credits.crew.filter { 
                        ["Director", "Writer", "Screenplay", "Producer", "Director of Photography", "Composer"].contains($0.job ?? "")
                    }
                    if !keyCrews.isEmpty {
                        CrewSection(crew: Array(keyCrews.prefix(8)))
                    }
                }
                
                // Additional info
                AdditionalInfoSection(items: movieInfoItems(detail))
            }
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - TV Content
    
    private func tvContent(_ detail: TMDBTVDetail) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Backdrop
            if let backdropURL = detail.backdropURL {
                AsyncImage(url: backdropURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(.quaternary)
                }
                .frame(height: 200)
                .clipped()
            }
            
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(alignment: .top, spacing: 16) {
                    AsyncImage(url: detail.posterURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(.quaternary)
                    }
                    .frame(width: 100, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 4)
                    .offset(y: -40)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(detail.name)
                            .font(.title2.bold())
                        
                        // Quick info
                        HStack(spacing: 12) {
                            if let yearRange = detail.yearRange {
                                Label(yearRange, systemImage: "calendar")
                            }
                            if let seasons = detail.numberOfSeasons {
                                Label("\(seasons) season\(seasons == 1 ? "" : "s")", systemImage: "tv")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        
                        // Rating
                        if let rating = detail.voteAverage, rating > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                Text(String(format: "%.1f", rating))
                                    .fontWeight(.semibold)
                                if let count = detail.voteCount {
                                    Text("(\(count.formatted()))")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .font(.subheadline)
                        }
                        
                        // User's ranking
                        if let ranked = rankedItem {
                            HStack {
                                Text(ranked.tier.emoji)
                                Text("#\(ranked.rank)")
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.orange.opacity(0.2))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal)
                
                // Action buttons
                if !isRanked {
                    actionButtons
                }
                
                // Created by
                if let creators = detail.createdBy, !creators.isEmpty {
                    InfoRow(label: "Created by", value: creators.map { $0.name }.joined(separator: ", "))
                }
                
                // Genres
                if !detail.genres.isEmpty {
                    GenreTagsView(genres: detail.genres)
                }
                
                // Tagline
                if let tagline = detail.tagline, !tagline.isEmpty {
                    Text("\"\(tagline)\"")
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
                
                // Overview
                if let overview = detail.overview, !overview.isEmpty {
                    SectionView(title: "Synopsis") {
                        Text(overview)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Cast
                if let credits = detail.credits, !credits.cast.isEmpty {
                    CastSection(cast: Array(credits.cast.prefix(10)))
                }
                
                // Additional info
                AdditionalInfoSection(items: tvInfoItems(detail))
            }
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Components
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                addToWatchlist()
            } label: {
                Label(isInWatchlist ? "In Watchlist" : "Watchlist", systemImage: isInWatchlist ? "bookmark.fill" : "bookmark")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isInWatchlist ? Color.blue : Color.blue.opacity(0.15))
                    .foregroundStyle(isInWatchlist ? .white : .blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(isInWatchlist)
            
            Button {
                showComparisonFlow = true
            } label: {
                Label("Rank It", systemImage: "list.number")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.15))
                    .foregroundStyle(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.horizontal)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
        .padding(.top, 50)
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
                voteAverage: movie.voteAverage
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
                voteAverage: tv.voteAverage
            )
        }
        return nil
    }
    
    private var itemStatus: ItemStatus {
        if isRanked { return .ranked }
        if isInWatchlist { return .watchlist }
        return .notAdded
    }
    
    private func movieInfoItems(_ detail: TMDBMovieDetail) -> [(String, String)] {
        var items: [(String, String)] = []
        if let status = detail.status {
            items.append(("Status", status))
        }
        if let budget = detail.budget, budget > 0 {
            items.append(("Budget", "$\(budget.formatted())"))
        }
        if let revenue = detail.revenue, revenue > 0 {
            items.append(("Revenue", "$\(revenue.formatted())"))
        }
        return items
    }
    
    private func tvInfoItems(_ detail: TMDBTVDetail) -> [(String, String)] {
        var items: [(String, String)] = []
        if let status = detail.status {
            items.append(("Status", status))
        }
        if let episodes = detail.numberOfEpisodes {
            items.append(("Episodes", "\(episodes) episodes"))
        }
        if let runtime = detail.episodeRuntimeFormatted {
            items.append(("Episode Length", runtime))
        }
        return items
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
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
        .padding(.horizontal)
    }
}

struct GenreTagsView: View {
    let genres: [TMDBGenre]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(genres) { genre in
                    Text(genre.name)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
        }
    }
}

struct SectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content
        }
        .padding(.horizontal)
    }
}

struct CastSection: View {
    let cast: [TMDBCastMember]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cast")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(cast) { member in
                        VStack(spacing: 6) {
                            AsyncImage(url: member.profileURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(.quaternary)
                                    .overlay {
                                        Image(systemName: "person.fill")
                                            .foregroundStyle(.tertiary)
                                    }
                            }
                            .frame(width: 70, height: 70)
                            .clipShape(Circle())
                            
                            Text(member.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            
                            if let character = member.character {
                                Text(character)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(width: 80)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct CrewSection: View {
    let crew: [TMDBCrewMember]
    
    var body: some View {
        SectionView(title: "Crew") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(crew) { member in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if let job = member.job {
                                Text(job)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
    }
}

struct AdditionalInfoSection: View {
    let items: [(String, String)]
    
    var body: some View {
        if !items.isEmpty {
            SectionView(title: "Details") {
                VStack(spacing: 8) {
                    ForEach(items, id: \.0) { item in
                        HStack {
                            Text(item.0)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(item.1)
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        MediaDetailView(tmdbId: 550, mediaType: .movie) // Fight Club
    }
    .modelContainer(for: [RankedItem.self, WatchlistItem.self], inMemory: true)
}
