import SwiftUI
import SwiftData

// MARK: - Filter Types

enum JournalTierFilter: String, CaseIterable, Identifiable {
    case good = "🟢 Good"
    case medium = "🟡 Medium"
    case bad = "🔴 Bad"
    
    var id: String { rawValue }
    
    var tier: Tier {
        switch self {
        case .good: return .good
        case .medium: return .medium
        case .bad: return .bad
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
            // Search filter
            if !searchText.isEmpty {
                let matches = item.title.localizedCaseInsensitiveContains(searchText)
                if !matches { return false }
            }
            
            // Tier filter
            if !selectedTierFilters.isEmpty {
                let tierMatch = selectedTierFilters.contains(where: { $0.tier == item.tier })
                if !tierMatch { return false }
            }
            
            // Media type filter
            if !selectedMediaFilters.isEmpty {
                let mediaMatch = selectedMediaFilters.contains(where: { $0.mediaType == item.mediaType })
                if !mediaMatch { return false }
            }
            
            // Has review filter
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
        
        // Sort groups by the date of the first item (newest first)
        let sorted = grouped.sorted { lhs, rhs in
            guard let lhsFirst = lhs.value.first, let rhsFirst = rhs.value.first else {
                return false
            }
            return lhsFirst.dateAdded > rhsFirst.dateAdded
        }
        
        return sorted.map { (key: $0.key, items: $0.value) }
    }
    
    private var hasActiveFilters: Bool {
        !searchText.isEmpty || !selectedTierFilters.isEmpty || !selectedMediaFilters.isEmpty || filterHasReview
    }
    
    private var firstRankedDate: Date? {
        allItems.last?.dateAdded // allItems sorted newest first, so last is oldest
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                // Stats Header
                journalStatsHeader
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                
                // Search Bar
                searchBar
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                
                // Filter Chips
                filterChips
                    .padding(.bottom, 12)
                
                // Content
                if allItems.isEmpty {
                    emptyStateNoItems
                        .padding(.top, 40)
                } else if filteredItems.isEmpty {
                    emptyStateNoMatches
                        .padding(.top, 40)
                } else {
                    journalFeed
                }
            }
        }
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
        HStack(spacing: 8) {
            Image(systemName: "book.closed.fill")
                .foregroundStyle(.orange)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Your Journal")
                    .font(.headline)
                
                HStack(spacing: 4) {
                    Text("\(allItems.count) \(allItems.count == 1 ? "entry" : "entries")")
                        .foregroundStyle(.secondary)
                    
                    if let firstDate = firstRankedDate {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text("First ranked: \(firstDate, format: .dateTime.month(.abbreviated).day().year())")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.orange.opacity(0.08))
        )
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search titles...", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Filter Chips
    
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Tier filters
                ForEach(JournalTierFilter.allCases) { filter in
                    FilterChip(
                        label: filter.rawValue,
                        isSelected: selectedTierFilters.contains(filter)
                    ) {
                        toggleTierFilter(filter)
                    }
                }
                
                // Media type filters
                ForEach(JournalMediaFilter.allCases) { filter in
                    FilterChip(
                        label: filter.rawValue,
                        isSelected: selectedMediaFilters.contains(filter)
                    ) {
                        toggleMediaFilter(filter)
                    }
                }
                
                // Has Review filter
                FilterChip(
                    label: "Has Review",
                    isSelected: filterHasReview
                ) {
                    filterHasReview.toggle()
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Journal Feed
    
    private var journalFeed: some View {
        ForEach(groupedByMonth, id: \.key) { group in
            Section {
                ForEach(group.items) { item in
                    JournalEntryCard(item: item)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedItem = item
                            showDetailSheet = true
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
    
    // MARK: - Empty States
    
    private var emptyStateNoItems: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "book.closed")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
            }
            
            Text("Your Journal is Empty")
                .font(.title3.bold())
            
            Text("Start ranking movies and shows\nto build your journal")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }
    
    private var emptyStateNoMatches: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
            }
            
            Text("No Items Match")
                .font(.title3.bold())
            
            Text("Try adjusting your filters\nor search terms")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            
            if hasActiveFilters {
                Button {
                    clearAllFilters()
                } label: {
                    Text("Clear All Filters")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.orange)
                }
                .padding(.top, 4)
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

// MARK: - Journal Entry Card

private struct JournalEntryCard: View {
    let item: RankedItem
    
    private var dateFormatted: String {
        item.dateAdded.formatted(.dateTime.month(.abbreviated).day().year())
    }
    
    private var mediaTypeLabel: String {
        item.mediaType == .movie ? "Movies" : "TV Shows"
    }
    
    private var reviewSnippet: String? {
        guard let review = item.review, !review.isEmpty else { return nil }
        if review.count <= 100 {
            return review
        }
        let index = review.index(review.startIndex, offsetBy: 100)
        return String(review[..<index]) + "…"
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Poster
            AsyncImage(url: item.posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.15))
                    .overlay {
                        Image(systemName: item.mediaType == .movie ? "film" : "tv")
                            .font(.title3)
                            .foregroundStyle(.tertiary)
                    }
            }
            .frame(width: 60, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                // Title + Year
                HStack(spacing: 4) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    
                    if let year = item.year {
                        Text("(\(year))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Tier + Rank + Media Type
                HStack(spacing: 4) {
                    Text(item.tier.emoji)
                    Text(item.tier.rawValue)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text("#\(item.rank) in \(mediaTypeLabel)")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
                
                // Date
                Text(dateFormatted)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                
                // Review snippet
                if let snippet = reviewSnippet {
                    Text("\"\(snippet)\"")
                        .font(.caption)
                        .italic()
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            
            Spacer(minLength: 0)
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.orange : Color(.secondarySystemBackground))
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        JournalView()
    }
    .modelContainer(for: RankedItem.self, inMemory: true)
}
