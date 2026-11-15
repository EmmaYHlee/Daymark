import SwiftUI

struct MonthCalendarView: View {
    let goal: Goal
    @Binding var month: Date
    @Binding var selected: Date
    let calendar: Calendar
    @Environment(\.colorScheme) private var scheme

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var checkedDays: Set<Date> { ProgressEngine.checkedDays(goal, calendar) }

    private var cells: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let count = calendar.range(of: .day, in: .month, for: interval.start)?.count else { return [] }
        let first = interval.start
        let leading = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        let days: [Date?] = (0..<count).map { calendar.date(byAdding: .day, value: $0, to: first) }
        return [Date?](repeating: nil, count: leading) + days
    }

    private var weekdaySymbols: [String] {
        let s = calendar.veryShortWeekdaySymbols
        return (0..<7).map { s[(calendar.firstWeekday - 1 + $0) % 7] }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(month.formatted(.dateTime.month(.wide).year())).font(.headline)
                Spacer()
                if !calendar.isDate(month, equalTo: .now, toGranularity: .month) {
                    Button("Today") {
                        withAnimation { month = .now; selected = calendar.startOfDay(for: .now) }
                    }.font(.subheadline)
                }
                Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("Previous month")
                Button { shift(1) } label: { Image(systemName: "chevron.right") }
                    .accessibilityLabel("Next month")
            }
            .tint(goal.theme.accent(scheme))

            HStack(spacing: 4) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, s in
                    Text(s).font(.caption.weight(.medium)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                    if let date { cell(for: date) } else { Color.clear.frame(height: 40) }
                }
            }
            .id(month)   // fresh identity per month so the grid cross-fades
            .transition(.opacity)

            legend
        }
    }

    private func shift(_ value: Int) {
        if let next = calendar.date(byAdding: .month, value: value, to: month) {
            withAnimation(.easeInOut(duration: 0.2)) { month = next }
            Haptics.selection()
        }
    }

    @ViewBuilder
    private func cell(for date: Date) -> some View {
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: .now)
        let done = checkedDays.contains(day)
        let isToday = day == today
        let isFuture = day > today
        let isMissed = !done && day < today && day >= calendar.startOfDay(for: goal.creationDate)
        let isSelected = calendar.isDate(day, inSameDayAs: selected)
        let accent = goal.theme.accent(scheme)

        Button {
            withAnimation(.easeInOut(duration: 0.15)) { selected = day }
            Haptics.selection()
        } label: {
            ZStack {
                if done {
                    Circle().fill(accent)
                } else if isToday {
                    Circle().fill(accent.opacity(0.15))
                }
                if isToday { Circle().strokeBorder(accent, lineWidth: 1.5) }
                if isSelected { Circle().strokeBorder(Color.primary.opacity(0.55), lineWidth: 1.5).padding(-3) }

                Text("\(calendar.component(.day, from: day))")
                    .font(.callout.weight(done || isToday ? .semibold : .regular))
                    .foregroundStyle(done ? Color.white
                                     : isFuture ? Color.secondary.opacity(0.5)
                                     : isMissed ? Color.secondary : Color.primary)

                if isMissed {
                    Circle().fill(Color.red.opacity(0.45)).frame(width: 4, height: 4).offset(y: 15)
                }
            }
            .frame(height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).month().day()) + (done ? ", checked in" : ""))
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(Circle().fill(goal.theme.accent(scheme)).frame(width: 10, height: 10), "Done")
            legendItem(Circle().fill(Color.red.opacity(0.45)).frame(width: 6, height: 6), "Missed")
            legendItem(Circle().strokeBorder(goal.theme.accent(scheme), lineWidth: 1.5).frame(width: 10, height: 10), "Today")
            Spacer()
        }
        .font(.caption).foregroundStyle(.secondary)
    }

    private func legendItem<S: View>(_ shape: S, _ label: String) -> some View {
        HStack(spacing: 5) { shape; Text(label) }
    }
}
