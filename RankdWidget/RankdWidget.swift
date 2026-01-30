import WidgetKit
import SwiftUI

// MARK: - Shared Data Model (duplicated from app — widget can't import app module)

struct WidgetItem: Codable, Identifiable {
    let id: String
    let title: String
    let score: Double
    let tier: String     // "Good", "Medium", "Bad"
    let posterURL: String?
    let rank: Int
}

// MARK: - Design Tokens (match DesignSystem.swift — widget can't import app module)
// Verified against Rankd/Theme/DesignSystem.swift values:

enum WidgetColors {
    // Background — warm off-white: #F5F3F0
    static let background = Color(red: 0.96, green: 0.95, blue: 0.94)
    // Card surface: #FDFAF8
    static let surfacePrimary = Color(red: 0.99, green: 0.98, blue: 0.97)
    // Elevated surface: #EDEBE8
    static let surfaceSecondary = Color(red: 0.93, green: 0.92, blue: 0.91)
    // Text primary: #212125
    static let textPrimary = Color(red: 0.13, green: 0.13, blue: 0.15)
    // Text secondary: #212125 @ 65%
    static let textSecondary = Color(red: 0.13, green: 0.13, blue: 0.15).opacity(0.65)
    // Text tertiary: #212125 @ 40%
    static let textTertiary = Color(red: 0.13, green: 0.13, blue: 0.15).opacity(0.40)
    // Brand / accent — muted slate blue: #596F94
    static let brand = Color(red: 0.35, green: 0.45, blue: 0.58)
    // Tier colors (muted for light backgrounds)
    static let tierGood = Color(red: 0.30, green: 0.65, blue: 0.45)
    static let tierMedium = Color(red: 0.75, green: 0.65, blue: 0.30)
    static let tierBad = Color(red: 0.75, green: 0.35, blue: 0.35)
    
    static func tierColor(_ tier: String) -> Color {
        switch tier {
        case "Good": return tierGood
        case "Medium": return tierMedium
        case "Bad": return tierBad
        default: return brand
        }
    }
}

// MARK: - Timeline Provider

struct RankdTimelineProvider: TimelineProvider {
    typealias Entry = RankdWidgetEntry
    
    func placeholder(in context: Context) -> RankdWidgetEntry {
        RankdWidgetEntry(date: Date(), items: sampleItems)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (RankdWidgetEntry) -> Void) {
        let items = loadItems()
        completion(RankdWidgetEntry(date: Date(), items: items.isEmpty ? sampleItems : items))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<RankdWidgetEntry>) -> Void) {
        let items = loadItems()
        let entry = RankdWidgetEntry(date: Date(), items: items)
        
        // Refresh every 4 hours
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadItems() -> [WidgetItem] {
        guard let defaults = UserDefaults(suiteName: "group.com.rankd.shared"),
              let data = defaults.data(forKey: "widget_top_items") else {
            return []
        }
        return (try? JSONDecoder().decode([WidgetItem].self, from: data)) ?? []
    }
    
    private var sampleItems: [WidgetItem] {
        [
            WidgetItem(id: "1", title: "The Shawshank Redemption", score: 9.8, tier: "Good", posterURL: nil, rank: 1),
            WidgetItem(id: "2", title: "Parasite", score: 9.5, tier: "Good", posterURL: nil, rank: 2),
            WidgetItem(id: "3", title: "The Dark Knight", score: 9.2, tier: "Good", posterURL: nil, rank: 3),
            WidgetItem(id: "4", title: "Spirited Away", score: 9.0, tier: "Good", posterURL: nil, rank: 4),
            WidgetItem(id: "5", title: "Pulp Fiction", score: 8.8, tier: "Good", posterURL: nil, rank: 5),
            WidgetItem(id: "6", title: "Inception", score: 8.5, tier: "Good", posterURL: nil, rank: 6),
            WidgetItem(id: "7", title: "Whiplash", score: 8.2, tier: "Good", posterURL: nil, rank: 7),
            WidgetItem(id: "8", title: "Arrival", score: 7.9, tier: "Good", posterURL: nil, rank: 8),
            WidgetItem(id: "9", title: "Moonlight", score: 7.6, tier: "Medium", posterURL: nil, rank: 9),
            WidgetItem(id: "10", title: "Her", score: 7.3, tier: "Medium", posterURL: nil, rank: 10),
        ]
    }
}

