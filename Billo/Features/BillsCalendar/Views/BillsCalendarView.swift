//  Created by Jiri Urbasek on 12/05/25.

import SwiftData
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct BillsCalendarView: View {
    private let viewMode: Binding<BillsHomeViewMode>?
    private let calendar: Calendar

    @Environment(BillsModel.self) private var billsModel
    @Environment(NotificationCoordinator.self) private var notificationCoordinator
    @Environment(NotificationPreferencesStore.self) private var preferencesStore
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomCategory.name) private var customCategories: [CustomCategory]

    @State private var displayedMonth: DateComponents
    @State private var selectedDayData: CalendarDayData?
    @State private var scrollTarget: String?
    @State private var sections: [CalendarMonthSection] = []
    @State private var monthGridData: CalendarMonthGridData = [:]
    @State private var months: [DateComponents] = []
    @State private var pageIndex: Int = 0
    @State private var hasInitialScroll = false
    @State private var allOccurrences: [BillOccurrence] = []
    @State private var allPayments: [Payment] = []
    @State private var showingAddBill = false
    @State private var showingSettings = false

    init(
        viewMode: Binding<BillsHomeViewMode>? = nil,
        calendar: Calendar = .current
    ) {
        self.viewMode = viewMode
        self.calendar = calendar
        _displayedMonth = State(initialValue: calendar.dateComponents([.year, .month], from: Date()))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Bills")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: Bill.self) { bill in
                    BillDetailView(bill: bill)
                        .environment(BillModel(bill: bill, modelContext: modelContext))
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gear")
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingAddBill = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .toolbarTitleMenu {
                    if let viewMode {
                        Picker("Default view", selection: viewMode) {
                            ForEach(BillsHomeViewMode.allCases) { mode in
                                Label(mode.title, systemImage: mode.iconName).tag(mode)
                            }
                        }
                    }
                }
                .sheet(isPresented: $showingAddBill) {
                    BillEditView(mode: .adding)
                        .environment(billsModel)
                }
                .sheet(isPresented: $showingSettings) {
                    NavigationStack {
                        NotificationSettingsView()
                            .environment(
                                NotificationSettingsModel(
                                    preferences: preferencesStore,
                                    coordinator: notificationCoordinator,
                                    openSettingsHandler: {
#if os(iOS)
                                        if let url = URL(string: UIApplication.openSettingsURLString) {
                                            UIApplication.shared.open(url)
                                        }
#endif
                                    }
                                )
                            )
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Done") {
                                        showingSettings = false
                                    }
                                }
                            }
                    }
                }
                .dayDetailPresentation(
                    dayData: $selectedDayData,
                    calendar: calendar,
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
                .onChange(of: displayedMonth) { _, _ in
                    updateGridData()
                    scrollTarget = sectionId(for: displayedMonth)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if billsModel.bills.isEmpty {
            CalendarEmptyStateView {
                showingAddBill = true
            }
        } else {
            VStack(spacing: 0) {
                MonthHeaderView(
                    title: monthTitle(for: displayedMonth),
                    canGoBack: canNavigateBackward,
                    canGoForward: canNavigateForward,
                    onBack: { movePage(by: -1) },
                    onForward: { movePage(by: 1) }
                )

                CalendarPagedGridView(
                    months: months,
                    pageIndex: $pageIndex,
                    calendar: calendar,
                    today: Date(),
                    selectedDate: selectedDayData?.date,
                    monthDataProvider: { month in
                        gridData(for: month)
                    },
                    onSelectDay: { dayData in
                        selectedDayData = dayData
                    },
                    onMonthChange: { newMonth in
                        displayedMonth = newMonth
                        updateGridData()
                        scrollTarget = sectionId(for: newMonth)
                    }
                )
                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                            ForEach(sections) { section in
                                Section {
                                    ForEach(section.items) { item in
                                        CalendarItemRow(
                                            item: item,
                                            customCategories: customCategories
                                        )
                                        .scrollTargetLayout()
                                    }
                                } header: {
                                    Text(section.title)
                                        .font(.headline)
                                        .padding(.horizontal, DesignSystem.Spacing.medium)
                                        .padding(.vertical, DesignSystem.Spacing.small)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.systemGroupedBackground))
                                }
                                .id(section.id)
                                .scrollTargetLayout()
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollIndicators(.visible)
                    .background(Color(.systemGroupedBackground))
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
        }
    }

    private var canNavigateBackward: Bool {
        pageIndex > 0
    }

    private var canNavigateForward: Bool {
        pageIndex < months.count - 1
    }

    private func movePage(by delta: Int) {
        let target = pageIndex + delta
        guard months.indices.contains(target) else { return }
        pageIndex = target
        displayedMonth = months[target]
        updateGridData()
        scrollTarget = sectionId(for: displayedMonth)
    }

    @MainActor
    private func refreshData() async {
        do {
            try billsModel.refresh()
        } catch {
            print("Failed to refresh bills: \(error)")
        }

        let payments = billsModel.bills.flatMap(\.payments)
        let earliest = CalendarNavigationBounds.earliestMonth(
            bills: billsModel.bills,
            payments: payments,
            calendar: calendar,
            currentDate: Date()
        )
        let latest = CalendarNavigationBounds.latestMonth(
            from: Date(),
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

        allOccurrences = occurrences
        allPayments = payments

        sections = CalendarSectionsBuilder.build(
            occurrences: occurrences,
            payments: payments,
            from: earliest,
            to: latest,
            calendar: calendar
        )

        updateGridData()
        if !hasInitialScroll {
            scrollTarget = sectionId(for: displayedMonth)
            hasInitialScroll = true
        }
    }

    private func updateGridData() {
        monthGridData = gridData(for: displayedMonth)
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

        let endDate = endMonthInterval.end.addingTimeInterval(-1)
        var occurrences: [BillOccurrence] = []

        for bill in bills {
            let generatedDates = bill.generateOccurrences(
                from: startDate,
                until: endDate,
                calendar: calendar
            )

            let filtered = generatedDates.filter { $0 >= startDate && $0 <= endDate }
            occurrences.append(contentsOf: filtered.map { BillOccurrence(bill: bill, dueDate: $0) })
        }

        return occurrences.sorted { $0.dueDate < $1.dueDate }
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
            print("Failed to mark paid: \(error)")
        }
    }

    private func gridData(for month: DateComponents) -> CalendarMonthGridData {
        if let section = sections.first(where: { $0.id == sectionId(for: month) }) {
            var data: CalendarMonthGridData = [:]

            func appendOccurrence(_ occurrence: BillOccurrence) {
                let key = calendar.startOfDay(for: occurrence.dueDate)
                var day = data[key] ?? CalendarDayData(date: key, occurrences: [], payments: [])
                day = CalendarDayData(date: key, occurrences: day.occurrences + [occurrence], payments: day.payments)
                data[key] = day
            }

            func appendPayment(_ payment: Payment) {
                let key = calendar.startOfDay(for: payment.datePaid)
                var day = data[key] ?? CalendarDayData(date: key, occurrences: [], payments: [])
                day = CalendarDayData(date: key, occurrences: day.occurrences, payments: day.payments + [payment])
                data[key] = day
            }

            for item in section.items {
                switch item {
                case .occurrence(let occurrence):
                    appendOccurrence(occurrence)
                case .payment(let payment):
                    appendPayment(payment)
                case .emptyMonth:
                    break
                }
            }
            return data
        }

        return CalendarMonthGridBuilder.build(
            month: month,
            calendar: calendar,
            occurrences: allOccurrences,
            payments: allPayments
        )
    }
}

