import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink { AppearanceSettingsView() } label: { Label("Appearance", systemImage: "paintbrush.fill") }
                NavigationLink { NotificationSettingsView() } label: { Label("Notifications & Reminders", systemImage: "bell.fill") }
                NavigationLink { GeneralSettingsView() } label: { Label("General", systemImage: "gearshape.fill") }
            }
            .navigationTitle("Settings")
        }
    }
}

struct AppearanceSettingsView: View {
    @AppStorage("appearanceMode") private var appearanceRaw = AppearanceMode.system.rawValue

    var body: some View {
        List {
            Section {
                ForEach(AppearanceMode.allCases) { mode in
                    Button {
                        appearanceRaw = mode.rawValue
                        Haptics.selection()
                    } label: {
                        HStack {
                            Label(mode.label, systemImage: mode.icon)
                            Spacer()
                            if appearanceRaw == mode.rawValue {
                                Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            } footer: {
                Text("Goal gradients adjust automatically for dark mode. Your choice is saved on this device.")
            }
        }
        .navigationTitle("Appearance")
    }
}

struct NotificationSettingsView: View {
    @Query(sort: \Goal.creationDate) private var goals: [Goal]
    @Environment(\.openURL) private var openURL
    @State private var status: UNAuthorizationStatus = .notDetermined

    private var statusText: String {
        switch status {
        case .authorized, .provisional, .ephemeral: return "On"
        case .denied: return "Off in iOS Settings"
        default: return "Not set up"
        }
    }

    var body: some View {
        List {
            Section {
                HStack { Text("Notifications"); Spacer(); Text(statusText).foregroundStyle(.secondary) }
                if status == .notDetermined {
                    Button("Allow notifications") {
                        Task { _ = await NotificationManager.shared.requestAuthorization(); await refresh() }
                    }
                } else if status == .denied {
                    Button("Open iOS Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
            } footer: {
                Text("Reminders are scheduled on this device and work without internet. A goal won't remind you on a day you've already checked in. Choose reminder days when editing a goal.")
            }

            Section("Goal reminders") {
                if goals.isEmpty { Text("No goals yet").foregroundStyle(.secondary) }
                ForEach(goals) { ReminderRow(goal: $0, onChange: { Task { await refresh() } }) }
            }
        }
        .navigationTitle("Reminders")
        .task { await refresh() }
    }

    private func refresh() async { status = await NotificationManager.shared.authorizationStatus() }
}

private struct ReminderRow: View {
    @Bindable var goal: Goal
    var onChange: () -> Void
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading) {
            Toggle(goal.name, isOn: $goal.reminderEnabled)
            if goal.reminderEnabled {
                DatePicker("Time", selection: $goal.reminderTime, displayedComponents: .hourAndMinute)
            }
        }
        .onChange(of: goal.reminderEnabled) { _, enabled in
            Task {
                if enabled { _ = await NotificationManager.shared.requestAuthorization() }
                NotificationManager.shared.rescheduleAll(context: context)
                onChange()
            }
        }
        .onChange(of: goal.reminderTime) { _, _ in NotificationManager.shared.rescheduleAll(context: context) }
    }
}

struct GeneralSettingsView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("weekStartDay") private var weekStartDay = 0
    @AppStorage("animationEnabled") private var animationEnabled = true
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @State private var confirmReset = false

    var body: some View {
        List {
            Section("Calendar") {
                Picker("Week starts on", selection: $weekStartDay) {
                    Text("System default").tag(0)
                    Text("Sunday").tag(1)
                    Text("Monday").tag(2)
                    Text("Saturday").tag(7)
                }
            }
            Section {
                Toggle("Celebration animations", isOn: $animationEnabled)
                Toggle("Haptic feedback", isOn: $hapticEnabled)
            } header: {
                Text("Feedback")
            } footer: {
                Text("Animations also respect the iOS Reduce Motion setting.")
            }
            Section {
                Label("All data stays on this device. Daymark never connects to a server.", systemImage: "lock.fill")
                    .font(.subheadline)
            } header: { Text("Privacy") }
            Section {
                Button("Delete all data", role: .destructive) { confirmReset = true }
            }
        }
        .navigationTitle("General")
        .onChange(of: weekStartDay) { _, _ in NotificationManager.shared.rescheduleAll(context: context) }
        .confirmationDialog("Delete all goals and history?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Delete Everything", role: .destructive) {
                let goals = (try? context.fetch(FetchDescriptor<Goal>())) ?? []
                goals.forEach { context.delete($0) }
                try? context.save()
                NotificationManager.shared.rescheduleAll(context: context)
            }
        } message: { Text("This can't be undone.") }
    }
}
