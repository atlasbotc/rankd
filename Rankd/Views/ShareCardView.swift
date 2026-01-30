import SwiftUI
import UIKit

// MARK: - Share Card Format

enum ShareCardFormat: String, CaseIterable, Identifiable {
    case top4Movies = "Top 4 Movies"
    case top4Shows = "Top 4 Shows"
    case top10Movies = "Top 10 Movies"
    case top10Shows = "Top 10 Shows"
    case list = "List"
    
    var id: String { rawValue }
    
    var isTop4: Bool {
        self == .top4Movies || self == .top4Shows
    }
    
    var isTop10: Bool {
        self == .top10Movies || self == .top10Shows
    }
    
    var mediaFilter: MediaType? {
        switch self {
        case .top4Movies, .top10Movies: return .movie
        case .top4Shows, .top10Shows: return .tv
        case .list: return nil
        }
    }
    
    var cardTitle: String {
        switch self {
        case .top4Movies: return "My Top 4 Movies"
        case .top4Shows: return "My Top 4 Shows"
        case .top10Movies: return "My Top 10 Movies"
        case .top10Shows: return "My Top 10 Shows"
        case .list: return "My Rankings"
        }
    }
}

// MARK: - Card Data Model

/// Pre-computed data for rendering share cards (no async loading needed).
struct ShareCardData {
    let items: [RankedItem]
    let posterImages: [URL: UIImage]
    let movieCount: Int
    let tvCount: Int
    let tastePersonality: String
    
    var topFourItems: [RankedItem] {
        Array(items.sorted { $0.rank < $1.rank }.prefix(4))
    }
    
    var topTenItems: [RankedItem] {
        Array(items.sorted { $0.rank < $1.rank }.prefix(10))
    }
    
    func topFourItems(for mediaType: MediaType) -> [RankedItem] {
        Array(items.filter { $0.mediaType == mediaType }.sorted { $0.rank < $1.rank }.prefix(4))
    }
    
    func topTenItems(for mediaType: MediaType) -> [RankedItem] {
        Array(items.filter { $0.mediaType == mediaType }.sorted { $0.rank < $1.rank }.prefix(10))
    }
    
    func filteredItems(for format: ShareCardFormat) -> [RankedItem] {
        guard let mediaType = format.mediaFilter else {
            return items.sorted { $0.rank < $1.rank }
        }
        let filtered = items.filter { $0.mediaType == mediaType }.sorted { $0.rank < $1.rank }
        if format.isTop4 {
            return Array(filtered.prefix(4))
        } else {
            return Array(filtered.prefix(10))
        }
    }
    
    func posterImage(for item: RankedItem) -> UIImage? {
        guard let url = item.posterURL else { return nil }
        return posterImages[url]
    }
    
