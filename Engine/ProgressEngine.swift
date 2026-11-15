import Foundation
import SwiftUI
import SwiftData

// MARK: - Calendar

enum AppCalendar {
    /// weekStart: 0 = system default, otherwise Calendar weekday number (1 = Sunday, 2 = Monday, 7 = Saturday)
    static func make(weekStart: Int) -> Calendar {
        var c = Calendar.current
        if weekStart != 0 { c.firstWeekday = weekStart }
        return c
    }
    static var current: Calendar { make(weekStart: UserDefaults.standard.integer(forKey: "weekStartDay")) }
}

// MARK: - Value types

struct WeekProgress {
    let completed: Int
    let target: Int
    var fraction: Double { min(1, Double(completed) / Double(max(target, 1))) }
    var percent: Int { Int((fraction * 100).rounded()) }
    var remaining: Int { max(0, target - completed) }
}

struct DayStatus: Identifiable {
    let date: Date
    let done: Bool
    var id: Date { date }
}

struct GoalStats {
    var currentStreak = 0
    var bestStreak = 0
    var successfulWeeks = 0
    var evaluatedWeeks = 0
    var totalCheckIns = 0
    var missedWeeks: [Date] = []
    var completionRate: Double { evaluatedWeeks == 0 ? 0 : Double(successfulWeeks) / Double(evaluatedWeeks) }
}

// MARK: - Progress engine

enum ProgressEngine {
    static func weekStart(of date: Date, _ calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    static func checkedDays(_ goal: Goal, _ calendar: Calendar) -> Set<Date> {
        Set(goal.checkIns.map { calendar.startOfDay(for: $0.completionDate) })
    }

    static func checkInCount(for goal: Goal, weekStarting start: Date, calendar: Calendar) -> Int {
        guard let end = calendar.date(byAdding: .day, value: 7, to: start) else { return 0 }
        return checkedDays(goal, calendar).filter { $0 >= start && $0 < end }.count
    }

    static func weekProgress(for goal: Goal, calendar: Calendar, now: Date = .now) -> WeekProgress {
        WeekProgress(completed: checkInCount(for: goal, weekStarting: weekStart(of: now, calendar), calendar: calendar),
                     target: goal.weeklyTarget)
    }

    static func weekDays(for goal: Goal, calendar: Calendar, now: Date = .now) -> [DayStatus] {
        let start = weekStart(of: now, calendar)
        let done = checkedDays(goal, calendar)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
            .map { DayStatus(date: $0, done: done.contains($0)) }
    }

    /// Days remaining in the current week, including today.
    static func daysLeftInWeek(calendar: Calendar, now: Date = .now) -> Int {
        guard let end = calendar.date(byAdding: .day, value: 7, to: weekStart(of: now, calendar)) else { return 0 }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: end).day ?? 0
    }

    /// Weekly streak rules:
    /// - A past week succeeds if check-ins >= target; otherwise it's a missed week and resets the streak.
    /// - The *current* week is never counted as a failure; it only adds to the streak once the target is met.
    /// - The week in which the goal was created is a grace week (can succeed, can't fail) because it's usually partial.
    static func stats(for goal: Goal, calendar: Calendar, now: Date = .now) -> GoalStats {
        var result = GoalStats()
        let days = checkedDays(goal, calendar)
        result.totalCheckIns = days.count

        var counts: [Date: Int] = [:]
        for d in days { counts[weekStart(of: d, calendar), default: 0] += 1 }

        let currentWeek = weekStart(of: now, calendar)
        let creationWeek = weekStart(of: goal.creationDate, calendar)
        let earliest = min(goal.creationDate, days.min() ?? goal.creationDate)
        var cursor = weekStart(of: earliest, calendar)
        let target = max(goal.weeklyTarget, 1)

        var run = 0
        while cursor < currentWeek {
            if (counts[cursor] ?? 0) >= target {
                run += 1
                result.successfulWeeks += 1
                result.evaluatedWeeks += 1
                result.bestStreak = max(result.bestStreak, run)
            } else if cursor == creationWeek {
                // grace week: neither success nor failure
            } else {
                run = 0
                result.evaluatedWeeks += 1
                result.missedWeeks.append(cursor)
            }
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) else { break }
            cursor = next
        }

        if (counts[currentWeek] ?? 0) >= target {
            run += 1
            result.successfulWeeks += 1
            result.evaluatedWeeks += 1
            result.bestStreak = max(result.bestStreak, run)
        }
        result.currentStreak = run
        return result
    }
}

// MARK: - Reminders

