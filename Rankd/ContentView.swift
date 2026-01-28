import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab = 0
    
    var body: some View {
        if hasCompletedOnboarding {
            mainTabView
        } else {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
    }
    
    private var mainTabView: some View {
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
            
            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(2)
            
            WatchlistView()
                .tabItem {
                    Label("Watchlist", systemImage: "bookmark")
                }
                .tag(3)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
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