    var statsString: String {
        var parts: [String] = []
        if movieCount > 0 {
            parts.append("\(movieCount) movie\(movieCount == 1 ? "" : "s") ranked")
        }
        if tvCount > 0 {
            parts.append("\(tvCount) TV show\(tvCount == 1 ? "" : "s") ranked")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Card Color Constants
// These are for EXPORTED images only — not in-app UI.
// They intentionally use their own palette separate from the design system.

private enum CardColors {
    static let gradientTop = Color(red: 0.102, green: 0.102, blue: 0.180)
    static let gradientMiddle = Color(red: 0.086, green: 0.129, blue: 0.243)
    static let gradientBottom = Color(red: 0.059, green: 0.204, blue: 0.376)
    static let accent = Color(red: 1.0, green: 0.584, blue: 0.0)
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.7)
    static let tertiaryText = Color.white.opacity(0.5)
    
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [gradientTop, gradientMiddle, gradientBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Top 4 Card (Portrait — 1080x1920 for IG Stories)

struct Top4CardView: View {
    let data: ShareCardData
    let format: ShareCardFormat
    
    private let cardWidth: CGFloat = 1080
    private let cardHeight: CGFloat = 1920
    
    var body: some View {
        ZStack {
            CardColors.backgroundGradient
            
            VStack {
                Spacer()
                Circle()
                    .fill(CardColors.accent.opacity(0.06))
                    .frame(width: 600, height: 600)
                    .offset(x: 200, y: 200)
            }
            
            VStack(spacing: 0) {
                Spacer().frame(height: 120)
                headerSection
                Spacer().frame(height: 64)
                posterGrid
                Spacer().frame(height: 64)
                
                if !data.tastePersonality.isEmpty && data.tastePersonality != "Getting Started" {
                    tasteBadge
                    Spacer().frame(height: 32)
                }
                
                statsBar
                Spacer()
                brandingFooter
                Spacer().frame(height: 80)
            }
            .padding(.horizontal, 72)
        }
        .frame(width: cardWidth, height: cardHeight)
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 2)
                .fill(CardColors.accent)
                .frame(width: 48, height: 4)
            
            Text(format.cardTitle)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(CardColors.primaryText)
                .tracking(1)
        }
    }
    
    private var posterGrid: some View {
        let items = data.filteredItems(for: format)
        let gridSpacing: CGFloat = 24
        let posterWidth = (cardWidth - 72 * 2 - gridSpacing) / 2
        let posterHeight = posterWidth * 1.5
        
        return VStack(spacing: gridSpacing) {
            HStack(spacing: gridSpacing) {
                if items.count > 0 {
                    posterCard(item: items[0], rank: 1, width: posterWidth, height: posterHeight)
                } else {
                    emptyPosterSlot(width: posterWidth, height: posterHeight)
                }
                if items.count > 1 {
                    posterCard(item: items[1], rank: 2, width: posterWidth, height: posterHeight)
                } else {
                    emptyPosterSlot(width: posterWidth, height: posterHeight)
                }
            }
            HStack(spacing: gridSpacing) {
                if items.count > 2 {
                    posterCard(item: items[2], rank: 3, width: posterWidth, height: posterHeight)
                } else {
                    emptyPosterSlot(width: posterWidth, height: posterHeight)
                }
                if items.count > 3 {
                    posterCard(item: items[3], rank: 4, width: posterWidth, height: posterHeight)
                } else {
                    emptyPosterSlot(width: posterWidth, height: posterHeight)
                }
            }
        }
    }
    
    private func posterCard(item: RankedItem, rank: Int, width: CGFloat, height: CGFloat) -> some View {
        let score = RankedItem.calculateScore(for: item, allItems: data.items)
        
        return VStack(spacing: 16) {
            ZStack(alignment: .topLeading) {
                if let image = data.posterImage(for: item) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: width, height: height)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    posterPlaceholder(item: item, width: width, height: height)
                }
                
                rankBadge(rank: rank)
                    .padding(12)
            }
            .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
            
            VStack(spacing: 6) {
                Text(item.title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(CardColors.primaryText)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if let year = item.year {
                        Text(year)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(CardColors.secondaryText)
                    }
                    
                    Text(String(format: "%.1f", score))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(RankdColors.tierColor(item.tier))
                        )
                }
            }
        }
        .frame(width: width)
    }
    
    private func emptyPosterSlot(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .frame(width: width, height: height)
                .overlay {
                    Image(systemName: "film")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.white.opacity(0.15))
                }
            
            Text(" ")
                .font(.system(size: 24))
        }
        .frame(width: width)
    }
    
    private func posterPlaceholder(item: RankedItem, width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: width, height: height)
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: item.mediaType == .movie ? "film" : "tv")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.white.opacity(0.3))
                    Text(item.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
            }
    }
    
    private func rankBadge(rank: Int) -> some View {
        ZStack {
            Circle()
                .fill(medalColor(for: rank))
                .frame(width: 44, height: 44)
                .shadow(color: medalColor(for: rank).opacity(0.6), radius: 8, y: 4)
            
            Text("#\(rank)")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
        }
    }
    
    private var tasteBadge: some View {
        Text(data.tastePersonality)
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(CardColors.accent)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(CardColors.accent.opacity(0.15))
                    .overlay(
                        Capsule()
                            .strokeBorder(CardColors.accent.opacity(0.3), lineWidth: 1)
                    )
            )
    }
    
    private var statsBar: some View {
        Text(data.statsString)
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(CardColors.secondaryText)
    }
    
    private var brandingFooter: some View {
        Text("rankd")
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundStyle(CardColors.tertiaryText)
    }
    
    private func medalColor(for rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.78)
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20)
        default: return Color(red: 0.5, green: 0.5, blue: 0.55)
        }
    }
}

