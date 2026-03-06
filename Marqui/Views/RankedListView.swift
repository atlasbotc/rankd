import SwiftUI
import SwiftData

struct RankedListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RankedItem.rank) private var allItems: [RankedItem]
    @State private var selectedMediaType: MediaType = .movie
    @State private var showDeleteConfirmation = false
    @State private var itemToDelete: RankedItem?
    @State private var selectedItem: RankedItem?
    @State private var isReorderMode = false
    @State private var reRankSearchResult: TMDBSearchResult?
    @State private var showReRankPrompt = false
    @State private var showFavoritesOnly = false
    @AppStorage("lastReRankMilestone") private var lastReRankMilestone: Int = 0
    
    var filteredItems: [RankedItem] {
        allItems
            .filter { $0.mediaType == selectedMediaType }
            .filter { !showFavoritesOnly || $0.isFavorite }
            .sorted { $0.rank < $1.rank }
    }
    
    private var averageScore: Double {
        guard !filteredItems.isEmpty else { return 0 }
        let scores = filteredItems.map { RankedItem.calculateScore(for: $0, allItems: filteredItems) }
        return scores.reduce(0, +) / Double(scores.count)
    }
    
    private var rankedThisYear: Int {
        let calendar = Calendar.current
        let thisYear = calendar.component(.year, from: Date())
        return filteredItems.filter { item in
            return calendar.component(.year, from: item.dateAdded) == thisYear
        }.count
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom header
                headerView
                
                // Tab underline picker
                tabPicker
                
                if filteredItems.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    // Stats row
                    statsRow
                    
                    // Rankings list
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                                RankedItemRowV3(
                                    item: item,
                                    rank: index + 1,
                                    allItems: filteredItems,
                                    onTap: { selectedItem = item },
                                    onDelete: {
                                        itemToDelete = item
                                        showDeleteConfirmation = true
                                    },
                                    onReRank: { startReRank(for: item) }
                                )
                            }
                            .onMove(perform: isReorderMode ? moveItems : nil)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .environment(\.editMode, .constant(isReorderMode ? .active : .inactive))
                }
            }
            .background(MarquiColors.background)
            .navigationBarHidden(true)
            .alert("Remove from Rankings?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    if let item = itemToDelete {
                        deleteItem(item)
                    }
                }
            } message: {
                if let item = itemToDelete {
                    Text("Remove \"\(item.title)\" from your rankings?")
                }
            }
            .sheet(item: $selectedItem) { item in
                RankedItemDetailView(item: item)
            }
            .fullScreenCover(item: $reRankSearchResult) { result in
                ComparisonFlowView(newItem: result)
            }
            .onChange(of: filteredItems.count) { _, newCount in
                checkReRankMilestone(count: newCount)
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: MarquiSpacing.xxs) {
                Text("MARQUI")
                    .font(MarquiTypography.logo)
                    .foregroundStyle(MarquiColors.textPrimary)
                    .tracking(-0.5)
                
                Text("FILM JOURNAL")
                    .font(MarquiTypography.logoSubtitle)
                    .foregroundStyle(MarquiColors.textTertiary)
                    .tracking(3)
            }
            
            Spacer()
            
            HStack(spacing: MarquiSpacing.md) {
                // Search icon
                NavigationLink(destination: SearchView()) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(MarquiColors.textSecondary)
                }
                
                // Add icon
                NavigationLink(destination: SearchView()) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(MarquiColors.textSecondary)
                }
            }
            .padding(.bottom, MarquiSpacing.xxs)
        }
        .padding(.horizontal, MarquiSpacing.lg)
        .padding(.top, MarquiSpacing.md)
        .padding(.bottom, MarquiSpacing.sm)
        .background(MarquiColors.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MarquiColors.divider)
                .frame(height: 1)
        }
    }
    
    // MARK: - Tab Picker (underline style)
    
    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach([MediaType.movie, MediaType.tv], id: \.self) { type in
                Button {
                    withAnimation(MarquiMotion.fast) {
                        selectedMediaType = type
                    }
                } label: {
                    VStack(spacing: MarquiSpacing.xs) {
                        Text(type == .movie ? "FILMS" : "SERIES")
                            .font(MarquiTypography.captionMono)
                            .tracking(2)
                            .foregroundStyle(
                                selectedMediaType == type
                                    ? MarquiColors.textPrimary
                                    : MarquiColors.textTertiary
                            )
                        
                        Rectangle()
                            .fill(selectedMediaType == type ? MarquiColors.accent : Color.clear)
                            .frame(height: 2)
                    }
                    .padding(.trailing, MarquiSpacing.md)
                }
            }
            
            // Lists tab placeholder
            Button {
                // Future: Lists tab
            } label: {
                VStack(spacing: MarquiSpacing.xs) {
                    Text("LISTS")
                        .font(MarquiTypography.captionMono)
                        .tracking(2)
                        .foregroundStyle(MarquiColors.textTertiary)
                    
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 2)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, MarquiSpacing.lg)
        .padding(.top, MarquiSpacing.xs)
        .background(MarquiColors.background)
    }
    
    // MARK: - Stats Row (asymmetric)
    
    private var statsRow: some View {
        HStack(spacing: 1) {
            // Big ranked count
            VStack(alignment: .leading, spacing: MarquiSpacing.xxs) {
                Text("\(filteredItems.count)")
                    .font(MarquiTypography.scoreLarge)
                    .foregroundStyle(MarquiColors.accent)
                
                Text("RANKED")
                    .font(MarquiTypography.captionMono)
                    .tracking(2)
                    .foregroundStyle(MarquiColors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(MarquiSpacing.md)
            .background(MarquiColors.background)
            
            // Average score
            VStack(alignment: .leading, spacing: MarquiSpacing.xxs) {
                Text(String(format: "%.1f", averageScore))
                    .font(MarquiTypography.scoreMedium)
                    .foregroundStyle(MarquiColors.textPrimary)
                
                Text("AVERAGE")
                    .font(MarquiTypography.captionMono)
                    .tracking(2)
                    .foregroundStyle(MarquiColors.textTertiary)
            }
            .padding(MarquiSpacing.md)
            .background(MarquiColors.surfacePrimary)
            
            // This year
            VStack(alignment: .leading, spacing: MarquiSpacing.xxs) {
                Text("\(rankedThisYear)")
                    .font(MarquiTypography.scoreMedium)
                    .foregroundStyle(MarquiColors.textPrimary)
                
                Text("THIS YEAR")
                    .font(MarquiTypography.captionMono)
                    .tracking(2)
                    .foregroundStyle(MarquiColors.textTertiary)
            }
            .padding(MarquiSpacing.md)
            .background(MarquiColors.surfacePrimary)
        }
        .background(MarquiColors.divider)
        .padding(.horizontal, MarquiSpacing.lg)
        .padding(.vertical, MarquiSpacing.md)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: MarquiSpacing.lg) {
            Image(systemName: "film.stack")
                .font(.system(size: 48))
                .foregroundStyle(MarquiColors.textQuaternary)
            
            VStack(spacing: MarquiSpacing.xs) {
                Text("Start ranking what you love")
                    .font(MarquiTypography.headingLarge)
                    .foregroundStyle(MarquiColors.textPrimary)
                
                Text("Search for movies and shows you've watched,\nthen rank them through head-to-head comparisons.")
                    .font(MarquiTypography.bodyMedium)
                    .foregroundStyle(MarquiColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            NavigationLink(destination: SearchView()) {
                Text("Search & Rank")
                    .font(MarquiTypography.labelLarge)
                    .foregroundStyle(MarquiColors.background)
                    .padding(.horizontal, MarquiSpacing.xl)
                    .padding(.vertical, MarquiSpacing.sm)
                    .background(MarquiColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: MarquiRadius.sm))
            }
            .padding(.top, MarquiSpacing.xs)
        }
        .padding(.horizontal, MarquiSpacing.lg)
    }
    
    // MARK: - Re-rank Helpers
    
    private func checkReRankMilestone(count: Int) {
        let milestones = [5, 10, 20]
        for milestone in milestones {
            if count == milestone && lastReRankMilestone < milestone {
                withAnimation(MarquiMotion.normal) {
                    showReRankPrompt = true
                }
                return
            }
        }
    }
    
    private func startReRank(for item: RankedItem) {
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
    
    // MARK: - Actions
    
    private func deleteItem(_ item: RankedItem) {
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
        updateWidgetData()
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        var reordered = filteredItems
        reordered.move(fromOffsets: source, toOffset: destination)
        
        for (index, item) in reordered.enumerated() {
            item.rank = index + 1
        }
        
        HapticManager.selection()
        modelContext.safeSave()
        updateWidgetData()
    }
    
    private func updateWidgetData() {
        WidgetDataManager.refreshWidgetData(from: allItems)
    }
}

// MARK: - Ranked Item Row V3

struct RankedItemRowV3: View {
    @Bindable var item: RankedItem
    let rank: Int
    var allItems: [RankedItem] = []
    let onTap: () -> Void
    let onDelete: () -> Void
    var onReRank: (() -> Void)? = nil
    
    private var score: Double {
        RankedItem.calculateScore(for: item, allItems: allItems)
    }
    
    private var isTopRank: Bool { rank == 1 }
    private var isTop3: Bool { rank <= 3 }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // #1 gets accent left border
                if isTopRank {
                    Rectangle()
                        .fill(MarquiColors.accent)
                        .frame(width: 2)
                }
                
                // Rank number column
                Text(String(format: "%02d", rank))
                    .font(isTopRank ? MarquiTypography.rankLarge : MarquiTypography.rankMedium)
                    .foregroundStyle(MarquiColors.rankColor(for: rank))
                    .frame(width: 52, alignment: .center)
                
                // Poster
                Rectangle()
                    .fill(MarquiColors.divider)
                    .frame(width: 1)
                
                CachedAsyncImage(url: item.posterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(MarquiColors.surfaceSecondary)
                }
                .frame(width: MarquiPoster.miniWidth, height: 72)
                .clipped()
                
                Rectangle()
                    .fill(MarquiColors.divider)
                    .frame(width: 1)
                
                // Info column
                VStack(alignment: .leading, spacing: MarquiSpacing.xxs) {
                    Text(item.title)
                        .font(MarquiTypography.filmTitle)
                        .foregroundStyle(MarquiColors.textPrimary)
                        .lineLimit(2)
                    
                    if let year = item.year {
                        Text("\(year) · \(item.mediaType == .movie ? "Film" : "Series")")
                            .font(MarquiTypography.captionMono)
                            .tracking(1)
                            .foregroundStyle(MarquiColors.textTertiary)
                            .textCase(.uppercase)
                    }
                }
                .padding(.horizontal, MarquiSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Score
                Text(String(format: "%.1f", score))
                    .font(isTopRank ? MarquiTypography.scoreMedium : MarquiTypography.scoreSmall)
                    .foregroundStyle(isTopRank ? MarquiColors.accent : MarquiColors.textSecondary)
                    .padding(.trailing, MarquiSpacing.md)
            }
            .frame(height: 72)
            .background(
                isTopRank
                    ? LinearGradient(
                        colors: [MarquiColors.gradientStart, MarquiColors.gradientEnd],
                        startPoint: .leading,
                        endPoint: .trailing
                      )
                    : LinearGradient(
                        colors: [MarquiColors.background, MarquiColors.background],
                        startPoint: .leading,
                        endPoint: .trailing
                      )
            )
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(MarquiColors.divider)
                    .frame(height: 1)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onReRank = onReRank {
                Button {
                    onReRank()
                } label: {
                    Label("Re-rank", systemImage: "arrow.up.arrow.down")
                }
            }
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}

#Preview {
    RankedListView()
        .modelContainer(for: RankedItem.self, inMemory: true)
}
