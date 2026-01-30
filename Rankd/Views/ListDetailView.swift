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
                        withAnimation {
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
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !list.listDescription.isEmpty {
                Text(list.listDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Text("\(list.items.count) item\(list.items.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Items List
    
    private var itemsList: some View {
        List {
            Section {
                if !list.listDescription.isEmpty {
                    Text(list.listDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .listRowSeparator(.hidden)
                }
                
                Text("\(list.items.count) item\(list.items.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .listRowSeparator(.hidden)
            }
            
            Section {
                ForEach(sortedItems) { item in
                    NavigationLink(destination: MediaDetailView(tmdbId: item.tmdbId, mediaType: item.mediaType)) {
                        ListItemRow(item: item)
                    }
                }
                .onDelete(perform: deleteItems)
                .onMove(perform: moveItems)
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, isEditing ? .constant(.active) : .constant(.inactive))
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "film.stack")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text("No Items Yet")
                    .font(.title3.bold())
                Text("Add movies and TV shows to your list")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Button {
                showAddItems = true
            } label: {
                Label("Add Items", systemImage: "plus")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .foregroundStyle(.white)
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
        // Re-number positions
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
        HStack(spacing: 12) {
            // Position
            Text("#\(item.position)")
                .font(.subheadline.bold())
                .foregroundStyle(.orange)
                .frame(width: 32, alignment: .center)
            
            // Poster
            AsyncImage(url: item.posterURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
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
                
                HStack(spacing: 6) {
                    if let year = item.year {
                        Text(year)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(item.mediaType == .movie ? "Movie" : "TV")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
                
                if let note = item.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .italic()
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        ListDetailView(list: CustomList(name: "Test", emoji: "🎬"))
    }
    .modelContainer(for: [CustomList.self, CustomListItem.self], inMemory: true)
}