// MARK: - Day Detail Presentation Modifier

private struct DayDetailPresentationModifier: ViewModifier {
    @Binding var dayData: CalendarDayData?
    let calendar: Calendar
    let onMarkPaid: (BillOccurrence) async -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
#if os(iOS)
        if horizontalSizeClass == .regular {
            content
                .popover(item: $dayData) { dayData in
                    DayDetailSheet(
                        dayData: dayData,
                        calendar: calendar,
                        today: Date(),
                        onMarkPaid: onMarkPaid
                    )
                }
                .presentationCompactAdaptation(.sheet)
        } else {
            content
                .sheet(item: $dayData) { dayData in
                    DayDetailSheet(
                        dayData: dayData,
                        calendar: calendar,
                        today: Date(),
                        onMarkPaid: onMarkPaid
                    )
                }
        }
#else
        content
            .popover(item: $dayData) { dayData in
                DayDetailSheet(
                    dayData: dayData,
                    calendar: calendar,
                    today: Date(),
                    onMarkPaid: onMarkPaid
                )
            }
#endif
    }
}

private extension View {
    func dayDetailPresentation(
        dayData: Binding<CalendarDayData?>,
        calendar: Calendar,
        onMarkPaid: @escaping (BillOccurrence) async -> Void
    ) -> some View {
        modifier(DayDetailPresentationModifier(
            dayData: dayData,
            calendar: calendar,
            onMarkPaid: onMarkPaid
        ))
    }
}
