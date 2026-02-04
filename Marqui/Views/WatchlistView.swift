import SwiftUI
import SwiftData

// MARK: - Sort & Filter Types

enum WatchlistSortOption: String, CaseIterable {
    case dateNewest = "Newest First"
    case dateOldest = "Oldest First"
    case titleAZ = "Title A–Z"
    case titleZA = "Title Z–A"
    case moviesFirst = "Movies First"
    case tvFirst = "TV First"
    case priorityHigh = "Priority (High First)"
}

enum WatchlistFilter: String, CaseIterable {
    case all = "All"
    case movies = "Movies"
    case tvShows = "TV Shows"
}

// MARK: - WatchlistView

struct WatchlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WatchlistItem.dateAdded, order: .reverse) private var items: [WatchlistItem]
    @Query private var rankedItems: [RankedItem]
    
    @State private var itemToRank: WatchlistItem?
    @State private var itemToDelete: WatchlistItem?
    @State private var showDeleteConfirmation = false
    @State private var searchResultToRank: TMDBSearchResult?
    
    @State private var sortOption: WatchlistSortOption = .dateNewest
    @State private var filterOption: WatchlistFilter = .all
    
    // Notification reminder states
    @State private var itemToRemind: WatchlistItem?
    @State private var showReminderOptions = false
    @State private var showCustomDatePicker = false
    @State private var customReminderDate = Date()
    @State private var showReminderConfirmation = false
    @State private var reminderConfirmationTitle = ""
    @State private var showPermissionDeniedAlert = false
    
    @StateObject private var notificationManager = NotificationManager.shared
    
    private var filteredAndSorted: [WatchlistItem] {
        let filtered: [WatchlistItem]
        switch filterOption {
        case .all:
            filtered = items
        case .movies:
            filtered = items.filter { $0.mediaType == .movie }
        case .tvShows:
            filtered = items.filter { $0.mediaType == .tv }
        }
        
        return filtered.sorted { a, b in
            switch sortOption {
            case .dateNewest:
                return a.dateAdded > b.dateAdded
            case .dateOldest:
                return a.dateAdded < b.dateAdded
            case .titleAZ:
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            case .titleZA:
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedDescending
            case .moviesFirst:
                if a.mediaType != b.mediaType { return a.mediaType == .movie }
                return a.dateAdded > b.dateAdded
            case .tvFirst:
                if a.mediaType != b.mediaType { return a.mediaType == .tv }
                return a.dateAdded > b.dateAdded
            case .priorityHigh:
                if a.priority != b.priority { return a.priority < b.priority }
                return a.dateAdded > b.dateAdded
            }
        }
    }
    
    private var movieCount: Int { items.filter { $0.mediaType == .movie }.count }
    private var tvCount: Int { items.filter { $0.mediaType == .tv }.count }
    
    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyState
                } else {
                    watchlist
                }
            }
            .background(MarquiColors.background)
            .navigationTitle("Watchlist")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !items.isEmpty {
                        sortMenu
                    }
                }
            }
            .refreshable {
                HapticManager.impact(.light)
            }
            .alert("Remove from Watchlist?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    if let item = itemToDelete {
                        deleteItem(item)
                    }
                }
            } message: {
                if let item = itemToDelete {
                    Text("Remove \"\(item.title)\" from your watchlist?")
                }
            }
            .fullScreenCover(item: $searchResultToRank) { result in
                ComparisonFlowView(newItem: result)
            }
            .onChange(of: searchResultToRank) { _, newValue in
                if newValue == nil {
                    if let item = itemToRank,
                       rankedItems.contains(where: { $0.tmdbId == item.tmdbId }) {
                        modelContext.delete(item)
                        modelContext.safeSave()
                    }
                    itemToRank = nil
                    searchResultToRank = nil
                }
            }
            .sheet(isPresented: $showCustomDatePicker) {
                customDatePickerSheet
            }
            .alert("Reminder Set", isPresented: $showReminderConfirmation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("We'll remind you about \"\(reminderConfirmationTitle)\"")
            }
            .alert("Notifications Disabled", isPresented: $showPermissionDeniedAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enable notifications in Settings to receive watchlist reminders.")
            }
        }
    }
    
    // MARK: - Custom Date Picker Sheet
    
    private var customDatePickerSheet: some View {
        NavigationStack {
            VStack(spacing: MarquiSpacing.lg) {
                if let item = itemToRemind {
                    Text("Remind me about \"\(item.title)\"")
                        .font(MarquiTypography.headingMedium)
                        .foregroundStyle(MarquiColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.top, MarquiSpacing.lg)
                }
                
                DatePicker(
                    "Reminder Date",
                    selection: $customReminderDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, MarquiSpacing.md)
                
                Spacer()
            }
            .background(MarquiColors.background)
            .navigationTitle("Pick a Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showCustomDatePicker = false
                        itemToRemind = nil
                    }
                    .foregroundStyle(MarquiColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set Reminder") {
                        if let item = itemToRemind {
                            scheduleReminder(for: item, date: customReminderDate)
                        }
                        showCustomDatePicker = false
                        itemToRemind = nil
                    }
                    .font(MarquiTypography.labelLarge)
                    .foregroundStyle(MarquiColors.brand)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    // MARK: - Reminder Scheduling
    
    private func scheduleReminder(for item: WatchlistItem, option: ReminderOption) {
        guard let date = option.triggerDate() else { return }
        scheduleReminder(for: item, date: date)
    }
    
    private func scheduleReminder(for item: WatchlistItem, date: Date) {
        Task {
            // Check permission
            await notificationManager.refreshAuthorizationStatus()
            
            if notificationManager.isDenied {
                showPermissionDeniedAlert = true
                return
            }
            
            await notificationManager.scheduleWatchlistReminder(
                itemId: item.id.uuidString,
                title: item.title,
                mediaType: item.mediaType == .movie ? "movie" : "show",
                posterPath: item.posterPath,
                at: date
            )
            
            reminderConfirmationTitle = item.title
            showReminderConfirmation = true
            HapticManager.notification(.success)
        }
    }
    
    // MARK: - Sort Menu
    
    private var sortMenu: some View {
        Menu {
            ForEach(WatchlistSortOption.allCases, id: \.self) { option in
                Button {
                    withAnimation(MarquiMotion.fast) {
                        sortOption = option
                    }
                } label: {
                    if sortOption == option {
                        Label(option.rawValue, systemImage: "checkmark")
                    } else {
                        Text(option.rawValue)
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(MarquiTypography.bodyMedium)
                .foregroundStyle(MarquiColors.brand)
        }
    }
    
    // MARK: - Pill Picker
    
    private var pillPicker: some View {
        HStack(spacing: 0) {
            ForEach(WatchlistFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(MarquiMotion.fast) {
                        filterOption = filter
                    }
                } label: {
                    Text(filter.rawValue)
                        .font(MarquiTypography.labelLarge)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, MarquiSpacing.sm)
                        .background(
                            filterOption == filter
                                ? MarquiColors.brand
                                : Color.clear
                        )
                        .foregroundStyle(
                            filterOption == filter
                                ? MarquiColors.surfacePrimary
                                : MarquiColors.textTertiary
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .padding(MarquiSpacing.xxs)
        .background(MarquiColors.surfaceSecondary)
        .clipShape(Capsule())
        .padding(.horizontal, MarquiSpacing.md)
    }
    
    // MARK: - Item Count Header
    
    private var itemCountHeader: some View {
        HStack {
            let display = filteredAndSorted.count
            let parts: [String] = {
                var p = ["\(display) item\(display == 1 ? "" : "s")"]
                if filterOption == .all {
                    if movieCount > 0 { p.append("\(movieCount) movie\(movieCount == 1 ? "" : "s")") }
                    if tvCount > 0 { p.append("\(tvCount) show\(tvCount == 1 ? "" : "s")") }
                }
                return p
            }()
            Text(parts.joined(separator: " · "))
                .font(MarquiTypography.labelMedium)
                .foregroundStyle(MarquiColors.textTertiary)
            Spacer()
        }
        .padding(.horizontal, MarquiSpacing.md)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: MarquiSpacing.lg) {
            Spacer()
            
            Image(systemName: "bookmark")
                .font(.system(size: 48))
                .foregroundStyle(MarquiColors.textQuaternary)
            
            VStack(spacing: MarquiSpacing.xs) {
                Text("Build your watch queue")
                    .font(MarquiTypography.headingLarge)
                    .foregroundStyle(MarquiColors.textPrimary)
                
                Text("Save movies and shows you want to watch\nso they're ready when you are.")
                    .font(MarquiTypography.bodyMedium)
                    .foregroundStyle(MarquiColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            NavigationLink(destination: SearchView()) {
                Text("Browse & Save")
                    .font(MarquiTypography.labelLarge)
                    .foregroundStyle(MarquiColors.surfacePrimary)
                    .padding(.horizontal, MarquiSpacing.xl)
                    .padding(.vertical, MarquiSpacing.sm)
                    .background(MarquiColors.brand)
                    .clipShape(RoundedRectangle(cornerRadius: MarquiRadius.md))
            }
            .padding(.top, MarquiSpacing.xs)
            
            Spacer()
        }
        .padding(.horizontal, MarquiSpacing.lg)
    }
    
    // MARK: - Watchlist
    
    private var watchlist: some View {
        VStack(spacing: 0) {
            VStack(spacing: MarquiSpacing.sm) {
                pillPicker
                itemCountHeader
            }
            .padding(.vertical, MarquiSpacing.xs)
            
            if filteredAndSorted.isEmpty {
                Spacer()
                VStack(spacing: MarquiSpacing.md) {
                    Image(systemName: filterOption == .tvShows ? "tv" : "film")
                        .font(.system(size: 36))
                        .foregroundStyle(MarquiColors.textQuaternary)
                    Text("No \(filterOption.rawValue.lowercased()) in your watchlist yet")
                        .font(MarquiTypography.bodyMedium)
                        .foregroundStyle(MarquiColors.textTertiary)
                }
                Spacer()
            } else {
            List {
            Section {
                ForEach(filteredAndSorted) { item in
                    WatchlistRow(
                        item: item,
                        onSetPriority: { priority in
                            item.priority = priority
                            modelContext.safeSave()
                        },
                        onRemind: {
                            itemToRemind = item
                            customReminderDate = Date().addingTimeInterval(86400)
                            showCustomDatePicker = true
                        },
                        onRank: {
                            itemToRank = item
                            searchResultToRank = TMDBSearchResult(
                                id: item.tmdbId,
                                title: item.mediaType == .movie ? item.title : nil,
                                name: item.mediaType == .tv ? item.title : nil,
                                overview: item.overview,
                                posterPath: item.posterPath,
                                releaseDate: item.mediaType == .movie ? item.releaseDate : nil,
                                firstAirDate: item.mediaType == .tv ? item.releaseDate : nil,
                                mediaType: item.mediaType.rawValue,
                                voteAverage: nil
                            )
                        },
                        onDelete: {
                            itemToDelete = item
                            showDeleteConfirmation = true
                            HapticManager.notification(.warning)
                        }
                    )
                    .listRowBackground(MarquiColors.background)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
            }
        }
    }
    
    private func deleteItem(_ item: WatchlistItem) {
        modelContext.delete(item)
        modelContext.safeSave()
    }
}

// MARK: - Watchlist Row

struct WatchlistRow: View {
    let item: WatchlistItem
    var onSetPriority: (WatchlistPriority) -> Void = { _ in }
    var onRemind: () -> Void = {}
    var onRank: () -> Void = {}
    var onDelete: () -> Void = {}
    
    var body: some View {
        HStack(spacing: MarquiSpacing.sm) {
            // Priority indicator
            if item.priority == .high {
                Circle()
                    .fill(MarquiColors.warning)
                    .frame(width: 8, height: 8)
            }
            
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
                    
                    if item.priority == .low {
                        Text("Low")
                            .font(MarquiTypography.caption)
                            .foregroundStyle(MarquiColors.textTertiary)
                    }
                }
                
                Text("Added \(item.dateAdded.formatted(.relative(presentation: .named)))")
                    .font(MarquiTypography.caption)
                    .foregroundStyle(MarquiColors.textTertiary)
            }
            
            Spacer()
            
            // Three-dot menu
            Menu {
                Section("Priority") {
                    ForEach(WatchlistPriority.allCases, id: \.self) { priority in
                        Button {
                            onSetPriority(priority)
                        } label: {
                            Label {
                                Text(priority.label)
                            } icon: {
                                Image(systemName: priority.iconName)
                            }
                            if item.priority == priority {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                
                Section("Remind Me") {
                    Button {
                        onRemind()
                    } label: {
                        Label("Set Reminder", systemImage: "bell")
                    }
                }
                
                Section {
                    Button {
                        onRank()
                    } label: {
                        Label("Rank It", systemImage: "list.number")
                    }
                    
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(MarquiTypography.bodyMedium)
                    .foregroundStyle(MarquiColors.textTertiary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
        }
        .padding(.vertical, MarquiSpacing.xxs)
    }
}

#Preview {
    WatchlistView()
        .modelContainer(for: WatchlistItem.self, inMemory: true)
}
