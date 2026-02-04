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
                    .padding(.top, MarquiSpacing.xs)
                
                // Tier filter chips
                if !availableTiers.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: MarquiSpacing.xs) {
                            FilterChip(title: "Any", isSelected: selectedTier == nil) {
                                selectedTier = nil
                                findNewPair()
                            }
                            
                            ForEach(availableTiers, id: \.self) { tier in
                                FilterChip(
                                    title: tier.rawValue,
                                    tierColor: MarquiColors.tierColor(tier),
                                    isSelected: selectedTier == tier
                                ) {
                                    selectedTier = tier
                                    findNewPair()
                                }
                            }
                        }
                        .padding(.horizontal, MarquiSpacing.md)
                        .padding(.vertical, MarquiSpacing.sm)
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
                    VStack(spacing: MarquiSpacing.lg) {
                        Text("Which is better?")
                            .font(MarquiTypography.headingLarge)
                            .foregroundStyle(MarquiColors.textPrimary)
                            .padding(.top, MarquiSpacing.lg)
                        
                        HStack(spacing: MarquiSpacing.md) {
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
                        .padding(.horizontal, MarquiSpacing.md)
                        
                        // Skip button
                        Button {
                            findNewPair()
                        } label: {
                            Text("Skip")
                                .font(MarquiTypography.labelMedium)
                                .foregroundStyle(MarquiColors.textTertiary)
                        }
                        .padding(.top, MarquiSpacing.xs)
                        
                        Spacer()
                        
                        // Stats
                        VStack(spacing: MarquiSpacing.xxs) {
                            Text("Comparisons help refine your rankings")
                                .font(MarquiTypography.caption)
                                .foregroundStyle(MarquiColors.textTertiary)
                        }
                        .padding(.bottom, MarquiSpacing.lg)
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
                            .font(MarquiTypography.headingSmall)
                            .padding(.horizontal, MarquiSpacing.lg)
                            .padding(.vertical, MarquiSpacing.sm)
                            .background(MarquiColors.brand)
                            .foregroundStyle(MarquiColors.surfacePrimary)
                            .clipShape(RoundedRectangle(cornerRadius: MarquiRadius.md))
                    }
                    .padding(.top, MarquiSpacing.md)
                    
                    Spacer()
                }
            }
            .background(MarquiColors.background)
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
                    withAnimation(MarquiMotion.fast) {
                        selectedMediaType = type
                        selectedTier = nil
                        findNewPair()
                    }
                } label: {
                    Text(type == .movie ? "Movies" : "TV Shows")
                        .font(MarquiTypography.labelLarge)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, MarquiSpacing.sm)
                        .background(
                            selectedMediaType == type
                                ? MarquiColors.brand
                                : Color.clear
                        )
                        .foregroundStyle(
                            selectedMediaType == type
                                ? MarquiColors.surfacePrimary
                                : MarquiColors.textTertiary
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .padding(MarquiSpacing.xxs)
        .background(MarquiColors.surfaceSecondary)
        .clipShape(Capsule())
        .padding(.horizontal, MarquiSpacing.md)
    }
    
    // MARK: - Empty/Done State
    
    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: MarquiSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(MarquiColors.textQuaternary)
            
            Text(title)
                .font(MarquiTypography.headingMedium)
                .foregroundStyle(MarquiColors.textPrimary)
            
            Text(subtitle)
                .font(MarquiTypography.bodyMedium)
                .foregroundStyle(MarquiColors.textSecondary)
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
            VStack(spacing: MarquiSpacing.sm) {
                // Poster
                CachedPosterImage(
                    url: item.posterURL,
                    width: MarquiPoster.largeWidth,
                    height: MarquiPoster.largeHeight,
                    placeholderIcon: item.mediaType == .movie ? "film" : "tv"
                )
                .overlay(
                    RoundedRectangle(cornerRadius: MarquiPoster.cornerRadius)
                        .stroke(
                            isChosen ? MarquiColors.surfaceTertiary : Color.clear,
                            lineWidth: 2
                        )
                )
                
                // Title
                Text(item.title)
                    .font(MarquiTypography.labelMedium)
                    .foregroundStyle(MarquiColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: MarquiPoster.largeWidth)
                    .frame(minHeight: 32)
                
                // Year
                if let year = item.year {
                    Text(year)
                        .font(MarquiTypography.caption)
                        .foregroundStyle(MarquiColors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .scaleEffect(isChosen ? 1.02 : 1.0)
        .animation(MarquiMotion.fast, value: isChosen)
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
            HStack(spacing: MarquiSpacing.xs) {
                if let tierColor = tierColor {
                    Circle()
                        .fill(tierColor)
                        .frame(width: 6, height: 6)
                }
                
                Text(title)
                    .font(MarquiTypography.labelMedium)
            }
            .padding(.horizontal, MarquiSpacing.sm)
            .padding(.vertical, MarquiSpacing.xs)
            .frame(minHeight: 44)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(colors: [MarquiColors.gradientStart, MarquiColors.gradientEnd], startPoint: .leading, endPoint: .trailing)
                    } else {
                        LinearGradient(colors: [MarquiColors.surfaceSecondary, MarquiColors.surfaceSecondary], startPoint: .leading, endPoint: .trailing)
                    }
                }
            )
            .foregroundStyle(isSelected ? MarquiColors.surfacePrimary : MarquiColors.textSecondary)
            .clipShape(Capsule())
            .shadow(color: isSelected ? MarquiColors.brand.opacity(0.3) : .clear, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CompareView()
        .modelContainer(for: RankedItem.self, inMemory: true)
}
