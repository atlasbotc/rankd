import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query(sort: \RankedItem.rank) private var rankedItems: [RankedItem]
    @Query private var watchlistItems: [WatchlistItem]
    
    @State private var showCompareView = false
    @State private var showLetterboxdImport = false
    @State private var showShareSheet = false
    
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
                    topFourSection
                    statsGrid
                    
                    if !rankedItems.isEmpty {
                        tasteSection
                    }
                    
                    // Navigation cards
                    VStack(spacing: RankdSpacing.sm) {
                        statisticsCard
                        journalCard
                        myListsCard
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
        }
    }
    
    // MARK: - Top 4 Showcase
    
    private var topFourSection: some View {
        VStack(spacing: RankdSpacing.md) {
            HStack {
                Text("Top 4")
                    .font(RankdTypography.headingLarge)
                    .foregroundStyle(RankdColors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, RankdSpacing.md)
            
            if topFour.isEmpty {
                emptyTopFour
            } else {
                topFourGrid
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
    
    // MARK: - Stats Grid
    
    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: RankdSpacing.sm) {
            StatCard(value: "\(movieItems.count)", label: "Movies", icon: "film")
            StatCard(value: "\(tvItems.count)", label: "TV Shows", icon: "tv")
            StatCard(value: "\(watchlistItems.count)", label: "Watchlist", icon: "bookmark")
        }
        .padding(.horizontal, RankdSpacing.md)
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
        .buttonStyle(.plain)
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
        .buttonStyle(.plain)
    }
    
    private var myListsCard: some View {
        NavigationLink {
            ListsView()
        } label: {
            ProfileNavCard(
                icon: "list.bullet.rectangle.portrait.fill",
                title: "My Lists",
                subtitle: "Create and curate themed collections"
            )
        }
        .buttonStyle(.plain)
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
        .buttonStyle(.plain)
    }
    
    // MARK: - Settings Section
    
    private var settingsSection: some View {
        VStack(spacing: RankdSpacing.sm) {
            HStack {
                Text("Settings")
                    .font(RankdTypography.headingSmall)
                    .foregroundStyle(RankdColors.textPrimary)
                Spacer()
            }
            
            Button {
                showLetterboxdImport = true
            } label: {
                HStack(spacing: RankdSpacing.sm) {
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(RankdTypography.headingSmall)
                        .foregroundStyle(RankdColors.textSecondary)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: RankdSpacing.xxs) {
                        Text("Import from Letterboxd")
                            .font(RankdTypography.headingSmall)
                            .foregroundStyle(RankdColors.textPrimary)
                        Text("Bring in your ratings and watched films")
                            .font(RankdTypography.bodySmall)
                            .foregroundStyle(RankdColors.textTertiary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(RankdTypography.caption)
                        .foregroundStyle(RankdColors.textQuaternary)
                }
                .padding(RankdSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: RankdRadius.lg)
                        .fill(RankdColors.surfacePrimary)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, RankdSpacing.md)
    }
    
    // MARK: - Tier Breakdown
    
    private var tierBreakdown: some View {
        VStack(spacing: RankdSpacing.sm) {
            HStack {
                Text("Tier Breakdown")
                    .font(RankdTypography.headingMedium)
                    .foregroundStyle(RankdColors.textPrimary)
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
                AsyncImage(url: item.posterURL) { image in
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
                
                // Rank badge
                Text("#\(rank)")
                    .font(RankdTypography.labelSmall)
                    .foregroundStyle(RankdColors.textSecondary)
                    .padding(.horizontal, RankdSpacing.xs)
                    .padding(.vertical, RankdSpacing.xxs)
                    .background(
                        Capsule()
                            .fill(RankdColors.surfaceTertiary)
                    )
                    .padding(RankdSpacing.xs)
            }
            
            VStack(spacing: RankdSpacing.xxs) {
                Text(item.title)
                    .font(RankdTypography.labelSmall)
                    .foregroundStyle(RankdColors.textPrimary)
                    .lineLimit(1)
                
                if !allItems.isEmpty {
                    ScoreBadge(score: score, tier: item.tier, compact: true)
                }
            }
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    @State private var displayedValue: Int = 0
    
    private var numericValue: Int? { Int(value) }
    
    var body: some View {
        VStack(spacing: RankdSpacing.xs) {
            Image(systemName: icon)
                .font(RankdTypography.headingSmall)
                .foregroundStyle(RankdColors.textTertiary)
            
            if let target = numericValue {
                Text("\(displayedValue)")
                    .font(RankdTypography.headingLarge)
                    .foregroundStyle(RankdColors.textPrimary)
                    .onAppear { animateCount(to: target) }
                    .onChange(of: value) { _, newValue in
                        if let newTarget = Int(newValue) {
                            animateCount(to: newTarget)
                        }
                    }
            } else {
                Text(value)
                    .font(RankdTypography.headingLarge)
                    .foregroundStyle(RankdColors.textPrimary)
            }
            
            Text(label)
                .font(RankdTypography.labelMedium)
                .foregroundStyle(RankdColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, RankdSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: RankdRadius.lg)
                .fill(RankdColors.surfacePrimary)
        )
    }
    
    private func animateCount(to target: Int) {
        guard target > 0 else {
            displayedValue = 0
            return
        }
        let steps = min(target, 20)
        let interval = 0.4 / Double(steps)
        for step in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(step)) {
                withAnimation(RankdMotion.fast) {
                    displayedValue = Int(Double(target) * Double(step) / Double(steps))
                }
            }
        }
    }
}

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

#Preview {
    ProfileView()
        .modelContainer(for: [RankedItem.self, WatchlistItem.self, CustomList.self, CustomListItem.self], inMemory: true)
}
