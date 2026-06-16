import SwiftUI

/// The five-tab shell (spec §7.1). Tabs hold placeholder screens in Phase 0 and are filled
/// in by their respective feature phases.
struct RootTabView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        TabView {
            ClosetView(container: container)
                .tabItem { Label("Closet", systemImage: "square.grid.2x2") }

            OutfitFeedView(container: container)
                .tabItem { Label("Outfits", systemImage: "sparkles") }

            TryOnView(container: container)
                .tabItem { Label("Try On", systemImage: "person.crop.rectangle") }

            GapFinderView(container: container)
                .tabItem { Label("Gap Finder", systemImage: "magnifyingglass") }

            ProfileView(container: container)
                .tabItem { Label("Profile", systemImage: "person.circle") }
        }
    }
}

#Preview {
    RootTabView()
        .environmentObject(AppContainer())
}
