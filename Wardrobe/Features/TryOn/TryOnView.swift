import SwiftUI

/// Try-On tab (spec §7.1). Phase 3 replaces the placeholder with the photo-upload setup flow
/// and the split-screen try-on result (original vs composited).
struct TryOnView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                systemImage: "person.crop.rectangle",
                title: "Virtual Try-On",
                message: "Upload one full-body photo to preview outfits on yourself. Coming in Phase 3."
            )
            .navigationTitle("Try On")
        }
    }
}

#Preview {
    TryOnView().environmentObject(AppContainer())
}
