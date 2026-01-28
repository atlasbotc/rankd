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
    case medium = "Add as 🟡 Medium"
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
            .animation(.easeInOut(duration: 0.3), value: step)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if step != .importing {
                        Button("Cancel") { dismiss() }
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
            VStack(spacing: 32) {
                Spacer(minLength: 20)
                
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)
                }
                
                // Header
                VStack(spacing: 12) {
                    Text("Import from Letterboxd")
                        .font(.title2.bold())
                    
                    Text("Bring your movie ratings into Rankd. We'll match them with TMDB and sort them into tiers.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal)
                
                // Steps
                VStack(alignment: .leading, spacing: 20) {
                    InstructionRow(
                        number: "1",
                        text: "Go to **letterboxd.com/settings/data/**"
                    )
                    InstructionRow(
                        number: "2",
                        text: "Click **Export Your Data** and download the ZIP"
                    )
                    InstructionRow(
                        number: "3",
                        text: "Unzip and select **ratings.csv** below"
                    )
                }
                .padding(.horizontal, 24)
                
                // Select File Button
                Button {
                    showFilePicker = true
                } label: {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                        Text("Select CSV File")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                
                // Note
                Text("You can also import **watched.csv** or **diary.csv** — movies without ratings will be handled separately.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Spacer(minLength: 40)
            }
        }
    }
    
    // MARK: - Step 2: Matching
    
    private var matchingView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse)
            }
            
            VStack(spacing: 8) {
                Text("Matching \(entries.count) movies")
                    .font(.title3.bold())
                
                Text("Finding each movie on TMDB...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 12) {
                ProgressView(value: matchProgress.fraction)
                    .tint(.orange)
                    .scaleEffect(y: 2)
                    .clipShape(Capsule())
                
                HStack(spacing: 16) {
                    Label("\(matchProgress.matched)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    
                    Label("\(matchProgress.notFound)", systemImage: "questionmark.circle.fill")
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text("\(matchProgress.processed) / \(matchProgress.total)")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
            .padding(.horizontal, 32)
            
            if entries.count > 100 {
                let estimatedSeconds = entries.count / 20 // ~10 per 0.5s
                Text("Estimated time: ~\(estimatedSeconds / 60 + 1) min")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Step 3: Review
    
    private var reviewView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Summary Card
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        SummaryBadge(
                            icon: "checkmark.circle.fill",
                            count: matchedOnly.count,
                            label: "Matched",
                            color: .green
                        )
                        SummaryBadge(
                            icon: "questionmark.circle.fill",
                            count: notFoundEntries.count,
                            label: "Not Found",
                            color: .orange
                        )
                        SummaryBadge(
                            icon: "arrow.right.circle.fill",
                            count: duplicateCount,
                            label: "Already In Rankd",
                            color: .secondary
                        )
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal)
                
                // Tier Breakdown
                VStack(spacing: 16) {
                    HStack {
                        Text("Tier Breakdown")
                            .font(.headline)
                        Spacer()
                    }
                    
                    TierPreviewRow(emoji: "🟢", label: "Good (4-5★)", count: goodEntries.count, color: .green)
                    TierPreviewRow(emoji: "🟡", label: "Medium (2.5-3.5★)", count: mediumEntries.count, color: .yellow)
                    TierPreviewRow(emoji: "🔴", label: "Bad (0.5-2★)", count: badEntries.count, color: .red)
                    
                    Divider()
                    
                    // Unrated handling
                    VStack(spacing: 12) {
                        HStack {
                            Text("Unrated")
                                .font(.subheadline.bold())
                            Spacer()
                            Text("\(unratedEntries.count) movies")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
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
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal)
                
                // Expandable matched list
                DisclosureGroup(isExpanded: $showMatchedList) {
                    LazyVStack(spacing: 8) {
                        ForEach(importableEntries) { entry in
                            MatchedEntryRow(entry: entry)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    HStack {
                        Image(systemName: "list.bullet")
                        Text("View all \(importableEntries.count) movies")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.orange)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal)
                
                // Import Button
                Button {
                    startImport()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import \(totalToImport) Movies")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(totalToImport > 0 ? Color.orange : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(totalToImport == 0)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .padding(.top)
        }
    }
    
    // MARK: - Step 4: Importing
    
    private var importingView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
                    .symbolEffect(.bounce, options: .repeating)
            }
            
            VStack(spacing: 8) {
                Text("Importing...")
                    .font(.title3.bold())
                
                Text("\(importProgress) / \(importTotal)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            
            ProgressView(value: Double(importProgress), total: Double(max(1, importTotal)))
                .tint(.orange)
                .scaleEffect(y: 2)
                .clipShape(Capsule())
                .padding(.horizontal, 48)
            
            Spacer()
        }
    }
    
    // MARK: - Step 5: Done
    
    private var doneView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
            }
            
            VStack(spacing: 12) {
                Text("🎉 Imported \(importedCount) movies!")
                    .font(.title2.bold())
                
                Text("Your rankings are ready.\nYou can refine them with comparisons anytime.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
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
        
        // Build the list of entries to import with their target tier
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
        
        // Handle unrated
        switch unratedAction {
        case .medium:
            for entry in unratedEntries {
                toImport.append((entry, .medium))
            }
        case .watchlist, .skip:
            break // handled separately below
        }
        
        importTotal = toImport.count + (unratedAction == .watchlist ? unratedEntries.count : 0)
        importProgress = 0
        importedCount = 0
        
        Task {
            // Sort for rank assignment: Good by rating desc, Medium by rating desc, Bad by rating desc
            let sorted = toImport.sorted { a, b in
                let tierOrder: [Tier: Int] = [.good: 0, .medium: 1, .bad: 2]
                let aTier = tierOrder[a.1] ?? 1
                let bTier = tierOrder[b.1] ?? 1
                if aTier != bTier { return aTier < bTier }
                return (a.0.entry.rating ?? 0) > (b.0.entry.rating ?? 0)
            }
            
            // Get current max rank to append after existing items
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
                
                // Small yield to keep UI responsive
                if importedCount % 20 == 0 {
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                }
            }
            
            // Handle unrated → watchlist
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
            
            // Save
            await MainActor.run {
                try? modelContext.save()
                step = .done
            }
        }
    }
}

// MARK: - Supporting Views

private struct InstructionRow: View {
    let number: String
    let text: LocalizedStringKey
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(number)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.orange)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
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
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            
            Text("\(count)")
                .font(.title3.bold())
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TierPreviewRow: View {
    let emoji: String
    let label: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack {
            Text(emoji)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text("\(count) movies")
                .font(.subheadline.bold())
                .foregroundStyle(color)
        }
    }
}

private struct MatchedEntryRow: View {
    let entry: MatchedEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // Poster thumbnail
            if let url = entry.tmdbResult?.posterURL {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.secondary.opacity(0.2)
                }
                .frame(width: 36, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.entry.name)
                    .font(.subheadline)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if let year = entry.entry.year {
                        Text(year)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let tier = entry.entry.tier {
                        Text(tier.emoji)
                            .font(.caption)
                    }
                    
                    Text(entry.entry.starDisplay)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    LetterboxdImportView()
        .modelContainer(for: [RankedItem.self, WatchlistItem.self], inMemory: true)
}
