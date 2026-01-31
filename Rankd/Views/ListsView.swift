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
                Spacer().frame(height: RankdSpacing.xl)
                
                // Hero illustration area
                VStack(spacing: RankdSpacing.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: RankdRadius.lg)
                            .fill(RankdColors.brandSubtle)
                            .frame(width: 80, height: 80)
                        Image(systemName: "rectangle.stack.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(RankdColors.brand)
                    }
                    
                    Text("Start a Collection")
                        .font(RankdTypography.displayMedium)
                        .foregroundStyle(RankdColors.textPrimary)
                    
                    Text("Organize movies and shows into themed lists.\nPick a template or create your own.")
                        .font(RankdTypography.bodyMedium)
                        .foregroundStyle(RankdColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, RankdSpacing.lg)
                }
                
                // Create blank button
                Button {
                    suggestedListToCreate = nil
                    showCreateSheet = true
                } label: {
                    Label("Create Blank List", systemImage: "plus")
                        .font(RankdTypography.headingSmall)
                        .foregroundStyle(RankdColors.surfacePrimary)
                        .padding(.horizontal, RankdSpacing.lg)
                        .padding(.vertical, RankdSpacing.sm)
                        .background(
                            Capsule()
                                .fill(RankdColors.brand)
                        )
                }
                
                // Template suggestions
                VStack(alignment: .leading, spacing: RankdSpacing.sm) {
                    Text("Or start from a template")
                        .font(RankdTypography.labelMedium)
                        .foregroundStyle(RankdColors.textTertiary)
                        .padding(.horizontal, RankdSpacing.md)
                    
                    ForEach(SuggestedList.allSuggestions) { suggestion in
                        Button {
                            suggestedListToCreate = suggestion
                            showCreateSheet = true
                        } label: {
                            HStack(spacing: RankdSpacing.sm) {
                                Text(suggestion.emoji)
                                    .font(.system(size: 28))
                                    .frame(width: 44, height: 44)
                                    .background(
                                        Circle()
                                            .fill(RankdColors.surfaceSecondary)
                                    )
                                
                                VStack(alignment: .leading, spacing: RankdSpacing.xxs) {
                                    Text(suggestion.name)
                                        .font(RankdTypography.headingSmall)
                                        .foregroundStyle(RankdColors.textPrimary)
                                    Text(suggestion.description)
                                        .font(RankdTypography.bodySmall)
                                        .foregroundStyle(RankdColors.textTertiary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(RankdColors.brand)
                            }
                            .padding(RankdSpacing.sm)
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
                
                Text("\(list.itemCount) item\(list.itemCount == 1 ? "" : "s")")
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
    let description: String
    
    static let allSuggestions: [SuggestedList] = [
        SuggestedList(emoji: "🏆", name: "All-Time Favorites", description: "The ones that never get old"),
        SuggestedList(emoji: "🔥", name: "Best of 2024", description: "Top picks from this year"),
        SuggestedList(emoji: "🍿", name: "Watch with Friends", description: "Perfect for movie night"),
        SuggestedList(emoji: "📺", name: "Weekend Binge", description: "Clear your schedule for these"),
        SuggestedList(emoji: "❤️", name: "Comfort Watches", description: "Warm, familiar, always good"),
        SuggestedList(emoji: "💎", name: "Hidden Gems", description: "Underrated titles worth discovering"),
        SuggestedList(emoji: "🤫", name: "Guilty Pleasures", description: "Love them, no apologies"),
    ]
}

#Preview {
    NavigationStack {
        ListsView()
    }
    .modelContainer(for: [CustomList.self, CustomListItem.self], inMemory: true)
}
