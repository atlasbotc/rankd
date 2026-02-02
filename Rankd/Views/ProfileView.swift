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
    
    private var averageScore: String {
        guard !rankedItems.isEmpty else { return "—" }
        let total = rankedItems.reduce(0.0) { sum, item in
            sum + RankedItem.calculateScore(for: item, allItems: Array(rankedItems))
        }
        let avg = total / Double(rankedItems.count)
        return String(format: "%.1f", avg)
    }
    
    private var topGenre: String {
        let allGenres = rankedItems.flatMap { $0.genreNames }
        guard !allGenres.isEmpty else { return "—" }
        let counts = Dictionary(grouping: allGenres, by: { $0 }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key ?? "—"
    }
    
    private var movieTVRatio: String {
        let m = movieItems.count
        let t = tvItems.count
        guard m + t > 0 else { return "—" }
        let pct = Int(round(Double(m) / Double(m + t) * 100))
        return "\(pct)/\(100 - pct)"
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
                VStack(spacing: RankdSpacing.lg) {
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
                    
                    VStack(spacing: RankdSpacing.sm) {
                        statisticsCard
                        journalCard
                        activityFeedCard
                        compareCard
                    }
                    .padding(.horizontal, RankdSpacing.md)
                    
                    if !rankedItems.isEmpty {
                        tierBreakdown
                    }
                    
                    settingsSection
                }
                .padding(.vertical, RankdSpacing.md)
            }
            .background(RankdColors.background)
            .navigationTitle("Profile")
            .task {
                recordTodayIfNeeded()
                if notificationsEnabled {
                    await notificationManager.refreshAuthorizationStatus()
                    await scheduleStreakReminderIfNeeded()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(RankdColors.textSecondary)
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
        VStack(spacing: RankdSpacing.sm) {
            // Avatar circle with initials
            ZStack {
                Circle()
                    .fill(RankdColors.brandSubtle)
                    .frame(width: 72, height: 72)
                
                Text(avatarInitials)
                    .font(RankdTypography.displayMedium)
                    .foregroundStyle(RankdColors.brand)
            }
            
            VStack(spacing: RankdSpacing.xxs) {
                Text(displayName.isEmpty ? "Your Profile" : displayName)
                    .font(RankdTypography.displayMedium)
                    .foregroundStyle(RankdColors.textPrimary)
                
                // Username will show here when social features launch
                
                HStack(spacing: RankdSpacing.xs) {
                    Image(systemName: "calendar")
                        .font(RankdTypography.caption)
                    Text("Member since \(memberSinceFormatted)")
                    Text("·")
                    Text("\(rankedItems.count) ranked")
                }
                .font(RankdTypography.bodySmall)
                .foregroundStyle(RankdColors.textSecondary)
            }
            
            // Taste archetype badge
            if !rankedItems.isEmpty {
                HStack(spacing: RankdSpacing.xs) {
                    Image(systemName: tasteIcon)
                        .font(RankdTypography.labelSmall)
                    Text(tastePersonality)
                        .font(RankdTypography.labelMedium)
                }
                .foregroundStyle(RankdColors.brand)
                .padding(.horizontal, RankdSpacing.sm)
                .padding(.vertical, RankdSpacing.xs)
                .background(
                    Capsule()
                        .fill(RankdColors.brandSubtle)
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, RankdSpacing.lg)
        .padding(.horizontal, RankdSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: RankdRadius.lg)
                .fill(RankdColors.surfacePrimary)
        )
        .padding(.horizontal, RankdSpacing.md)
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
        switch tastePersonality {
        case "Film Purist": return "film"
        case "Binge Watcher": return "play.rectangle.on.rectangle"
        case "Movie Buff": return "popcorn"
        case "Series Devotee": return "tv"
        case "The Optimist": return "hand.thumbsup"
        case "Tough Critic": return "eye"
        case "Getting Started": return "sparkles"
        default: return "star"
        }
    }
    
    // MARK: - Quick Stats Row
    
    private var quickStatsRow: some View {
        HStack(spacing: RankdSpacing.sm) {
            QuickStatCard(icon: "number", value: "\(rankedItems.count)", label: "Ranked")
            QuickStatCard(icon: "chart.bar", value: averageScore, label: "Avg Score")
            QuickStatCard(icon: "tag", value: topGenre, label: "Top Genre")
            QuickStatCard(icon: "film", value: movieTVRatio, label: "Film/TV")
        }
        .padding(.horizontal, RankdSpacing.md)
    }
    
    // MARK: - Streak Badge
    
    private var streakBadge: some View {
        HStack(spacing: RankdSpacing.xs) {
            Image(systemName: "flame.fill")
                .font(RankdTypography.headingSmall)
                .foregroundStyle(RankdColors.warning)
            
            Text("\(currentStreak) day streak")
                .font(RankdTypography.labelLarge)
                .foregroundStyle(RankdColors.textPrimary)
            
            Spacer()
            
            Text("Keep ranking!")
                .font(RankdTypography.bodySmall)
                .foregroundStyle(RankdColors.textTertiary)
        }
        .padding(RankdSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: RankdRadius.lg)
                .fill(RankdColors.surfacePrimary)
        )
        .padding(.horizontal, RankdSpacing.md)
    }
    
    // MARK: - Top 4 Showcase
    
    private var topFourSection: some View {
        VStack(spacing: RankdSpacing.md) {
            HStack {
                Text("YOUR TOP 4")
                    .font(RankdTypography.sectionLabel)
                    .tracking(1.5)
                    .foregroundStyle(RankdColors.textTertiary)
                Spacer()
            }
            .padding(.horizontal, RankdSpacing.md)
            
            if topFour.isEmpty {
                emptyTopFour
            } else {
                topFourGrid
                
                // Share Top 4 button
                Button {
                    showShareSheet = true
                } label: {
                    HStack(spacing: RankdSpacing.xs) {
                        Image(systemName: "square.and.arrow.up")
                            .font(RankdTypography.labelMedium)
                        Text("Share Top 4")
                            .font(RankdTypography.labelMedium)
                    }
                    .foregroundStyle(RankdColors.brand)
                    .padding(.horizontal, RankdSpacing.md)
                    .padding(.vertical, RankdSpacing.xs)
                    .background(
                        Capsule()
                            .fill(RankdColors.brandSubtle)
                    )
                }
                .buttonStyle(RankdPressStyle())
            }
        }
    }
    
    private var topFourGrid: some View {
        HStack(spacing: RankdSpacing.sm) {
            ForEach(Array(topFour.enumerated()), id: \.element.id) { index, item in
                TopFourCard(item: item, rank: index + 1, allItems: Array(rankedItems))
            }
            
            ForEach(0..<max(0, 4 - topFour.count), id: \.self) { _ in
                emptySlot
            }
        }
        .padding(.horizontal, RankdSpacing.md)
    }
    
    private var emptyTopFour: some View {
        HStack(spacing: RankdSpacing.sm) {
            ForEach(0..<4, id: \.self) { _ in
                emptySlot
            }
        }
        .padding(.horizontal, RankdSpacing.md)
    }
    
    private var emptySlot: some View {
        RoundedRectangle(cornerRadius: RankdPoster.cornerRadius)
            .fill(RankdColors.surfacePrimary)
            .aspectRatio(2/3, contentMode: .fit)
            .overlay {
                Image(systemName: "plus")
                    .font(RankdTypography.headingLarge)
                    .foregroundStyle(RankdColors.textQuaternary)
            }
    }
    
    // MARK: - Favorites Showcase
    
    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: RankdSpacing.sm) {
            HStack {
                HStack(spacing: RankdSpacing.xs) {
                    Image(systemName: "heart.fill")
                        .font(RankdTypography.labelSmall)
                        .foregroundStyle(RankdColors.tierBad)
                    Text("FAVORITES")
                        .font(RankdTypography.sectionLabel)
                        .tracking(1.5)
                        .foregroundStyle(RankdColors.textTertiary)
                }
                Spacer()
                Text("\(favoriteItems.count)")
                    .font(RankdTypography.labelMedium)
                    .foregroundStyle(RankdColors.textTertiary)
            }
            .padding(.horizontal, RankdSpacing.md)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: RankdSpacing.sm) {
                    ForEach(favoriteItems) { item in
                        VStack(spacing: RankdSpacing.xs) {
                            ZStack(alignment: .topTrailing) {
                                CachedPosterImage(
                                    url: item.posterURL,
                                    width: RankdPoster.standardWidth,
                                    height: RankdPoster.standardHeight,
                                    placeholderIcon: item.mediaType == .movie ? "film" : "tv"
                                )
                                
                                Image(systemName: "heart.fill")
                                    .font(RankdTypography.labelSmall)
                                    .foregroundStyle(.white)
                                    .padding(RankdSpacing.xs)
                                    .background(
                                        Circle()
                                            .fill(RankdColors.tierBad.opacity(0.85))
                                    )
                                    .padding(RankdSpacing.xs)
                            }
                            
                            Text(item.title)
                                .font(RankdTypography.labelSmall)
                                .foregroundStyle(RankdColors.textPrimary)
                                .lineLimit(1)
                        }
                        .frame(width: RankdPoster.standardWidth)
                    }
                }
                .padding(.horizontal, RankdSpacing.md)
            }
        }
    }
    
    // MARK: - Taste Personality
    
    private var tasteSection: some View {
        VStack(alignment: .leading, spacing: RankdSpacing.xs) {
            Text("Taste Profile")
                .font(RankdTypography.labelMedium)
                .foregroundStyle(RankdColors.textTertiary)
            
            Text(tastePersonality)
                .font(RankdTypography.headingMedium)
                .foregroundStyle(RankdColors.brand)
            
            Text(tasteDescription)
                .font(RankdTypography.bodySmall)
                .foregroundStyle(RankdColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RankdSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: RankdRadius.lg)
                .fill(RankdColors.surfacePrimary)
        )
        .padding(.horizontal, RankdSpacing.md)
    }
    
    private var tastePersonality: String {
        let total = rankedItems.count
        let movies = movieItems.count
        let tv = tvItems.count
        
        if total < 5 { return "Getting Started" }
        
        if movies > 0 && tv == 0 { return "Film Purist" }
        if tv > 0 && movies == 0 { return "Binge Watcher" }
        if Double(movies) / Double(total) > 0.75 { return "Movie Buff" }
        if Double(tv) / Double(total) > 0.75 { return "Series Devotee" }
        
        let goodCount = rankedItems.filter { $0.tier == .good }.count
        let badCount = rankedItems.filter { $0.tier == .bad }.count
        
        if Double(goodCount) / Double(total) > 0.7 { return "The Optimist" }
        if Double(badCount) / Double(total) > 0.4 { return "Tough Critic" }
        
        return "Well-Rounded Viewer"
    }
    
    private var tasteDescription: String {
        switch tastePersonality {
        case "Getting Started":
            return "Rank more titles to unlock your taste profile."
        case "Film Purist":
            return "You're all about the big screen. Cinema is your thing."
        case "Binge Watcher":
            return "Episodes over end credits. You love a good series."
        case "Movie Buff":
            return "Mostly movies with the occasional show. Classic taste."
        case "Series Devotee":
            return "You prefer the long game. Character development is key."
        case "The Optimist":
            return "You tend to love what you watch. Glass half full."
        case "Tough Critic":
            return "High standards. Not everything makes the cut."
        default:
            return "A healthy mix of movies and TV. You appreciate it all."
        }
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
        .buttonStyle(RankdPressStyle())
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
        .buttonStyle(RankdPressStyle())
    }
    
    // MARK: - My Lists Section
    
    private var myListsSection: some View {
        VStack(alignment: .leading, spacing: RankdSpacing.sm) {
            HStack {
                Text("MY LISTS")
                    .font(RankdTypography.sectionLabel)
                    .tracking(1.5)
                    .foregroundStyle(RankdColors.textTertiary)
                Spacer()
                NavigationLink {
                    ListsView()
                } label: {
                    HStack(spacing: RankdSpacing.xxs) {
                        Text(customLists.isEmpty ? "Create" : "See All")
                            .font(RankdTypography.labelMedium)
                            .foregroundStyle(RankdColors.brand)
                        Image(systemName: "chevron.right")
                            .font(RankdTypography.caption)
                            .foregroundStyle(RankdColors.brand)
                    }
                }
            }
            .padding(.horizontal, RankdSpacing.md)
            
            if customLists.isEmpty {
                myListsEmptyState
            } else {
                myListsScrollCards
            }
        }
    }
    
    private var myListsEmptyState: some View {
        VStack(spacing: RankdSpacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: RankdSpacing.sm) {
                    Button {
                        suggestedListToCreate = nil
                        showCreateListSheet = true
                    } label: {
                        VStack(spacing: RankdSpacing.sm) {
                            ZStack {
                                RoundedRectangle(cornerRadius: RankdRadius.md)
                                    .fill(RankdColors.brandSubtle)
                                    .frame(width: 60, height: 60)
                                Image(systemName: "plus")
                                    .font(RankdTypography.headingLarge)
                                    .foregroundStyle(RankdColors.brand)
                            }
                            Text("Blank List")
                                .font(RankdTypography.labelMedium)
                                .foregroundStyle(RankdColors.textPrimary)
                            Text("Start fresh")
                                .font(RankdTypography.caption)
                                .foregroundStyle(RankdColors.textTertiary)
                        }
                        .frame(width: 120)
                        .padding(RankdSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: RankdRadius.lg)
                                .fill(RankdColors.surfacePrimary)
                        )
                    }
                    .buttonStyle(RankdPressStyle())
                    
                    ForEach(Array(SuggestedList.allSuggestions.prefix(4))) { suggestion in
                        Button {
                            suggestedListToCreate = suggestion
                            showCreateListSheet = true
                        } label: {
                            VStack(spacing: RankdSpacing.sm) {
                                Text(suggestion.emoji)
                                    .font(.system(size: 32))
                                    .frame(width: 60, height: 60)
                                    .background(
                                        Circle()
                                            .fill(RankdColors.surfaceSecondary)
                                    )
                                Text(suggestion.name)
                                    .font(RankdTypography.labelMedium)
                                    .foregroundStyle(RankdColors.textPrimary)
                                    .lineLimit(1)
                                Text(suggestion.description)
                                    .font(RankdTypography.caption)
                                    .foregroundStyle(RankdColors.textTertiary)
                                    .lineLimit(1)
                            }
                            .frame(width: 120)
                            .padding(RankdSpacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: RankdRadius.lg)
                                    .fill(RankdColors.surfacePrimary)
                            )
                        }
                        .buttonStyle(RankdPressStyle())
                    }
                }
                .padding(.horizontal, RankdSpacing.md)
            }
        }
        .sheet(isPresented: $showCreateListSheet) {
            CreateListView(suggested: suggestedListToCreate)
        }
    }
    
    private var myListsScrollCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: RankdSpacing.sm) {
                ForEach(customLists) { list in
                    NavigationLink(destination: ListDetailView(list: list)) {
                        ListPreviewCard(list: list)
                    }
                    .buttonStyle(RankdPressStyle())
                }
                
                Button {
                    suggestedListToCreate = nil
                    showCreateListSheet = true
                } label: {
                    VStack(spacing: RankdSpacing.sm) {
                        ZStack {
                            RoundedRectangle(cornerRadius: RankdRadius.md)
                                .fill(RankdColors.brandSubtle)
                                .frame(width: 48, height: 48)
                            Image(systemName: "plus")
                                .font(RankdTypography.headingMedium)
                                .foregroundStyle(RankdColors.brand)
                        }
                        Text("New List")
                            .font(RankdTypography.labelMedium)
                            .foregroundStyle(RankdColors.brand)
                    }
                    .frame(width: 100, height: 160)
                    .background(
                        RoundedRectangle(cornerRadius: RankdRadius.lg)
                            .fill(RankdColors.surfacePrimary)
                    )
                }
                .buttonStyle(RankdPressStyle())
            }
            .padding(.horizontal, RankdSpacing.md)
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
        .buttonStyle(RankdPressStyle())
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
        .buttonStyle(RankdPressStyle())
    }
    
    // MARK: - Settings Section
    
    private var settingsSection: some View {
        VStack(spacing: RankdSpacing.sm) {
            HStack {
                Text("SETTINGS")
                    .font(RankdTypography.sectionLabel)
                    .tracking(1.5)
                    .foregroundStyle(RankdColors.textTertiary)
                Spacer()
            }
            .padding(.horizontal, RankdSpacing.md)
            
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
                .buttonStyle(RankdPressStyle())
                
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
                .buttonStyle(RankdPressStyle())
                
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
                .buttonStyle(RankdPressStyle())
                
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
                .buttonStyle(RankdPressStyle())
                
                // Reset
                Button {
                    showResetConfirmation = true
                } label: {
                    HStack(spacing: RankdSpacing.sm) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(RankdTypography.headingSmall)
                            .foregroundStyle(RankdColors.error)
                            .frame(width: 32)
                        
                        VStack(alignment: .leading, spacing: RankdSpacing.xxs) {
                            Text("Reset Data")
                                .font(RankdTypography.headingSmall)
                                .foregroundStyle(RankdColors.error)
                            Text("Delete all rankings, watchlist, and lists")
                                .font(RankdTypography.bodySmall)
                                .foregroundStyle(RankdColors.textTertiary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(RankdTypography.caption)
                            .foregroundStyle(RankdColors.textQuaternary)
                    }
                    .padding(RankdSpacing.md)
                    .background(RankdColors.surfacePrimary)
                }
                .buttonStyle(RankdPressStyle())
            }
            .clipShape(RoundedRectangle(cornerRadius: RankdRadius.lg))
            .padding(.horizontal, RankdSpacing.md)
        }
    }
    
    private func settingsRow(icon: String, title: String, subtitle: String, destination: AnyView) -> some View {
        NavigationLink {
            destination
        } label: {
            settingsRowContent(icon: icon, title: title, subtitle: subtitle)
        }
        .buttonStyle(RankdPressStyle())
    }
    
    private func settingsRowContent(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: RankdSpacing.sm) {
            Image(systemName: icon)
                .font(RankdTypography.headingSmall)
                .foregroundStyle(RankdColors.textSecondary)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: RankdSpacing.xxs) {
                Text(title)
                    .font(RankdTypography.headingSmall)
                    .foregroundStyle(RankdColors.textPrimary)
                Text(subtitle)
                    .font(RankdTypography.bodySmall)
                    .foregroundStyle(RankdColors.textTertiary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(RankdTypography.caption)
                .foregroundStyle(RankdColors.textQuaternary)
        }
        .padding(RankdSpacing.md)
        .background(RankdColors.surfacePrimary)
    }
    
    private var displayNameEditor: some View {
        Form {
            Section {
                TextField("Name", text: $displayName)
                    .font(RankdTypography.bodyLarge)
            } header: {
                Text("Your name appears at the top of your profile.")
            }
        }
        .navigationTitle("Name")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Notification Toggle
    
    private var notificationToggleRow: some View {
        HStack(spacing: RankdSpacing.sm) {
            Image(systemName: "bell.fill")
                .font(RankdTypography.headingSmall)
                .foregroundStyle(RankdColors.textSecondary)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: RankdSpacing.xxs) {
                Text("Notifications")
                    .font(RankdTypography.headingSmall)
                    .foregroundStyle(RankdColors.textPrimary)
                Text(notificationsEnabled ? "Reminders & streaks" : "Off")
                    .font(RankdTypography.bodySmall)
                    .foregroundStyle(RankdColors.textTertiary)
            }
            
            Spacer()
            
            Toggle("", isOn: $notificationsEnabled)
                .labelsHidden()
                .tint(RankdColors.brand)
        }
        .padding(RankdSpacing.md)
        .background(RankdColors.surfacePrimary)
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
        VStack(spacing: RankdSpacing.sm) {
            HStack {
                Text("TIER BREAKDOWN")
                    .font(RankdTypography.sectionLabel)
                    .tracking(1.5)
                    .foregroundStyle(RankdColors.textTertiary)
                Spacer()
            }
            
            ForEach(Tier.allCases, id: \.self) { tier in
                let count = rankedItems.filter { $0.tier == tier }.count
                let fraction = rankedItems.isEmpty ? 0.0 : Double(count) / Double(rankedItems.count)
                
                TierBar(tier: tier, count: count, fraction: fraction)
            }
        }
        .padding(RankdSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: RankdRadius.lg)
                .fill(RankdColors.surfacePrimary)
        )
        .padding(.horizontal, RankdSpacing.md)
    }
}

