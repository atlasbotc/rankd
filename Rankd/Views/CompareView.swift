import SwiftUI
import SwiftData

struct CompareView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [RankedItem]
    @State private var viewModel = RankingViewModel()
    @State private var currentPair: (RankedItem, RankedItem)?
    @State private var selectedTier: Tier?
    @State private var animateChoice = false
    @State private var chosenItem: RankedItem?
    
    var availableTiers: [Tier] {
        Tier.allCases.filter { tier in
            items.filter { $0.tier == tier }.count >= 2
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tier selector
                if !availableTiers.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "Any", isSelected: selectedTier == nil) {
                                selectedTier = nil
                                findNewPair()
                            }
                            
                            ForEach(availableTiers, id: \.self) { tier in
                                FilterChip(
                                    title: "\(tier.emoji) \(tier.rawValue)",
                                    isSelected: selectedTier == tier
                                ) {
                                    selectedTier = tier
                                    findNewPair()
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .background(.ultraThinMaterial)
                }
                
                if items.count < 2 {
                    // Not enough items
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        Text("Need at least 2 items")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("Add more movies or TV shows to compare")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                } else if let pair = currentPair {
                    // Comparison view
                    VStack(spacing: 20) {
                        Text("Which is better?")
                            .font(.title2.bold())
                            .padding(.top)
                        
                        HStack(spacing: 16) {
                            CompareCard(item: pair.0, isChosen: chosenItem?.id == pair.0.id) {
                                selectWinner(pair.0, loser: pair.1)
                            }
                            
                            Text("vs")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            
                            CompareCard(item: pair.1, isChosen: chosenItem?.id == pair.1.id) {
                                selectWinner(pair.1, loser: pair.0)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Skip button
                        Button {
                            findNewPair()
                        } label: {
                            Label("Skip", systemImage: "forward.fill")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                        
                        Spacer()
                        
                        // Stats
                        VStack(spacing: 4) {
                            Text("Comparisons help refine your rankings")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            
                            let totalComparisons = items.reduce(0) { $0 + $1.comparisonCount } / 2
                            Text("\(totalComparisons) comparisons made")
                                .font(.caption2)
                                .foregroundStyle(.quaternary)
                        }
                        .padding(.bottom)
                    }
                } else {
                    // No pairs available for selected tier
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 50))
                            .foregroundStyle(.green)
                        Text("All caught up!")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("Add more items or select a different tier")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        
                        Button("Find More") {
                            selectedTier = nil
                            findNewPair()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                    Spacer()
                }
            }
            .navigationTitle("Compare")
            .onAppear {
                findNewPair()
            }
        }
    }
    
    private func findNewPair() {
        if let tier = selectedTier {
            currentPair = viewModel.findPairToCompare(items: items, tier: tier)
        } else {
            currentPair = viewModel.findAnyPairToCompare(items: items)
        }
        chosenItem = nil
    }
    
    private func selectWinner(_ winner: RankedItem, loser: RankedItem) {
        chosenItem = winner
        
        // Brief animation before moving to next
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            viewModel.processComparison(winner: winner, loser: loser, context: modelContext)
            findNewPair()
        }
    }
}

// MARK: - Compare Card
struct CompareCard: View {
    let item: RankedItem
    let isChosen: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Poster
                AsyncImage(url: item.posterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: item.mediaType == .movie ? "film" : "tv")
                                .font(.largeTitle)
                                .foregroundStyle(.tertiary)
                        }
                }
                .frame(width: 140, height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    if isChosen {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.green, lineWidth: 4)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if isChosen {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.green)
                            .background(Circle().fill(.white))
                            .offset(x: 8, y: -8)
                    }
                }
                
                // Title
                Text(item.title)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 40)
                
                // Year and type
                HStack(spacing: 4) {
                    if let year = item.year {
                        Text(year)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("•")
                        .foregroundStyle(.tertiary)
                    
                    Text(item.mediaType == .movie ? "Movie" : "TV")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isChosen ? Color.green.opacity(0.1) : Color.secondary.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isChosen ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isChosen)
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CompareView()
        .modelContainer(for: RankedItem.self, inMemory: true)
}
