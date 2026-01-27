import SwiftUI
import SwiftData

struct RankedListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RankedItem.rank) private var items: [RankedItem]
    @State private var selectedTier: Tier?
    @State private var showDeleteConfirmation = false
    @State private var itemToDelete: RankedItem?
    
    var filteredItems: [RankedItem] {
        guard let tier = selectedTier else {
            return items.sorted { item1, item2 in
                // Sort by tier priority, then by rank
                let tierOrder: [Tier] = [.good, .medium, .bad]
                let tier1Index = tierOrder.firstIndex(of: item1.tier) ?? 0
                let tier2Index = tierOrder.firstIndex(of: item2.tier) ?? 0
                
                if tier1Index != tier2Index {
                    return tier1Index < tier2Index
                }
                return item1.rank < item2.rank
            }
        }
        return items.filter { $0.tier == tier }.sorted { $0.rank < $1.rank }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tier filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "All", isSelected: selectedTier == nil) {
                            selectedTier = nil
                        }
                        
                        ForEach(Tier.allCases, id: \.self) { tier in
                            let count = items.filter { $0.tier == tier }.count
                            FilterChip(
                                title: "\(tier.emoji) \(tier.rawValue) (\(count))",
                                isSelected: selectedTier == tier
                            ) {
                                selectedTier = tier
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(.ultraThinMaterial)
                
                if items.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "list.number")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        Text("No rankings yet")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("Add movies and TV shows to get started")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                } else if filteredItems.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        Text("No items in this tier")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                            RankedItemRow(item: item, displayRank: index + 1)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        itemToDelete = item
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Menu {
                                        ForEach(Tier.allCases, id: \.self) { tier in
                                            Button {
                                                changeTier(item: item, to: tier)
                                            } label: {
                                                Label(tier.rawValue, systemImage: tier == item.tier ? "checkmark" : "")
                                            }
                                        }
                                    } label: {
                                        Label("Tier", systemImage: "arrow.up.arrow.down")
                                    }
                                    .tint(.orange)
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Rankings")
            .alert("Delete Item?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let item = itemToDelete {
                        deleteItem(item)
                    }
                }
            } message: {
                if let item = itemToDelete {
                    Text("Remove \"\(item.title)\" from your rankings?")
                }
            }
        }
    }
    
    private func deleteItem(_ item: RankedItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }
    
    private func changeTier(item: RankedItem, to newTier: Tier) {
        guard item.tier != newTier else { return }
        
        item.tier = newTier
        item.rank = items.filter { $0.tier == newTier }.count + 1
        item.comparisonCount = 0 // Reset comparisons for new tier
        
        try? modelContext.save()
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.orange : Color.secondary.opacity(0.2))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Ranked Item Row
struct RankedItemRow: View {
    let item: RankedItem
    let displayRank: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank number
            Text("#\(displayRank)")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 40)
            
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
            .frame(width: 45, height: 67)
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
            }
            
            Spacer()
            
            // Tier indicator
            Text(item.tier.emoji)
                .font(.title2)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    RankedListView()
        .modelContainer(for: RankedItem.self, inMemory: true)
}
