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
    @State private var comparisonsMade: Int = 0
    @State private var chosenSide: ChoiceSide? = nil
    
    // Undo support
    @State private var undoState: UndoSnapshot?
    @State private var canUndo = false
    
    // Completion celebration
    @State private var showCelebration = false
    @State private var celebrationScale: CGFloat = 0.5
    @State private var celebrationOpacity: Double = 0
    
    // Accessibility
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private enum ChoiceSide {
        case left, right
    }
    
    /// Snapshot for undo support
    private struct UndoSnapshot {
        let searchRange: Range<Int>
        let comparison: RankedItem?
        let comparisonsMade: Int
    }
    
    /// All items of the same media type, sorted by rank
    private var existingItems: [RankedItem] {
        allRankedItems
            .filter { $0.mediaType == newItem.resolvedMediaType }
            .sorted { $0.rank < $1.rank }
    }
    
    private var totalComparisons: Int {
        Int(log2(Double(max(existingItems.count, 1)))) + 1
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                RankdColors.background.ignoresSafeArea()
                
                if !tierSelected {
                    tierSelectionStep
                        .transition(.opacity)
                } else if showReviewStep {
                    if showSavedCheck {
                        savedCheckmark
                            .transition(.opacity)
                    } else {
                        reviewStep
                            .transition(.opacity)
                    }
                } else if showCelebration {
                    completionCelebration
                        .transition(.opacity)
                } else if let comparison = currentComparison {
                    comparisonStep(comparison)
                        .transition(.opacity)
                } else if finalRank != nil {
                    ProgressView()
                        .tint(RankdColors.textTertiary)
                        .onAppear {
                            showCompletionCelebration()
                        }
                } else {
                    ProgressView()
                        .tint(RankdColors.textTertiary)
                        .onAppear {
                            guard !hasStarted else { return }
                            hasStarted = true
                            startComparison()
                        }
                }
            }
            .animation(RankdMotion.fast, value: tierSelected)
            .animation(RankdMotion.fast, value: showReviewStep)
            .animation(RankdMotion.fast, value: showSavedCheck)
            .animation(RankdMotion.fast, value: showCelebration)
            .navigationTitle("Add to Rankings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(RankdTypography.labelLarge)
                        .foregroundStyle(RankdColors.textSecondary)
                }
                
                // Undo button — only visible during comparisons
                if tierSelected && !showReviewStep && !showSavedCheck && !showCelebration && currentComparison != nil && canUndo {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            performUndo()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                                .font(RankdTypography.labelLarge)
                                .foregroundStyle(RankdColors.brand)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Saved Checkmark
    
    private var savedCheckmark: some View {
        VStack(spacing: RankdSpacing.lg) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(RankdColors.success)
            
            Text("Saved")
                .font(RankdTypography.headingLarge)
                .foregroundStyle(RankdColors.textPrimary)
            
            if let rank = finalRank {
                Text("#\(rank) in \(newItem.resolvedMediaType == .movie ? "Movies" : "TV Shows")")
                    .font(RankdTypography.headingMedium)
                    .foregroundStyle(RankdColors.brand)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Completion Celebration
    
    private var completionCelebration: some View {
        VStack(spacing: RankdSpacing.lg) {
            Spacer()
            
            // Poster thumbnail
            CachedPosterImage(
                url: newItem.posterURL,
                width: RankdPoster.standardWidth,
                height: RankdPoster.standardHeight
            )
            
            Text(newItem.displayTitle)
                .font(RankdTypography.headingLarge)
                .foregroundStyle(RankdColors.textPrimary)
                .multilineTextAlignment(.center)
            
            if let rank = finalRank {
                Text("#\(rank)")
                    .font(RankdTypography.displayLarge)
                    .foregroundStyle(RankdColors.brand)
                    .scaleEffect(celebrationScale)
                    .opacity(celebrationOpacity)
                
                Text("in \(newItem.resolvedMediaType == .movie ? "Movies" : "TV Shows")")
                    .font(RankdTypography.bodyMedium)
                    .foregroundStyle(RankdColors.textSecondary)
                    .opacity(celebrationOpacity)
            }
            
            Spacer()
        }
        .padding(.horizontal, RankdSpacing.lg)
    }
    
    // MARK: - Tier Selection Step
    
    private var tierSelectionStep: some View {
        VStack(spacing: RankdSpacing.lg) {
            itemHeader
            
            Text("How was it?")
                .font(RankdTypography.displayMedium)
                .foregroundStyle(RankdColors.textPrimary)
            
            VStack(spacing: RankdSpacing.sm) {
                ForEach(Tier.allCases, id: \.self) { t in
                    Button {
                        tier = t
                        HapticManager.impact(.medium)
                        withAnimation(RankdMotion.normal) {
                            tierSelected = true
                        }
                    } label: {
                        HStack(spacing: RankdSpacing.sm) {
                            Circle()
                                .fill(RankdColors.tierColor(t))
                                .frame(width: 12, height: 12)
                            
                            Text(t.rawValue)
                                .font(RankdTypography.headingSmall)
                                .foregroundStyle(RankdColors.textPrimary)
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                        .padding(.horizontal, RankdSpacing.md)
                        .background(RankdColors.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: RankdRadius.md))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, RankdSpacing.xl)
            
            Spacer()
        }
        .padding(.top, RankdSpacing.xl)
    }
    
    // MARK: - Comparison Step
    
    private func comparisonStep(_ comparison: RankedItem) -> some View {
        VStack(spacing: RankdSpacing.lg) {
            // Progress indicator at the top
            VStack(spacing: RankdSpacing.xxs) {
                Text("Comparison \(comparisonsMade + 1) of \(totalComparisons)")
                    .font(RankdTypography.labelMedium)
                    .foregroundStyle(RankdColors.textSecondary)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(RankdColors.surfaceSecondary)
                            .frame(height: 3)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(RankdColors.brand)
                            .frame(
                                width: geo.size.width * CGFloat(comparisonsMade) / CGFloat(max(totalComparisons, 1)),
                                height: 3
                            )
                            .animation(RankdMotion.fast, value: comparisonsMade)
                    }
                }
                .frame(height: 3)
            }
            .padding(.horizontal, RankdSpacing.xl)
            .padding(.top, RankdSpacing.md)
            
            Text("Which is better?")
                .font(RankdTypography.headingLarge)
                .foregroundStyle(RankdColors.textPrimary)
            
            HStack(spacing: RankdSpacing.md) {
                // New item (left)
                ComparisonCard(
                    title: newItem.displayTitle,
                    year: newItem.displayYear,
                    posterURL: newItem.posterURL,
                    isHighlighted: false,
                    keyboardHint: "←"
                ) {
                    animateChoice(side: .left, newIsBetter: true)
                }
                .scaleEffect(reduceMotion ? 1.0 : (chosenSide == .left ? 1.05 : (chosenSide == .right ? 0.97 : 1.0)))
                .opacity(reduceMotion ? 1.0 : (chosenSide == .right ? 0.3 : 1.0))
                
                // Existing item (right)
                ComparisonCard(
                    title: comparison.title,
                    year: comparison.year,
                    posterURL: comparison.posterURL,
                    isHighlighted: false,
                    keyboardHint: "→"
                ) {
                    animateChoice(side: .right, newIsBetter: false)
                }
                .scaleEffect(reduceMotion ? 1.0 : (chosenSide == .right ? 1.05 : (chosenSide == .left ? 0.97 : 1.0)))
                .opacity(reduceMotion ? 1.0 : (chosenSide == .left ? 0.3 : 1.0))
            }
            .animation(reduceMotion ? nil : RankdMotion.fast, value: chosenSide)
            .padding(.horizontal, RankdSpacing.md)
            
            Spacer()
        }
        .keyboardShortcut(.leftArrow, modifiers: [], action: {
            animateChoice(side: .left, newIsBetter: true)
        })
        .keyboardShortcut(.rightArrow, modifiers: [], action: {
            animateChoice(side: .right, newIsBetter: false)
        })
    }
    
    // MARK: - Review Step
    
    private var reviewStep: some View {
        ScrollView {
            VStack(spacing: RankdSpacing.lg) {
                itemHeader
                
                // Tier + rank
                HStack(spacing: RankdSpacing.sm) {
                    Circle()
                        .fill(RankdColors.tierColor(tier))
                        .frame(width: 8, height: 8)
                    
                    Text(tier.rawValue)
                        .font(RankdTypography.labelMedium)
                        .foregroundStyle(RankdColors.textSecondary)
                    
                    if let rank = finalRank {
                        Text("#\(rank) in \(newItem.resolvedMediaType == .movie ? "Movies" : "TV Shows")")
                            .font(RankdTypography.headingMedium)
                            .foregroundStyle(RankdColors.brand)
                    }
                }
                
                // Review
                VStack(alignment: .leading, spacing: RankdSpacing.sm) {
                    Text("Review (optional)")
                        .font(RankdTypography.headingSmall)
                        .foregroundStyle(RankdColors.textPrimary)
                    
                    TextEditor(text: $review)
                        .font(RankdTypography.bodyMedium)
                        .frame(minHeight: 100)
                        .padding(RankdSpacing.xs)
                        .scrollContentBackground(.hidden)
                        .background(RankdColors.surfaceSecondary)
                        .foregroundStyle(RankdColors.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: RankdRadius.md))
                }
                .padding(.horizontal, RankdSpacing.md)
                
                // Save button — gradient CTA
                Button {
                    saveItem()
                } label: {
                    Text("Save to Rankings")
                        .font(RankdTypography.headingSmall)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [RankdColors.gradientStart, RankdColors.gradientEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .shadow(color: RankdColors.brand.opacity(0.4), radius: 8, y: 4)
                }
                .padding(.horizontal, RankdSpacing.md)
                .padding(.top, RankdSpacing.xs)
            }
            .padding(.vertical, RankdSpacing.md)
        }
    }
    
    // MARK: - Item Header
    
    private var itemHeader: some View {
        HStack(spacing: RankdSpacing.md) {
            CachedPosterImage(
                url: newItem.posterURL,
                width: 80,
                height: 120
            )
            
            VStack(alignment: .leading, spacing: RankdSpacing.xxs) {
                Text(newItem.displayTitle)
                    .font(RankdTypography.headingLarge)
                    .foregroundStyle(RankdColors.textPrimary)
                    .lineLimit(2)
                
                if let year = newItem.displayYear {
                    Text(year)
                        .font(RankdTypography.bodySmall)
                        .foregroundStyle(RankdColors.textSecondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, RankdSpacing.md)
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
            currentComparison = nil
            finalRank = searchRange.lowerBound + 1
            return
        }
        
        let midIndex = searchRange.lowerBound + searchRange.count / 2
        currentComparison = existingItems[midIndex]
    }
    
    private func animateChoice(side: ChoiceSide, newIsBetter: Bool) {
        guard chosenSide == nil else { return } // prevent double-tap
        
        // Haptic on choice — medium impact for satisfying feedback
        HapticManager.impact(.medium)
        
        if reduceMotion {
            // Skip animation, proceed immediately
            handleChoice(newIsBetter: newIsBetter)
            return
        }
        
        chosenSide = side
        
        // Fast transition: ~200ms for winner scale + loser fade, then next pair
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            chosenSide = nil
            handleChoice(newIsBetter: newIsBetter)
        }
    }
    
    private func handleChoice(newIsBetter: Bool) {
        guard let comparison = currentComparison,
              let comparisonIndex = existingItems.firstIndex(where: { $0.id == comparison.id }) else {
            return
        }
        
        // Save undo state before modifying
        undoState = UndoSnapshot(
            searchRange: searchRange,
            comparison: comparison,
            comparisonsMade: comparisonsMade
        )
        canUndo = true
        
        comparisonsMade += 1
        
        if newIsBetter {
            searchRange = searchRange.lowerBound..<comparisonIndex
        } else {
            searchRange = (comparisonIndex + 1)..<searchRange.upperBound
        }
        
        pickNextComparison()
    }
    
    private func performUndo() {
        guard let snapshot = undoState else { return }
        
        HapticManager.impact(.light)
        
        withAnimation(RankdMotion.fast) {
            searchRange = snapshot.searchRange
            currentComparison = snapshot.comparison
            comparisonsMade = snapshot.comparisonsMade
            finalRank = nil
            showCelebration = false
            celebrationScale = 0.5
            celebrationOpacity = 0
        }
        
        undoState = nil
        canUndo = false
    }
    
    private func showCompletionCelebration() {
        HapticManager.notification(.success)
        
        if reduceMotion {
            // Skip celebration, go straight to review
            showCelebration = false
            showReviewStep = true
            celebrationScale = 1.0
            celebrationOpacity = 1.0
            return
        }
        
        withAnimation(RankdMotion.fast) {
            showCelebration = true
        }
        
        // Animate the rank number in
        withAnimation(RankdMotion.reveal) {
            celebrationScale = 1.0
            celebrationOpacity = 1.0
        }
        
        // Auto-advance to review step after a brief pause
        Task {
            try? await Task.sleep(for: .milliseconds(1200))
            withAnimation(RankdMotion.normal) {
                showCelebration = false
                showReviewStep = true
            }
        }
    }
    
    private func saveItem() {
        // Prevent duplicates
        guard !allRankedItems.contains(where: { $0.tmdbId == newItem.id && $0.mediaType == newItem.resolvedMediaType }) else {
            dismiss()
            return
        }
        
        let rank = finalRank ?? (existingItems.count + 1)
        
        // Shift existing items down
        RankingService.insertAtRank(rank, shifting: existingItems, context: modelContext)
        
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
        
        // Log activity
        let score = RankedItem.calculateScore(for: item, allItems: existingItems + [item])
        ActivityLogger.logRanked(item: item, score: score, context: modelContext)
        
        modelContext.safeSave()
        
        HapticManager.notification(.success)
        
        // Backfill genre and runtime data
        let itemTmdbId = newItem.id
        let itemMediaType = newItem.resolvedMediaType
        Task {
            if itemMediaType == .movie {
                if let details = try? await TMDBService.shared.getMovieDetails(id: itemTmdbId) {
                    item.genreIds = details.genres.map { $0.id }
                    item.genreNames = details.genres.map { $0.name }
                    item.runtimeMinutes = details.runtime ?? 0
                    modelContext.safeSave()
                }
            } else {
                if let details = try? await TMDBService.shared.getTVDetails(id: itemTmdbId) {
                    item.genreIds = details.genres.map { $0.id }
                    item.genreNames = details.genres.map { $0.name }
                    item.runtimeMinutes = details.episodeRunTime?.first ?? 0
                    modelContext.safeSave()
                }
            }
        }
        
        // Update widget data with latest rankings
        updateWidgetData()
        
        // Show saved animation then dismiss
        withAnimation(RankdMotion.normal) {
            showSavedCheck = true
        }
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            dismiss()
        }
    }
    
    private func updateWidgetData() {
        WidgetDataManager.refreshWidgetData(from: allRankedItems)
    }
}

// MARK: - Keyboard Shortcut Helper

private extension View {
    func keyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = [], action: @escaping () -> Void) -> some View {
        self.background(
            Button("") { action() }
                .keyboardShortcut(key, modifiers: modifiers)
                .frame(width: 0, height: 0)
                .opacity(0)
        )
    }
}

// MARK: - Comparison Card

struct ComparisonCard: View {
    let title: String
    let year: String?
    let posterURL: URL?
    let isHighlighted: Bool
    var keyboardHint: String? = nil
    let action: () -> Void
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: RankdSpacing.sm) {
                CachedPosterImage(
                    url: posterURL,
                    width: RankdPoster.largeWidth,
                    height: RankdPoster.largeHeight
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RankdPoster.cornerRadius)
                        .stroke(
                            isHighlighted ? RankdColors.surfaceTertiary : Color.clear,
                            lineWidth: 2
                        )
                )
                
                Text(title)
                    .font(RankdTypography.labelMedium)
                    .foregroundStyle(RankdColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: RankdPoster.largeWidth)
                
                if let year = year {
                    Text(year)
                        .font(RankdTypography.caption)
                        .foregroundStyle(RankdColors.textTertiary)
                }
                
                // Keyboard shortcut hint for iPad
                if let hint = keyboardHint {
                    Text(hint)
                        .font(RankdTypography.caption)
                        .foregroundStyle(RankdColors.textQuaternary)
                        .padding(.horizontal, RankdSpacing.xs)
                        .padding(.vertical, RankdSpacing.xxs)
                        .background(RankdColors.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: RankdRadius.sm))
                }
            }
        }
        .buttonStyle(RankdPressStyle())
        .scaleEffect(reduceMotion ? 1.0 : (isHighlighted ? 1.02 : 1.0))
        .animation(reduceMotion ? nil : RankdMotion.fast, value: isHighlighted)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)\(year.map { ", \($0)" } ?? ""). Tap to choose as winner")
        .accessibilityAddTraits(.isButton)
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
