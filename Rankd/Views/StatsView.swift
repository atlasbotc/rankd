import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \RankedItem.rank) private var rankedItems: [RankedItem]
    @Query private var watchlistItems: [WatchlistItem]
    @Environment(\.modelContext) private var modelContext
    
    @State private var isBackfilling = false
    @State private var backfillProgress: Int = 0
    @State private var animateCharts = false
    
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
            VStack(spacing: RankdSpacing.lg) {
                if rankedItems.isEmpty {
                    emptyState
                } else {
                    summaryHeader
                    genreDistribution
                    decadeBreakdown
                    tierAnalysis
                    watchTimeSection
                    activityTimeline
                    funInsights
                }
            }
            .padding(.vertical, RankdSpacing.md)
        }
        .background(RankdColors.background)
        .navigationTitle("Statistics")
        .navigationBarTitleDisplayMode(.large)
        .task {
            // Trigger backfill for items missing genre data
            let itemsMissingGenres = rankedItems.filter { $0.genreNames.isEmpty }
            if !itemsMissingGenres.isEmpty {
                isBackfilling = true
                let updated = await GenreBackfillService.shared.backfillMissingData(
                    items: rankedItems,
                    modelContext: modelContext
                )
                backfillProgress = updated
                isBackfilling = false
            }
            
            // Trigger chart animations after a brief delay
            withAnimation(RankdMotion.reveal.delay(0.2)) {
                animateCharts = true
            }
        }
    }
    
    private static let statsThreshold = 5
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: RankdSpacing.lg) {
            Spacer()
            
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundStyle(RankdColors.textQuaternary)
            
            VStack(spacing: RankdSpacing.xs) {
                Text("Rank more to unlock insights")
                    .font(RankdTypography.headingLarge)
                    .foregroundStyle(RankdColors.textPrimary)
                
                Text("Your stats and viewing patterns will appear\nonce you've ranked at least \(Self.statsThreshold) items.")
                    .font(RankdTypography.bodyMedium)
                    .foregroundStyle(RankdColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            // Progress indicator
            VStack(spacing: RankdSpacing.xs) {
                let current = rankedItems.count
                let needed = max(Self.statsThreshold - current, 0)
                
                ProgressView(value: Double(current), total: Double(Self.statsThreshold))
                    .tint(RankdColors.brand)
                    .frame(width: 200)
                
                Text("\(current) of \(Self.statsThreshold) ranked — \(needed) more to go")
                    .font(RankdTypography.labelMedium)
                    .foregroundStyle(RankdColors.textTertiary)
            }
            .padding(.top, RankdSpacing.xs)
            
            Spacer()
        }
        .padding(.horizontal, RankdSpacing.lg)
    }
    
    // MARK: - A. Summary Header
    
    private var summaryHeader: some View {
        VStack(spacing: RankdSpacing.md) {
            // Big number
            Text("\(rankedItems.count)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(RankdColors.brand)
            
            Text("Items Ranked")
                .font(RankdTypography.bodyMedium)
                .foregroundStyle(RankdColors.textSecondary)
            
            // Sub-stats row
            HStack(spacing: RankdSpacing.lg) {
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
                    .font(RankdTypography.caption)
                    .foregroundStyle(RankdColors.textTertiary)
            }
        }
        .padding(RankdSpacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: RankdRadius.lg)
                .fill(RankdColors.surfacePrimary)
        )
        .padding(.horizontal, RankdSpacing.md)
    }
    
    // MARK: - B. Genre Distribution
    
    private var genreDistribution: some View {
        StatsSection(title: "Genre Distribution", icon: "theatermasks") {
            if isBackfilling && itemsWithGenres.isEmpty {
                HStack(spacing: RankdSpacing.sm) {
                    ProgressView()
                    Text("Analyzing your taste...")
                        .font(RankdTypography.bodyMedium)
                        .foregroundStyle(RankdColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, RankdSpacing.lg)
            } else if itemsWithGenres.isEmpty {
                Text("Rank more to see genre stats")
                    .font(RankdTypography.bodyMedium)
                    .foregroundStyle(RankdColors.textSecondary)
                    .padding(.vertical, RankdSpacing.lg)
            } else {
                let genreCounts = computeGenreCounts()
                let maxCount = genreCounts.first?.count ?? 1
                
                VStack(spacing: RankdSpacing.xs) {
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
                    HStack(spacing: RankdSpacing.xs) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading more genre data...")
                            .font(RankdTypography.caption)
                            .foregroundStyle(RankdColors.textTertiary)
                    }
                    .padding(.top, RankdSpacing.xxs)
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
                    .font(RankdTypography.bodyMedium)
                    .foregroundStyle(RankdColors.textSecondary)
                    .padding(.vertical, RankdSpacing.lg)
            } else {
                let maxCount = decades.first?.count ?? 1
                
                VStack(spacing: RankdSpacing.xs) {
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
            
            VStack(spacing: RankdSpacing.lg) {
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
                
                VStack(spacing: RankdSpacing.xs) {
                    HStack(spacing: RankdSpacing.xxs) {
                        Text("Average Score:")
                            .font(RankdTypography.bodyMedium)
                            .foregroundStyle(RankdColors.textSecondary)
                        Text(String(format: "%.1f", avgScore))
                            .font(RankdTypography.headingSmall)
                            .foregroundStyle(RankdColors.textPrimary)
                        Text("/ 3.0")
                            .font(RankdTypography.caption)
                            .foregroundStyle(RankdColors.textTertiary)
                    }
                    
                    Text(viewerInsight(avgScore: avgScore))
                        .font(RankdTypography.bodyMedium)
                        .foregroundStyle(RankdColors.brand)
                        .fontWeight(.medium)
                }
            }
        }
    }
    
    // MARK: - E. Watch Time
    
    private var watchTimeSection: some View {
        StatsSection(title: "Watch Time", icon: "clock") {
            if itemsWithRuntime.isEmpty {
                VStack(spacing: RankdSpacing.xs) {
                    Text("No runtime data available yet")
                        .font(RankdTypography.bodyMedium)
                        .foregroundStyle(RankdColors.textSecondary)
                    
                    if isBackfilling {
                        HStack(spacing: RankdSpacing.xs) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Fetching runtime data...")
                                .font(RankdTypography.caption)
                                .foregroundStyle(RankdColors.textTertiary)
                        }
                    }
                }
                .padding(.vertical, RankdSpacing.sm)
            } else {
                let totalMinutes = itemsWithRuntime.reduce(0) { $0 + $1.runtimeMinutes }
                let days = totalMinutes / (60 * 24)
                let hours = (totalMinutes % (60 * 24)) / 60
                let minutes = totalMinutes % 60
                
                VStack(spacing: RankdSpacing.md) {
                    // Total watch time
                    HStack(spacing: RankdSpacing.xxs) {
                        if days > 0 {
                            Text("\(days)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(RankdColors.brand)
                            Text("d")
                                .font(RankdTypography.headingSmall)
                                .foregroundStyle(RankdColors.textSecondary)
                        }
                        Text("\(hours)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(RankdColors.brand)
                        Text("h")
                            .font(RankdTypography.headingSmall)
                            .foregroundStyle(RankdColors.textSecondary)
                        Text("\(minutes)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(RankdColors.brand)
                        Text("m")
                            .font(RankdTypography.headingSmall)
                            .foregroundStyle(RankdColors.textSecondary)
                    }
                    
                    Text("Total estimated watch time")
                        .font(RankdTypography.caption)
                        .foregroundStyle(RankdColors.textTertiary)
                    
                    if itemsWithRuntime.count < rankedItems.count {
                        Text("\(itemsWithRuntime.count) of \(rankedItems.count) items have runtime data")
                            .font(RankdTypography.caption)
                            .foregroundStyle(RankdColors.textTertiary)
                    }
                    
                    Rectangle()
                        .fill(RankdColors.divider)
                        .frame(height: 1)
                    
                    // Longest & shortest
                    HStack(spacing: RankdSpacing.md) {
                        if let longest = itemsWithRuntime.max(by: { $0.runtimeMinutes < $1.runtimeMinutes }) {
                            WatchTimeExtreme(
                                label: "Longest",
                                title: longest.title,
                                minutes: longest.runtimeMinutes,
                                icon: "arrow.up.circle.fill",
                                color: RankdColors.brand
                            )
                        }
                        
                        if itemsWithRuntime.count > 1,
                           let shortest = itemsWithRuntime.min(by: { $0.runtimeMinutes < $1.runtimeMinutes }) {
                            WatchTimeExtreme(
                                label: "Shortest",
                                title: shortest.title,
                                minutes: shortest.runtimeMinutes,
                                icon: "arrow.down.circle.fill",
                                color: RankdColors.textTertiary
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
                    .font(RankdTypography.bodyMedium)
                    .foregroundStyle(RankdColors.textSecondary)
                    .padding(.vertical, RankdSpacing.sm)
            } else {
                let maxCount = monthlyData.map(\.count).max() ?? 1
                
                VStack(spacing: RankdSpacing.sm) {
                    // Bar chart
                    HStack(alignment: .bottom, spacing: RankdSpacing.xs) {
                        ForEach(monthlyData, id: \.label) { month in
                            VStack(spacing: RankdSpacing.xxs) {
                                Text("\(month.count)")
                                    .font(RankdTypography.caption)
                                    .foregroundStyle(RankdColors.textSecondary)
                                
                                RoundedRectangle(cornerRadius: RankdRadius.sm)
                                    .fill(
                                        month.count == maxCount
                                            ? RankdColors.brand
                                            : RankdColors.brand.opacity(0.35)
                                    )
                                    .frame(
                                        height: animateCharts
                                            ? max(8, CGFloat(month.count) / CGFloat(maxCount) * 100)
                                            : 8
                                    )
                                
                                Text(month.label)
                                    .font(RankdTypography.caption)
                                    .foregroundStyle(RankdColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 140)
                    .animation(RankdMotion.reveal, value: animateCharts)
                    
                    // Most active month
                    if let mostActive = monthlyData.max(by: { $0.count < $1.count }), mostActive.count > 0 {
                        Text("Most active: \(mostActive.fullLabel) (\(mostActive.count) items)")
                            .font(RankdTypography.caption)
                            .foregroundStyle(RankdColors.textSecondary)
                    }
                }
            }
        }
    }
    
    // MARK: - G. Fun Insights
    
    private var funInsights: some View {
        VStack(spacing: RankdSpacing.sm) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(RankdColors.warning)
                Text("Insights")
                    .font(RankdTypography.headingMedium)
                    .foregroundStyle(RankdColors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, RankdSpacing.md)
            
            let insights = computeInsights()
            
            if insights.isEmpty {
                Text("Rank more items to unlock insights!")
                    .font(RankdTypography.bodyMedium)
                    .foregroundStyle(RankdColors.textSecondary)
                    .padding(RankdSpacing.md)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: RankdSpacing.sm) {
                    ForEach(Array(insights.prefix(4).enumerated()), id: \.offset) { _, insight in
                        InsightCard(icon: insight.icon, text: insight.text)
                    }
                }
                .padding(.horizontal, RankdSpacing.md)
            }
        }
        .padding(.bottom, RankdSpacing.md)
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
            RankdColors.brand,
            RankdColors.brand.opacity(0.65),
            RankdColors.tierGood.opacity(0.7),
            RankdColors.tierMedium.opacity(0.7),
            RankdColors.textTertiary,
            RankdColors.brand.opacity(0.45),
            RankdColors.tierBad.opacity(0.5),
            RankdColors.textSecondary
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
        VStack(spacing: RankdSpacing.xxs) {
            Image(systemName: icon)
                .font(RankdTypography.caption)
                .foregroundStyle(RankdColors.textSecondary)
            Text("\(value)")
                .font(RankdTypography.headingMedium)
                .foregroundStyle(RankdColors.textPrimary)
            Text(label)
                .font(RankdTypography.caption)
                .foregroundStyle(RankdColors.textSecondary)
        }
    }
}

private struct StatsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(spacing: RankdSpacing.sm) {
            HStack(spacing: RankdSpacing.xs) {
                Image(systemName: icon)
                    .foregroundStyle(RankdColors.brand)
                Text(title)
                    .font(RankdTypography.headingMedium)
                    .foregroundStyle(RankdColors.textPrimary)
                Spacer()
            }
            
            content
        }
        .padding(RankdSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: RankdRadius.lg)
                .fill(RankdColors.surfacePrimary)
        )
        .padding(.horizontal, RankdSpacing.md)
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
        HStack(spacing: RankdSpacing.xs) {
            Text(name)
                .font(RankdTypography.caption)
                .foregroundStyle(RankdColors.textSecondary)
                .frame(width: 80, alignment: .trailing)
                .lineLimit(1)
            
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: RankdRadius.sm)
                    .fill(color.opacity(0.7))
                    .frame(
                        width: animate
                            ? max(4, geo.size.width * CGFloat(count) / CGFloat(maxCount))
                            : 4
                    )
            }
            .frame(height: 22)
            .animation(RankdMotion.reveal, value: animate)
            
            Text("\(count)")
                .font(RankdTypography.labelMedium)
                .foregroundStyle(RankdColors.textPrimary)
                .frame(width: 24, alignment: .trailing)
            
            Text("\(percentage)%")
                .font(RankdTypography.caption)
                .foregroundStyle(RankdColors.textSecondary)
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
        HStack(spacing: RankdSpacing.xs) {
            Text(decade)
                .font(RankdTypography.labelMedium)
                .foregroundStyle(RankdColors.textPrimary)
                .frame(width: 50, alignment: .trailing)
            
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: RankdRadius.sm)
                    .fill(RankdColors.brand.opacity(0.45))
                    .frame(
                        width: animate
                            ? max(4, geo.size.width * CGFloat(count) / CGFloat(maxCount))
                            : 4
                    )
            }
            .frame(height: 22)
            .animation(RankdMotion.reveal, value: animate)
            
            Text("\(count)")
                .font(RankdTypography.labelMedium)
                .foregroundStyle(RankdColors.textPrimary)
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
                    RoundedRectangle(cornerRadius: RankdRadius.sm)
                        .fill(RankdColors.tierGood.opacity(0.7))
                        .frame(width: animate ? geo.size.width * CGFloat(good) / CGFloat(max(total, 1)) : 0)
                }
                if medium > 0 {
                    RoundedRectangle(cornerRadius: RankdRadius.sm)
                        .fill(RankdColors.tierMedium.opacity(0.7))
                        .frame(width: animate ? geo.size.width * CGFloat(medium) / CGFloat(max(total, 1)) : 0)
                }
                if bad > 0 {
                    RoundedRectangle(cornerRadius: RankdRadius.sm)
                        .fill(RankdColors.tierBad.opacity(0.7))
                        .frame(width: animate ? geo.size.width * CGFloat(bad) / CGFloat(max(total, 1)) : 0)
                }
            }
        }
        .frame(height: 28)
        .clipShape(RoundedRectangle(cornerRadius: RankdRadius.sm))
        .animation(RankdMotion.reveal, value: animate)
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
        HStack(spacing: RankdSpacing.xs) {
            Circle()
                .fill(RankdColors.tierColor(tier).opacity(0.7))
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(tier.rawValue)
                    .font(RankdTypography.labelMedium)
                    .foregroundStyle(RankdColors.textPrimary)
                Text("\(count) (\(percentage)%)")
                    .font(RankdTypography.caption)
                    .foregroundStyle(RankdColors.textSecondary)
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
        VStack(alignment: .leading, spacing: RankdSpacing.xs) {
            HStack(spacing: RankdSpacing.xxs) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(RankdTypography.caption)
                Text(label)
                    .font(RankdTypography.caption)
                    .foregroundStyle(RankdColors.textSecondary)
            }
            
            Text(title)
                .font(RankdTypography.labelMedium)
                .foregroundStyle(RankdColors.textPrimary)
                .lineLimit(2)
            
            Text(formatted)
                .font(RankdTypography.caption)
                .foregroundStyle(RankdColors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InsightCard: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: RankdSpacing.xs) {
            Image(systemName: icon)
                .foregroundStyle(RankdColors.brand)
                .font(RankdTypography.bodyMedium)
                .frame(width: 24)
            
            Text(text)
                .font(RankdTypography.caption)
                .foregroundStyle(RankdColors.textSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(RankdSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RankdRadius.md)
                .fill(RankdColors.brandSubtle)
        )
    }
}

#Preview {
    NavigationStack {
        StatsView()
    }
    .modelContainer(for: [RankedItem.self, WatchlistItem.self], inMemory: true)
}
