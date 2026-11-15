import SwiftUI
import SwiftData

struct GoalDetailView: View {
    let goal: Goal
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @AppStorage("weekStartDay") private var weekStartDay = 0

    @State private var month = Date.now
    @State private var selected = Calendar.current.startOfDay(for: .now)
    @State private var celebration: Celebration?
    @State private var showEdit = false
    @State private var showReflection = false
    @State private var confirmDelete = false

    private var calendar: Calendar { AppCalendar.make(weekStart: weekStartDay) }
    private var theme: GradientTheme { goal.theme }
    private var accent: Color { theme.accent(scheme) }

    var body: some View {
        let stats = ProgressEngine.stats(for: goal, calendar: calendar)
        let progress = ProgressEngine.weekProgress(for: goal, calendar: calendar)

        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    header(progress)
                    checkInButton
                    statsGrid(stats)
                    missedWeekCard(stats)
                    calendarCard
                    selectedDayCard
                    achievementsCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))

            if let celebration {
                CelebrationOverlay(celebration: celebration, accent: accent) { self.celebration = nil }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: celebration)
        .navigationTitle(goal.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showEdit = true } label: { Label("Edit", systemImage: "pencil") }
                    Section("Status") {
                        ForEach(GoalStatus.allCases.filter { $0 != goal.status }) { s in
                            Button("Mark as \(s.label)") { setStatus(s) }
                        }
                    }
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $showEdit) { GoalFormView(goal: goal) }
        .sheet(isPresented: $showReflection) {
            if let ws = missedWeekNeedingReflection(stats) {
                ReflectionSheet(goal: goal, weekStart: ws,
                                completed: ProgressEngine.checkInCount(for: goal, weekStarting: ws, calendar: calendar))
            }
        }
        .confirmationDialog("Delete this goal?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Goal", role: .destructive, action: deleteGoal)
        } message: {
            Text("All check-ins and history for this goal will be removed.")
        }
    }

    // MARK: Sections

    private func header(_ progress: WeekProgress) -> some View {
        let fg = theme.onGradient(scheme)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: goal.iconName).font(.title2)
                    .frame(width: 48, height: 48)
                    .background(fg.opacity(0.18), in: Circle())
                Spacer()
                if goal.status != .active {
                    Text(goal.status.label).font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(fg.opacity(0.18), in: Capsule())
                }
            }
            Text(goal.name).font(.title.bold())
            if !goal.goalDescription.isEmpty {
                Text(goal.goalDescription).font(.subheadline).opacity(0.9)
            }
            HStack {
                Text("\(progress.completed)/\(progress.target) days completed")
                Spacer()
                Text("\(progress.percent)%")
            }
            .font(.subheadline.weight(.semibold))
            ProgressBar(value: progress.fraction, tint: fg, track: fg.opacity(0.25), height: 10)
            Text(progress.remaining == 0
                 ? "Weekly target reached"
                 : "\(progress.remaining) remaining check-in\(progress.remaining == 1 ? "" : "s")")
                .font(.footnote).opacity(0.85)
        }
        .foregroundStyle(fg)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.gradient(scheme), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: accent.opacity(0.25), radius: 14, y: 8)
    }

    private var doneToday: Bool {
        ProgressEngine.checkedDays(goal, calendar).contains(calendar.startOfDay(for: .now))
    }

    private var checkInButton: some View {
        Button {
            selected = calendar.startOfDay(for: .now)
            month = .now
            perform(on: .now)
        } label: {
            Label(doneToday ? "Checked in today" : "Check in today",
                  systemImage: doneToday ? "checkmark.circle.fill" : "checkmark.circle")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(doneToday ? accent.opacity(0.15) : accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .foregroundStyle(doneToday ? accent : Color.white)
        }
        .disabled(doneToday)
    }

    private func statsGrid(_ s: GoalStats) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            StatTile(title: "Current streak", value: "\(s.currentStreak) wk", icon: "flame.fill", tint: accent)
            StatTile(title: "Best streak", value: "\(s.bestStreak) wk", icon: "trophy.fill", tint: accent)
            StatTile(title: "Successful weeks", value: "\(s.successfulWeeks)", icon: "checkmark.seal.fill", tint: accent)
            StatTile(title: "Total check-ins", value: "\(s.totalCheckIns)", icon: "calendar.badge.checkmark", tint: accent)
            StatTile(title: "Weekly completion rate", value: "\(Int((s.completionRate * 100).rounded()))%", icon: "chart.pie.fill", tint: accent)
            StatTile(title: "Weeks tracked", value: "\(s.evaluatedWeeks)", icon: "clock.fill", tint: accent)
        }
    }

    // Accountability: only shown for the week that just ended, until the user reflects on it.
    private func missedWeekNeedingReflection(_ stats: GoalStats) -> Date? {
        let thisWeek = ProgressEngine.weekStart(of: .now, calendar)
        guard let prev = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek),
              stats.missedWeeks.contains(prev),
              !goal.reflections.contains(where: { calendar.isDate($0.weekStartDate, inSameDayAs: prev) })
        else { return nil }
        return prev
    }

    @ViewBuilder
    private func missedWeekCard(_ stats: GoalStats) -> some View {
        if let ws = missedWeekNeedingReflection(stats) {
            let count = ProgressEngine.checkInCount(for: goal, weekStarting: ws, calendar: calendar)
            let pct = Int((Double(count) / Double(max(goal.weeklyTarget, 1)) * 100).rounded())
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Last week", systemImage: "arrow.uturn.forward.circle.fill").font(.headline)
                    Text("You completed \(count) of \(goal.weeklyTarget) days (\(pct)%). That week didn't hit the target, so your streak has reset — but your progress is still real. A fresh week starts now.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button("Reflect on it") { showReflection = true }
                        .buttonStyle(.borderedProminent).tint(accent)
                }
            }
        }
    }

    private var calendarCard: some View {
        Card { MonthCalendarView(goal: goal, month: $month, selected: $selected, calendar: calendar) }
    }

    private var selectedDayCard: some View {
        let day = calendar.startOfDay(for: selected)
        let isFuture = day > calendar.startOfDay(for: .now)
        let isDone = ProgressEngine.checkedDays(goal, calendar).contains(day)
        return Card {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(day.formatted(.dateTime.weekday(.wide).month(.wide).day())).font(.headline)
                    Text(isFuture ? "Future dates can't be checked in"
                         : isDone ? "Checked in" : "Not checked in")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button(isDone ? "Remove" : "Check in") { perform(on: day) }
                    .buttonStyle(.bordered)
                    .tint(isDone ? .red : accent)
                    .disabled(isFuture)
            }
        }
    }

    @ViewBuilder
    private var achievementsCard: some View {
        let items = goal.achievements.sorted { $0.achievementDate > $1.achievementDate }.prefix(5)
        if !items.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Achievements").font(.headline)
                    ForEach(Array(items)) { a in
                        HStack {
                            Image(systemName: a.icon).foregroundStyle(accent)
                            Text(a.title)
                            Spacer()
                            Text(a.achievementDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: Actions

    private func perform(on date: Date) {
        switch GoalActions.toggleCheckIn(goal: goal, on: date, context: context, calendar: calendar) {
        case .added:
            let stats = ProgressEngine.stats(for: goal, calendar: calendar)
            let progress = ProgressEngine.weekProgress(for: goal, calendar: calendar)
            Haptics.success()
            celebration = Celebration(message: Motivation.checkInMessage(stats: stats, progress: progress))
        case .removed:
            Haptics.light()
        case .futureDate:
            break
        }
    }

    private func setStatus(_ status: GoalStatus) {
        goal.status = status
        try? context.save()
        NotificationManager.shared.rescheduleAll(context: context)
    }

    private func deleteGoal() {
        dismiss()
        // Delete after the pop animation so the detail view never reads a deleted model.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            context.delete(goal)
            try? context.save()
            NotificationManager.shared.rescheduleAll(context: context)
        }
    }
}

struct ReflectionSheet: View {
    let goal: Goal
    let weekStart: Date
    let completed: Int
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private static let reasons = ["Busy schedule", "Low energy", "Lost motivation", "Travel or illness", "Forgot", "Something else"]
    @State private var reason = ReflectionSheet.reasons[0]
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("You completed \(completed) of \(goal.weeklyTarget) days that week. This is information, not a verdict.")
                        .font(.subheadline)
                }
                Section("What got in the way?") {
                    Picker("Main reason", selection: $reason) {
                        ForEach(Self.reasons, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("What would help next week?") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                }
                Section {
                    Text("One check-in is enough to get moving again.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Weekly reflection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Not now") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        context.insert(Reflection(goal: goal, weekStart: weekStart, reason: reason, notes: notes))
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
    }
}
