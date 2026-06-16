import SwiftUI

/// Gap Finder tab (spec §7.1). Phase 4 replaces the placeholder with the gap hero card
/// (missing item + outfits unlocked) and a horizontal scroll of shopping result cards.
struct GapFinderView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                systemImage: "magnifyingglass",
                title: "Gap Finder",
                message: "Discover the single purchase that unlocks the most new outfits. Coming in Phase 4."
            )
            .navigationTitle("Gap Finder")
        }
    }
}

#Preview {
    GapFinderView().environmentObject(AppContainer())
}
