//  Created by Jiri Urbasek on 12/05/25.

import SwiftData
import SwiftUI

struct BillsCalendarView: View {
    private let calendar: Calendar
    private let usesStackNavigation: Bool
    private let onAddBill: () -> Void
    private let onOpen: (HomeDetailDestination) -> Void

    @Binding private var isAtCurrentMonth: Bool
    @Binding private var scrollToTodayToken: Int

    @Environment(BillsModel.self) private var billsModel
    @Environment(AppSettingsModel.self) private var appSettings
    @Query(sort: \CustomCategory.name) private var customCategories: [CustomCategory]

    private var currencyCode: String {
        appSettings.currencyCode ?? AppSettingsModel.defaultCurrency ?? "USD"
    }

    @State private var displayedMonth: DateComponents
    @State private var selectedDayData: CalendarDayData?
    @State private var scrollTarget: String?
    @State private var sections: [CalendarMonthSection] = []
    @State private var months: [DateComponents] = []
    @State private var pageIndex: Int = 0
    @State private var hasInitialScroll = false
    @State private var allOccurrences: [BillOccurrence] = []
    @State private var allPayments: [PaymentEntry] = []
    @State private var allIncomeOccurrences: [IncomeOccurrence] = []
    @State private var referenceDate: Date = Date()

	    init(
	        calendar: Calendar = .autoupdatingCurrent,
            usesStackNavigation: Bool = true,
	        onAddBill: @escaping () -> Void = {},
	        onOpen: @escaping (HomeDetailDestination) -> Void = { _ in },
	        isAtCurrentMonth: Binding<Bool> = .constant(true),
	        scrollToTodayToken: Binding<Int> = .constant(0)
	    ) {
        self.calendar = calendar
        self.usesStackNavigation = usesStackNavigation
        self.onAddBill = onAddBill
        self.onOpen = onOpen
        _isAtCurrentMonth = isAtCurrentMonth
        _scrollToTodayToken = scrollToTodayToken
        _displayedMonth = State(initialValue: calendar.dateComponents([.year, .month], from: Date()))
    }

    var body: some View {
        content
            .navigationTitle(navigationTitle)
            .dayDetailPresentation(
                dayData: $selectedDayData,
                onMarkPaid: { occurrence in
                    await markPaid(occurrence)
                }
            )
            .task {
                await refreshData()
            }
            .onChange(of: billsModel.bills) { _, _ in
                Task { await refreshData() }
            }
            .onChange(of: billsModel.incomes) { _, _ in
                Task { await refreshData() }
            }
            .onChange(of: displayedMonth) { _, _ in
                scrollTarget = sectionId(for: displayedMonth)
                updateIsAtCurrentMonth()
            }
            .onChange(of: scrollToTodayToken) { _, _ in
                scrollToToday()
            }
    }

    private var navigationTitle: String {
        if usesStackNavigation {
            return monthTitle(for: displayedMonth)
        }

        return String(localized: "Calendar")
    }

