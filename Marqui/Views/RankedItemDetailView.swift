import SwiftUI
import SwiftData

/// Detail view for a ranked item, matching the v3 dark theme design.
struct RankedItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \RankedItem.rank) private var allItems: [RankedItem]
    @Bindable var item: RankedItem
    
    @State private var movieDetail: TMDBMovieDetail?
    @State private var tvDetail: TMDBTVDetail?
    @State private var isLoading = true
    @State private var editedNote: String = ""
    @State private var isEditingNote = false
    @State private var reRankSearchResult: TMDBSearchResult?
    
    private var score: Double {
        RankedItem.calculateScore(for: item, allItems: allItems.filter { $0.mediaType == item.mediaType })
    }
    
    private var filteredItems: [RankedItem] {
        allItems.filter { $0.mediaType == item.mediaType }
    }
    
    private var director: String? {
        if let credits = movieDetail?.credits {
            return credits.crew.first { $0.job == "Director" }?.name
        }
        if let creators = tvDetail?.createdBy, !creators.isEmpty {
            return creators.map { $0.name }.joined(separator: ", ")
        }
        return nil
    }
    
    private var topCast: String? {
        if let cast = movieDetail?.credits?.cast.prefix(3), !cast.isEmpty {
            return cast.map { $0.name }.joined(separator: ", ")
        }
        if let cast = tvDetail?.credits?.cast.prefix(3), !cast.isEmpty {
            return cast.map { $0.name }.joined(separator: ", ")
        }
        return nil
    }
    
    private var runtime: String? {
        if let runtime = movieDetail?.runtime, runtime > 0 {
            return "\(runtime) min"
        }
        if let runtime = tvDetail?.episodeRunTime?.first {
            return "\(runtime) min/ep"
        }
        return nil
    }
    
    private var genre: String? {
        if let genres = movieDetail?.genres, let first = genres.first {
            return first.name
        }
        if let genres = tvDetail?.genres, let first = genres.first {
            return first.name
        }
        return nil
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Back button
                    backButton
                    
                    // Hero image with gradient
                    heroImage
                    
                    // Title lockup
                    titleLockup
                    
                    // Meta strip
                    metaStrip
                    
                    // Data table
                    dataTable
                    
                    // Action buttons
                    actionButtons
                }
            }
            .scrollIndicators(.hidden)
            .background(MarquiColors.background)
            .navigationBarHidden(true)
            .task {
                await loadDetails()
            }
            .fullScreenCover(item: $reRankSearchResult) { result in
                ComparisonFlowView(newItem: result)
            }
            .onChange(of: reRankSearchResult) { _, newValue in
                if newValue == nil {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Back Button
    
    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: MarquiSpacing.xs) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                Text("BACK")
                    .font(MarquiTypography.captionMono)
                    .tracking(2)
            }
            .foregroundStyle(MarquiColors.textTertiary)
        }
        .padding(.horizontal, MarquiSpacing.lg)
        .padding(.vertical, MarquiSpacing.sm)
        .background(MarquiColors.background)
    }
    
    // MARK: - Hero Image
    
    private var heroImage: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                CachedAsyncImage(url: item.posterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(MarquiColors.surfaceSecondary)
                }
                .frame(width: geo.size.width, height: 280)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: MarquiRadius.sm))
                
                // Gradient overlay
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.clear,
                        MarquiColors.background.opacity(0.85),
                        MarquiColors.background
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .frame(height: 280)
        .padding(.horizontal, MarquiSpacing.lg)
    }
    
    // MARK: - Title Lockup
    
    private var titleLockup: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: MarquiSpacing.xs) {
                // Rank tag
                Text("№ \(String(format: "%02d", item.rank)) OF \(filteredItems.count)")
                    .font(MarquiTypography.captionMono)
                    .tracking(2)
                    .foregroundStyle(MarquiColors.accent)
                
                // Title
                Text(item.title)
                    .font(MarquiTypography.filmTitleLarge)
                    .foregroundStyle(MarquiColors.textPrimary)
            }
            
            Spacer()
            
            // Score
            Text(String(format: "%.1f", score))
                .font(MarquiTypography.scoreLarge)
                .foregroundStyle(MarquiColors.accent)
        }
        .padding(.horizontal, MarquiSpacing.lg)
        .padding(.bottom, MarquiSpacing.md)
        .offset(y: -48)
    }
    
    // MARK: - Meta Strip
    
    private var metaStrip: some View {
        HStack(spacing: MarquiSpacing.md) {
            if let year = item.year {
                metaItem(year)
            }
            
            if let genre = genre {
                metaItem(genre)
            }
            
            if let runtime = runtime {
                metaItem(runtime)
            }
            
            metaItem("\(item.comparisonCount) wins")
        }
        .padding(.horizontal, MarquiSpacing.lg)
        .padding(.vertical, MarquiSpacing.sm)
        .offset(y: -40)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(MarquiColors.divider)
                .frame(height: 1)
                .padding(.horizontal, MarquiSpacing.lg)
                .offset(y: -40)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MarquiColors.divider)
                .frame(height: 1)
                .padding(.horizontal, MarquiSpacing.lg)
                .offset(y: -40)
        }
    }
    
    private func metaItem(_ text: String) -> some View {
        Text(text.uppercased())
            .font(MarquiTypography.captionMono)
            .tracking(1)
            .foregroundStyle(MarquiColors.textSecondary)
    }
    
    // MARK: - Data Table
    
    private var dataTable: some View {
        VStack(spacing: 0) {
            if let director = director {
                dataRow(key: "DIRECTOR", value: director)
            }
            
            dataRow(key: "RANKED", value: item.dateAdded.formatted(.dateTime.month(.wide).day().year()))
            
            if let cast = topCast {
                dataRow(key: "CAST", value: cast)
            }
            
            // Note row with left border accent
            noteRow
        }
        .padding(.horizontal, MarquiSpacing.lg)
        .offset(y: -32)
    }
    
    private func dataRow(key: String, value: String) -> some View {
        HStack(alignment: .top, spacing: MarquiSpacing.md) {
            Text(key)
                .font(MarquiTypography.captionMono)
                .tracking(2)
                .foregroundStyle(MarquiColors.textTertiary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(MarquiTypography.bodySmall)
                .foregroundStyle(MarquiColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, MarquiSpacing.sm)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MarquiColors.divider)
                .frame(height: 1)
        }
    }
    
    private var noteRow: some View {
        HStack(alignment: .top, spacing: MarquiSpacing.md) {
            Text("NOTE")
                .font(MarquiTypography.captionMono)
                .tracking(2)
                .foregroundStyle(MarquiColors.textTertiary)
                .frame(width: 80, alignment: .leading)
            
            if isEditingNote {
                TextEditor(text: $editedNote)
                    .font(MarquiTypography.bodySmall)
                    .foregroundStyle(MarquiColors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 60)
                    .padding(.leading, MarquiSpacing.sm)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(MarquiColors.brandSecondary)
                            .frame(width: 2)
                    }
            } else if let review = item.review, !review.isEmpty {
                Text(review)
                    .font(.system(size: 14, design: .serif))
                    .italic()
                    .foregroundStyle(MarquiColors.textPrimary)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, MarquiSpacing.sm)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(MarquiColors.brandSecondary)
                            .frame(width: 2)
                    }
            } else {
                Text("Tap Edit Note to add your thoughts")
                    .font(MarquiTypography.bodySmall)
                    .foregroundStyle(MarquiColors.textTertiary)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, MarquiSpacing.sm)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: MarquiSpacing.xs) {
            // Compare button (CTA)
            actionButton(
                title: "Compare Against List",
                isPrimary: true,
                action: { /* Future: comparison mode */ }
            )
            
            // Edit Note
            actionButton(
                title: isEditingNote ? "Save Note" : "Edit Note",
                isPrimary: false,
                action: {
                    if isEditingNote {
                        item.review = editedNote.isEmpty ? nil : editedNote
                        modelContext.safeSave()
                    } else {
                        editedNote = item.review ?? ""
                    }
                    isEditingNote.toggle()
                }
            )
            
            // Re-rank
            actionButton(
                title: "Re-rank",
                isPrimary: false,
                action: startReRank
            )
            
            // Remove
            actionButton(
                title: "Remove from Rankings",
                isPrimary: false,
                action: {
                    removeFromRankings()
                    dismiss()
                }
            )
        }
        .padding(.horizontal, MarquiSpacing.lg)
        .padding(.vertical, MarquiSpacing.md)
        .offset(y: -24)
    }
    
    private func actionButton(title: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title.uppercased())
                    .font(MarquiTypography.captionMono)
                    .tracking(1.5)
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 12))
                    .opacity(0.4)
            }
            .foregroundStyle(isPrimary ? MarquiColors.background : MarquiColors.textTertiary)
            .padding(.vertical, MarquiSpacing.sm)
            .padding(.horizontal, MarquiSpacing.md)
            .background(isPrimary ? MarquiColors.accent : Color.clear)
            .overlay {
                if !isPrimary {
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(MarquiColors.divider, lineWidth: 1)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func loadDetails() async {
        isLoading = true
        
        do {
            if item.mediaType == .movie {
                movieDetail = try await TMDBService.shared.getMovieDetails(id: item.tmdbId)
            } else {
                tvDetail = try await TMDBService.shared.getTVDetails(id: item.tmdbId)
            }
        } catch {
            print("Failed to load details: \(error)")
        }
        
        isLoading = false
    }
    
    private func startReRank() {
        let result = TMDBSearchResult(
            id: item.tmdbId,
            title: item.mediaType == .movie ? item.title : nil,
            name: item.mediaType == .tv ? item.title : nil,
            overview: item.overview,
            posterPath: item.posterPath,
            releaseDate: item.mediaType == .movie ? item.releaseDate : nil,
            firstAirDate: item.mediaType == .tv ? item.releaseDate : nil,
            mediaType: item.mediaType.rawValue,
            voteAverage: nil
        )
        
        let deletedRank = item.rank
        let deletedId = item.id
        let mediaType = item.mediaType
        modelContext.delete(item)
        modelContext.safeSave()
        
        RankingService.shiftRanksAfterDeletion(
            excludingId: deletedId,
            deletedRank: deletedRank,
            mediaType: mediaType,
            in: allItems,
            context: modelContext
        )
        
        HapticManager.impact(.medium)
        reRankSearchResult = result
    }
    
    private func removeFromRankings() {
        let deletedRank = item.rank
        let deletedId = item.id
        let mediaType = item.mediaType
        modelContext.delete(item)
        modelContext.safeSave()
        
        RankingService.shiftRanksAfterDeletion(
            excludingId: deletedId,
            deletedRank: deletedRank,
            mediaType: mediaType,
            in: allItems,
            context: modelContext
        )
        
        WidgetDataManager.refreshWidgetData(from: allItems)
        HapticManager.notification(.warning)
    }
}

#Preview {
    RankedItemDetailView(
        item: {
            let item = RankedItem(
                tmdbId: 693134,
                title: "Dune: Part Two",
                overview: "Follow the mythic journey of Paul Atreides...",
                posterPath: "/1XDDXPXGiI8id7MrUxK36ke7gkX.jpg",
                releaseDate: "2024-02-27",
                mediaType: .movie,
                tier: .good,
                review: "The sandworm sequence alone earns this its rank."
            )
            item.rank = 1
            return item
        }()
    )
    .modelContainer(for: RankedItem.self, inMemory: true)
}
