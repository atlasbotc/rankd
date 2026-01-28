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
    
    private var topThree: [RankedItem] {
        Array(filteredItems.prefix(3))
    }
    
    private var remainingItems: [RankedItem] {
        Array(filteredItems.dropFirst(3))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom pill picker
                pillPicker
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                
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
                                                Label("Remove", systemImage: "trash")
                                            }
                                        }
                                }
                            } header: {
                                Text("All Rankings")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .textCase(nil)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Rankings")
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
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedMediaType = type
                    }
                } label: {
                    Text(type == .movie ? "Movies" : "TV Shows")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedMediaType == type
                                ? Color.orange
                                : Color.clear
                        )
                        .foregroundStyle(selectedMediaType == type ? .white : .secondary)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(Color(.secondarySystemBackground))
        .clipShape(Capsule())
        .padding(.horizontal)
    }
    
    // MARK: - Stats Bar
    
    private var statsBar: some View {
        HStack(spacing: 16) {
            let label = selectedMediaType == .movie ? "movies" : "shows"
            
            HStack(spacing: 4) {
                Image(systemName: "number")
                    .foregroundStyle(.orange)
                Text("\(filteredItems.count) \(label) ranked")
            }
            
            let goodCount = filteredItems.filter { $0.tier == .good }.count
            if goodCount > 0 {
                HStack(spacing: 4) {
                    Text("🟢")
                    Text("\(goodCount)")
                }
            }
            
            let mediumCount = filteredItems.filter { $0.tier == .medium }.count
            if mediumCount > 0 {
                HStack(spacing: 4) {
                    Text("🟡")
                    Text("\(mediumCount)")
                }
            }
            
            let badCount = filteredItems.filter { $0.tier == .bad }.count
            if badCount > 0 {
                HStack(spacing: 4) {
                    Text("🔴")
                    Text("\(badCount)")
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
    }
    
    // MARK: - Top 3 Showcase
    
    private var topShowcase: some View {
        VStack(spacing: 12) {
            HStack {
                Text("🏆 Top \(min(3, topThree.count))")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            
            HStack(alignment: .bottom, spacing: 12) {
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
            .padding(.horizontal)
        }
    }
    
    // MARK: - Remaining List
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: selectedMediaType == .movie ? "film" : "tv")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
            }
            
            Text("No \(selectedMediaType == .movie ? "movies" : "TV shows") ranked yet")
                .font(.title3.bold())
            
            Text("Search for something you've watched\nand start building your list")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
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
}

// MARK: - Top Ranked Card

private struct TopRankedCard: View {
    let item: RankedItem
    let rank: Int
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack(alignment: .top) {
                    AsyncImage(url: item.posterURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.secondary.opacity(0.15))
                            .overlay {
                                Image(systemName: item.mediaType == .movie ? "film" : "tv")
                                    .font(.title)
                                    .foregroundStyle(.tertiary)
                            }
                    }
                    .aspectRatio(2/3, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                    
                    // Medal
                    medalBadge
                        .offset(y: -12)
                }
                
                Text(item.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                
                Text(item.tier.emoji)
                    .font(.caption)
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
    
    private var medalBadge: some View {
        ZStack {
            Circle()
                .fill(medalColor)
                .frame(width: 28, height: 28)
                .shadow(color: medalColor.opacity(0.5), radius: 4, y: 2)
            
            Text("\(rank)")
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
    }
    
    private var medalColor: Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0) // Gold
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.78) // Silver
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20) // Bronze
        default: return .gray
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
                .frame(width: 40, alignment: .leading)
            
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
                    .font(.subheadline.weight(.semibold))
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
            
            // Tier
            Text(item.tier.emoji)
                .font(.title3)
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
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.title)
                                .font(.title2.bold())
                            
                            if let year = item.year {
                                Text(year)
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack(spacing: 6) {
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
                            Text("No review yet — tap Edit to add one")
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
