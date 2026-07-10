//  Created by Jiri Urbasek on 11/27/25.

import Testing
import Foundation
@testable import Billo

@MainActor
@Suite("CategoryCatalog")
struct CategoryCatalogTests {

    @Test
    func whenRequestingAvailableCategories_thenAllFifteenDefaultsAppearBeforeCustoms() {
        let custom = makeCustomCategory(id: "custom-1", name: "Gym")

        let available = CategoryCatalog.availableCategories(customCategories: [custom])

        #expect(DefaultCategoryIdentifier.allCases.count == 15)
        #expect(available.count == DefaultCategoryIdentifier.allCases.count + 1)
        #expect(available.first?.id == .predefined(.utilities))
        #expect(available.last?.id == .custom("custom-1"))
    }

    @Test
    func whenCustomCategoryArchived_thenExcludedFromDefaultPickerResults() {
        let archived = makeCustomCategory(id: "archived", name: "Old", isArchived: true)

        let available = CategoryCatalog.availableCategories(customCategories: [archived])

        #expect(available.allSatisfy { $0.id.isDefault })
    }

    @Test
    func whenLookingUpDefaultIdentifier_thenReturnsLiteralSymbolAndHex() {
        let info = CategoryCatalog.displayInfo(for: .predefined(.housing), customCategories: [])

        #expect(info?.name == "Housing")
        #expect(info?.systemImageName == "house.fill")
        #expect(info?.colorHex == "#34C759")
        #expect(info?.isCustom == false)
    }

    @Test
    func whenLookingUpCustomIdentifier_thenReturnsItsSymbolAndHex() {
        let custom = makeCustomCategory(
            id: "custom-2",
            name: "Pets",
            iconToken: "pawprint.fill",
            colorHex: "#00C7BE"
        )

        let info = CategoryCatalog.displayInfo(for: .custom("custom-2"), customCategories: [custom])

        #expect(info?.name == "Pets")
        #expect(info?.systemImageName == "pawprint.fill")
        #expect(info?.colorHex == "#00C7BE")
        #expect(info?.isCustom == true)
    }

    @Test
    func whenCustomCategoryHasInvalidSymbolName_thenFallsBackToDefaultGlyph() {
        let corrupt = makeCustomCategory(id: "corrupt", iconToken: "not.a.real.symbol.name")

        let info = CategoryCatalog.displayInfo(for: .custom("corrupt"), customCategories: [corrupt])

        #expect(info?.systemImageName == CategoryIcon.defaultSymbol)
    }

    @Test
    func whenCustomCategoriesPassedUnsorted_thenAvailableCategoriesOrderThemByName() {
        let zebra = makeCustomCategory(id: "z", name: "Zebra")
        let alpha = makeCustomCategory(id: "a", name: "Alpha")

        let available = CategoryCatalog.availableCategories(customCategories: [zebra, alpha])

        let customIDs = available.filter(\.isCustom).map(\.id)
        #expect(customIDs == [.custom("a"), .custom("z")])
    }

    // MARK: - Usage Counts

