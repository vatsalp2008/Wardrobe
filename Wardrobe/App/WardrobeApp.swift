import SwiftUI

@main
struct WardrobeApp: App {
    @StateObject private var container = AppContainer()
    @AppStorage(OnboardingStore.key) private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(container)
                .tint(DS.Colors.primary)
                .fullScreenCover(isPresented: .constant(!hasCompletedOnboarding)) {
                    OnboardingView()
                }
                .task {
                    try? await container.supabase.signInAnonymously()
                    // Only on returning launches: during onboarding the permissions page owns
                    // this call, and firing it here first would pre-empt the priming screen.
                    if hasCompletedOnboarding {
                        await NotificationService.shared.requestAndScheduleDailyReminder()
                    }
                }
        }
    }
}
