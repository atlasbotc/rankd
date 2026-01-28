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
            VStack(spacing: 24) {
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
            .padding(.vertical)
        }
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
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animateCharts = true
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundStyle(.orange.opacity(0.5))
            
            Text("No Stats Yet")
                .font(.title2.bold())
            
            Text("Start ranking movies and TV shows to see your viewing patterns and insights.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 60)
    }
    
    // MARK: - A. Summary Header
    
    private var summaryHeader: some View {
        VStack(spacing: 16) {
            // Big number
            Text("\(rankedItems.count)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(.orange)
            
            Text("Items Ranked")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Sub-stats row
            HStack(spacing: 24) {
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
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
    
    // MARK: - B. Genre Distribution
    
    private var genreDistribution: some View {
        StatsSection(title: "Genre Distribution", icon: "theatermasks") {
            if isBackfilling && itemsWithGenres.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Analyzing your taste...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if itemsWithGenres.isEmpty {
                Text("Rank more to see genre stats")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
            } else {
                let genreCounts = computeGenreCounts()
                let maxCount = genreCounts.first?.count ?? 1
                
                VStack(spacing: 10) {
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
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading more genre data...")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 4)
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
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
            } else {
                let maxCount = decades.first?.count ?? 1
                
                VStack(spacing: 10) {
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
            
            VStack(spacing: 20) {
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
                
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Text("Average Score:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f", avgScore))
                            .font(.subheadline.bold())
                        Text("/ 3.0")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    
                    Text(viewerInsight(avgScore: avgScore))
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                        .fontWeight(.medium)
                }
            }
        }
    }
    
    // MARK: - E. Watch Time
    
    private var watchTimeSection: some View {
        StatsSection(title: "Watch Time", icon: "clock") {
            if itemsWithRuntime.isEmpty {
                VStack(spacing: 8) {
                    Text("No runtime data available yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if isBackfilling {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Fetching runtime data...")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.vertical, 12)
            } else {
                let totalMinutes = itemsWithRuntime.reduce(0) { $0 + $1.runtimeMinutes }
                let days = totalMinutes / (60 * 24)
                let hours = (totalMinutes % (60 * 24)) / 60
                let minutes = totalMinutes % 60
                
                VStack(spacing: 16) {
                    // Total watch time
                    HStack(spacing: 4) {
                        if days > 0 {
                            Text("\(days)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(.orange)
                            Text("d")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(hours)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                        Text("h")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("\(minutes)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                        Text("m")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("Total estimated watch time")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    
                    if itemsWithRuntime.count < rankedItems.count {
                        Text("\(itemsWithRuntime.count) of \(rankedItems.count) items have runtime data")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    
                    Divider()
                    
                    // Longest & shortest
                    HStack(spacing: 16) {
                        if let longest = itemsWithRuntime.max(by: { $0.runtimeMinutes < $1.runtimeMinutes }) {
                            WatchTimeExtreme(
                                label: "Longest",
                                title: longest.title,
                                minutes: longest.runtimeMinutes,
                                icon: "arrow.up.circle.fill",
                                color: .orange
                            )
                        }
                        
                        if itemsWithRuntime.count > 1,
                           let shortest = itemsWithRuntime.min(by: { $0.runtimeMinutes < $1.runtimeMinutes }) {
                            WatchTimeExtreme(
                                label: "Shortest",
                                title: shortest.title,
                                minutes: shortest.runtimeMinutes,
                                icon: "arrow.down.circle.fill",
                                color: .blue
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
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                let maxCount = monthlyData.map(\.count).max() ?? 1
                
                VStack(spacing: 12) {
                    // Bar chart
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(monthlyData, id: \.label) { month in
                            VStack(spacing: 4) {
                                Text("\(month.count)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        month.count == maxCount
                                            ? Color.orange
                                            : Color.orange.opacity(0.4)
                                    )
                                    .frame(
                                        height: animateCharts
                                            ? max(8, CGFloat(month.count) / CGFloat(maxCount) * 100)
                                            : 8
                                    )
                                
                                Text(month.label)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 140)
                    .animation(.easeOut(duration: 0.8), value: animateCharts)
                    
                    // Most active month
                    if let mostActive = monthlyData.max(by: { $0.count < $1.count }), mostActive.count > 0 {
                        Text("Most active: \(mostActive.fullLabel) (\(mostActive.count) items)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - G. Fun Insights
    
    private var funInsights: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("Insights")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            
            let insights = computeInsights()
            
            if insights.isEmpty {
                Text("Rank more items to unlock insights!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Array(insights.prefix(4).enumerated()), id: \.offset) { _, insight in
                        InsightCard(icon: insight.icon, text: insight.text)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 16)
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
            return "You're a generous viewer 🎉"
        } else if avgScore >= 1.8 {
            return "You're a balanced viewer ⚖️"
        } else {
            return "You're a critical viewer 🧐"
        }
    }
    
    private func genreColor(for index: Int) -> Color {
        let colors: [Color] = [
            .orange, .blue, .purple, .green, .pink, .cyan, .yellow, .red
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
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.title3.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct StatsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(.orange)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            
            content
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
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
        HStack(spacing: 10) {
            Text(name)
                .font(.caption)
                .frame(width: 80, alignment: .trailing)
                .lineLimit(1)
            
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.7))
                    .frame(
                        width: animate
                            ? max(4, geo.size.width * CGFloat(count) / CGFloat(maxCount))
                            : 4
                    )
            }
            .frame(height: 22)
            .animation(.easeOut(duration: 0.6), value: animate)
            
            Text("\(count)")
                .font(.caption.bold())
                .frame(width: 24, alignment: .trailing)
            
            Text("\(percentage)%")
                .font(.caption2)
                .foregroundStyle(.secondary)
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
        HStack(spacing: 10) {
            Text(decade)
                .font(.caption.bold())
                .frame(width: 50, alignment: .trailing)
            
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.cyan.opacity(0.6))
                    .frame(
                        width: animate
                            ? max(4, geo.size.width * CGFloat(count) / CGFloat(maxCount))
                            : 4
                    )
            }
            .frame(height: 22)
            .animation(.easeOut(duration: 0.6), value: animate)
            
            Text("\(count)")
                .font(.caption.bold())
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
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.green.opacity(0.7))
                        .frame(width: animate ? geo.size.width * CGFloat(good) / CGFloat(max(total, 1)) : 0)
                }
                if medium > 0 {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.yellow.opacity(0.7))
                        .frame(width: animate ? geo.size.width * CGFloat(medium) / CGFloat(max(total, 1)) : 0)
                }
                if bad > 0 {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.red.opacity(0.7))
                        .frame(width: animate ? geo.size.width * CGFloat(bad) / CGFloat(max(total, 1)) : 0)
                }
            }
        }
        .frame(height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .animation(.easeOut(duration: 0.8), value: animate)
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
    
    private var tierColor: Color {
        switch tier {
        case .good: return .green
        case .medium: return .yellow
        case .bad: return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tierColor.opacity(0.7))
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(tier.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                Text("\(count) (\(percentage)%)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
            
            Text(formatted)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InsightCard: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.orange)
                .font(.callout)
                .frame(width: 24)
            
            Text(text)
                .font(.caption)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.08))
        )
    }
}

#Preview {
    NavigationStack {
        StatsView()
    }
    .modelContainer(for: [RankedItem.self, WatchlistItem.self], inMemory: true)
}
