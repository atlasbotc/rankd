import SwiftUI
import SwiftData

@main
struct RankdApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            RankedItem.self,
            WatchlistItem.self,
            CustomList.self,
            CustomListItem.self,
            UserProfile.self,
            Activity.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Clean expired disk cache entries on launch
                    await PosterCache.shared.cleanDiskCacheIfNeeded()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
