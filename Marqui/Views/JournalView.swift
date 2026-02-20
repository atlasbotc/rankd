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
        case .good: return MarquiColors.tierGood
        case .medium: return MarquiColors.tierMedium
        case .bad: return MarquiColors.tierBad
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
                    .padding(.horizontal, MarquiSpacing.md)
                    .padding(.bottom, MarquiSpacing.xs)
                
                searchBar
                    .padding(.horizontal, MarquiSpacing.md)
                    .padding(.bottom, MarquiSpacing.xs)
                
                filterChips
                    .padding(.bottom, MarquiSpacing.sm)
                
                if allItems.isEmpty {
                    emptyStateNoItems
                        .padding(.top, MarquiSpacing.xxl)
                } else if filteredItems.isEmpty {
                    emptyStateNoMatches
                        .padding(.top, MarquiSpacing.xxl)
                } else {
                    journalFeed
                }
            }
        }
        .background(MarquiColors.background)
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
        VStack(alignment: .leading, spacing: MarquiSpacing.xxs) {
            Text("\(allItems.count) \(allItems.count == 1 ? "entry" : "entries")")
                .font(MarquiTypography.headingMedium)
                .foregroundStyle(MarquiColors.textPrimary)
            
            if let firstDate = firstRankedDate {
                Text("First ranked: \(firstDate, format: .dateTime.month(.abbreviated).day().year())")
                    .font(MarquiTypography.bodySmall)
                    .foregroundStyle(MarquiColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MarquiSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: MarquiRadius.lg)
                .fill(MarquiColors.surfacePrimary)
        )
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: MarquiSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(MarquiColors.textTertiary)
            
            TextField("Search titles...", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .foregroundStyle(MarquiColors.textPrimary)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(MarquiColors.textTertiary)
                }
            }
        }
        .padding(MarquiSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: MarquiRadius.md)
                .fill(MarquiColors.surfaceSecondary)
        )
    }
    
    // MARK: - Filter Chips
    
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MarquiSpacing.xs) {
                // Tier filters with colored dots
                ForEach(JournalTierFilter.allCases) { filter in
                    JournalFilterChip(
                        isSelected: selectedTierFilters.contains(filter),
                        action: { toggleTierFilter(filter) }
                    ) {
                        HStack(spacing: MarquiSpacing.xxs) {
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
            .padding(.horizontal, MarquiSpacing.md)
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
                        .padding(.horizontal, MarquiSpacing.md)
                        .padding(.vertical, MarquiSpacing.xxs)
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
                .font(MarquiTypography.headingSmall)
                .foregroundStyle(MarquiColors.textSecondary)
            Spacer()
        }
        .padding(.horizontal, MarquiSpacing.md)
        .padding(.vertical, MarquiSpacing.xs)
        .background(MarquiColors.background)
    }
    
    // MARK: - Empty States
    
    private var emptyStateNoItems: some View {
        VStack(spacing: MarquiSpacing.lg) {
            Image(systemName: "book")
                .font(.system(size: 48))
                .foregroundStyle(MarquiColors.textQuaternary)
            
            VStack(spacing: MarquiSpacing.xs) {
                Text("Your ranking journey starts here")
                    .font(MarquiTypography.headingLarge)
                    .foregroundStyle(MarquiColors.textPrimary)
                
                Text("Every movie and show you rank appears\nin your journal, building a personal timeline\nof everything you've watched and rated.")
                    .font(MarquiTypography.bodyMedium)
                    .foregroundStyle(MarquiColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            NavigationLink(destination: SearchView()) {
                Text("Rank Something")
                    .font(MarquiTypography.labelLarge)
                    .foregroundStyle(MarquiColors.surfacePrimary)
                    .padding(.horizontal, MarquiSpacing.xl)
                    .padding(.vertical, MarquiSpacing.sm)
                    .background(MarquiColors.brand)
                    .clipShape(RoundedRectangle(cornerRadius: MarquiRadius.md))
            }
            .padding(.top, MarquiSpacing.xs)
        }
        .padding(.horizontal, MarquiSpacing.lg)
    }
    
    private var emptyStateNoMatches: some View {
        VStack(spacing: MarquiSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(MarquiColors.textQuaternary)
            
            Text("No Items Match")
                .font(MarquiTypography.headingMedium)
                .foregroundStyle(MarquiColors.textPrimary)
            
            Text("Try adjusting your filters\nor search terms")
                .font(MarquiTypography.bodyMedium)
                .foregroundStyle(MarquiColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            
            if hasActiveFilters {
                Button {
                    clearAllFilters()
                } label: {
                    Text("Clear All Filters")
                        .font(MarquiTypography.labelMedium)
                        .foregroundStyle(MarquiColors.brand)
                }
                .padding(.top, MarquiSpacing.xxs)
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
                .font(MarquiTypography.labelMedium)
                .foregroundStyle(isSelected ? MarquiColors.textPrimary : MarquiColors.textSecondary)
                .padding(.horizontal, MarquiSpacing.sm)
                .padding(.vertical, MarquiSpacing.xs)
                .background(isSelected ? MarquiColors.brand : MarquiColors.surfaceSecondary)
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
        HStack(alignment: .top, spacing: MarquiSpacing.sm) {
            // Poster
            CachedPosterImage(
                url: item.posterURL,
                width: MarquiPoster.miniWidth,
                height: MarquiPoster.miniHeight,
                cornerRadius: MarquiRadius.sm,
                placeholderIcon: item.mediaType == .movie ? "film" : "tv"
            )
            
            // Info
            VStack(alignment: .leading, spacing: MarquiSpacing.xxs) {
                Text(item.title)
                    .font(MarquiTypography.headingSmall)
                    .foregroundStyle(MarquiColors.textPrimary)
                    .lineLimit(2)
                
                // Tier + Rank metadata + Score
                HStack(spacing: MarquiSpacing.xxs) {
                    Circle()
                        .fill(MarquiColors.tierColor(item.tier))
                        .frame(width: 8, height: 8)
                    Text(item.tier.rawValue)
                        .foregroundStyle(MarquiColors.textSecondary)
                    Text("· #\(item.rank) in \(mediaTypeLabel)")
                        .foregroundStyle(MarquiColors.textSecondary)
                    
                    if !allItems.isEmpty {
                        ScoreBadge(score: score, tier: item.tier, compact: true)
                    }
                }
                .font(MarquiTypography.labelMedium)
                
                Text(dateFormatted)
                    .font(MarquiTypography.caption)
                    .foregroundStyle(MarquiColors.textTertiary)
                
                if let snippet = reviewSnippet {
                    Text("\"\(snippet)\"")
                        .font(MarquiTypography.bodySmall)
                        .italic()
                        .foregroundStyle(MarquiColors.textTertiary)
                        .lineLimit(2)
                        .padding(.top, MarquiSpacing.xxs)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(MarquiSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: MarquiRadius.md)
                .fill(MarquiColors.surfacePrimary)
        )
    }
}

#Preview {
    NavigationStack {
        JournalView()
    }
    .modelContainer(for: RankedItem.self, inMemory: true)
}
