import SwiftUI
import UIKit

// MARK: - Share Card Format

enum ShareCardFormat: String, CaseIterable, Identifiable {
    case top4 = "Top 4"
    case top10 = "Top 10"
    case list = "List"
    
    var id: String { rawValue }
}

// MARK: - Card Data Model

/// Pre-computed data for rendering share cards (no async loading needed).
struct ShareCardData {
    let items: [RankedItem]
    let posterImages: [URL: UIImage]
    let movieCount: Int
    let tvCount: Int
    let tastePersonality: String
    
    /// Items to display for Top 4 format.
    var topFourItems: [RankedItem] {
        Array(items.sorted { $0.rank < $1.rank }.prefix(4))
    }
    
    /// Items to display for Top 10 format.
    var topTenItems: [RankedItem] {
        Array(items.sorted { $0.rank < $1.rank }.prefix(10))
    }
    
    /// Get pre-loaded poster image for an item.
    func posterImage(for item: RankedItem) -> UIImage? {
        guard let url = item.posterURL else { return nil }
        return posterImages[url]
    }
    
    /// Stats string like "42 movies · 12 TV shows"
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

private enum CardColors {
    static let gradientTop = Color(red: 0.102, green: 0.102, blue: 0.180)       // #1a1a2e
    static let gradientMiddle = Color(red: 0.086, green: 0.129, blue: 0.243)     // #16213e
    static let gradientBottom = Color(red: 0.059, green: 0.204, blue: 0.376)     // #0f3460
    static let accent = Color(red: 1.0, green: 0.584, blue: 0.0)                 // #FF9500
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
    
    private let cardWidth: CGFloat = 1080
    private let cardHeight: CGFloat = 1920
    
    var body: some View {
        ZStack {
            // Background
            CardColors.backgroundGradient
            
            // Subtle pattern overlay
            VStack {
                Spacer()
                Circle()
                    .fill(CardColors.accent.opacity(0.06))
                    .frame(width: 600, height: 600)
                    .offset(x: 200, y: 200)
            }
            
            // Content
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 120)
                
                // Header
                headerSection
                
                Spacer()
                    .frame(height: 64)
                
                // Poster Grid
                posterGrid
                
                Spacer()
                    .frame(height: 64)
                
                // Taste personality
                if !data.tastePersonality.isEmpty && data.tastePersonality != "Getting Started" {
                    tasteBadge
                    Spacer()
                        .frame(height: 32)
                }
                
                // Stats
                statsBar
                
                Spacer()
                
                // Branding
                brandingFooter
                
                Spacer()
                    .frame(height: 80)
            }
            .padding(.horizontal, 72)
        }
        .frame(width: cardWidth, height: cardHeight)
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Decorative line
            RoundedRectangle(cornerRadius: 2)
                .fill(CardColors.accent)
                .frame(width: 48, height: 4)
            
            Text("My Top 4")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(CardColors.primaryText)
                .tracking(1)
        }
    }
    
    private var posterGrid: some View {
        let items = data.topFourItems
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
        VStack(spacing: 16) {
            ZStack(alignment: .topLeading) {
                // Poster image
                if let image = data.posterImage(for: item) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: width, height: height)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    posterPlaceholder(item: item, width: width, height: height)
                }
                
                // Rank badge
                rankBadge(rank: rank)
                    .padding(12)
            }
            .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
            
            // Title + year + tier
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Text(item.tier.emoji)
                        .font(.system(size: 20))
                    Text(item.title)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(CardColors.primaryText)
                        .lineLimit(1)
                }
                
                if let year = item.year {
                    Text(year)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(CardColors.secondaryText)
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
        HStack(spacing: 12) {
            Text("🎬")
                .font(.system(size: 24))
            Text(data.tastePersonality)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(CardColors.accent)
        }
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
        HStack(spacing: 8) {
            Text("rankd")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(CardColors.tertiaryText)
        }
    }
    
    private func medalColor(for rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)   // Gold
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.78)  // Silver
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20)  // Bronze
        default: return Color(red: 0.5, green: 0.5, blue: 0.55)
        }
    }
}

// MARK: - Top 10 Card (Square — 1080x1080 for general sharing)

struct Top10CardView: View {
    let data: ShareCardData
    
    private let cardSize: CGFloat = 1080
    
    var body: some View {
        ZStack {
            // Background
            CardColors.backgroundGradient
            
            // Subtle accent glow
            Circle()
                .fill(CardColors.accent.opacity(0.05))
                .frame(width: 500, height: 500)
                .offset(x: -300, y: -300)
            
            // Content
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 64)
                
                // Header
                top10Header
                
                Spacer()
                    .frame(height: 40)
                
                // Rankings list
                rankingsList
                
                Spacer()
                    .frame(height: 36)
                
                // Stats
                top10StatsBar
                
                Spacer()
                    .frame(height: 24)
                
                // Branding
                top10Branding
                
                Spacer()
                    .frame(height: 48)
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
            
            Text("My Rankings")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(CardColors.primaryText)
                .tracking(0.5)
        }
    }
    
    private var rankingsList: some View {
        let items = data.topTenItems
        let thumbSize: CGFloat = 64
        
        return VStack(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 16) {
                    // Rank number
                    Text("\(index + 1)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(index < 3 ? medalColorForRank(index + 1) : CardColors.secondaryText)
                        .frame(width: 36, alignment: .trailing)
                    
                    // Poster thumbnail
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
                    
                    // Title + year
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
                    
                    // Tier emoji
                    Text(item.tier.emoji)
                        .font(.system(size: 20))
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(index % 2 == 0 ? Color.white.opacity(0.04) : Color.clear)
                )
            }
            
            // Empty slot rows if fewer than 10
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
            // Taste personality
            if !data.tastePersonality.isEmpty && data.tastePersonality != "Getting Started" {
                HStack(spacing: 6) {
                    Text("🎬")
                        .font(.system(size: 18))
                    Text(data.tastePersonality)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(CardColors.accent)
                }
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