enum ReminderPlanner {
    /// Upcoming reminder fire dates, skipping days that are already checked in and days not selected.
    static func fireDates(for goal: Goal, days horizon: Int, calendar: Calendar, now: Date = .now) -> [Date] {
        guard goal.status == .active, goal.reminderEnabled else { return [] }
        let done = ProgressEngine.checkedDays(goal, calendar)
        let time = calendar.dateComponents([.hour, .minute], from: goal.reminderTime)
        let today = calendar.startOfDay(for: now)
        return (0..<horizon).compactMap { offset -> Date? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  goal.reminderDays.contains(calendar.component(.weekday, from: day)),
                  !done.contains(day),
                  let fire = calendar.date(bySettingHour: time.hour ?? 20, minute: time.minute ?? 0, second: 0, of: day),
                  fire > now else { return nil }
            return fire
        }
    }
}

// MARK: - Check-in actions

enum CheckInResult { case added, removed, futureDate }

@MainActor
enum GoalActions {
    static let streakMilestones = [2, 4, 8, 12, 26, 52]

    static func toggleCheckIn(goal: Goal, on date: Date, context: ModelContext, calendar: Calendar) -> CheckInResult {
        let day = calendar.startOfDay(for: date)
        guard day <= calendar.startOfDay(for: .now) else { return .futureDate }

        if let existing = goal.checkIns.first(where: { calendar.isDate($0.completionDate, inSameDayAs: day) }) {
            context.delete(existing)
            try? context.save()
            NotificationManager.shared.rescheduleAll(context: context)
            return .removed
        }

        context.insert(CheckIn(goal: goal, date: day))
        try? context.save()
        awardAchievements(for: goal, checkedDate: day, context: context, calendar: calendar)
        NotificationManager.shared.rescheduleAll(context: context)
        return .added
    }

    private static func awardAchievements(for goal: Goal, checkedDate: Date, context: ModelContext, calendar: Calendar) {
        let stats = ProgressEngine.stats(for: goal, calendar: calendar)
        var wanted: [String] = []
        if stats.totalCheckIns >= 1 { wanted.append("first_checkin") }

        let ws = ProgressEngine.weekStart(of: checkedDate, calendar)
        if ProgressEngine.checkInCount(for: goal, weekStarting: ws, calendar: calendar) >= goal.weeklyTarget {
            wanted.append("week_complete:\(Int(ws.timeIntervalSince1970))")
        }
        for m in streakMilestones where stats.currentStreak >= m { wanted.append("streak:\(m)") }

        let existing = Set(goal.achievements.map(\.achievementType))
        for type in wanted where !existing.contains(type) {
            context.insert(Achievement(type: type, goal: goal))
        }
        try? context.save()
    }
}

// MARK: - Messages

enum Motivation {
    private static let generic = [
        "Nice work — small actions add up.",
        "One more day in the books.",
        "Consistency beats intensity. Well done.",
        "You showed up. That's what counts.",
        "Progress, one day at a time."
    ]

    static func checkInMessage(stats: GoalStats, progress: WeekProgress) -> String {
        if progress.completed == progress.target {
            return stats.currentStreak > 1
            ? "Weekly target met — that's \(stats.currentStreak) successful weeks in a row!"
            : "Weekly target met. Great week!"
        }
        let base = generic.randomElement() ?? generic[0]
        if progress.remaining > 0 && progress.completed > 0 {
            return "\(base) \(progress.remaining) more to hit this week's target."
        }
        return base
    }
}

struct Announcement: Identifiable {
    let icon: String
    let text: String
    var id: String { text }
}

enum AnnouncementEngine {
    private static func plural(_ n: Int, _ word: String) -> String { "\(n) \(word)\(n == 1 ? "" : "s")" }

    static func make(goals: [Goal], calendar: Calendar) -> [Announcement] {
        var items: [Announcement] = []
        let thisWeek = ProgressEngine.weekStart(of: .now, calendar)
        let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek)
        let daysLeft = ProgressEngine.daysLeftInWeek(calendar: calendar)

        for goal in goals where goal.status == .active {
            let stats = ProgressEngine.stats(for: goal, calendar: calendar)
            let progress = ProgressEngine.weekProgress(for: goal, calendar: calendar)

            if progress.completed >= progress.target {
                if stats.currentStreak >= 2 {
                    items.append(Announcement(icon: "flame.fill",
                        text: "You've successfully maintained \(goal.name) for \(stats.currentStreak) consecutive weeks!"))
                } else {
                    items.append(Announcement(icon: "checkmark.seal.fill",
                        text: "Weekly target met for \(goal.name). Nicely done."))
                }
            } else if progress.remaining >= daysLeft {
                items.append(Announcement(icon: "clock.fill",
                    text: "\(goal.name) needs \(plural(progress.remaining, "more check-in")) — \(plural(daysLeft, "day")) left this week."))
            } else if let lastWeek, stats.missedWeeks.contains(lastWeek), progress.completed == 0 {
                items.append(Announcement(icon: "arrow.clockwise",
                    text: "Last week got away from \(goal.name). Today is a good day to restart."))
            }
        }
        if items.isEmpty {
            items.append(Announcement(icon: "sparkles", text: "Small actions. Consistent progress. Meaningful growth."))
        }
        return Array(items.prefix(3))
    }
}
