import SwiftUI
import SwiftData

struct WatchlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WatchlistItem.dateAdded, order: .reverse) private var items: [WatchlistItem]
    
    @State private var itemToRank: WatchlistItem?
    @State private var showTierPicker = false
    @State private var itemToDelete: WatchlistItem?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyState
                } else {
                    watchlist
                }
            }
            .navigationTitle("Watchlist")
            .confirmationDialog("Choose Tier", isPresented: $showTierPicker, presenting: itemToRank) { item in
                ForEach(Tier.allCases, id: \.self) { tier in
                    Button("\(tier.emoji) \(tier.rawValue)") {
                        markAsWatched(item: item, tier: tier)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { item in
                Text("How was \"\(item.title)\"?")
            }
            .alert("Remove from Watchlist?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    if let item = itemToDelete {
                        deleteItem(item)
                    }
                }
            } message: {
                if let item = itemToDelete {
                    Text("Remove \"\(item.title)\" from your watchlist?")
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text("Watchlist empty")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Search for movies & shows to add")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }
    
    private var watchlist: some View {
        List {
            ForEach(items) { item in
                WatchlistRow(item: item)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            itemToDelete = item
                            showDeleteConfirmation = true
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            itemToRank = item
                            showTierPicker = true
                        } label: {
                            Label("Watched", systemImage: "checkmark.circle")
                        }
                        .tint(.green)
                    }
            }
        }
        .listStyle(.plain)
    }
    
    private func markAsWatched(item: WatchlistItem, tier: Tier) {
        // Create ranked item
        let rankedItem = item.toRankedItem(tier: tier)
        modelContext.insert(rankedItem)
        
        // Remove from watchlist
        modelContext.delete(item)
        
        try? modelContext.save()
    }
    
    private func deleteItem(_ item: WatchlistItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }
}

// MARK: - Watchlist Row
struct WatchlistRow: View {
    let item: WatchlistItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Poster
            AsyncImage(url: item.posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: item.mediaType == .movie ? "film" : "tv")
                            .foregroundStyle(.tertiary)
                    }
            }
            .frame(width: 50, height: 75)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    if let year = item.year {
                        Text(year)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(item.mediaType == .movie ? "Movie" : "TV")
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
                
                Text("Added \(item.dateAdded.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            // Swipe hint
            Image(systemName: "chevron.left")
                .font(.caption)
                .foregroundStyle(.quaternary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    WatchlistView()
        .modelContainer(for: WatchlistItem.self, inMemory: true)
}
