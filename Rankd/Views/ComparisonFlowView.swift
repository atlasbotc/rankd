import SwiftUI
import SwiftData

/// Handles the comparison-based ranking flow when adding a new item
struct ComparisonFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let newItem: TMDBSearchResult
    @Query private var allRankedItems: [RankedItem]
    
    @State private var currentComparison: RankedItem?
    @State private var searchRange: Range<Int> = 0..<0
    @State private var finalRank: Int?
    @State private var showReviewStep = false
    @State private var review: String = ""
    @State private var tier: Tier = .good
    @State private var hasStarted = false
    
    /// Items filtered by the same media type, sorted by rank
    private var existingItems: [RankedItem] {
        allRankedItems
            .filter { $0.mediaType == newItem.resolvedMediaType }
            .sorted { $0.rank < $1.rank }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if showReviewStep {
                    reviewStep
                } else if let comparison = currentComparison {
                    comparisonStep(comparison)
                } else if existingItems.isEmpty && hasStarted {
                    firstItemStep
                } else if finalRank != nil {
                    ProgressView()
                        .onAppear { showReviewStep = true }
                } else {
                    ProgressView()
                        .onAppear {
                            guard !hasStarted else { return }
                            hasStarted = true
                            startComparison()
                        }
                }
            }
            .navigationTitle("Add to Rankings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - First Item Step
    private var firstItemStep: some View {
        VStack(spacing: 24) {
            itemHeader
            
            Text("This is your first \(newItem.resolvedMediaType == .movie ? "movie" : "TV show")!")
                .font(.headline)
            
            Text("Pick a tier to get started:")
                .foregroundStyle(.secondary)
            
            VStack(spacing: 12) {
                ForEach(Tier.allCases, id: \.self) { t in
                    Button {
                        tier = t
                        finalRank = 1
                        showReviewStep = true
                    } label: {
                        HStack {
                            Text(t.emoji)
                            Text(t.rawValue)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(tierColor(t).opacity(0.2))
                        .foregroundStyle(tierColor(t))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .padding(.top, 32)
    }
    
    // MARK: - Comparison Step
    private func comparisonStep(_ comparison: RankedItem) -> some View {
        VStack(spacing: 24) {
            Text("Which is better?")
                .font(.title2.bold())
            
            HStack(spacing: 20) {
                // New item
                ComparisonCard(
                    title: newItem.displayTitle,
                    year: newItem.displayYear,
                    posterURL: newItem.posterURL,
                    isHighlighted: false
                ) {
                    handleChoice(newIsBetter: true)
                }
                
                Text("vs")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                // Existing item
                ComparisonCard(
                    title: comparison.title,
                    year: comparison.year,
                    posterURL: comparison.posterURL,
                    isHighlighted: false
                ) {
                    handleChoice(newIsBetter: false)
                }
            }
            .padding(.horizontal)
            
            // Progress indicator
            let total = Int(log2(Double(max(existingItems.count, 1)))) + 1
            let remaining = Int(log2(Double(max(searchRange.count, 1)))) + 1
            let progress = total - remaining
            
            VStack(spacing: 8) {
                ProgressView(value: Double(progress), total: Double(total))
                    .tint(.orange)
                Text("\(progress)/\(total) comparisons")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .padding(.top, 32)
    }
    
    // MARK: - Review Step
    private var reviewStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                itemHeader
                
                if let rank = finalRank {
                    Text("Ranked #\(rank) in \(newItem.resolvedMediaType == .movie ? "Movies" : "TV Shows")!")
                        .font(.headline)
                        .foregroundStyle(.orange)
                }
                
                // Tier selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tier")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        ForEach(Tier.allCases, id: \.self) { t in
                            Button {
                                tier = t
                            } label: {
                                VStack(spacing: 4) {
                                    Text(t.emoji)
                                        .font(.title2)
                                    Text(t.rawValue)
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(tier == t ? tierColor(t).opacity(0.3) : Color(.systemGray6))
                                .foregroundStyle(tier == t ? tierColor(t) : .secondary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Review
                VStack(alignment: .leading, spacing: 12) {
                    Text("Review (optional)")
                        .font(.headline)
                    
                    TextEditor(text: $review)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal)
                
                // Save button
                Button {
                    saveItem()
                } label: {
                    Text("Save to Rankings")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Item Header
    private var itemHeader: some View {
        HStack(spacing: 16) {
            AsyncImage(url: newItem.posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(.quaternary)
            }
            .frame(width: 80, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(newItem.displayTitle)
                    .font(.title3.bold())
                    .lineLimit(2)
                
                if let year = newItem.displayYear {
                    Text(year)
                        .foregroundStyle(.secondary)
                }
                
                Text(newItem.resolvedMediaType == .movie ? "Movie" : "TV Show")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    // MARK: - Logic
    
    private func startComparison() {
        guard !existingItems.isEmpty else {
            finalRank = 1
            return
        }
        
        searchRange = 0..<existingItems.count
        pickNextComparison()
    }
    
    private func pickNextComparison() {
        guard searchRange.count > 0 else {
            // Found position — clear comparison so view transitions
            currentComparison = nil
            finalRank = searchRange.lowerBound + 1
            return
        }
        
        let midIndex = searchRange.lowerBound + searchRange.count / 2
        currentComparison = existingItems[midIndex]
    }
    
    private func handleChoice(newIsBetter: Bool) {
        guard let comparison = currentComparison,
              let comparisonIndex = existingItems.firstIndex(where: { $0.id == comparison.id }) else {
            return
        }
        
        if newIsBetter {
            searchRange = searchRange.lowerBound..<comparisonIndex
        } else {
            searchRange = (comparisonIndex + 1)..<searchRange.upperBound
        }
        
        // Directly pick next comparison (no nil intermediate state)
        pickNextComparison()
    }
    
    private func saveItem() {
        let rank = finalRank ?? (existingItems.count + 1)
        
        // Shift existing items down
        for item in existingItems where item.rank >= rank {
            item.rank += 1
        }
        
        // Create new item
        let item = RankedItem(
            tmdbId: newItem.id,
            title: newItem.displayTitle,
            overview: newItem.overview ?? "",
            posterPath: newItem.posterPath,
            releaseDate: newItem.displayDate,
            mediaType: newItem.resolvedMediaType,
            tier: tier,
            review: review.isEmpty ? nil : review
        )
        item.rank = rank
        item.comparisonCount = Int(log2(Double(max(existingItems.count, 1)))) + 1
        
        modelContext.insert(item)
        try? modelContext.save()
        
        dismiss()
    }
    
    private func tierColor(_ tier: Tier) -> Color {
        switch tier {
        case .good: return .green
        case .medium: return .yellow
        case .bad: return .red
        }
    }
}

// MARK: - Comparison Card
struct ComparisonCard: View {
    let title: String
    let year: String?
    let posterURL: URL?
    let isHighlighted: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                AsyncImage(url: posterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "film")
                                .font(.title)
                                .foregroundStyle(.tertiary)
                        }
                }
                .frame(width: 120, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isHighlighted ? Color.orange : Color.clear, lineWidth: 3)
                )
                
                Text(title)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 120)
                
                if let year = year {
                    Text(year)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ComparisonFlowView(
        newItem: TMDBSearchResult(
            id: 1,
            title: "Test Movie",
            name: nil,
            overview: "A test movie",
            posterPath: nil,
            releaseDate: "2024-01-01",
            firstAirDate: nil,
            mediaType: "movie",
            voteAverage: 8.5
        )
    )
    .modelContainer(for: RankedItem.self, inMemory: true)
}
