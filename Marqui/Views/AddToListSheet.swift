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
            .background(MarquiColors.background)
            .navigationTitle("Add to List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(MarquiColors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateList = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(MarquiColors.textSecondary)
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
                    HStack(spacing: MarquiSpacing.sm) {
                        Text(list.emoji)
                            .font(MarquiTypography.headingLarge)
                        
                        VStack(alignment: .leading, spacing: MarquiSpacing.xxs) {
                            Text(list.name)
                                .font(MarquiTypography.headingSmall)
                                .foregroundStyle(MarquiColors.textPrimary)
                            Text("\(list.itemCount) item\(list.itemCount == 1 ? "" : "s")")
                                .font(MarquiTypography.labelSmall)
                                .foregroundStyle(MarquiColors.textSecondary)
                        }
                        
                        Spacer()
                        
                        if alreadyIn {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(MarquiColors.success)
                        } else {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(MarquiColors.brand)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(alreadyIn)
                .opacity(alreadyIn ? 0.6 : 1.0)
                .listRowBackground(MarquiColors.background)
            }
            
            Section {
                Button {
                    showCreateList = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(MarquiColors.brand)
                        Text("Create New List")
                            .font(MarquiTypography.headingSmall)
                            .foregroundStyle(MarquiColors.brand)
                    }
                }
                .listRowBackground(MarquiColors.background)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: MarquiSpacing.lg) {
            Spacer()
            
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 50))
                .foregroundStyle(MarquiColors.textQuaternary)
            
            VStack(spacing: MarquiSpacing.xs) {
                Text("No Lists Yet")
                    .font(MarquiTypography.headingMedium)
                    .foregroundStyle(MarquiColors.textPrimary)
                Text("Create a list to add \"\(title)\" to it")
                    .font(MarquiTypography.bodyMedium)
                    .foregroundStyle(MarquiColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                showCreateList = true
            } label: {
                Label("Create a List", systemImage: "plus")
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
        ActivityLogger.logAddedToList(item: item, list: list, context: modelContext)
        modelContext.safeSave()
    }
}
