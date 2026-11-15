import Foundation
import UserNotifications
import SwiftData

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    private let bodies = [
        "Time for your check-in. Small actions, consistent progress.",
        "A few minutes today keeps your week on track.",
        "Ready when you are — one check-in at a time.",
        "Keep the rhythm going."
    ]

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Fire-and-forget: rebuilds every pending reminder from current data.
    func rescheduleAll(context: ModelContext) {
        Task {
            let goals = (try? context.fetch(FetchDescriptor<Goal>())) ?? []
            await reschedule(goals: goals)
        }
    }

    /// Schedules one-shot notifications for the next few days instead of repeating ones, so a goal
    /// that's already checked in today doesn't buzz. iOS caps pending notifications at 64, so the
    /// horizon shrinks as the number of reminder-enabled goals grows.
    func reschedule(goals: [Goal]) async {
        let status = await authorizationStatus()
        center.removeAllPendingNotificationRequests()
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        let calendar = AppCalendar.current
        let active = goals.filter { $0.status == .active && $0.reminderEnabled && !$0.reminderDays.isEmpty }
        guard !active.isEmpty else { return }
        let horizon = max(2, min(14, 60 / active.count))

        for goal in active {
            for fire in ReminderPlanner.fireDates(for: goal, days: horizon, calendar: calendar) {
                let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                let content = UNMutableNotificationContent()
                content.title = goal.name
                content.body = bodies.randomElement() ?? bodies[0]
                content.sound = .default
                let id = "\(goal.goalID.uuidString)-\(Int(fire.timeIntervalSince1970))"
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }
        }
    }
}
