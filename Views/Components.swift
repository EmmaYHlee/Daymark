import SwiftUI

struct ProgressBar: View {
    var value: Double
    var tint: Color
    var track: Color = Color.secondary.opacity(0.2)
    var height: CGFloat = 8
    @AppStorage("animationEnabled") private var animationEnabled = true

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(tint)
                    .frame(width: value > 0 ? max(height, geo.size.width * min(value, 1)) : 0)
            }
        }
        .frame(height: height)
        .animation(animationEnabled ? .easeInOut(duration: 0.6) : nil, value: value)
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let icon: String
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.subheadline).foregroundStyle(tint)
            Text(value).font(.title2.weight(.semibold).monospacedDigit())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }
}

struct GoalCardView: View {
    let goal: Goal
    let calendar: Calendar
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let theme = goal.theme
        let progress = ProgressEngine.weekProgress(for: goal, calendar: calendar)
        let stats = ProgressEngine.stats(for: goal, calendar: calendar)
        let days = ProgressEngine.weekDays(for: goal, calendar: calendar)
        let fg = theme.onGradient(scheme)

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: goal.iconName)
                    .font(.title3)
                    .frame(width: 40, height: 40)
                    .background(fg.opacity(0.18), in: Circle())
                Spacer()
                if stats.currentStreak > 0 {
                    Label("\(stats.currentStreak) wk", systemImage: "flame.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(fg.opacity(0.18), in: Capsule())
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.name).font(.headline)
                Text("\(progress.completed)/\(progress.target) days this week")
                    .font(.subheadline).opacity(0.85)
            }
            ProgressBar(value: progress.fraction, tint: fg, track: fg.opacity(0.25))
            HStack(spacing: 6) {
                ForEach(days) { d in
                    Circle().fill(d.done ? fg : fg.opacity(0.25)).frame(width: 9, height: 9)
                }
            }
        }
        .foregroundStyle(fg)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.gradient(scheme), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: theme.accent(scheme).opacity(0.25), radius: 12, y: 6)
    }
}
