import SwiftUI
import SwiftData

struct ListDetailView: View {
    @Bindable var list: CustomList
    @Environment(\.modelContext) private var modelContext
    
    @State private var showAddItems = false
    @State private var showEditList = false
    @State private var showShareSheet = false
    @State private var isEditing = false
    
    private var sortedItems: [CustomListItem] {
        list.sortedItems
    }
    
    var body: some View {
        Group {
            if sortedItems.isEmpty {
                emptyState
            } else {
                itemsList
            }
        }
        .background(MarquiColors.background)
        .navigationTitle("\(list.emoji) \(list.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showAddItems = true
                    } label: {
                        Label("Add Items", systemImage: "plus")
                    }
                    
                    Button {
                        showEditList = true
                    } label: {
                        Label("Edit List", systemImage: "pencil")
                    }
                    
                    Button {
                        withAnimation(MarquiMotion.normal) {
                            isEditing.toggle()
                        }
                    } label: {
                        Label(isEditing ? "Done Reordering" : "Reorder", systemImage: "arrow.up.arrow.down")
                    }
                    
                    if !sortedItems.isEmpty {
                        Button {
                            showShareSheet = true
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(MarquiColors.textSecondary)
                }
            }
        }
        .sheet(isPresented: $showAddItems) {
            AddToListView(list: list)
        }
        .sheet(isPresented: $showEditList) {
            CreateListView(suggested: nil, existingList: list)
        }
        .sheet(isPresented: $showShareSheet) {
            ListShareSheet(list: list)
        }
    }
    
    // MARK: - Items List
    
    private var itemsList: some View {
        List {
            Section {
                if !list.listDescription.isEmpty {
                    Text(list.listDescription)
                        .font(MarquiTypography.bodyMedium)
                        .foregroundStyle(MarquiColors.textSecondary)
                        .listRowSeparator(.hidden)
                        .listRowBackground(MarquiColors.background)
                }
                
                Text("\(list.itemCount) item\(list.itemCount == 1 ? "" : "s")")
                    .font(MarquiTypography.caption)
                    .foregroundStyle(MarquiColors.textTertiary)
                    .listRowSeparator(.hidden)
                    .listRowBackground(MarquiColors.background)
            }
            
            Section {
                ForEach(sortedItems) { item in
                    NavigationLink(destination: MediaDetailView(tmdbId: item.tmdbId, mediaType: item.mediaType)) {
                        ListItemRow(item: item)
                    }
                    .listRowBackground(MarquiColors.background)
                }
                .onDelete(perform: deleteItems)
                .onMove(perform: moveItems)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, isEditing ? .constant(.active) : .constant(.inactive))
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: MarquiSpacing.lg) {
            Spacer()
            
            Image(systemName: "film.stack")
                .font(.system(size: 50))
                .foregroundStyle(MarquiColors.textQuaternary)
            
            VStack(spacing: MarquiSpacing.xs) {
                Text("No Items Yet")
                    .font(MarquiTypography.headingMedium)
                    .foregroundStyle(MarquiColors.textPrimary)
                Text("Add movies and TV shows to your list")
                    .font(MarquiTypography.bodyMedium)
                    .foregroundStyle(MarquiColors.textSecondary)
            }
            
            Button {
                showAddItems = true
            } label: {
                Label("Add Items", systemImage: "plus")
                    .font(MarquiTypography.headingSmall)
                    .padding(.horizontal, MarquiSpacing.lg)
                    .padding(.vertical, MarquiSpacing.sm)
                    .background(MarquiColors.brand)
                    .foregroundStyle(MarquiColors.textPrimary)
                    .clipShape(Capsule())
            }
            
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private func deleteItems(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { sortedItems[$0] }
        let deletedIds = Set(itemsToDelete.map { $0.id })
        for item in itemsToDelete {
            modelContext.delete(item)
        }
        list.dateModified = Date()
        modelContext.safeSave()
        
        // Renumber remaining items excluding deleted ones
        let remaining = (list.items ?? [])
            .filter { !deletedIds.contains($0.id) }
            .sorted { $0.position < $1.position }
        for (index, item) in remaining.enumerated() {
            item.position = index + 1
        }
        modelContext.safeSave()
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        var items = sortedItems
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() {
            item.position = index + 1
        }
        list.dateModified = Date()
        modelContext.safeSave()
    }
    
    private func renumberPositions() {
        let items = list.sortedItems
        for (index, item) in items.enumerated() {
            item.position = index + 1
        }
        modelContext.safeSave()
    }
}

// MARK: - List Item Row

struct ListItemRow: View {
    let item: CustomListItem
    
    var body: some View {
        HStack(spacing: MarquiSpacing.sm) {
            // Position
            Text("#\(item.position)")
                .font(MarquiTypography.labelMedium)
                .foregroundStyle(MarquiColors.textSecondary)
                .frame(width: 32, alignment: .center)
            
            // Poster
            CachedPosterImage(
                url: item.posterURL,
                width: MarquiPoster.thumbWidth,
                height: MarquiPoster.thumbHeight,
                cornerRadius: MarquiRadius.sm,
                placeholderIcon: item.mediaType == .movie ? "film" : "tv"
            )
            
            // Info
            VStack(alignment: .leading, spacing: MarquiSpacing.xxs) {
                Text(item.title)
                    .font(MarquiTypography.headingSmall)
                    .foregroundStyle(MarquiColors.textPrimary)
                    .lineLimit(2)
                
                HStack(spacing: MarquiSpacing.xs) {
                    if let year = item.year {
                        Text(year)
                            .font(MarquiTypography.labelSmall)
                            .foregroundStyle(MarquiColors.textTertiary)
                    }
                    
                    Text(item.mediaType == .movie ? "Movie" : "TV")
                        .font(MarquiTypography.labelSmall)
                        .foregroundStyle(MarquiColors.textTertiary)
                }
                
                if let note = item.note, !note.isEmpty {
                    Text(note)
                        .font(MarquiTypography.bodySmall)
                        .foregroundStyle(MarquiColors.textSecondary)
                        .lineLimit(1)
                        .italic()
                }
            }
        }
        .padding(.vertical, MarquiSpacing.xxs)
    }
}

#Preview {
    NavigationStack {
        ListDetailView(list: CustomList(name: "Test", emoji: "🎬"))
    }
    .modelContainer(for: [CustomList.self, CustomListItem.self], inMemory: true)
}
