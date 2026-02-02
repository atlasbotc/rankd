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
                    .padding(.top, RankdSpacing.xs)
                    .padding(.bottom, RankdSpacing.xxs)
                
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
                                            isReorderMode ? RankdColors.surfaceSecondary : RankdColors.background
                                        )
                                        .contentShape(Rectangle())
                                        .animation(RankdMotion.normal, value: item.rank)
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
                                            .tint(RankdColors.error)
                                        }
                                }
                                .onMove(perform: isReorderMode ? moveItems : nil)
                            } header: {
                                Text("ALL RANKINGS")
                                    .font(RankdTypography.sectionLabel)
                                    .tracking(1.5)
                                    .foregroundStyle(RankdColors.textTertiary)
                                    .textCase(nil)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .environment(\.editMode, .constant(isReorderMode ? .active : .inactive))
                }
            }
            .background(RankdColors.background)
            .navigationTitle("Rankings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: RankdSpacing.sm) {
                        // Favorites filter
                        Button {
                            withAnimation(RankdMotion.fast) {
                                showFavoritesOnly.toggle()
                            }
                            HapticManager.selection()
                        } label: {
                            Image(systemName: showFavoritesOnly ? "heart.fill" : "heart")
                                .font(RankdTypography.labelLarge)
                                .foregroundStyle(showFavoritesOnly ? RankdColors.tierBad : RankdColors.textSecondary)
                        }
                        
                        if filteredItems.count >= 2 {
                            Button {
                                startReRankLeastCompared()
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(RankdTypography.labelLarge)
                                    .foregroundStyle(RankdColors.brand)
                            }
                        }
                        
                        if !filteredItems.isEmpty && remainingItems.count > 1 {
                            Button(isReorderMode ? "Done" : "Reorder") {
                                withAnimation(RankdMotion.normal) {
                                    isReorderMode.toggle()
                                }
                            }
                            .font(RankdTypography.labelLarge)
                            .foregroundStyle(RankdColors.textSecondary)
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
                    withAnimation(RankdMotion.fast) {
                        selectedMediaType = type
                    }
                } label: {
                    Text(type == .movie ? "Movies" : "TV Shows")
                        .font(RankdTypography.labelLarge)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RankdSpacing.sm)
                        .background(
                            selectedMediaType == type
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [RankdColors.gradientStart, RankdColors.gradientEnd],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                  ))
                                : AnyShapeStyle(Color.clear)
                        )
                        .foregroundStyle(
                            selectedMediaType == type
                                ? RankdColors.surfacePrimary
                                : RankdColors.textTertiary
                        )
                        .clipShape(Capsule())
                        .shadow(
                            color: selectedMediaType == type ? RankdColors.brand.opacity(0.3) : .clear,
                            radius: selectedMediaType == type ? 4 : 0,
                            y: selectedMediaType == type ? 2 : 0
                        )
                }
            }
        }
        .padding(RankdSpacing.xxs)
        .background(RankdColors.surfaceSecondary)
        .clipShape(Capsule())
        .padding(.horizontal, RankdSpacing.md)
    }
    
    // MARK: - Stats Bar
    
    private var statsBar: some View {
        HStack {
            let label = selectedMediaType == .movie ? "movies" : "shows"
            Text("\(filteredItems.count) \(label) ranked")
                .font(RankdTypography.labelMedium)
                .foregroundStyle(RankdColors.textTertiary)
            Spacer()
        }
        .padding(.horizontal, RankdSpacing.md)
        .padding(.vertical, RankdSpacing.xs)
    }
    
    // MARK: - Top 3 Showcase
    
    private var topShowcase: some View {
        VStack(spacing: RankdSpacing.sm) {
            HStack(alignment: .bottom, spacing: RankdSpacing.sm) {
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
            .padding(.horizontal, RankdSpacing.md)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: RankdSpacing.lg) {
            Image(systemName: "film.stack")
                .font(.system(size: 48))
                .foregroundStyle(RankdColors.textQuaternary)
            
            VStack(spacing: RankdSpacing.xs) {
                Text("Start ranking what you love")
                    .font(RankdTypography.headingLarge)
                    .foregroundStyle(RankdColors.textPrimary)
                
                Text("Search for movies and shows you've watched,\nthen rank them through head-to-head comparisons\nto build your personal top list.")
                    .font(RankdTypography.bodyMedium)
                    .foregroundStyle(RankdColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            NavigationLink(destination: SearchView()) {
                Text("Search & Rank")
                    .font(RankdTypography.labelLarge)
                    .foregroundStyle(.white)
                    .padding(.horizontal, RankdSpacing.xl)
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
            }
            .padding(.top, RankdSpacing.xs)
        }
        .padding(.horizontal, RankdSpacing.lg)
    }
    
    // MARK: - Re-rank Prompt Banner
    
    private var reRankPromptBanner: some View {
        HStack(spacing: RankdSpacing.sm) {
            Image(systemName: "arrow.up.arrow.down")
                .font(RankdTypography.bodyMedium)
                .foregroundStyle(RankdColors.brand)
            
            VStack(alignment: .leading, spacing: RankdSpacing.xxs) {
                Text("Your rankings are growing!")
                    .font(RankdTypography.labelLarge)
                    .foregroundStyle(RankdColors.textPrimary)
                Text("Want to re-rank to fine-tune your scores?")
                    .font(RankdTypography.caption)
                    .foregroundStyle(RankdColors.textSecondary)
            }
            
            Spacer()
            
            Button {
                startReRankLeastCompared()
            } label: {
                Text("Go")
                    .font(RankdTypography.labelLarge)
                    .foregroundStyle(RankdColors.surfacePrimary)
                    .padding(.horizontal, RankdSpacing.sm)
                    .padding(.vertical, RankdSpacing.xs)
                    .background(RankdColors.brand)
                    .clipShape(RoundedRectangle(cornerRadius: RankdRadius.sm))
            }
            
            Button {
                withAnimation(RankdMotion.fast) {
                    showReRankPrompt = false
                    lastReRankMilestone = filteredItems.count
                }
            } label: {
                Image(systemName: "xmark")
                    .font(RankdTypography.caption)
                    .foregroundStyle(RankdColors.textTertiary)
            }
        }
        .padding(RankdSpacing.sm)
        .background(RankdColors.brandSubtle)
        .clipShape(RoundedRectangle(cornerRadius: RankdRadius.md))
        .padding(.horizontal, RankdSpacing.md)
        .padding(.vertical, RankdSpacing.xs)
    }
    
    // MARK: - Re-rank Helpers
    
    private func checkReRankMilestone(count: Int) {
        let milestones = [5, 10, 20]
        for milestone in milestones {
            if count == milestone && lastReRankMilestone < milestone {
                withAnimation(RankdMotion.normal) {
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
        try? modelContext.save()
        
        let itemsToShift = allItems.filter { $0.id != deletedId && $0.mediaType == mediaType && $0.rank > deletedRank }
        for shiftItem in itemsToShift {
            shiftItem.rank -= 1
        }
        try? modelContext.save()
        
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
        try? modelContext.save()
        
        let itemsToShift = allItems.filter { $0.id != deletedId && $0.mediaType == mediaType && $0.rank > deletedRank }
        for shiftItem in itemsToShift {
            shiftItem.rank -= 1
        }
        
        try? modelContext.save()
        updateWidgetData()
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        var reordered = remainingItems
        reordered.move(fromOffsets: source, toOffset: destination)
        
        for (index, item) in reordered.enumerated() {
            item.rank = index + 4
        }
        
        HapticManager.selection()
        try? modelContext.save()
        updateWidgetData()
    }
    
    /// Push updated rankings to widget after modifications.
    private func updateWidgetData() {
        let sorted = allItems.sorted { $0.rank < $1.rank }
        let top10 = Array(sorted.prefix(10))
        
        let widgetItems = top10.map { item in
            let score = RankedItem.calculateScore(for: item, allItems: allItems)
            return WidgetDataManager.WidgetItem(
                id: item.id.uuidString,
                title: item.title,
                score: score,
                tier: item.tier.rawValue,
                posterURL: item.posterURL?.absoluteString,
                rank: item.rank
            )
        }
        
        WidgetDataManager.updateSharedData(items: widgetItems)
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
            VStack(spacing: RankdSpacing.xs) {
                ZStack(alignment: .topLeading) {
                    CachedAsyncImage(url: item.posterURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: RankdPoster.cornerRadius)
                            .fill(RankdColors.surfaceSecondary)
                            .overlay {
                                Image(systemName: item.mediaType == .movie ? "film" : "tv")
                                    .font(RankdTypography.headingLarge)
                                    .foregroundStyle(RankdColors.textQuaternary)
                            }
                            .shimmer()
                    }
                    .aspectRatio(2/3, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: RankdPoster.cornerRadius))
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .clear, .black.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: RankdPoster.cornerRadius))
                    )
                    
                    // Rank badge
                    rankBadge
                        .offset(x: RankdSpacing.xs, y: RankdSpacing.xs)
                }
                
                // Title + tier dot + score
                VStack(spacing: RankdSpacing.xxs) {
                    HStack(spacing: RankdSpacing.xxs) {
                        Circle()
                            .fill(RankdColors.tierColor(item.tier))
                            .frame(width: 6, height: 6)
                        
                        Text(item.title)
                            .font(RankdTypography.labelMedium)
                            .foregroundStyle(RankdColors.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    
                    if !allItems.isEmpty {
                        ScoreBadge(score: score, tier: item.tier, compact: true)
                    }
                }
            }
        }
        .buttonStyle(RankdPressStyle())
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
                .fill(RankdColors.surfaceTertiary)
                .frame(width: 26, height: 26)
                .overlay(
                    Circle()
                        .stroke(medalRingColor, lineWidth: 2)
                )
            
            Text("\(rank)")
                .font(RankdTypography.labelMedium)
                .foregroundStyle(RankdColors.textPrimary)
        }
    }
    
    private var medalRingColor: Color {
        RankdColors.medalColor(for: rank)
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
                .fill(RankdColors.tierColor(item.tier))
                .frame(width: 3, height: 48)
                .padding(.trailing, RankdSpacing.xs)
            
            HStack(spacing: RankdSpacing.sm) {
            // Rank number — gradient text
            Text("\(displayRank)")
                .font(RankdTypography.headingSmall)
                .foregroundStyle(
                    LinearGradient(
                        colors: [RankdColors.gradientStart, RankdColors.gradientEnd],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 32, alignment: .leading)
            
            // Poster
            CachedPosterImage(
                url: item.posterURL,
                width: RankdPoster.thumbWidth,
                height: RankdPoster.thumbHeight,
                cornerRadius: RankdRadius.sm,
                placeholderIcon: item.mediaType == .movie ? "film" : "tv"
            )
            
            // Info
            VStack(alignment: .leading, spacing: RankdSpacing.xxs) {
                Text(item.title)
                    .font(RankdTypography.headingSmall)
                    .foregroundStyle(RankdColors.textPrimary)
                    .lineLimit(2)
                
                if let year = item.year {
                    Text(year)
                        .font(RankdTypography.caption)
                        .foregroundStyle(RankdColors.textTertiary)
                }
            }
            
            Spacer()
            
            // Favorite heart
            Button {
                withAnimation(RankdMotion.fast) {
                    item.isFavorite.toggle()
                }
                HapticManager.impact(.light)
            } label: {
                Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                    .font(RankdTypography.bodyMedium)
                    .foregroundStyle(item.isFavorite ? RankdColors.tierBad : RankdColors.textQuaternary)
            }
            .buttonStyle(.plain)
            
            // Score badge
            if !allItems.isEmpty {
                ScoreBadge(score: score, tier: item.tier)
            }
        }
        }
        .padding(.vertical, RankdSpacing.xxs)
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
                VStack(alignment: .leading, spacing: RankdSpacing.lg) {
                    // Header
                    HStack(alignment: .top, spacing: RankdSpacing.md) {
                        CachedPosterImage(
                            url: item.posterURL,
                            width: 100,
                            height: 150
                        )
                        
                        VStack(alignment: .leading, spacing: RankdSpacing.xs) {
                            Text(item.title)
                                .font(RankdTypography.headingLarge)
                                .foregroundStyle(RankdColors.textPrimary)
                            
                            if let year = item.year {
                                Text(year)
                                    .font(RankdTypography.bodySmall)
                                    .foregroundStyle(RankdColors.textSecondary)
                            }
                            
                            HStack(spacing: RankdSpacing.xs) {
                                Circle()
                                    .fill(RankdColors.tierColor(item.tier))
                                    .frame(width: 8, height: 8)
                                Text(item.tier.rawValue)
                                    .font(RankdTypography.labelMedium)
                                    .foregroundStyle(RankdColors.textSecondary)
                            }
                            
                            Text("Ranked #\(item.rank)")
                                .font(RankdTypography.headingMedium)
                                .foregroundStyle(RankdColors.brand)
                            
                            ScoreDisplay(
                                score: RankedItem.calculateScore(for: item, allItems: allItems),
                                tier: item.tier
                            )
                        }
                    }
                    .padding(.horizontal, RankdSpacing.md)
                    
                    // Favorite toggle
                    Button {
                        withAnimation(RankdMotion.fast) {
                            item.isFavorite.toggle()
                        }
                        try? modelContext.save()
                        HapticManager.impact(.light)
                    } label: {
                        HStack(spacing: RankdSpacing.xs) {
                            Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                                .font(RankdTypography.headingSmall)
                                .foregroundStyle(item.isFavorite ? RankdColors.tierBad : RankdColors.textTertiary)
                            Text(item.isFavorite ? "Favorited" : "Add to Favorites")
                                .font(RankdTypography.headingSmall)
                                .foregroundStyle(item.isFavorite ? RankdColors.textPrimary : RankdColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RankdSpacing.sm)
                        .background(
                            item.isFavorite
                                ? RankdColors.tierBad.opacity(0.12)
                                : RankdColors.surfaceSecondary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: RankdRadius.md))
                    }
                    .padding(.horizontal, RankdSpacing.md)
                    
                    Rectangle()
                        .fill(RankdColors.divider)
                        .frame(height: 1)
                    
                    // Change Tier
                    VStack(alignment: .leading, spacing: RankdSpacing.sm) {
                        Text("Tier")
                            .font(RankdTypography.headingSmall)
                            .foregroundStyle(RankdColors.textPrimary)
                        
                        HStack(spacing: RankdSpacing.sm) {
                            ForEach(Tier.allCases, id: \.self) { t in
                                Button {
                                    guard t != item.tier else { return }
                                    withAnimation(RankdMotion.fast) {
                                        item.tier = t
                                    }
                                    try? modelContext.save()
                                    HapticManager.impact(.medium)
                                } label: {
                                    HStack(spacing: RankdSpacing.xs) {
                                        Circle()
                                            .fill(RankdColors.tierColor(t))
                                            .frame(width: 8, height: 8)
                                        Text(t.rawValue)
                                            .font(RankdTypography.labelLarge)
                                            .foregroundStyle(
                                                item.tier == t
                                                    ? RankdColors.textPrimary
                                                    : RankdColors.textSecondary
                                            )
                                    }
                                    .padding(.horizontal, RankdSpacing.sm)
                                    .padding(.vertical, RankdSpacing.xs)
                                    .frame(minHeight: 44)
                                    .background(
                                        item.tier == t
                                            ? RankdColors.tierColor(t).opacity(0.15)
                                            : RankdColors.surfaceSecondary
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: RankdRadius.sm))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, RankdSpacing.md)
                    
                    Rectangle()
                        .fill(RankdColors.divider)
                        .frame(height: 1)
                    
                    // Re-rank Button
                    Button {
                        startReRank()
                    } label: {
                        HStack(spacing: RankdSpacing.xs) {
                            Image(systemName: "arrow.up.arrow.down")
                            Text("Re-rank")
                                .font(RankdTypography.headingSmall)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RankdSpacing.sm)
                        .background(RankdColors.surfaceSecondary)
                        .foregroundStyle(RankdColors.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: RankdRadius.md))
                    }
                    .padding(.horizontal, RankdSpacing.md)
                    
                    Rectangle()
                        .fill(RankdColors.divider)
                        .frame(height: 1)
                    
                    // Review
                    VStack(alignment: .leading, spacing: RankdSpacing.sm) {
                        HStack {
                            Text("Your Review")
                                .font(RankdTypography.headingSmall)
                                .foregroundStyle(RankdColors.textPrimary)
                            Spacer()
                            Button(isEditing ? "Done" : "Edit") {
                                if isEditing {
                                    item.review = editedReview.isEmpty ? nil : editedReview
                                    try? modelContext.save()
                                }
                                isEditing.toggle()
                            }
                            .font(RankdTypography.labelLarge)
                            .foregroundStyle(RankdColors.brand)
                        }
                        
                        if isEditing {
                            TextEditor(text: $editedReview)
                                .font(RankdTypography.bodyMedium)
                                .frame(minHeight: 100)
                                .padding(RankdSpacing.xs)
                                .scrollContentBackground(.hidden)
                                .background(RankdColors.surfaceSecondary)
                                .foregroundStyle(RankdColors.textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: RankdRadius.md))
                        } else if let review = item.review, !review.isEmpty {
                            Text(review)
                                .font(RankdTypography.bodyMedium)
                                .foregroundStyle(RankdColors.textSecondary)
                        } else {
                            Text("No review yet — tap Edit to add one")
                                .font(RankdTypography.bodyMedium)
                                .foregroundStyle(RankdColors.textTertiary)
                        }
                    }
                    .padding(.horizontal, RankdSpacing.md)
                    
                    if !item.overview.isEmpty {
                        Rectangle()
                            .fill(RankdColors.divider)
                            .frame(height: 1)
                        
                        VStack(alignment: .leading, spacing: RankdSpacing.xs) {
                            Text("Synopsis")
                                .font(RankdTypography.headingSmall)
                                .foregroundStyle(RankdColors.textPrimary)
                            Text(item.overview)
                                .font(RankdTypography.bodyMedium)
                                .foregroundStyle(RankdColors.textSecondary)
                        }
                        .padding(.horizontal, RankdSpacing.md)
                    }
                }
                .padding(.vertical, RankdSpacing.md)
            }
            .background(RankdColors.background)
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(RankdTypography.labelLarge)
                        .foregroundStyle(RankdColors.textSecondary)
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
        try? modelContext.save()
        
        let itemsToShift = allItems.filter { $0.id != deletedId && $0.mediaType == mediaType && $0.rank > deletedRank }
        for shiftItem in itemsToShift {
            shiftItem.rank -= 1
        }
        try? modelContext.save()
        
        HapticManager.impact(.medium)
        
        reRankSearchResult = result
    }
}

#Preview {
    RankedListView()
        .modelContainer(for: RankedItem.self, inMemory: true)
}
