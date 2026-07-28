import AVFoundation
import Foundation

/// Drives the first-run intro (spec §7.3): three slides, then permission priming.
///
/// Only camera and notifications are primed. The photo library needs no permission — both entry
/// points use `PhotosPicker`/`PHPicker`, which run out of process — and location is only required
/// by WeatherKit, which isn't enabled yet.
@MainActor
final class OnboardingViewModel: ObservableObject {
    static let slideCount = 3
    /// Three slides plus the permissions page.
    static let pageCount = slideCount + 1

    @Published var page = 0
    @Published private(set) var cameraPrimed = false
    @Published private(set) var notificationsPrimed = false

    private let store: OnboardingStore

    init(store: OnboardingStore = OnboardingStore()) {
        self.store = store
    }

    var isOnPermissionsPage: Bool { page >= Self.slideCount }

    func advance() {
        page = min(page + 1, Self.pageCount - 1)
    }

    /// Asks for camera access up front, so the prompt doesn't interrupt the first capture.
    /// The Simulator has no camera and grants immediately — harmless, the flow just proceeds.
    func primeCamera() async {
        cameraPrimed = await AVCaptureDevice.requestAccess(for: .video)
    }

    /// Requests notification authorization and schedules the daily reminder. On success the
    /// Profile toggle is written explicitly, so it shows the real state instead of its default.
    func primeNotifications() async {
        let granted = await NotificationService.shared.requestAndScheduleDailyReminder()
        notificationsPrimed = granted
        if granted {
            UserDefaults.standard.set(true, forKey: NotificationService.remindersEnabledKey)
        }
    }

    func finish() {
        store.hasCompletedOnboarding = true
    }
}
