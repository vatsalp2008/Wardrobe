import Foundation
import UserNotifications

/// Daily outfit-suggestion reminder (spec §5.2 / §2.1 UserNotifications).
/// Requests authorization, then schedules a repeating local notification each morning.
struct NotificationService {
    static let shared = NotificationService()

    private let dailyIdentifier = "daily-outfit-reminder"

    /// Requests permission and (if granted) schedules the daily reminder. Safe to call on launch.
    func requestAndScheduleDailyReminder(hour: Int = 8) async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return }
        scheduleDaily(at: hour, center: center)
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
