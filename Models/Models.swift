import Foundation
import SwiftData

enum GoalStatus: String, Codable, CaseIterable, Identifiable {
    case active, paused, completed, archived
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

@Model
final class Goal {
    @Attribute(.unique) var goalID: UUID
    var name: String
    var goalDescription: String
    var weeklyTarget: Int
    var creationDate: Date
    var statusRaw: String
    var gradientThemeID: String
    var iconName: String
    var reminderEnabled: Bool
    var reminderTime: Date
    /// Calendar weekday numbers: 1 = Sunday ... 7 = Saturday
    var reminderDays: [Int]

    @Relationship(deleteRule: .cascade, inverse: \CheckIn.goal) var checkIns: [CheckIn] = []
    @Relationship(deleteRule: .cascade, inverse: \Achievement.goal) var achievements: [Achievement] = []
    @Relationship(deleteRule: .cascade, inverse: \Reflection.goal) var reflections: [Reflection] = []

    var status: GoalStatus {
        get { GoalStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }
    var theme: GradientTheme { GradientTheme.theme(for: gradientThemeID) }

    static var defaultReminderTime: Date {
        Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: .now) ?? .now
    }

    init(name: String,
         goalDescription: String = "",
         weeklyTarget: Int = 3,
         gradientThemeID: String = GradientTheme.all[0].id,
         iconName: String = "sparkles",
         reminderEnabled: Bool = false,
         reminderTime: Date = Goal.defaultReminderTime,
         reminderDays: [Int] = Array(1...7),
         status: GoalStatus = .active) {
        self.goalID = UUID()
        self.name = name
        self.goalDescription = goalDescription
        self.weeklyTarget = weeklyTarget
        self.creationDate = .now
        self.statusRaw = status.rawValue
        self.gradientThemeID = gradientThemeID
        self.iconName = iconName
        self.reminderEnabled = reminderEnabled
        self.reminderTime = reminderTime
        self.reminderDays = reminderDays
    }
}

@Model
final class CheckIn {
    @Attribute(.unique) var checkInID: UUID
    var goalID: UUID
    /// Always normalised to start-of-day.
    var completionDate: Date
    var creationTimestamp: Date
    var goal: Goal?

    init(goal: Goal, date: Date) {
        self.checkInID = UUID()
        self.goalID = goal.goalID
        self.completionDate = date
        self.creationTimestamp = .now
        self.goal = goal
    }
}

@Model
final class Achievement {
    @Attribute(.unique) var achievementID: UUID
    /// "first_checkin", "week_complete:<weekStartEpoch>", "streak:<weeks>"
    var achievementType: String
    var achievementDate: Date
    var goal: Goal?

    init(type: String, goal: Goal) {
        self.achievementID = UUID()
        self.achievementType = type
        self.achievementDate = .now
        self.goal = goal
    }

    var title: String {
        if achievementType == "first_checkin" { return "First check-in" }
        if achievementType.hasPrefix("week_complete") { return "Weekly target met" }
        if achievementType.hasPrefix("streak:"), let n = Int(achievementType.dropFirst(7)) { return "\(n)-week streak" }
        return "Achievement"
    }
    var icon: String {
        if achievementType == "first_checkin" { return "star.fill" }
        if achievementType.hasPrefix("streak:") { return "flame.fill" }
        return "checkmark.seal.fill"
    }
}

@Model
final class Reflection {
    @Attribute(.unique) var reflectionID: UUID
    var weekStartDate: Date
    var reason: String
    var notes: String
    var goal: Goal?

    init(goal: Goal, weekStart: Date, reason: String, notes: String) {
        self.reflectionID = UUID()
        self.weekStartDate = weekStart
        self.reason = reason
        self.notes = notes
        self.goal = goal
    }
}
