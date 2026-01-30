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
        .background(RankdColors.background)
        .navigationTitle("My Lists")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    suggestedListToCreate = nil
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(RankdColors.textSecondary)
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
                .listRowBackground(RankdColors.background)
            }
            .onDelete(perform: deleteLists)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ScrollView {
            VStack(spacing: RankdSpacing.lg) {
                Spacer().frame(height: RankdSpacing.xxl)
                
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.system(size: 60))
                    .foregroundStyle(RankdColors.textQuaternary)
                
                VStack(spacing: RankdSpacing.xs) {
                    Text("Create Your First List")
                        .font(RankdTypography.headingLarge)
                        .foregroundStyle(RankdColors.textPrimary)
                    Text("Curate themed collections of movies and TV shows")
                        .font(RankdTypography.bodyMedium)
                        .foregroundStyle(RankdColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: RankdSpacing.sm) {
                    Text("Quick Start Ideas")
                        .font(RankdTypography.headingSmall)
                        .foregroundStyle(RankdColors.textSecondary)
                    
                    ForEach(SuggestedList.allSuggestions) { suggestion in
                        Button {
                            suggestedListToCreate = suggestion
                            showCreateSheet = true
                        } label: {
                            HStack(spacing: RankdSpacing.sm) {
                                Text(suggestion.emoji)
                                    .font(RankdTypography.headingLarge)
                                Text(suggestion.name)
                                    .font(RankdTypography.bodyLarge)
                                    .foregroundStyle(RankdColors.textPrimary)
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(RankdColors.textTertiary)
                            }
                            .padding(RankdSpacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: RankdRadius.md)
                                    .fill(RankdColors.surfacePrimary)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, RankdSpacing.md)
            }
            .padding(RankdSpacing.md)
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
        HStack(spacing: RankdSpacing.sm) {
            miniPosterCollage
            
            VStack(alignment: .leading, spacing: RankdSpacing.xxs) {
                HStack(spacing: RankdSpacing.xs) {
                    Text(list.emoji)
                    Text(list.name)
                        .font(RankdTypography.headingSmall)
                        .foregroundStyle(RankdColors.textPrimary)
                        .lineLimit(1)
                }
                
                Text("\(list.items.count) item\(list.items.count == 1 ? "" : "s")")
                    .font(RankdTypography.labelMedium)
                    .foregroundStyle(RankdColors.textSecondary)
                
                Text(list.dateModified, style: .relative)
                    .font(RankdTypography.caption)
                    .foregroundStyle(RankdColors.textTertiary)
            }
            
            Spacer()
        }
        .padding(.vertical, RankdSpacing.xxs)
    }
    
    private var miniPosterCollage: some View {
        let items = Array(sortedItems.prefix(4))
        let size: CGFloat = 60
        
        return ZStack {
            RoundedRectangle(cornerRadius: RankdRadius.sm)
                .fill(RankdColors.surfaceSecondary)
                .frame(width: size, height: size)
            
            if items.isEmpty {
                Image(systemName: "film.stack")
                    .foregroundStyle(RankdColors.textQuaternary)
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
                .clipShape(RoundedRectangle(cornerRadius: RankdRadius.sm))
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
                Rectangle().fill(RankdColors.surfaceTertiary)
            }
            .frame(width: size, height: size)
            .clipped()
        } else {
            Rectangle()
                .fill(RankdColors.surfaceTertiary)
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