// MARK: - Quick Stat Card

private struct QuickStatCard: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: RankdSpacing.xxs) {
            Image(systemName: icon)
                .font(RankdTypography.labelSmall)
                .foregroundStyle(RankdColors.textTertiary)
            
            Text(value)
                .font(RankdTypography.headingMedium)
                .foregroundStyle(RankdColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(label)
                .font(RankdTypography.caption)
                .foregroundStyle(RankdColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, RankdSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: RankdRadius.md)
                .fill(RankdColors.surfacePrimary)
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
        VStack(alignment: .leading, spacing: RankdSpacing.sm) {
            posterCollage
            
            VStack(alignment: .leading, spacing: RankdSpacing.xxs) {
                HStack(spacing: RankdSpacing.xxs) {
                    Text(list.emoji)
                        .font(RankdTypography.bodyMedium)
                    Text(list.name)
                        .font(RankdTypography.headingSmall)
                        .foregroundStyle(RankdColors.textPrimary)
                        .lineLimit(1)
                }
                
                Text("\(list.itemCount) item\(list.itemCount == 1 ? "" : "s")")
                    .font(RankdTypography.caption)
                    .foregroundStyle(RankdColors.textTertiary)
            }
            .padding(.horizontal, RankdSpacing.xs)
            .padding(.bottom, RankdSpacing.xs)
        }
        .frame(width: 160)
        .background(
            RoundedRectangle(cornerRadius: RankdRadius.lg)
                .fill(RankdColors.surfacePrimary)
        )
    }
    
