import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \RankedItem.rank) private var rankedItems: [RankedItem]
    @Query private var watchlistItems: [WatchlistItem]
    @Environment(\.modelContext) private var modelContext
    
    @State private var isBackfilling = false
    @State private var backfillProgress: Int = 0
    @State private var animateCharts = false
    
    @AppStorage("cachedArchetype") private var cachedArchetype: String = ""
    @State private var personalityResult: TastePersonality.Result?
    
    // MARK: - Computed Properties
    
    private var movieItems: [RankedItem] {
        rankedItems.filter { $0.mediaType == .movie }
    }
    
    private var tvItems: [RankedItem] {
        rankedItems.filter { $0.mediaType == .tv }
    }
    
    private var itemsWithGenres: [RankedItem] {
        rankedItems.filter { !$0.genreNames.isEmpty }
    }
    
    private var itemsWithRuntime: [RankedItem] {
        rankedItems.filter { $0.runtimeMinutes > 0 }
    }
    
    private var memberSinceDate: Date? {
        rankedItems.map(\.dateAdded).min()
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: MarquiSpacing.lg) {
                if rankedItems.isEmpty {
                    emptyState
                } else {
                    summaryHeader
                    tasteDNASection
                    genreDistribution
                    decadeBreakdown
                    tierAnalysis
                    watchTimeSection
                    activityTimeline
                    funInsights
                }
            }
            .padding(.vertical, MarquiSpacing.md)
        }
        .background(MarquiColors.background)
        .navigationTitle("Statistics")
        .navigationBarTitleDisplayMode(.large)
        .task {
            // Trigger backfill for items missing genre data
            let itemsMissingGenres = rankedItems.filter { $0.genreNames.isEmpty }
            if !itemsMissingGenres.isEmpty {
                isBackfilling = true
                let updated = await GenreBackfillService.shared.backfillMissingData(
                    itemIDs: rankedItems.map(\.persistentModelID),
                    modelContext: modelContext
                )
                backfillProgress = updated
                isBackfilling = false
            }
            
            // Trigger chart animations after a brief delay
            withAnimation(MarquiMotion.reveal.delay(0.2)) {
                animateCharts = true
            }
        }
    }
    
    private static let statsThreshold = 5
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: MarquiSpacing.lg) {
            Spacer()
            
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundStyle(MarquiColors.textQuaternary)
            
            VStack(spacing: MarquiSpacing.xs) {
                Text("Rank more to unlock insights")
                    .font(MarquiTypography.headingLarge)
                    .foregroundStyle(MarquiColors.textPrimary)
                
                Text("Your stats and viewing patterns will appear\nonce you've ranked at least \(Self.statsThreshold) items.")
                    .font(MarquiTypography.bodyMedium)
                    .foregroundStyle(MarquiColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            // Progress indicator
            VStack(spacing: MarquiSpacing.xs) {
                let current = rankedItems.count
                let needed = max(Self.statsThreshold - current, 0)
                
                ProgressView(value: Double(current), total: Double(Self.statsThreshold))
                    .tint(MarquiColors.brand)
                    .frame(width: 200)
                
                Text("\(current) of \(Self.statsThreshold) ranked — \(needed) more to go")
                    .font(MarquiTypography.labelMedium)
                    .foregroundStyle(MarquiColors.textTertiary)
            }
            .padding(.top, MarquiSpacing.xs)
            
            Spacer()
        }
        .padding(.horizontal, MarquiSpacing.lg)
    }
    
    // MARK: - A. Summary Header
    
    private var summaryHeader: some View {
        VStack(spacing: MarquiSpacing.md) {
            // Big number
            Text("\(rankedItems.count)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(MarquiColors.brand)
            
            Text("Items Ranked")
                .font(MarquiTypography.bodyMedium)
                .foregroundStyle(MarquiColors.textSecondary)
            
            // Sub-stats row
            HStack(spacing: MarquiSpacing.lg) {
                MiniStat(value: movieItems.count, label: "Movies", icon: "film")
                
                Divider()
                    .frame(height: 30)
                
                MiniStat(value: tvItems.count, label: "TV Shows", icon: "tv")
                
                Divider()
                    .frame(height: 30)
                
                MiniStat(value: watchlistItems.count, label: "Watchlist", icon: "bookmark")
            }
            
            // Member since
            if let date = memberSinceDate {
                Text("Member since \(date.formatted(.dateTime.month(.wide).year()))")
                    .font(MarquiTypography.caption)
                    .foregroundStyle(MarquiColors.textTertiary)
            }
        }
        .padding(MarquiSpacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: MarquiRadius.lg)
                .fill(MarquiColors.surfacePrimary)
        )
        .padding(.horizontal, MarquiSpacing.md)
    }
    
    // MARK: - Taste DNA
    
    private var currentDNA: TastePersonality.Result {
        if let cached = personalityResult { return cached }
        return TastePersonality.analyze(items: Array(rankedItems))
    }
    
    private var tasteDNASection: some View {
        StatsSection(title: "Taste DNA", icon: "dna") {
            let dna = currentDNA.dna
            
            VStack(spacing: MarquiSpacing.md) {
                // Top 3 genres
                if !dna.topGenres.isEmpty {
                    VStack(alignment: .leading, spacing: MarquiSpacing.xs) {
                        Text("Top Genres")
                            .font(MarquiTypography.labelMedium)
                            .foregroundStyle(MarquiColors.textTertiary)
                        
                        ForEach(Array(dna.topGenres.enumerated()), id: \.offset) { index, genre in
                            HStack(spacing: MarquiSpacing.xs) {
                                Text("\(index + 1)")
                                    .font(MarquiTypography.labelSmall)
                                    .foregroundStyle(MarquiColors.textTertiary)
                                    .frame(width: 16)
                                
                                Text(genre.name)
                                    .font(MarquiTypography.bodyMedium)
                                    .foregroundStyle(MarquiColors.textPrimary)
                                
                                Spacer()
                                
                                Text("\(genre.percentage)%")
                                    .font(MarquiTypography.labelMedium)
                                    .foregroundStyle(MarquiColors.brand)
                            }
                        }
                    }
                    
                    Rectangle()
                        .fill(MarquiColors.divider)
                        .frame(height: 1)
                }
                
                // Stats grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: MarquiSpacing.sm) {
                    // Average score
                    DNAStatCell(
                        label: "Avg Score",
                        value: String(format: "%.1f", dna.averageScore),
                        detail: "/ 3.0",
                        icon: "star.fill"
                    )
                    
                    // Pickiness
                    DNAStatCell(
                        label: "Pickiness",
                        value: "\(dna.pickinessPercent)%",
                        detail: "red tier",
                        icon: "hand.thumbsdown"
                    )
                    
                    // Favorite decade
                    if let decade = dna.favoriteDecade {
                        DNAStatCell(
                            label: "Fav Decade",
                            value: decade,
                            detail: "",
                            icon: "calendar"
                        )
                    }
                    
                    // Movie vs TV
                    DNAStatCell(
                        label: "Ratio",
                        value: "\(dna.movieCount):\(dna.tvCount)",
                        detail: "movie:tv",
                        icon: "film"
                    )
                }
            }
        }
        .onAppear {
            recalculatePersonality()
        }
        .onChange(of: rankedItems.count) { _, _ in
            recalculatePersonality()
        }
    }
    
    private func recalculatePersonality() {
        let result = TastePersonality.analyze(items: Array(rankedItems))
        personalityResult = result
        cachedArchetype = result.archetype.rawValue
    }
    
    // MARK: - B. Genre Distribution
    
    private var genreDistribution: some View {
        StatsSection(title: "Genre Distribution", icon: "theatermasks") {
            if isBackfilling && itemsWithGenres.isEmpty {
                HStack(spacing: MarquiSpacing.sm) {
                    ProgressView()
                    Text("Analyzing your taste...")
                        .font(MarquiTypography.bodyMedium)
                        .foregroundStyle(MarquiColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, MarquiSpacing.lg)
            } else if itemsWithGenres.isEmpty {
                Text("Rank more to see genre stats")
                    .font(MarquiTypography.bodyMedium)
                    .foregroundStyle(MarquiColors.textSecondary)
                    .padding(.vertical, MarquiSpacing.lg)
            } else {
                let genreCounts = computeGenreCounts()
                let maxCount = genreCounts.first?.count ?? 1
                
                VStack(spacing: MarquiSpacing.xs) {
                    ForEach(Array(genreCounts.prefix(8).enumerated()), id: \.element.name) { index, genre in
                        GenreBar(
                            name: genre.name,
                            count: genre.count,
                            total: itemsWithGenres.count,
                            maxCount: maxCount,
                            color: genreColor(for: index),
                            animate: animateCharts
                        )
                    }
                }
                
                if isBackfilling {
                    HStack(spacing: MarquiSpacing.xs) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading more genre data...")
                            .font(MarquiTypography.caption)
                            .foregroundStyle(MarquiColors.textTertiary)
                    }
                    .padding(.top, MarquiSpacing.xxs)
                }
            }
        }
    }
    
    // MARK: - C. Decade Breakdown
    
    private var decadeBreakdown: some View {
        StatsSection(title: "Decades", icon: "calendar.badge.clock") {
            let decades = computeDecades()
            
            if decades.isEmpty {
                Text("No release date information available")
                    .font(MarquiTypography.bodyMedium)
                    .foregroundStyle(MarquiColors.textSecondary)
                    .padding(.vertical, MarquiSpacing.lg)
            } else {
                let maxCount = decades.first?.count ?? 1
                
                VStack(spacing: MarquiSpacing.xs) {
                    ForEach(decades, id: \.decade) { item in
                        DecadeBar(
                            decade: item.decade,
                            count: item.count,
                            total: rankedItems.count,
                            maxCount: maxCount,
                            animate: animateCharts
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - D. Tier Analysis
    
    private var tierAnalysis: some View {
        StatsSection(title: "Tier Analysis", icon: "chart.pie") {
            let goodCount = rankedItems.filter { $0.tier == .good }.count
            let mediumCount = rankedItems.filter { $0.tier == .medium }.count
            let badCount = rankedItems.filter { $0.tier == .bad }.count
            let total = rankedItems.count
            
            VStack(spacing: MarquiSpacing.lg) {
                // Segmented bar
                TierSegmentedBar(
                    good: goodCount,
                    medium: mediumCount,
                    bad: badCount,
                    total: total,
                    animate: animateCharts
                )
                
                // Percentages
                HStack(spacing: 0) {
                    TierStatPill(
                        tier: .good,
                        count: goodCount,
                        total: total
                    )
                    Spacer()
                    TierStatPill(
                        tier: .medium,
                        count: mediumCount,
                        total: total
                    )
                    Spacer()
                    TierStatPill(
                        tier: .bad,
                        count: badCount,
                        total: total
                    )
                }
                
                // Average score and insight
                let avgScore = total > 0
                    ? Double(goodCount * 3 + mediumCount * 2 + badCount) / Double(total)
                    : 0.0
                
                VStack(spacing: MarquiSpacing.xs) {
                    HStack(spacing: MarquiSpacing.xxs) {
                        Text("Average Score:")
                            .font(MarquiTypography.bodyMedium)
                            .foregroundStyle(MarquiColors.textSecondary)
                        Text(String(format: "%.1f", avgScore))
                            .font(MarquiTypography.headingSmall)
                            .foregroundStyle(MarquiColors.textPrimary)
                        Text("/ 3.0")
                            .font(MarquiTypography.caption)
                            .foregroundStyle(MarquiColors.textTertiary)
                    }
                    
                    Text(viewerInsight(avgScore: avgScore))
                        .font(MarquiTypography.bodyMedium)
                        .foregroundStyle(MarquiColors.brand)
                        .fontWeight(.medium)
                }
            }
        }
    }
    
    // MARK: - E. Watch Time
    
    private var watchTimeSection: some View {
        StatsSection(title: "Watch Time", icon: "clock") {
            if itemsWithRuntime.isEmpty {
                VStack(spacing: MarquiSpacing.xs) {
                    Text("No runtime data available yet")
                        .font(MarquiTypography.bodyMedium)
                        .foregroundStyle(MarquiColors.textSecondary)
                    
                    if isBackfilling {
                        HStack(spacing: MarquiSpacing.xs) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Fetching runtime data...")
                                .font(MarquiTypography.caption)
                                .foregroundStyle(MarquiColors.textTertiary)
                        }
                    }
                }
                .padding(.vertical, MarquiSpacing.sm)
            } else {
                let totalMinutes = itemsWithRuntime.reduce(0) { $0 + $1.runtimeMinutes }
                let days = totalMinutes / (60 * 24)
                let hours = (totalMinutes % (60 * 24)) / 60
                let minutes = totalMinutes % 60
                
                VStack(spacing: MarquiSpacing.md) {
                    // Total watch time
                    HStack(spacing: MarquiSpacing.xxs) {
                        if days > 0 {
                            Text("\(days)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(MarquiColors.brand)
                            Text("d")
                                .font(MarquiTypography.headingSmall)
                                .foregroundStyle(MarquiColors.textSecondary)
                        }
                        Text("\(hours)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(MarquiColors.brand)
                        Text("h")
                            .font(MarquiTypography.headingSmall)
                            .foregroundStyle(MarquiColors.textSecondary)
                        Text("\(minutes)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(MarquiColors.brand)
                        Text("m")
                            .font(MarquiTypography.headingSmall)
                            .foregroundStyle(MarquiColors.textSecondary)
                    }
                    
                    Text("Total estimated watch time")
                        .font(MarquiTypography.caption)
                        .foregroundStyle(MarquiColors.textTertiary)
                    
                    if itemsWithRuntime.count < rankedItems.count {
                        Text("\(itemsWithRuntime.count) of \(rankedItems.count) items have runtime data")
                            .font(MarquiTypography.caption)
                            .foregroundStyle(MarquiColors.textTertiary)
                    }
                    
                    Rectangle()
                        .fill(MarquiColors.divider)
                        .frame(height: 1)
                    
                    // Longest & shortest
                    HStack(spacing: MarquiSpacing.md) {
                        if let longest = itemsWithRuntime.max(by: { $0.runtimeMinutes < $1.runtimeMinutes }) {
                            WatchTimeExtreme(
                                label: "Longest",
                                title: longest.title,
                                minutes: longest.runtimeMinutes,
                                icon: "arrow.up.circle.fill",
                                color: MarquiColors.brand
                            )
                        }
                        
                        if itemsWithRuntime.count > 1,
                           let shortest = itemsWithRuntime.min(by: { $0.runtimeMinutes < $1.runtimeMinutes }) {
                            WatchTimeExtreme(
                                label: "Shortest",
                                title: shortest.title,
                                minutes: shortest.runtimeMinutes,
                                icon: "arrow.down.circle.fill",
                                color: MarquiColors.textTertiary
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - F. Activity Timeline
    
    private var activityTimeline: some View {
        StatsSection(title: "Activity", icon: "chart.bar.fill") {
            let monthlyData = computeMonthlyActivity()
            
            if monthlyData.isEmpty {
                Text("Not enough data yet")
                    .font(MarquiTypography.bodyMedium)
                    .foregroundStyle(MarquiColors.textSecondary)
                    .padding(.vertical, MarquiSpacing.sm)
            } else {
                let maxCount = monthlyData.map(\.count).max() ?? 1
                
                VStack(spacing: MarquiSpacing.sm) {
                    // Bar chart
                    HStack(alignment: .bottom, spacing: MarquiSpacing.xs) {
                        ForEach(monthlyData, id: \.label) { month in
                            VStack(spacing: MarquiSpacing.xxs) {
                                Text("\(month.count)")
                                    .font(MarquiTypography.caption)
                                    .foregroundStyle(MarquiColors.textSecondary)
                                
                                RoundedRectangle(cornerRadius: MarquiRadius.sm)
                                    .fill(
                                        month.count == maxCount
                                            ? MarquiColors.brand
                                            : MarquiColors.brand.opacity(0.35)
                                    )
                                    .frame(
                                        height: animateCharts
                                            ? max(8, CGFloat(month.count) / CGFloat(maxCount) * 100)
                                            : 8
                                    )
                                
                                Text(month.label)
                                    .font(MarquiTypography.caption)
                                    .foregroundStyle(MarquiColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 140)
                    .animation(MarquiMotion.reveal, value: animateCharts)
                    
                    // Most active month
                    if let mostActive = monthlyData.max(by: { $0.count < $1.count }), mostActive.count > 0 {
                        Text("Most active: \(mostActive.fullLabel) (\(mostActive.count) items)")
                            .font(MarquiTypography.caption)
                            .foregroundStyle(MarquiColors.textSecondary)
                    }
                }
            }
        }
    }
    
    // MARK: - G. Fun Insights
    
    private var funInsights: some View {
        VStack(spacing: MarquiSpacing.sm) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(MarquiColors.warning)
                Text("Insights")
                    .font(MarquiTypography.headingMedium)
                    .foregroundStyle(MarquiColors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, MarquiSpacing.md)
            
            let insights = computeInsights()
            
            if insights.isEmpty {
                Text("Rank more items to unlock insights!")
                    .font(MarquiTypography.bodyMedium)
                    .foregroundStyle(MarquiColors.textSecondary)
                    .padding(MarquiSpacing.md)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: MarquiSpacing.sm) {
                    ForEach(Array(insights.prefix(4).enumerated()), id: \.offset) { _, insight in
                        InsightCard(icon: insight.icon, text: insight.text)
                    }
                }
                .padding(.horizontal, MarquiSpacing.md)
            }
        }
        .padding(.bottom, MarquiSpacing.md)
    }
    
    // MARK: - Data Computation
    
    private func computeGenreCounts() -> [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for item in itemsWithGenres {
            for genre in item.genreNames {
                counts[genre, default: 0] += 1
            }
        }
        return counts.map { (name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    private func computeDecades() -> [(decade: String, count: Int)] {
        var decadeCounts: [String: Int] = [:]
        for item in rankedItems {
            guard let date = item.releaseDate, date.count >= 4,
                  let year = Int(date.prefix(4)) else { continue }
            let decadeStart = (year / 10) * 10
            let label = "\(decadeStart)s"
            decadeCounts[label, default: 0] += 1
        }
        return decadeCounts.map { (decade: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    private struct MonthData {
        let label: String
        let fullLabel: String
        let count: Int
    }
    
    private func computeMonthlyActivity() -> [MonthData] {
        let calendar = Calendar.current
        let now = Date()
        
        // Show last 6 months
        var months: [MonthData] = []
        let formatter = DateFormatter()
        let fullFormatter = DateFormatter()
        fullFormatter.dateFormat = "MMMM yyyy"
        
        for i in (0..<6).reversed() {
            guard let date = calendar.date(byAdding: .month, value: -i, to: now) else { continue }
            let components = calendar.dateComponents([.year, .month], from: date)
            
            formatter.dateFormat = "MMM"
            let label = formatter.string(from: date)
            let full = fullFormatter.string(from: date)
            
            let count = rankedItems.filter { item in
                let itemComponents = calendar.dateComponents([.year, .month], from: item.dateAdded)
                return itemComponents.year == components.year && itemComponents.month == components.month
            }.count
            
            months.append(MonthData(label: label, fullLabel: full, count: count))
        }
        
        return months
    }
    
    private struct Insight {
        let icon: String
        let text: String
    }
    
    private func computeInsights() -> [Insight] {
        var insights: [Insight] = []
        
        // #1 Genre
        let genreCounts = computeGenreCounts()
        if let topGenre = genreCounts.first {
            insights.append(Insight(
                icon: "star.fill",
                text: "Your #1 genre is \(topGenre.name)"
            ))
        }
        
        // Decade count
        let decades = computeDecades()
        if let topDecade = decades.first {
            insights.append(Insight(
                icon: "calendar",
                text: "You've ranked \(topDecade.count) titles from the \(topDecade.decade)"
            ))
        }
        
        // Longest movie
        if let longest = itemsWithRuntime.max(by: { $0.runtimeMinutes < $1.runtimeMinutes }),
           longest.runtimeMinutes > 0 {
            let h = longest.runtimeMinutes / 60
            let m = longest.runtimeMinutes % 60
            let timeStr = h > 0 ? "\(h)h \(m)m" : "\(m)m"
            insights.append(Insight(
                icon: "hourglass",
                text: "Longest: \(longest.title) at \(timeStr)"
            ))
        }
        
        // Total comparisons
        let totalComparisons = rankedItems.reduce(0) { $0 + $1.comparisonCount }
        if totalComparisons > 0 {
            insights.append(Insight(
                icon: "arrow.left.arrow.right",
                text: "You've made \(totalComparisons) comparisons"
            ))
        }
        
        // Movie vs TV ratio
        if movieItems.count > 0 && tvItems.count > 0 {
            let ratio = Double(movieItems.count) / Double(tvItems.count)
            if ratio > 2 {
                insights.append(Insight(
                    icon: "film",
                    text: "You watch \(String(format: "%.0f", ratio))x more movies than TV"
                ))
            } else if ratio < 0.5 {
                let tvRatio = Double(tvItems.count) / Double(movieItems.count)
                insights.append(Insight(
                    icon: "tv",
                    text: "You watch \(String(format: "%.0f", tvRatio))x more TV than movies"
                ))
            }
        }
        
        return insights
    }
    
    private func viewerInsight(avgScore: Double) -> String {
        if avgScore >= 2.5 {
            return "You're a generous viewer"
        } else if avgScore >= 1.8 {
            return "You're a balanced viewer"
        } else {
            return "You're a critical viewer"
        }
    }
    
    private func genreColor(for index: Int) -> Color {
        // Muted palette — no saturated colors
        let colors: [Color] = [
            MarquiColors.brand,
            MarquiColors.brand.opacity(0.65),
            MarquiColors.tierGood.opacity(0.7),
            MarquiColors.tierMedium.opacity(0.7),
            MarquiColors.textTertiary,
            MarquiColors.brand.opacity(0.45),
            MarquiColors.tierBad.opacity(0.5),
            MarquiColors.textSecondary
        ]
        return colors[index % colors.count]
    }
}

// MARK: - Supporting Views

private struct MiniStat: View {
    let value: Int
    let label: String
    let icon: String
    
    var body: some View {
        VStack(spacing: MarquiSpacing.xxs) {
            Image(systemName: icon)
                .font(MarquiTypography.caption)
                .foregroundStyle(MarquiColors.textSecondary)
            Text("\(value)")
                .font(MarquiTypography.headingMedium)
                .foregroundStyle(MarquiColors.textPrimary)
            Text(label)
                .font(MarquiTypography.caption)
                .foregroundStyle(MarquiColors.textSecondary)
        }
    }
}

private struct StatsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(spacing: MarquiSpacing.sm) {
            HStack(spacing: MarquiSpacing.xs) {
                Image(systemName: icon)
                    .foregroundStyle(MarquiColors.brand)
                Text(title)
                    .font(MarquiTypography.headingMedium)
                    .foregroundStyle(MarquiColors.textPrimary)
                Spacer()
            }
            
            content
        }
        .padding(MarquiSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: MarquiRadius.lg)
                .fill(MarquiColors.surfacePrimary)
        )
        .padding(.horizontal, MarquiSpacing.md)
    }
}

private struct GenreBar: View {
    let name: String
    let count: Int
    let total: Int
    let maxCount: Int
    let color: Color
    let animate: Bool
    
    private var percentage: Int {
        guard total > 0 else { return 0 }
        return Int(round(Double(count) / Double(total) * 100))
    }
    
    var body: some View {
        HStack(spacing: MarquiSpacing.xs) {
            Text(name)
                .font(MarquiTypography.caption)
                .foregroundStyle(MarquiColors.textSecondary)
                .frame(width: 80, alignment: .trailing)
                .lineLimit(1)
            
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: MarquiRadius.sm)
                    .fill(color.opacity(0.7))
                    .frame(
                        width: animate
                            ? max(4, geo.size.width * CGFloat(count) / CGFloat(maxCount))
                            : 4
                    )
            }
            .frame(height: 22)
            .animation(MarquiMotion.reveal, value: animate)
            
            Text("\(count)")
                .font(MarquiTypography.labelMedium)
                .foregroundStyle(MarquiColors.textPrimary)
                .frame(width: 24, alignment: .trailing)
            
            Text("\(percentage)%")
                .font(MarquiTypography.caption)
                .foregroundStyle(MarquiColors.textSecondary)
                .frame(width: 32, alignment: .trailing)
        }
    }
}

private struct DecadeBar: View {
    let decade: String
    let count: Int
    let total: Int
    let maxCount: Int
    let animate: Bool
    
    var body: some View {
        HStack(spacing: MarquiSpacing.xs) {
            Text(decade)
                .font(MarquiTypography.labelMedium)
                .foregroundStyle(MarquiColors.textPrimary)
                .frame(width: 50, alignment: .trailing)
            
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: MarquiRadius.sm)
                    .fill(MarquiColors.brand.opacity(0.45))
                    .frame(
                        width: animate
                            ? max(4, geo.size.width * CGFloat(count) / CGFloat(maxCount))
                            : 4
                    )
            }
            .frame(height: 22)
            .animation(MarquiMotion.reveal, value: animate)
            
            Text("\(count)")
                .font(MarquiTypography.labelMedium)
                .foregroundStyle(MarquiColors.textPrimary)
                .frame(width: 28, alignment: .trailing)
        }
    }
}

private struct TierSegmentedBar: View {
    let good: Int
    let medium: Int
    let bad: Int
    let total: Int
    let animate: Bool
    
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                if good > 0 {
                    RoundedRectangle(cornerRadius: MarquiRadius.sm)
                        .fill(MarquiColors.tierGood.opacity(0.7))
                        .frame(width: animate ? geo.size.width * CGFloat(good) / CGFloat(max(total, 1)) : 0)
                }
                if medium > 0 {
                    RoundedRectangle(cornerRadius: MarquiRadius.sm)
                        .fill(MarquiColors.tierMedium.opacity(0.7))
                        .frame(width: animate ? geo.size.width * CGFloat(medium) / CGFloat(max(total, 1)) : 0)
                }
                if bad > 0 {
                    RoundedRectangle(cornerRadius: MarquiRadius.sm)
                        .fill(MarquiColors.tierBad.opacity(0.7))
                        .frame(width: animate ? geo.size.width * CGFloat(bad) / CGFloat(max(total, 1)) : 0)
                }
            }
        }
        .frame(height: 28)
        .clipShape(RoundedRectangle(cornerRadius: MarquiRadius.sm))
        .animation(MarquiMotion.reveal, value: animate)
    }
}

private struct TierStatPill: View {
    let tier: Tier
    let count: Int
    let total: Int
    
    private var percentage: Int {
        guard total > 0 else { return 0 }
        return Int(round(Double(count) / Double(total) * 100))
    }
    
    var body: some View {
        HStack(spacing: MarquiSpacing.xs) {
            Circle()
                .fill(MarquiColors.tierColor(tier).opacity(0.7))
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(tier.rawValue)
                    .font(MarquiTypography.labelMedium)
                    .foregroundStyle(MarquiColors.textPrimary)
                Text("\(count) (\(percentage)%)")
                    .font(MarquiTypography.caption)
                    .foregroundStyle(MarquiColors.textSecondary)
            }
        }
    }
}

private struct WatchTimeExtreme: View {
    let label: String
    let title: String
    let minutes: Int
    let icon: String
    let color: Color
    
    private var formatted: String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m)m"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: MarquiSpacing.xs) {
            HStack(spacing: MarquiSpacing.xxs) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(MarquiTypography.caption)
                Text(label)
                    .font(MarquiTypography.caption)
                    .foregroundStyle(MarquiColors.textSecondary)
            }
            
            Text(title)
                .font(MarquiTypography.labelMedium)
                .foregroundStyle(MarquiColors.textPrimary)
                .lineLimit(2)
            
            Text(formatted)
                .font(MarquiTypography.caption)
                .foregroundStyle(MarquiColors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InsightCard: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: MarquiSpacing.xs) {
            Image(systemName: icon)
                .foregroundStyle(MarquiColors.brand)
                .font(MarquiTypography.bodyMedium)
                .frame(width: 24)
            
            Text(text)
                .font(MarquiTypography.caption)
                .foregroundStyle(MarquiColors.textSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(MarquiSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: MarquiRadius.md)
                .fill(MarquiColors.brandSubtle)
        )
    }
}

private struct DNAStatCell: View {
    let label: String
    let value: String
    let detail: String
    let icon: String
    
    var body: some View {
        VStack(spacing: MarquiSpacing.xxs) {
            Image(systemName: icon)
                .font(MarquiTypography.bodySmall)
                .foregroundStyle(MarquiColors.brand)
            
            Text(value)
                .font(MarquiTypography.headingMedium)
                .foregroundStyle(MarquiColors.textPrimary)
            
            if !detail.isEmpty {
                Text(detail)
                    .font(MarquiTypography.caption)
                    .foregroundStyle(MarquiColors.textTertiary)
            }
            
            Text(label)
                .font(MarquiTypography.labelSmall)
                .foregroundStyle(MarquiColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MarquiSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: MarquiRadius.md)
                .fill(MarquiColors.surfaceSecondary)
        )
    }
}

#Preview {
    NavigationStack {
        StatsView()
    }
    .modelContainer(for: [RankedItem.self, WatchlistItem.self], inMemory: true)
}
