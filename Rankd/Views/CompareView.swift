import SwiftUI
import SwiftData

struct CompareView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [RankedItem]
    @State private var viewModel = RankingViewModel()
    @State private var currentPair: (RankedItem, RankedItem)?
    @State private var selectedTier: Tier?
    @State private var selectedMediaType: MediaType = .movie
    @State private var chosenItem: RankedItem?
    
    private var filteredItems: [RankedItem] {
        items.filter { $0.mediaType == selectedMediaType }
    }
    
    var availableTiers: [Tier] {
        Tier.allCases.filter { tier in
            filteredItems.filter { $0.tier == tier }.count >= 2
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Media type picker
                pillPicker
                    .padding(.top, RankdSpacing.xs)
                
                // Tier filter chips
                if !availableTiers.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: RankdSpacing.xs) {
                            FilterChip(title: "Any", isSelected: selectedTier == nil) {
                                selectedTier = nil
                                findNewPair()
                            }
                            
                            ForEach(availableTiers, id: \.self) { tier in
                                FilterChip(
                                    title: tier.rawValue,
                                    tierColor: RankdColors.tierColor(tier),
                                    isSelected: selectedTier == tier
                                ) {
                                    selectedTier = tier
                                    findNewPair()
                                }
                            }
                        }
                        .padding(.horizontal, RankdSpacing.md)
                        .padding(.vertical, RankdSpacing.sm)
                    }
                }
                
                if filteredItems.count < 2 {
                    // Not enough items
                    Spacer()
                    emptyState(
                        icon: "arrow.left.arrow.right",
                        title: "Need at least 2 items",
                        subtitle: "Add more \(selectedMediaType == .movie ? "movies" : "TV shows") to compare"
                    )
                    Spacer()
                } else if let pair = currentPair {
                    // Comparison view
                    VStack(spacing: RankdSpacing.lg) {
                        Text("Which is better?")
                            .font(RankdTypography.headingLarge)
                            .foregroundStyle(RankdColors.textPrimary)
                            .padding(.top, RankdSpacing.lg)
                        
                        HStack(spacing: RankdSpacing.md) {
                            CompareItemCard(
                                item: pair.0,
                                isChosen: chosenItem?.id == pair.0.id
                            ) {
                                selectWinner(pair.0, loser: pair.1)
                            }
                            
                            CompareItemCard(
                                item: pair.1,
                                isChosen: chosenItem?.id == pair.1.id
                            ) {
                                selectWinner(pair.1, loser: pair.0)
                            }
                        }
                        .padding(.horizontal, RankdSpacing.md)
                        
                        // Skip button
                        Button {
                            findNewPair()
                        } label: {
                            Text("Skip")
                                .font(RankdTypography.labelMedium)
                                .foregroundStyle(RankdColors.textTertiary)
                        }
                        .padding(.top, RankdSpacing.xs)
                        
                        Spacer()
                        
                        // Stats
                        VStack(spacing: RankdSpacing.xxs) {
                            Text("Comparisons help refine your rankings")
                                .font(RankdTypography.caption)
                                .foregroundStyle(RankdColors.textTertiary)
                        }
                        .padding(.bottom, RankdSpacing.lg)
                    }
                } else {
                    // All caught up
                    Spacer()
                    emptyState(
                        icon: "checkmark.circle",
                        title: "All caught up",
                        subtitle: "Add more items or select a different tier"
                    )
                    
                    Button {
                        selectedTier = nil
                        findNewPair()
                    } label: {
                        Text("Find More")
                            .font(RankdTypography.headingSmall)
                            .padding(.horizontal, RankdSpacing.lg)
                            .padding(.vertical, RankdSpacing.sm)
                            .background(RankdColors.brand)
                            .foregroundStyle(RankdColors.surfacePrimary)
                            .clipShape(RoundedRectangle(cornerRadius: RankdRadius.md))
                    }
                    .padding(.top, RankdSpacing.md)
                    
                    Spacer()
                }
            }
            .background(RankdColors.background)
            .navigationTitle("Compare")
            .onAppear {
                findNewPair()
            }
        }
    }
    
    // MARK: - Pill Picker
    
    private var pillPicker: some View {
        HStack(spacing: 0) {
            ForEach([MediaType.movie, MediaType.tv], id: \.self) { type in
                Button {
                    withAnimation(RankdMotion.fast) {
                        selectedMediaType = type
                        selectedTier = nil
                        findNewPair()
                    }
                } label: {
                    Text(type == .movie ? "Movies" : "TV Shows")
                        .font(RankdTypography.labelLarge)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RankdSpacing.sm)
                        .background(
                            selectedMediaType == type
                                ? RankdColors.brand
                                : Color.clear
                        )
                        .foregroundStyle(
                            selectedMediaType == type
                                ? RankdColors.surfacePrimary
                                : RankdColors.textTertiary
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .padding(RankdSpacing.xxs)
        .background(RankdColors.surfaceSecondary)
        .clipShape(Capsule())
        .padding(.horizontal, RankdSpacing.md)
    }
    
    // MARK: - Empty/Done State
    
    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: RankdSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(RankdColors.textQuaternary)
            
            Text(title)
                .font(RankdTypography.headingMedium)
                .foregroundStyle(RankdColors.textPrimary)
            
            Text(subtitle)
                .font(RankdTypography.bodyMedium)
                .foregroundStyle(RankdColors.textSecondary)
        }
    }
    
    // MARK: - Actions
    
    private func findNewPair() {
        if let tier = selectedTier {
            currentPair = viewModel.findPairToCompare(items: filteredItems, tier: tier)
        } else {
            currentPair = viewModel.findAnyPairToCompare(items: filteredItems)
        }
        chosenItem = nil
    }
    
    private func selectWinner(_ winner: RankedItem, loser: RankedItem) {
        chosenItem = winner
        HapticManager.impact(.light)
        
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            viewModel.processComparison(winner: winner, loser: loser, context: modelContext)
            findNewPair()
        }
    }
}

