import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            RankedListView()
                .tabItem {
                    Label("Rankings", systemImage: "list.number")
                }
                .tag(0)
            
            SearchView()
                .tabItem {
                    Label("Add", systemImage: "plus.circle")
                }
                .tag(1)
            
            CompareView()
                .tabItem {
                    Label("Compare", systemImage: "arrow.left.arrow.right")
                }
                .tag(2)
        }
        .tint(.orange)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: RankedItem.self, inMemory: true)
}
