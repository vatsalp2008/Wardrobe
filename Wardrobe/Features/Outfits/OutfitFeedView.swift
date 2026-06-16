import SwiftUI

/// Outfits tab (spec §7.1). Phase 2 replaces the placeholder with a vertical feed of
/// AI-generated outfit cards, occasion filter chips, and pull-to-refresh.
struct OutfitFeedView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                systemImage: "sparkles",
                title: "Daily Outfits",
                message: "AI-curated outfit suggestions from your wardrobe will appear here in Phase 2."
            )
            .navigationTitle("Outfits")
        }
    }
}

#Preview {
    OutfitFeedView().environmentObject(AppContainer())
}
