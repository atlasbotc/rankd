import SwiftUI
import SwiftData

struct RankedListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RankedItem.rank) private var allItems: [RankedItem]
    @State private var selectedMediaType: MediaType = .movie
    @State private var showDeleteConfirmation = false
    @State private var itemToDelete: RankedItem?
    @State private var selectedItem: RankedItem?
    @State private var showDetailSheet = false
    
    var filteredItems: [RankedItem] {
        allItems
            .filter { $0.mediaType == selectedMediaType }
            .sorted { $0.rank < $1.rank }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Media type picker
                Picker("Media Type", selection: $selectedMediaType) {
                    HStack {
                        Image(systemName: "film")
                        Text("Movies")
                    }.tag(MediaType.movie)
                    
                    HStack {
                        Image(systemName: "tv")
                        Text("TV Shows")
                    }.tag(MediaType.tv)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if filteredItems.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    rankingsList
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
            .sheet(isPresented: $showDetailSheet) {
                if let item = selectedItem {
                    ItemDetailSheet(item: item)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: selectedMediaType == .movie ? "film" : "tv")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text("No \(selectedMediaType == .movie ? "movies" : "TV shows") ranked yet")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Add some from the Discover tab")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
    
    private var rankingsList: some View {
        List {
            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                RankedItemRow(item: item, displayRank: index + 1)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedItem = item
                        showDetailSheet = true
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            itemToDelete = item
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            .onMove(perform: moveItems)
        }
        .listStyle(.plain)
    }
    
    private func deleteItem(_ item: RankedItem) {
        let deletedRank = item.rank
        let mediaType = item.mediaType
        modelContext.delete(item)
        
        // Reorder remaining items
        let remainingItems = allItems.filter { $0.mediaType == mediaType && $0.rank > deletedRank }
        for item in remainingItems {
            item.rank -= 1
        }
        
        try? modelContext.save()
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        var items = filteredItems
        items.move(fromOffsets: source, toOffset: destination)
        
        // Update ranks
        for (index, item) in items.enumerated() {
            item.rank = index + 1
        }
        
        try? modelContext.save()
    }
}

// MARK: - Ranked Item Row
struct RankedItemRow: View {
    let item: RankedItem
    let displayRank: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank number with medal for top 3
            ZStack {
                if displayRank <= 3 {
                    Circle()
                        .fill(medalColor)
                        .frame(width: 36, height: 36)
                    Text("\(displayRank)")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                } else {
                    Text("#\(displayRank)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(width: 40)
                }
            }
            
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
                    
                    if item.review != nil {
                        Image(systemName: "text.quote")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Tier indicator
            Text(item.tier.emoji)
                .font(.title2)
        }
        .padding(.vertical, 4)
    }
    
    private var medalColor: Color {
        switch displayRank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .clear
        }
    }
}

// MARK: - Item Detail Sheet
struct ItemDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var item: RankedItem
    @State private var editedReview: String = ""
    @State private var isEditing = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack(alignment: .top, spacing: 16) {
                        AsyncImage(url: item.posterURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(.quaternary)
                        }
                        .frame(width: 100, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.title)
                                .font(.title2.bold())
                            
                            if let year = item.year {
                                Text(year)
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack {
                                Text(item.tier.emoji)
                                Text(item.tier.rawValue)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Text("Ranked #\(item.rank)")
                                .font(.headline)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Review
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Your Review")
                                .font(.headline)
                            Spacer()
                            Button(isEditing ? "Done" : "Edit") {
                                if isEditing {
                                    item.review = editedReview.isEmpty ? nil : editedReview
                                    try? modelContext.save()
                                }
                                isEditing.toggle()
                            }
                        }
                        
                        if isEditing {
                            TextEditor(text: $editedReview)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else if let review = item.review, !review.isEmpty {
                            Text(review)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("No review yet")
                                .foregroundStyle(.tertiary)
                                .italic()
                        }
                    }
                    .padding(.horizontal)
                    
                    if !item.overview.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Synopsis")
                                .font(.headline)
                            Text(item.overview)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                editedReview = item.review ?? ""
            }
        }
    }
}

#Preview {
    RankedListView()
        .modelContainer(for: RankedItem.self, inMemory: true)
}
