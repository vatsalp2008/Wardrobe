import SwiftUI

@main
struct WardrobeApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(container)
                .tint(DS.Colors.primary)
                .task {
                    try? await container.supabase.signInAnonymously()
                    await NotificationService.shared.requestAndScheduleDailyReminder()
                }
        }
    }
}
