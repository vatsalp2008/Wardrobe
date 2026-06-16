import SwiftUI

/// Profile tab (spec §7.1). Phase 5 fills this with user-photo management, wear-history stats,
/// notification preferences, and the budget setting used by Gap Finder.
struct ProfileView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                systemImage: "person.circle",
                title: "Profile",
                message: "Photo management, wear stats, notifications, and budget settings arrive in Phase 5."
            )
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    ProfileView().environmentObject(AppContainer())
}