    private var posterCollage: some View {
        let size: CGFloat = 160
        let items = previewItems
        
        return ZStack {
            RoundedRectangle(cornerRadius: RankdRadius.md)
                .fill(RankdColors.surfaceSecondary)
            
            if items.isEmpty {
                Image(systemName: "film.stack")
                    .font(RankdTypography.headingLarge)
                    .foregroundStyle(RankdColors.textQuaternary)
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
                            Rectangle().fill(RankdColors.surfaceTertiary)
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                    HStack(spacing: 1) {
                        if items.count > 2 {
                            posterImage(for: items[2])
                                .frame(width: cellSize, height: cellSize)
                                .clipped()
                        } else {
                            Rectangle().fill(RankdColors.surfaceTertiary)
                                .frame(width: cellSize, height: cellSize)
                        }
                        if items.count > 3 {
                            posterImage(for: items[3])
                                .frame(width: cellSize, height: cellSize)
                                .clipped()
                        } else {
                            Rectangle().fill(RankdColors.surfaceTertiary)
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
        .frame(width: size, height: size * 0.65)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: RankdRadius.lg,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: RankdRadius.lg
            )
        )
    }
    
    @ViewBuilder
    private func posterImage(for item: CustomListItem) -> some View {
        if let url = item.posterURL {
            CachedAsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(RankdColors.surfaceTertiary)
            }
        } else {
            Rectangle().fill(RankdColors.surfaceTertiary)
        }
    }
}

// MARK: - Profile Nav Card

private struct ProfileNavCard: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: RankdSpacing.sm) {
            Image(systemName: icon)
                .font(RankdTypography.headingLarge)
                .foregroundStyle(RankdColors.textSecondary)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: RankdSpacing.xxs) {
                Text(title)
                    .font(RankdTypography.headingSmall)
                    .foregroundStyle(RankdColors.textPrimary)
                Text(subtitle)
                    .font(RankdTypography.bodySmall)
                    .foregroundStyle(RankdColors.textTertiary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(RankdTypography.caption)
                .foregroundStyle(RankdColors.textQuaternary)
        }
        .padding(RankdSpacing.md)
        .frame(minHeight: 48)
        .background(
            RoundedRectangle(cornerRadius: RankdRadius.lg)
                .fill(RankdColors.surfacePrimary)
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
        VStack(spacing: RankdSpacing.xs) {
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(url: item.posterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: RankdPoster.cornerRadius)
                        .fill(RankdColors.surfacePrimary)
                        .overlay {
                            Image(systemName: item.mediaType == .movie ? "film" : "tv")
                                .font(RankdTypography.headingLarge)
                                .foregroundStyle(RankdColors.textQuaternary)
                        }
                }
                .aspectRatio(2/3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: RankdPoster.cornerRadius))
                .overlay(alignment: .bottomTrailing) {
                    // Score badge overlay
                    if !allItems.isEmpty {
                        Text(String(format: "%.1f", score))
                            .font(RankdTypography.labelSmall)
                            .foregroundStyle(.white)
                            .padding(.horizontal, RankdSpacing.xs)
                            .padding(.vertical, RankdSpacing.xxs)
                            .background(
                                Capsule()
                                    .fill(RankdColors.tierColor(item.tier))
                            )
                            .padding(RankdSpacing.xs)
                    }
                }
                
                // Rank number overlay
                Text("\(rank)")
                    .font(RankdTypography.displayMedium)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                    .padding(.leading, RankdSpacing.xs)
                    .padding(.top, RankdSpacing.xs)
            }
            
            Text(item.title)
                .font(RankdTypography.labelSmall)
                .foregroundStyle(RankdColors.textPrimary)
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
        HStack(spacing: RankdSpacing.sm) {
            Circle()
                .fill(RankdColors.tierColor(tier))
                .frame(width: 8, height: 8)
            
            Text(tier.rawValue)
                .font(RankdTypography.bodySmall)
                .foregroundStyle(RankdColors.textSecondary)
                .frame(width: 64, alignment: .leading)
            
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: RankdRadius.sm)
                    .fill(RankdColors.tierColor(tier).opacity(0.4))
                    .frame(width: max(4, geo.size.width * fraction))
                    .animation(RankdMotion.reveal, value: fraction)
            }
            .frame(height: 20)
            
            Text("\(count)")
                .font(RankdTypography.labelMedium)
                .foregroundStyle(RankdColors.textSecondary)
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
            VStack(spacing: RankdSpacing.md) {
                VStack(spacing: RankdSpacing.xs) {
                    Image(systemName: "square.and.arrow.up")
                        .font(RankdTypography.displayMedium)
                        .foregroundStyle(RankdColors.brand)
                    
                    Text("Export Data")
                        .font(RankdTypography.headingLarge)
                        .foregroundStyle(RankdColors.textPrimary)
                    
                    Text("Save your data to share or back up")
                        .font(RankdTypography.bodySmall)
                        .foregroundStyle(RankdColors.textTertiary)
                }
                .padding(.top, RankdSpacing.lg)
                
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
                .clipShape(RoundedRectangle(cornerRadius: RankdRadius.lg))
                .padding(.horizontal, RankdSpacing.md)
                
                Spacer()
            }
            .background(RankdColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(RankdColors.brand)
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
            HStack(spacing: RankdSpacing.sm) {
                Image(systemName: icon)
                    .font(RankdTypography.headingSmall)
                    .foregroundStyle(disabled ? RankdColors.textQuaternary : RankdColors.brand)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: RankdSpacing.xxs) {
                    Text(title)
                        .font(RankdTypography.headingSmall)
                        .foregroundStyle(disabled ? RankdColors.textTertiary : RankdColors.textPrimary)
                    Text(subtitle)
                        .font(RankdTypography.bodySmall)
                        .foregroundStyle(RankdColors.textTertiary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(RankdTypography.caption)
                    .foregroundStyle(RankdColors.textQuaternary)
            }
            .padding(RankdSpacing.md)
            .background(RankdColors.surfacePrimary)
        }
        .buttonStyle(RankdPressStyle())
        .disabled(disabled)
    }
}

// MARK: - Share Sheet (UIActivityViewController)

#Preview {
    ProfileView()
        .modelContainer(for: [RankedItem.self, WatchlistItem.self, CustomList.self, CustomListItem.self], inMemory: true)
}
