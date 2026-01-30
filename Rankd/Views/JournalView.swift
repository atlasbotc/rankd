import SwiftUI
import SwiftData

// MARK: - Filter Types

enum JournalTierFilter: String, CaseIterable, Identifiable {
    case good = "Good"
    case medium = "Medium"
    case bad = "Bad"
    
    var id: String { rawValue }
    
    var tier: Tier {
        switch self {
        case .good: return .good
        case .medium: return .medium
        case .bad: return .bad
        }
    }
    
    var dotColor: Color {
        switch self {
        case .good: return RankdColors.tierGood
        case .medium: return RankdColors.tierMedium
        case .bad: return RankdColors.tierBad
        }
    }
}

enum JournalMediaFilter: String, CaseIterable, Identifiable {
    case movies = "Movies"
    case tvShows = "TV Shows"
    
    var id: String { rawValue }
    
    var mediaType: MediaType {
        switch self {
        case .movies: return .movie
        case .tvShows: return .tv
        }
    }
}

// MARK: - JournalView

struct JournalView: View {
    @Query(sort: \RankedItem.dateAdded, order: .reverse) private var allItems: [RankedItem]
    
    @State private var searchText = ""
    @State private var selectedTierFilters: Set<JournalTierFilter> = []
    @State private var selectedMediaFilters: Set<JournalMediaFilter> = []
    @State private var filterHasReview = false
    @State private var selectedItem: RankedItem?
    @State private var showDetailSheet = false
    
    // MARK: - Filtered Items
    
    private var filteredItems: [RankedItem] {
        allItems.filter { item in
            if !searchText.isEmpty {
                let matches = item.title.localizedCaseInsensitiveContains(searchText)
                if !matches { return false }
            }
            if !selectedTierFilters.isEmpty {
                let tierMatch = selectedTierFilters.contains(where: { $0.tier == item.tier })
                if !tierMatch { return false }
            }
            if !selectedMediaFilters.isEmpty {
                let mediaMatch = selectedMediaFilters.contains(where: { $0.mediaType == item.mediaType })
                if !mediaMatch { return false }
            }
            if filterHasReview {
                guard let review = item.review, !review.isEmpty else { return false }
            }
            return true
        }
    }
    
    // MARK: - Grouped by Month
    
    private var groupedByMonth: [(key: String, items: [RankedItem])] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        
        let grouped = Dictionary(grouping: filteredItems) { item -> String in
            let components = calendar.dateComponents([.year, .month], from: item.dateAdded)
            let date = calendar.date(from: components) ?? item.dateAdded
            return formatter.string(from: date)
        }
        
        let sorted = grouped.sorted { lhs, rhs in
            guard let lhsFirst = lhs.value.first, let rhsFirst = rhs.value.first else { return false }
            return lhsFirst.dateAdded > rhsFirst.dateAdded
        }
        
