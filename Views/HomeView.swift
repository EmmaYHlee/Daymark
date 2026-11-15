import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Goal.creationDate) private var goals: [Goal]
    @AppStorage("weekStartDay") private var weekStartDay = 0
    @State private var path = NavigationPath()
    @State private var showCreate = false

    private var calendar: Calendar { AppCalendar.make(weekStart: weekStartDay) }
    private var activeGoals: [Goal] { goals.filter { $0.status == .active } }
    private var otherGoals: [Goal] { goals.filter { $0.status == .paused || $0.status == .completed } }

    private var greeting: String {
        let h = calendar.component(.hour, from: .now)
        return h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
    }

    private var doneToday: Int {
        let today = calendar.startOfDay(for: .now)
        return activeGoals.filter { ProgressEngine.checkedDays($0, calendar).contains(today) }.count
    }

    private var upcoming: [(Goal, Date)] {
        let items: [(Goal, Date)] = activeGoals.compactMap { g in
            guard let d = ReminderPlanner.fireDates(for: g, days: 8, calendar: calendar).first else { return nil }
            return (g, d)
        }
        return Array(items.sorted { $0.1 < $1.1 }.prefix(4))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if goals.isEmpty {
                        emptyState
                    } else {
                        if !activeGoals.isEmpty { todayCard }
                        announcements
                        goalsSection
                        if !otherGoals.isEmpty { otherSection }
                        if !upcoming.isEmpty { remindersSection }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Goal.self) { GoalDetailView(goal: $0) }
            .sheet(isPresented: $showCreate) {
                GoalFormView(goal: nil) { created in
                    DispatchQueue.main.async { path.append(created) }   // jump straight to the new goal's page
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting).font(.largeTitle.bold())
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Button { showCreate = true } label: {
                Image(systemName: "plus").font(.headline)
                    .frame(width: 44, height: 44)
                    .background(Color(.secondarySystemGroupedBackground), in: Circle())
            }
            .accessibilityLabel("New goal")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No goals yet", systemImage: "target")
        } description: {
            Text("Create your first goal and start building consistency.")
        } actions: {
            Button("Create a goal") { showCreate = true }.buttonStyle(.borderedProminent)
        }
        .padding(.top, 60)
    }

    private var todayCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Today").font(.headline)
                Text("\(doneToday) of \(activeGoals.count) goals checked in")
                    .font(.subheadline).foregroundStyle(.secondary)
                ProgressBar(value: Double(doneToday) / Double(max(activeGoals.count, 1)), tint: .accentColor)
            }
        }
    }

    private var announcements: some View {
        VStack(spacing: 10) {
            ForEach(AnnouncementEngine.make(goals: goals, calendar: calendar)) { a in
                HStack(spacing: 12) {
                    Image(systemName: a.icon).foregroundStyle(Color.accentColor)
                    Text(a.text).font(.subheadline)
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your goals").font(.title3.bold())
            ForEach(activeGoals) { goal in
                NavigationLink(value: goal) { GoalCardView(goal: goal, calendar: calendar) }
                    .buttonStyle(.plain)
            }
        }
    }

    private var otherSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paused & completed").font(.title3.bold())
            ForEach(otherGoals) { goal in
                NavigationLink(value: goal) { GoalCardView(goal: goal, calendar: calendar).opacity(0.55) }
                    .buttonStyle(.plain)
            }
        }
    }

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming reminders").font(.title3.bold())
            Card {
                VStack(spacing: 12) {
                    ForEach(upcoming, id: \.0.goalID) { goal, date in
                        HStack {
                            Image(systemName: goal.iconName).foregroundStyle(goal.theme.accent(.light))
                            Text(goal.name)
                            Spacer()
                            Text(calendar.isDateInToday(date)
                                 ? "Today, " + date.formatted(date: .omitted, time: .shortened)
                                 : date.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
