import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query(sort: \RankedItem.rank) private var rankedItems: [RankedItem]
    @Query private var watchlistItems: [WatchlistItem]
    @Query(sort: \CustomList.dateModified, order: .reverse) private var customLists: [CustomList]
    @Environment(\.modelContext) private var modelContext
    
    @AppStorage("displayName") private var displayName: String = ""
    @AppStorage("memberSinceDate") private var memberSinceDateString: String = ""
    @AppStorage("streakDates") private var streakDatesString: String = ""
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = false
    
    @StateObject private var notificationManager = NotificationManager.shared
    
    @State private var showCompareView = false
    @State private var showLetterboxdImport = false
    @State private var showShareSheet = false
    @State private var showCreateListSheet = false
    @State private var showResetConfirmation = false
    @State private var showAbout = false
    @State private var showWhatsNew = false
    @State private var showNotificationSettingsAlert = false
    @State private var showExportSheet = false
    @State private var exportFileURL: URL?
    @State private var showExportShareSheet = false
    @State private var suggestedListToCreate: SuggestedList?
    
    // Cached computed stats (P1: avoid recalculating on every render)
    @State private var cachedAverageScore: String = "—"
    @State private var cachedTopGenre: String = "—"
    @State private var cachedMovieTVRatio: String = "—"
    
    private var movieItems: [RankedItem] {
        rankedItems.filter { $0.mediaType == .movie }.sorted { $0.rank < $1.rank }
    }
    
    private var tvItems: [RankedItem] {
        rankedItems.filter { $0.mediaType == .tv }.sorted { $0.rank < $1.rank }
    }
    
    private var topFour: [RankedItem] {
        Array(rankedItems.sorted { $0.dateAdded > $1.dateAdded }
            .sorted { $0.rank < $1.rank }
            .prefix(4))
    }
    
    private var favoriteItems: [RankedItem] {
        rankedItems.filter { $0.isFavorite }.sorted { $0.rank < $1.rank }
    }
    
    private var memberSinceDate: Date {
        if let date = ISO8601DateFormatter().date(from: memberSinceDateString) {
            return date
        }
        let now = Date()
        memberSinceDateString = ISO8601DateFormatter().string(from: now)
        return now
    }
    
    private var memberSinceFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: memberSinceDate)
    }
    
    private func recalculateStats() {
        guard !rankedItems.isEmpty else {
            cachedAverageScore = "—"
            cachedTopGenre = "—"
            cachedMovieTVRatio = "—"
            return
        }
        
        // Average score using batch calculation
        let scores = RankedItem.calculateAllScores(for: Array(rankedItems))
        let total = scores.values.reduce(0.0, +)
        let avg = total / Double(scores.count)
        cachedAverageScore = String(format: "%.1f", avg)
        
        // Top genre
        let allGenres = rankedItems.flatMap { $0.genreNames }
        if allGenres.isEmpty {
            cachedTopGenre = "—"
        } else {
            let counts = Dictionary(grouping: allGenres, by: { $0 }).mapValues { $0.count }
            cachedTopGenre = counts.max(by: { $0.value < $1.value })?.key ?? "—"
        }
        
        // Movie/TV ratio
        let m = movieItems.count
        let t = tvItems.count
        if m + t > 0 {
            let pct = Int(round(Double(m) / Double(m + t) * 100))
            cachedMovieTVRatio = "\(pct)/\(100 - pct)"
        } else {
            cachedMovieTVRatio = "—"
        }
    }
    
    // MARK: - Streak Calculation
    
    private var currentStreak: Int {
        let dates = parsedStreakDates
        guard !dates.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var checkDate = today
        
        while dates.contains(checkDate) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return streak
    }
    
    private var parsedStreakDates: Set<Date> {
        guard !streakDatesString.isEmpty else { return [] }
        let calendar = Calendar.current
        let formatter = ISO8601DateFormatter()
        let parts = streakDatesString.split(separator: ",")
        let dates = parts.compactMap { part -> Date? in
            guard let date = formatter.date(from: String(part)) else {
                print("⚠️ Failed to parse streak date: \(part)")
                return nil
            }
            return calendar.startOfDay(for: date)
        }
        // If all parts failed to parse, the data is corrupt — reset it
        if dates.isEmpty && !parts.isEmpty {
            print("⚠️ All streak dates failed to parse, resetting streakDatesString")
            DispatchQueue.main.async { [self] in
                self.streakDatesString = ""
            }
        }
        return Set(dates)
    }
    
    private func recordTodayIfNeeded() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayHasRanking = rankedItems.contains { calendar.isDate($0.dateAdded, inSameDayAs: today) }
        guard todayHasRanking else { return }
        
        let formatter = ISO8601DateFormatter()
        let todayStr = formatter.string(from: today)
        if !streakDatesString.contains(todayStr) {
            if streakDatesString.isEmpty {
                streakDatesString = todayStr
            } else {
                streakDatesString += ",\(todayStr)"
            }
            // Trim to last 90 days
            let cutoff = calendar.date(byAdding: .day, value: -90, to: today) ?? today
            let dates = streakDatesString.split(separator: ",").filter {
                if let d = formatter.date(from: String($0)) {
                    return d >= cutoff
                }
                return false
            }
            streakDatesString = dates.joined(separator: ",")
        }
    }
    
    private func buildShareCardData() -> ShareCardData {
        ShareCardData(
            items: Array(rankedItems),
            posterImages: [:],
            movieCount: movieItems.count,
            tvCount: tvItems.count,
            tastePersonality: tastePersonality
        )
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MarquiSpacing.lg) {
                    profileHeader
                    quickStatsRow
                    
                    if currentStreak > 0 {
                        streakBadge
                    }
                    
                    topFourSection
                    
                    if !favoriteItems.isEmpty {
                        favoritesSection
                    }
                    
                    if !rankedItems.isEmpty {
                        tasteSection
                    }
                    
                    myListsSection
                    
                    VStack(spacing: MarquiSpacing.sm) {
                        statisticsCard
                        journalCard
                        activityFeedCard
                        compareCard
                    }
                    .padding(.horizontal, MarquiSpacing.md)
                    
                    if !rankedItems.isEmpty {
                        tierBreakdown
                    }
                    
                    settingsSection
                }
                .padding(.vertical, MarquiSpacing.md)
            }
            .background(MarquiColors.background)
            .navigationTitle("Profile")
            .task {
                recordTodayIfNeeded()
                recalculateStats()
                if notificationsEnabled {
                    await notificationManager.refreshAuthorizationStatus()
                    await scheduleStreakReminderIfNeeded()
                }
            }
            .onChange(of: rankedItems.count) { _, _ in
                recalculateStats()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(MarquiColors.textSecondary)
                    }
                    .disabled(rankedItems.isEmpty)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareProfileSheet(cardData: buildShareCardData())
            }
            .sheet(isPresented: $showLetterboxdImport) {
                LetterboxdImportView()
            }
            .sheet(isPresented: $showWhatsNew) {
                WhatsNewView()
            }
            .fullScreenCover(isPresented: $showCompareView) {
                NavigationStack {
                    CompareView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showCompareView = false }
                            }
                        }
                }
            }
            .alert("About Marqui", isPresented: $showAbout) {
                Button("OK", role: .cancel) { }
            } message: {
                let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                Text("Version \(version) (\(build))\n\nYour personal movie & TV ranking companion.\n\nMade with care.")
            }
            .alert("Reset All Data?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetAllData()
                }
            } message: {
                Text("This will permanently delete all your rankings, watchlist, and lists. This cannot be undone.")
            }
            .sheet(isPresented: $showExportSheet) {
                ExportOptionsSheet(
                    rankedItems: Array(rankedItems),
                    watchlistItems: Array(watchlistItems)
                )
            }
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        VStack(spacing: MarquiSpacing.sm) {
            // Avatar circle with initials
            ZStack {
                Circle()
                    .fill(MarquiColors.brandSubtle)
                    .frame(width: 72, height: 72)
                
                Text(avatarInitials)
                    .font(MarquiTypography.displayMedium)
                    .foregroundStyle(MarquiColors.brand)
            }
            
            VStack(spacing: MarquiSpacing.xxs) {
                Text(displayName.isEmpty ? "Your Profile" : displayName)
                    .font(MarquiTypography.displayMedium)
                    .foregroundStyle(MarquiColors.textPrimary)
                
                // Username will show here when social features launch
                
                HStack(spacing: MarquiSpacing.xs) {
                    Image(systemName: "calendar")
                        .font(MarquiTypography.caption)
                    Text("Member since \(memberSinceFormatted)")
                    Text("·")
                    Text("\(rankedItems.count) ranked")
                }
                .font(MarquiTypography.bodySmall)
                .foregroundStyle(MarquiColors.textSecondary)
            }
            
            // Taste archetype badge
            if !rankedItems.isEmpty {
                HStack(spacing: MarquiSpacing.xs) {
                    Image(systemName: tasteIcon)
                        .font(MarquiTypography.labelSmall)
                    Text(tastePersonality)
                        .font(MarquiTypography.labelMedium)
                }
                .foregroundStyle(MarquiColors.brand)
                .padding(.horizontal, MarquiSpacing.sm)
                .padding(.vertical, MarquiSpacing.xs)
                .background(
                    Capsule()
                        .fill(MarquiColors.brandSubtle)
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MarquiSpacing.lg)
        .padding(.horizontal, MarquiSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: MarquiRadius.lg)
                .fill(MarquiColors.surfacePrimary)
        )
        .padding(.horizontal, MarquiSpacing.md)
    }
    
    private var avatarInitials: String {
        let name = displayName.isEmpty ? "R" : displayName
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(1)).uppercased()
    }
    
    private var tasteIcon: String {
        tasteResult.archetype.icon
    }
    
    // MARK: - Quick Stats Row
    
    private var quickStatsRow: some View {
        HStack(spacing: MarquiSpacing.sm) {
            QuickStatCard(icon: "number", value: "\(rankedItems.count)", label: "Ranked")
            QuickStatCard(icon: "chart.bar", value: cachedAverageScore, label: "Avg Score")
            QuickStatCard(icon: "tag", value: cachedTopGenre, label: "Top Genre")
            QuickStatCard(icon: "film", value: cachedMovieTVRatio, label: "Film/TV")
        }
        .padding(.horizontal, MarquiSpacing.md)
    }
    
    // MARK: - Streak Badge
    
    private var streakBadge: some View {
        HStack(spacing: MarquiSpacing.xs) {
            Image(systemName: "flame.fill")
                .font(MarquiTypography.headingSmall)
                .foregroundStyle(MarquiColors.warning)
            
            Text("\(currentStreak) day streak")
                .font(MarquiTypography.labelLarge)
                .foregroundStyle(MarquiColors.textPrimary)
            
            Spacer()
            
            Text("Keep ranking!")
                .font(MarquiTypography.bodySmall)
                .foregroundStyle(MarquiColors.textTertiary)
        }
        .padding(MarquiSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: MarquiRadius.lg)
                .fill(MarquiColors.surfacePrimary)
        )
        .padding(.horizontal, MarquiSpacing.md)
    }
    
    // MARK: - Top 4 Showcase
    
    private var topFourSection: some View {
        VStack(spacing: MarquiSpacing.md) {
            HStack {
                Text("YOUR TOP 4")
                    .font(MarquiTypography.sectionLabel)
                    .tracking(1.5)
                    .foregroundStyle(MarquiColors.textTertiary)
                Spacer()
            }
            .padding(.horizontal, MarquiSpacing.md)
            
            if topFour.isEmpty {
                emptyTopFour
            } else {
                topFourGrid
                
                // Share Top 4 button
                Button {
                    showShareSheet = true
                } label: {
                    HStack(spacing: MarquiSpacing.xs) {
                        Image(systemName: "square.and.arrow.up")
                            .font(MarquiTypography.labelMedium)
                        Text("Share Top 4")
                            .font(MarquiTypography.labelMedium)
                    }
                    .foregroundStyle(MarquiColors.brand)
                    .padding(.horizontal, MarquiSpacing.md)
                    .padding(.vertical, MarquiSpacing.xs)
                    .background(
                        Capsule()
                            .fill(MarquiColors.brandSubtle)
                    )
                }
                .buttonStyle(MarquiPressStyle())
            }
        }
    }
    
    private var topFourGrid: some View {
        HStack(spacing: MarquiSpacing.sm) {
            ForEach(Array(topFour.enumerated()), id: \.element.id) { index, item in
                TopFourCard(item: item, rank: index + 1, allItems: Array(rankedItems))
            }
            
            ForEach(0..<max(0, 4 - topFour.count), id: \.self) { _ in
                emptySlot
            }
        }
        .padding(.horizontal, MarquiSpacing.md)
    }
    
    private var emptyTopFour: some View {
        HStack(spacing: MarquiSpacing.sm) {
            ForEach(0..<4, id: \.self) { _ in
                emptySlot
            }
        }
        .padding(.horizontal, MarquiSpacing.md)
    }
    
    private var emptySlot: some View {
        RoundedRectangle(cornerRadius: MarquiPoster.cornerRadius)
            .fill(MarquiColors.surfacePrimary)
            .aspectRatio(2/3, contentMode: .fit)
            .overlay {
                Image(systemName: "plus")
                    .font(MarquiTypography.headingLarge)
                    .foregroundStyle(MarquiColors.textQuaternary)
            }
    }
    
    // MARK: - Favorites Showcase
    
    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: MarquiSpacing.sm) {
            HStack {
                HStack(spacing: MarquiSpacing.xs) {
                    Image(systemName: "heart.fill")
                        .font(MarquiTypography.labelSmall)
                        .foregroundStyle(MarquiColors.tierBad)
                    Text("FAVORITES")
                        .font(MarquiTypography.sectionLabel)
                        .tracking(1.5)
                        .foregroundStyle(MarquiColors.textTertiary)
                }
                Spacer()
                Text("\(favoriteItems.count)")
                    .font(MarquiTypography.labelMedium)
                    .foregroundStyle(MarquiColors.textTertiary)
            }
            .padding(.horizontal, MarquiSpacing.md)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: MarquiSpacing.sm) {
                    ForEach(favoriteItems) { item in
                        VStack(spacing: MarquiSpacing.xs) {
                            ZStack(alignment: .topTrailing) {
                                CachedPosterImage(
                                    url: item.posterURL,
                                    width: MarquiPoster.standardWidth,
                                    height: MarquiPoster.standardHeight,
                                    placeholderIcon: item.mediaType == .movie ? "film" : "tv"
                                )
                                
                                Image(systemName: "heart.fill")
                                    .font(MarquiTypography.labelSmall)
                                    .foregroundStyle(.white)
                                    .padding(MarquiSpacing.xs)
                                    .background(
                                        Circle()
                                            .fill(MarquiColors.tierBad.opacity(0.85))
                                    )
                                    .padding(MarquiSpacing.xs)
                            }
                            
                            Text(item.title)
                                .font(MarquiTypography.labelSmall)
                                .foregroundStyle(MarquiColors.textPrimary)
                                .lineLimit(1)
                        }
                        .frame(width: MarquiPoster.standardWidth)
                    }
                }
                .padding(.horizontal, MarquiSpacing.md)
            }
        }
    }
    
    // MARK: - Taste Personality
    
    private var tasteSection: some View {
        VStack(alignment: .leading, spacing: MarquiSpacing.xs) {
            Text("Taste Profile")
                .font(MarquiTypography.labelMedium)
                .foregroundStyle(MarquiColors.textTertiary)
            
            Text(tastePersonality)
                .font(MarquiTypography.headingMedium)
                .foregroundStyle(MarquiColors.brand)
            
            Text(tasteDescription)
                .font(MarquiTypography.bodySmall)
                .foregroundStyle(MarquiColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MarquiSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: MarquiRadius.lg)
                .fill(MarquiColors.surfacePrimary)
        )
        .padding(.horizontal, MarquiSpacing.md)
    }
    
    private var tasteResult: TastePersonality.Result {
        TastePersonality.analyze(items: Array(rankedItems))
    }
    
    private var tastePersonality: String {
        tasteResult.archetype.rawValue
    }
    
    private var tasteDescription: String {
        tasteResult.archetype.description
    }
    
    // MARK: - Navigation Cards
    
    private var statisticsCard: some View {
        NavigationLink {
            StatsView()
        } label: {
            ProfileNavCard(
                icon: "chart.bar.xaxis",
                title: "Statistics",
                subtitle: "See your watching patterns, genres, and insights"
            )
        }
        .buttonStyle(MarquiPressStyle())
    }
    
    private var journalCard: some View {
        NavigationLink {
            JournalView()
        } label: {
            ProfileNavCard(
                icon: "book.closed.fill",
                title: "Watch Journal",
                subtitle: "Your ranking diary — \(rankedItems.count) \(rankedItems.count == 1 ? "entry" : "entries")"
            )
        }
        .buttonStyle(MarquiPressStyle())
    }
    
    // MARK: - My Lists Section
    
    private var myListsSection: some View {
        VStack(alignment: .leading, spacing: MarquiSpacing.sm) {
            HStack {
                Text("MY LISTS")
                    .font(MarquiTypography.sectionLabel)
                    .tracking(1.5)
                    .foregroundStyle(MarquiColors.textTertiary)
                Spacer()
                NavigationLink {
                    ListsView()
                } label: {
                    HStack(spacing: MarquiSpacing.xxs) {
                        Text(customLists.isEmpty ? "Create" : "See All")
                            .font(MarquiTypography.labelMedium)
                            .foregroundStyle(MarquiColors.brand)
                        Image(systemName: "chevron.right")
                            .font(MarquiTypography.caption)
                            .foregroundStyle(MarquiColors.brand)
                    }
                }
            }
            .padding(.horizontal, MarquiSpacing.md)
            
            if customLists.isEmpty {
                myListsEmptyState
            } else {
                myListsScrollCards
            }
        }
    }
    
    private var myListsEmptyState: some View {
        VStack(spacing: MarquiSpacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: MarquiSpacing.sm) {
                    Button {
                        suggestedListToCreate = nil
                        showCreateListSheet = true
                    } label: {
                        VStack(spacing: MarquiSpacing.sm) {
                            ZStack {
                                RoundedRectangle(cornerRadius: MarquiRadius.md)
                                    .fill(MarquiColors.brandSubtle)
                                    .frame(width: 60, height: 60)
                                Image(systemName: "plus")
                                    .font(MarquiTypography.headingLarge)
                                    .foregroundStyle(MarquiColors.brand)
                            }
                            Text("Blank List")
                                .font(MarquiTypography.labelMedium)
                                .foregroundStyle(MarquiColors.textPrimary)
                            Text("Start fresh")
                                .font(MarquiTypography.caption)
                                .foregroundStyle(MarquiColors.textTertiary)
                        }
                        .frame(width: 120)
                        .padding(MarquiSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: MarquiRadius.lg)
                                .fill(MarquiColors.surfacePrimary)
                        )
                    }
                    .buttonStyle(MarquiPressStyle())
                    
                    ForEach(Array(SuggestedList.allSuggestions.prefix(4))) { suggestion in
                        Button {
                            suggestedListToCreate = suggestion
                            showCreateListSheet = true
                        } label: {
                            VStack(spacing: MarquiSpacing.sm) {
                                Text(suggestion.emoji)
                                    .font(.system(size: 32))
                                    .frame(width: 60, height: 60)
                                    .background(
                                        Circle()
                                            .fill(MarquiColors.surfaceSecondary)
                                    )
                                Text(suggestion.name)
                                    .font(MarquiTypography.labelMedium)
                                    .foregroundStyle(MarquiColors.textPrimary)
                                    .lineLimit(1)
                                Text(suggestion.description)
                                    .font(MarquiTypography.caption)
                                    .foregroundStyle(MarquiColors.textTertiary)
                                    .lineLimit(1)
                            }
                            .frame(width: 120)
                            .padding(MarquiSpacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: MarquiRadius.lg)
                                    .fill(MarquiColors.surfacePrimary)
                            )
                        }
                        .buttonStyle(MarquiPressStyle())
                    }
                }
                .padding(.horizontal, MarquiSpacing.md)
            }
        }
        .sheet(isPresented: $showCreateListSheet) {
            CreateListView(suggested: suggestedListToCreate)
        }
    }
    
    private var myListsScrollCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MarquiSpacing.sm) {
                ForEach(customLists) { list in
                    NavigationLink(destination: ListDetailView(list: list)) {
                        ListPreviewCard(list: list)
                    }
                    .buttonStyle(MarquiPressStyle())
                }
                
                Button {
                    suggestedListToCreate = nil
                    showCreateListSheet = true
                } label: {
                    VStack(spacing: MarquiSpacing.sm) {
                        ZStack {
                            RoundedRectangle(cornerRadius: MarquiRadius.md)
                                .fill(MarquiColors.brandSubtle)
                                .frame(width: 48, height: 48)
                            Image(systemName: "plus")
                                .font(MarquiTypography.headingMedium)
                                .foregroundStyle(MarquiColors.brand)
                        }
                        Text("New List")
                            .font(MarquiTypography.labelMedium)
                            .foregroundStyle(MarquiColors.brand)
                    }
                    .frame(width: 100, height: 160)
                    .background(
                        RoundedRectangle(cornerRadius: MarquiRadius.lg)
                            .fill(MarquiColors.surfacePrimary)
                    )
                }
                .buttonStyle(MarquiPressStyle())
            }
            .padding(.horizontal, MarquiSpacing.md)
        }
        .sheet(isPresented: $showCreateListSheet) {
            CreateListView(suggested: suggestedListToCreate)
        }
    }
    
    private var activityFeedCard: some View {
        NavigationLink {
            ActivityFeedView()
        } label: {
            ProfileNavCard(
                icon: "clock.arrow.circlepath",
                title: "Activity",
                subtitle: "Your recent ranking activity"
            )
        }
        .buttonStyle(MarquiPressStyle())
    }
    
    private var compareCard: some View {
        Button {
            showCompareView = true
        } label: {
            ProfileNavCard(
                icon: "arrow.left.arrow.right.circle.fill",
                title: "Compare",
                subtitle: "Refine your rankings with head-to-head picks"
            )
        }
        .buttonStyle(MarquiPressStyle())
    }
    
    // MARK: - Settings Section
    
    private var settingsSection: some View {
        VStack(spacing: MarquiSpacing.sm) {
            HStack {
                Text("SETTINGS")
                    .font(MarquiTypography.sectionLabel)
                    .tracking(1.5)
                    .foregroundStyle(MarquiColors.textTertiary)
                Spacer()
            }
            .padding(.horizontal, MarquiSpacing.md)
            
            VStack(spacing: 1) {
                // Name
                settingsRow(
                    icon: "person.fill",
                    title: "Name",
                    subtitle: displayName.isEmpty ? "Set your name" : displayName,
                    destination: AnyView(displayNameEditor)
                )
                
                // Notifications toggle
                notificationToggleRow
                
                // Export Data
                Button {
                    showExportSheet = true
                } label: {
                    settingsRowContent(
                        icon: "square.and.arrow.up.fill",
                        title: "Export Data",
                        subtitle: "Save your rankings & watchlist as CSV or JSON"
                    )
                }
                .buttonStyle(MarquiPressStyle())
                
                // Import from Letterboxd
                Button {
                    showLetterboxdImport = true
                } label: {
                    settingsRowContent(
                        icon: "square.and.arrow.down.fill",
                        title: "Import from Letterboxd",
                        subtitle: "Bring in your ratings and watched films"
                    )
                }
                .buttonStyle(MarquiPressStyle())
                
                // What's New
                Button {
                    showWhatsNew = true
                } label: {
                    settingsRowContent(
                        icon: "sparkles",
                        title: "What's New",
                        subtitle: "See the latest features"
                    )
                }
                .buttonStyle(MarquiPressStyle())
                
                // About
                Button {
                    showAbout = true
                } label: {
                    settingsRowContent(
                        icon: "info.circle.fill",
                        title: "About Marqui",
                        subtitle: "Version & credits"
                    )
                }
                .buttonStyle(MarquiPressStyle())
                
                // Reset
                Button {
                    showResetConfirmation = true
                } label: {
                    HStack(spacing: MarquiSpacing.sm) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(MarquiTypography.headingSmall)
                            .foregroundStyle(MarquiColors.error)
                            .frame(width: 32)
                        
                        VStack(alignment: .leading, spacing: MarquiSpacing.xxs) {
                            Text("Reset Data")
                                .font(MarquiTypography.headingSmall)
                                .foregroundStyle(MarquiColors.error)
                            Text("Delete all rankings, watchlist, and lists")
                                .font(MarquiTypography.bodySmall)
                                .foregroundStyle(MarquiColors.textTertiary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(MarquiTypography.caption)
                            .foregroundStyle(MarquiColors.textQuaternary)
                    }
                    .padding(MarquiSpacing.md)
                    .background(MarquiColors.surfacePrimary)
                }
                .buttonStyle(MarquiPressStyle())
            }
            .clipShape(RoundedRectangle(cornerRadius: MarquiRadius.lg))
            .padding(.horizontal, MarquiSpacing.md)
        }
    }
    
    private func settingsRow(icon: String, title: String, subtitle: String, destination: AnyView) -> some View {
        NavigationLink {
            destination
        } label: {
            settingsRowContent(icon: icon, title: title, subtitle: subtitle)
        }
        .buttonStyle(MarquiPressStyle())
    }
    
    private func settingsRowContent(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: MarquiSpacing.sm) {
            Image(systemName: icon)
                .font(MarquiTypography.headingSmall)
                .foregroundStyle(MarquiColors.textSecondary)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: MarquiSpacing.xxs) {
                Text(title)
                    .font(MarquiTypography.headingSmall)
                    .foregroundStyle(MarquiColors.textPrimary)
                Text(subtitle)
                    .font(MarquiTypography.bodySmall)
                    .foregroundStyle(MarquiColors.textTertiary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(MarquiTypography.caption)
                .foregroundStyle(MarquiColors.textQuaternary)
        }
        .padding(MarquiSpacing.md)
        .background(MarquiColors.surfacePrimary)
    }
    
    private var displayNameEditor: some View {
        Form {
            Section {
                TextField("Name", text: $displayName)
                    .font(MarquiTypography.bodyLarge)
            } header: {
                Text("Your name appears at the top of your profile.")
            }
        }
        .navigationTitle("Name")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Notification Toggle
    
    private var notificationToggleRow: some View {
        HStack(spacing: MarquiSpacing.sm) {
            Image(systemName: "bell.fill")
                .font(MarquiTypography.headingSmall)
                .foregroundStyle(MarquiColors.textSecondary)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: MarquiSpacing.xxs) {
                Text("Notifications")
                    .font(MarquiTypography.headingSmall)
                    .foregroundStyle(MarquiColors.textPrimary)
                Text(notificationsEnabled ? "Reminders & streaks" : "Off")
                    .font(MarquiTypography.bodySmall)
                    .foregroundStyle(MarquiColors.textTertiary)
            }
            
            Spacer()
            
            Toggle("", isOn: $notificationsEnabled)
                .labelsHidden()
                .tint(MarquiColors.brand)
        }
        .padding(MarquiSpacing.md)
        .background(MarquiColors.surfacePrimary)
        .onChange(of: notificationsEnabled) { _, enabled in
            Task {
                if enabled {
                    let granted = await notificationManager.requestPermission()
                    if !granted {
                        notificationsEnabled = false
                        if notificationManager.isDenied {
                            showNotificationSettingsAlert = true
                        }
                    } else {
                        // Schedule streak reminder now
                        await scheduleStreakReminderIfNeeded()
                    }
                } else {
                    notificationManager.cancelAllNotifications()
                }
            }
        }
        .alert("Notifications Disabled", isPresented: $showNotificationSettingsAlert) {
            Button("Go to Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Notifications are turned off for Marqui. Enable them in Settings to receive streak reminders and updates.")
        }
    }
    
    private func scheduleStreakReminderIfNeeded() async {
        let streak = currentStreak
        guard streak > 0, notificationsEnabled else { return }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let rankedToday = rankedItems.contains { calendar.isDate($0.dateAdded, inSameDayAs: today) }
        
        await notificationManager.scheduleStreakReminder(streak: streak, rankedToday: rankedToday)
    }
    
    private func resetAllData() {
        for item in rankedItems { modelContext.delete(item) }
        for item in watchlistItems { modelContext.delete(item) }
        for list in customLists { modelContext.delete(list) }
        streakDatesString = ""
        // Clear widget data
        WidgetDataManager.updateSharedData(items: [])
        HapticManager.notification(.success)
    }
    
    // MARK: - Tier Breakdown
    
    private var tierBreakdown: some View {
        VStack(spacing: MarquiSpacing.sm) {
            HStack {
                Text("TIER BREAKDOWN")
                    .font(MarquiTypography.sectionLabel)
                    .tracking(1.5)
                    .foregroundStyle(MarquiColors.textTertiary)
                Spacer()
            }
            
            ForEach(Tier.allCases, id: \.self) { tier in
                let count = rankedItems.filter { $0.tier == tier }.count
                let fraction = rankedItems.isEmpty ? 0.0 : Double(count) / Double(rankedItems.count)
                
                TierBar(tier: tier, count: count, fraction: fraction)
            }
        }
        .padding(MarquiSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: MarquiRadius.lg)
                .fill(MarquiColors.surfacePrimary)
        )
        .padding(.horizontal, MarquiSpacing.md)
    }
}

