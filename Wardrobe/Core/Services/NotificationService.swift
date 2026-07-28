import Foundation
import UserNotifications

/// Daily outfit-suggestion reminder (spec §5.2 / §2.1 UserNotifications).
/// Requests authorization, then schedules a repeating local notification each morning.
struct NotificationService {
    static let shared = NotificationService()

    /// UserDefaults key for the Profile reminder toggle. Owned here so onboarding and Profile
    /// can't drift apart on the literal.
    static let remindersEnabledKey = "settings.dailyRemindersEnabled"

    private let dailyIdentifier = "daily-outfit-reminder"

    /// Requests permission and (if granted) schedules the daily reminder. Safe to call on launch.
    /// Returns whether authorization was granted, so onboarding can reflect it in the UI.
    @discardableResult
    func requestAndScheduleDailyReminder(hour: Int = 8) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return false }
        scheduleDaily(at: hour, center: center)
        return true
    }

    /// Cancels the daily reminder (used when the user turns it off in Profile).
    func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailyIdentifier])
    }

    private func scheduleDaily(at hour: Int, center: UNUserNotificationCenter) {
        let content = UNMutableNotificationContent()
        content.title = "Today's Outfits"
        content.body = "Your AI-picked outfits for today are ready. Tap to see them."
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: dailyIdentifier, content: content, trigger: trigger)

        center.removePendingNotificationRequests(withIdentifiers: [dailyIdentifier])
        center.add(request)
    }
}
