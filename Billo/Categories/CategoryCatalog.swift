//  Created by Jiri Urbasek on 11/27/25.

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CategoryDisplayInfo: Identifiable, Hashable, Sendable {
    let id: CategoryIdentifier
    let name: String
    /// Literal SF Symbol name, validated at construction — render with
    /// `Image(systemName:)` without further checks.
    let systemImageName: String
    /// "#RRGGBB" — render with `color`.
    let colorHex: String
    let isArchived: Bool
    let isCustom: Bool
    let sortOrder: Int

    var color: SwiftUI.Color { SwiftUI.Color(hex: colorHex) }

    /// Canonical category ordering used by the catalog, pickers, and charts:
    /// catalog `sortOrder`, then name, then id as the deterministic tie-break.
    static func displayOrder(_ lhs: CategoryDisplayInfo, _ rhs: CategoryDisplayInfo) -> Bool {
        if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
        let nameComparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        if nameComparison != .orderedSame { return nameComparison == .orderedAscending }
        return lhs.id.rawValue < rhs.id.rawValue
    }
}

enum CategoryCatalog {
    static func availableCategories(
        customCategories: [CustomCategory],
        includeArchived: Bool = false
    ) -> [CategoryDisplayInfo] {
        let customInfos = customCategories
            .filter { includeArchived || $0.isArchived == false }
            .map(displayInfo(for:))

        return (defaultDisplayInfos + customInfos)
            .sorted(by: CategoryDisplayInfo.displayOrder)
    }

    static func displayInfo(
        for identifier: CategoryIdentifier?,
        customCategories: [CustomCategory]
    ) -> CategoryDisplayInfo? {
        switch identifier {
        case nil:
            return nil
        case .predefined(let defaultIdentifier):
            return displayInfo(for: defaultIdentifier)
        case .custom(let id):
            guard let category = customCategories.first(where: { $0.id == id }) else { return nil }
            return displayInfo(for: category)
        }
    }

    /// Non-optional lookup for predefined categories — every case has a
    /// definition, so callers (previews, fallback paths) don't need to unwrap.
    static func displayInfo(for defaultIdentifier: DefaultCategoryIdentifier) -> CategoryDisplayInfo {
        CategoryDisplayInfo(
            id: .predefined(defaultIdentifier),
            name: defaultIdentifier.displayName,
            systemImageName: defaultIdentifier.systemImageName,
            colorHex: defaultIdentifier.colorHex,
            isArchived: false,
            isCustom: false,
            sortOrder: defaultIdentifier.sortOrder
        )
    }

    // MARK: - Usage Ranking

    /// Count of bills per assigned category. O(bills). Bills without a
    /// category count nowhere.
    static func usageCounts(bills: [Bill]) -> [CategoryIdentifier: Int] {
        var counts: [CategoryIdentifier: Int] = [:]
        for bill in bills {
            guard let identifier = bill.categoryIdentifier else { continue }
            counts[identifier, default: 0] += 1
        }
        return counts
    }

    /// The quick-pick options for the bill editor: top `limit` categories by
    /// usage (desc), tie-broken by the canonical display order. Slots beyond
    /// the used categories fill with predefined catalog order. `selected` is
    /// always included, replacing the last slot when it ranks outside the top
    /// `limit` (even when archived, so an existing bill's category never
    /// vanishes from the editor).
    static func quickPickCategories(
        customCategories: [CustomCategory],
        usageCounts: [CategoryIdentifier: Int],
        selected: CategoryIdentifier?,
        limit: Int = 8
    ) -> [CategoryDisplayInfo] {
        let ranked = availableCategories(customCategories: customCategories)
            .sorted { lhs, rhs in
                let lhsCount = usageCounts[lhs.id] ?? 0
                let rhsCount = usageCounts[rhs.id] ?? 0
                if lhsCount != rhsCount { return lhsCount > rhsCount }
                return CategoryDisplayInfo.displayOrder(lhs, rhs)
            }

        var picks = Array(ranked.prefix(limit))

        if let selected,
           picks.contains(where: { $0.id == selected }) == false,
           let selectedInfo = displayInfo(for: selected, customCategories: customCategories) {
            if picks.count >= limit {
                picks[picks.count - 1] = selectedInfo
            } else {
                picks.append(selectedInfo)
            }
        }

        return picks
    }

    // MARK: - Private

    /// Built once per process; predefined categories are compile-time
    /// constants, so no locking or invalidation is needed.
    private static let defaultDisplayInfos: [CategoryDisplayInfo] =
        DefaultCategoryIdentifier.allCases.map { displayInfo(for: $0) }

    private static func displayInfo(for category: CustomCategory) -> CategoryDisplayInfo {
        CategoryDisplayInfo(
            id: .custom(category.id),
            name: category.name,
            systemImageName: validatedSymbolName(category.iconToken),
            colorHex: category.colorHex,
            isArchived: category.isArchived,
            isCustom: true,
            sortOrder: customSortBase
        )
    }

    /// Custom categories sort after every predefined category; ordering among
    /// them comes from `displayOrder`'s name/id tie-breaks.
    private static let customSortBase = 1000

    /// A persisted symbol name can be invalid on this OS (synced from a
    /// device with a newer symbol catalog, or corrupt) — `Image(systemName:)`
    /// would render blank, so degrade to the default category glyph.
    private static func validatedSymbolName(_ name: String) -> String {
        #if canImport(UIKit)
        guard UIImage(systemName: name) != nil else { return CategoryIcon.defaultSymbol }
        #endif
        return name
    }
}
