import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Import Step

private enum ImportStep: Equatable {
    case instructions
    case matching
    case review
    case importing
    case done
}

// MARK: - Unrated Action

enum UnratedAction: String, CaseIterable {
    case medium = "Add as Medium"
    case watchlist = "Add to Watchlist"
    case skip = "Skip"
}

// MARK: - Import View

struct LetterboxdImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query private var existingRanked: [RankedItem]
    @Query private var existingWatchlist: [WatchlistItem]
    
    @State private var step: ImportStep = .instructions
    @State private var showFilePicker = false
    @State private var entries: [LetterboxdEntry] = []
    @State private var matchedEntries: [MatchedEntry] = []
    @State private var matchProgress = MatchProgress(total: 0, processed: 0, matched: 0, notFound: 0)
    @State private var unratedAction: UnratedAction = .medium
    @State private var importProgress = 0
    @State private var importTotal = 0
    @State private var importedCount = 0
    @State private var errorMessage: String?
    @State private var showMatchedList = false
    
    private let matcher = TMDBMatcher()
    
    // MARK: - Computed Properties
    
    private var existingTmdbIds: Set<Int> {
        Set(existingRanked.map(\.tmdbId))
    }
    
    private var existingWatchlistTmdbIds: Set<Int> {
        Set(existingWatchlist.map(\.tmdbId))
    }
    
    private var matchedOnly: [MatchedEntry] {
        matchedEntries.filter(\.isMatched)
    }
    
    private var notFoundEntries: [MatchedEntry] {
        matchedEntries.filter { !$0.isMatched }
    }
    
    private var duplicateCount: Int {
        matchedOnly.filter { entry in
            guard let tmdb = entry.tmdbResult else { return false }
            return existingTmdbIds.contains(tmdb.id)
        }.count
    }
    
    private var importableEntries: [MatchedEntry] {
        matchedOnly.filter { entry in
            guard let tmdb = entry.tmdbResult else { return false }
            return !existingTmdbIds.contains(tmdb.id)
        }
    }
    
    private var goodEntries: [MatchedEntry] {
        importableEntries.filter { $0.entry.tier == .good }
    }
    
    private var mediumEntries: [MatchedEntry] {
        importableEntries.filter { $0.entry.tier == .medium }
    }
    
    private var badEntries: [MatchedEntry] {
        importableEntries.filter { $0.entry.tier == .bad }
    }
    
    private var unratedEntries: [MatchedEntry] {
        importableEntries.filter { $0.entry.tier == nil }
    }
    
    private var totalToImport: Int {
        let rated = goodEntries.count + mediumEntries.count + badEntries.count
        switch unratedAction {
        case .medium, .watchlist:
            return rated + unratedEntries.count
        case .skip:
            return rated
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .instructions:
                    instructionsView
                case .matching:
                    matchingView
                case .review:
                    reviewView
                case .importing:
                    importingView
                case .done:
                    doneView
                }
            }
            .background(RankdColors.background)
            .animation(RankdMotion.normal, value: step)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if step != .importing {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(RankdColors.textSecondary)
                    }
                }
            }
            .alert("Import Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
        }
    }
    
    private var navigationTitle: String {
        switch step {
        case .instructions: return "Import"
        case .matching: return "Matching"
        case .review: return "Review"
        case .importing: return "Importing"
        case .done: return "Complete"
        }
    }
    
    // MARK: - Step 1: Instructions
    
    private var instructionsView: some View {
        ScrollView {
            VStack(spacing: RankdSpacing.xl) {
                Spacer(minLength: RankdSpacing.lg)
                
                Image(systemName: "square.and.arrow.down.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(RankdColors.textSecondary)
                
                VStack(spacing: RankdSpacing.sm) {
                    Text("Import from Letterboxd")
                        .font(RankdTypography.headingLarge)
                        .foregroundStyle(RankdColors.textPrimary)
                    
                    Text("Bring your movie ratings into Marqui. We'll match them with TMDB and sort them into tiers.")
                        .font(RankdTypography.bodyMedium)
                        .foregroundStyle(RankdColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, RankdSpacing.md)
                
                // Steps
                VStack(alignment: .leading, spacing: RankdSpacing.lg) {
                    InstructionRow(number: "1", text: "Go to **letterboxd.com/settings/data/**")
                    InstructionRow(number: "2", text: "Click **Export Your Data** and download the ZIP")
                    InstructionRow(number: "3", text: "Unzip and select **ratings.csv** below")
                }
                .padding(.horizontal, RankdSpacing.lg)
                
                // Select File Button
                Button {
                    showFilePicker = true
                } label: {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                        Text("Select CSV File")
                            .font(RankdTypography.headingSmall)
                    }
                    .foregroundStyle(RankdColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(RankdColors.brand)
                    .clipShape(RoundedRectangle(cornerRadius: RankdRadius.md))
                }
                .padding(.horizontal, RankdSpacing.lg)
                
                Text("You can also import **watched.csv** or **diary.csv** — movies without ratings will be handled separately.")
                    .font(RankdTypography.caption)
                    .foregroundStyle(RankdColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, RankdSpacing.xl)
                
                Spacer(minLength: RankdSpacing.xxl)
            }
        }
    }
    
    // MARK: - Step 2: Matching
    
    private var matchingView: some View {
        VStack(spacing: RankdSpacing.xl) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(RankdColors.textSecondary)
            
            VStack(spacing: RankdSpacing.xs) {
                Text("Matching \(entries.count) movies")
                    .font(RankdTypography.headingMedium)
                    .foregroundStyle(RankdColors.textPrimary)
                
                Text("Finding each movie on TMDB...")
                    .font(RankdTypography.bodyMedium)
                    .foregroundStyle(RankdColors.textSecondary)
            }
            
            VStack(spacing: RankdSpacing.sm) {
                ProgressView(value: matchProgress.fraction)
                    .tint(RankdColors.brand)
                    .scaleEffect(y: 2)
                    .clipShape(Capsule())
                    .background(
                        Capsule().fill(RankdColors.surfaceSecondary)
                            .scaleEffect(y: 2)
                    )
                
                HStack(spacing: RankdSpacing.md) {
                    Label("\(matchProgress.matched)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(RankdColors.success)
                    
                    Label("\(matchProgress.notFound)", systemImage: "questionmark.circle.fill")
                        .foregroundStyle(RankdColors.textTertiary)
                    
                    Spacer()
                    
                    Text("\(matchProgress.processed) / \(matchProgress.total)")
                        .foregroundStyle(RankdColors.textSecondary)
                }
                .font(RankdTypography.bodySmall)
            }
            .padding(.horizontal, RankdSpacing.xl)
            
            if entries.count > 100 {
                let estimatedSeconds = entries.count / 20
                Text("Estimated time: ~\(estimatedSeconds / 60 + 1) min")
                    .font(RankdTypography.caption)
                    .foregroundStyle(RankdColors.textTertiary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Step 3: Review
    
    private var reviewView: some View {
        ScrollView {
            VStack(spacing: RankdSpacing.lg) {
                // Summary Card
                HStack(spacing: RankdSpacing.md) {
                    SummaryBadge(icon: "checkmark.circle.fill", count: matchedOnly.count, label: "Matched", color: RankdColors.success)
                    SummaryBadge(icon: "questionmark.circle.fill", count: notFoundEntries.count, label: "Not Found", color: RankdColors.textTertiary)
                    SummaryBadge(icon: "arrow.right.circle.fill", count: duplicateCount, label: "Already In Marqui", color: RankdColors.textSecondary)
                }
                .padding(RankdSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: RankdRadius.lg)
                        .fill(RankdColors.surfacePrimary)
                )
                .padding(.horizontal, RankdSpacing.md)
                
                // Tier Breakdown
                VStack(spacing: RankdSpacing.md) {
                    HStack {
                        Text("Tier Breakdown")
                            .font(RankdTypography.headingMedium)
                            .foregroundStyle(RankdColors.textPrimary)
                        Spacer()
                    }
                    
                    TierPreviewRow(tier: .good, label: "Good (4-5★)", count: goodEntries.count)
                    TierPreviewRow(tier: .medium, label: "Medium (2.5-3.5★)", count: mediumEntries.count)
                    TierPreviewRow(tier: .bad, label: "Bad (0.5-2★)", count: badEntries.count)
                    
                    Rectangle()
                        .fill(RankdColors.divider)
                        .frame(height: 1)
                    
                    // Unrated handling
                    VStack(spacing: RankdSpacing.sm) {
                        HStack {
                            Text("Unrated")
                                .font(RankdTypography.headingSmall)
                                .foregroundStyle(RankdColors.textPrimary)
                            Spacer()
                            Text("\(unratedEntries.count) movies")
                                .font(RankdTypography.bodySmall)
                                .foregroundStyle(RankdColors.textSecondary)
                        }
                        
                        if !unratedEntries.isEmpty {
                            Picker("Unrated movies", selection: $unratedAction) {
                                ForEach(UnratedAction.allCases, id: \.self) { action in
                                    Text(action.rawValue).tag(action)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }
                .padding(RankdSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: RankdRadius.lg)
                        .fill(RankdColors.surfacePrimary)
                )
                .padding(.horizontal, RankdSpacing.md)
                
                // Expandable matched list
                DisclosureGroup(isExpanded: $showMatchedList) {
                    LazyVStack(spacing: RankdSpacing.xs) {
                        ForEach(importableEntries) { entry in
                            MatchedEntryRow(entry: entry)
                        }
                    }
                    .padding(.top, RankdSpacing.xs)
                } label: {
                    HStack {
                        Image(systemName: "list.bullet")
                        Text("View all \(importableEntries.count) movies")
                            .font(RankdTypography.bodyMedium)
                    }
                    .foregroundStyle(RankdColors.brand)
                }
                .padding(RankdSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: RankdRadius.lg)
                        .fill(RankdColors.surfacePrimary)
                )
                .padding(.horizontal, RankdSpacing.md)
                
                // Import Button
                Button {
                    startImport()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import \(totalToImport) Movies")
                            .font(RankdTypography.headingSmall)
                    }
                    .foregroundStyle(RankdColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(totalToImport > 0 ? RankdColors.brand : RankdColors.surfaceTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: RankdRadius.md))
                }
                .disabled(totalToImport == 0)
                .padding(.horizontal, RankdSpacing.lg)
                .padding(.bottom, RankdSpacing.xl)
            }
            .padding(.top, RankdSpacing.md)
        }
    }
    
    // MARK: - Step 4: Importing
    
    private var importingView: some View {
        VStack(spacing: RankdSpacing.xl) {
            Spacer()
            
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(RankdColors.brand)
            
            VStack(spacing: RankdSpacing.xs) {
                Text("Importing...")
                    .font(RankdTypography.headingMedium)
                    .foregroundStyle(RankdColors.textPrimary)
                
                Text("\(importProgress) / \(importTotal)")
                    .font(RankdTypography.headingSmall)
                    .foregroundStyle(RankdColors.textSecondary)
            }
            
            ProgressView(value: Double(importProgress), total: Double(max(1, importTotal)))
                .tint(RankdColors.brand)
                .scaleEffect(y: 2)
                .clipShape(Capsule())
                .background(
                    Capsule().fill(RankdColors.surfaceSecondary)
                        .scaleEffect(y: 2)
                )
                .padding(.horizontal, RankdSpacing.xxl)
            
            Spacer()
        }
    }
    
    // MARK: - Step 5: Done
    
    private var doneView: some View {
        VStack(spacing: RankdSpacing.xl) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(RankdColors.success)
            
            VStack(spacing: RankdSpacing.sm) {
                Text("Imported \(importedCount) movies!")
                    .font(RankdTypography.headingLarge)
                    .foregroundStyle(RankdColors.textPrimary)
                
                Text("Your rankings are ready.\nYou can refine them with comparisons anytime.")
                    .font(RankdTypography.bodyMedium)
                    .foregroundStyle(RankdColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(RankdTypography.headingSmall)
                    .foregroundStyle(RankdColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(RankdColors.brand)
                    .clipShape(RoundedRectangle(cornerRadius: RankdRadius.md))
            }
            .padding(.horizontal, RankdSpacing.lg)
            .padding(.bottom, RankdSpacing.xxl)
        }
    }
    
    // MARK: - Actions
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            do {
                let parsed = try LetterboxdImporter.parse(url: url)
                entries = parsed
                step = .matching
                startMatching()
            } catch {
                errorMessage = error.localizedDescription
            }
            
        case .failure(let error):
            errorMessage = "Failed to open file: \(error.localizedDescription)"
        }
    }
    
    private func startMatching() {
        matchProgress = MatchProgress(total: entries.count, processed: 0, matched: 0, notFound: 0)
        
        Task {
            let results = await matcher.match(entries: entries) { progress in
                self.matchProgress = progress
            }
            
            await MainActor.run {
                matchedEntries = results
                
                if matchedOnly.isEmpty {
                    errorMessage = "No movies could be matched. Please check your CSV file."
                    step = .instructions
                } else {
                    step = .review
                }
            }
        }
    }
    
    private func startImport() {
        step = .importing
        
        var toImport: [(MatchedEntry, Tier)] = []
        
        for entry in goodEntries {
            toImport.append((entry, .good))
        }
        for entry in mediumEntries {
            toImport.append((entry, .medium))
        }
        for entry in badEntries {
            toImport.append((entry, .bad))
        }
        
        switch unratedAction {
        case .medium:
            for entry in unratedEntries {
                toImport.append((entry, .medium))
            }
        case .watchlist, .skip:
            break
        }
        
        importTotal = toImport.count + (unratedAction == .watchlist ? unratedEntries.count : 0)
        importProgress = 0
        importedCount = 0
        
        Task {
            let sorted = toImport.sorted { a, b in
                let tierOrder: [Tier: Int] = [.good: 0, .medium: 1, .bad: 2]
                let aTier = tierOrder[a.1] ?? 1
                let bTier = tierOrder[b.1] ?? 1
                if aTier != bTier { return aTier < bTier }
                return (a.0.entry.rating ?? 0) > (b.0.entry.rating ?? 0)
            }
            
            let currentMaxRank = await MainActor.run {
                existingRanked.map(\.rank).max() ?? 0
            }
            
            var rankCounter = currentMaxRank + 1
            
            for (matched, tier) in sorted {
                guard let tmdb = matched.tmdbResult else { continue }
                
                await MainActor.run {
                    let item = RankedItem(
                        tmdbId: tmdb.id,
                        title: tmdb.displayTitle,
                        overview: tmdb.overview ?? "",
                        posterPath: tmdb.posterPath,
                        releaseDate: tmdb.releaseDate ?? tmdb.firstAirDate,
                        mediaType: .movie,
                        tier: tier
                    )
                    item.rank = rankCounter
                    item.comparisonCount = 0
                    rankCounter += 1
                    
                    modelContext.insert(item)
                    importProgress += 1
                    importedCount += 1
                }
                
                if importedCount % 20 == 0 {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
            }
            
            if unratedAction == .watchlist {
                for entry in unratedEntries {
                    guard let tmdb = entry.tmdbResult else { continue }
                    
                    await MainActor.run {
                        if !existingWatchlistTmdbIds.contains(tmdb.id) {
                            let watchlistItem = WatchlistItem(
                                tmdbId: tmdb.id,
                                title: tmdb.displayTitle,
                                overview: tmdb.overview ?? "",
                                posterPath: tmdb.posterPath,
                                releaseDate: tmdb.releaseDate ?? tmdb.firstAirDate,
                                mediaType: .movie
                            )
                            modelContext.insert(watchlistItem)
                        }
                        importProgress += 1
                    }
                }
            }
            
            await MainActor.run {
                modelContext.safeSave()
                updateWidgetDataAfterImport()
                step = .done
            }
        }
    }
    
    /// Push top ranked items to widget after Letterboxd import.
    private func updateWidgetDataAfterImport() {
        let descriptor = FetchDescriptor<RankedItem>(sortBy: [SortDescriptor(\.rank)])
        guard let allItems = try? modelContext.fetch(descriptor) else { return }
        let top10 = Array(allItems.prefix(10))
        
        let widgetItems = top10.map { item in
            let score = RankedItem.calculateScore(for: item, allItems: allItems)
            return WidgetDataManager.WidgetItem(
                id: item.id.uuidString,
                title: item.title,
                score: score,
                tier: item.tier.rawValue,
                posterURL: item.posterURL?.absoluteString,
                rank: item.rank
            )
        }
        
        WidgetDataManager.updateSharedData(items: widgetItems)
    }
}

// MARK: - Supporting Views

private struct InstructionRow: View {
    let number: String
    let text: LocalizedStringKey
    
    var body: some View {
        HStack(alignment: .top, spacing: RankdSpacing.md) {
            Text(number)
                .font(RankdTypography.headingSmall)
                .foregroundStyle(RankdColors.textPrimary)
                .frame(width: 28, height: 28)
                .background(RankdColors.surfaceTertiary)
                .clipShape(Circle())
            
            Text(text)
                .font(RankdTypography.bodyMedium)
                .foregroundStyle(RankdColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SummaryBadge: View {
    let icon: String
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: RankdSpacing.xs) {
            Image(systemName: icon)
                .font(RankdTypography.headingSmall)
                .foregroundStyle(color)
            
            Text("\(count)")
                .font(RankdTypography.headingMedium)
                .foregroundStyle(RankdColors.textPrimary)
            
            Text(label)
                .font(RankdTypography.caption)
                .foregroundStyle(RankdColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TierPreviewRow: View {
    let tier: Tier
    let label: String
    let count: Int
    
    var body: some View {
        HStack {
            Circle()
                .fill(RankdColors.tierColor(tier))
                .frame(width: 8, height: 8)
            Text(label)
                .font(RankdTypography.bodyMedium)
                .foregroundStyle(RankdColors.textSecondary)
            Spacer()
            Text("\(count) movies")
                .font(RankdTypography.labelMedium)
                .foregroundStyle(RankdColors.textPrimary)
        }
    }
}

private struct MatchedEntryRow: View {
    let entry: MatchedEntry
    
    var body: some View {
        HStack(spacing: RankdSpacing.sm) {
            if let url = entry.tmdbResult?.posterURL {
                CachedPosterImage(
                    url: url,
                    width: 36,
                    height: 54,
                    cornerRadius: RankdRadius.sm
                )
            }
            
            VStack(alignment: .leading, spacing: RankdSpacing.xxs) {
                Text(entry.entry.name)
                    .font(RankdTypography.bodyMedium)
                    .foregroundStyle(RankdColors.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: RankdSpacing.xs) {
                    if let year = entry.entry.year {
                        Text(year)
                            .font(RankdTypography.labelSmall)
                            .foregroundStyle(RankdColors.textTertiary)
                    }
                    
                    if let tier = entry.entry.tier {
                        Circle()
                            .fill(RankdColors.tierColor(tier))
                            .frame(width: 8, height: 8)
                    }
                    
                    Text(entry.entry.starDisplay)
                        .font(RankdTypography.labelSmall)
                        .foregroundStyle(RankdColors.brand)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, RankdSpacing.xxs)
    }
}

#Preview {
    LetterboxdImportView()
        .modelContainer(for: [RankedItem.self, WatchlistItem.self], inMemory: true)
}
