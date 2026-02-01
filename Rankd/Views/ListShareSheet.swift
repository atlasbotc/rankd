import SwiftUI
import UIKit

struct ListShareSheet: View {
    let list: CustomList
    
    @State private var isLoading = true
    @State private var generatedImage: UIImage?
    @State private var showShareSheet = false
    @State private var savedToPhotos = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    cardPreview
                        .padding(.horizontal, RankdSpacing.md)
                        .padding(.top, RankdSpacing.md)
                }
                
                actionButtons
                    .padding(.horizontal, RankdSpacing.md)
                    .padding(.vertical, RankdSpacing.md)
                    .background(RankdColors.surfacePrimary)
            }
            .background(RankdColors.background)
            .navigationTitle("Share List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(RankdColors.textSecondary)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = generatedImage {
                    ActivityViewController(activityItems: [image])
                }
            }
            .task {
                await generateListCard()
            }
        }
    }
    
    // MARK: - Card Preview
    
    private var cardPreview: some View {
        Group {
            if isLoading {
                RoundedRectangle(cornerRadius: RankdRadius.lg)
                    .fill(RankdColors.surfacePrimary)
                    .aspectRatio(1080.0 / 1920.0, contentMode: .fit)
                    .overlay {
                        VStack(spacing: RankdSpacing.sm) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(RankdColors.textTertiary)
                            Text("Generating card...")
                                .font(RankdTypography.bodyMedium)
                                .foregroundStyle(RankdColors.textSecondary)
                        }
                    }
            } else if let image = generatedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: RankdRadius.lg))
                    .shadow(color: RankdShadow.elevated, radius: RankdShadow.elevatedRadius, y: RankdShadow.elevatedY)
                    .padding(.vertical, RankdSpacing.xs)
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: RankdSpacing.sm) {
            Button {
                if let image = generatedImage {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    withAnimation(RankdMotion.normal) { savedToPhotos = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(RankdMotion.normal) { savedToPhotos = false }
                    }
                }
            } label: {
                HStack(spacing: RankdSpacing.xs) {
                    Image(systemName: savedToPhotos ? "checkmark" : "arrow.down.to.line")
                        .font(RankdTypography.headingSmall)
                    Text(savedToPhotos ? "Saved!" : "Save")
                        .font(RankdTypography.headingSmall)
                }
                .foregroundStyle(RankdColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: RankdRadius.md)
                        .fill(RankdColors.surfaceSecondary)
                )
            }
            .buttonStyle(.plain)
            .disabled(generatedImage == nil || isLoading)
            
            Button {
                showShareSheet = true
            } label: {
                HStack(spacing: RankdSpacing.xs) {
                    Image(systemName: "square.and.arrow.up")
                        .font(RankdTypography.headingSmall)
                    Text("Share")
                        .font(RankdTypography.headingSmall)
                }
                .foregroundStyle(RankdColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: RankdRadius.md)
                        .fill(RankdColors.accent)
                )
            }
            .buttonStyle(.plain)
            .disabled(generatedImage == nil || isLoading)
        }
    }
    
    // MARK: - Card Generation
    
    @MainActor
    private func generateListCard() async {
        isLoading = true
        
        let sortedItems = list.sortedItems
        let displayItems = Array(sortedItems.prefix(10))
        
        let urls = displayItems.compactMap { $0.posterURL }
        let posterImages = await PosterCache.shared.preload(urls: urls)
        
        let cardData = ListCardData(
            name: list.name,
            emoji: list.emoji,
            listDescription: list.listDescription,
            items: displayItems,
            totalCount: list.itemCount,
            posterImages: posterImages
        )
        
        let cardView = ListCardView(data: cardData)
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0
        renderer.proposedSize = .init(width: 1080, height: 1920)
        generatedImage = renderer.uiImage
        isLoading = false
    }
}

// MARK: - List Card Data

struct ListCardData {
    let name: String
    let emoji: String
    let listDescription: String
    let items: [CustomListItem]
    let totalCount: Int
    let posterImages: [URL: UIImage]
    
    func posterImage(for item: CustomListItem) -> UIImage? {
        guard let url = item.posterURL else { return nil }
        return posterImages[url]
    }
}

// MARK: - List Card View (1080×1920) — Exported image, keeps its own gradient design

struct ListCardView: View {
    let data: ListCardData
    
    private let cardWidth: CGFloat = 1080
    private let cardHeight: CGFloat = 1920
    
    private enum Colors {
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
    
    var body: some View {
        ZStack {
            Colors.backgroundGradient
            
            VStack {
                Spacer()
                Circle()
                    .fill(Colors.accent.opacity(0.06))
                    .frame(width: 600, height: 600)
                    .offset(x: 200, y: 200)
            }
            
            VStack(spacing: 0) {
                Spacer().frame(height: 100)
                
                headerSection
                
                Spacer().frame(height: 48)
                
                itemsList
                
                Spacer().frame(height: 40)
                
                if data.totalCount > data.items.count {
                    Text("+ \(data.totalCount - data.items.count) more")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Colors.secondaryText)
                } else {
                    Text("\(data.totalCount) item\(data.totalCount == 1 ? "" : "s")")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Colors.secondaryText)
                }
                
                Spacer()
                
                Text("marqui")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Colors.tertiaryText)
                
                Spacer().frame(height: 80)
            }
            .padding(.horizontal, 64)
        }
        .frame(width: cardWidth, height: cardHeight)
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Colors.accent)
                .frame(width: 48, height: 4)
            
            Text(data.emoji)
                .font(.system(size: 56))
            
            Text(data.name)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(Colors.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            if !data.listDescription.isEmpty {
                Text(data.listDescription)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
    }
    
    private var itemsList: some View {
        let thumbSize: CGFloat = 64
        
        return VStack(spacing: 8) {
            ForEach(Array(data.items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 16) {
                    Text("\(index + 1)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(index < 3 ? medalColor(for: index + 1) : Colors.secondaryText)
                        .frame(width: 40, alignment: .trailing)
                    
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
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Colors.primaryText)
                            .lineLimit(1)
                        
                        if let year = item.year {
                            Text(year)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Colors.secondaryText)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(index % 2 == 0 ? Color.white.opacity(0.04) : Color.clear)
                )
            }
        }
    }
    
    private func medalColor(for rank: Int) -> Color {
        switch rank {
        case 1: return RankdColors.medalGold
        case 2: return RankdColors.medalSilver
        case 3: return RankdColors.medalBronze
        default: return Colors.secondaryText
        }
    }
}
