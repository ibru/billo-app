//  Created by Jiri Urbasek on 12/05/25.

import SwiftUI
import Foundation
#if os(iOS)
import UIKit
#endif

struct CalendarPagedGridView: View {
    let months: [DateComponents]
    @Binding var pageIndex: Int
    let calendar: Calendar
    let today: Date
    let selectedDate: Date?
    let monthDataProvider: (DateComponents) -> CalendarMonthGridData
    let onSelectDay: (CalendarDayData) -> Void
    let onMonthChange: (DateComponents) -> Void

    /// Base row height scales with Dynamic Type (relative to callout font)
    /// Accounts for: day circle (36) + dot spacing (2) + dot size (6) = 44
    @ScaledMetric(relativeTo: .callout) private var rowHeight: CGFloat = 44
    /// Header height scales with Dynamic Type (relative to caption2 font used in weekday header)
    @ScaledMetric(relativeTo: .caption2) private var headerHeight: CGFloat = 14

    private var rowSpacing: CGFloat { DesignSystem.Spacing.extraSmall }

    private func gridHeight(for month: DateComponents) -> CGFloat {
        let rowCount = CGFloat(numberOfRows(for: month))
        let topPadding = DesignSystem.Spacing.extraSmall   // .padding(.top) on each page
        let headerToGridSpacing = DesignSystem.Spacing.extraSmall  // VStack spacing in CalendarGridView
        let bottomInset = DesignSystem.Spacing.extraSmall  // clearance for last row dots
        return (rowHeight * rowCount) + (rowSpacing * (rowCount - 1)) + headerHeight + headerToGridSpacing + topPadding + bottomInset
    }

    private func numberOfRows(for month: DateComponents) -> Int {
        guard let monthStart = calendar.date(from: month),
              let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return 6
        }
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let offset = (firstWeekday - calendar.firstWeekday + 7) % 7
        let totalCells = offset + dayRange.count
        return (totalCells + 6) / 7 // Ceiling division
    }

    private var currentMonth: DateComponents? {
        guard months.indices.contains(pageIndex) else { return nil }
        return months[pageIndex]
    }

    private var showsMonthNavigationHeader: Bool {
#if os(iOS)
        return UIDevice.current.userInterfaceIdiom != .phone
#else
        return true
#endif
    }

    private var monthTitle: String {
        guard let currentMonth,
              let date = calendar.date(from: currentMonth) else { return "" }
        return date.formatted(.dateTime.month(.wide).year())
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.extraSmall) {
            if showsMonthNavigationHeader {
                monthNavigationHeader
                    .padding(.horizontal, DesignSystem.Spacing.medium)
            }

            TabView(selection: $pageIndex) {
                ForEach(Array(months.enumerated()), id: \.offset) { index, month in
                    CalendarGridView(
                        displayedMonth: month,
                        calendar: calendar,
                        today: today,
                        selectedDate: selectedDate,
                        monthData: monthDataProvider(month),
                        rowHeight: rowHeight,
                        onSelectDay: onSelectDay
                    )
                    .tag(index)
                    .padding(.top, DesignSystem.Spacing.extraSmall)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: currentMonth.map { gridHeight(for: $0) } ?? gridHeight(for: months.first ?? DateComponents()))
        }
        .animation(.easeInOut(duration: 0.2), value: pageIndex)
        .accessibilityScrollAction { edge in
            guard !months.isEmpty else { return }
            switch edge {
            case .leading:
                pageIndex = max(0, pageIndex - 1)
            case .trailing:
                pageIndex = min(months.count - 1, pageIndex + 1)
            default:
                break
            }
        }
        .onChange(of: pageIndex) { _, newIndex in
            guard months.indices.contains(newIndex) else { return }
            onMonthChange(months[newIndex])
        }
    }

    private var monthNavigationHeader: some View {
        let canGoToPrevious = !months.isEmpty && pageIndex > 0
        let canGoToNext = !months.isEmpty && pageIndex < (months.count - 1)

        return HStack(spacing: DesignSystem.Spacing.medium) {
            Button {
                guard canGoToPrevious else { return }
                pageIndex -= 1
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.semibold))
                    .frame(minWidth: 24, minHeight: 24)
            }
            .buttonStyle(.plain)
            .disabled(!canGoToPrevious)
            .accessibilityLabel(Text("Previous month"))

            Text(monthTitle)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityAddTraits(.isHeader)

            Button {
                guard canGoToNext else { return }
                pageIndex += 1
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.semibold))
                    .frame(minWidth: 24, minHeight: 24)
            }
            .buttonStyle(.plain)
            .disabled(!canGoToNext)
            .accessibilityLabel(Text("Next month"))
        }
        .padding(.vertical, DesignSystem.Spacing.extraSmall)
    }
}

