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
        .background(MarquiColors.background)
        .navigationTitle("My Lists")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    suggestedListToCreate = nil
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(MarquiColors.textSecondary)
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
                .listRowBackground(MarquiColors.background)
            }
            .onDelete(perform: deleteLists)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ScrollView {
            VStack(spacing: MarquiSpacing.lg) {
                Spacer().frame(height: MarquiSpacing.xl)
                
                // Hero illustration area
                VStack(spacing: MarquiSpacing.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: MarquiRadius.lg)
                            .fill(MarquiColors.brandSubtle)
                            .frame(width: 80, height: 80)
                        Image(systemName: "rectangle.stack.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(MarquiColors.brand)
                    }
                    
                    Text("Start a Collection")
                        .font(MarquiTypography.displayMedium)
                        .foregroundStyle(MarquiColors.textPrimary)
                    
                    Text("Organize movies and shows into themed lists.\nPick a template or create your own.")
                        .font(MarquiTypography.bodyMedium)
                        .foregroundStyle(MarquiColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, MarquiSpacing.lg)
                }
                
                // Create blank button
                Button {
                    suggestedListToCreate = nil
                    showCreateSheet = true
                } label: {
                    Label("Create Blank List", systemImage: "plus")
                        .font(MarquiTypography.headingSmall)
                        .foregroundStyle(MarquiColors.surfacePrimary)
                        .padding(.horizontal, MarquiSpacing.lg)
                        .padding(.vertical, MarquiSpacing.sm)
                        .background(
                            Capsule()
                                .fill(MarquiColors.brand)
                        )
                }
                
                // Template suggestions
                VStack(alignment: .leading, spacing: MarquiSpacing.sm) {
                    Text("Or start from a template")
                        .font(MarquiTypography.labelMedium)
                        .foregroundStyle(MarquiColors.textTertiary)
                        .padding(.horizontal, MarquiSpacing.md)
                    
                    ForEach(SuggestedList.allSuggestions) { suggestion in
                        Button {
                            suggestedListToCreate = suggestion
                            showCreateSheet = true
                        } label: {
                            HStack(spacing: MarquiSpacing.sm) {
                                Text(suggestion.emoji)
                                    .font(.system(size: 28))
                                    .frame(width: 44, height: 44)
                                    .background(
                                        Circle()
                                            .fill(MarquiColors.surfaceSecondary)
                                    )
                                
                                VStack(alignment: .leading, spacing: MarquiSpacing.xxs) {
                                    Text(suggestion.name)
                                        .font(MarquiTypography.headingSmall)
                                        .foregroundStyle(MarquiColors.textPrimary)
                                    Text(suggestion.description)
                                        .font(MarquiTypography.bodySmall)
                                        .foregroundStyle(MarquiColors.textTertiary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(MarquiColors.brand)
                            }
                            .padding(MarquiSpacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: MarquiRadius.md)
                                    .fill(MarquiColors.surfacePrimary)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, MarquiSpacing.md)
            }
            .padding(MarquiSpacing.md)
        }
    }
    
    // MARK: - Actions
    
    private func deleteLists(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(lists[index])
        }
        modelContext.safeSave()
    }
}

// MARK: - List Row

struct ListRowView: View {
    let list: CustomList
    
    private var sortedItems: [CustomListItem] {
        list.sortedItems
    }
    
    var body: some View {
        HStack(spacing: MarquiSpacing.sm) {
            miniPosterCollage
            
            VStack(alignment: .leading, spacing: MarquiSpacing.xxs) {
                HStack(spacing: MarquiSpacing.xs) {
                    Text(list.emoji)
                    Text(list.name)
                        .font(MarquiTypography.headingSmall)
                        .foregroundStyle(MarquiColors.textPrimary)
                        .lineLimit(1)
                }
                
                Text("\(list.itemCount) item\(list.itemCount == 1 ? "" : "s")")
                    .font(MarquiTypography.labelMedium)
                    .foregroundStyle(MarquiColors.textSecondary)
                
                Text(list.dateModified, style: .relative)
                    .font(MarquiTypography.caption)
                    .foregroundStyle(MarquiColors.textTertiary)
            }
            
            Spacer()
        }
        .padding(.vertical, MarquiSpacing.xxs)
    }
    
    private var miniPosterCollage: some View {
        let items = Array(sortedItems.prefix(4))
        let size: CGFloat = 60
        
        return ZStack {
            RoundedRectangle(cornerRadius: MarquiRadius.sm)
                .fill(MarquiColors.surfaceSecondary)
                .frame(width: size, height: size)
            
            if items.isEmpty {
                Image(systemName: "film.stack")
                    .foregroundStyle(MarquiColors.textQuaternary)
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
                .clipShape(RoundedRectangle(cornerRadius: MarquiRadius.sm))
            }
        }
        .frame(width: size, height: size)
    }
    
    @ViewBuilder
    private func miniPoster(for item: CustomListItem?, size: CGFloat) -> some View {
        if let item = item, let url = item.posterURL {
            CachedAsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(MarquiColors.surfaceTertiary)
            }
            .frame(width: size, height: size)
            .clipped()
        } else {
            Rectangle()
                .fill(MarquiColors.surfaceTertiary)
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
        SuggestedList(emoji: "🔥", name: "Best of \(Calendar.current.component(.year, from: Date()))", description: "Top picks from this year"),
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