// MARK: - Top 10 Card (Square — 1080x1080 for general sharing)

struct Top10CardView: View {
    let data: ShareCardData
    let format: ShareCardFormat
    
    private let cardSize: CGFloat = 1080
    
    var body: some View {
        ZStack {
            CardColors.backgroundGradient
            
            Circle()
                .fill(CardColors.accent.opacity(0.05))
                .frame(width: 500, height: 500)
                .offset(x: -300, y: -300)
            
            VStack(spacing: 0) {
                Spacer().frame(height: 64)
                top10Header
                Spacer().frame(height: 40)
                rankingsList
                Spacer().frame(height: 36)
                top10StatsBar
                Spacer().frame(height: 24)
                top10Branding
                Spacer().frame(height: 48)
            }
            .padding(.horizontal, 64)
        }
        .frame(width: cardSize, height: cardSize)
    }
    
    private var top10Header: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(CardColors.accent)
                .frame(width: 40, height: 3)
            
            Text(format.cardTitle)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(CardColors.primaryText)
                .tracking(0.5)
        }
    }
    
    private var rankingsList: some View {
        let items = data.filteredItems(for: format)
        let thumbSize: CGFloat = 64
        
        return VStack(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 16) {
                    Text("\(index + 1)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(index < 3 ? medalColorForRank(index + 1) : CardColors.secondaryText)
                        .frame(width: 36, alignment: .trailing)
                    
                    if let image = data.posterImage(for: item) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: thumbSize, height: thumbSize)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: thumbSize, height: thumbSize)
                            .overlay {
                                Image(systemName: item.mediaType == .movie ? "film" : "tv")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.white.opacity(0.2))
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(CardColors.primaryText)
                            .lineLimit(1)
                        
                        if let year = item.year {
                            Text(year)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(CardColors.secondaryText)
                        }
                    }
                    
                    Spacer()
                    
                    // Score badge
                    let score = RankedItem.calculateScore(for: item, allItems: data.items)
                    Text(String(format: "%.1f", score))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(RankdColors.tierColor(item.tier))
                        )
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(index % 2 == 0 ? Color.white.opacity(0.04) : Color.clear)
                )
            }
            
            if items.count < 10 {
                ForEach(items.count..<min(10, items.count + 3), id: \.self) { index in
                    HStack(spacing: 16) {
                        Text("\(index + 1)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(CardColors.tertiaryText)
                            .frame(width: 36, alignment: .trailing)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.04))
                            .frame(width: thumbSize, height: thumbSize)
                        
                        Text("—")
                            .font(.system(size: 20))
                            .foregroundStyle(CardColors.tertiaryText)
                        
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
                }
            }
        }
    }
    
    private var top10StatsBar: some View {
        HStack(spacing: 24) {
            if !data.tastePersonality.isEmpty && data.tastePersonality != "Getting Started" {
                Text(data.tastePersonality)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(CardColors.accent)
            }
            
            Text("•")
                .foregroundStyle(CardColors.tertiaryText)
                .font(.system(size: 18))
            
            Text(data.statsString)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(CardColors.secondaryText)
        }
    }
    
    private var top10Branding: some View {
        Text("rankd")
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundStyle(CardColors.tertiaryText)
    }
    
    private func medalColorForRank(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.78)
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20)
        default: return CardColors.secondaryText
        }
    }
}
