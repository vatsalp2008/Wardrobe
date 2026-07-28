import XCTest
@testable import Wardrobe

/// Onboarding tests — the first-run completion flag and page advancement.
final class OnboardingTests: XCTestCase {

    private func freshDefaults() -> UserDefaults {
        let name = "onboarding.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testDefaultsToNotCompleted() {
        let store = OnboardingStore(defaults: freshDefaults())
        XCTAssertFalse(store.hasCompletedOnboarding)
    }

    func testCompletionPersistsAcrossInstances() {
        let defaults = freshDefaults()
        OnboardingStore(defaults: defaults).hasCompletedOnboarding = true
        XCTAssertTrue(OnboardingStore(defaults: defaults).hasCompletedOnboarding)
    }

    /// `WardrobeApp` binds `@AppStorage(OnboardingStore.key)`. If the literal ever drifts out of
    /// the `settings.` namespace the binding silently reads a different value, so pin it.
    func testKeyStaysInSettingsNamespace() {
        XCTAssertEqual(OnboardingStore.key, "settings.hasCompletedOnboarding")
    }

    @MainActor
    func testAdvanceStopsAtPermissionsPage() {
        let viewModel = OnboardingViewModel(store: OnboardingStore(defaults: freshDefaults()))
        XCTAssertFalse(viewModel.isOnPermissionsPage)
        for _ in 0..<10 { viewModel.advance() }
        XCTAssertEqual(viewModel.page, OnboardingViewModel.pageCount - 1)
        XCTAssertTrue(viewModel.isOnPermissionsPage)
    }

    @MainActor
    func testFinishMarksOnboardingComplete() {
        let defaults = freshDefaults()
        let store = OnboardingStore(defaults: defaults)
        OnboardingViewModel(store: store).finish()
        XCTAssertTrue(OnboardingStore(defaults: defaults).hasCompletedOnboarding)
    }
}
