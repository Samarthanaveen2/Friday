import FridayCore
import Foundation
import UserNotifications

/// Box reminders and timed to-dos ring as notifications. Rebuilt from the store after every change.
@MainActor
enum Notifier {
    private struct Alert: Sendable {
        let id: String
        let title: String
        let body: String
        let at: Date
    }

    static func sync(_ store: Store) {
        let now = Date.now
        var alerts: [Alert] = []
        for note in store.notes {
            guard let at = note.reminder, at > now else { continue }
            let title = note.title ?? String(note.text.split(separator: "\n").first ?? "Reminder")
            alerts.append(Alert(id: "box-" + note.id, title: title, body: note.title == nil ? "" : note.text, at: at))
        }
        for item in store.items where !item.done {
            guard let time = item.time, let at = CalendarService.date(item.date, time), at > now else { continue }
            alerts.append(Alert(id: "item-" + item.id, title: item.title, body: "", at: at))
        }
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard !alerts.isEmpty else { return }
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            for alert in alerts.prefix(60) {
                let content = UNMutableNotificationContent()
                content.title = alert.title
                if !alert.body.isEmpty { content.body = String(alert.body.prefix(160)) }
                content.sound = .default
                let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: alert.at)
                let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
                UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: alert.id, content: content, trigger: trigger))
            }
        }
    }
}
