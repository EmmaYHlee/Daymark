import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \Goal.creationDate) private var goals: [Goal]
    @Query(sort: \Achievement.achievementDate, order: .reverse) private var achievements: [Achievement]
    @AppStorage("weekStartDay") private var weekStartDay = 0
    @Environment(\.colorScheme) private var scheme

    private var calendar: Calendar { AppCalendar.make(weekStart: weekStartDay) }

    var body: some View {
        let all = goals.map { ($0, ProgressEngine.stats(for: $0, calendar: calendar)) }
        let totalCheckIns = all.reduce(0) { $0 + $1.1.totalCheckIns }
        let totalWeeks = all.reduce(0) { $0 + $1.1.successfulWeeks }
        let bestStreak = all.map { $0.1.bestStreak }.max() ?? 0

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        StatTile(title: "Check-ins", value: "\(totalCheckIns)", icon: "checkmark.circle.fill")
                        StatTile(title: "Good weeks", value: "\(totalWeeks)", icon: "checkmark.seal.fill")
                        StatTile(title: "Best streak", value: "\(bestStreak) wk", icon: "flame.fill")
                    }

                    if !goals.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("By goal").font(.title3.bold())
                            Card {
                                VStack(spacing: 14) {
                                    ForEach(all, id: \.0.goalID) { goal, s in
                                        HStack(spacing: 12) {
                                            Circle().fill(goal.theme.gradient(scheme)).frame(width: 14, height: 14)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(goal.name).font(.subheadline.weight(.semibold))
                                                Text("\(s.currentStreak) wk streak · \(s.totalCheckIns) check-ins")
                                                    .font(.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Text("\(Int((s.completionRate * 100).rounded()))%")
                                                .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Achievements").font(.title3.bold())
                        if achievements.isEmpty {
                            Text("Check in to start earning achievements.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        } else {
                            Card {
                                VStack(spacing: 14) {
                                    ForEach(achievements) { a in
                                        HStack(spacing: 12) {
                                            Image(systemName: a.icon)
                                                .foregroundStyle(a.goal?.theme.accent(scheme) ?? .accentColor)
                                                .frame(width: 24)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(a.title).font(.subheadline.weight(.semibold))
                                                Text(a.goal?.name ?? "").font(.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Text(a.achievementDate.formatted(date: .abbreviated, time: .omitted))
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Progress")
        }
    }
}
