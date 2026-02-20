import SwiftUI
import SwiftData

struct AddToListView: View {
    @Bindable var list: CustomList
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RankedItem.rank) private var rankedItems: [RankedItem]
    
    @State private var searchQuery = ""
    @State private var searchResults: [TMDBSearchResult] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var addedIds: Set<Int> = []
    
    private var rankedNotInList: [RankedItem] {
        rankedItems.filter { ranked in
            !list.contains(tmdbId: ranked.tmdbId) && !addedIds.contains(ranked.tmdbId)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                
                if isSearching {
                    Spacer()
                    ProgressView("Searching...")
                        .tint(MarquiColors.textTertiary)
                        .foregroundStyle(MarquiColors.textSecondary)
                    Spacer()
                } else if !searchQuery.isEmpty {
                    searchResultsList
                } else {
                    fromRankingsSection
                }
            }
            .background(MarquiColors.background)
            .navigationTitle("Add Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(MarquiColors.brand)
                }
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: MarquiSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(MarquiColors.textTertiary)
            
            TextField("Search movies & TV shows...", text: $searchQuery)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .foregroundStyle(MarquiColors.textPrimary)
                .onChange(of: searchQuery) { _, _ in
                    performSearch()
                }
            
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(MarquiColors.textTertiary)
                }
            }
        }
        .padding(MarquiSpacing.sm)
        .background(MarquiColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: MarquiRadius.md))
        .padding(.horizontal, MarquiSpacing.md)
        .padding(.vertical, MarquiSpacing.xs)
    }
    
    // MARK: - Search Results
    
    private var searchResultsList: some View {
        List {
            if let error = searchError {
                Text(error)
                    .font(MarquiTypography.bodyMedium)
                    .foregroundStyle(MarquiColors.textSecondary)
                    .listRowBackground(MarquiColors.background)
            } else if searchResults.isEmpty && !isSearching {
                Text("No results found")
                    .font(MarquiTypography.bodyMedium)
                    .foregroundStyle(MarquiColors.textSecondary)
                    .listRowBackground(MarquiColors.background)
            } else {
                ForEach(searchResults) { result in
                    Button {
                        addSearchResult(result)
                    } label: {
                        searchResultRow(result)
                    }
                    .buttonStyle(.plain)
                    .disabled(isInList(tmdbId: result.id))
                    .listRowBackground(MarquiColors.background)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private func searchResultRow(_ result: TMDBSearchResult) -> some View {
        let inList = isInList(tmdbId: result.id)
        
        return HStack(spacing: MarquiSpacing.sm) {
            CachedPosterImage(
                url: result.posterURL,
                width: MarquiPoster.miniWidth,
                height: MarquiPoster.miniHeight,
                cornerRadius: MarquiRadius.sm,
                placeholderIcon: result.resolvedMediaType == .movie ? "film" : "tv"
            )
            
            VStack(alignment: .leading, spacing: MarquiSpacing.xxs) {
                Text(result.displayTitle)
                    .font(MarquiTypography.headingSmall)
                    .foregroundStyle(MarquiColors.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: MarquiSpacing.xs) {
                    if let year = result.displayYear {
                        Text(year)
                            .font(MarquiTypography.labelSmall)
                            .foregroundStyle(MarquiColors.textTertiary)
                    }
                    Text(result.resolvedMediaType == .movie ? "Movie" : "TV")
                        .font(MarquiTypography.labelSmall)
                        .foregroundStyle(MarquiColors.textTertiary)
                }
            }
            
            Spacer()
            
            if inList {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(MarquiColors.success)
            } else {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(MarquiColors.brand)
            }
        }
        .opacity(inList ? 0.5 : 1.0)
    }
    
    // MARK: - From Rankings
    
    private var fromRankingsSection: some View {
        Group {
            if rankedNotInList.isEmpty && (list.items ?? []).isEmpty {
                VStack(spacing: MarquiSpacing.md) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(MarquiColors.textQuaternary)
                    Text("Search to add movies and shows")
                        .font(MarquiTypography.bodyMedium)
                        .foregroundStyle(MarquiColors.textSecondary)
                    Spacer()
                }
            } else if rankedNotInList.isEmpty {
                VStack(spacing: MarquiSpacing.md) {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 40))
                        .foregroundStyle(MarquiColors.success)
                    Text("All your ranked items are in this list")
                        .font(MarquiTypography.bodyMedium)
                        .foregroundStyle(MarquiColors.textSecondary)
                    Text("Search to add more")
                        .font(MarquiTypography.bodySmall)
                        .foregroundStyle(MarquiColors.textTertiary)
                    Spacer()
                }
            } else {
                List {
                    Section {
                        Text("From Your Rankings")
                            .font(MarquiTypography.headingSmall)
                            .foregroundStyle(MarquiColors.textSecondary)
                            .listRowBackground(MarquiColors.background)
                        
                        ForEach(rankedNotInList) { item in
                            Button {
                                addRankedItem(item)
                            } label: {
                                rankedItemRow(item)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(MarquiColors.background)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
    
    private func rankedItemRow(_ item: RankedItem) -> some View {
        HStack(spacing: MarquiSpacing.sm) {
            CachedPosterImage(
                url: item.posterURL,
                width: MarquiPoster.miniWidth,
                height: MarquiPoster.miniHeight,
                cornerRadius: MarquiRadius.sm,
                placeholderIcon: item.mediaType == .movie ? "film" : "tv"
            )
            
            VStack(alignment: .leading, spacing: MarquiSpacing.xxs) {
                Text(item.title)
                    .font(MarquiTypography.headingSmall)
                    .foregroundStyle(MarquiColors.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: MarquiSpacing.xs) {
                    Circle()
                        .fill(MarquiColors.tierColor(item.tier))
                        .frame(width: 8, height: 8)
                    Text("#\(item.rank)")
                        .font(MarquiTypography.labelSmall)
                        .foregroundStyle(MarquiColors.textSecondary)
                    if let year = item.year {
                        Text(year)
                            .font(MarquiTypography.labelSmall)
                            .foregroundStyle(MarquiColors.textTertiary)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(MarquiColors.brand)
        }
    }
    
    // MARK: - Actions
    
    private func isInList(tmdbId: Int) -> Bool {
        list.contains(tmdbId: tmdbId) || addedIds.contains(tmdbId)
    }
    
    private func addSearchResult(_ result: TMDBSearchResult) {
        guard !isInList(tmdbId: result.id) else { return }
        
        let item = CustomListItem(
            tmdbId: result.id,
            title: result.displayTitle,
            posterPath: result.posterPath,
            releaseDate: result.displayDate,
            mediaType: result.resolvedMediaType,
            position: list.nextPosition
        )
        item.list = list
        modelContext.insert(item)
        list.dateModified = Date()
        addedIds.insert(result.id)
        ActivityLogger.logAddedToList(item: item, list: list, context: modelContext)
        modelContext.safeSave()
    }
    
    private func addRankedItem(_ ranked: RankedItem) {
        guard !isInList(tmdbId: ranked.tmdbId) else { return }
        
        let item = CustomListItem(
            tmdbId: ranked.tmdbId,
            title: ranked.title,
            posterPath: ranked.posterPath,
            releaseDate: ranked.releaseDate,
            mediaType: ranked.mediaType,
            position: list.nextPosition
        )
        item.list = list
        modelContext.insert(item)
        list.dateModified = Date()
        addedIds.insert(ranked.tmdbId)
        ActivityLogger.logAddedToList(item: item, list: list, context: modelContext)
        modelContext.safeSave()
    }
    
    private func performSearch() {
        searchTask?.cancel()
        
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        searchError = nil
        
        searchTask = Task {
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                
                let results = try await TMDBService.shared.searchMulti(query: searchQuery)
                
                await MainActor.run {
                    self.searchResults = results
                    self.isSearching = false
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.searchError = error.localizedDescription
                        self.isSearching = false
                    }
                }
            }
        }
    }
}

#Preview {
    AddToListView(list: CustomList(name: "Test"))
        .modelContainer(for: [CustomList.self, CustomListItem.self, RankedItem.self], inMemory: true)
}
