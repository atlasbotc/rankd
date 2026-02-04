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
                MarquiColors.background.ignoresSafeArea()
                
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
                        .tint(MarquiColors.textTertiary)
                        .onAppear {
                            showCompletionCelebration()
                        }
                } else {
                    ProgressView()
                        .tint(MarquiColors.textTertiary)
                        .onAppear {
                            guard !hasStarted else { return }
                            hasStarted = true
                            startComparison()
                        }
                }
            }
            .animation(MarquiMotion.fast, value: tierSelected)
            .animation(MarquiMotion.fast, value: showReviewStep)
            .animation(MarquiMotion.fast, value: showSavedCheck)
            .animation(MarquiMotion.fast, value: showCelebration)
            .navigationTitle("Add to Rankings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(MarquiTypography.labelLarge)
                        .foregroundStyle(MarquiColors.textSecondary)
                }
                
                // Undo button — only visible during comparisons
                if tierSelected && !showReviewStep && !showSavedCheck && !showCelebration && currentComparison != nil && canUndo {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            performUndo()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                                .font(MarquiTypography.labelLarge)
                                .foregroundStyle(MarquiColors.brand)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Saved Checkmark
    
    private var savedCheckmark: some View {
        VStack(spacing: MarquiSpacing.lg) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(MarquiColors.success)
            
            Text("Saved")
                .font(MarquiTypography.headingLarge)
                .foregroundStyle(MarquiColors.textPrimary)
            
            if let rank = finalRank {
                Text("#\(rank) in \(newItem.resolvedMediaType == .movie ? "Movies" : "TV Shows")")
                    .font(MarquiTypography.headingMedium)
                    .foregroundStyle(MarquiColors.brand)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Completion Celebration
    
    private var completionCelebration: some View {
        VStack(spacing: MarquiSpacing.lg) {
            Spacer()
            
            // Poster thumbnail
            CachedPosterImage(
                url: newItem.posterURL,
                width: MarquiPoster.standardWidth,
                height: MarquiPoster.standardHeight
            )
            
            Text(newItem.displayTitle)
                .font(MarquiTypography.headingLarge)
                .foregroundStyle(MarquiColors.textPrimary)
                .multilineTextAlignment(.center)
            
            if let rank = finalRank {
                Text("#\(rank)")
                    .font(MarquiTypography.displayLarge)
                    .foregroundStyle(MarquiColors.brand)
                    .scaleEffect(celebrationScale)
                    .opacity(celebrationOpacity)
                
                Text("in \(newItem.resolvedMediaType == .movie ? "Movies" : "TV Shows")")
                    .font(MarquiTypography.bodyMedium)
                    .foregroundStyle(MarquiColors.textSecondary)
                    .opacity(celebrationOpacity)
            }
            
            Spacer()
        }
        .padding(.horizontal, MarquiSpacing.lg)
    }
    
    // MARK: - Tier Selection Step
    
    private var tierSelectionStep: some View {
        VStack(spacing: MarquiSpacing.lg) {
            itemHeader
            
            Text("How was it?")
                .font(MarquiTypography.displayMedium)
                .foregroundStyle(MarquiColors.textPrimary)
            
            VStack(spacing: MarquiSpacing.sm) {
                ForEach(Tier.allCases, id: \.self) { t in
                    Button {
                        tier = t
                        HapticManager.impact(.medium)
                        withAnimation(MarquiMotion.normal) {
                            tierSelected = true
                        }
                    } label: {
                        HStack(spacing: MarquiSpacing.sm) {
                            Circle()
                                .fill(MarquiColors.tierColor(t))
                                .frame(width: 12, height: 12)
                            
                            Text(t.rawValue)
                                .font(MarquiTypography.headingSmall)
                                .foregroundStyle(MarquiColors.textPrimary)
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                        .padding(.horizontal, MarquiSpacing.md)
                        .background(MarquiColors.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: MarquiRadius.md))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, MarquiSpacing.xl)
            
            Spacer()
        }
        .padding(.top, MarquiSpacing.xl)
    }
    
    // MARK: - Comparison Step
    
    private func comparisonStep(_ comparison: RankedItem) -> some View {
        VStack(spacing: MarquiSpacing.lg) {
            // Progress indicator at the top
            VStack(spacing: MarquiSpacing.xxs) {
                Text("Comparison \(comparisonsMade + 1) of \(totalComparisons)")
                    .font(MarquiTypography.labelMedium)
                    .foregroundStyle(MarquiColors.textSecondary)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(MarquiColors.surfaceSecondary)
                            .frame(height: 3)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(MarquiColors.brand)
                            .frame(
                                width: geo.size.width * CGFloat(comparisonsMade) / CGFloat(max(totalComparisons, 1)),
                                height: 3
                            )
                            .animation(MarquiMotion.fast, value: comparisonsMade)
                    }
                }
                .frame(height: 3)
            }
            .padding(.horizontal, MarquiSpacing.xl)
            .padding(.top, MarquiSpacing.md)
            
            Text("Which is better?")
                .font(MarquiTypography.headingLarge)
                .foregroundStyle(MarquiColors.textPrimary)
            
            HStack(spacing: MarquiSpacing.md) {
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
            .animation(reduceMotion ? nil : MarquiMotion.fast, value: chosenSide)
            .padding(.horizontal, MarquiSpacing.md)
            
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
            VStack(spacing: MarquiSpacing.lg) {
                itemHeader
                
                // Tier + rank
                HStack(spacing: MarquiSpacing.sm) {
                    Circle()
                        .fill(MarquiColors.tierColor(tier))
                        .frame(width: 8, height: 8)
                    
                    Text(tier.rawValue)
                        .font(MarquiTypography.labelMedium)
                        .foregroundStyle(MarquiColors.textSecondary)
                    
                    if let rank = finalRank {
                        Text("#\(rank) in \(newItem.resolvedMediaType == .movie ? "Movies" : "TV Shows")")
                            .font(MarquiTypography.headingMedium)
                            .foregroundStyle(MarquiColors.brand)
                    }
                }
                
                // Review
                VStack(alignment: .leading, spacing: MarquiSpacing.sm) {
                    Text("Review (optional)")
                        .font(MarquiTypography.headingSmall)
                        .foregroundStyle(MarquiColors.textPrimary)
                    
                    TextEditor(text: $review)
                        .font(MarquiTypography.bodyMedium)
                        .frame(minHeight: 100)
                        .padding(MarquiSpacing.xs)
                        .scrollContentBackground(.hidden)
                        .background(MarquiColors.surfaceSecondary)
                        .foregroundStyle(MarquiColors.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: MarquiRadius.md))
                }
                .padding(.horizontal, MarquiSpacing.md)
                
                // Save button — gradient CTA
                Button {
                    saveItem()
                } label: {
                    Text("Save to Rankings")
                        .font(MarquiTypography.headingSmall)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [MarquiColors.gradientStart, MarquiColors.gradientEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .shadow(color: MarquiColors.brand.opacity(0.4), radius: 8, y: 4)
                }
                .padding(.horizontal, MarquiSpacing.md)
                .padding(.top, MarquiSpacing.xs)
            }
            .padding(.vertical, MarquiSpacing.md)
        }
    }
    
    // MARK: - Item Header
    
    private var itemHeader: some View {
        HStack(spacing: MarquiSpacing.md) {
            CachedPosterImage(
                url: newItem.posterURL,
                width: 80,
                height: 120
            )
            
            VStack(alignment: .leading, spacing: MarquiSpacing.xxs) {
                Text(newItem.displayTitle)
                    .font(MarquiTypography.headingLarge)
                    .foregroundStyle(MarquiColors.textPrimary)
                    .lineLimit(2)
                
                if let year = newItem.displayYear {
                    Text(year)
                        .font(MarquiTypography.bodySmall)
                        .foregroundStyle(MarquiColors.textSecondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, MarquiSpacing.md)
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
        
        withAnimation(MarquiMotion.fast) {
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
        
        withAnimation(MarquiMotion.fast) {
            showCelebration = true
        }
        
        // Animate the rank number in
        withAnimation(MarquiMotion.reveal) {
            celebrationScale = 1.0
            celebrationOpacity = 1.0
        }
        
        // Auto-advance to review step after a brief pause
        Task {
            try? await Task.sleep(for: .milliseconds(1200))
            withAnimation(MarquiMotion.normal) {
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
        Task { @MainActor in
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
        withAnimation(MarquiMotion.normal) {
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
            VStack(spacing: MarquiSpacing.sm) {
                CachedPosterImage(
                    url: posterURL,
                    width: MarquiPoster.largeWidth,
                    height: MarquiPoster.largeHeight
                )
                .overlay(
                    RoundedRectangle(cornerRadius: MarquiPoster.cornerRadius)
                        .stroke(
                            isHighlighted ? MarquiColors.surfaceTertiary : Color.clear,
                            lineWidth: 2
                        )
                )
                
                Text(title)
                    .font(MarquiTypography.labelMedium)
                    .foregroundStyle(MarquiColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: MarquiPoster.largeWidth)
                
                if let year = year {
                    Text(year)
                        .font(MarquiTypography.caption)
                        .foregroundStyle(MarquiColors.textTertiary)
                }
                
                // Keyboard shortcut hint for iPad
                if let hint = keyboardHint {
                    Text(hint)
                        .font(MarquiTypography.caption)
                        .foregroundStyle(MarquiColors.textQuaternary)
                        .padding(.horizontal, MarquiSpacing.xs)
                        .padding(.vertical, MarquiSpacing.xxs)
                        .background(MarquiColors.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: MarquiRadius.sm))
                }
            }
        }
        .buttonStyle(MarquiPressStyle())
        .scaleEffect(reduceMotion ? 1.0 : (isHighlighted ? 1.02 : 1.0))
        .animation(reduceMotion ? nil : MarquiMotion.fast, value: isHighlighted)
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
