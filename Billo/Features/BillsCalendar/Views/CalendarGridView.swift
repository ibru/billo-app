//  Created by Jiri Urbasek on 12/05/25.

import SwiftUI

struct CalendarPagedGridView: View {
    let months: [DateComponents]
    @Binding var pageIndex: Int
    let calendar: Calendar
    let today: Date
    let selectedDate: Date?
    let monthDataProvider: (DateComponents) -> CalendarMonthGridData
    let onSelectDay: (CalendarDayData) -> Void
    let onMonthChange: (DateComponents) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var rowHeight: CGFloat { 52 }
    private var rowSpacing: CGFloat { DesignSystem.Spacing.small }
    private var headerHeight: CGFloat { 20 }
    private var gridHeight: CGFloat {
        (rowHeight * 6) + (rowSpacing * 5) + headerHeight + DesignSystem.Spacing.small
    }

    var body: some View {
        TabView(selection: $pageIndex) {
            ForEach(Array(months.enumerated()), id: \.offset) { index, month in
                CalendarGridView(
                    displayedMonth: month,
                    calendar: calendar,
                    today: today,
                    selectedDate: selectedDate,
                    monthData: monthDataProvider(month),
                    onSelectDay: onSelectDay
                )
                .tag(index)
                .padding(.top, DesignSystem.Spacing.small)
                .frame(minHeight: gridHeight)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onChange(of: pageIndex) { _, newIndex in
            guard months.indices.contains(newIndex) else { return }
            onMonthChange(months[newIndex])
        }
    }
}

private struct CalendarGridView: View {
    let displayedMonth: DateComponents
    let calendar: Calendar
    let today: Date
    let selectedDate: Date?
    let monthData: CalendarMonthGridData
    let onSelectDay: (CalendarDayData) -> Void

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible()), count: 7)
    }

    var body: some View {
        let entries = dayEntries()

        VStack(spacing: DesignSystem.Spacing.small) {
            weekdayHeader

            LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.small) {
                ForEach(entries.indices, id: \.self) { index in
                    if let date = entries[index] {
                        CalendarDayCell(
                            date: date,
                            dayData: monthData[calendar.startOfDay(for: date)] ?? CalendarDayData(date: date, occurrences: [], payments: [], incomeOccurrences: []),
                            calendar: calendar,
                            today: today,
                            isToday: calendar.isDate(date, inSameDayAs: today),
                            isSelected: selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false,
                            onTap: { dayData in
                                onSelectDay(dayData)
                            }
                        )
                    } else {
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)
        }
        .padding(.bottom, DesignSystem.Spacing.small)
    }

    private var weekdayHeader: some View {
        let symbols = shiftedWeekdaySymbols()
        return HStack {
            ForEach(symbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
    }

    private func shiftedWeekdaySymbols() -> [String] {
        let symbols = calendar.shortWeekdaySymbols
        let startIndex = calendar.firstWeekday - 1
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    private func dayEntries() -> [Date?] {
        guard let monthStart = calendar.date(from: displayedMonth),
              let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let offset = (firstWeekday - calendar.firstWeekday + 7) % 7
        var entries: [Date?] = Array(repeating: nil, count: offset)

        for day in dayRange {
            if let date = calendar.date(bySetting: .day, value: day, of: monthStart) {
                entries.append(calendar.startOfDay(for: date))
            }
        }

        return entries
    }
}

@MainActor
private struct CalendarDayCell: View {
    let date: Date
    let dayData: CalendarDayData
    let calendar: Calendar
    let today: Date
    let isToday: Bool
    let isSelected: Bool
    let onTap: (CalendarDayData) -> Void

    private var dots: [DotIndicator] {
        DotIndicatorGenerator.dots(
            for: dayData,
            relativeTo: today,
            calendar: calendar
        )
    }

    var body: some View {
        Button {
            if dayData.hasItems {
                onTap(dayData)
            }
        } label: {
            ZStack {
                highlight

                VStack(spacing: 6) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.body.weight(isToday ? .semibold : .regular))
                        .frame(maxWidth: .infinity)

                    if dayData.hasItems {
                        HStack(spacing: 3) {
                            ForEach(dots.prefix(4)) { dot in
                                Circle()
                                    .fill(color(for: dot.color))
                                    .frame(width: 8, height: 8)
                            }
                            if dots.count > 4 {
                                Text("+\(dots.count - 4)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.small)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.plain)
        .disabled(!dayData.hasItems)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(dayData.hasItems ? "Double-tap to open day details" : "No bills or payments on this day")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var highlight: some View {
        if isToday {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 44, height: 44)
        } else if isSelected {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.22))
                .frame(width: 44, height: 44)
        }
    }

    private func color(for dotColor: DotColor) -> Color {
        switch dotColor {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .gray: return .gray
        case .green: return .green
        case .income: return DesignSystem.Color.income
        }
    }

    private var accessibilityLabel: String {
        let dayString = date.formatted(.dateTime.month(.abbreviated).day())
        let occurrenceCount = dayData.occurrences.count
        let paymentCount = dayData.payments.count
        let incomeCount = dayData.incomeOccurrences.count

        var components: [String] = [dayString]
        if isToday { components.append("today") }
        if isSelected { components.append("selected") }

        if dayData.hasItems {
            if incomeCount > 0 {
                components.append("\(incomeCount) income\(incomeCount == 1 ? "" : "s")")
            }
            components.append("\(occurrenceCount) bill\(occurrenceCount == 1 ? "" : "s")")
            components.append("\(paymentCount) payment\(paymentCount == 1 ? "" : "s")")
        } else {
            components.append("No bills or payments")
        }

        return components.joined(separator: ", ")
    }
}