// MARK: - Compare Item Card

struct CompareItemCard: View {
    let item: RankedItem
    let isChosen: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: RankdSpacing.sm) {
                // Poster
                CachedPosterImage(
                    url: item.posterURL,
                    width: RankdPoster.largeWidth,
                    height: RankdPoster.largeHeight,
                    placeholderIcon: item.mediaType == .movie ? "film" : "tv"
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RankdPoster.cornerRadius)
                        .stroke(
                            isChosen ? RankdColors.surfaceTertiary : Color.clear,
                            lineWidth: 2
                        )
                )
                
                // Title
                Text(item.title)
                    .font(RankdTypography.labelMedium)
                    .foregroundStyle(RankdColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: RankdPoster.largeWidth)
                    .frame(minHeight: 32)
                
                // Year
                if let year = item.year {
                    Text(year)
                        .font(RankdTypography.caption)
                        .foregroundStyle(RankdColors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .scaleEffect(isChosen ? 1.02 : 1.0)
        .animation(RankdMotion.fast, value: isChosen)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    var tierColor: Color? = nil
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: RankdSpacing.xs) {
                if let tierColor = tierColor {
                    Circle()
                        .fill(tierColor)
                        .frame(width: 6, height: 6)
                }
                
                Text(title)
                    .font(RankdTypography.labelMedium)
            }
            .padding(.horizontal, RankdSpacing.sm)
            .padding(.vertical, RankdSpacing.xs)
            .frame(minHeight: 44)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(colors: [RankdColors.gradientStart, RankdColors.gradientEnd], startPoint: .leading, endPoint: .trailing)
                    } else {
                        LinearGradient(colors: [RankdColors.surfaceSecondary, RankdColors.surfaceSecondary], startPoint: .leading, endPoint: .trailing)
                    }
                }
            )
            .foregroundStyle(isSelected ? RankdColors.surfacePrimary : RankdColors.textSecondary)
            .clipShape(Capsule())
            .shadow(color: isSelected ? RankdColors.brand.opacity(0.3) : .clear, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CompareView()
        .modelContainer(for: RankedItem.self, inMemory: true)
}
