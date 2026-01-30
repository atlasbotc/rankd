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
        .background(RankdColors.background)
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
                        withAnimation(RankdMotion.normal) {
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
                        .foregroundStyle(RankdColors.textSecondary)
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
                        .font(RankdTypography.bodyMedium)
                        .foregroundStyle(RankdColors.textSecondary)
                        .listRowSeparator(.hidden)
                        .listRowBackground(RankdColors.background)
                }
                
                Text("\(list.items.count) item\(list.items.count == 1 ? "" : "s")")
                    .font(RankdTypography.caption)
                    .foregroundStyle(RankdColors.textTertiary)
                    .listRowSeparator(.hidden)
                    .listRowBackground(RankdColors.background)
            }
            
            Section {
                ForEach(sortedItems) { item in
                    NavigationLink(destination: MediaDetailView(tmdbId: item.tmdbId, mediaType: item.mediaType)) {
                        ListItemRow(item: item)
                    }
                    .listRowBackground(RankdColors.background)
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
        VStack(spacing: RankdSpacing.lg) {
            Spacer()
            
            Image(systemName: "film.stack")
                .font(.system(size: 50))
                .foregroundStyle(RankdColors.textQuaternary)
            
            VStack(spacing: RankdSpacing.xs) {
                Text("No Items Yet")
                    .font(RankdTypography.headingMedium)
                    .foregroundStyle(RankdColors.textPrimary)
                Text("Add movies and TV shows to your list")
                    .font(RankdTypography.bodyMedium)
                    .foregroundStyle(RankdColors.textSecondary)
            }
            
            Button {
                showAddItems = true
            } label: {
                Label("Add Items", systemImage: "plus")
                    .font(RankdTypography.headingSmall)
                    .padding(.horizontal, RankdSpacing.lg)
                    .padding(.vertical, RankdSpacing.sm)
                    .background(RankdColors.accent)
                    .foregroundStyle(RankdColors.textPrimary)
                    .clipShape(Capsule())
            }
            
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private func deleteItems(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { sortedItems[$0] }
        for item in itemsToDelete {
            modelContext.delete(item)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            renumberPositions()
        }
        list.dateModified = Date()
        try? modelContext.save()
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        var items = sortedItems
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() {
            item.position = index + 1
        }
        list.dateModified = Date()
        try? modelContext.save()
    }
    
    private func renumberPositions() {
        let items = list.sortedItems
        for (index, item) in items.enumerated() {
            item.position = index + 1
        }
        try? modelContext.save()
    }
}

// MARK: - List Item Row

struct ListItemRow: View {
    let item: CustomListItem
    
    var body: some View {
        HStack(spacing: RankdSpacing.sm) {
            // Position
            Text("#\(item.position)")
                .font(RankdTypography.labelMedium)
                .foregroundStyle(RankdColors.textSecondary)
                .frame(width: 32, alignment: .center)
            
            // Poster
            AsyncImage(url: item.posterURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: RankdRadius.sm)
                    .fill(RankdColors.surfaceSecondary)
                    .overlay {
                        Image(systemName: item.mediaType == .movie ? "film" : "tv")
                            .foregroundStyle(RankdColors.textQuaternary)
                    }
            }
            .frame(width: RankdPoster.thumbWidth, height: RankdPoster.thumbHeight)
            .clipShape(RoundedRectangle(cornerRadius: RankdRadius.sm))
            
            // Info
            VStack(alignment: .leading, spacing: RankdSpacing.xxs) {
                Text(item.title)
                    .font(RankdTypography.headingSmall)
                    .foregroundStyle(RankdColors.textPrimary)
                    .lineLimit(2)
                
                HStack(spacing: RankdSpacing.xs) {
                    if let year = item.year {
                        Text(year)
                            .font(RankdTypography.labelSmall)
                            .foregroundStyle(RankdColors.textTertiary)
                    }
                    
                    Text(item.mediaType == .movie ? "Movie" : "TV")
                        .font(RankdTypography.labelSmall)
                        .foregroundStyle(RankdColors.textTertiary)
                }
                
                if let note = item.note, !note.isEmpty {
                    Text(note)
                        .font(RankdTypography.bodySmall)
                        .foregroundStyle(RankdColors.textSecondary)
                        .lineLimit(1)
                        .italic()
                }
            }
        }
        .padding(.vertical, RankdSpacing.xxs)
    }
}

#Preview {
    NavigationStack {
        ListDetailView(list: CustomList(name: "Test", emoji: "🎬"))
    }
    .modelContainer(for: [CustomList.self, CustomListItem.self], inMemory: true)
}
