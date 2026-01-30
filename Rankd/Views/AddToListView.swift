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
                // Search bar
                searchBar
                
                // Content
                if isSearching {
                    Spacer()
                    ProgressView("Searching...")
                    Spacer()
                } else if !searchQuery.isEmpty {
                    searchResultsList
                } else {
                    fromRankingsSection
                }
            }
            .navigationTitle("Add Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search movies & TV shows...", text: $searchQuery)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .onChange(of: searchQuery) { _, _ in
                    performSearch()
                }
            
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Search Results
    
    private var searchResultsList: some View {
        List {
            if let error = searchError {
                Text(error)
                    .foregroundStyle(.secondary)
            } else if searchResults.isEmpty && !isSearching {
                Text("No results found")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(searchResults) { result in
                    Button {
                        addSearchResult(result)
                    } label: {
                        searchResultRow(result)
                    }
                    .buttonStyle(.plain)
                    .disabled(isInList(tmdbId: result.id))
                }
            }
        }
        .listStyle(.plain)
    }
    
    private func searchResultRow(_ result: TMDBSearchResult) -> some View {
        let inList = isInList(tmdbId: result.id)
        
        return HStack(spacing: 12) {
            // Poster
            AsyncImage(url: result.posterURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: result.resolvedMediaType == .movie ? "film" : "tv")
                            .foregroundStyle(.tertiary)
                    }
            }
            .frame(width: 44, height: 66)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(result.displayTitle)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    if let year = result.displayYear {
                        Text(year)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(result.resolvedMediaType == .movie ? "Movie" : "TV")
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
            
            // Status icon
            if inList {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.orange)
            }
        }
        .opacity(inList ? 0.5 : 1.0)
    }
    
    // MARK: - From Rankings
    
    private var fromRankingsSection: some View {
        Group {
            if rankedNotInList.isEmpty && list.items.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Search to add movies and shows")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else if rankedNotInList.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                    Text("All your ranked items are in this list")
                        .foregroundStyle(.secondary)
                    Text("Search to add more")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            } else {
                List {
                    Section("From Your Rankings") {
                        ForEach(rankedNotInList) { item in
                            Button {
                                addRankedItem(item)
                            } label: {
                                rankedItemRow(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    private func rankedItemRow(_ item: RankedItem) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: item.posterURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: item.mediaType == .movie ? "film" : "tv")
                            .foregroundStyle(.tertiary)
                    }
            }
            .frame(width: 44, height: 66)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(item.tier.emoji)
                    Text("#\(item.rank)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let year = item.year {
                        Text(year)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.orange)
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
        try? modelContext.save()
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
        try? modelContext.save()
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