// MARK: - Quick Stat Card

private struct QuickStatCard: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: MarquiSpacing.xxs) {
            Image(systemName: icon)
                .font(MarquiTypography.labelSmall)
                .foregroundStyle(MarquiColors.textTertiary)
            
            Text(value)
                .font(MarquiTypography.headingMedium)
                .foregroundStyle(MarquiColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(label)
                .font(MarquiTypography.caption)
                .foregroundStyle(MarquiColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MarquiSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: MarquiRadius.md)
                .fill(MarquiColors.surfacePrimary)
        )
    }
}

// MARK: - List Preview Card

struct ListPreviewCard: View {
    let list: CustomList
    
    private var previewItems: [CustomListItem] {
        Array(list.sortedItems.prefix(4))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: MarquiSpacing.sm) {
            posterCollage
            
            VStack(alignment: .leading, spacing: MarquiSpacing.xxs) {
                HStack(spacing: MarquiSpacing.xxs) {
                    Text(list.emoji)
                        .font(MarquiTypography.bodyMedium)
                    Text(list.name)
                        .font(MarquiTypography.headingSmall)
                        .foregroundStyle(MarquiColors.textPrimary)
                        .lineLimit(1)
                }
                
                Text("\(list.itemCount) item\(list.itemCount == 1 ? "" : "s")")
                    .font(MarquiTypography.caption)
                    .foregroundStyle(MarquiColors.textTertiary)
            }
            .padding(.horizontal, MarquiSpacing.xs)
            .padding(.bottom, MarquiSpacing.xs)
        }
        .frame(width: 160)
        .background(
            RoundedRectangle(cornerRadius: MarquiRadius.lg)
                .fill(MarquiColors.surfacePrimary)
        )
    }
    
    private var posterCollage: some View {
        let size: CGFloat = 160
        let items = previewItems
        
        return ZStack {
            RoundedRectangle(cornerRadius: MarquiRadius.md)
                .fill(MarquiColors.surfaceSecondary)
            
            if items.isEmpty {
                Image(systemName: "film.stack")
                    .font(MarquiTypography.headingLarge)
                    .foregroundStyle(MarquiColors.textQuaternary)
            } else if items.count == 1 {
                posterImage(for: items[0])
            } else {
                let cellSize = (size - 2) / 2
                VStack(spacing: 1) {
                    HStack(spacing: 1) {
                        posterImage(for: items[0])
                            .frame(width: cellSize, height: cellSize)
                            .clipped()
                        if items.count > 1 {
                            posterImage(for: items[1])
                                .frame(width: cellSize, height: cellSize)
                                .clipped()
                        } else {
                            Rectangle().fill(MarquiColors.surfaceTertiary)
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                    HStack(spacing: 1) {
                        if items.count > 2 {
                            posterImage(for: items[2])
                                .frame(width: cellSize, height: cellSize)
                                .clipped()
                        } else {
                            Rectangle().fill(MarquiColors.surfaceTertiary)
                                .frame(width: cellSize, height: cellSize)
                        }
                        if items.count > 3 {
                            posterImage(for: items[3])
                                .frame(width: cellSize, height: cellSize)
                                .clipped()
                        } else {
                            Rectangle().fill(MarquiColors.surfaceTertiary)
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
        .frame(width: size, height: size * 0.65)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: MarquiRadius.lg,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: MarquiRadius.lg
            )
        )
    }
    
    @ViewBuilder
    private func posterImage(for item: CustomListItem) -> some View {
        if let url = item.posterURL {
            CachedAsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(MarquiColors.surfaceTertiary)
            }
        } else {
            Rectangle().fill(MarquiColors.surfaceTertiary)
        }
    }
}

// MARK: - Profile Nav Card

private struct ProfileNavCard: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: MarquiSpacing.sm) {
            Image(systemName: icon)
                .font(MarquiTypography.headingLarge)
                .foregroundStyle(MarquiColors.textSecondary)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: MarquiSpacing.xxs) {
                Text(title)
                    .font(MarquiTypography.headingSmall)
                    .foregroundStyle(MarquiColors.textPrimary)
                Text(subtitle)
                    .font(MarquiTypography.bodySmall)
                    .foregroundStyle(MarquiColors.textTertiary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(MarquiTypography.caption)
                .foregroundStyle(MarquiColors.textQuaternary)
        }
        .padding(MarquiSpacing.md)
        .frame(minHeight: 48)
        .background(
            RoundedRectangle(cornerRadius: MarquiRadius.lg)
                .fill(MarquiColors.surfacePrimary)
        )
    }
}

// MARK: - Top Four Card

private struct TopFourCard: View {
    let item: RankedItem
    let rank: Int
    var allItems: [RankedItem] = []
    
    private var score: Double {
        RankedItem.calculateScore(for: item, allItems: allItems)
    }
    
    var body: some View {
        VStack(spacing: MarquiSpacing.xs) {
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(url: item.posterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: MarquiPoster.cornerRadius)
                        .fill(MarquiColors.surfacePrimary)
                        .overlay {
                            Image(systemName: item.mediaType == .movie ? "film" : "tv")
                                .font(MarquiTypography.headingLarge)
                                .foregroundStyle(MarquiColors.textQuaternary)
                        }
                }
                .aspectRatio(2/3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: MarquiPoster.cornerRadius))
                .overlay(alignment: .bottomTrailing) {
                    // Score badge overlay
                    if !allItems.isEmpty {
                        Text(String(format: "%.1f", score))
                            .font(MarquiTypography.labelSmall)
                            .foregroundStyle(.white)
                            .padding(.horizontal, MarquiSpacing.xs)
                            .padding(.vertical, MarquiSpacing.xxs)
                            .background(
                                Capsule()
                                    .fill(MarquiColors.tierColor(item.tier))
                            )
                            .padding(MarquiSpacing.xs)
                    }
                }
                
                // Rank number overlay
                Text("\(rank)")
                    .font(MarquiTypography.displayMedium)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                    .padding(.leading, MarquiSpacing.xs)
                    .padding(.top, MarquiSpacing.xs)
            }
            
            Text(item.title)
                .font(MarquiTypography.labelSmall)
                .foregroundStyle(MarquiColors.textPrimary)
                .lineLimit(1)
        }
    }
}

