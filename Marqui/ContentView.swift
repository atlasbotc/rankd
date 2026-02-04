import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab = 0
    @Binding var deepLinkTab: Int?
    
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
        .animation(MarquiMotion.normal, value: selectedTab)
        .tint(MarquiColors.brand)
        .onChange(of: deepLinkTab) { _, newTab in
            if let tab = newTab {
                selectedTab = tab
                deepLinkTab = nil
            }
        }
        .onAppear {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithOpaqueBackground()
            tabBarAppearance.backgroundColor = UIColor(MarquiColors.background)
            
            let normalColor = UIColor(MarquiColors.textTertiary)
            let selectedColor = UIColor(MarquiColors.brand)
            
            tabBarAppearance.stackedLayoutAppearance.normal.iconColor = normalColor
            tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
            tabBarAppearance.stackedLayoutAppearance.selected.iconColor = selectedColor
            tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
            
            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
    }
}

#Preview {
    ContentView(deepLinkTab: .constant(nil))
        .modelContainer(for: [RankedItem.self, WatchlistItem.self], inMemory: true)
}
