import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query(sort: \RankedItem.rank) private var rankedItems: [RankedItem]
    @Query private var watchlistItems: [WatchlistItem]
    
    @State private var showCompareView = false
    @State private var showLetterboxdImport = false
    
    private var movieItems: [RankedItem] {
        rankedItems.filter { $0.mediaType == .movie }.sorted { $0.rank < $1.rank }
    }
    
    private var tvItems: [RankedItem] {
        rankedItems.filter { $0.mediaType == .tv }.sorted { $0.rank < $1.rank }
    }
    
    private var topFour: [RankedItem] {
        Array(rankedItems.sorted { $0.dateAdded > $1.dateAdded }
            .sorted { $0.rank < $1.rank }
            .prefix(4))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Top 4 Showcase
                    topFourSection
                    
                    // Quick Stats
                    statsGrid
                    
                    // Taste Personality
                    if !rankedItems.isEmpty {
                        tasteSection
                    }
                    
                    // Compare Button
                    compareButton
                    
                    // Tier Breakdown
                    if !rankedItems.isEmpty {
                        tierBreakdown
                    }
                    
                    // Settings / Import
                    settingsSection
                }
                .padding(.vertical)
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showLetterboxdImport) {
                LetterboxdImportView()
            }
            .fullScreenCover(isPresented: $showCompareView) {
                NavigationStack {
                    CompareView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showCompareView = false }
                            }
                        }
                }
            }
        }
    }
    
    // MARK: - Top 4 Showcase
    
    private var topFourSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("My Top 4")
                    .font(.title2.bold())
                Spacer()
            }
            .padding(.horizontal)
            
            if topFour.isEmpty {
                emptyTopFour
            } else {
                topFourGrid
            }
        }
    }
    
    private var topFourGrid: some View {
        HStack(spacing: 12) {
            ForEach(Array(topFour.enumerated()), id: \.element.id) { index, item in
                TopFourCard(item: item, rank: index + 1)
            }
            
            // Fill remaining slots
            ForEach(0..<max(0, 4 - topFour.count), id: \.self) { _ in
                emptySlot
            }
        }
        .padding(.horizontal)
    }
    
    private var emptyTopFour: some View {
        HStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                emptySlot
            }
        }
        .padding(.horizontal)
    }
    
    private var emptySlot: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.secondary.opacity(0.1))
            .aspectRatio(2/3, contentMode: .fit)
            .overlay {
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
    }
    
    // MARK: - Stats Grid
    
    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatCard(
                value: "\(movieItems.count)",
                label: "Movies",
                icon: "film",
                color: .orange
            )
            
            StatCard(
                value: "\(tvItems.count)",
                label: "TV Shows",
                icon: "tv",
                color: .blue
            )
            
            StatCard(
                value: "\(watchlistItems.count)",
                label: "Watchlist",
                icon: "bookmark",
                color: .purple
            )
        }
        .padding(.horizontal)
    }
    
    // MARK: - Taste Personality
    
    private var tasteSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.orange)
                Text("Taste Profile")
                    .font(.headline)
                Spacer()
            }
            
            Text(tastePersonality)
                .font(.title3.bold())
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(tasteDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.08))
        )
        .padding(.horizontal)
    }
    
    private var tastePersonality: String {
        let total = rankedItems.count
        let movies = movieItems.count
        let tv = tvItems.count
        
        if total < 5 { return "Getting Started" }
        
        if movies > 0 && tv == 0 { return "Film Purist" }
        if tv > 0 && movies == 0 { return "Binge Watcher" }
        if Double(movies) / Double(total) > 0.75 { return "Movie Buff" }
        if Double(tv) / Double(total) > 0.75 { return "Series Devotee" }
        
        let goodCount = rankedItems.filter { $0.tier == .good }.count
        let badCount = rankedItems.filter { $0.tier == .bad }.count
        
        if Double(goodCount) / Double(total) > 0.7 { return "The Optimist" }
        if Double(badCount) / Double(total) > 0.4 { return "Tough Critic" }
        
        return "Well-Rounded Viewer"
    }
    
    private var tasteDescription: String {
        switch tastePersonality {
        case "Getting Started":
            return "Rank more titles to unlock your taste profile."
        case "Film Purist":
            return "You're all about the big screen. Cinema is your thing."
        case "Binge Watcher":
            return "Episodes over end credits. You love a good series."
        case "Movie Buff":
            return "Mostly movies with the occasional show. Classic taste."
        case "Series Devotee":
            return "You prefer the long game. Character development is key."
        case "The Optimist":
            return "You tend to love what you watch. Glass half full."
        case "Tough Critic":
            return "High standards. Not everything makes the cut."
        default:
            return "A healthy mix of movies and TV. You appreciate it all."
        }
    }
    
    // MARK: - Compare Button
    
    private var compareButton: some View {
        Button {
            showCompareView = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Compare")
                        .font(.headline)
                    Text("Refine your rankings with head-to-head picks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
    
    // MARK: - Settings Section
    
    private var settingsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
            }
            
            Button {
                showLetterboxdImport = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import from Letterboxd")
                            .font(.subheadline.weight(.medium))
                        Text("Bring in your ratings and watched films")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.secondarySystemBackground))
                )
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground).opacity(0.5))
        )
        .padding(.horizontal)
    }
    
    // MARK: - Tier Breakdown
    
    private var tierBreakdown: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Tier Breakdown")
                    .font(.headline)
                Spacer()
            }
            
            ForEach(Tier.allCases, id: \.self) { tier in
                let count = rankedItems.filter { $0.tier == tier }.count
                let fraction = rankedItems.isEmpty ? 0.0 : Double(count) / Double(rankedItems.count)
                
                TierBar(tier: tier, count: count, fraction: fraction)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
}

// MARK: - Top Four Card

private struct TopFourCard: View {
    let item: RankedItem
    let rank: Int
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topLeading) {
                AsyncImage(url: item.posterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.15))
                        .overlay {
                            Image(systemName: item.mediaType == .movie ? "film" : "tv")
                                .font(.title2)
                                .foregroundStyle(.tertiary)
                        }
                }
                .aspectRatio(2/3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Rank badge
                Text("#\(rank)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(6)
            }
            
            Text(item.title)
                .font(.caption2)
                .fontWeight(.medium)
                .lineLimit(1)
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title2.bold())
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Tier Bar

private struct TierBar: View {
    let tier: Tier
    let count: Int
    let fraction: Double
    
    var body: some View {
        HStack(spacing: 12) {
            Text(tier.emoji)
                .frame(width: 24)
            
            Text(tier.rawValue)
                .font(.subheadline)
                .frame(width: 64, alignment: .leading)
            
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4)
                    .fill(tierColor.opacity(0.3))
                    .frame(width: max(4, geo.size.width * fraction))
                    .animation(.easeOut(duration: 0.5), value: fraction)
            }
            .frame(height: 20)
            
            Text("\(count)")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }
    
    private var tierColor: Color {
        switch tier {
        case .good: return .green
        case .medium: return .yellow
        case .bad: return .red
        }
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [RankedItem.self, WatchlistItem.self], inMemory: true)
}
