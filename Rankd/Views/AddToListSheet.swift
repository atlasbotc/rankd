import SwiftUI
import SwiftData

/// Sheet shown from MediaDetailView to add a movie/show to one or more custom lists.
struct AddToListSheet: View {
    let tmdbId: Int
    let title: String
    let posterPath: String?
    let releaseDate: String?
    let mediaType: MediaType
    
    @Query(sort: \CustomList.dateModified, order: .reverse) private var lists: [CustomList]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var showCreateList = false
    @State private var addedToLists: Set<UUID> = []
    
    var body: some View {
        NavigationStack {
            Group {
                if lists.isEmpty {
                    emptyState
                } else {
                    listSelection
                }
            }
            .navigationTitle("Add to List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateList = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateList) {
                CreateListView(suggested: nil)
            }
        }
    }
    
    // MARK: - List Selection
    
    private var listSelection: some View {
        List {
            ForEach(lists) { list in
                let alreadyIn = list.contains(tmdbId: tmdbId) || addedToLists.contains(list.id)
                
                Button {
                    addToList(list)
                } label: {
                    HStack(spacing: 12) {
                        Text(list.emoji)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(list.name)
                                .font(.body.weight(.medium))
                            Text("\(list.items.count) item\(list.items.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if alreadyIn {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(alreadyIn)
                .opacity(alreadyIn ? 0.6 : 1.0)
            }
            
            Section {
                Button {
                    showCreateList = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.orange)
                        Text("Create New List")
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text("No Lists Yet")
                    .font(.title3.bold())
                Text("Create a list to add \"\(title)\" to it")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                showCreateList = true
            } label: {
                Label("Create a List", systemImage: "plus")
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
    
    private func addToList(_ list: CustomList) {
        guard !list.contains(tmdbId: tmdbId), !addedToLists.contains(list.id) else { return }
        
        let item = CustomListItem(
            tmdbId: tmdbId,
            title: title,
            posterPath: posterPath,
            releaseDate: releaseDate,
            mediaType: mediaType,
            position: list.nextPosition
        )
        item.list = list
        modelContext.insert(item)
        list.dateModified = Date()
        addedToLists.insert(list.id)
        try? modelContext.save()
    }
}
