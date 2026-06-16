import SwiftUI

/// Closet tab (spec §7.1). Phase 1 replaces the placeholder with a `LazyVGrid` of
/// `ClothingCardView`s fetched from the wardrobe, plus a category/color/season filter bar.
struct ClosetView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                systemImage: "square.grid.2x2",
                title: "Your Closet",
                message: "Tap + to photograph a clothing item. Captured items will appear here in Phase 1."
            )
            .navigationTitle("Closet")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // Phase 1: present the Closet Scanner capture flow.
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

#Preview {
    ClosetView().environmentObject(AppContainer())
}