// MARK: - Timeline Entry

struct RankdWidgetEntry: TimelineEntry {
    let date: Date
    let items: [WidgetItem]
}

// MARK: - Widget Views

// Small: Show #1 ranked item
struct RankdSmallView: View {
    let entry: RankdWidgetEntry
    
    private var topItem: WidgetItem? {
        entry.items.first
    }
    
    var body: some View {
        if let item = topItem {
            VStack(alignment: .leading, spacing: 6) {
                // Crown icon + "YOUR #1" label
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(WidgetColors.brand)
                    
                    Text("YOUR #1")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(WidgetColors.brand)
                }
                
                Spacer()
                
                // Title
                Text(item.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(WidgetColors.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                
                // Score badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(WidgetColors.tierColor(item.tier))
                        .frame(width: 8, height: 8)
                    
                    Text(String(format: "%.1f", item.score))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetColors.textPrimary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(WidgetColors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        } else {
            emptyState
                .padding(12)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.number")
                .font(.system(size: 24))
                .foregroundStyle(WidgetColors.textTertiary)
            
            Text("No Rankings Yet")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(WidgetColors.textSecondary)
            
            Text("Add your first item")
                .font(.system(size: 11))
                .foregroundStyle(WidgetColors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Medium: Show Top 4 in a row
struct RankdMediumView: View {
    let entry: RankdWidgetEntry
    
    private var top4: [WidgetItem] {
        Array(entry.items.prefix(4))
    }
    
    var body: some View {
        if top4.isEmpty {
            emptyState
                .padding(16)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(WidgetColors.brand)
                    
                    Text("TOP RANKED")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(WidgetColors.brand)
                    
                    Spacer()
                }
                
                // Top 4 items in a row
                HStack(spacing: 8) {
                    ForEach(Array(top4.enumerated()), id: \.element.id) { index, item in
                        VStack(spacing: 4) {
                            // Poster placeholder with rank badge
                            ZStack(alignment: .topLeading) {
                                if let urlString = item.posterURL,
                                   let _ = URL(string: urlString) {
                                    // In widget, we use a colored placeholder
                                    // (AsyncImage not reliable in widgets)
                                    posterPlaceholder(for: item)
                                } else {
                                    posterPlaceholder(for: item)
                                }
                                
                                // Rank badge
                                Text("#\(item.rank)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(WidgetColors.brand)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .offset(x: 3, y: 3)
                            }
                            
                            // Title
                            Text(item.title)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(WidgetColors.textPrimary)
                                .lineLimit(1)
                            
                            // Score
                            Text(String(format: "%.1f", item.score))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(WidgetColors.tierColor(item.tier))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(12)
        }
    }
    
    private func posterPlaceholder(for item: WidgetItem) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(WidgetColors.surfaceSecondary)
            .aspectRatio(2.0/3.0, contentMode: .fit)
            .overlay {
                Image(systemName: "film")
                    .font(.system(size: 16))
                    .foregroundStyle(WidgetColors.textTertiary)
            }
    }
    
    private var emptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "list.number")
                .font(.system(size: 28))
                .foregroundStyle(WidgetColors.textTertiary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("No Rankings Yet")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WidgetColors.textSecondary)
                
                Text("Rate some movies to see your top picks here")
                    .font(.system(size: 12))
                    .foregroundStyle(WidgetColors.textTertiary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Large: Show Top 10 list
struct RankdLargeView: View {
    let entry: RankdWidgetEntry
    
    private var top10: [WidgetItem] {
        Array(entry.items.prefix(10))
    }
    
    var body: some View {
        if top10.isEmpty {
            emptyState
                .padding(16)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WidgetColors.brand)
                    
                    Text("TOP RANKINGS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WidgetColors.brand)
                    
                    Spacer()
                    
                    Text("\(top10.count) items")
                        .font(.system(size: 10))
                        .foregroundStyle(WidgetColors.textTertiary)
                }
                .padding(.bottom, 8)
                
                // List of items
                ForEach(Array(top10.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 8) {
                        // Rank number
                        Text("#\(item.rank)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(item.rank <= 3 ? WidgetColors.brand : WidgetColors.textTertiary)
                            .frame(width: 28, alignment: .leading)
                        
                        // Tier dot
                        Circle()
                            .fill(WidgetColors.tierColor(item.tier))
                            .frame(width: 6, height: 6)
                        
                        // Title
                        Text(item.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(WidgetColors.textPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Score
                        Text(String(format: "%.1f", item.score))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(WidgetColors.tierColor(item.tier))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(WidgetColors.tierColor(item.tier).opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .padding(.vertical, 3)
                    
                    if index < top10.count - 1 {
                        Divider()
                            .foregroundStyle(Color(red: 0.13, green: 0.13, blue: 0.15).opacity(0.08))
                    }
                }
            }
            .padding(14)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.number")
                .font(.system(size: 36))
                .foregroundStyle(WidgetColors.textTertiary)
            
            Text("No Rankings Yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(WidgetColors.textSecondary)
            
            Text("Start ranking movies and TV shows\nto see your top 10 here")
                .font(.system(size: 13))
                .foregroundStyle(WidgetColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Widget Entry View (dispatches by family)

struct RankdWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: RankdTimelineProvider.Entry
    
    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                RankdSmallView(entry: entry)
            case .systemMedium:
                RankdMediumView(entry: entry)
            case .systemLarge:
                RankdLargeView(entry: entry)
            default:
                RankdSmallView(entry: entry)
            }
        }
        .widgetURL(URL(string: "rankd://rankings"))
    }
}

// MARK: - Widget Configuration

struct RankdWidget: Widget {
    let kind: String = "RankdWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RankdTimelineProvider()) { entry in
            if #available(iOS 17.0, *) {
                RankdWidgetEntryView(entry: entry)
                    .containerBackground(WidgetColors.background, for: .widget)
            } else {
                RankdWidgetEntryView(entry: entry)
                    .background(WidgetColors.background)
            }
        }
        .configurationDisplayName("Top Rankings")
        .description("See your top ranked movies and TV shows at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    RankdWidget()
} timeline: {
    RankdWidgetEntry(date: Date(), items: [
        WidgetItem(id: "1", title: "The Shawshank Redemption", score: 9.8, tier: "Good", posterURL: nil, rank: 1)
    ])
}

#Preview("Medium", as: .systemMedium) {
    RankdWidget()
} timeline: {
    RankdWidgetEntry(date: Date(), items: [
        WidgetItem(id: "1", title: "The Shawshank Redemption", score: 9.8, tier: "Good", posterURL: nil, rank: 1),
        WidgetItem(id: "2", title: "Parasite", score: 9.5, tier: "Good", posterURL: nil, rank: 2),
        WidgetItem(id: "3", title: "The Dark Knight", score: 9.2, tier: "Good", posterURL: nil, rank: 3),
        WidgetItem(id: "4", title: "Spirited Away", score: 9.0, tier: "Good", posterURL: nil, rank: 4),
    ])
}

#Preview("Large", as: .systemLarge) {
    RankdWidget()
} timeline: {
    RankdWidgetEntry(date: Date(), items: [
        WidgetItem(id: "1", title: "The Shawshank Redemption", score: 9.8, tier: "Good", posterURL: nil, rank: 1),
        WidgetItem(id: "2", title: "Parasite", score: 9.5, tier: "Good", posterURL: nil, rank: 2),
        WidgetItem(id: "3", title: "The Dark Knight", score: 9.2, tier: "Good", posterURL: nil, rank: 3),
        WidgetItem(id: "4", title: "Spirited Away", score: 9.0, tier: "Good", posterURL: nil, rank: 4),
        WidgetItem(id: "5", title: "Pulp Fiction", score: 8.8, tier: "Good", posterURL: nil, rank: 5),
        WidgetItem(id: "6", title: "Inception", score: 8.5, tier: "Good", posterURL: nil, rank: 6),
        WidgetItem(id: "7", title: "Whiplash", score: 8.2, tier: "Good", posterURL: nil, rank: 7),
        WidgetItem(id: "8", title: "Arrival", score: 7.9, tier: "Good", posterURL: nil, rank: 8),
        WidgetItem(id: "9", title: "Moonlight", score: 7.6, tier: "Medium", posterURL: nil, rank: 9),
        WidgetItem(id: "10", title: "Her", score: 7.3, tier: "Medium", posterURL: nil, rank: 10),
    ])
}
