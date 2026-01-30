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
    @State private var showComparisonFlow = false
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
            .background(RankdColors.background)
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
            .fullScreenCover(isPresented: $showComparisonFlow) {
                if let result = searchResultToRank {
                    ComparisonFlowView(newItem: result)
                }
            }
            .onChange(of: showComparisonFlow) { _, isShowing in
                if !isShowing {
                    if let item = itemToRank,
                       rankedItems.contains(where: { $0.tmdbId == item.tmdbId }) {
                        modelContext.delete(item)
                        try? modelContext.save()
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
            VStack(spacing: RankdSpacing.lg) {
                if let item = itemToRemind {
                    Text("Remind me about \"\(item.title)\"")
                        .font(RankdTypography.headingMedium)
                        .foregroundStyle(RankdColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.top, RankdSpacing.lg)
                }
                
                DatePicker(
                    "Reminder Date",
                    selection: $customReminderDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, RankdSpacing.md)
                
                Spacer()
            }
            .background(RankdColors.background)
            .navigationTitle("Pick a Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showCustomDatePicker = false
                        itemToRemind = nil
                    }
                    .foregroundStyle(RankdColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set Reminder") {
                        if let item = itemToRemind {
                            scheduleReminder(for: item, date: customReminderDate)
                        }
                        showCustomDatePicker = false
                        itemToRemind = nil
                    }
                    .font(RankdTypography.labelLarge)
                    .foregroundStyle(RankdColors.brand)
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
                    withAnimation(RankdMotion.fast) {
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
                .font(RankdTypography.bodyMedium)
                .foregroundStyle(RankdColors.brand)
        }
    }
    
    // MARK: - Pill Picker
    
    private var pillPicker: some View {
        HStack(spacing: 0) {
            ForEach(WatchlistFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(RankdMotion.fast) {
                        filterOption = filter
                    }
                } label: {
                    Text(filter.rawValue)
                        .font(RankdTypography.labelLarge)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RankdSpacing.sm)
                        .background(
                            filterOption == filter
                                ? RankdColors.brand
                                : Color.clear
                        )
                        .foregroundStyle(
                            filterOption == filter
                                ? RankdColors.surfacePrimary
                                : RankdColors.textTertiary
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .padding(RankdSpacing.xxs)
        .background(RankdColors.surfaceSecondary)
        .clipShape(Capsule())
        .padding(.horizontal, RankdSpacing.md)
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
                .font(RankdTypography.labelMedium)
                .foregroundStyle(RankdColors.textTertiary)
            Spacer()
        }
        .padding(.horizontal, RankdSpacing.md)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: RankdSpacing.lg) {
            Spacer()
            
            Image(systemName: "bookmark")
                .font(.system(size: 48))
                .foregroundStyle(RankdColors.textQuaternary)
            
            VStack(spacing: RankdSpacing.xs) {
                Text("Build your watch queue")
                    .font(RankdTypography.headingLarge)
                    .foregroundStyle(RankdColors.textPrimary)
                
                Text("Save movies and shows you want to watch\nso they're ready when you are.")
                    .font(RankdTypography.bodyMedium)
                    .foregroundStyle(RankdColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            NavigationLink(destination: SearchView()) {
                Text("Browse & Save")
                    .font(RankdTypography.labelLarge)
                    .foregroundStyle(RankdColors.surfacePrimary)
                    .padding(.horizontal, RankdSpacing.xl)
                    .padding(.vertical, RankdSpacing.sm)
                    .background(RankdColors.brand)
                    .clipShape(RoundedRectangle(cornerRadius: RankdRadius.md))
            }
            .padding(.top, RankdSpacing.xs)
            
            Spacer()
        }
        .padding(.horizontal, RankdSpacing.lg)
    }
    
    // MARK: - Watchlist
    
    private var watchlist: some View {
        List {
            Section {
                VStack(spacing: RankdSpacing.sm) {
                    pillPicker
                    itemCountHeader
                }
                .listRowBackground(RankdColors.background)
                .listRowInsets(EdgeInsets(top: RankdSpacing.xs, leading: 0, bottom: RankdSpacing.xs, trailing: 0))
                .listRowSeparator(.hidden)
            }
            
            Section {
                ForEach(filteredAndSorted) { item in
                    WatchlistRow(item: item)
                        .listRowBackground(RankdColors.background)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                itemToDelete = item
                                showDeleteConfirmation = true
                                HapticManager.notification(.warning)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                            .tint(RankdColors.error)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
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
                                showComparisonFlow = true
                            } label: {
                                Label("Rank It", systemImage: "list.number")
                            }
                            .tint(RankdColors.brand)
                        }
                        .contextMenu {
                            Section("Priority") {
                                ForEach(WatchlistPriority.allCases, id: \.self) { priority in
                                    Button {
                                        item.priority = priority
                                        try? modelContext.save()
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
                                ForEach(ReminderOption.allCases.filter { $0 != .custom }) { option in
                                    Button {
                                        scheduleReminder(for: item, option: option)
                                    } label: {
                                        Label(option.rawValue, systemImage: option.icon)
                                    }
                                }
                                
                                Button {
                                    itemToRemind = item
                                    customReminderDate = Date().addingTimeInterval(86400)
                                    showCustomDatePicker = true
                                } label: {
                                    Label(ReminderOption.custom.rawValue, systemImage: ReminderOption.custom.icon)
                                }
                            }
                            
                            Section {
                                Button {
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
                                    showComparisonFlow = true
                                } label: {
                                    Label("Rank It", systemImage: "list.number")
                                }
                                
                                Button(role: .destructive) {
                                    itemToDelete = item
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private func deleteItem(_ item: WatchlistItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }
}

// MARK: - Watchlist Row

struct WatchlistRow: View {
    let item: WatchlistItem
    
    var body: some View {
        HStack(spacing: RankdSpacing.sm) {
            // Priority indicator
            if item.priority == .high {
                Circle()
                    .fill(RankdColors.warning)
                    .frame(width: 8, height: 8)
            }
            
            // Poster
            AsyncImage(url: item.posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
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
                    
                    if item.priority == .low {
                        Text("Low")
                            .font(RankdTypography.caption)
                            .foregroundStyle(RankdColors.textTertiary)
                    }
                }
                
                Text("Added \(item.dateAdded.formatted(.relative(presentation: .named)))")
                    .font(RankdTypography.caption)
                    .foregroundStyle(RankdColors.textTertiary)
            }
            
            Spacer()
        }
        .padding(.vertical, RankdSpacing.xxs)
    }
}

#Preview {
    WatchlistView()
        .modelContainer(for: WatchlistItem.self, inMemory: true)
}
