import SwiftUI
import SwiftData

struct ListsView: View {
    @Query(sort: \CustomList.dateModified, order: .reverse) private var lists: [CustomList]
    @Environment(\.modelContext) private var modelContext
    
    @State private var showCreateSheet = false
    @State private var suggestedListToCreate: SuggestedList?
    
    var body: some View {
        Group {
            if lists.isEmpty {
                emptyState
            } else {
                listContent
            }
        }
        .navigationTitle("My Lists")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    suggestedListToCreate = nil
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateListView(suggested: suggestedListToCreate)
        }
    }
    
    // MARK: - List Content
    
    private var listContent: some View {
        List {
            ForEach(lists) { list in
                NavigationLink(destination: ListDetailView(list: list)) {
                    ListRowView(list: list)
                }
            }
            .onDelete(perform: deleteLists)
        }
        .listStyle(.plain)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 40)
                
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange.opacity(0.6))
                
                VStack(spacing: 8) {
                    Text("Create Your First List")
                        .font(.title2.bold())
                    Text("Curate themed collections of movies and TV shows")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 12) {
                    Text("Quick Start Ideas")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    ForEach(SuggestedList.allSuggestions) { suggestion in
                        Button {
                            suggestedListToCreate = suggestion
                            showCreateSheet = true
                        } label: {
                            HStack(spacing: 12) {
                                Text(suggestion.emoji)
                                    .font(.title2)
                                Text(suggestion.name)
                                    .font(.body.weight(.medium))
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.orange)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }
    
    // MARK: - Actions
    
    private func deleteLists(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(lists[index])
        }
        try? modelContext.save()
    }
}

// MARK: - List Row

struct ListRowView: View {
    let list: CustomList
    
    private var sortedItems: [CustomListItem] {
        list.sortedItems
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Mini poster collage
            miniPosterCollage
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(list.emoji)
                    Text(list.name)
                        .font(.headline)
                        .lineLimit(1)
                }
                
                Text("\(list.items.count) item\(list.items.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(list.dateModified, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var miniPosterCollage: some View {
        let items = Array(sortedItems.prefix(4))
        let size: CGFloat = 60
        
        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))
                .frame(width: size, height: size)
            
            if items.isEmpty {
                Image(systemName: "film.stack")
                    .foregroundStyle(.tertiary)
            } else {
                let cellSize = (size - 2) / 2
                VStack(spacing: 1) {
                    HStack(spacing: 1) {
                        miniPoster(for: items.count > 0 ? items[0] : nil, size: cellSize)
                        miniPoster(for: items.count > 1 ? items[1] : nil, size: cellSize)
                    }
                    HStack(spacing: 1) {
                        miniPoster(for: items.count > 2 ? items[2] : nil, size: cellSize)
                        miniPoster(for: items.count > 3 ? items[3] : nil, size: cellSize)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(width: size, height: size)
    }
    
    @ViewBuilder
    private func miniPoster(for item: CustomListItem?, size: CGFloat) -> some View {
        if let item = item, let url = item.posterURL {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(Color(.quaternarySystemFill))
            }
            .frame(width: size, height: size)
            .clipped()
        } else {
            Rectangle()
                .fill(Color(.quaternarySystemFill))
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Suggested List

struct SuggestedList: Identifiable {
    let id = UUID()
    let emoji: String
    let name: String
    
    static let allSuggestions: [SuggestedList] = [
        SuggestedList(emoji: "🏆", name: "All-Time Favorites"),
        SuggestedList(emoji: "😱", name: "Best Horror"),
        SuggestedList(emoji: "😂", name: "Funniest Movies"),
        SuggestedList(emoji: "❤️", name: "Comfort Watches"),
        SuggestedList(emoji: "🍿", name: "Watch With Friends"),
        SuggestedList(emoji: "🎄", name: "Holiday Movies"),
    ]
}

#Preview {
    NavigationStack {
        ListsView()
    }
    .modelContainer(for: [CustomList.self, CustomListItem.self], inMemory: true)
}