    @ViewBuilder
    private var content: some View {
        if billsModel.bills.isEmpty && billsModel.incomes.isEmpty {
            BillsEmptyStateView(
                onAddBill: { onAddBill() },
                descriptionText: "Add your first bill to see it in the calendar"
            )
        } else {
            VStack(spacing: 0) {
                // Calendar section with white background, rounded bottom corners, and shadow
                CalendarPagedGridView(
                    months: months,
                    pageIndex: $pageIndex,
                    calendar: calendar,
                    today: referenceDate,
                    selectedDate: selectedDayData?.date,
                    monthDataProvider: { month in
                        gridData(for: month)
                    },
                    onSelectDay: { dayData in
                        selectedDayData = dayData
                    },
                    onMonthChange: { newMonth in
                        displayedMonth = newMonth
                        scrollTarget = sectionId(for: newMonth)
                        updateIsAtCurrentMonth()
                    }
                )
                .padding(.bottom, DesignSystem.Spacing.small)
                .background(
                    DesignSystem.Color.background
                        .clipShape(
                            UnevenRoundedRectangle(
                                bottomLeadingRadius: DesignSystem.CornerRadius.extraLarge,
                                bottomTrailingRadius: DesignSystem.CornerRadius.extraLarge
                            )
                        )
                )


                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                            ForEach(sections) { section in
                                Section {
                                    ForEach(section.items) { item in
                                        CalendarItemRow(
                                            usesStackNavigation: usesStackNavigation,
                                            item: item,
                                            customCategories: customCategories,
                                            onOpen: onOpen
                                        )
                                        .scrollTargetLayout()
                                    }
                                } header: {
                                    MonthSectionHeader(
                                        section: section,
                                        currencyCode: currencyCode
                                    )
                                }
                                .id(section.id)
                                .scrollTargetLayout()
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollIndicators(.visible)
                    .onChange(of: scrollTarget) { _, target in
                        guard let target else { return }
                        withAnimation(.easeInOut) {
                            proxy.scrollTo(target, anchor: .top)
                        }
                        // Clear to avoid unintended re-scroll on unrelated state changes
                        scrollTarget = nil
                    }
                }
            }
            .background(DesignSystem.Color.groupedBackground)
            .toolbarBackground(DesignSystem.Color.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private func scrollToToday() {
        let todayMonth = calendar.dateComponents([.year, .month], from: referenceDate)
        guard let index = monthIndex(for: todayMonth) else { return }

        withAnimation(.easeInOut) {
            pageIndex = index
            displayedMonth = todayMonth
            scrollTarget = sectionId(for: todayMonth)
        }
    }

    private func updateIsAtCurrentMonth() {
        isAtCurrentMonth = CalendarMonthComparison.isSameMonth(
            displayedMonth,
            as: referenceDate,
            calendar: calendar
        )
    }

    @MainActor
    private func refreshData() async {
        referenceDate = Date()

        do {
            try billsModel.refresh()
        } catch {
            Logger.log("Failed to refresh bills: \(error)", level: .error)
        }

        let payments = billsModel.bills.flatMap(\.allPaymentEntries)
        let earliest = CalendarNavigationBounds.earliestMonth(
            bills: billsModel.bills,
            payments: payments,
            incomes: billsModel.incomes,
            calendar: calendar,
            currentDate: referenceDate
        )
        let latest = CalendarNavigationBounds.latestMonth(
            from: referenceDate,
            calendar: calendar
        )
        months = monthSequence(from: earliest, to: latest)
        displayedMonth = clamped(displayedMonth, min: earliest, max: latest)
        pageIndex = monthIndex(for: displayedMonth) ?? 0

        let occurrences = buildOccurrences(
            bills: billsModel.bills,
            from: earliest,
            to: latest
        )

        let incomeOccurrences = buildIncomeOccurrences(
            incomes: billsModel.incomes,
            from: earliest,
            to: latest
        )

        allOccurrences = occurrences
        allPayments = payments
        allIncomeOccurrences = incomeOccurrences

        sections = CalendarSectionsBuilder.build(
            occurrences: occurrences,
            payments: payments,
            incomeOccurrences: incomeOccurrences,
            from: earliest,
            to: latest,
            referenceDate: referenceDate,
            calendar: calendar
        )

        if !hasInitialScroll {
            scrollTarget = sectionId(for: displayedMonth)
            hasInitialScroll = true
        }

        updateIsAtCurrentMonth()
    }

    private func buildOccurrences(
        bills: [Bill],
        from start: DateComponents,
        to end: DateComponents
    ) -> [BillOccurrence] {
        guard let startDate = calendar.date(from: start),
              let endMonthStart = calendar.date(from: end),
              let endMonthInterval = calendar.dateInterval(of: .month, for: endMonthStart) else {
            return []
        }

        let endDate = endMonthInterval.end // exclusive upper bound (first instant of next month)
        var occurrences: [BillOccurrence] = []

        for bill in bills {
            let generatedDates = bill.generateOccurrences(
                from: startDate,
                until: endDate,
                calendar: calendar
            )

            let filtered = generatedDates.filter { $0 >= startDate && $0 < endDate }
            occurrences.append(contentsOf: filtered.map { BillOccurrence(bill: bill, dueDate: $0, calendar: calendar) })
        }

        return occurrences.sorted { $0.dueDate < $1.dueDate }
    }

    private func buildIncomeOccurrences(
        incomes: [Income],
        from start: DateComponents,
        to end: DateComponents
    ) -> [IncomeOccurrence] {
        guard let startDate = calendar.date(from: start),
              let endMonthStart = calendar.date(from: end),
              let endMonthInterval = calendar.dateInterval(of: .month, for: endMonthStart) else {
            return []
        }

        let endDate = endMonthInterval.end // exclusive upper bound (first instant of next month)
        return IncomeOccurrence.generateOccurrences(
            from: incomes,
            rangeStart: startDate,
            rangeEnd: endDate,
            calendar: calendar
        ).sorted { $0.date < $1.date }
    }

    private func monthTitle(for components: DateComponents) -> String {
        guard let date = calendar.date(from: components) else { return "" }
        return date.formatted(.dateTime.month(.wide).year())
    }

    private func sectionId(for components: DateComponents) -> String {
        String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }

    private func clamped(
        _ components: DateComponents,
        min minComponents: DateComponents,
        max maxComponents: DateComponents
    ) -> DateComponents {
        if isBefore(components, minComponents) { return minComponents }
        if isAfter(components, maxComponents) { return maxComponents }
        return components
    }

    private func isAfter(_ lhs: DateComponents, _ rhs: DateComponents) -> Bool {
        guard let lhsDate = calendar.date(from: lhs), let rhsDate = calendar.date(from: rhs) else {
            return false
        }
        return lhsDate > rhsDate
    }

    private func isBefore(_ lhs: DateComponents, _ rhs: DateComponents) -> Bool {
        guard let lhsDate = calendar.date(from: lhs), let rhsDate = calendar.date(from: rhs) else {
            return false
        }
        return lhsDate < rhsDate
    }

    private func monthSequence(from start: DateComponents, to end: DateComponents) -> [DateComponents] {
        guard let startDate = calendar.date(from: start),
              let endDate = calendar.date(from: end) else { return [] }

        var months: [DateComponents] = []
        var current = startDate
        while current <= endDate {
            months.append(calendar.dateComponents([.year, .month], from: current))
            guard let next = calendar.date(byAdding: .month, value: 1, to: current) else { break }
            current = next
        }
        return months
    }

    private func monthIndex(for components: DateComponents) -> Int? {
        months.firstIndex(where: { month in
            guard let lhs = calendar.date(from: month), let rhs = calendar.date(from: components) else { return false }
            return calendar.isDate(lhs, equalTo: rhs, toGranularity: .month)
        })
    }

    private func markPaid(_ occurrence: BillOccurrence) async {
        do {
            try await billsModel.markPaid(occurrence)
        } catch {
            Logger.log("Failed to mark paid: \(error)", level: .error)
        }
    }

    private func gridData(for month: DateComponents) -> CalendarMonthGridData {
        return CalendarMonthGridBuilder.build(
            month: month,
            calendar: calendar,
            occurrences: allOccurrences,
            payments: allPayments,
            incomeOccurrences: allIncomeOccurrences,
            referenceDate: referenceDate
        )
    }
}

// MARK: - Month Section Header

/// Displays the month title with income/bills breakdown on the right side
/// Format: "Dec 2024  <----->  +$4,200 / -$2,800 | Remaining: $1,400"
private struct MonthSectionHeader: View {
    let section: CalendarMonthSection
    let currencyCode: String

    private var remainingColor: Color {
        section.netRemaining >= 0 ? DesignSystem.Color.green : DesignSystem.Color.red
    }

    private var showBreakdown: Bool {
        section.totalIncome > 0 || section.totalBillsDue > 0
    }

    var body: some View {
        HStack(alignment: .top) {
                Text(section.title)
                    .font(.headline)

                if showBreakdown {
                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        breakdownView
                        remainingLabel
                    }
                }
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .padding(.top, DesignSystem.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Color.groupedBackground)
    }

    @ViewBuilder
    private var breakdownView: some View {
        HStack(spacing: 4) {
            // Income: +$amount in green
            HStack(spacing: 0) {
                Text("+")
                Text(section.totalIncome, format: .currency(code: currencyCode))
            }
            .foregroundStyle(DesignSystem.Color.green)

            Text("/")
                .foregroundStyle(.secondary)

            // Bills: -$amount in red
            HStack(spacing: 0) {
                Text("-")
                Text(section.totalBillsDue, format: .currency(code: currencyCode))
            }
            .foregroundStyle(DesignSystem.Color.red)
        }
        .font(.caption)
    }

    @ViewBuilder
    private var remainingLabel: some View {
        HStack(spacing: 4) {
            Text("Remaining:")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(section.netRemaining, format: .currency(code: currencyCode))
                .foregroundStyle(remainingColor)
        }
        .font(.caption)
    }
}

// MARK: - Day Detail Presentation Modifier

private struct DayDetailPresentationModifier: ViewModifier {
    @Binding var dayData: CalendarDayData?
    let onMarkPaid: (BillOccurrence) async -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
#if os(iOS)
        content
            .sheet(item: $dayData) { dayData in
                DayDetailSheet(
                    dayData: dayData,
                    onMarkPaid: onMarkPaid
                )
            }
#else
        content
            .popover(item: $dayData) { dayData in
                DayDetailSheet(
                    dayData: dayData,
                    onMarkPaid: onMarkPaid
                )
            }
#endif
    }
}

private extension View {
    func dayDetailPresentation(
        dayData: Binding<CalendarDayData?>,
        onMarkPaid: @escaping (BillOccurrence) async -> Void
    ) -> some View {
        modifier(DayDetailPresentationModifier(
            dayData: dayData,
            onMarkPaid: onMarkPaid
        ))
    }
}

// MARK: - Previews

#Preview("Sample Data") {
    let preview = BilloPreviewContainer.withSampleData()

    return NavigationStack {
        BillsCalendarView()
            .navigationBarTitleDisplayMode(.inline)
    }
    .billoPreviewEnvironment(preview)
}

#Preview("Empty State") {
    let preview = BilloPreviewContainer.empty()

    return NavigationStack {
        BillsCalendarView()
            .navigationBarTitleDisplayMode(.inline)
    }
    .billoPreviewEnvironment(preview)
}
