import SwiftUI
import SwiftData

struct RankedListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RankedItem.rank) private var allItems: [RankedItem]
    @State private var selectedMediaType: MediaType = .movie
    @State private var showDeleteConfirmation = false
    @State private var itemToDelete: RankedItem?
    @State private var selectedItem: RankedItem?
    // selectedItem drives the detail sheet via .sheet(item:)
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
    
    private var topThree: [RankedItem] {
        Array(filteredItems.prefix(3))
    }
    
    private var remainingItems: [RankedItem] {
        Array(filteredItems.dropFirst(3))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                pillPicker
                    .padding(.top, MarquiSpacing.xs)
                    .padding(.bottom, MarquiSpacing.xxs)
                
                if filteredItems.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    List {
                        // Stats bar
                        Section {
                            statsBar
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                        
                        // Re-rank milestone prompt
                        if showReRankPrompt {
                            Section {
                                reRankPromptBanner
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                        }
                        
                        // Top 3 showcase
                        if topThree.count >= 1 {
                            Section {
                                topShowcase
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                        }
                        
                        // Remaining rankings (#4+)
                        if remainingItems.count > 0 {
                            Section {
                                ForEach(Array(remainingItems.enumerated()), id: \.element.id) { index, item in
                                    RankedItemRow(item: item, displayRank: index + 4, allItems: filteredItems)
                                        .listRowBackground(
                                            isReorderMode ? MarquiColors.surfaceSecondary : MarquiColors.background
                                        )
                                        .contentShape(Rectangle())
                                        .animation(MarquiMotion.normal, value: item.rank)
                                        .onTapGesture {
                                            selectedItem = item
                                        }
                                        .contextMenu {
                                            Button {
                                                startReRank(for: item)
                                            } label: {
                                                Label("Re-rank this item", systemImage: "arrow.up.arrow.down")
                                            }
                                            
                                            Button(role: .destructive) {
                                                itemToDelete = item
                                                showDeleteConfirmation = true
                                                HapticManager.notification(.warning)
                                            } label: {
                                                Label("Remove", systemImage: "trash")
                                            }
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                itemToDelete = item
                                                showDeleteConfirmation = true
                                                HapticManager.notification(.warning)
                                            } label: {
                                                Label("Remove", systemImage: "trash")
                                            }
                                            .tint(MarquiColors.error)
                                        }
                                }
                                .onMove(perform: isReorderMode ? moveItems : nil)
                            } header: {
                                Text("ALL RANKINGS")
                                    .font(MarquiTypography.sectionLabel)
                                    .tracking(1.5)
                                    .foregroundStyle(MarquiColors.textTertiary)
                                    .textCase(nil)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .environment(\.editMode, .constant(isReorderMode ? .active : .inactive))
                }
            }
            .background(MarquiColors.background)
            .navigationTitle("Rankings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: MarquiSpacing.sm) {
                        // Favorites filter
                        Button {
                            withAnimation(MarquiMotion.fast) {
                                showFavoritesOnly.toggle()
                            }
                            HapticManager.selection()
                        } label: {
                            Image(systemName: showFavoritesOnly ? "heart.fill" : "heart")
                                .font(MarquiTypography.labelLarge)
                                .foregroundStyle(showFavoritesOnly ? MarquiColors.tierBad : MarquiColors.textSecondary)
                        }
                        
                        if filteredItems.count >= 2 {
                            Button {
                                startReRankLeastCompared()
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(MarquiTypography.labelLarge)
                                    .foregroundStyle(MarquiColors.brand)
                            }
                        }
                        
                        if !filteredItems.isEmpty && remainingItems.count > 1 {
                            Button(isReorderMode ? "Done" : "Reorder") {
                                withAnimation(MarquiMotion.normal) {
                                    isReorderMode.toggle()
                                }
                            }
                            .font(MarquiTypography.labelLarge)
                            .foregroundStyle(MarquiColors.textSecondary)
                        }
                    }
                }
            }
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
                ItemDetailSheet(item: item)
            }
            .fullScreenCover(item: $reRankSearchResult) { result in
                ComparisonFlowView(newItem: result)
            }
            .onChange(of: filteredItems.count) { _, newCount in
                checkReRankMilestone(count: newCount)
            }
        }
    }
    
    // MARK: - Pill Picker
    
    private var pillPicker: some View {
        HStack(spacing: 0) {
            ForEach([MediaType.movie, MediaType.tv], id: \.self) { type in
                Button {
                    withAnimation(MarquiMotion.fast) {
                        selectedMediaType = type
                    }
                } label: {
                    Text(type == .movie ? "Movies" : "TV Shows")
                        .font(MarquiTypography.labelLarge)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, MarquiSpacing.sm)
                        .background(
                            selectedMediaType == type
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [MarquiColors.gradientStart, MarquiColors.gradientEnd],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                  ))
                                : AnyShapeStyle(Color.clear)
                        )
                        .foregroundStyle(
                            selectedMediaType == type
                                ? MarquiColors.surfacePrimary
                                : MarquiColors.textTertiary
                        )
                        .clipShape(Capsule())
                        .shadow(
                            color: selectedMediaType == type ? MarquiColors.brand.opacity(0.3) : .clear,
                            radius: selectedMediaType == type ? 4 : 0,
                            y: selectedMediaType == type ? 2 : 0
                        )
                }
            }
        }
        .padding(MarquiSpacing.xxs)
        .background(MarquiColors.surfaceSecondary)
        .clipShape(Capsule())
        .padding(.horizontal, MarquiSpacing.md)
    }
    
    // MARK: - Stats Bar
    
    private var statsBar: some View {
        HStack {
            let label = selectedMediaType == .movie ? "movies" : "shows"
            Text("\(filteredItems.count) \(label) ranked")
                .font(MarquiTypography.labelMedium)
                .foregroundStyle(MarquiColors.textTertiary)
            Spacer()
        }
        .padding(.horizontal, MarquiSpacing.md)
        .padding(.vertical, MarquiSpacing.xs)
    }
    
    // MARK: - Top 3 Showcase
    
    private var topShowcase: some View {
        VStack(spacing: MarquiSpacing.sm) {
            HStack(alignment: .bottom, spacing: MarquiSpacing.sm) {
                ForEach(Array(topThree.enumerated()), id: \.element.id) { index, item in
                    TopRankedCard(
                        item: item,
                        rank: index + 1,
                        allItems: filteredItems,
                        onTap: {
                            selectedItem = item
                        },
                        onDelete: {
                            itemToDelete = item
                            showDeleteConfirmation = true
                        },
                        onReRank: {
                            startReRank(for: item)
                        }
                    )
                }
            }
            .padding(.horizontal, MarquiSpacing.md)
        }
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
                
                Text("Search for movies and shows you've watched,\nthen rank them through head-to-head comparisons\nto build your personal top list.")
                    .font(MarquiTypography.bodyMedium)
                    .foregroundStyle(MarquiColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            NavigationLink(destination: SearchView()) {
                Text("Search & Rank")
                    .font(MarquiTypography.labelLarge)
                    .foregroundStyle(.white)
                    .padding(.horizontal, MarquiSpacing.xl)
                    .padding(.vertical, MarquiSpacing.sm)
                    .background(
                        LinearGradient(
                            colors: [MarquiColors.gradientStart, MarquiColors.gradientEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: MarquiColors.brand.opacity(0.4), radius: 8, y: 4)
            }
            .padding(.top, MarquiSpacing.xs)
        }
        .padding(.horizontal, MarquiSpacing.lg)
    }
    
    // MARK: - Re-rank Prompt Banner
    
    private var reRankPromptBanner: some View {
        HStack(spacing: MarquiSpacing.sm) {
            Image(systemName: "arrow.up.arrow.down")
                .font(MarquiTypography.bodyMedium)
                .foregroundStyle(MarquiColors.brand)
            
            VStack(alignment: .leading, spacing: MarquiSpacing.xxs) {
                Text("Your rankings are growing!")
                    .font(MarquiTypography.labelLarge)
                    .foregroundStyle(MarquiColors.textPrimary)
                Text("Want to re-rank to fine-tune your scores?")
                    .font(MarquiTypography.caption)
                    .foregroundStyle(MarquiColors.textSecondary)
            }
            
            Spacer()
            
            Button {
                startReRankLeastCompared()
            } label: {
                Text("Go")
                    .font(MarquiTypography.labelLarge)
                    .foregroundStyle(MarquiColors.surfacePrimary)
                    .padding(.horizontal, MarquiSpacing.sm)
                    .padding(.vertical, MarquiSpacing.xs)
                    .background(MarquiColors.brand)
                    .clipShape(RoundedRectangle(cornerRadius: MarquiRadius.sm))
            }
            
            Button {
                withAnimation(MarquiMotion.fast) {
                    showReRankPrompt = false
                    lastReRankMilestone = filteredItems.count
                }
            } label: {
                Image(systemName: "xmark")
                    .font(MarquiTypography.caption)
                    .foregroundStyle(MarquiColors.textTertiary)
            }
        }
        .padding(MarquiSpacing.sm)
        .background(MarquiColors.brandSubtle)
        .clipShape(RoundedRectangle(cornerRadius: MarquiRadius.md))
        .padding(.horizontal, MarquiSpacing.md)
        .padding(.vertical, MarquiSpacing.xs)
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
    
    private func startReRankLeastCompared() {
        guard let item = filteredItems.min(by: { $0.comparisonCount < $1.comparisonCount }) else { return }
        startReRank(for: item)
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
        var reordered = remainingItems
        reordered.move(fromOffsets: source, toOffset: destination)
        
        for (index, item) in reordered.enumerated() {
            item.rank = index + 4
        }
        
        HapticManager.selection()
        modelContext.safeSave()
        updateWidgetData()
    }
    
    /// Push updated rankings to widget after modifications.
    private func updateWidgetData() {
        WidgetDataManager.refreshWidgetData(from: allItems)
    }
}

// MARK: - Top Ranked Card

private struct TopRankedCard: View {
    let item: RankedItem
    let rank: Int
    var allItems: [RankedItem] = []
    let onTap: () -> Void
    let onDelete: () -> Void
    var onReRank: (() -> Void)? = nil
    
    private var score: Double {
        RankedItem.calculateScore(for: item, allItems: allItems)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: MarquiSpacing.xs) {
                ZStack(alignment: .topLeading) {
                    CachedAsyncImage(url: item.posterURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: MarquiPoster.cornerRadius)
                            .fill(MarquiColors.surfaceSecondary)
                            .overlay {
                                Image(systemName: item.mediaType == .movie ? "film" : "tv")
                                    .font(MarquiTypography.headingLarge)
                                    .foregroundStyle(MarquiColors.textQuaternary)
                            }
                            .shimmer()
                    }
                    .aspectRatio(2/3, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: MarquiPoster.cornerRadius))
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .clear, .black.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: MarquiPoster.cornerRadius))
                    )
                    
                    // Rank badge
                    rankBadge
                        .offset(x: MarquiSpacing.xs, y: MarquiSpacing.xs)
                }
                
                // Title + tier dot + score
                VStack(spacing: MarquiSpacing.xxs) {
                    HStack(spacing: MarquiSpacing.xxs) {
                        Circle()
                            .fill(MarquiColors.tierColor(item.tier))
                            .frame(width: 6, height: 6)
                        
                        Text(item.title)
                            .font(MarquiTypography.labelMedium)
                            .foregroundStyle(MarquiColors.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    
                    if !allItems.isEmpty {
                        ScoreBadge(score: score, tier: item.tier, compact: true)
                    }
                }
            }
        }
        .buttonStyle(MarquiPressStyle())
        .contextMenu {
            if let onReRank = onReRank {
                Button {
                    onReRank()
                } label: {
                    Label("Re-rank this item", systemImage: "arrow.up.arrow.down")
                }
            }
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }
    
    private var rankBadge: some View {
        ZStack {
            Circle()
                .fill(MarquiColors.surfaceTertiary)
                .frame(width: 26, height: 26)
                .overlay(
                    Circle()
                        .stroke(medalRingColor, lineWidth: 2)
                )
            
            Text("\(rank)")
                .font(MarquiTypography.labelMedium)
                .foregroundStyle(MarquiColors.textPrimary)
        }
    }
    
    private var medalRingColor: Color {
        MarquiColors.medalColor(for: rank)
    }
}