private struct CalendarGridView: View {
    let displayedMonth: DateComponents
    let calendar: Calendar
    let today: Date
    let selectedDate: Date?
    let monthData: CalendarMonthGridData
    let rowHeight: CGFloat
    let onSelectDay: (CalendarDayData) -> Void

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible()), count: 7)
    }

    var body: some View {
        let entries = dayEntries()

        VStack(spacing: DesignSystem.Spacing.extraSmall) {
            weekdayHeader

            LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.extraSmall) {
                ForEach(entries.indices, id: \.self) { index in
                    if let date = entries[index] {
                        CalendarDayCell(
                            date: date,
                            dayData: monthData[calendar.startOfDay(for: date)] ?? CalendarDayData(date: date),
                            calendar: calendar,
                            today: today,
                            isToday: calendar.isDate(date, inSameDayAs: today),
                            isSelected: selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false,
                            onTap: { dayData in
                                onSelectDay(dayData)
                            }
                        )
                        .frame(height: rowHeight)
                    } else {
                        Color.clear
                            .frame(height: rowHeight)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)
        }
    }

    private var weekdayHeader: some View {
        let symbols = shiftedWeekdaySymbols()
        let weekendIndices = weekendColumnIndices()
        return VStack(spacing: DesignSystem.Spacing.small) {
            HStack {
                ForEach(Array(symbols.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(weekendIndices.contains(index) ? Color(uiColor: .secondaryLabel) : Color(uiColor: .label))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)

            Divider()
                .padding(.horizontal, DesignSystem.Spacing.medium)
        }
    }

    private func weekendColumnIndices() -> Set<Int> {
        // Find which column indices are Saturday (7) and Sunday (1)
        let saturdayWeekday = 7
        let sundayWeekday = 1
        let firstWeekday = calendar.firstWeekday

        let saturdayIndex = (saturdayWeekday - firstWeekday + 7) % 7
        let sundayIndex = (sundayWeekday - firstWeekday + 7) % 7

        return [saturdayIndex, sundayIndex]
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

    /// Dot indicator size scales with Dynamic Type
    @ScaledMetric(relativeTo: .caption2) private var dotSize: CGFloat = 6
    /// Horizontal spacing between individual dots
    @ScaledMetric(relativeTo: .caption2) private var dotGap: CGFloat = 1
    /// Vertical gap between bottom of day circle and top of dots row
    @ScaledMetric(relativeTo: .caption2) private var numberToDotSpacing: CGFloat = -2
    /// Fixed layout slot for day number; keeps row height stable if circleSize changes
    @ScaledMetric(relativeTo: .callout) private var daySlotSize: CGFloat = 36
    /// Circle diameter for today/selected highlight, scales with Dynamic Type
    @ScaledMetric(relativeTo: .callout) private var circleSize: CGFloat = 30

    private var isWeekend: Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7 // Sunday = 1, Saturday = 7
    }

    private var dayNumberColor: Color {
        isWeekend ? Color(uiColor: .secondaryLabel) : Color(uiColor: .label)
    }

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
            VStack(spacing: 0) {
                ZStack {
                    if isToday {
                        Circle()
                            .fill(DesignSystem.Color.yellow)
                            .frame(width: circleSize, height: circleSize)
                    } else if isSelected {
                        Circle()
                            .fill(DesignSystem.Color.yellow.opacity(0.25))
                            .frame(width: circleSize, height: circleSize)
                    }

                    Text("\(calendar.component(.day, from: date))")
                        .font(.callout.weight(isToday ? .semibold : .regular))
                        .foregroundColor(isToday ? Color(white: 0.2) : dayNumberColor)
                }
                .frame(width: daySlotSize, height: daySlotSize)

                HStack(spacing: dotGap) {
                    if dayData.hasItems {
                        ForEach(dots.prefix(4)) { dot in
                            Circle()
                                .fill(color(for: dot.color))
                                .frame(width: dotSize, height: dotSize)
                        }
                        if dots.count > 4 {
                            Text("+\(dots.count - 4)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(height: dotSize)
                .padding(.top, numberToDotSpacing)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(dayData.hasItems
                           ? String(
                            localized: "Double-tap to open day details",
                            comment: "Accessibility hint for a calendar day cell that has items"
                           )
                           : String(
                            localized: "No bills or payments on this day",
                            comment: "Accessibility hint for a calendar day cell that has no items"
                           )
        )
        .accessibilityAddTraits(.isButton)
    }

    private func color(for dotColor: DotColor) -> Color {
        switch dotColor {
        case .red: return DesignSystem.Color.red
        case .orange: return DesignSystem.Color.orange
        case .yellow: return DesignSystem.Color.yellow
        case .gray: return DesignSystem.Color.neutralDark
        case .green: return DesignSystem.Color.green
        case .income: return DesignSystem.Color.blue
        }
    }

    private var accessibilityLabel: String {
        let dayString = date.formatted(.dateTime.month(.abbreviated).day())
        let billCount = dayData.bills.count
        let paymentCount = dayData.payments.count
        let incomeCount = dayData.incomeOccurrences.count

        var components: [String] = [dayString]
        if isToday {
            components.append(String(localized: "today", comment: "Accessibility: day state (today)"))
        }
        if isSelected {
            components.append(String(localized: "selected", comment: "Accessibility: day state (selected)"))
        }

        if dayData.hasItems {
            if incomeCount > 0 {
                components.append(String(
                    localized: incomeCount == 1 ? "\(incomeCount) income" : "\(incomeCount) incomes",
                    comment: "Accessibility: calendar day cell income count"
                ))
            }
            components.append(String(
                localized: billCount == 1 ? "\(billCount) bill" : "\(billCount) bills",
                comment: "Accessibility: calendar day cell bill count"
            ))
            components.append(String(
                localized: paymentCount == 1 ? "\(paymentCount) payment" : "\(paymentCount) payments",
                comment: "Accessibility: calendar day cell payment count"
            ))
        } else {
            components.append(String(
                localized: "No bills or payments",
                comment: "Accessibility: calendar day cell empty state"
            ))
        }

        let listFormatter = ListFormatter()
        listFormatter.locale = .autoupdatingCurrent
        return listFormatter.string(from: components) ?? components.joined(separator: ", ")
    }
}

// MARK: - Previews

#Preview("Paged Grid") {
    struct PreviewWrapper: View {
        @State private var pageIndex = 1

        private let calendar = Calendar.current
        private let today = Date()

        private var months: [DateComponents] {
            let now = today
            return (-1...1).compactMap { offset in
                guard let date = calendar.date(byAdding: .month, value: offset, to: now) else { return nil }
                return calendar.dateComponents([.year, .month], from: date)
            }
        }

        var body: some View {
            CalendarPagedGridView(
                months: months,
                pageIndex: $pageIndex,
                calendar: calendar,
                today: today,
                selectedDate: nil,
                monthDataProvider: { _ in [:] },
                onSelectDay: { _ in },
                onMonthChange: { _ in }
            )
        }
    }

    return PreviewWrapper()
}

#Preview("With Sample Data") {
    struct PreviewWrapper: View {
        @State private var pageIndex = 1
        @State private var selectedDate: Date?

        private let calendar = Calendar.current
        private let today = Date()

        private var months: [DateComponents] {
            let now = today
            return (-1...1).compactMap { offset in
                guard let date = calendar.date(byAdding: .month, value: offset, to: now) else { return nil }
                return calendar.dateComponents([.year, .month], from: date)
            }
        }

        private func sampleMonthData(for month: DateComponents) -> CalendarMonthGridData {
            guard let monthStart = calendar.date(from: month) else { return [:] }

            var data: CalendarMonthGridData = [:]

            // Add some sample occurrences on different days
            let sampleBill = Bill(
                name: "Sample Bill",
                amount: 100,
                dueDate: today,
                categoryIdentifier: .predefined(.utilities)
            )

            // Day with unpaid bill (today)
            let todayStart = calendar.startOfDay(for: today)
            if calendar.isDate(todayStart, equalTo: monthStart, toGranularity: .month) {
                let occurrence = BillOccurrence(bill: sampleBill, dueDate: todayStart)
                data[todayStart] = CalendarDayData(
                    date: todayStart,
                    bills: [BillDisplay(occurrence: occurrence, status: .upcoming)]
                )
            }

            // Day with paid bill (5 days ago)
            if let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: today) {
                let fiveDaysAgoStart = calendar.startOfDay(for: fiveDaysAgo)
                if calendar.isDate(fiveDaysAgoStart, equalTo: monthStart, toGranularity: .month) {
                    let issued = IssuedOccurrence(
                        occurrenceKey: sampleBill.occurrenceKey(for: fiveDaysAgoStart, calendar: calendar),
                        dueDate: fiveDaysAgoStart,
                        billName: sampleBill.name,
                        billAmount: sampleBill.amount,
                        billCurrencyCode: sampleBill.currencyCode,
                        billAccountIdentifier: sampleBill.accountIdentifier,
                        billNotes: sampleBill.notes,
                        billCategoryRawValue: sampleBill.categoryIdentifier?.rawValue,
                        bill: sampleBill
                    )
                    let payment = PaymentEntry(
                        amount: 50,
                        datePaid: fiveDaysAgoStart,
                        confirmationNumber: nil,
                        issuedOccurrence: issued
                    )
                    data[fiveDaysAgoStart] = CalendarDayData(
                        date: fiveDaysAgoStart,
                        payments: [payment]
                    )
                }
            }

            // Day with income (10 days from now)
            if let tenDaysFromNow = calendar.date(byAdding: .day, value: 10, to: today) {
                let tenDaysStart = calendar.startOfDay(for: tenDaysFromNow)
                if calendar.isDate(tenDaysStart, equalTo: monthStart, toGranularity: .month) {
                    let income = Income(name: "Salary", amount: 5000, startDate: tenDaysStart)
                    data[tenDaysStart] = CalendarDayData(
                        date: tenDaysStart,
                        incomeOccurrences: [IncomeOccurrence(from: income, on: tenDaysStart)]
                    )
                }
            }

            let rentBill = Bill(name: "Rent", amount: 1200, dueDate: today, categoryIdentifier: .predefined(.housing))
            let streamingBill = Bill(name: "Netflix", amount: 15, dueDate: today, categoryIdentifier: .predefined(.subscriptions))
            let phoneBill = Bill(name: "Phone", amount: 60, dueDate: today, categoryIdentifier: .predefined(.utilities))
            let salary = Income(name: "Salary", amount: 5000, startDate: today)
            let freelance = Income(name: "Freelance", amount: 800, startDate: today)

            // Day with 3 future bills (multiple urgency dots)
            if let day2 = calendar.date(byAdding: .day, value: 2, to: today) {
                let d = calendar.startOfDay(for: day2)
                if calendar.isDate(d, equalTo: monthStart, toGranularity: .month) {
                    data[d] = CalendarDayData(
                        date: d,
                        bills: [
                            BillDisplay(occurrence: BillOccurrence(bill: sampleBill, dueDate: d), status: .upcoming),
                            BillDisplay(occurrence: BillOccurrence(bill: rentBill, dueDate: d), status: .upcoming),
                            BillDisplay(occurrence: BillOccurrence(bill: phoneBill, dueDate: d), status: .upcoming)
                        ]
                    )
                }
            }

            // Day with income + bill (income dot + bill dot)
            if let day7 = calendar.date(byAdding: .day, value: 7, to: today) {
                let d = calendar.startOfDay(for: day7)
                if calendar.isDate(d, equalTo: monthStart, toGranularity: .month) {
                    data[d] = CalendarDayData(
                        date: d,
                        bills: [
                            BillDisplay(occurrence: BillOccurrence(bill: streamingBill, dueDate: d), status: .upcoming)
                        ],
                        incomeOccurrences: [IncomeOccurrence(from: salary, on: d)]
                    )
                }
            }

            // Day with 2 incomes
            if let day15 = calendar.date(byAdding: .day, value: 15, to: today) {
                let d = calendar.startOfDay(for: day15)
                if calendar.isDate(d, equalTo: monthStart, toGranularity: .month) {
                    data[d] = CalendarDayData(
                        date: d,
                        incomeOccurrences: [
                            IncomeOccurrence(from: salary, on: d),
                            IncomeOccurrence(from: freelance, on: d)
                        ]
                    )
                }
            }

            // Day far out with single gray-urgency bill
            if let day25 = calendar.date(byAdding: .day, value: 25, to: today) {
                let d = calendar.startOfDay(for: day25)
                if calendar.isDate(d, equalTo: monthStart, toGranularity: .month) {
                    data[d] = CalendarDayData(
                        date: d,
                        bills: [
                            BillDisplay(occurrence: BillOccurrence(bill: rentBill, dueDate: d), status: .upcoming)
                        ]
                    )
                }
            }

            // Single-bill days at various offsets
            for dayOffset in [3, 8, 12, -2, -8, -12] {
                if let date = calendar.date(byAdding: .day, value: dayOffset, to: today) {
                    let dateStart = calendar.startOfDay(for: date)
                    guard calendar.isDate(dateStart, equalTo: monthStart, toGranularity: .month),
                          data[dateStart] == nil else { continue }
                    let occurrence = BillOccurrence(bill: sampleBill, dueDate: dateStart)
                    data[dateStart] = CalendarDayData(
                        date: dateStart,
                        bills: [BillDisplay(occurrence: occurrence, status: .upcoming)]
                    )
                }
            }

            return data
        }

        var body: some View {
            CalendarPagedGridView(
                months: months,
                pageIndex: $pageIndex,
                calendar: calendar,
                today: today,
                selectedDate: selectedDate,
                monthDataProvider: sampleMonthData,
                onSelectDay: { dayData in
                    selectedDate = dayData.date
                },
                onMonthChange: { _ in }
            )
        }
    }

    return PreviewWrapper()
}
