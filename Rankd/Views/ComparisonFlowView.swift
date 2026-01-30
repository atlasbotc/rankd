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
    @State private var tierSelected = false
    @State private var showReviewStep = false
    @State private var review: String = ""
    @State private var tier: Tier = .good
    @State private var hasStarted = false
    @State private var showSavedCheck = false
    
    /// All items of the same media type, sorted by rank
    private var existingItems: [RankedItem] {
        allRankedItems
            .filter { $0.mediaType == newItem.resolvedMediaType }
            .sorted { $0.rank < $1.rank }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if !tierSelected {
                    tierSelectionStep
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else if showReviewStep {
                    if showSavedCheck {
                        savedCheckmark
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        reviewStep
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                } else if let comparison = currentComparison {
                    comparisonStep(comparison)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else if finalRank != nil {
                    ProgressView()
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showReviewStep = true
                            }
                        }
                } else {
                    ProgressView()
                        .onAppear {
                            guard !hasStarted else { return }
                            hasStarted = true
                            startComparison()
                        }
                }
            }
            .animation(.easeInOut(duration: 0.35), value: tierSelected)
            .animation(.easeInOut(duration: 0.35), value: showReviewStep)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showSavedCheck)
            .navigationTitle("Add to Rankings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Saved Checkmark
    private var savedCheckmark: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: showSavedCheck)
            Text("Saved!")
                .font(.title.bold())
            if let rank = finalRank {
                Text("Ranked #\(rank)")
                    .font(.headline)
                    .foregroundStyle(.orange)
            }
            Spacer()
        }
    }
    
    // MARK: - Tier Selection Step (always shown first)
    private var tierSelectionStep: some View {
        VStack(spacing: 24) {
            itemHeader
            
            Text("How was it?")
                .font(.title2.bold())
            
            Text("Pick a tier:")
                .foregroundStyle(.secondary)
            
            VStack(spacing: 12) {
                ForEach(Tier.allCases, id: \.self) { t in
                    Button {
                        tier = t
                        HapticManager.impact(.medium)
                        withAnimation {
                            tierSelected = true
                        }
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
                    HapticManager.impact(.light)
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
                    HapticManager.impact(.light)
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
                
                // Show selected tier + rank
                HStack(spacing: 12) {
                    Text(tier.emoji)
                        .font(.title)
                    Text(tier.rawValue)
                        .font(.headline)
                    
                    if let rank = finalRank {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text("#\(rank) in \(newItem.resolvedMediaType == .movie ? "Movies" : "TV Shows")")
                            .font(.headline)
                            .foregroundStyle(.orange)
                    }
                }
                
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
        // Prevent duplicates
        guard !allRankedItems.contains(where: { $0.tmdbId == newItem.id && $0.mediaType == newItem.resolvedMediaType }) else {
            dismiss()
            return
        }
        
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
        
        HapticManager.notification(.success)
        
        // Backfill genre and runtime data asynchronously (don't block UI)
        let itemTmdbId = newItem.id
        let itemMediaType = newItem.resolvedMediaType
        Task {
            if itemMediaType == .movie {
                if let details = try? await TMDBService.shared.getMovieDetails(id: itemTmdbId) {
                    item.genreIds = details.genres.map { $0.id }
                    item.genreNames = details.genres.map { $0.name }
                    item.runtimeMinutes = details.runtime ?? 0
                    try? modelContext.save()
                }
            } else {
                if let details = try? await TMDBService.shared.getTVDetails(id: itemTmdbId) {
                    item.genreIds = details.genres.map { $0.id }
                    item.genreNames = details.genres.map { $0.name }
                    item.runtimeMinutes = details.episodeRunTime?.first ?? 0
                    try? modelContext.save()
                }
            }
        }
        
        // Show saved animation then dismiss
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showSavedCheck = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dismiss()
        }
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
