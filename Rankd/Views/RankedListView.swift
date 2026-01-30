import SwiftUI
import SwiftData
import UIKit

struct RankedListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RankedItem.rank) private var allItems: [RankedItem]
    @State private var selectedMediaType: MediaType = .movie
    @State private var showDeleteConfirmation = false
    @State private var itemToDelete: RankedItem?
    @State private var selectedItem: RankedItem?
    @State private var showDetailSheet = false
    @State private var isReorderMode = false
    
    var filteredItems: [RankedItem] {
        allItems
            .filter { $0.mediaType == selectedMediaType }
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
                                    RankedItemRow(item: item, displayRank: index + 4)
                                        .listRowBackground(
                                            isReorderMode ? RankdColors.surfaceSecondary : RankdColors.background
                                        )
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedItem = item
                                            showDetailSheet = true
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
                                Text("All Rankings")
                                    .font(RankdTypography.headingSmall)
                                    .foregroundStyle(RankdColors.textPrimary)
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
            .sheet(isPresented: $showDetailSheet) {
                if let item = selectedItem {
                    ItemDetailSheet(item: item)
                }
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
                                ? RankdColors.brand
                                : Color.clear
                        )
                        .foregroundStyle(
                            selectedMediaType == type
                                ? RankdColors.surfacePrimary
                                : RankdColors.textTertiary
                        )
                        .clipShape(Capsule())
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
                        onTap: {
                            selectedItem = item
                            showDetailSheet = true
                        },
                        onDelete: {
                            itemToDelete = item
                            showDeleteConfirmation = true
                        }
                    )
                }
            }
            .padding(.horizontal, RankdSpacing.md)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: RankdSpacing.md) {
            Image(systemName: selectedMediaType == .movie ? "film" : "tv")
                .font(.system(size: 40))
                .foregroundStyle(RankdColors.textQuaternary)
            
            Text("No \(selectedMediaType == .movie ? "movies" : "TV shows") ranked yet")
                .font(RankdTypography.headingMedium)
                .foregroundStyle(RankdColors.textPrimary)
            
            Text("Search for something you've watched\nand start building your list")
                .font(RankdTypography.bodyMedium)
                .foregroundStyle(RankdColors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Actions
    
    private func deleteItem(_ item: RankedItem) {
        let deletedRank = item.rank
        let mediaType = item.mediaType
        modelContext.delete(item)
        
        let remainingItems = allItems.filter { $0.mediaType == mediaType && $0.rank > deletedRank }
        for item in remainingItems {
            item.rank -= 1
        }
        
        try? modelContext.save()
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        var reordered = remainingItems
        reordered.move(fromOffsets: source, toOffset: destination)
        
        for (index, item) in reordered.enumerated() {
            item.rank = index + 4
        }
        
        HapticManager.selection()
        try? modelContext.save()
    }
}

// MARK: - Top Ranked Card

private struct TopRankedCard: View {
    let item: RankedItem
    let rank: Int
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: RankdSpacing.xs) {
                ZStack(alignment: .topLeading) {
                    AsyncImage(url: item.posterURL) { image in
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
                    }
                    .aspectRatio(2/3, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: RankdPoster.cornerRadius))
                    
                    // Rank badge
                    rankBadge
                        .offset(x: RankdSpacing.xs, y: RankdSpacing.xs)
                }
                
                // Title + tier dot
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
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
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
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)   // Gold
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.78)  // Silver
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20)  // Bronze
        default: return Color.clear
        }
    }
}

// MARK: - Ranked Item Row

struct RankedItemRow: View {
    let item: RankedItem
    let displayRank: Int
    
    var body: some View {
        HStack(spacing: RankdSpacing.sm) {
            // Rank number
            Text("\(displayRank)")
                .font(RankdTypography.headingSmall)
                .foregroundStyle(RankdColors.textTertiary)
                .frame(width: 32, alignment: .leading)
            
            // Poster
            AsyncImage(url: item.posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(RankdColors.surfaceSecondary)
                    .overlay {
                        Image(systemName: item.mediaType == .movie ? "film" : "tv")
                            .foregroundStyle(RankdColors.textQuaternary)
                    }
            }
            .frame(width: RankdPoster.thumbWidth, height: RankdPoster.thumbHeight)
            .clipShape(RoundedRectangle(cornerRadius: RankdRadius.sm))
            
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
            
            // Tier dot
            Circle()
                .fill(RankdColors.tierColor(item.tier))
                .frame(width: 6, height: 6)
        }
        .padding(.vertical, RankdSpacing.xxs)
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
    @State private var showReRank = false
    @State private var reRankSearchResult: TMDBSearchResult?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RankdSpacing.lg) {
                    // Header
                    HStack(alignment: .top, spacing: RankdSpacing.md) {
                        AsyncImage(url: item.posterURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(RankdColors.surfaceSecondary)
                        }
                        .frame(width: 100, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: RankdPoster.cornerRadius))
                        
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
                        }
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
            .fullScreenCover(isPresented: $showReRank) {
                if let result = reRankSearchResult {
                    ComparisonFlowView(newItem: result)
                }
            }
            .onChange(of: showReRank) { _, isShowing in
                if !isShowing {
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
        let mediaType = item.mediaType
        modelContext.delete(item)
        
        let itemsToShift = allItems.filter { $0.mediaType == mediaType && $0.rank > deletedRank }
        for shiftItem in itemsToShift {
            shiftItem.rank -= 1
        }
        try? modelContext.save()
        
        HapticManager.impact(.medium)
        
        reRankSearchResult = result
        showReRank = true
    }
}

#Preview {
    RankedListView()
        .modelContainer(for: RankedItem.self, inMemory: true)
}
