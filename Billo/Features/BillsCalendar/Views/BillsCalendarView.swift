//  Created by Jiri Urbasek on 12/05/25.

import StoreKit
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
    @Environment(ReviewPromptModel.self) private var reviewPrompts
    @Environment(\.requestReview) private var requestReview
    @Query(sort: \CustomCategory.name) private var customCategories: [CustomCategory]
    // Fetch all payments directly so orphaned entries (bill deleted → IssuedOccurrence nullified)
    // still surface in past months. Going through `bills.flatMap(\.allPaymentEntries)` misses them.
    @Query(sort: \PaymentEntry.datePaid) private var allStoredPayments: [PaymentEntry]

    private var currencyCode: String {
        appSettings.currencyCode ?? AppSettingsModel.defaultCurrency ?? "USD"
    }

    @State private var displayedMonth: DateComponents
    @State private var selectedDayData: CalendarDayData?
    @State private var scrollRequest: CalendarListScrollRequest?
    @State private var nextScrollRequestID = 0
    @State private var listShowsCurrentMonth = true
    @State private var sections: [CalendarMonthSection] = []
    @State private var months: [DateComponents] = []
    @State private var pageIndex: Int = 0
    @State private var hasInitialScroll = false
    /// Per-month grid data, built once in `rebuildLocalState()`. The paged
    /// `TabView` instantiates every month page on each body evaluation
    /// (page-style `TabView` is not lazy), so the `monthDataProvider` closure
    /// must be an O(1) lookup — recomputing `CalendarMonthGridBuilder.build`
    /// per page scans every occurrence and payment for each of the ~36+
    /// months on every swipe or day selection.
    @State private var gridDataByMonth: [DateComponents: CalendarMonthGridData] = [:]

    private var allPayments: [PaymentEntry] { allStoredPayments }
    @State private var referenceDate: Date = Date()

    /// Everything the calendar renders or routes from one payment. Equatable
    /// value snapshot (not a hash) so change detection is exact.
    private struct PaymentChangeKey: Equatable {
        let id: PersistentIdentifier
        let amount: Decimal
        let datePaid: Date
        let occurrenceDate: Date
        let snapshotName: String?
        let snapshotCurrencyCode: String?
        let snapshotCategoryRawValue: String?
        let billID: PersistentIdentifier?
    }

    /// Change detector over the payment fields the calendar renders. The
    /// query re-runs on any context save, so this is recomputed per body
    /// evaluation — O(payments) value copies, negligible next to a rebuild.
    private var paymentsChangeSnapshot: [PaymentChangeKey] {
        allStoredPayments.map { payment in
            PaymentChangeKey(
                id: payment.persistentModelID,
                amount: payment.amount,
                datePaid: payment.datePaid,
                occurrenceDate: payment.occurrenceDate,
                snapshotName: payment.snapshotName,
                snapshotCurrencyCode: payment.snapshotCurrencyCode,
                snapshotCategoryRawValue: payment.snapshotCategoryIdentifier?.rawValue,
                billID: payment.bill?.persistentModelID
            )
        }
    }

    /// Payments state the last `rebuildLocalState()` ran against. Lets the
    /// payments observer skip when a `BillsModel` mutation path (which calls
    /// `refresh()` itself, e.g. `markPaid`) already rebuilt with this exact
    /// state — otherwise every local payment change would refresh and rebuild
    /// twice (once via `refreshGeneration`, once via the query observer).
    @State private var lastRebuiltPayments: [PaymentChangeKey]?

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
                },
                onSkipIncome: {
                    // `BillsModel.skipIncomeOccurrence` already refreshed the
                    // model, which bumps `refreshGeneration` — the observer
                    // below rebuilds local state; nothing to do here.
                }
            )
            .analyticsScreen(.billsCalendar)
            .task {
                await refreshData()
            }
            // Single rebuild pipeline: every model mutation ends in
            // `BillsModel.refresh()`, which bumps the generation. Observing it
            // (instead of the bills/incomes arrays) also catches in-place
            // edits that keep array identity, e.g. changing a bill's amount.
            .onChange(of: billsModel.refreshGeneration) { _, _ in
                rebuildLocalState()
            }
            // Payments can also change without a model refresh (CloudKit sync
            // delivering remote inserts/deletes/field updates — including
            // same-count batches, which a `.count` trigger would miss). Local
            // mutations go through `BillsModel` and already rebuilt via the
            // generation observer above, so skip those (the rebuild recorded
            // the payments state it ran against).
            .onChange(of: paymentsChangeSnapshot) { _, newValue in
                guard newValue != lastRebuiltPayments else { return }
                Task { await refreshData() }
            }
            .onChange(of: displayedMonth) { _, _ in
                enqueueScroll(to: sectionId(for: displayedMonth))
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
                        enqueueScroll(to: sectionId(for: newMonth))
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
                                .onAppear {
                                    guard section.id == currentMonthSectionId else { return }
                                    listShowsCurrentMonth = true
                                    updateIsAtCurrentMonth()
                                }
                                .onDisappear {
                                    guard section.id == currentMonthSectionId else { return }
                                    listShowsCurrentMonth = false
                                    updateIsAtCurrentMonth()
                                }
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollIndicators(.visible)
                    // One container-level replay mask for the whole list.
                    // Per-row masks each injected PostHog tag UIViews whose
                    // setup re-walks the view hierarchy — profiled as the
                    // dominant cost of calendar scrolling hangs. The rows and
                    // section headers inside rely on this mask.
                    .replayMaskSensitive()
                    .onChange(of: scrollRequest) { _, request in
                        guard let request else { return }
                        withAnimation(.easeInOut) {
                            proxy.scrollTo(request.sectionID, anchor: .top)
                        }
                        // Clear to avoid unintended re-scroll on unrelated state changes
                        scrollRequest = nil
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
            enqueueScroll(to: sectionId(for: todayMonth))
        }
    }

    private var currentMonthSectionId: String {
        sectionId(for: calendar.dateComponents([.year, .month], from: referenceDate))
    }

    private func updateIsAtCurrentMonth() {
        let calendarIsShowingCurrentMonth = CalendarMonthComparison.isSameMonth(
            displayedMonth,
            as: referenceDate,
            calendar: calendar
        )
        isAtCurrentMonth = calendarIsShowingCurrentMonth && listShowsCurrentMonth
    }

    private func enqueueScroll(to sectionID: String) {
        nextScrollRequestID += 1
        scrollRequest = CalendarListScrollRequest(
            id: nextScrollRequestID,
            sectionID: sectionID
        )
    }

    /// Full refresh: `BillsModel.refresh()` bumps `refreshGeneration`, whose
    /// observer in `body` performs the local rebuild — no direct rebuild call
    /// on the success path, or every refresh would rebuild twice.
    @MainActor
    private func refreshData() async {
        do {
            try billsModel.refresh()
        } catch {
            Logger.log("Failed to refresh bills: \(error)", level: .error)
            // The generation didn't bump; rebuild from whatever state the
            // model holds so the calendar still renders something.
            rebuildLocalState()
        }
    }

    /// Rebuild-only path: assumes `BillsModel` is already up to date and just
    /// reads from it to refresh the calendar's local @State. Driven by the
    /// `refreshGeneration` observer in `body`.
    @MainActor
    private func rebuildLocalState() {
        referenceDate = Date()
        lastRebuiltPayments = paymentsChangeSnapshot

        let payments = allPayments
        let earliest = CalendarNavigationBounds.earliestMonth(
            bills: billsModel.bills,
            payments: payments,
            incomes: billsModel.incomes,
            incomeOccurrences: billsModel.incomeOccurrences,
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

        let incomeOccurrences = incomeOccurrenceItems(
            from: earliest,
            to: latest
        )

        var gridData: [DateComponents: CalendarMonthGridData] = [:]
        gridData.reserveCapacity(months.count)
        for month in months {
            gridData[month] = CalendarMonthGridBuilder.build(
                month: month,
                calendar: calendar,
                occurrences: occurrences,
                payments: payments,
                incomeOccurrences: incomeOccurrences,
                referenceDate: referenceDate
            )
        }
        gridDataByMonth = gridData

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
            enqueueScroll(to: sectionId(for: displayedMonth))
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

    private func incomeOccurrenceItems(
        from start: DateComponents,
        to end: DateComponents
    ) -> [IncomeOccurrenceItem] {
        guard let startDate = calendar.date(from: start),
              let endMonthStart = calendar.date(from: end),
              let endMonthInterval = calendar.dateInterval(of: .month, for: endMonthStart) else {
            return []
        }

        let endDate = endMonthInterval.end // exclusive upper bound (first instant of next month)
        // Pass the calendar's captured `referenceDate` so the past/future
        // boundary inside the model agrees with the one used elsewhere in this
        // refresh pipeline. Otherwise the model would re-read the wall clock.
        return billsModel.incomeOccurrenceItems(
            rangeStart: startDate,
            rangeEnd: endDate,
            referenceDate: referenceDate
        )
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

    /// Returns whether the payment was actually recorded so the day sheet can
    /// dismiss only on success.
    private func markPaid(_ occurrence: BillOccurrence) async -> Bool {
        do {
            try await billsModel.markPaid(occurrence, source: .calendar)
            if reviewPrompts.notePaymentRecorded(isCaughtUp: billsModel.isCaughtUp) {
                // Unstructured on purpose: the caller (day sheet) awaits this
                // method and then dismisses — the settle delay must neither
                // hold up that dismissal nor die with the sheet's task.
                Task {
                    await requestReview.requestAfterSettleDelay()
                }
            }
            return true
        } catch {
            Logger.log("Failed to mark paid: \(error)", level: .error)
            return false
        }
    }

    private func gridData(for month: DateComponents) -> CalendarMonthGridData {
        gridDataByMonth[month] ?? [:]
    }
}

// MARK: - Month Section Header

/// Displays the month title with income/bills breakdown on the right side
/// Format: "Dec 2024  <----->  +$4,200 / -$2,800 | Remaining: $1,400"
private struct MonthSectionHeader: View {
    let section: CalendarMonthSection
    let currencyCode: String

    private var remainingColor: Color {
        section.netRemaining >= 0 ? DesignSystem.Color.greenIncome : DesignSystem.Color.red
    }

    private var showBreakdown: Bool {
        section.totalIncome > 0 || section.totalBillsDue > 0 || section.totalPaid > 0
    }

    var body: some View {
        HStack(alignment: .top) {
                Text(section.title)
                    .font(.headline)

                if showBreakdown {
                    Spacer()

                    // Masked by the calendar list's container-level
                    // `.replayMaskSensitive()` in `BillsCalendarView.content`.
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
            .foregroundStyle(DesignSystem.Color.greenIncome)

            if section.isPast {
                if section.totalPaid > 0 {
                    Text("/")
                        .foregroundStyle(.secondary)

                    // Paid expenses: -$amount in paid-green (actual payments made in the month)
                    HStack(spacing: 0) {
                        Text("-")
                        Text(section.totalPaid, format: .currency(code: currencyCode))
                    }
                    .foregroundStyle(DesignSystem.Color.green)
                }

                if section.totalBillsDue > 0 {
                    Text("/")
                        .foregroundStyle(.secondary)

                    // Outstanding unpaid: -$amount in red (bills due in the month not yet paid)
                    HStack(spacing: 0) {
                        Text("-")
                        Text(section.totalBillsDue, format: .currency(code: currencyCode))
                    }
                    .foregroundStyle(DesignSystem.Color.red)
                }
            } else {
                Text("/")
                    .foregroundStyle(.secondary)

                // Bills due: -$amount in red (outstanding for current/future months)
                HStack(spacing: 0) {
                    Text("-")
                    Text(section.totalBillsDue, format: .currency(code: currencyCode))
                }
                .foregroundStyle(DesignSystem.Color.red)
            }
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
    let onMarkPaid: (BillOccurrence) async -> Bool
    let onSkipIncome: () async -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    var appModels = AppEnvironmentModels()

    func body(content: Content) -> some View {
#if os(iOS)
        content
            .sheet(item: $dayData) { dayData in
                DayDetailSheet(
                    dayData: dayData,
                    onMarkPaid: onMarkPaid,
                    onSkipIncome: onSkipIncome
                )
                .appEnvironment(appModels)
            }
#else
        content
            .popover(item: $dayData) { dayData in
                DayDetailSheet(
                    dayData: dayData,
                    onMarkPaid: onMarkPaid,
                    onSkipIncome: onSkipIncome
                )
                .appEnvironment(appModels)
            }
#endif
    }
}

private extension View {
    func dayDetailPresentation(
        dayData: Binding<CalendarDayData?>,
        onMarkPaid: @escaping (BillOccurrence) async -> Bool,
        onSkipIncome: @escaping () async -> Void
    ) -> some View {
        modifier(DayDetailPresentationModifier(
            dayData: dayData,
            onMarkPaid: onMarkPaid,
            onSkipIncome: onSkipIncome
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

#Preview("Historical Data") {
    let preview = BilloPreviewContainer.withHistoricalSampleData()

    return NavigationStack {
        BillsCalendarView()
            .navigationBarTitleDisplayMode(.inline)
    }
    .billoPreviewEnvironment(preview)
}

private struct CalendarListScrollRequest: Equatable, Identifiable {
    let id: Int
    let sectionID: String
}

#Preview("Empty State") {
    let preview = BilloPreviewContainer.empty()

    return NavigationStack {
        BillsCalendarView()
            .navigationBarTitleDisplayMode(.inline)
    }
    .billoPreviewEnvironment(preview)
}