        return sorted.map { (key: $0.key, items: $0.value) }
    }
    
    private var hasActiveFilters: Bool {
        !searchText.isEmpty || !selectedTierFilters.isEmpty || !selectedMediaFilters.isEmpty || filterHasReview
    }
    
    private var firstRankedDate: Date? {
        allItems.last?.dateAdded
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                journalStatsHeader
                    .padding(.horizontal, RankdSpacing.md)
                    .padding(.bottom, RankdSpacing.xs)
                
                searchBar
                    .padding(.horizontal, RankdSpacing.md)
                    .padding(.bottom, RankdSpacing.xs)
                
                filterChips
                    .padding(.bottom, RankdSpacing.sm)
                
                if allItems.isEmpty {
                    emptyStateNoItems
                        .padding(.top, RankdSpacing.xxl)
                } else if filteredItems.isEmpty {
                    emptyStateNoMatches
                        .padding(.top, RankdSpacing.xxl)
                } else {
                    journalFeed
                }
            }
        }
        .background(RankdColors.background)
        .navigationTitle("Watch Journal")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showDetailSheet) {
            if let item = selectedItem {
                ItemDetailSheet(item: item)
            }
        }
    }
    
    // MARK: - Stats Header
    
    private var journalStatsHeader: some View {
        VStack(alignment: .leading, spacing: RankdSpacing.xxs) {
            Text("\(allItems.count) \(allItems.count == 1 ? "entry" : "entries")")
                .font(RankdTypography.headingMedium)
                .foregroundStyle(RankdColors.textPrimary)
            
            if let firstDate = firstRankedDate {
                Text("First ranked: \(firstDate, format: .dateTime.month(.abbreviated).day().year())")
                    .font(RankdTypography.bodySmall)
                    .foregroundStyle(RankdColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RankdSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: RankdRadius.lg)
                .fill(RankdColors.surfacePrimary)
        )
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: RankdSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(RankdColors.textTertiary)
            
            TextField("Search titles...", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .foregroundStyle(RankdColors.textPrimary)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(RankdColors.textTertiary)
                }
            }
        }
        .padding(RankdSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: RankdRadius.md)
                .fill(RankdColors.surfaceSecondary)
        )
    }
    
    // MARK: - Filter Chips
    
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: RankdSpacing.xs) {
                // Tier filters with colored dots
                ForEach(JournalTierFilter.allCases) { filter in
                    JournalFilterChip(
                        isSelected: selectedTierFilters.contains(filter),
                        action: { toggleTierFilter(filter) }
                    ) {
                        HStack(spacing: RankdSpacing.xxs) {
                            Circle()
                                .fill(filter.dotColor)
                                .frame(width: 8, height: 8)
                            Text(filter.rawValue)
                        }
                    }
                }
                
                // Media type filters
                ForEach(JournalMediaFilter.allCases) { filter in
                    JournalFilterChip(
                        isSelected: selectedMediaFilters.contains(filter),
                        action: { toggleMediaFilter(filter) }
                    ) {
                        Text(filter.rawValue)
                    }
                }
                
                // Has Review filter
                JournalFilterChip(
                    isSelected: filterHasReview,
                    action: { filterHasReview.toggle() }
                ) {
                    Text("Has Review")
                }
            }
            .padding(.horizontal, RankdSpacing.md)
        }
    }
    
    // MARK: - Journal Feed
    
    private var journalFeed: some View {
        ForEach(groupedByMonth, id: \.key) { group in
            Section {
                ForEach(group.items) { item in
                    JournalEntryCard(item: item, allItems: allItems)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedItem = item
                            showDetailSheet = true
                        }
                        .padding(.horizontal, RankdSpacing.md)
                        .padding(.vertical, RankdSpacing.xxs)
                }
            } header: {
                monthHeader(group.key)
            }
        }
    }
    
    // MARK: - Month Header
    
    private func monthHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(RankdTypography.headingSmall)
                .foregroundStyle(RankdColors.textSecondary)
            Spacer()
        }
        .padding(.horizontal, RankdSpacing.md)
        .padding(.vertical, RankdSpacing.xs)
        .background(RankdColors.background)
    }
    
    // MARK: - Empty States
    
    private var emptyStateNoItems: some View {
        VStack(spacing: RankdSpacing.lg) {
            Image(systemName: "book")
                .font(.system(size: 48))
                .foregroundStyle(RankdColors.textQuaternary)
            
            VStack(spacing: RankdSpacing.xs) {
                Text("Your ranking journey starts here")
                    .font(RankdTypography.headingLarge)
                    .foregroundStyle(RankdColors.textPrimary)
                
                Text("Every movie and show you rank appears\nin your journal, building a personal timeline\nof everything you've watched and rated.")
                    .font(RankdTypography.bodyMedium)
                    .foregroundStyle(RankdColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            NavigationLink(destination: SearchView()) {
                Text("Rank Something")
                    .font(RankdTypography.labelLarge)
                    .foregroundStyle(RankdColors.surfacePrimary)
                    .padding(.horizontal, RankdSpacing.xl)
                    .padding(.vertical, RankdSpacing.sm)
                    .background(RankdColors.brand)
                    .clipShape(RoundedRectangle(cornerRadius: RankdRadius.md))
            }
            .padding(.top, RankdSpacing.xs)
        }
        .padding(.horizontal, RankdSpacing.lg)
    }
    
    private var emptyStateNoMatches: some View {
        VStack(spacing: RankdSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(RankdColors.textQuaternary)
            
            Text("No Items Match")
                .font(RankdTypography.headingMedium)
                .foregroundStyle(RankdColors.textPrimary)
            
            Text("Try adjusting your filters\nor search terms")
                .font(RankdTypography.bodyMedium)
                .foregroundStyle(RankdColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            
            if hasActiveFilters {
                Button {
                    clearAllFilters()
                } label: {
                    Text("Clear All Filters")
                        .font(RankdTypography.labelMedium)
                        .foregroundStyle(RankdColors.brand)
                }
                .padding(.top, RankdSpacing.xxs)
            }
        }
    }
    
    // MARK: - Actions
    
    private func toggleTierFilter(_ filter: JournalTierFilter) {
        if selectedTierFilters.contains(filter) {
            selectedTierFilters.remove(filter)
        } else {
            selectedTierFilters.insert(filter)
        }
    }
    
    private func toggleMediaFilter(_ filter: JournalMediaFilter) {
        if selectedMediaFilters.contains(filter) {
            selectedMediaFilters.remove(filter)
        } else {
            selectedMediaFilters.insert(filter)
        }
    }
    
    private func clearAllFilters() {
        searchText = ""
        selectedTierFilters = []
        selectedMediaFilters = []
        filterHasReview = false
    }
}

// MARK: - Journal Filter Chip

private struct JournalFilterChip<Label: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let label: Label
    
    var body: some View {
        Button(action: action) {
            label
                .font(RankdTypography.labelMedium)
                .foregroundStyle(isSelected ? RankdColors.textPrimary : RankdColors.textSecondary)
                .padding(.horizontal, RankdSpacing.sm)
                .padding(.vertical, RankdSpacing.xs)
                .background(isSelected ? RankdColors.brand : RankdColors.surfaceSecondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Journal Entry Card

private struct JournalEntryCard: View {
    let item: RankedItem
    var allItems: [RankedItem] = []
    
    private var score: Double {
        RankedItem.calculateScore(for: item, allItems: allItems)
    }
    
    private var dateFormatted: String {
        item.dateAdded.formatted(.dateTime.month(.abbreviated).day().year())
    }
    
    private var mediaTypeLabel: String {
        item.mediaType == .movie ? "Movies" : "TV Shows"
    }
    
    private var reviewSnippet: String? {
        guard let review = item.review, !review.isEmpty else { return nil }
        if review.count <= 100 { return review }
        let index = review.index(review.startIndex, offsetBy: 100)
        return String(review[..<index]) + "…"
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: RankdSpacing.sm) {
            // Poster
            AsyncImage(url: item.posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: RankdRadius.sm)
                    .fill(RankdColors.surfaceSecondary)
                    .overlay {
                        Image(systemName: item.mediaType == .movie ? "film" : "tv")
                            .font(RankdTypography.headingSmall)
                            .foregroundStyle(RankdColors.textQuaternary)
                    }
            }
            .frame(width: RankdPoster.miniWidth, height: RankdPoster.miniHeight)
            .clipShape(RoundedRectangle(cornerRadius: RankdRadius.sm))
            
            // Info
            VStack(alignment: .leading, spacing: RankdSpacing.xxs) {
                Text(item.title)
                    .font(RankdTypography.headingSmall)
                    .foregroundStyle(RankdColors.textPrimary)
                    .lineLimit(2)
                
                // Tier + Rank metadata + Score
                HStack(spacing: RankdSpacing.xxs) {
                    Circle()
                        .fill(RankdColors.tierColor(item.tier))
                        .frame(width: 8, height: 8)
                    Text(item.tier.rawValue)
                        .foregroundStyle(RankdColors.textSecondary)
                    Text("· #\(item.rank) in \(mediaTypeLabel)")
                        .foregroundStyle(RankdColors.textSecondary)
                    
                    if !allItems.isEmpty {
                        ScoreBadge(score: score, tier: item.tier, compact: true)
                    }
                }
                .font(RankdTypography.labelMedium)
                
                Text(dateFormatted)
                    .font(RankdTypography.caption)
                    .foregroundStyle(RankdColors.textTertiary)
                
                if let snippet = reviewSnippet {
                    Text("\"\(snippet)\"")
                        .font(RankdTypography.bodySmall)
                        .italic()
                        .foregroundStyle(RankdColors.textTertiary)
                        .lineLimit(2)
                        .padding(.top, RankdSpacing.xxs)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(RankdSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: RankdRadius.md)
                .fill(RankdColors.surfacePrimary)
        )
    }
}

#Preview {
    NavigationStack {
        JournalView()
    }
    .modelContainer(for: RankedItem.self, inMemory: true)
}
