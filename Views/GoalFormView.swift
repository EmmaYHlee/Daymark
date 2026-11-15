import SwiftUI
import SwiftData

struct GoalFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @AppStorage("weekStartDay") private var weekStartDay = 0

    let goal: Goal?
    var onSaved: ((Goal) -> Void)?

    @State private var name: String
    @State private var desc: String
    @State private var target: Int
    @State private var themeID: String
    @State private var icon: String
    @State private var reminderEnabled: Bool
    @State private var reminderTime: Date
    @State private var reminderDays: Set<Int>
    @State private var status: GoalStatus

    init(goal: Goal? = nil, onSaved: ((Goal) -> Void)? = nil) {
        self.goal = goal
        self.onSaved = onSaved
        _name = State(initialValue: goal?.name ?? "")
        _desc = State(initialValue: goal?.goalDescription ?? "")
        _target = State(initialValue: goal?.weeklyTarget ?? 3)
        _themeID = State(initialValue: goal?.gradientThemeID ?? GradientTheme.all[0].id)
        _icon = State(initialValue: goal?.iconName ?? "sparkles")
        _reminderEnabled = State(initialValue: goal?.reminderEnabled ?? false)
        _reminderTime = State(initialValue: goal?.reminderTime ?? Goal.defaultReminderTime)
        _reminderDays = State(initialValue: Set(goal?.reminderDays ?? Array(1...7)))
        _status = State(initialValue: goal?.status ?? .active)
    }

    private var calendar: Calendar { AppCalendar.make(weekStart: weekStartDay) }
    private var theme: GradientTheme { GradientTheme.theme(for: themeID) }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                previewSection
                Section("Goal") {
                    TextField("Name", text: $name)
                    TextField("Description (optional)", text: $desc, axis: .vertical)
                }
                Section("Weekly target") {
                    Stepper("\(target) day\(target == 1 ? "" : "s") per week", value: $target, in: 1...7)
                }
                Section("Theme") { themeGrid }
                Section("Icon") { iconGrid }
                Section("Reminder") {
                    Toggle("Remind me", isOn: $reminderEnabled.animation())
                    if reminderEnabled {
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        dayChips
                    }
                }
                if goal != nil {
                    Section("Status") {
                        Picker("Status", selection: $status) {
                            ForEach(GoalStatus.allCases) { Text($0.label).tag($0) }
                        }
                    }
                }
            }
            .navigationTitle(goal == nil ? "New Goal" : "Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(!canSave) }
            }
        }
    }

    private var previewSection: some View {
        Section {
            let fg = theme.onGradient(scheme)
            HStack(spacing: 14) {
                Image(systemName: icon).font(.title2)
                    .frame(width: 46, height: 46)
                    .background(fg.opacity(0.18), in: Circle())
                VStack(alignment: .leading) {
                    Text(name.isEmpty ? "Your goal" : name).font(.headline)
                    Text("\(target) days per week").font(.subheadline).opacity(0.85)
                }
                Spacer()
            }
            .foregroundStyle(fg)
            .padding(18)
            .background(theme.gradient(scheme), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private var themeGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 14) {
            ForEach(GradientTheme.all) { t in
                Button { themeID = t.id; Haptics.selection() } label: {
                    VStack(spacing: 6) {
                        Circle().fill(t.gradient(scheme)).frame(width: 48, height: 48)
                            .overlay {
                                if themeID == t.id {
                                    Image(systemName: "checkmark").font(.headline).foregroundStyle(t.onGradient(scheme))
                                }
                            }
                        Text(t.name).font(.caption2).lineLimit(1).minimumScaleFactor(0.7).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private var iconGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
            ForEach(goalIcons, id: \.self) { name in
                Button { icon = name; Haptics.selection() } label: {
                    Image(systemName: name)
                        .frame(width: 42, height: 42)
                        .background(icon == name ? theme.accent(scheme) : Color(.tertiarySystemFill), in: Circle())
                        .foregroundStyle(icon == name ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private var dayChips: some View {
        let symbols = calendar.veryShortWeekdaySymbols
        let order = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
        return HStack {
            ForEach(order, id: \.self) { wd in
                let on = reminderDays.contains(wd)
                Button {
                    if on { reminderDays.remove(wd) } else { reminderDays.insert(wd) }
                    Haptics.selection()
                } label: {
                    Text(symbols[wd - 1])
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 34, height: 34)
                        .background(on ? theme.accent(scheme) : Color(.tertiarySystemFill), in: Circle())
                        .foregroundStyle(on ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let g: Goal
        if let goal { g = goal } else {
            g = Goal(name: trimmed)
            context.insert(g)
        }
        g.name = trimmed
        g.goalDescription = desc
        g.weeklyTarget = target
        g.gradientThemeID = themeID
        g.iconName = icon
        g.reminderEnabled = reminderEnabled
        g.reminderTime = reminderTime
        g.reminderDays = reminderDays.sorted()
        if goal != nil { g.status = status }
        try? context.save()

        let wantsReminders = reminderEnabled
        Task {
            if wantsReminders { _ = await NotificationManager.shared.requestAuthorization() }
            NotificationManager.shared.rescheduleAll(context: context)
        }
        Haptics.success()
        dismiss()
        onSaved?(g)
    }
}