// StatCard removed — replaced by QuickStatCard

// MARK: - Tier Bar

private struct TierBar: View {
    let tier: Tier
    let count: Int
    let fraction: Double
    
    var body: some View {
        HStack(spacing: MarquiSpacing.sm) {
            Circle()
                .fill(MarquiColors.tierColor(tier))
                .frame(width: 8, height: 8)
            
            Text(tier.rawValue)
                .font(MarquiTypography.bodySmall)
                .foregroundStyle(MarquiColors.textSecondary)
                .frame(width: 64, alignment: .leading)
            
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: MarquiRadius.sm)
                    .fill(MarquiColors.tierColor(tier).opacity(0.4))
                    .frame(width: max(4, geo.size.width * fraction))
                    .animation(MarquiMotion.reveal, value: fraction)
            }
            .frame(height: 20)
            
            Text("\(count)")
                .font(MarquiTypography.labelMedium)
                .foregroundStyle(MarquiColors.textSecondary)
                .frame(width: 32, alignment: .trailing)
        }
    }
}

// MARK: - Export Options Sheet

private struct ExportOptionsSheet: View {
    let rankedItems: [RankedItem]
    let watchlistItems: [WatchlistItem]
    
    @Environment(\.dismiss) private var dismiss
    @State private var exportFileURL: URL?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: MarquiSpacing.md) {
                VStack(spacing: MarquiSpacing.xs) {
                    Image(systemName: "square.and.arrow.up")
                        .font(MarquiTypography.displayMedium)
                        .foregroundStyle(MarquiColors.brand)
                    
                    Text("Export Data")
                        .font(MarquiTypography.headingLarge)
                        .foregroundStyle(MarquiColors.textPrimary)
                    
                    Text("Save your data to share or back up")
                        .font(MarquiTypography.bodySmall)
                        .foregroundStyle(MarquiColors.textTertiary)
                }
                .padding(.top, MarquiSpacing.lg)
                
                VStack(spacing: 1) {
                    exportOptionRow(
                        icon: "list.number",
                        title: "Export Rankings",
                        subtitle: "\(rankedItems.count) items · CSV",
                        disabled: rankedItems.isEmpty
                    ) {
                        exportFileURL = ExportService.exportRankingsCSV(items: rankedItems)
                    }
                    
                    exportOptionRow(
                        icon: "bookmark",
                        title: "Export Watchlist",
                        subtitle: "\(watchlistItems.count) items · CSV",
                        disabled: watchlistItems.isEmpty
                    ) {
                        exportFileURL = ExportService.exportWatchlistCSV(items: watchlistItems)
                    }
                    
                    exportOptionRow(
                        icon: "doc.text",
                        title: "Export Everything",
                        subtitle: "\(rankedItems.count + watchlistItems.count) items · JSON",
                        disabled: rankedItems.isEmpty && watchlistItems.isEmpty
                    ) {
                        exportFileURL = ExportService.exportAllJSON(ranked: rankedItems, watchlist: watchlistItems)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: MarquiRadius.lg))
                .padding(.horizontal, MarquiSpacing.md)
                
                Spacer()
            }
            .background(MarquiColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(MarquiColors.brand)
                }
            }
            .onChange(of: exportFileURL) { _, newURL in
                // Trigger share sheet via UIKit since URL isn't Identifiable
                if let url = newURL {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootVC = windowScene.windows.first?.rootViewController {
                            var topVC = rootVC
                            while let presented = topVC.presentedViewController {
                                topVC = presented
                            }
                            activityVC.popoverPresentationController?.sourceView = topVC.view
                            topVC.present(activityVC, animated: true)
                        }
                        exportFileURL = nil
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func exportOptionRow(
        icon: String,
        title: String,
        subtitle: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: MarquiSpacing.sm) {
                Image(systemName: icon)
                    .font(MarquiTypography.headingSmall)
                    .foregroundStyle(disabled ? MarquiColors.textQuaternary : MarquiColors.brand)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: MarquiSpacing.xxs) {
                    Text(title)
                        .font(MarquiTypography.headingSmall)
                        .foregroundStyle(disabled ? MarquiColors.textTertiary : MarquiColors.textPrimary)
                    Text(subtitle)
                        .font(MarquiTypography.bodySmall)
                        .foregroundStyle(MarquiColors.textTertiary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(MarquiTypography.caption)
                    .foregroundStyle(MarquiColors.textQuaternary)
            }
            .padding(MarquiSpacing.md)
            .background(MarquiColors.surfacePrimary)
        }
        .buttonStyle(MarquiPressStyle())
        .disabled(disabled)
    }
}

// MARK: - Share Sheet (UIActivityViewController)

#Preview {
    ProfileView()
        .modelContainer(for: [RankedItem.self, WatchlistItem.self, CustomList.self, CustomListItem.self], inMemory: true)
}