// MARK: - Ranked Item Row

struct RankedItemRow: View {
    @Bindable var item: RankedItem
    let displayRank: Int
    var allItems: [RankedItem] = []
    
    private var score: Double {
        RankedItem.calculateScore(for: item, allItems: allItems)
    }
    
    private var accessibilityDescription: String {
        var parts = ["Rank \(displayRank)", item.title]
        if !allItems.isEmpty {
            parts.append("Score \(String(format: "%.1f", score))")
        }
        parts.append("\(item.tier.rawValue) tier")
        if item.isFavorite { parts.append("Favorite") }
        return parts.joined(separator: ", ")
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Tier-colored left accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(MarquiColors.tierColor(item.tier))
                .frame(width: 3, height: 48)
                .padding(.trailing, MarquiSpacing.xs)
            
            HStack(spacing: MarquiSpacing.sm) {
            // Rank number — gradient text
            Text("\(displayRank)")
                .font(MarquiTypography.headingSmall)
                .foregroundStyle(
                    LinearGradient(
                        colors: [MarquiColors.gradientStart, MarquiColors.gradientEnd],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 32, alignment: .leading)
            
            // Poster
            CachedPosterImage(
                url: item.posterURL,
                width: MarquiPoster.thumbWidth,
                height: MarquiPoster.thumbHeight,
                cornerRadius: MarquiRadius.sm,
                placeholderIcon: item.mediaType == .movie ? "film" : "tv"
            )
            
            // Info
            VStack(alignment: .leading, spacing: MarquiSpacing.xxs) {
                Text(item.title)
                    .font(MarquiTypography.headingSmall)
                    .foregroundStyle(MarquiColors.textPrimary)
                    .lineLimit(2)
                
                if let year = item.year {
                    Text(year)
                        .font(MarquiTypography.caption)
                        .foregroundStyle(MarquiColors.textTertiary)
                }
            }
            
            Spacer()
            
            // Favorite heart
            Button {
                withAnimation(MarquiMotion.fast) {
                    item.isFavorite.toggle()
                }
                HapticManager.impact(.light)
            } label: {
                Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                    .font(MarquiTypography.bodyMedium)
                    .foregroundStyle(item.isFavorite ? MarquiColors.tierBad : MarquiColors.textQuaternary)
            }
            .buttonStyle(.plain)
            
            // Score badge
            if !allItems.isEmpty {
                ScoreBadge(score: score, tier: item.tier)
            }
        }
        }
        .padding(.vertical, MarquiSpacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }
}

// MARK: - Item Detail Sheet

struct ItemDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \RankedItem.rank) private var allItems: [RankedItem]
    @Bindable var item: RankedItem
    @State private var editedReview: String = ""
    @State private var isEditing = false
    @State private var reRankSearchResult: TMDBSearchResult?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MarquiSpacing.lg) {
                    // Header
                    HStack(alignment: .top, spacing: MarquiSpacing.md) {
                        CachedPosterImage(
                            url: item.posterURL,
                            width: 100,
                            height: 150
                        )
                        
                        VStack(alignment: .leading, spacing: MarquiSpacing.xs) {
                            Text(item.title)
                                .font(MarquiTypography.headingLarge)
                                .foregroundStyle(MarquiColors.textPrimary)
                            
                            if let year = item.year {
                                Text(year)
                                    .font(MarquiTypography.bodySmall)
                                    .foregroundStyle(MarquiColors.textSecondary)
                            }
                            
                            HStack(spacing: MarquiSpacing.xs) {
                                Circle()
                                    .fill(MarquiColors.tierColor(item.tier))
                                    .frame(width: 8, height: 8)
                                Text(item.tier.rawValue)
                                    .font(MarquiTypography.labelMedium)
                                    .foregroundStyle(MarquiColors.textSecondary)
                            }
                            
                            Text("Ranked #\(item.rank)")
                                .font(MarquiTypography.headingMedium)
                                .foregroundStyle(MarquiColors.brand)
                            
                            ScoreDisplay(
                                score: RankedItem.calculateScore(for: item, allItems: allItems),
                                tier: item.tier
                            )
                        }
                    }
                    .padding(.horizontal, MarquiSpacing.md)
                    
                    // Favorite toggle
                    Button {
                        withAnimation(MarquiMotion.fast) {
                            item.isFavorite.toggle()
                        }
                        modelContext.safeSave()
                        HapticManager.impact(.light)
                    } label: {
                        HStack(spacing: MarquiSpacing.xs) {
                            Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                                .font(MarquiTypography.headingSmall)
                                .foregroundStyle(item.isFavorite ? MarquiColors.tierBad : MarquiColors.textTertiary)
                            Text(item.isFavorite ? "Favorited" : "Add to Favorites")
                                .font(MarquiTypography.headingSmall)
                                .foregroundStyle(item.isFavorite ? MarquiColors.textPrimary : MarquiColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, MarquiSpacing.sm)
                        .background(
                            item.isFavorite
                                ? MarquiColors.tierBad.opacity(0.12)
                                : MarquiColors.surfaceSecondary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: MarquiRadius.md))
                    }
                    .padding(.horizontal, MarquiSpacing.md)
                    
                    Rectangle()
                        .fill(MarquiColors.divider)
                        .frame(height: 1)
                    
                    // Change Tier
                    VStack(alignment: .leading, spacing: MarquiSpacing.sm) {
                        Text("Tier")
                            .font(MarquiTypography.headingSmall)
                            .foregroundStyle(MarquiColors.textPrimary)
                        
                        HStack(spacing: MarquiSpacing.sm) {
                            ForEach(Tier.allCases, id: \.self) { t in
                                Button {
                                    guard t != item.tier else { return }
                                    withAnimation(MarquiMotion.fast) {
                                        item.tier = t
                                    }
                                    modelContext.safeSave()
                                    HapticManager.impact(.medium)
                                } label: {
                                    HStack(spacing: MarquiSpacing.xs) {
                                        Circle()
                                            .fill(MarquiColors.tierColor(t))
                                            .frame(width: 8, height: 8)
                                        Text(t.rawValue)
                                            .font(MarquiTypography.labelLarge)
                                            .foregroundStyle(
                                                item.tier == t
                                                    ? MarquiColors.textPrimary
                                                    : MarquiColors.textSecondary
                                            )
                                    }
                                    .padding(.horizontal, MarquiSpacing.sm)
                                    .padding(.vertical, MarquiSpacing.xs)
                                    .frame(minHeight: 44)
                                    .background(
                                        item.tier == t
                                            ? MarquiColors.tierColor(t).opacity(0.15)
                                            : MarquiColors.surfaceSecondary
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: MarquiRadius.sm))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, MarquiSpacing.md)
                    
                    Rectangle()
                        .fill(MarquiColors.divider)
                        .frame(height: 1)
                    
                    // Re-rank Button
                    Button {
                        startReRank()
                    } label: {
                        HStack(spacing: MarquiSpacing.xs) {
                            Image(systemName: "arrow.up.arrow.down")
                            Text("Re-rank")
                                .font(MarquiTypography.headingSmall)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, MarquiSpacing.sm)
                        .background(MarquiColors.surfaceSecondary)
                        .foregroundStyle(MarquiColors.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: MarquiRadius.md))
                    }
                    .padding(.horizontal, MarquiSpacing.md)
                    
                    Rectangle()
                        .fill(MarquiColors.divider)
                        .frame(height: 1)
                    
                    // Review
                    VStack(alignment: .leading, spacing: MarquiSpacing.sm) {
                        HStack {
                            Text("Your Review")
                                .font(MarquiTypography.headingSmall)
                                .foregroundStyle(MarquiColors.textPrimary)
                            Spacer()
                            Button(isEditing ? "Done" : "Edit") {
                                if isEditing {
                                    item.review = editedReview.isEmpty ? nil : editedReview
                                    modelContext.safeSave()
                                }
                                isEditing.toggle()
                            }
                            .font(MarquiTypography.labelLarge)
                            .foregroundStyle(MarquiColors.brand)
                        }
                        
                        if isEditing {
                            TextEditor(text: $editedReview)
                                .font(MarquiTypography.bodyMedium)
                                .frame(minHeight: 100)
                                .padding(MarquiSpacing.xs)
                                .scrollContentBackground(.hidden)
                                .background(MarquiColors.surfaceSecondary)
                                .foregroundStyle(MarquiColors.textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: MarquiRadius.md))
                        } else if let review = item.review, !review.isEmpty {
                            Text(review)
                                .font(MarquiTypography.bodyMedium)
                                .foregroundStyle(MarquiColors.textSecondary)
                        } else {
                            Text("No review yet — tap Edit to add one")
                                .font(MarquiTypography.bodyMedium)
                                .foregroundStyle(MarquiColors.textTertiary)
                        }
                    }
                    .padding(.horizontal, MarquiSpacing.md)
                    
                    if !item.overview.isEmpty {
                        Rectangle()
                            .fill(MarquiColors.divider)
                            .frame(height: 1)
                        
                        VStack(alignment: .leading, spacing: MarquiSpacing.xs) {
                            Text("Synopsis")
                                .font(MarquiTypography.headingSmall)
                                .foregroundStyle(MarquiColors.textPrimary)
                            Text(item.overview)
                                .font(MarquiTypography.bodyMedium)
                                .foregroundStyle(MarquiColors.textSecondary)
                        }
                        .padding(.horizontal, MarquiSpacing.md)
                    }
                }
                .padding(.vertical, MarquiSpacing.md)
            }
            .background(MarquiColors.background)
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(MarquiTypography.labelLarge)
                        .foregroundStyle(MarquiColors.textSecondary)
                }
            }
            .onAppear {
                editedReview = item.review ?? ""
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
}

#Preview {
    RankedListView()
        .modelContainer(for: RankedItem.self, inMemory: true)
}
