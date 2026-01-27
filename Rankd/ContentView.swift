import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DiscoverView()
                .tabItem {
                    Label("Discover", systemImage: "sparkles")
                }
                .tag(0)
            
            RankedListView()
                .tabItem {
                    Label("Rankings", systemImage: "list.number")
                }
                .tag(1)
            
            WatchlistView()
                .tabItem {
                    Label("Watchlist", systemImage: "bookmark")
                }
                .tag(2)
            
            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(3)
            
            CompareView()
                .tabItem {
                    Label("Compare", systemImage: "arrow.left.arrow.right")
                }
                .tag(4)
        }
        .tint(.orange)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [RankedItem.self, WatchlistItem.self], inMemory: true)
}
