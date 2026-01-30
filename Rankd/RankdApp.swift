import SwiftUI
import SwiftData

@main
struct RankdApp: App {
    @State private var deepLinkTab: Int?
    @State private var showWhatsNew = false
    @AppStorage("lastSeenVersion") private var lastSeenVersion: String = ""
    
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
            ContentView(deepLinkTab: $deepLinkTab)
                .rankdDynamicTypeLimit()
                .task {
                    // Clean expired disk cache entries on launch
                    await PosterCache.shared.cleanDiskCacheIfNeeded()
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .onAppear {
                    let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                    if lastSeenVersion != currentVersion {
                        showWhatsNew = true
                    }
                }
                .sheet(isPresented: $showWhatsNew, onDismiss: {
                    let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                    lastSeenVersion = currentVersion
                }) {
                    WhatsNewView()
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "rankd" else { return }
        
        switch url.host {
        case "rankings":
            deepLinkTab = 1  // Rankings tab
        default:
            break
        }
    }
}