    @Suite("usageCounts")
    @MainActor
    struct UsageCounts {
        @Test
        func whenBillsAssignedToCategories_thenCountsMatchPerCategory() {
            let bills = [
                makeBill(category: .predefined(.utilities)),
                makeBill(category: .predefined(.utilities)),
                makeBill(category: .custom("custom-1"))
            ]

            let counts = CategoryCatalog.usageCounts(bills: bills)

            #expect(counts == [
                .predefined(.utilities): 2,
                .custom("custom-1"): 1
            ])
        }

        @Test
        func whenBillHasNoCategory_thenItCountsNowhere() {
            let counts = CategoryCatalog.usageCounts(bills: [makeBill(category: nil)])

            #expect(counts.isEmpty)
        }
    }

    // MARK: - Quick Pick

    @Suite("quickPickCategories")
    @MainActor
    struct QuickPick {
        @Test
        func whenNoBillsExist_thenQuickPickReturnsFirstEightPredefinedInCatalogOrder() {
            let picks = CategoryCatalog.quickPickCategories(
                customCategories: [],
                usageCounts: [:],
                selected: nil
            )

            let expectedOrder = Array(DefaultCategoryIdentifier.allCases.prefix(8))
                .map { CategoryIdentifier.predefined($0) }
            #expect(picks.map(\.id) == expectedOrder)
        }

        @Test
        func whenSomeCategoriesUsed_thenUsedCategoriesRankAheadOfUnused() {
            let picks = CategoryCatalog.quickPickCategories(
                customCategories: [],
                usageCounts: [
                    .predefined(.pets): 3,
                    .predefined(.taxesFees): 1
                ],
                selected: nil
            )

            #expect(picks.first?.id == .predefined(.pets))
            #expect(picks[1].id == .predefined(.taxesFees))
        }

        @Test
        func whenUsageTied_thenCatalogSortOrderBreaksTie() {
            let picks = CategoryCatalog.quickPickCategories(
                customCategories: [],
                usageCounts: [
                    .predefined(.other): 2,
                    .predefined(.housing): 2
                ],
                selected: nil
            )

            // housing (sortOrder 2) outranks other (sortOrder 14) on equal usage
            #expect(Array(picks.map(\.id).prefix(2)) == [.predefined(.housing), .predefined(.other)])
        }

        @Test
        func whenCustomCategoryMostUsed_thenCustomAppearsFirst() {
            let custom = makeCustomCategory(id: "custom-1", name: "Gym")

            let picks = CategoryCatalog.quickPickCategories(
                customCategories: [custom],
                usageCounts: [.custom("custom-1"): 5],
                selected: nil
            )

            #expect(picks.first?.id == .custom("custom-1"))
        }

        @Test
        func whenSelectedCategoryOutsideTopEight_thenSelectedReplacesLastSlot() {
            // No usage: top 8 are the first eight predefined. `other` (index 14)
            // is outside, but selected — it must take the last slot.
            let picks = CategoryCatalog.quickPickCategories(
                customCategories: [],
                usageCounts: [:],
                selected: .predefined(.other)
            )

            #expect(picks.count == 8)
            #expect(picks.last?.id == .predefined(.other))
            #expect(Array(picks.map(\.id).prefix(7)) == DefaultCategoryIdentifier.allCases.prefix(7).map { .predefined($0) })
        }

        @Test
        func whenArchivedCustomCategoryUnused_thenExcludedFromQuickPickUnlessSelected() {
            let archived = makeCustomCategory(id: "archived", name: "Old", isArchived: true)

            let unselected = CategoryCatalog.quickPickCategories(
                customCategories: [archived],
                usageCounts: [:],
                selected: nil
            )
            let selected = CategoryCatalog.quickPickCategories(
                customCategories: [archived],
                usageCounts: [:],
                selected: .custom("archived")
            )

            #expect(unselected.map(\.id).contains(.custom("archived")) == false)
            #expect(selected.last?.id == .custom("archived"))
        }

        @Test
        func whenSelectedOutranked_thenSelectedDisplacesLowestRankedUsedSlot() {
            // Nine categories used; `taxesFees` is the least used so it holds
            // slot 8 — until it is the selection elsewhere. Here `pets` (the
            // 9th by usage) is selected and must displace the last slot.
            var usage: [CategoryIdentifier: Int] = [
                .predefined(.utilities): 10,
                .predefined(.subscriptions): 9,
                .predefined(.housing): 8,
                .predefined(.insurance): 7,
                .predefined(.loans): 6,
                .predefined(.transportation): 5,
                .predefined(.phoneInternet): 4,
                .predefined(.taxesFees): 3
            ]
            usage[.predefined(.pets)] = 1

            let picks = CategoryCatalog.quickPickCategories(
                customCategories: [],
                usageCounts: usage,
                selected: .predefined(.pets)
            )

            #expect(picks.count == 8)
            #expect(picks.last?.id == .predefined(.pets))
            #expect(picks.map(\.id).contains(.predefined(.taxesFees)) == false)
            #expect(Set(picks.map(\.id)).count == picks.count)
        }

        @Test
        func whenDeletedCustomCategoryHasUsage_thenItNeverSurfacesInQuickPick() {
            let picks = CategoryCatalog.quickPickCategories(
                customCategories: [],
                usageCounts: [.custom("deleted-id"): 99],
                selected: nil
            )

            #expect(picks.map(\.id).contains(.custom("deleted-id")) == false)
            #expect(picks.count == 8)
        }

        @Test
        func whenSelectedCategoryDeleted_thenQuickPickStaysAtEightPredefined() {
            let picks = CategoryCatalog.quickPickCategories(
                customCategories: [],
                usageCounts: [:],
                selected: .custom("deleted-id")
            )

            #expect(picks.count == 8)
            #expect(picks.map(\.id).contains(.custom("deleted-id")) == false)
        }
    }
}

// MARK: - Factories

private func makeBill(category: CategoryIdentifier?) -> Bill {
    Bill(
        name: UUID().uuidString,
        amount: Decimal(Int.random(in: 50...500)),
        dueDate: Date(),
        categoryIdentifier: category
    )
}

private func makeCustomCategory(
    id: String = UUID().uuidString,
    name: String = UUID().uuidString,
    iconToken: String = "tag",
    colorHex: String = "#8E8E93",
    isArchived: Bool = false
) -> CustomCategory {
    CustomCategory(
        id: id,
        name: name,
        iconToken: iconToken,
        colorHex: colorHex,
        isArchived: isArchived
    )
}
