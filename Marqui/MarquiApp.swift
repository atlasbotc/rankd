import SwiftUI
import SwiftData

@main
struct MarquiApp: App {
    @State private var deepLinkTab: Int?
    @State private var whatsNewVersion: WhatsNewItem?
    @AppStorage("lastSeenVersion") private var lastSeenVersion: String = ""
    
    @State private var containerError: String?
    
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
            // Fallback to in-memory container so the app doesn't crash
            print("⚠️ Persistent ModelContainer failed: \(error). Falling back to in-memory store.")
            let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [inMemoryConfig])
            } catch {
                // Last resort: bare-minimum container
                return try! ModelContainer(for: schema)
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(deepLinkTab: $deepLinkTab)
                .marquiDynamicTypeLimit()
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
                        whatsNewVersion = WhatsNewItem(version: currentVersion)
                    }
                }
                .sheet(item: $whatsNewVersion, onDismiss: {
                    let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                    lastSeenVersion = currentVersion
                }) { _ in
                    WhatsNewView()
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    /// Identifiable wrapper for the WhatsNew sheet item binding.
    struct WhatsNewItem: Identifiable {
        let id = UUID()
        let version: String
    }
    
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "marqui" else { return }
        
        switch url.host {
        case "rankings":
            deepLinkTab = 1  // Rankings tab
        default:
            break
        }
    }
}
